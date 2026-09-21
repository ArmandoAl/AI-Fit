import hashlib
import io
import logging
import os
import re
from typing import Dict, List, Optional
import uuid

import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Header, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from PIL import Image
from pydantic import BaseModel
from supabase import create_client, Client

from flatlay_composer import compose_flatlay, export_flatlay_jpeg, normalize_category_key

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("image-worker")

# ==============================================================================
# Configuración y Variables de Entorno
# ==============================================================================
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
WORKER_SECRET_TOKEN = os.getenv("IMAGE_WORKER_API_KEY", "")
CLIP_MODEL_NAME = os.getenv("CLIP_MODEL_NAME", "clip-ViT-B-32")

app = FastAPI(
    title="AI-Fit Image Ingestion & Flat-Lay Worker",
    description="Microservicio de segmentación de prendas (rembg), embeddings CLIP (512-dim), búsqueda pgvector y composición de flat-lays.",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==============================================================================
# Clientes y Modelos (Lazy Loaded)
# ==============================================================================
_supabase_client: Optional[Client] = None
_clip_model = None
_rembg_session = None


def get_supabase() -> Client:
    global _supabase_client
    if _supabase_client is None:
        if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
            raise HTTPException(
                status_code=500,
                detail="Supabase credentials (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) not configured on worker.",
            )
        _supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    return _supabase_client


def get_rembg_session():
    global _rembg_session
    if _rembg_session is None:
        try:
            from rembg import new_session
            try:
                _rembg_session = new_session("u2net_cloth_seg")
                logger.info("✅ rembg session initialized with 'u2net_cloth_seg'")
            except Exception:
                _rembg_session = new_session("u2net")
                logger.info("✅ rembg session initialized with fallback 'u2net'")
        except Exception as e:
            logger.warning(f"⚠️ Failed to initialize rembg session: {e}. Running in passthrough mode.")
            _rembg_session = False
    return _rembg_session


def get_clip_model():
    global _clip_model
    if _clip_model is None:
        try:
            from sentence_transformers import SentenceTransformer
            logger.info(f"⏳ Loading CLIP model '{CLIP_MODEL_NAME}'...")
            _clip_model = SentenceTransformer(CLIP_MODEL_NAME)
            logger.info(f"✅ CLIP model '{CLIP_MODEL_NAME}' loaded successfully (512 dimensions)")
        except Exception as e:
            logger.warning(f"⚠️ Failed to load CLIP model: {e}. Fallback vector generator enabled.")
            _clip_model = False
    return _clip_model


# ==============================================================================
# Modelos Pydantic
# ==============================================================================
class ProcessItemRequest(BaseModel):
    itemId: Optional[str] = None
    userId: Optional[str] = None
    imagePath: Optional[str] = None
    imageUrl: Optional[str] = None
    imageBase64: Optional[str] = None


class ProcessItemResponse(BaseModel):
    status: str
    itemId: Optional[str] = None
    cutoutPath: Optional[str] = None
    processedImageUrl: Optional[str] = None
    cutoutBase64: Optional[str] = None
    embedding: Optional[List[float]] = None
    embeddingDimensions: int
    isCacheHit: bool = False
    details: Optional[str] = None


class FlatlayItem(BaseModel):
    category: str  # 'top' | 'bottom' | 'shoes' | 'outerwear' | 'one_piece' | 'accessories' | 'bag' | 'scarf'
    cutoutPath: str


class CompositeFlatlayRequest(BaseModel):
    userId: str
    outfitId: str
    items: List[FlatlayItem]


class CompositeFlatlayResponse(BaseModel):
    status: str
    outfitId: str
    storagePath: str
    signedUrl: Optional[str] = None
    isCacheHit: bool = False
    fileSizeBytes: Optional[int] = None
    details: Optional[str] = None


class EncodeTextRequest(BaseModel):
    text: str


class EncodeTextResponse(BaseModel):
    dimensions: int
    vector: List[float]


class MatchWardrobeRequest(BaseModel):
    userId: str
    query: str
    category: Optional[str] = None
    matchCount: int = 12


class WardrobeMatchItem(BaseModel):
    id: str
    category: str
    similarity: float
    metadata: Optional[dict] = None


class MatchWardrobeResponse(BaseModel):
    query: str
    matches: List[WardrobeMatchItem]


# ==============================================================================
# Utilidades de Procesamiento
# ==============================================================================
UUID_REGEX = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def is_valid_uuid(val: Optional[str]) -> bool:
    """
    Valida sintaxis estricta de UUID (RFC 4122) para evitar excepciones PostgREST 22P02.
    """
    if not val or not isinstance(val, str):
        return False
    val_clean = val.strip()
    if not UUID_REGEX.match(val_clean):
        return False
    try:
        parsed = uuid.UUID(val_clean)
        return str(parsed).lower() == val_clean.lower()
    except (ValueError, TypeError, AttributeError):
        return False


def remove_background(image: Image.Image) -> Image.Image:
    """Remueve el fondo de una imagen de prenda preservando el canal alfa."""
    session = get_rembg_session()
    if session:
        try:
            from rembg import remove
            cutout = remove(image, session=session, alpha_matting=True)
            return cutout
        except Exception as e:
            logger.error(f"❌ Error during background removal: {e}")
    if image.mode != "RGBA":
        return image.convert("RGBA")
    return image


def generate_clip_embedding(image: Image.Image) -> List[float]:
    """Genera vector de 512 dimensiones normalizado L2 con CLIP para imágenes."""
    model = get_clip_model()
    if model:
        try:
            if image.mode == "RGBA":
                rgb_image = Image.new("RGB", image.size, (255, 255, 255))
                rgb_image.paste(image, mask=image.split()[3])
            else:
                rgb_image = image.convert("RGB")

            vector = model.encode(rgb_image, convert_to_numpy=True)
            norm = np.linalg.norm(vector)
            if norm > 0:
                vector = vector / norm
            return vector.tolist()
        except Exception as e:
            logger.error(f"❌ Error during CLIP image encoding: {e}")

    # Fallback determinista pseudo-aleatorio basado en hash de la imagen
    img_bytes = image.tobytes()
    seed = int(hashlib.sha256(img_bytes).hexdigest()[:8], 16)
    rng = np.random.default_rng(seed)
    synthetic_vec = rng.standard_normal(512)
    synthetic_vec /= np.linalg.norm(synthetic_vec)
    return synthetic_vec.tolist()


def generate_clip_text_embedding(text: str) -> List[float]:
    """Genera vector de 512 dimensiones normalizado L2 con CLIP para texto."""
    model = get_clip_model()
    if model:
        try:
            vector = model.encode(text, convert_to_numpy=True)
            norm = np.linalg.norm(vector)
            if norm > 0:
                vector = vector / norm
            return vector.tolist()
        except Exception as e:
            logger.error(f"❌ Error during CLIP text encoding: {e}")

    # Fallback determinista pseudo-aleatorio basado en hash del texto
    seed = int(hashlib.sha256(text.encode("utf-8")).hexdigest()[:8], 16)
    rng = np.random.default_rng(seed)
    synthetic_vec = rng.standard_normal(512)
    synthetic_vec /= np.linalg.norm(synthetic_vec)
    return synthetic_vec.tolist()


# ==============================================================================
# Endpoints de la API
# ==============================================================================
@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "image-worker",
        "version": "1.1.0",
        "clip_model": CLIP_MODEL_NAME,
    }


