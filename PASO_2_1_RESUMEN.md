# Resumen Paso 2.1: Gateway Server-Side (ai-router)

## 1. Acciones Realizadas

Se construyó e implementó el Gateway Server-Side centralizado de inferencia de IA utilizando **Supabase Edge Functions** en TypeScript bajo el runtime nativo de **Deno**.

### Estructura de Archivos Creados
- [supabase/functions/_shared/cors.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/_shared/cors.ts): Manejo estandarizado de encabezados CORS y respuesta inmediata a peticiones preflight `OPTIONS` (indispensable para clientes Flutter Web, iOS y Android).
- [supabase/functions/_shared/auth.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/_shared/auth.ts): Helper de validación criptográfica de sesión y autenticación que extrae el `Bearer <JWT>` del header `Authorization` y verifica la identidad contra `supabase.auth.getUser()`.
- [supabase/functions/_shared/types.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/_shared/types.ts): Contratos de tipos de entrada (`AiRouterRequest`) y salida (`AiRouterResponse`), soportando acciones `ping`, `chat`, `analyze_intent` y `compose_outfits`.
- [supabase/functions/ai-router/index.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/ai-router/index.ts): Función principal del gateway que procesa las solicitudes de IA, enruta llamadas hacia el proveedor (DeepSeek Chat API), calcula tokens y costos estimados en USD, y registra auditoría en `public.outfit_generations`.

### Flujo de Seguridad y Trazabilidad
1. **Filtro CORS:** Manejo de preflights para peticiones cross-origin desde la app.
2. **Autenticación Estricta (Zero-Trust):** Toda petición debe contener un JWT válido emitido por Supabase Auth; de lo contrario, se rechaza inmediatamente con código `401 Unauthorized`.
3. **Protección de Secretos:** La API Key de DeepSeek (`DEEPSEEK_API_KEY`) nunca se expone al cliente móvil; se consume exclusivamente en memoria del servidor mediante `Deno.env.get('DEEPSEEK_API_KEY')`.
4. **Idempotencia y Métricas:** Se genera o reutiliza una `idempotency_key` por cada petición y se registra la sesión en `public.outfit_generations` con los tokens consumidos (`input_tokens`, `output_tokens`), modelo, proveedor (`deepseek`), costo estimado en USD y latencia en milisegundos (`latency_ms`).

---

## 2. Bloques de Código Clave

### Contratos de Datos (`_shared/types.ts`)
```typescript
export type AiRouterAction = 'ping' | 'chat' | 'analyze_intent' | 'compose_outfits';

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface AiRouterRequest {
  action: AiRouterAction;
  idempotencyKey?: string;
  messages?: ChatMessage[];
  prompt?: string;
  temperature?: number;
  model?: string;
  jsonMode?: boolean;
  metadata?: Record<string, unknown>;
}

export interface AiRouterResponse {
  status: 'ok' | 'error';
  action: AiRouterAction;
  idempotencyKey?: string;
  content?: string;
  jsonData?: Record<string, unknown> | unknown[];
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
    estimatedCostUsd: number;
  };
  latencyMs: number;
  error?: string;
}
```

### Verificación de Autenticación (`_shared/auth.ts`)
```typescript
export async function validateAuth(req: Request): Promise<{ user: User; errorResponse?: Response }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      user: null as unknown as User,
      errorResponse: new Response(
        JSON.stringify({ error: 'Missing or malformed Authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      ),
    };
  }

  const token = authHeader.replace('Bearer ', '').trim();
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) {
    return {
      user: null as unknown as User,
      errorResponse: new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid or expired token', details: error?.message }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      ),
    };
  }

  return { user };
}
```

### Invocación a DeepSeek y Registro de Métricas (`ai-router/index.ts`)
```typescript
const deepseekPayload: Record<string, unknown> = {
  model: body.model || DEFAULT_MODEL,
  messages: requestMessages,
  temperature: temperature ?? (action === 'analyze_intent' ? 0.2 : 0.7),
  stream: false,
};

if (jsonMode || action === 'analyze_intent') {
  deepseekPayload.response_format = { type: 'json_object' };
}

const deepseekRes = await fetch(DEEPSEEK_API_URL, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${apiKey}`,
  },
  body: JSON.stringify(deepseekPayload),
});

// Registro de auditoría e idempotencia en Supabase Postgres
if (supabaseUrl && supabaseServiceRole) {
  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);
  await supabaseAdmin.from('outfit_generations').upsert({
    user_id: user.id,
    idempotency_key: effectiveIdempotencyKey,
    user_prompt: prompt || messages?.[messages.length - 1]?.content || 'ai-router chat',
    intent: parsedJson || {},
    status: 'completed',
    text_provider: 'deepseek',
    text_model: (deepseekPayload.model as string) || DEFAULT_MODEL,
    input_tokens: promptTokens,
    output_tokens: completionTokens,
    estimated_cost_usd: estimatedCostUsd,
    latency_ms: latencyMs,
  }, { onConflict: 'user_id, idempotency_key' });
}
```

---

## 3. Verificación

- **Sintaxis TypeScript / Deno:** Se validaron las importaciones ESM (`@supabase/supabase-js@2.49.1`), el manejo de promesas con `fetch` nativo, tipado estricto y resolución de headers CORS.
- **Validación del Workspace Flutter:** `fvm flutter analyze` ejecutado con éxito sin advertencias ni regresiones en la base de código.

---

## 4. Requerimientos de Acción Humana (Configuración y Despliegue)

### A. Configurar el Secreto de DeepSeek en Supabase

Ejecuta el siguiente comando en tu terminal para almacenar de forma segura la API key en el vault de Supabase:
```bash
supabase secrets set DEEPSEEK_API_KEY="tu_deepseek_api_key_aqui"
```
*(Alternativamente, configúralo desde el Supabase Dashboard: **Project Settings** ➔ **Edge Functions** ➔ **Secrets**).*

### B. Desplegar la Edge Function
Despliega la función `ai-router` ejecutando:
```bash
supabase functions deploy ai-router
```

### C. Probar el Endpoint con `curl` Autenticado

#### 1. Probar Healthcheck (`ping`)
```bash
curl -i --location --request POST 'https://<TU_PROYECTO_ID>.supabase.co/functions/v1/ai-router' \
  --header 'Authorization: Bearer <TU_SUPABASE_USER_JWT>' \
  --header 'Content-Type: application/json' \
  --data '{
    "action": "ping"
  }'
```
**Respuesta esperada:**
```json
{
  "status": "ok",
  "action": "ping",
  "idempotencyKey": "...",
  "content": "Pong from ai-router for user <USER_UUID>",
  "latencyMs": 45
}
```

#### 2. Probar Análisis de Intención (`analyze_intent`)
```bash
curl -i --location --request POST 'https://<TU_PROYECTO_ID>.supabase.co/functions/v1/ai-router' \
  --header 'Authorization: Bearer <TU_SUPABASE_USER_JWT>' \
  --header 'Content-Type: application/json' \
  --data '{
    "action": "analyze_intent",
    "prompt": "Necesito un outfit formal para una cena de gala en clima templado en formato JSON con occasion, weather, style, primaryColors"
  }'
```
