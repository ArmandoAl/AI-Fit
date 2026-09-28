# INFORME DE AUDITORÍA FORENSE — Pipeline Wardrobe → Try-On → Identidad

**Alcance:** Solo lectura/análisis. Ningún archivo de código fue modificado.
**Fecha:** 2026-09-21

---

## 1. Diagrama: Flujo Diseñado vs. Flujo Real

### 1.1 Flujo diseñado (según docs `PASO_*_RESUMEN.md` y comentarios en código)

```
Flutter (Wardrobe) --guardar--> Supabase Storage (user-media)
        |
        v
  wardrobe_items (INSERT, processing_status='processing')
        |
        v
  ai-router:process_wardrobe_item --> image-worker:/process-garment
        |                                   |
        |                                   v
        |                          rembg (cutout) + CLIP 512-d embedding
        |                                   |
        v                                   v
  wardrobe_items.cutout_path <----- UPDATE (cutout_path, embedding, status='ready')
        |
        v
  Flutter (Generar Outfit) --candidates--> ai-router:compose_outfits (DeepSeek, solo texto/IDs)
        |
        v
  outfit_items(outfit_id, wardrobe_item_id, role)   <-- relación ID persistida
        |
        v
  Flutter (Try-On) --identityImageUrl + garmentFlatlayUrl(bytes reales)--> ai-router:generate_tryon
        |
        v
  image_providers.ts --IMAGE-TO-IMAGE (identidad + flat-lay como inlineData)--> Gemini multimodal
        |
        v
  Imagen final con rostro/cuerpo real + prendas reales renderizada y subida a bucket 'generated'
        |
        v
  UI muestra look con foto real del usuario + chips/thumbnails de las prendas reales usadas
```

### 1.2 Flujo real (lo que efectivamente ejecuta el código hoy)

```
Flutter (Wardrobe) --guardar--> Supabase Storage (user-media)  ✅ OK
        |
        v
  wardrobe_items (INSERT, processing_status='processing')      ✅ OK
        |
        v
  ai-router:process_wardrobe_item --> image-worker:/process-garment
        |                                   |
        |                                   v
        |                    ❌ NameError: 'base64'/'urllib' no importados
        |                       (main.py líneas 566/575-576/596)
        |                       -> processing_status='failed' (HTTP 500)
        v
  wardrobe_items.cutout_path = NULL, embedding = NULL  (persiste "sin fondo IA")
  Flutter no muestra error (catch silencioso en background) --> usuario ni se entera
        |
        v
  Flutter (Generar Outfit) --candidates--> ai-router:compose_outfits   ✅ OK (solo IDs/texto)
        |
        v
  outfit_items(outfit_id, wardrobe_item_id, role)   ✅ Relación SÍ se persiste correctamente
        |
        v
  Flutter (Try-On) --identityImageUrl + garmentFlatlayUrl--> ai-router:generate_tryon  ✅ payload OK
        |
        v
  image_providers.ts: modelo por defecto 'imagen-3.0-generate-001' empieza con 'imagen-3'
        |
        v
  ❌ generateWithImagen() SOLO envía { instances: [{ prompt: texto }] } al endpoint :predict
     -> identityImageUrl y garmentFlatlayUrl se descartan por completo, JAMÁS se leen sus bytes
        |
        v
  Imagen 3 (texto-a-imagen) genera una persona/outfit "genérico" inventado, sin relación
  con la cara/cuerpo real ni con las prendas reales del clóset
        |
        v
  (el camino image-to-image real, generateWithGemini, con fetch() real de las 2 imágenes,
   solo se ejecuta si Imagen 3 LANZA EXCEPCIÓN — no ocurre en el camino feliz)
        |
        v
  UI (generate_outfit_page.dart:340-359): aunque outfit.itemIds SÍ contiene los UUIDs reales,
  se renderizan como Chip(texto=uuid.substring(0,8)) -- ningún fetch a wardrobe_items,
  ningún cutout_path, ninguna miniatura. saved_outfits_page.dart ni siquiera itera itemIds.
        |
        v
  Resultado: usuario ve un look con cara genérica + ropa inventada + lista de "códigos"
  en vez de las fotos de sus prendas reales.
```

---

## 2. Los 3 Cuellos de Botella Exactos

### 🔴 Bottleneck #1 — El try-on real nunca usa las fotos del usuario ni de las prendas

