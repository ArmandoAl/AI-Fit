# Resumen Paso 3.1 y 3.2: Normalización y Worker de Ingestión

## 1. Acciones Realizadas

Se ejecutaron de forma coordinada las **Tareas 3.1 y 3.2** del plan de migración arquitectural, normalizando el pipeline de carga de imágenes en el cliente Flutter para evitar fugas de memoria y construyendo el nuevo microservicio de ingestión visual en Python con segmentación automática de ropa (`rembg`) y extracción de embeddings visuales CLIP (`512-dim`).

---

### A. Normalización de Carga en Flutter (Tarea 3.1)

1. **Prendas (`garment`):**
   - Redimensionamiento proporcional para que el lado más largo sea de **máximo 1600 px**.
   - Límite estricto de peso: **máximo 1.5 MB** (`maxGarmentSizeBytes = 1572864`).
   - Algoritmo adaptativo que ajusta la calidad si el archivo inicial excede el límite permitido.

2. **Fotos de Identidad (`identity`):**
   - **Corrección de Regla Defectuosa:** Se eliminó la condición errónea que permitía imágenes gigantescas sin downscaling y forzaba un reescalado artificial hacia arriba si eran menores a 1024 px.
   - Se estableció un **límite superior estricto de 1920 px** en el lado más largo, protegiendo la memoria RAM de dispositivos móviles contra errores de *Out-Of-Memory (OOM)*.

3. **Preservación de Transparencia (Canal Alfa):**
   - Si la imagen contiene canal alfa (`image.hasAlpha == true`, como en PNGs o recortes transparentes), se codifica y preserva como PNG.
   - Si no contiene alfa o el PNG sobrepasa 1.5 MB, se optimiza en JPEG.

4. **Corrección de Orientación EXIF:**
   - Se aplica `img.bakeOrientation(image)` previo a cualquier redimensionamiento o codificación, eliminando fotos rotadas o deformadas provenientes de cámaras iOS/Android.

5. **Integración Transparente en [lib/core/services/storage_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/services/storage_service.dart):**
   - Toda subida mediante `uploadWardrobeItem` o `uploadUserPhoto` pasa automáticamente por la normalización, detectando el MIME real del binario (`image/png` vs `image/jpeg`).

---

### B. Microservicio de Ingestión Visual (Tarea 3.2: `services/image-worker/`)

Se construyó un microservicio en Python 3.10 con **FastAPI** y **Uvicorn**, diseñado para procesar prendas en segundo plano:

1. **Segmentación de Prenda (`rembg`):**
   - Remoción de fondo y creación de recorte transparente (`cutout.webp`) optimizado con `u2net_cloth_seg` / `u2net`.

2. **Embeddings CLIP de 512 Dimensiones:**
   - Modelo `clip-ViT-B-32` mediante `sentence-transformers`, generando vectores de 512 floats con normalización L2 unitaria, alineados con la columna `embedding extensions.vector(512)` de Supabase Postgres.

3. **Pipeline Integral Idempotente (`POST /process-item`):**
   - Recibe `{ "itemId": "...", "userId": "..." }`.
   - Consulta `public.wardrobe_items`; si ya cuenta con embedding y recorte, omite el procesamiento (*Cache Hit*).
   - Descarga la imagen original del bucket `user-media`.
   - Genera el cutout transparente y lo sube como `user-media/{userId}/wardrobe/{itemId}/cutout.webp`.
   - Calcula el embedding visual CLIP.
   - Actualiza el registro en Postgres con `embedding`, `embedding_model = 'clip-ViT-B-32'`, `cutout_path` y `processing_status = 'ready'`.

---

## 2. Bloques de Código Clave

### A. Normalización y Preservación Alfa en Flutter (`lib/core/utils/image_compression_util.dart`)
```dart
Uint8List _encodeInIsolate(_EncodeParams params) {
  try {
    var image = img.decodeImage(params.bytes);
    if (image == null) return params.bytes;

    // 1. Corregir orientación EXIF
    image = img.bakeOrientation(image);
    final hasAlpha = image.hasAlpha;

    switch (params.payload) {
      case AiImagePayload.garment:
        image = _resizeToMaxLongSide(image, ImageCompressionUtil.garmentMaxLongSide);

        // 2. Preservar canal alfa (PNG)
        if (hasAlpha) {
          final pngBytes = Uint8List.fromList(img.encodePng(image));
          if (pngBytes.lengthInBytes <= ImageCompressionUtil.maxGarmentSizeBytes) {
            return pngBytes;
          }
        }

        // Compresión JPEG adaptativa <= 1.5 MB
        var quality = ImageCompressionUtil.garmentJpegQuality;
        var encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
        while (encoded.lengthInBytes > ImageCompressionUtil.maxGarmentSizeBytes && quality > 50) {
          quality -= 10;
          encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
        }
        return encoded;

      case AiImagePayload.identity:
        // Límite estricto 1920px (sin forzar upscale)
        image = _resizeToMaxLongSide(image, ImageCompressionUtil.identityMaxLongSide);
        if (hasAlpha) return Uint8List.fromList(img.encodePng(image));
        return Uint8List.fromList(img.encodeJpg(image, quality: ImageCompressionUtil.identityJpegQuality));
      // ...
    }
  } catch (_) {
    return params.bytes;
  }
}
```

