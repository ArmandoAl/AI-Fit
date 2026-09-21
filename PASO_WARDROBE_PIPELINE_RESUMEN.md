# Resumen de Implementación: Pipeline de Ingesta de Prendas y Generación de Base Avatar

**Fecha:** 21 de Septiembre de 2026  
**Proyecto:** AI-Fit Mobile App & Backend Gateway  
**Autor:** Senior Fullstack & Computer Vision Engineer  

---

## 1. Redirección de Subida de Prendas: Pipeline de Segmentación y Embeddings CLIP

### Flujo de Ingesta Automatizado:
1. **Captura y Almacenamiento Inicial:**
   - La imagen original se comprime y se sube de forma autenticada a Supabase Storage en el bucket `user-media`: `${userId}/wardrobe/item_${timestamp}.jpg`.
   - Se inserta el registro en la tabla `public.wardrobe_items` con estado inicial `processing_status = 'processing'`.

2. **Ejecución del Worker de Visión por Computadora:**
   - Inmediatamente tras la inserción, el repositorio (`WardrobeRepositoryImpl`) invoca al Gateway de IA (`DeepSeekService.processWardrobeItem` -> `ai-router` con acción `process_wardrobe_item`).
   - `ai-router` enruta la petición de forma segura hacia el microservicio en Cloud Run / FastAPI (`image-worker` en el endpoint `/process-item`).
   - **Segmentación (`rembg`):** El worker ejecuta una sesión `u2net_cloth_seg` (con fallback `u2net`) aislando la prenda del fondo y generando un cutout limpio en formato WebP con canal alfa.
   - **Almacenamiento del Recorte:** El archivo WebP procesado se sube al bucket `user-media` en `${userId}/wardrobe/${itemId}/cutout.webp` y se genera una URL firmada de 7 días.
   - **Extracción de Embeddings CLIP (`clip-ViT-B-32`):** Se genera el vector unitario L2 normalizado de 512 dimensiones correspondiente a la prenda.
   - **Persistencia en Postgres (`public.wardrobe_items`):** El worker actualiza directamente la fila de la prenda:
     - `cutout_path`: URL firmada o storage path del recorte.
     - `embedding`: Vector de 512 dimensiones (`vector(512)`).
     - `embedding_model`: `'clip-ViT-B-32'`.
     - `processing_status`: `'ready'`.

3. **Tolerancia a Fallos:**
   - Si el microservicio de procesamiento experimenta indisponibilidad o timeout, el fallo se captura de forma no-bloqueante (`try-catch`), preservando la imagen cruda y permitiendo al usuario continuar usando la prenda.

---

## 2. Formato de Imagen y Presentación Visual en el Armario

1. **Prioridad Visual en el Dominio (`WardrobeItem`):**
   - Se configuró el getter `displayImageUrl` que prioriza `cutoutPath` si existe y es válido, recurriendo a `imageUrl` únicamente si el recorte aún no está listo.
2. **Visualización en Cuadrícula (`WardrobeItemCard`):**
   - Cuando el recorte está disponible, la tarjeta monta la prenda sobre un lienzo blanco puro (`Colors.white`) utilizando `BoxFit.contain`, logrando una apariencia de catálogo de moda e-commerce premium sin fondos ruidosos.
   - Se incorporó una insignia discreta flotante con icono de varita mágica (`auto_fix_high`) en oro/dorado indicando que la prenda cuenta con fondo aislado por IA.
3. **Detalle de la Prenda (`WardrobeItemDetailPage`):**
   - El visor principal expandido adopta el fondo de estudio blanco con `BoxFit.contain` y un chip informativo: `"Prenda aislada (IA)"`.

---

## 3. Estado de la Generación del Avatar Base Neutral

### Estrategia Maniquí de Estudio IA vs. Collage de Respaldo:
1. **Generación Primaria por IA (Maniquí de Estudio Neutral):**
   - `UserBaseImageService` invoca `ai-router` con la acción `generate_base_image`.
   - El gateway utiliza el proveedor visual (Google Imagen 3 / Gemini) con un prompt altamente detallado para un maniquí de e-commerce sobre fondo gris claro neutro, en pose de descanso natural (A-pose) y vistiendo ropa deportiva básica neutra (leggings y camiseta sin mangas oscura ajustada), preservando la fisionomía facial, tono de piel, complexión y proporciones corporales extraídas de las fotos del usuario.
   - Si la síntesis genera una imagen válida (> 50 KB), se guarda en `profiles` con `base_image_content_hash = 'ai_mannequin'`.

2. **Fallback Defensivo (Tablero de Identidad Local):**
   - En caso de fallo transitorio del modelo generativo (500, 502, 504 o respuesta corrupta < 1 KB), se activa automáticamente la composición local del Tablero de Identidad (1024x1024, > 50 KB) estructurado con fotos de rostro y cuerpo.
   - Se registra en `profiles` con `base_image_content_hash = 'collage_fallback'`.

3. **Banner Informativo en el Perfil (`ProfilePage`):**
   - Si se detecta el modo fallback, la pantalla de Perfil muestra un banner amigable y descriptivo:
     - ℹ️ **Modo Collage de Respaldo Activo:** *Se está utilizando el tablero compuesto de fotos como respaldo defensivo. Pulsa "Regenerar" para sintetizar el maniquí neutral con IA.*
   - Si el maniquí IA está activo, se muestra:
     - ✨ **Maniquí de Estudio IA Activo:** *Fondo neutro, fisionomía y complexión preservadas.*

---

## 4. Verificación y Calidad de Código

- **Análisis Estático (`fvm flutter analyze`):** 0 errores, 0 advertencias (`No issues found!`).
- **Pruebas Unitarias y de Integración (`fvm flutter test`):** 26/26 pruebas pasando exitosamente.
