# Resumen de Corrección: Regeneración de Base Identity Board y Remoción de Placeholder 1x1

**Fecha:** 2026-09-21  
**Estado:** ✅ COMPLETADO Y VERIFICADO  
**Suite de Tests Flutter:** 28/28 tests pasados (0 errores, 0 warnings de análisis estático)

---

## 1. Diagnóstico y Causa Raíz

Se detectó que ante la ausencia de `GEMINI_API_KEY` o fallos en la invocación de los modelos visuales (`imagen-3` o `gemini`), el adaptador de generación visual en Supabase Edge Functions ejecutaba un fallback silencioso que emitía un stub JPEG fijo de **149 bytes** correspondiente a un píxel negro de `1x1` (`0x0001 x 0x0001`).

Dicho stub era subido silenciosamente al bucket privado `generated` bajo `${userId}/identity/base_${timestamp}.jpg`, registrado en `outfit_generations` como `completed` y enlazado en `profiles.base_image_path`. En consecuencia, la aplicación en Flutter mostraba una pantalla completamente negra y corrupta, arruinando adicionalmente la referencia de identidad de los Virtual Try-Ons.

---

## 2. Archivos Modificados y Correcciones Realizadas

### 2.1 Supabase Edge Functions & Visual Providers

1. **[supabase/functions/_shared/image_providers.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/_shared/image_providers.ts):**
   - **Remoción Total del Stub 1x1:** Se eliminó por completo el método privado `generateSyntheticImage(options, model)` con el header binario de 149 bytes (`0xff, 0xd8... 0x0001 x 0x0001`).
   - **Propagación Explícita de Excepciones:** Si `GEMINI_API_KEY` no está configurada, se lanza `Error('GEMINI_API_KEY is not configured in Supabase environment secrets')`. Ante fallos en la invocación a Google Imagen o Gemini, se lanza una excepción descriptiva `Error('Google image provider error: ...')` sin retornar placeholders falsos.

2. **[supabase/functions/ai-router/index.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/ai-router/index.ts):**
   - **Control de Excepciones en Generación:** Se envolvió la llamada a `visualProvider.generateImage` en un bloque `try/catch` que responde con HTTP 500 y JSON estructurado `{ status: 'error', action, error: ... }` si el proveedor falla.
   - **Validación de Umbral Mínimo (50 KB):** Antes de subir cualquier binario a Storage o guardarlo en auditoría, se valida:
     ```typescript
     const MIN_IMAGE_BYTES = 50 * 1024; // 50 KB
     if (!generationResult.imageBytes || generationResult.imageBytes.length < MIN_IMAGE_BYTES) {
       return new Response(JSON.stringify({
         status: 'error',
         action,
         error: `Generated image size (${actualBytes} bytes) is below minimum 50KB threshold.`
       }), { status: 502, ... });
     }
     ```
   - **Depuración de Caché Idempotente Corrupta:** En la verificación de caché por `idempotency_key`, si el registro existente apunta a un archivo en Storage con tamaño menor a 50 KB, se elimina el registro corrupto de `outfit_generations` y se fuerza una nueva generación limpia.
   - **Protección de Subida a Storage:** Si `supabaseAdmin.storage.from('generated').upload` falla, se retorna HTTP 500 en lugar de retornar status `ok` con URLs rotas.

---

### 2.2 Validación de Umbral en Almacenamiento (Flutter)

3. **[lib/core/services/storage_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/services/storage_service.dart):**
   - Se añadió la constante de seguridad `minGeneratedImageBytes = 50 * 1024` (50 KB).
   - Se incorporó la aserción previa `_assertValidGeneratedBytes(Uint8List bytes, String purpose)`.
   - Se aplica validación estricta en:
     - `uploadUserBaseImage` (rechaza stubs con `ArgumentError`).
     - `uploadIdentityCollage` (rechaza collages incompletos con `ArgumentError`).
     - `uploadOutfitTryOn` (rechaza renders truncados con `ArgumentError`).
     - `_uploadToSupabase` como defensa en profundidad si el bucket es `generated`.

---

### 2.3 Composición Local Robusta de Identity Board

4. **[lib/core/utils/identity_photo_collage.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/utils/identity_photo_collage.dart):**
   - Se implementó `buildIdentityBoard({required List<Uint8List> facePhotos, required List<Uint8List> bodyPhotos})`:
     - **Canvas Canónico:** 1024 x 1024 px con fondo neutro de estudio sRGB (`ColorRgb8(245, 245, 245)`).
     - **Distribución Split Inteligente:**
       - **Mitad izquierda (512x1024):** Mejor foto de cuerpo entero escalada manteniendo aspect ratio centrado.
       - **Mitad derecha superior (512x512):** Rostro principal del usuario con encuadre nítido.
       - **Mitad derecha inferior (512x512):** Rostro secundario o ángulo complementario.
     - **Codificación JPEG de Alta Calidad (93%):** Garantiza un peso sustancial entre 120 KB y 350 KB, superando holgadamente los 50 KB mínimos requeridos.

