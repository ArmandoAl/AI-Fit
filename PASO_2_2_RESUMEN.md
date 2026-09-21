# Resumen Paso 2.2: Unificación de Chat e Intención en ai-router

## 1. Acciones Realizadas

Se completó la migración y unificación del razonamiento de IA en la aplicación móvil/Flutter, desacoplando completamente el cliente de endpoints externos y enrutando todo el tráfico de chat y análisis de intención a través de la Edge Function server-side `ai-router`.

### Detalle de Modificaciones por Componente

1. **[lib/core/services/deepseek_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/services/deepseek_service.dart):**
   - Se eliminaron las llamadas directas HTTP con Dio hacia `https://api.deepseek.com`.
   - Se refactorizó como el cliente unificado del Gateway Server-Side utilizando `AppSupabaseClient.client!.functions.invoke('ai-router', body: ...)`.
   - Soporta timeout controlado (15 segundos por defecto), tipado estricto, manejo de respuestas JSON estructuradas (`jsonData` o `content`), e inyección de `idempotencyKey`.

2. **[lib/features/outfit/services/outfit_intent_analyzer.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/outfit_intent_analyzer.dart):**
   - El analizador de intención ahora consume `DeepSeekService` contra el gateway `ai-router`.
   - Implementa una arquitectura resiliente con **3 capas de defensa**:
     - **Capa 1 (Primaria):** Inferencia en DeepSeek vía Gateway Server-Side (`ai-router`).
     - **Capa 2 (Fallback Remoto):** Gemini 2.5 Flash (`FirebaseAI.vertexAI()`) si el gateway no responde o arroja error.
     - **Capa 3 (Fallback Local):** Analizador heurístico determinista (`_localFallbackAnalysis`) para garantizar que la UI nunca sufra bloqueos ni errores fatales si no hay conexión a internet o servicios de IA.

3. **[lib/features/stylist/services/stylist_chat_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/stylist/services/stylist_chat_service.dart):**
   - Se eliminó por completo la dependencia con OpenAI (`https://api.openai.com`), la clave `openAiApiKey` y la dependencia de Dio.
   - El chat conversacional del estilista ahora invoca `DeepSeekService.chatJson(...)` hacia el gateway server-side con el prompt del sistema y el historial de conversación en formato JSON estructurado.
   - Si ocurre una desconexión o fallo de red, retorna un turno de fallback conversacional en español preservando el estado acumulado de `StylistIntentState`.

4. **Eliminación Total de Consumo de Claves en Cliente:**
   - Ningún archivo en `lib/` importa ni consume claves en texto plano de OpenAI o DeepSeek.

---

## 2. Bloques de Código Clave

### A. Invocación al Gateway Server-Side (`lib/core/services/deepseek_service.dart`)
```dart
Future<Map<String, dynamic>> invokeGateway(
  Map<String, dynamic> payload, {
  String? idempotencyKey,
}) async {
  final client = AppSupabaseClient.client;
  if (client == null || !AppSupabaseClient.isInitialized) {
    throw Exception(
      'AppSupabaseClient is not initialized or configured. Server-side AI gateway unavailable.',
    );
  }

  final body = Map<String, dynamic>.from(payload);
  if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
    body['idempotencyKey'] = idempotencyKey;
  }

  final response = await client.functions
      .invoke('ai-router', body: body)
      .timeout(
    timeout,
    onTimeout: () {
      throw TimeoutException(
        'ai-router gateway request timed out after ${timeout.inSeconds} seconds.',
      );
    },
  );

  if (response.status != 200) {
    throw Exception(
      'ai-router returned HTTP ${response.status}: ${response.data}',
    );
  }

  final data = response.data;
  if (data is Map<String, dynamic>) {
    if (data['status'] == 'error') {
      throw Exception(data['error'] ?? 'Unknown ai-router error');
    }
    return data;
  }
  // ...
}
```

