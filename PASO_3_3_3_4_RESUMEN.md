# Resumen Paso 3.3 y 3.4: pgvector y Compositor Flat-Lay

## 1. Acciones Realizadas

### A. Compositor de Flat-Lays en Backend (`services/image-worker`) — Tarea 3.4
- **Módulo `flatlay_composer.py`:**
  - Implementación del canvas determinista en espacio de color **sRGB blanco puro `(255, 255, 255)` de 1024x1024 px**.
  - Algoritmo de centrado y ajuste proporcional `contain` mediante función `fit_and_center_in_slot`, evitando cualquier distorsión de aspecto o solapamiento destructivo.
  - Distribución espacial adaptativa según la presencia de prendas de abrigo:
    - **Layout de 4 piezas (con outerwear):**
      - Outerwear: Cuadrante superior izquierdo `(40, 40, 450, 450)`.
      - Top: Cuadrante superior derecho `(534, 40, 450, 450)`.
      - Bottom: Cuadrante inferior izquierdo `(40, 534, 450, 450)`.
      - Shoes: Cuadrante inferior derecho `(534, 534, 450, 450)`.
    - **Layout de 3 piezas (sin outerwear):**
      - Top: Superior centrado dominante `(112, 40, 800, 440)`.
      - Bottom: Inferior izquierdo `(60, 510, 500, 470)`.
      - Shoes: Inferior derecho `(600, 530, 360, 430)`.
  - Exportación optimizada a JPEG calidad 85 (con verificación para no exceder 900 KB).
- **Endpoint `POST /composite-flatlay` en `services/image-worker/main.py`:**
  - Recibe `{ userId, outfitId, items: [{ category, cutoutPath }] }`.
  - Verifica idempotencia en Supabase Storage (`generated/{userId}/flatlays/{outfitId}.jpg`).
  - Descarga los cutouts transparentes WebP del bucket `user-media`.
  - Compone la imagen y la sube al bucket `generated` con `content-type: image/jpeg`.
  - Retorna `storagePath` y URL firmada (`signedUrl`) con 7 días de validez.

### B. Pipeline de Try-On Reducido Estrictamente a 2 Imágenes
- **Eliminación del Payload Disperso (5-6 fotos separadas):**
  - En `supabase/functions/ai-router/index.ts` y `_shared/image_providers.ts`, el adaptador visual multi-proveedor (Google Imagen 3 / Gemini multimodal) recibe exactamente **2 imágenes**:
    1. `identity_image`: La foto base o ancla de identidad del usuario.
    2. `garment_flatlay`: El flat-lay consolidado de todas las prendas sobre fondo blanco puro.
  - En `lib/features/outfit/services/virtual_try_on_service.dart`, se añadieron campos `garmentFlatlayUrl` e `items` en `VirtualTryOnRequest`, resolviendo de forma transparente los cutouts de las prendas del outfit y delegando la composición o consumo del flat-lay único.

### C. Matching Semántico con `pgvector` — Tarea 3.3
- **Codificación Textual CLIP en `image-worker`:**
  - Endpoint `POST /encode-text` para proyectar descripciones textuales (*"casual summer outfit with light colors"*) al espacio vectorial latente de 512 dimensiones unitario (`clip-ViT-B-32`).
  - Endpoint `POST /match-wardrobe` en el worker para consultas directas contra la base de datos Postgres.
- **Integración en Gateway (`ai-router`) y Flutter:**
  - `action: 'match_wardrobe'` en `ai-router`: invoca la función RPC de Postgres `public.match_wardrobe(query_embedding, category_filter, match_count)`.
  - En `lib/features/outfit/services/wardrobe_search_algorithm.dart`:
    - Función `filterWardrobeSemantic(...)` que consulta la similitud vectorial de las prendas disponibles y aplica un boost ponderado (35% vector + 65% reglas de negocio), manteniendo fallback total a filtrado determinista si pgvector no tiene embeddings listos.
  - Conectado en `lib/features/outfit/services/outfit_service.dart` durante el flujo de sugerencia de outfits.

---

## 2. Bloques de Código Clave

### A. Lógica de Composición Espacial Determinista (`services/image-worker/flatlay_composer.py`)
```python
def compose_flatlay(items_by_category: Dict[str, Image.Image]) -> Image.Image:
    canvas = Image.new("RGB", CANVAS_SIZE, BG_COLOR) # 1024x1024, blanco puro (255, 255, 255)

    has_outerwear = "outerwear" in items_by_category and items_by_category["outerwear"] is not None

    if has_outerwear:
        # 4 cuadrantes balanceados con márgenes seguros
        slots = {
            "outerwear": (40, 40, 450, 450),
            "top": (534, 40, 450, 450),
            "bottom": (40, 534, 450, 450),
            "shoes": (534, 534, 450, 450),
        }
    else:
        # 3 piezas: Top superior dominante, bottom y zapatos abajo
        slots = {
            "top": (112, 40, 800, 440),
            "bottom": (60, 510, 500, 470),
            "shoes": (600, 530, 360, 430),
        }

    render_order = ["outerwear", "top", "bottom", "shoes"]
    for cat in render_order:
        img = items_by_category.get(cat)
        if img is None:
            continue
        slot = slots.get(cat)
        if not slot:
            continue

        if img.mode != "RGBA":
            img = img.convert("RGBA")

        fitted_img, (pos_x, pos_y) = fit_and_center_in_slot(img, slot)
        canvas.paste(fitted_img, (pos_x, pos_y), mask=fitted_img.split()[3])

    return canvas
```

