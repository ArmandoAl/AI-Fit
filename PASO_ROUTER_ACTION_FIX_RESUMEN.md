# Resumen: Implementación de la Acción 'process_wardrobe_item' en AI-Router Gateway

**Fecha:** 21 de Septiembre de 2026  
**Proyecto:** AI-Fit Backend & Supabase Edge Functions  
**Autor:** Senior Backend & AI Systems Engineer  

---

## 1. Conexión hacia el Microservicio Image Worker

En la Supabase Edge Function `ai-router` ([`supabase/functions/ai-router/index.ts`](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/ai-router/index.ts)), se implementó el handler para `action === 'process_wardrobe_item'`, conectando directamente con el servicio de visión por computadora en Cloud Run:

- **Endpoint Primario:** `${IMAGE_WORKER_URL}/process-garment`
- **Endpoint Fallback:** `${IMAGE_WORKER_URL}/process-item`

### Autenticación y Secretos de Entorno:
- La Edge Function recupera `IMAGE_WORKER_URL` (por defecto `http://localhost:8080`) e inyecta la cabecera `Authorization: Bearer ${IMAGE_WORKER_API_KEY}` si está configurada.

---

## 2. Ingesta Flexible y Procesamiento de la Prenda

El handler acepta cualquiera de las siguientes modalidades de entrada en el payload JSON:
1. `{ itemId, imageUrl, userId }`
2. `{ itemId, imagePath, userId }`
3. `{ imageBase64, userId }`

### Pipeline de Procesamiento:
1. **Segmentación y Extracción en Image Worker:**
   - El worker recibe la imagen (vía URL HTTP/HTTPS, path de Storage o decodificación directa de base64).
   - Ejecuta `rembg` (sesión `u2net_cloth_seg` / `u2net`) aislando la prenda sobre fondo transparente/blanco.
   - Genera el embedding numérico de 512 dimensiones con `clip-ViT-B-32` normalizado L2.
2. **Persistencia en Supabase Storage (`user-media`):**
   - Si el worker devuelve `cutoutBase64` sin URL pre-firmada, `ai-router` almacena el WebP en el bucket `user-media` en `${userId}/wardrobe/${itemId}/cutout.webp` y genera una URL firmada de 7 días.
3. **Persistencia en Base de Datos Postgres (`public.wardrobe_items`):**
   - Actualiza de forma segura la fila de la prenda:
     - `cutout_path`: URL firmada o storage path del recorte.
     - `embedding`: Vector de 512 dimensiones (`vector(512)`).
     - `embedding_model`: `'clip-ViT-B-32'`.
     - `processing_status`: `'ready'`.
     - `updated_at`: Timestamp ISO-8601.

---

## 3. Formato de Respuesta del Gateway

La función retorna una respuesta HTTP 200 con el contrato estructurado:

```json
{
  "success": true,
  "status": "ok",
  "action": "process_wardrobe_item",
  "itemId": "uuid-de-la-prenda",
  "processedImageUrl": "https://<supabase-url>/storage/v1/object/sign/user-media/...",
  "cutoutPath": "https://<supabase-url>/storage/v1/object/sign/user-media/...",
  "embedding": [0.0124, -0.0451, ..., 0.0382],
  "dimensions": 512,
  "data": { ... },
  "latencyMs": 412
}
```

---

## 4. Comando de Despliegue en Producción

El comando ejecutado y validado exitosamente para desplegar la Edge Function actualizada es:

```bash
supabase functions deploy ai-router --no-verify-jwt
```

**Resultado del despliegue:**
```json
{
  "project_ref": "cictlfpnohrnvfchtroa",
  "functions": ["ai-router"],
  "dashboard_url": "https://supabase.com/dashboard/project/cictlfpnohrnvfchtroa/functions",
  "message": "Deployed Functions."
}
```