### B. Estrategia Multicapa de Fallback (`lib/features/outfit/services/outfit_intent_analyzer.dart`)
```dart
Future<OutfitIntent> analyzeUserPrompt(String userPrompt) async {
  debugPrint('🔍 FASE 1 — Analyzing intent: "$userPrompt"');

  try {
    // 1. Inferencia primaria en DeepSeek vía Gateway
    final jsonMap = await _analyzeWithDeepSeek(userPrompt);
    jsonMap['userPrompt'] = userPrompt;
    debugPrint('✅ Intent (DeepSeek Gateway): $jsonMap');
    return OutfitIntent.fromJson(jsonMap);
  } catch (e) {
    debugPrint('⚠️ DeepSeek Gateway failed ($e), trying Gemini fallback...');
    try {
      // 2. Fallback a Gemini 2.5 Flash
      final jsonMap = await _analyzeWithGemini(userPrompt);
      jsonMap['userPrompt'] = userPrompt;
      debugPrint('✅ Intent (Gemini Fallback): $jsonMap');
      return OutfitIntent.fromJson(jsonMap);
    } catch (e2) {
      // 3. Fallback local determinista si no hay conexión de IA
      debugPrint('❌ Gemini fallback failed ($e2), running local heuristic analyzer...');
      return _localFallbackAnalysis(userPrompt);
    }
  }
}
```

### C. Chat del Estilista vía Gateway (`lib/features/stylist/services/stylist_chat_service.dart`)
```dart
try {
  final json = await _gateway.chatJson(
    systemPrompt: _systemPrompt,
    userPrompt: userPayload,
    model: _model,
    temperature: 0.6,
  );

  debugPrint('✅ Stylist chat response received: ready=${json['readyToGenerate']}');
  return StylistChatResponse.fromJson(json);
} catch (e) {
  debugPrint('⚠️ Stylist chat gateway error ($e), executing graceful fallback...');
  return StylistChatResponse(
    assistantMessage:
        '¡Excelente! Cuéntame más sobre la ocasión o el estilo que buscas para armar tu outfit ideal.',
    intentState: currentIntent,
    readyToGenerate: currentIntent.hasMinimumContext,
  );
}
```

---

## 3. Estado de la Compilación

Ejecución de `fvm flutter analyze`:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 2.9s)
```

**Resultado:** 0 errores, 0 advertencias y 0 hints en todo el workspace.

---

## 4. Requerimientos de Acción Humana (Pruebas de Verificación)

### A. Pruebas del Chat del Estilista
1. Inicia sesión en la aplicación Flutter.
2. Navega a la pestaña de **Estilista**.
3. Envía un mensaje como: *"Hola, tengo una cena elegante mañana por la noche en la terraza de un hotel, hace fresco. ¿Qué colores y estilo me recomiendas?"*.
4. **Verificación:**
   - La respuesta del asistente debe llegar en español neutro, con tono profesional.
   - El estado de intención acumulará `occasion: "formal_event"`, clima templado/fresco y colores sugeridos.
   - No se emitirán errores de red ni referencias a OpenAI en la consola.

### B. Pruebas de Generación de Outfits con Análisis de Prompt
1. Ve a la pantalla de **Generación de Outfits**.
2. Ingresa un prompt libre: *"Look casual para salir con amigos el sábado por la tarde"*.
3. **Verificación:**
   - En consola observarás el log: `🔍 FASE 1 — Analyzing intent: "..."` seguido de `✅ Intent (DeepSeek Gateway): ...`.
   - Se generará el `OutfitIntent` y continuará el pipeline hacia el filtrado de prendas del armario.

### C. Prueba de Resiliencia / Modo Offline
1. Ejecuta la aplicación sin las variables `--dart-define` de Supabase o desconecta internet momentáneamente.
2. Ingresa un prompt en el generador de outfits.
3. **Verificación:**
   - Observarás la captura del error en consola: `⚠️ DeepSeek Gateway failed (...), trying Gemini fallback...`.
   - Si Gemini tampoco está disponible, se activará el analizador heurístico local (`_localFallbackAnalysis`) sin romper la UI.