**Archivo:** `supabase/functions/_shared/image_providers.ts`
**Líneas:** 19, 29-42 (selección de modelo) y 44-87 (`generateWithImagen`)

```ts
private readonly defaultModel = 'imagen-3.0-generate-001';   // línea 19
...
if (model.startsWith('imagen-3')) {                           // línea 29 — TRUE por defecto
  try {
    return await this.generateWithImagen(options, apiKey, model);  // línea 31
  } catch (imagenErr) { ... return await this.generateWithGemini(...) }  // fallback SOLO si lanza excepción
```

Dentro de `generateWithImagen` (líneas 44-87), la petición HTTP al endpoint `:predict` de Imagen 3 es:

```ts
body: JSON.stringify({
  instances: [{ prompt: imagenPrompt }],     // línea 61 — SOLO TEXTO
  parameters: { sampleCount: 1, aspectRatio: '3:4', personGeneration: 'ALLOW_ADULT' },
}),
```

`options.identityImageUrl` y `options.garmentFlatlayUrl` **nunca se leen** en esta función. El único código que de verdad hace `fetch()` de esas URLs y las adjunta como `inlineData` (base64) al payload multimodal está en `generateWithGemini` (líneas 89-271, especialmente 99-147), pero esa función **solo se invoca si Imagen 3 lanza una excepción** (línea 32). Como el endpoint `imagen-3.0-generate-001:predict` normalmente responde 200 OK (es un modelo texto-a-imagen válido y funcional, solo que sin soporte de condicionamiento por imagen en este payload), la ruta "feliz" jamás cae al fallback con imágenes reales. En consecuencia, **el 100% de las generaciones de try-on en el camino normal ignoran la identidad real del usuario y las prendas reales**, y solo describen la escena por texto.

### 🔴 Bottleneck #2 — El pipeline de ingesta de prendas (rembg + CLIP) falla siempre con `NameError`

**Archivo:** `services/image-worker/main.py`
**Líneas de uso:** 566, 575-576, 596 — **líneas de import faltantes:** 1-18 (no existen)

```python
# Imports actuales (líneas 1-18): NO incluyen `base64` ni `urllib.request`
import hashlib, io, logging, os, re
from typing import Dict, List, Optional
import uuid
import numpy as np
...
```
```python
# línea 566
image_bytes = base64.b64decode(b64_clean)          # NameError: name 'base64' is not defined
...
# línea 575-576
req = urllib.request.Request(clean_path, ...)       # NameError: name 'urllib' is not defined
with urllib.request.urlopen(req, timeout=30) as resp:
...
# línea 596
cutout_b64 = base64.b64encode(webp_bytes).decode("ascii")   # NameError también aquí
```

Cualquier llamada real (no cache-hit) a `/process-item` o `/process-garment` entra al bloque `try` de la línea 561 y revienta con `NameError` en la primera rama que ejecute (imagen por base64 o por URL). La excepción es capturada por el `except Exception as err` genérico (línea 646), que marca `processing_status = 'failed'` y responde HTTP 500. Del lado de Flutor, `wardrobe_repository_impl.dart:_triggerBackgroundProcessing` (líneas 192-234) atrapa ese error con un `catch` que solo hace `debugPrint` (línea 230-233) — **no hay ningún indicador visual para el usuario**. Esto explica exactamente el síntoma reportado: `wardrobe_items.embedding` queda `NULL`, `cutout_path` nunca se llena, y todo ocurre "silenciosamente" desde la perspectiva de la UI.

### 🔴 Bottleneck #3 — Las prendas reales del outfit no se renderizan en la UI (aunque el dato SÍ existe)

**Archivo:** `lib/features/outfit/presentation/pages/generate_outfit_page.dart`
**Líneas:** 340-359

```dart
if (outfit.itemIds.isNotEmpty) ...[
  const Text('Prendas:', ...),
  Wrap(
    spacing: 8,
    children: outfit.itemIds.map((itemId) {
      return Chip(
        label: Text(itemId.substring(0, 8), ...),   // línea 351 — solo el UUID truncado
        backgroundColor: Colors.grey[200],
      );
    }).toList(),
  ),
],
```

