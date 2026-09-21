# Resumen Paso 2.4: Abstracción del Proveedor Visual

## 1. Acciones Realizadas

Se desacopló por completo la generación y renderizado visual del cliente móvil, resolviendo la **obsolescencia programada de `gemini-2.5-flash-image`** (cuyo retiro definitivo está programado para el 2 de octubre de 2026) y centralizando el procesamiento visual en la Edge Function server-side `ai-router` con un adaptador multi-proveedor.

### Detalle de Mejoras Arquitecturales

1. **Mitigación de Depreciación y Obsolescencia:**
   - La llamada directa a `gemini-2.5-flash-image` en el cliente Flutter ha sido sustituida por un backend visual agnóstico en Supabase Edge Functions.
   - El backend utiliza por defecto modelos modernos y estables como **Google Imagen 3** (`imagen-3.0-generate-002`) o endpoints multimodales actualizados, configurables mediante variables de entorno en Supabase sin necesidad de recompilar la app móvil.

2. **Adaptador de Proveedores Visuales (`_shared/image_providers.ts`):**
   - Se diseñó una interfaz agnóstica `ImageProvider` implementada por:
     - **`GoogleImageProvider`:** Soporta Google Imagen 3 y Gemini API moderna con soporte de aspect ratio 3:4 e inyección de imagen de identidad de referencia.
     - **`FalAiImageProvider`:** Esqueleto compatible para conmutar a modelos de difusión de alta fidelidad (ej. Flux Realism en Fal.ai).
     - **`ReplicateImageProvider`:** Esqueleto compatible para conmutar a SDXL Lightning o modelos open-source en Replicate.
     - **Mecanismo de Resiliencia / Sandbox:** Incluye un generador sintético JPEG para entornos de prueba y desarrollo local cuando no hay credenciales activas.

3. **Almacenamiento Aislado y Control de Acceso (Storage RLS):**
   - Las imágenes generadas se guardan de forma aislada en el bucket privado `generated` de Supabase Storage bajo:
     - Try-on: `${userId}/tryons/${outfitId}_${timestamp}.jpg`
     - Imagen Base: `${userId}/identity/base_${timestamp}.jpg`
   - La Edge Function emite URLs firmadas (Signed URLs con 7 días de validez) o delega la ruta protegida respetando las políticas RLS.

4. **Refactorización de Servicios en Flutter:**
   - [lib/features/outfit/services/virtual_try_on_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/virtual_try_on_service.dart) y [lib/features/outfit/services/user_base_image_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/user_base_image_service.dart) ahora dirigen preferentemente las peticiones hacia el gateway server-side `ai-router` (`action: 'generate_tryon'` y `action: 'generate_base_image'`).
   - Se conserva la implementación anterior de Vertex AI / Firebase AI únicamente como fallback temporal de rescate si el gateway está inactivo.

---

## 2. Bloques de Código Clave

### A. Adaptador Multi-Proveedor (`_shared/image_providers.ts`)
```typescript
export interface ImageProvider {
  name: string;
  generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult>;
}

export class GoogleImageProvider implements ImageProvider {
  public readonly name = 'google';
  private readonly defaultModel = 'imagen-3.0-generate-002';

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    const apiKey = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GOOGLE_API_KEY');
    const model = Deno.env.get('IMAGE_MODEL') || this.defaultModel;

    if (model.startsWith('imagen-3')) {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict?key=${apiKey}`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          instances: [{ prompt: options.prompt }],
          parameters: { sampleCount: 1, aspectRatio: '3:4', personGeneration: 'ALLOW_ADULT' },
        }),
      });
      // ... decodificación base64 y retorno de bytes binarios
    }
  }
}
```

### B. Invocación desde `VirtualTryOnService.dart`
```dart
// Enrutamiento preferente server-side al Gateway ai-router
if (AppSupabaseClient.isInitialized && AppSupabaseClient.client != null) {
  try {
    final baseImageUrl = await _baseImageService.getUserBaseImageUrl(userId);
    final effectiveIdentityUrl = baseImageUrl ?? request.userBodyPhotoUrl ?? '';

    final prompt = IdentityConsistencyPrompt.buildTryOnPrompt(
      profile: request.identityProfile,
      hasBaseImage: baseImageUrl != null,
      hasFaceAnchor: request.userFacePhotoUrl != null,
      garmentCount: request.itemImageUrls.length,
    );

    final idempotencyKey = 'tryon_${userId}_${request.outfit.id}';

    final res = await _gateway.generateTryOn(
      identityImageUrl: effectiveIdentityUrl,
      garmentImageUrls: request.itemImageUrls,
      prompt: prompt,
      outfitId: request.outfit.id,
      idempotencyKey: idempotencyKey,
    );

    final imageUrl = res['imageUrl']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return VirtualTryOnResult(
        outfitId: request.outfit.id,
        generatedImageUrl: imageUrl,
        generatedAt: DateTime.now(),
      );
    }
  } catch (e) {
    debugPrint('⚠️ Server-side try-on failed ($e). Falling back to legacy client AI...');
  }
}
```

---

## 3. Estado de la Compilación

Ejecución de `fvm flutter analyze`:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 2.8s)
```

**Resultado:** 0 errores y 0 advertencias en todo el workspace.

---

## 4. Requerimientos de Acción Humana (Configuración de Secrets y Despliegue)

### A. Variables de Entorno en Supabase

Configura las variables requeridas en el vault de Supabase Secrets:
```bash
# 1. Clave de Google / Gemini / Imagen para generación visual
supabase secrets set GEMINI_API_KEY="tu_gemini_api_key_aqui"

# 2. (Opcional) Proveedor y modelo visual preferido
supabase secrets set IMAGE_PROVIDER="google"
supabase secrets set IMAGE_MODEL="imagen-3.0-generate-002"

# 3. (Opcional - Si utilizas proveedores alternativos)
# supabase secrets set FAL_KEY="tu_fal_key"
# supabase secrets set REPLICATE_API_TOKEN="tu_replicate_token"
```
*(También configurables desde el dashboard web de Supabase en **Settings** ➔ **Edge Functions** ➔ **Secrets**).*

---

### B. Desplegar la Edge Function Actualizada

Despliega los cambios de `ai-router` con los nuevos manejadores visuales:
```bash
supabase functions deploy ai-router
```

---

### C. Procedimiento para Probar Try-On e Imagen Base

#### 1. Prueba de Generación de Imagen Base
1. Inicia sesión en la aplicación móvil con un usuario con fotos de identidad cargadas.
2. Ingresa a la pantalla de **Perfil de Identidad**.
3. Si el usuario no tiene imagen base, pulsa en *"Generar Imagen Base"*.
4. **Verificación en Logs:**
   ```
   🌐 [UserBaseImageService] Routing base image generation to server-side ai-router...
   ✅ [UserBaseImageService] Server-side base image created: https://<project>.supabase.co/storage/v1/object/sign/generated/...
   ```

#### 2. Prueba de Virtual Try-On
1. Ve a la pantalla de **Generación de Outfits** y genera 3 propuestas.
2. Selecciona uno de los outfits y pulsa en *"Ver cómo me queda"* (Probarse look).
3. **Verificación en Logs:**
   ```
   🌐 [VirtualTryOnService] Routing try-on to server-side ai-router for outfit: outfit_1
   ✅ [VirtualTryOnService] Server-side try-on successful: https://<project>.supabase.co/storage/v1/object/sign/generated/...
   ```
4. Comprueba en la tabla `public.outfit_generations` de Supabase que la transacción quede registrada con `image_provider: 'google-imagen'` y su respectiva latencia y costo.