@app.post("/segment")
async def segment_image(file: UploadFile = File(...)):
    """Endpoint directo para recortar prendas y devolver WebP transparente."""
    contents = await file.read()
    image = Image.open(io.BytesIO(contents))
    cutout = remove_background(image)

    buffer = io.BytesIO()
    cutout.save(buffer, format="WEBP", lossless=True)
    return Response(content=buffer.getvalue(), media_type="image/webp")


@app.post("/embed")
async def embed_image(file: UploadFile = File(...)):
    """Endpoint directo para generar embedding CLIP de 512 dimensiones desde imagen."""
    contents = await file.read()
    image = Image.open(io.BytesIO(contents))
    vector = generate_clip_embedding(image)
    return {
        "dimensions": len(vector),
        "vector": vector,
    }


@app.post("/encode-text", response_model=EncodeTextResponse)
async def encode_text_endpoint(payload: EncodeTextRequest):
    """
    Tarea 3.3: Codifica texto en lenguaje natural a vector CLIP de 512 dimensiones unitario.
    Permite proyectar prompts de usuario al espacio latente compartido de prendas para pgvector.
    """
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty.")
    vector = generate_clip_text_embedding(text)
    return EncodeTextResponse(dimensions=len(vector), vector=vector)


@app.post("/composite-flatlay", response_model=CompositeFlatlayResponse)
async def composite_flatlay_endpoint(payload: CompositeFlatlayRequest):
    """
    Tarea 3.4: Compositor de Flat-Lays sobre canvas blanco puro sRGB (1024x1024).
    1. Verifica si ya existe en generated/{userId}/flatlays/{outfitId}.jpg (Idempotencia).
    2. Descarga cutouts WebP desde Supabase Storage bucket 'user-media'.
    3. Monta prendas deterministamente usando fit_and_center_in_slot ('contain').
    4. Exporta a JPEG calidad 85 (máx 900 KB).
    5. Sube a Supabase Storage: generated/{userId}/flatlays/{outfitId}.jpg.
    6. Retorna storagePath y signedUrl con 7 días de validez.
    """
    user_id = payload.userId
    outfit_id = payload.outfitId
    items = payload.items

    if not items:
        raise HTTPException(status_code=400, detail="Items list cannot be empty.")

    supabase = get_supabase()
    target_storage_path = f"{user_id}/flatlays/{outfit_id}.jpg"

    # 1. Idempotencia: Verificar si ya existe en bucket 'generated'
    try:
        signed_res = supabase.storage.from_("generated").create_signed_url(target_storage_path, 604800)
        if signed_res and signed_res.get("signedUrl"):
            logger.info(f"⚡ Flat-lay already exists for outfit {outfit_id}. Returning cached URL.")
            return CompositeFlatlayResponse(
                status="success",
                outfitId=outfit_id,
                storagePath=target_storage_path,
                signedUrl=signed_res["signedUrl"],
                isCacheHit=True,
                details="Flat-lay was already generated and cached.",
            )
    except Exception as e:
        logger.debug(f"Cache miss or error querying existing flat-lay: {e}")

    # 2. Descargar cada cutout de Storage 'user-media'
    images_by_category: Dict[str, Image.Image] = {}
    extra_accessories: List[Image.Image] = []

    for item in items:
        cat = item.category.lower().strip()
        path = item.cutoutPath.strip()
        if "user-media/" in path:
            path = path.split("user-media/")[-1]

        try:
            logger.info(f"⬇️ Downloading cutout for category '{cat}' from '{path}'...")
            raw_bytes = supabase.storage.from_("user-media").download(path)
            img = Image.open(io.BytesIO(raw_bytes))
            if img.mode != "RGBA":
                img = img.convert("RGBA")

            norm_cat = normalize_category_key(cat)
            if norm_cat == "accessories":
                extra_accessories.append(img)
            else:
                images_by_category[norm_cat] = img
        except Exception as err:
            logger.warning(f"⚠️ Failed to download cutout '{path}' for category '{cat}': {err}")

    if not images_by_category and not extra_accessories:
        raise HTTPException(
            status_code=404,
            detail="Could not retrieve any valid garment cutout images from storage.",
        )

    # 3. Componer el Flat-Lay dinámico (soporta one_piece y múltiples accesorios)
    logger.info(
        f"🎨 Composing flat-lay for outfit {outfit_id} with categories: {list(images_by_category.keys())} "
        f"(+ {len(extra_accessories)} accessories)"
    )
    canvas = compose_flatlay(images_by_category, extra_accessories=extra_accessories)

    # 4. Exportar como JPEG calidad 85 (<= 900 KB)
    jpeg_bytes = export_flatlay_jpeg(canvas, quality=85)
    file_size = len(jpeg_bytes)
    logger.info(f"📦 Flat-lay generated. Size: {file_size} bytes ({file_size / 1024:.1f} KB)")

    if file_size > 900 * 1024:
        logger.warning(f"⚠️ Flat-lay size ({file_size} bytes) exceeds 900 KB. Re-encoding at quality 75...")
        jpeg_bytes = export_flatlay_jpeg(canvas, quality=75)
        file_size = len(jpeg_bytes)

    # 5. Subir a Supabase Storage (bucket 'generated')
    logger.info(f"⬆️ Uploading flat-lay to bucket 'generated': {target_storage_path}")
    supabase.storage.from_("generated").upload(
        path=target_storage_path,
        file=jpeg_bytes,
        file_options={"content-type": "image/jpeg", "upsert": "true"},
    )

    # 6. Crear Signed URL (7 días TTL = 604800 segundos)
    signed_url = None
    try:
        signed_res = supabase.storage.from_("generated").create_signed_url(target_storage_path, 604800)
        signed_url = signed_res.get("signedUrl") if signed_res else None
    except Exception as e:
        logger.warning(f"⚠️ Could not generate signed URL: {e}")

    return CompositeFlatlayResponse(
        status="success",
        outfitId=outfit_id,
        storagePath=target_storage_path,
        signedUrl=signed_url,
        isCacheHit=False,
        fileSizeBytes=file_size,
    )