**Contrario a la hipótesis inicial de la auditoría**, la relación `outfits` ↔ `wardrobe_items` **sí se persiste correctamente** vía la tabla `outfit_items` (`role`, `wardrobe_item_id`) — ver `saved_outfits_repository.dart:74-104` (escritura) y `:186-211` (lectura en `getSavedOutfits`). El problema no es de datos sino de **renderizado**: nunca se hace un `select` a `wardrobe_items` para resolver esos IDs a `name` + `cutout_path`; solo se imprime el UUID crudo como texto. Además, `saved_outfits_page.dart` (la vista del lookbook guardado) ni siquiera itera `outfit.itemIds` — solo muestra `outfit.tryOnImageUrl`.

*Hallazgo secundario relacionado:* `saved_outfits_repository.dart:getOutfitById` (líneas 322-335) reconstruye `GeneratedOutfit` leyendo solo los roles `top/bottom/shoes/outerwear` desde `outfit_items`, **omitiendo `one_piece` y `accessory`** (a diferencia de `getSavedOutfits`, líneas 194-211, que sí los maneja). Esto rompe la vista de detalle individual para vestidos/monos y outfits con accesorios.

---

## 3. Propuesta de Arquitectura Técnica (sin disparar costos de API adicionales)

Los 3 fixes reutilizan infraestructura ya existente en el repo — no se necesita agregar proveedores nuevos ni llamadas nuevas, solo corregir el ruteo/orden y completar imports/queries que ya deberían existir.

### 3.1 Fix Bottleneck #1 — invertir la prioridad cuando hay imágenes reales
En `image_providers.ts`, antes de decidir Imagen-3-solo-texto, verificar si `options.identityImageUrl` o `options.garmentFlatlayUrl` están presentes:
- Si SÍ hay imágenes de referencia (caso normal de `generate_tryon`) → llamar directamente a `generateWithGemini` (que ya implementa correctamente el fetch + inlineData + prompt de preservación de identidad, líneas 89-271). Este camino **ya está pagado y probado**, solo nunca se ejecuta en el camino feliz.
- Si NO hay imágenes de referencia (p. ej. `generate_base_image` inicial sin fotos aún) → usar Imagen 3 texto-a-imagen como hoy.
Esto no agrega costo: es el mismo modelo (`gemini-2.5-flash-image` / fallback chain ya configurada), solo reordenado por prioridad según disponibilidad de imagen real.

### 3.2 Fix Bottleneck #2 — imports faltantes
Agregar en las primeras líneas de `services/image-worker/main.py`:
```python
import base64
import urllib.request
```
Diff de una línea, desbloquea el 100% del pipeline rembg + CLIP que ya está correctamente diseñado (idempotencia, UUID validation, upload a `user-media`, update de `wardrobe_items` — todo ese código es correcto, solo nunca se alcanza a ejecutar sin este import).

### 3.3 Fix Bottleneck #3 — resolver IDs a miniaturas reales
En `generate_outfit_page.dart` (y añadir el equivalente en `saved_outfits_page.dart`), reemplazar el `Chip` de texto por un `FutureBuilder`/query batch única:
```dart
final rows = await supabase.from('wardrobe_items')
    .select('id, name, cutout_path, image_url')
    .inFilter('id', outfit.itemIds);
```
y renderizar con el mismo patrón visual ya usado en `WardrobeItemCard` (fondo blanco + `cutout_path` con `BoxFit.contain`, definido en `PASO_WARDROBE_PIPELINE_RESUMEN.md` §2). Una sola consulta por outfit (no N+1). De paso, corregir `getOutfitById` para incluir `one_piece`/`accessory` igual que `getSavedOutfits`.

---

## Resumen ejecutivo

Los tres defectos son independientes y cada uno por sí solo ya explica la desconexión reportada; juntos explican el 100% del síntoma "cara genérica + ropa inventada + sin lista de prendas reales":

| # | Bottleneck | Archivo:línea | Efecto |
|---|---|---|---|
| 1 | Try-on solo usa texto, ignora fotos reales | `image_providers.ts:29-87` | Imagen/cuerpo/ropa generados son "alucinados" |
| 2 | Ingesta de prendas crashea siempre | `services/image-worker/main.py:566,575-576,596` (imports faltantes) | `embedding`/`cutout_path` quedan NULL |
| 3 | UI no resuelve IDs de prendas a fotos | `generate_outfit_page.dart:340-359` | Prendas reales no se muestran aunque el dato existe |

Ningún fix requiere nueva infraestructura, nuevo proveedor de IA ni presupuesto adicional — son correcciones de ruteo/imports/rendering sobre código y arquitectura ya existentes.