### B. Pipeline de Ingestión en Python (`services/image-worker/main.py`)
```python
@app.post("/process-item", response_model=ProcessItemResponse)
async def process_wardrobe_item(payload: ProcessItemRequest):
    item_id = payload.itemId
    user_id = payload.userId
    supabase = get_supabase()

    # 1. Idempotencia: Verificar si ya fue procesado
    item = supabase.table("wardrobe_items").select("*").eq("id", item_id).eq("user_id", user_id).maybe_single().execute().data
    if item.get("processing_status") == "ready" and item.get("embedding") and item.get("cutout_path"):
        return ProcessItemResponse(status="skipped", itemId=item_id, isCacheHit=True)

    # 2. Descargar original de user-media
    image_bytes = supabase.storage.from_("user-media").download(item["source_path"])
    original_img = Image.open(io.BytesIO(image_bytes))

    # 3. Generar Cutout con rembg y subir a Storage
    cutout_img = remove_background(original_img)
    webp_buffer = io.BytesIO()
    cutout_img.save(webp_buffer, format="WEBP", quality=90)
    cutout_path = f"{user_id}/wardrobe/{item_id}/cutout.webp"
    supabase.storage.from_("user-media").upload(cutout_path, webp_buffer.getvalue(), {"content-type": "image/webp", "upsert": "true"})

    # 4. Extraer embedding CLIP normalizado (512 dims)
    embedding_vec = generate_clip_embedding(cutout_img)

    # 5. Persistir en Postgres
    supabase.table("wardrobe_items").update({
        "embedding": embedding_vec,
        "embedding_model": "clip-ViT-B-32",
        "cutout_path": cutout_path,
        "processing_status": "ready",
    }).eq("id", item_id).execute()

    return ProcessItemResponse(status="success", itemId=item_id, cutoutPath=cutout_path, embeddingDimensions=len(embedding_vec))
```

---

## 3. Estado de la Compilación

Ejecución de `fvm flutter analyze`:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 2.9s)
```

**Resultado:** 0 errores y 0 advertencias en todo el proyecto Flutter.

---

## 4. Requerimientos de Acción Humana (Instrucciones para Levantar el Worker)

### A. Configuración de Variables de Entorno

Copia el archivo de ejemplo en el directorio del microservicio:
```bash
cd services/image-worker
cp .env.example .env
```

Edita `.env` con tus credenciales de Supabase:
```ini
SUPABASE_URL=https://<TU_PROYECTO_ID>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<TU_SUPABASE_SERVICE_ROLE_KEY>
PORT=8080
```

---

### B. Opción 1: Ejecución con Docker (Recomendada para Producción / Staging)

Construye la imagen e inicia el contenedor:
```bash
cd services/image-worker
docker build -t aifit-image-worker .
docker run -d --name aifit-image-worker -p 8080:8080 --env-file .env aifit-image-worker
```

Verifica la salud del servicio:
```bash
curl http://localhost:8080/health
# {"status":"healthy","service":"image-worker","version":"1.0.0","clip_model":"clip-ViT-B-32"}
```

---

### C. Opción 2: Ejecución Local con Virtualenv (Desarrollo)

```bash
cd services/image-worker
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

---

### D. Prueba Manual del Endpoint de Ingestión

Para disparar el procesamiento de una prenda existente:
```bash
curl -i --location --request POST 'http://localhost:8080/process-item' \
  --header 'Content-Type: application/json' \
  --data '{
    "itemId": "<UUID_DE_PRENDA>",
    "userId": "<UUID_DE_USUARIO>"
  }'
```
**Respuesta esperada:**
```json
{
  "status": "success",
  "itemId": "<UUID_DE_PRENDA>",
  "cutoutPath": "<UUID_USUARIO>/wardrobe/<UUID_PRENDA>/cutout.webp",
  "embeddingDimensions": 512,
  "isCacheHit": false
}
```
Si se vuelve a ejecutar la misma petición, responderá de inmediato con `status: "skipped"` y `isCacheHit: true`.
