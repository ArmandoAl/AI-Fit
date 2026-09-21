# Resumen Paso 0.2: Instrumentación del Baseline de IA

## 1. Acciones Realizadas
- **Creación de Utilidad de Telemetría Ligera y Segura (`lib/core/utils/ai_telemetry_logger.dart`):**
  - Se implementó `AiTelemetryLogger` para estructurar y emitir eventos operativos de IA.
  - **Política de Privacidad Estricta:** No registra datos sensibles (se omiten URLs firmadas, prompts confidenciales de usuario, imágenes base64 y bytes). Únicamente captura metadatos operativos: operación, modelo, conteo de imágenes de entrada, tamaño total en bytes (`input_bytes_total`), latencia en ms (`latency_ms`), tokens (`input_tokens`, `output_tokens` vía `usageMetadata`), estado (`success`, `failed`, `cache_hit`) y código de error si ocurre una excepción.
  - Emite logs estructurados mediante `dart:developer.log` (bajo el nombre `AI_TELEMETRY`) y un formato clave-valor conciso en consola (`debugPrint`) para rápida inspección en desarrollo.
- **Instrumentación en Servicios Clave:**
  - `lib/core/services/firebase_ai_service_impl.dart`: Medición de latencia, bytes procesados y tokens en `analyzeImageToJson` (operaciones `analyze_garment` y `analyze_identity`) y `generateContent` (`generate_content`).
  - `lib/features/outfit/services/outfit_generator_service.dart`: Medición en `generateOutfits` de la llamada multimodal a Gemini 2.5 Flash, registrando el conteo exacto de prendas enviadas (hasta 12), bytes totales de imágenes, latencia y tokens.
  - `lib/features/outfit/services/virtual_try_on_service.dart`: Medición en `generateTryOnImage` para el modelo `gemini-2.5-flash-image`, registrando la suma de bytes de entrada (imagen base, rostro y prendas) y tiempo de respuesta.
  - `lib/features/outfit/services/user_base_image_service.dart`: Medición de generación de imagen base (`generate_base_image`) y registro de `cache_hit` cuando la imagen base ya existe previamente en Firestore.
- **Manejo Seguro de Excepciones:**
  - Todas las intercepciones capturan fallas registrando el evento con `status: 'failed'` y relanzan (`rethrow` / propagación de excepción) para no alterar el flujo de negocio ni silenciar errores.

---

## 2. Bloques de Código Clave

### Utilidad de Telemetría (`lib/core/utils/ai_telemetry_logger.dart`)
```dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight structured telemetry logger for AI operations.
///
/// Strictly enforces privacy: no prompts, raw images, signed URLs or user identifiers are logged.
class AiTelemetryLogger {
  AiTelemetryLogger._();

  /// Logs a structured AI telemetry event.
  static void logEvent({
    required String operation,
    String? model,
    int inputCount = 0,
    int inputBytesTotal = 0,
    required int latencyMs,
    int? inputTokens,
    int? outputTokens,
    required String status,
    String? errorCode,
    Map<String, dynamic>? extraMetadata,
  }) {
    final payload = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'operation': operation,
      if (model != null) 'model': model,
      'input_count': inputCount,
      'input_bytes_total': inputBytesTotal,
      'latency_ms': latencyMs,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      'status': status,
      if (errorCode != null) 'error_code': errorCode,
      if (extraMetadata != null) ...extraMetadata,
    };

    final jsonStr = jsonEncode(payload);

    if (kDebugMode) {
      developer.log(
        jsonStr,
        name: 'AI_TELEMETRY',
        level: status == 'failed' ? 1000 : 800,
      );

      final kbs = (inputBytesTotal / 1024).toStringAsFixed(1);
      final tokensInfo = (inputTokens != null || outputTokens != null)
          ? ' | tokens: in=${inputTokens ?? 0}, out=${outputTokens ?? 0}'
          : '';
      final errorInfo = errorCode != null ? ' | error: $errorCode' : '';
      debugPrint(
        '📊 [AI_TELEMETRY] op=$operation | model=${model ?? "n/a"} | status=$status '
        '| latency=${latencyMs}ms | inputs=$inputCount (${kbs}KB)$tokensInfo$errorInfo',
      );
    }
  }
}
```