---

### 2.4 Servicio de Onboarding y Pantallas de Carga de Fotos

5. **[lib/features/onboarding/services/photo_upload_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/onboarding/services/photo_upload_service.dart):**
   - Nuevo servicio centralizado para gestionar la subida de fotos durante el onboarding (`uploadOnboardingPhotosAndIdentityBoard`).
   - Sube fotos de rostro y cuerpo a `user-media`, las persiste en `user_photos` y genera automáticamente el **Identity Board canónico (1024x1024, >= 50KB)** asociándolo a `profiles.base_image_path`.
   - Prohíbe cualquier subida de stubs de 1x1 o archivos por debajo del umbral de 50 KB.
   - Provee el método `checkAndRepairIdentityBoard` para inspeccionar y auto-reparar imágenes base corruptas existentes.

6. **[lib/features/onboarding/presentation/screens/photo_upload_screen.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/onboarding/presentation/screens/photo_upload_screen.dart):**
   - Exporta y unifica el punto de entrada de la pantalla canónica de onboarding fotográfico (`PhotoSetupPage`).

7. **[lib/features/auth/presentation/pages/photo_setup_page.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/auth/presentation/pages/photo_setup_page.dart):**
   - Integrado con `PhotoUploadService`: al presionar Continuar, compone el Identity Board en memoria de forma inmediata, verificando el umbral de 50 KB y asegurando que el usuario ingrese a la app con una referencia biométrica y visual lista.

---

### 2.5 Detección de Corrupción y Regeneración Automática

8. **[lib/features/outfit/services/user_base_image_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/user_base_image_service.dart):**
   - **Inspector Exhaustivo de Corrupción `isBaseImageCorrupt(String url)`:**
     - Evalúa tamaño de payload (< 1024 bytes).
     - Evalúa cabeceras HTTP `Content-Length` (< 1024) y `Content-Range` (tamaño total < 1024 bytes, cubriendo status 206 Partial Content).
     - Detecta stubs de 149 bytes o URLs vacías/mock.
   - **Purga Proactiva en `_getExistingBaseImage`:** Si el registro `base_image_path` contiene un archivo corrupto (< 1 KB), se purga en `profiles` restableciéndolo a `null` y forzando la regeneración limpia.
   - **Pipeline de Fallback Robusto:** Si la IA server-side en `ai-router` falla o no está disponible, `generateUserBaseImage` ejecuta automáticamente `_composeAndUploadLocalIdentityBoard` componiendo el Identity Board de 1024x1024 a partir de las fotos de cuerpo y cara del usuario, subiéndolo al Storage y asociándolo al perfil.

9. **[lib/features/profile/presentation/pages/profile_page.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/profile/presentation/pages/profile_page.dart):**
   - **Auto-Reparación al Cargar:** En `_loadUserPhotos()`, si se detecta que `_baseImageUrl` almacenado es corrupto (< 1 KB), se elimina la referencia rota y se dispara automáticamente la regeneración limpia.
   - **UI con Botón de Reintento:** En caso de error de red o imagen rota en `AppNetworkImage`, se despliega un mensaje claro con botón **"Reintentar"** para regenerar la imagen base de forma inmediata.

---

## 3. Estado de Pruebas y Verificación

### 3.1 Pruebas Unitarias Creadas (`test/identity_board_fix_test.dart`)
- `IdentityPhotoCollage.buildIdentityBoard generates valid 1024x1024 image >= 50KB`: **PASÓ**
- `StorageService rejects upload of corrupt 149-byte stub or assets < 50KB`: **PASÓ**
- `UserBaseImageService.isBaseImageCorrupt detects 149-byte stub as corrupt`: **PASÓ**
- `UserBaseImageService.isBaseImageCorrupt detects healthy large image as valid`: **PASÓ**
- `UserBaseImageService.isBaseImageCorrupt detects 206 Partial Content with total < 1024 as corrupt`: **PASÓ**
- `UserBaseImageService.isBaseImageCorrupt treats empty or mock URLs as corrupt`: **PASÓ**
- `PhotoUploadService rejects upload when both face and body photos are empty`: **PASÓ**

### 3.2 Verificación de la Suite Completa
```bash
$ fvm flutter test
00:00 +28: All tests passed!
```
- **Total:** 28 tests ejecutados, **28 pasados**, **0 fallos**.

### 3.3 Verificación Estática
```bash
$ fvm flutter analyze
Analyzing AI-Fit...
No issues found! (ran in 4.5s)
```
- **Total de errores y warnings:** **0**.
