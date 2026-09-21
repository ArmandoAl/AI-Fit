# Resumen de Migración de Modelo Gemini: gemini-2.5-flash -> gemini-3.6-flash

## 1. Contexto y Causa Raíz

El endpoint de análisis de imagen en la Edge Function `ai-router` mantenía como valor por defecto el identificador `gemini-2.5-flash`, el cual retornaba un código de error HTTP `404 (Not Found)` en la API de Google Gemini (Google AI Studio / Generative Language API) debido a obsolescencia / deprecación del identificador de modelo.

---

## 2. Archivos Modificados

| Componente | Archivo | Modificación |
|---|---|---|
| **Edge Function Gateway** | [index.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/ai-router/index.ts) | Se configuró `gemini-3.6-flash` como modelo primario para `analyze_image`. Se agregó lectura de la variable de entorno `GEMINI_ANALYSIS_MODEL` y fallback automático ante 404 a `gemini-3.5-flash` y `gemini-flash-latest`. |
| **Flutter Gateway AI Service** | [gateway_ai_service_impl.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/services/gateway_ai_service_impl.dart) | Se actualizó el identificador en `AiTelemetryLogger` de `'gemini-2.5-flash-server'` a `'gemini-3.6-flash-server'` para operaciones exitosas y fallidas. |
| **Pruebas de Integración y Smoke** | [smoke_test.dart](file:///Users/armandoalvarado/Documents/AI-Fit/test/smoke_test.dart) | Se añadió el test `Gemini 3.6 Flash IdentityProfile JSON contract preserves all biometric fields` para validar que el contrato JSON devuelto preserve íntegramente los campos biométricos esperados. |

---

## 3. Configuración del Endpoint en `ai-router`

### 3.1 Endpoint Primario
```
https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}
```

### 3.2 Soporte de Variable de Entorno
Se soporta opcionalmente la variable de entorno:
```bash
GEMINI_ANALYSIS_MODEL="gemini-3.6-flash"
```
Si se define en el panel de Supabase o en `.env`, tomará precedencia dinámica sin necesidad de re-desplegar código.

### 3.3 Cadena de Fallback Automático ante HTTP 404
Si el modelo configurado o solicitado responde con código `404` (o mensaje de modelo no encontrado), el gateway itera transparentemente por los siguientes candidatos:
1. `GEMINI_ANALYSIS_MODEL` || `gemini-3.6-flash` (Primario)
2. `gemini-3.5-flash` (Fallback secundario)
3. `gemini-flash-latest` (Fallback terciario)

---

## 4. Estado de Verificación Estática en Flutter

- **Análisis estático:**
  ```bash
  fvm flutter analyze
  # Output: Analyzing AI-Fit... No issues found! (ran in 4.9s)
  ```
- **Tests unitarios y de integración:**
  ```bash
  fvm flutter test
  # Output: 00:00 +21: All tests passed!
  ```

---

## 5. Instrucción para Re-Desplegar la Edge Function

Para aplicar los cambios del gateway `ai-router` en el entorno Supabase remoto, ejecuta el siguiente comando en la terminal:

```bash
supabase functions deploy ai-router --no-verify-jwt
```
*(o `npx supabase functions deploy ai-router --no-verify-jwt` si no tienes supabase instalado globalmente).*