### Instrumentación en `OutfitGeneratorService` (`lib/features/outfit/services/outfit_generator_service.dart`)
```dart
      debugPrint('🤖 Calling Gemini 2.5 Flash to generate outfits...');
      stopwatch.start();
      final response = await model.generateContent(content);
      stopwatch.stop();

      AiTelemetryLogger.logEvent(
        operation: 'generate_outfits',
        model: 'gemini-2.5-flash',
        inputCount: imageCount,
        inputBytesTotal: totalImageBytes,
        latencyMs: stopwatch.elapsedMilliseconds,
        inputTokens: response.usageMetadata?.promptTokenCount,
        outputTokens: response.usageMetadata?.candidatesTokenCount,
        status: 'success',
      );
```

### Instrumentación en `VirtualTryOnService` (`lib/features/outfit/services/virtual_try_on_service.dart`)
```dart
      stopwatch.start();
      final response = await model.generateContent([Content.multi(parts)]);
      stopwatch.stop();

      AiTelemetryLogger.logEvent(
        operation: 'try_on',
        model: 'gemini-2.5-flash-image',
        inputCount: imageCount,
        inputBytesTotal: totalImageBytes,
        latencyMs: stopwatch.elapsedMilliseconds,
        inputTokens: response.usageMetadata?.promptTokenCount,
        outputTokens: response.usageMetadata?.candidatesTokenCount,
        status: 'success',
      );
```

---

## 3. Formato del Payload de Métricas

### Log Estructurado JSON (`dart:developer.log`, name: `AI_TELEMETRY`)
```json
{
  "timestamp": "2026-09-20T04:00:15.123Z",
  "operation": "generate_outfits",
  "model": "gemini-2.5-flash",
  "input_count": 8,
  "input_bytes_total": 425120,
  "latency_ms": 1842,
  "input_tokens": 2150,
  "output_tokens": 480,
  "status": "success"
}
```

### Línea de Consola para Debug (`debugPrint`)
```text
📊 [AI_TELEMETRY] op=generate_outfits | model=gemini-2.5-flash | status=success | latency=1842ms | inputs=8 (415.2KB) | tokens: in=2150, out=480
📊 [AI_TELEMETRY] op=try_on | model=gemini-2.5-flash-image | status=success | latency=3120ms | inputs=4 (620.5KB) | tokens: in=1040, out=0
📊 [AI_TELEMETRY] op=generate_base_image | status=cache_hit | latency=45ms | inputs=0 (0.0KB)
```

---

## 4. Estado de la Compilación

Se ejecutó la verificación con FVM:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...
No issues found! (ran in 2.7s)
```

---

## 5. Requerimientos de Acción Humana (Instrucciones para Probar)

Para validar el registro de métricas en tu entorno local:

1. **Iniciar la aplicación:**
   ```bash
   fvm flutter run
   ```
2. **Realizar una prueba de análisis de prenda:**
   - Ve a la sección de Guardarropa / Añadir Prenda.
   - Sube una prenda para análisis.
   - Verifica en la consola la línea: `📊 [AI_TELEMETRY] op=analyze_garment | model=gemini-2.5-flash ...`
3. **Realizar una prueba de generación de outfits:**
   - Dirígete al Generador de Outfits y solicita una recomendación.
   - Verifica en la consola: `📊 [AI_TELEMETRY] op=generate_outfits | model=gemini-2.5-flash | inputs=...`
4. **Verificar Try-On Virtual:**
   - Solicita la vista previa virtual de un outfit generado.
   - Verifica en consola: `📊 [AI_TELEMETRY] op=try_on | model=gemini-2.5-flash-image ...`
