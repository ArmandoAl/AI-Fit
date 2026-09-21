# ==============================================================================
# flatlay_composer.py — Compositor Dinámico de Flat-Lays para Virtual Try-On
# ==============================================================================
# Consolida prendas y accesorios con fondo transparente en un solo canvas sRGB 1024x1024
# sobre fondo blanco puro, soportando:
# 1. Modo One-Piece (vestidos/enterizos verticales dominantes + calzado + abrigo + accesorios)
# 2. Modo Two-Piece clásico con 1-2 accesorios coordinados
# Mantiene el aspect ratio intacto ('contain') y reduce el payload del modelo a 2 imágenes.

import io
from typing import Any, Dict, List, Optional, Tuple, Union
from PIL import Image

CANVAS_SIZE = (1024, 1024)
BG_COLOR = (255, 255, 255)  # Blanco puro sRGB

ONE_PIECE_ALIASES = {
    "one_piece",
    "one-piece",
    "dress",
    "vestido",
    "jumpsuit",
    "enterizo",
    "romper",
}

ACCESSORY_ALIASES = {
    "accessories",
    "accessory",
    "accesorio",
    "accesorios",
    "scarf",
    "bufanda",
    "bag",
    "bolso",
    "jewelry",
    "necklace",
    "collar",
    "earrings",
    "aretes",
    "belt",
    "cinturon",
    "cinturón",
}


def normalize_category_key(raw_cat: str) -> str:
    """Normaliza variantes y alias de categorías a claves canónicas."""
    clean = raw_cat.strip().lower().replace("-", "_")
    if clean in ONE_PIECE_ALIASES or raw_cat.strip().lower() in ONE_PIECE_ALIASES:
        return "one_piece"
    if clean in ACCESSORY_ALIASES or raw_cat.strip().lower() in ACCESSORY_ALIASES:
        return "accessories"
    return clean


def fit_and_center_in_slot(
    image: Image.Image,
    slot: Tuple[int, int, int, int],  # (left, top, width, height)
) -> Tuple[Image.Image, Tuple[int, int]]:
    """
    Redimensiona proporcionalmente la prenda ('contain') para ajustarse al slot
    sin deformaciones ni cortes, calculando la posición centrada.
    """
    left, top, slot_w, slot_h = slot
    img_w, img_h = image.size

    if img_w <= 0 or img_h <= 0:
        return image, (left, top)

    scale = min(slot_w / img_w, slot_h / img_h)
    new_w = max(1, int(img_w * scale))
    new_h = max(1, int(img_h * scale))

    resized = image.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Centrar dentro del slot
    offset_x = left + (slot_w - new_w) // 2
    offset_y = top + (slot_h - new_h) // 2

    return resized, (offset_x, offset_y)


def _paste_item(canvas: Image.Image, img: Image.Image, slot: Tuple[int, int, int, int]):
    """Pega una imagen con canal alfa transparente en un slot del canvas."""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    fitted_img, (pos_x, pos_y) = fit_and_center_in_slot(img, slot)
    canvas.paste(fitted_img, (pos_x, pos_y), mask=fitted_img.split()[3])


