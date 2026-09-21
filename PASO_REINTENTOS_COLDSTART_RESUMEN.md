# Resumen: Resiliencia ante Cold Start y Retry Automático en Gateway

## 1. Arquitectura del Mecanismo de Retry en Flutter

Para garantizar la alta disponibilidad y mitigar fallos transitorios provocados por **cold starts** o suspensión por inactividad de instancias serverless (Supabase Edge Functions y Cloud Run con FastAPI/rembg), se implementó un interceptor de resiliencia centralizado en [`DeepSeekService`](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/services/deepseek_service.dart).

### Componentes Clave:
1. **Punto Único de Invocación (`invokeGateway`):**
   - Todas las llamadas de IA del sistema (chat, análisis de intención, composición de outfits, try-on visual y generación de imagen base de identidad) convergen a través de `invokeGateway`.
   - `generateTryOn` y `generateBaseImage` fueron unificados para delegar directamente en `invokeGateway`, heredando la protección sin duplicación de código.
2. **Detección Rigurosa de Errores Transitorios (`isTransientError` / `isTransientStatusCode`):**
   - **Códigos HTTP:** `502 Bad Gateway`, `503 Service Unavailable`, `504 Gateway Timeout`.
   - **Excepciones de Red y Timeout:** `TimeoutException`, `SocketException`, `HttpException`, `FunctionException` de Supabase con códigos 502/503/504.
   - Errores de cliente (como `400 Bad Request` o `401 Unauthorized`) no son reintentados para evitar carga innecesaria en el servidor.
3. **Resolución Transparente:**
   - Si la invocación tiene éxito en cualquiera de los intentos (intento 1, 2 o 3), el resultado se desempaqueta y retorna directamente a la UI sin emitir alertas de error falsas ni interrumpir la experiencia de usuario.

---

## 2. Configuración de Tiempos de Timeout y Retroceso Exponencial

| Parámetro | Valor | Justificación Técnica |
| :--- | :--- | :--- |
| **Timeout Base** | **45 segundos** | Concede margen suficiente para que el contenedor de Cloud Run despierte, cargue los modelos CLIP/U2-Net en memoria y responda a la Edge Function. |
| **Intentos Máximos** | **3 intentos** | 1 intento inicial + hasta 2 reintentos progresivos. |
| **Fórmula de Backoff** | `delay = 1.5 * pow(2, intento)` | Retroceso exponencial progresivo: <br>• Intento 0 a 1: **1.5s** (1,500 ms)<br>• Intento 1 a 2: **3.0s** (3,000 ms) |
| **Inyección para Testing** | `customDelay` y `customInvoker` | Permite pruebas unitarias instantáneas y deterministas sin retardos artificiales ni acoplamiento a red externa. |

---

## 3. Feedback Visual Amigable en UI durante Tiempos Prolongados

Se implementó el componente reutilizable [`ColdStartProgressIndicator`](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/widgets/cold_start_loader.dart) e integró tanto en [`SmartWardrobeScreen`](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/presentation/screens/smart_wardrobe_screen.dart) como en [`GenerateOutfitPage`](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/presentation/pages/generate_outfit_page.dart) y [`StylistOutfitPreviewCard`](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/stylist/presentation/widgets/stylist_outfit_preview_card.dart) con diseño **Dark Glam / Y2K Cyber-Goth**:

- **0s - 3.5s:**
  - *"Diseñando tu look Cyber-Goth..."* / *"Generando vista try-on…"* con spinner animado de menta eléctrica (`AppColors.neonMint`).
- **> 3.5s (Detección de Cold Start):**
  - El mensaje transmuta suavemente a:
  - *"Despertando al vestidor inteligente... ✨"*
- **> 7.0s (Carga prolongada de modelos de inferencia):**
  - El mensaje pasa a:
  - *"Preparando los percheros virtuales... 🦇"*
- **Limpieza de Recursos:**
  - Los `Timer` asociados se cancelan de manera segura en el bloque `finally` de la llamada o en el método `dispose()` de los widgets correspondientes.

---

## 4. Resultados de Verificación Estática y Pruebas

### 4.1. Análisis Estático (`fvm flutter analyze`)
```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 5.0s)
```
**Resultado:** **0 errores, 0 advertencias**.

### 4.2. Suite de Pruebas Unitarias (`fvm flutter test`)
```bash
$ fvm flutter test
00:00 +0: loading /Users/armandoalvarado/Documents/AI-Fit/test/smoke_test.dart
...
00:00 +13: Supabase Cutover Smoke Tests DeepSeekService retries on transient errors (503 / Timeout) and succeeds transparently with exponential backoff
🌐 [DeepSeekService] Invoking ai-router (attempt 1/3)...
⚠️ [DeepSeekService] Transient error (Cold start/Network) on attempt 1: _TransientGatewayException(status: 503, message: ai-router returned HTTP 503: {error: Service Unavailable - Cold start}). Retrying in 1.5s...
🌐 [DeepSeekService] Invoking ai-router (attempt 2/3)...
⚠️ [DeepSeekService] Transient error (Cold start/Network) on attempt 2: TimeoutException: Gateway timeout while waking up function. Retrying in 3.0s...
🌐 [DeepSeekService] Invoking ai-router (attempt 3/3)...
00:00 +14: Supabase Cutover Smoke Tests DeepSeekService does not retry on non-transient errors (400 Bad Request)
00:00 +15: Supabase Cutover Smoke Tests DeepSeekService exhausts retries after 3 failed attempts on continuous 504 Gateway Timeout
00:00 +16: Supabase Cutover Smoke Tests DeepSeekService transient status code helper validates 502, 503, 504
00:00 +17: Supabase Cutover Smoke Tests ColdStartProgressIndicator updates loading message past 3.5s during cold start
00:00 +18: All tests passed!
```
**Resultado:** **18 pruebas ejecutadas, 18 exitosas (100% passing)**.

### 4.3. Verificación de Microservicios Backend (`services/image-worker`)
```bash
$ python3 -m unittest discover -s services/image-worker
......
----------------------------------------------------------------------
Ran 6 tests in 0.061s

OK
```
**Resultado:** **6 pruebas de composición y recorte pasando limpiamente**.