@app.post("/match-wardrobe", response_model=MatchWardrobeResponse)
async def match_wardrobe_endpoint(payload: MatchWardrobeRequest):
    """
    Tarea 3.3: Búsqueda semántica vectorial vía pgvector en Supabase:
    1. Codifica el texto con CLIP (512-dim).
    2. Invoca RPC 'public.match_wardrobe' en PostgreSQL.
    """
    supabase = get_supabase()
    query_vec = generate_clip_text_embedding(payload.query)

    try:
        rpc_res = supabase.rpc(
            "match_wardrobe",
            {
                "query_embedding": query_vec,
                "category_filter": payload.category if payload.category else None,
                "match_count": payload.matchCount,
            },
        ).execute()

        matches = []
        for row in (rpc_res.data or []):
            matches.append(
                WardrobeMatchItem(
                    id=str(row.get("id")),
                    category=str(row.get("category")),
                    similarity=float(row.get("similarity", 0.0)),
                    metadata=row.get("metadata"),
                )
            )

        return MatchWardrobeResponse(query=payload.query, matches=matches)
    except Exception as err:
        logger.error(f"❌ Error in match_wardrobe RPC: {err}")
        raise HTTPException(status_code=500, detail=f"match_wardrobe RPC failed: {err}")


@app.post("/process-item", response_model=ProcessItemResponse)
@app.post("/process-garment", response_model=ProcessItemResponse)
async def process_wardrobe_item(
    payload: ProcessItemRequest,
    authorization: Optional[str] = Header(None),
):
    """
    Pipeline de ingestión visual (rembg + CLIP embedding):
    1. Verifica idempotencia en Supabase si itemId y userId están presentes.
    2. Obtiene la imagen de: base64, URL pública/firmada o Supabase Storage.
    3. Genera cutout sin fondo en formato WebP transparente (rembg).
    4. Si itemId y userId existen, sube cutout a `user-media` y actualiza `wardrobe_items`.
    5. Extrae vector CLIP de 512 dimensiones (clip-ViT-B-32).
    6. Retorna cutoutPath, processedImageUrl, cutoutBase64 y vector de embedding.
    """
    # Requisito 2: Validar formato UUID defensivamente para evitar excepciones PostgREST 22P02
    if payload.itemId and not is_valid_uuid(payload.itemId):
        logger.warning(f"⚠️ Invalid UUID syntax for itemId: '{payload.itemId}'")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid itemId format: '{payload.itemId}'. Must be a valid UUID (RFC 4122).",
        )

    if payload.userId and payload.userId != "anonymous" and not is_valid_uuid(payload.userId):
        logger.warning(f"⚠️ Invalid UUID syntax for userId: '{payload.userId}'")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid userId format: '{payload.userId}'. Must be a valid UUID (RFC 4122).",
        )

    item_id = payload.itemId or f"item_{hashlib.md5(os.urandom(16)).hexdigest()[:12]}"
    user_id = payload.userId or "anonymous"
    supabase = None
    try:
        supabase = get_supabase()
    except Exception as e:
        logger.warning(f"⚠️ Supabase not configured on worker: {e}")

    logger.info(f"📥 Processing garment item: {item_id} (user: {user_id})")

    # 1. Consultar registro e Idempotencia en Supabase (si aplica)
    item = None
    if supabase and payload.itemId and payload.userId and payload.userId != "anonymous":
        try:
            res = (
                supabase.table("wardrobe_items")
                .select("id, user_id, source_path, cutout_path, content_hash, embedding, processing_status")
                .eq("id", payload.itemId)
                .eq("user_id", payload.userId)
                .maybe_single()
                .execute()
            )
            item = res.data
        except Exception as q_err:
            logger.error(f"❌ Error querying wardrobe item {payload.itemId}: {q_err}")
            err_str = str(q_err)
            if "22P02" in err_str or "invalid input syntax for type uuid" in err_str:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid UUID syntax when querying database: {err_str}",
                )
            raise HTTPException(
                status_code=500,
                detail=f"Database query error for wardrobe item {payload.itemId}: {err_str}",
            )

        # Requisito 2: Si el ítem no existe en la tabla, devolver 404 estructurado en vez de un 500 no capturado
        if not item:
            logger.warning(f"⚠️ Wardrobe item '{payload.itemId}' not found in database for user '{payload.userId}'")
            raise HTTPException(
                status_code=404,
                detail=f"Wardrobe item '{payload.itemId}' not found in database for user '{payload.userId}'.",
            )

        # Idempotencia: Verificar si ya está procesado
        if (
            item
            and item.get("processing_status") == "ready"
            and item.get("embedding")
            and item.get("cutout_path")
        ):
            logger.info(f"⚡ Item {payload.itemId} already processed. Skipping (Cache Hit).")
            return ProcessItemResponse(
                status="skipped",
                itemId=payload.itemId,
                cutoutPath=item["cutout_path"],
                processedImageUrl=item["cutout_path"],
                embedding=item["embedding"],
                embeddingDimensions=len(item["embedding"]),
                isCacheHit=True,
                details="Item already has embedding and cutout.",
            )

        # Marcar estado como 'processing'
        try:
            supabase.table("wardrobe_items").update({
                "processing_status": "processing",
            }).eq("id", payload.itemId).execute()
        except Exception as upd_err:
            logger.debug(f"Non-fatal error updating status to processing: {upd_err}")

    try:
        # 2. Descargar o decodificar imagen original
        image_bytes = None
        if payload.imageBase64:
            b64_clean = payload.imageBase64.split(",")[-1]
            image_bytes = base64.b64decode(b64_clean)
        else:
            raw_path = payload.imageUrl or payload.imagePath or (item.get("source_path") if item else None)
            if not raw_path:
                raise ValueError("No imageUrl, imagePath or imageBase64 provided in request")

            clean_path = raw_path
            if clean_path.startswith("http://") or clean_path.startswith("https://"):
                logger.info(f"⬇️ Downloading garment image from URL: {clean_path[:80]}...")
                req = urllib.request.Request(clean_path, headers={"User-Agent": "AI-Fit/1.0"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    image_bytes = resp.read()
            elif supabase:
                if "user-media/" in clean_path:
                    clean_path = clean_path.split("user-media/")[-1]
                logger.info(f"⬇️ Downloading original image from bucket 'user-media': {clean_path}")
                image_bytes = supabase.storage.from_("user-media").download(clean_path)
            else:
                raise ValueError(f"Cannot download path '{clean_path}' without Supabase client or HTTP URL")

        original_img = Image.open(io.BytesIO(image_bytes))

        # 3. Generar Cutout con fondo transparente (rembg)
        logger.info(f"✂️ Generating background cutout for item {item_id}...")
        cutout_img = remove_background(original_img)

        # Codificar a WebP transparente
        webp_buffer = io.BytesIO()
        cutout_img.save(webp_buffer, format="WEBP", quality=90, method=6)
        webp_bytes = webp_buffer.getvalue()
        cutout_b64 = base64.b64encode(webp_bytes).decode("ascii")

        # 4. Extraer embedding CLIP de 512 dimensiones
        logger.info(f"🧠 Extracting CLIP 512-dim embedding for item {item_id}...")
        embedding_vec = generate_clip_embedding(cutout_img)

        # 5. Subir Cutout a Supabase Storage y actualizar BD si itemId & userId están disponibles
        final_cutout_path = None
        if supabase and payload.itemId and payload.userId:
            cutout_storage_path = f"{user_id}/wardrobe/{item_id}/cutout.webp"
            logger.info(f"⬆️ Uploading cutout to 'user-media': {cutout_storage_path} ({len(webp_bytes)} bytes)")
            supabase.storage.from_("user-media").upload(
                path=cutout_storage_path,
                file=webp_bytes,
                file_options={"content-type": "image/webp", "upsert": "true"},
            )

            # URL firmada con 7 días de validez
            try:
                signed_res = supabase.storage.from_("user-media").create_signed_url(cutout_storage_path, 604800)
                final_cutout_path = signed_res.get("signedUrl") if signed_res else cutout_storage_path
            except Exception as e:
                logger.warning(f"⚠️ Could not generate signed URL: {e}")
                final_cutout_path = cutout_storage_path

            # Actualizar tabla public.wardrobe_items
            logger.info(f"💾 Updating wardrobe_items record in database for {item_id}...")
            supabase.table("wardrobe_items").update({
                "embedding": embedding_vec,
                "embedding_model": "clip-ViT-B-32",
                "cutout_path": final_cutout_path,
                "processing_status": "ready",
                "processing_error": None,
            }).eq("id", item_id).execute()

        logger.info(f"🎉 Item {item_id} successfully processed and marked ready.")
        return ProcessItemResponse(
            status="success",
            itemId=item_id,
            cutoutPath=final_cutout_path,
            processedImageUrl=final_cutout_path,
            cutoutBase64=cutout_b64,
            embedding=embedding_vec,
            embeddingDimensions=len(embedding_vec),
            isCacheHit=False,
        )

    except HTTPException:
        # Re-lanzar directamente excepciones HTTP 400/404 sin convertirlas en 500
        raise
    except Exception as err:
        error_msg = str(err)
        logger.error(f"💥 Failed to process wardrobe item {item_id}: {error_msg}")
        if supabase and payload.itemId and is_valid_uuid(payload.itemId) and item:
            try:
                supabase.table("wardrobe_items").update({
                    "processing_status": "failed",
                    "processing_error": error_msg,
                }).eq("id", payload.itemId).execute()
            except Exception:
                pass
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process wardrobe item {item_id}: {error_msg}",
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)