### B. Invocación de Try-On con 2 Imágenes (`supabase/functions/_shared/image_providers.ts`)
```typescript
// Imagen 1: Foto de identidad
if (options.identityImageUrl) {
  const imgRes = await fetch(options.identityImageUrl);
  if (imgRes.ok) {
    const arrayBuf = await imgRes.arrayBuffer();
    const b64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuf)));
    parts.push({ inlineData: { mimeType: 'image/jpeg', data: b64 } });
  }
}

// Imagen 2: Flat-lay consolidado único sobre fondo blanco
if (options.garmentFlatlayUrl) {
  const flatlayRes = await fetch(options.garmentFlatlayUrl);
  if (flatlayRes.ok) {
    const arrayBuf = await flatlayRes.arrayBuffer();
    const b64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuf)));
    parts.push({ inlineData: { mimeType: 'image/jpeg', data: b64 } });
    console.log('✅ Loaded unified garment flat-lay into visual provider payload (2-image mode active)');
  }
}

// Instrucción prompt clara haciendo referencia a ambas imágenes
parts.push({ text: options.prompt });
```

### C. Matching Semántico con pgvector (`lib/features/outfit/services/wardrobe_search_algorithm.dart`)
```dart
static Future<FilteredWardrobe> filterWardrobeSemantic({
  required List<WardrobeItem> allItems,
  required OutfitIntent intent,
  String? userPrompt,
  DeepSeekService? gateway,
}) async {
  if (AppSupabaseClient.isInitialized && AppSupabaseClient.client != null) {
    final queryText = (userPrompt != null && userPrompt.trim().isNotEmpty)
        ? userPrompt.trim()
        : [...intent.styleTags, if (intent.occasion != null) intent.occasion!, ...intent.preferredColors].join(' ').trim();

    if (queryText.isNotEmpty) {
      try {
        final effectiveGateway = gateway ?? const DeepSeekService();
        final matches = await effectiveGateway.matchWardrobe(query: queryText, matchCount: 20);

        if (matches.isNotEmpty) {
          final similarityById = {
            for (final m in matches)
              if (m['id'] != null) m['id'].toString(): (m['similarity'] as num?)?.toDouble() ?? 0.0
          };

          return _filterAndRankWithVectorBoost(
            allItems: allItems,
            intent: intent,
            vectorSimilarities: similarityById,
          );
        }
      } catch (e) {
        _log('⚠️ pgvector search unavailable ($e). Falling back to rule-based filtering.');
      }
    }
  }

  return filterWardrobe(allItems: allItems, intent: intent);
}
```

---

## 3. Estado de la Compilación

### Salida de `fvm flutter analyze`
```bash
Analyzing AI-Fit...
No issues found! (ran in 2.6s)
```

### Salida de Verificación de Scripts Python
```bash
$ python3 -m py_compile services/image-worker/main.py services/image-worker/flatlay_composer.py
# Código de retorno: 0 (Sin errores de sintaxis)

$ python3 -c "from flatlay_composer import compose_flatlay, export_flatlay_jpeg; ..."
4-item flatlay size: 14789 bytes (14.4 KB)
3-item flatlay size: 12542 bytes (12.2 KB)
✅ flatlay_composer tests passed successfully!
```

---

## 4. Requerimientos de Acción Humana (Pruebas de Verificación)

### 1. Probar el Endpoint `/composite-flatlay` con curl
Cuando el contenedor o proceso local de `image-worker` esté ejecutándose (`uvicorn main:app --host 0.0.0.0 --port 8080`):
```bash
curl -X POST http://localhost:8080/composite-flatlay \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "00000000-0000-0000-0000-000000000000",
    "outfitId": "test-outfit-001",
    "items": [
      { "category": "outerwear", "cutoutPath": "00000000-0000-0000-0000-000000000000/wardrobe/item-coat/cutout.webp" },
      { "category": "top", "cutoutPath": "00000000-0000-0000-0000-000000000000/wardrobe/item-shirt/cutout.webp" },
      { "category": "bottom", "cutoutPath": "00000000-0000-0000-0000-000000000000/wardrobe/item-pants/cutout.webp" },
      { "category": "shoes", "cutoutPath": "00000000-0000-0000-0000-000000000000/wardrobe/item-shoes/cutout.webp" }
    ]
  }'
```

**Respuesta esperada:**
```json
{
  "status": "success",
  "outfitId": "test-outfit-001",
  "storagePath": "00000000-0000-0000-0000-000000000000/flatlays/test-outfit-001.jpg",
  "signedUrl": "https://<supabase-url>/storage/v1/object/sign/generated/...",
  "isCacheHit": false,
  "fileSizeBytes": 182430
}
```

### 2. Probar el Endpoint `/encode-text` con curl
```bash
curl -X POST http://localhost:8080/encode-text \
  -H "Content-Type: application/json" \
  -d '{"text": "casual summer outfit with beige linen shirt and white sneakers"}'
```

**Respuesta esperada:**
```json
{
  "dimensions": 512,
  "vector": [0.0341, -0.0125, 0.0872, ...]
}
```

### 3. Verificación del Flat-Lay en Supabase Storage
1. Abrir la consola de Supabase > **Storage** > Bucket **`generated`**.
2. Navegar a la carpeta `{userId}/flatlays/`.
3. Validar que la imagen `{outfitId}.jpg` muestre:
   - Fondo blanco puro sRGB.
   - Las 3 o 4 prendas posicionadas de forma armónica sin solapamientos.
   - Peso inferior a 900 KB (típicamente entre 120 KB y 450 KB).