def compose_flatlay(
    items_by_category: Dict[str, Any],
    extra_accessories: Optional[List[Image.Image]] = None,
) -> Image.Image:
    """
    Monta las prendas sobre un canvas blanco de 1024x1024 con distribución adaptativa
    según la presencia de piezas únicas (one_piece), dos piezas (top+bottom), abrigo y accesorios.

    Distribuciones soportadas:
    --------------------------
    A. Modo One-Piece (Vestidos / Enterizos):
       - Con outerwear:
           outerwear: lateral izquierdo (40, 50, 440, 580)
           one_piece: derecho vertical dominante (500, 40, 480, 680)
           shoes: inferior derecho (520, 740, 460, 244)
           accessories: inferior izquierdo (40, 660, 440, 324) y/o superior izquierdo
       - Sin outerwear:
           one_piece: centro vertical dominante (262, 40, 500, 680)
           shoes: inferior derecho (520, 740, 460, 244)
           accessories: laterales (40, 160, 210, 380) / (774, 160, 210, 380) / (40, 640, 400, 340)

    B. Modo Two-Piece (Top + Bottom):
       - Clásico sin outerwear: Top arriba, Bottom y Shoes abajo.
       - Clásico con outerwear: 4 cuadrantes.
       - Con accesorios: Ranuras perimetrales armónicas sin solapamiento.
    """
    canvas = Image.new("RGB", CANVAS_SIZE, BG_COLOR)

    # 1. Normalizar y clasificar los items entrantes
    normalized_items: Dict[str, Image.Image] = {}
    accessories_list: List[Image.Image] = []

    if extra_accessories:
        accessories_list.extend(extra_accessories)

    for k, v in items_by_category.items():
        if v is None:
            continue
        norm_cat = normalize_category_key(k)
        if norm_cat == "accessories":
            if isinstance(v, list):
                accessories_list.extend(v)
            else:
                accessories_list.append(v)
        else:
            if isinstance(v, list) and len(v) > 0:
                normalized_items[norm_cat] = v[0]
            elif isinstance(v, Image.Image):
                normalized_items[norm_cat] = v

    is_one_piece = "one_piece" in normalized_items
    has_outerwear = "outerwear" in normalized_items
    has_top = "top" in normalized_items
    has_bottom = "bottom" in normalized_items
    has_shoes = "shoes" in normalized_items

    # --------------------------------------------------------------------------
    # Layout A: Modo One-Piece
    # --------------------------------------------------------------------------
    if is_one_piece:
        one_piece_img = normalized_items["one_piece"]
        shoes_img = normalized_items.get("shoes")
        outerwear_img = normalized_items.get("outerwear")

        if has_outerwear:
            # Con abrigo a la izquierda
            _paste_item(canvas, outerwear_img, (40, 50, 440, 580))
            _paste_item(canvas, one_piece_img, (500, 40, 480, 680))
            if shoes_img:
                _paste_item(canvas, shoes_img, (520, 740, 460, 244))

            # Accesorios en slots libres
            if len(accessories_list) > 0:
                _paste_item(canvas, accessories_list[0], (40, 660, 440, 324))
            if len(accessories_list) > 1:
                _paste_item(canvas, accessories_list[1], (40, 40, 180, 180))

        else:
            # Sin abrigo: One-piece centrado vertical dominante
            _paste_item(canvas, one_piece_img, (262, 40, 500, 680))

            if shoes_img:
                _paste_item(canvas, shoes_img, (520, 740, 460, 244))

            # Accesorios a los lados del vestido o abajo a la izquierda
            if len(accessories_list) == 1:
                _paste_item(canvas, accessories_list[0], (40, 640, 420, 340))
            elif len(accessories_list) >= 2:
                _paste_item(canvas, accessories_list[0], (40, 160, 210, 380))
                _paste_item(canvas, accessories_list[1], (774, 160, 210, 380))
                # Si hubiera un tercer accesorio, en slot inferior izquierdo
                if len(accessories_list) >= 3:
                    _paste_item(canvas, accessories_list[2], (40, 640, 420, 340))

        return canvas

    # --------------------------------------------------------------------------
    # Layout B: Modo Two-Piece (Top + Bottom)
    # --------------------------------------------------------------------------
    top_img = normalized_items.get("top")
    bottom_img = normalized_items.get("bottom")
    shoes_img = normalized_items.get("shoes")
    outerwear_img = normalized_items.get("outerwear")

    if has_outerwear:
        if len(accessories_list) == 0:
            # 4 cuadrantes clásicos sin accesorios
            slots = {
                "outerwear": (40, 40, 450, 450),
                "top": (534, 40, 450, 450),
                "bottom": (40, 534, 450, 450),
                "shoes": (534, 534, 450, 450),
            }
            if outerwear_img:
                _paste_item(canvas, outerwear_img, slots["outerwear"])
            if top_img:
                _paste_item(canvas, top_img, slots["top"])
            if bottom_img:
                _paste_item(canvas, bottom_img, slots["bottom"])
            if shoes_img:
                _paste_item(canvas, shoes_img, slots["shoes"])
        else:
            # Layout con outerwear + accesorios
            if outerwear_img:
                _paste_item(canvas, outerwear_img, (30, 40, 380, 440))
            if top_img:
                _paste_item(canvas, top_img, (430, 40, 380, 440))
            if bottom_img:
                _paste_item(canvas, bottom_img, (30, 520, 380, 460))
            if shoes_img:
                _paste_item(canvas, shoes_img, (430, 540, 380, 440))

            if len(accessories_list) > 0:
                _paste_item(canvas, accessories_list[0], (830, 50, 164, 420))
            if len(accessories_list) > 1:
                _paste_item(canvas, accessories_list[1], (830, 520, 164, 460))

    else:
        # Sin outerwear
        if len(accessories_list) == 0:
            # Layout de 3 piezas estándar
            if top_img:
                _paste_item(canvas, top_img, (112, 40, 800, 440))
            if bottom_img:
                _paste_item(canvas, bottom_img, (60, 510, 500, 470))
            if shoes_img:
                _paste_item(canvas, shoes_img, (600, 530, 360, 430))
        else:
            # Layout de 3 piezas + 1 o 2 accesorios
            if top_img:
                _paste_item(canvas, top_img, (180, 40, 640, 440))
            if bottom_img:
                _paste_item(canvas, bottom_img, (60, 510, 460, 470))
            if shoes_img:
                _paste_item(canvas, shoes_img, (540, 530, 430, 430))

            if len(accessories_list) == 1:
                _paste_item(canvas, accessories_list[0], (30, 50, 140, 400))
            elif len(accessories_list) >= 2:
                _paste_item(canvas, accessories_list[0], (30, 50, 140, 400))
                _paste_item(canvas, accessories_list[1], (830, 50, 160, 400))

    return canvas


def export_flatlay_jpeg(canvas: Image.Image, quality: int = 85) -> bytes:
    """
    Exporta el flat-lay en formato JPEG calidad 85, optimizado para ser <= 900 KB.
    """
    buffer = io.BytesIO()
    rgb_canvas = canvas.convert("RGB")
    rgb_canvas.save(buffer, format="JPEG", quality=quality, optimize=True)
    return buffer.getvalue()
