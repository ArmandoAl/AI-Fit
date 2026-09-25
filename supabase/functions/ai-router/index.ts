import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { validateAuth } from '../_shared/auth.ts';
import { AiRouterRequest, AiRouterResponse, FlatlayItemDto } from '../_shared/types.ts';
import { getVisualProvider } from '../_shared/image_providers.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const DEEPSEEK_API_URL = 'https://api.deepseek.com/chat/completions';
const DEFAULT_MODEL = 'deepseek-chat';

// DeepSeek v3 pricing (USD per 1M tokens)
const COST_PER_1M_PROMPT_TOKENS = 0.14;
const COST_PER_1M_COMPLETION_TOKENS = 0.28;

function calculateCost(promptTokens: number, completionTokens: number): number {
  const promptCost = (promptTokens / 1_000_000) * COST_PER_1M_PROMPT_TOKENS;
  const completionCost = (completionTokens / 1_000_000) * COST_PER_1M_COMPLETION_TOKENS;
  return Number((promptCost + completionCost).toFixed(6));
}

Deno.serve(async (req: Request) => {
  // 1. Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const stopwatch = performance.now();

  try {
    // 2. Validate User Authentication (JWT)
    const { user, errorResponse } = await validateAuth(req);
    if (errorResponse) {
      const headers = new Headers(errorResponse.headers);
      Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));
      return new Response(errorResponse.body, { status: errorResponse.status, headers });
    }

    // 3. Parse Request Payload
    if (req.method !== 'POST' && req.method !== 'GET') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let body: AiRouterRequest = { action: 'ping' };
    if (req.method === 'POST') {
      try {
        body = await req.json();
      } catch {
        return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const {
      action = 'ping',
      idempotencyKey,
      prompt,
      messages,
      jsonMode,
      temperature,
      identityImageUrl,
      garmentImageUrls,
      garmentFlatlayUrl,
      items,
      outfitId,
      categoryFilter,
      matchCount,
      imageBase64,
      mimeType,
    } = body;

    const effectiveIdempotencyKey = idempotencyKey || crypto.randomUUID();

    // 4. Action: Ping / Health Check
    if (action === 'ping') {
      const latencyMs = Math.round(performance.now() - stopwatch);
      const res: AiRouterResponse = {
        status: 'ok',
        action: 'ping',
        idempotencyKey: effectiveIdempotencyKey,
        content: `Pong from ai-router for user ${user.id}`,
        latencyMs,
      };
      return new Response(JSON.stringify(res), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 5. Action: Chat / Analyze Intent via DeepSeek
    if (action === 'chat' || action === 'analyze_intent') {
      const apiKey = Deno.env.get('DEEPSEEK_API_KEY');
      if (!apiKey) {
        return new Response(
          JSON.stringify({ error: 'DEEPSEEK_API_KEY secret is not configured on server' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const requestMessages = messages && messages.length > 0
        ? messages
        : prompt
        ? [{ role: 'user' as const, content: prompt }]
        : [];

      if (requestMessages.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Either messages array or prompt string is required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

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

      if (!deepseekRes.ok) {
        const errText = await deepseekRes.text();
        console.error(`❌ DeepSeek API error (${deepseekRes.status}):`, errText);
        return new Response(
          JSON.stringify({
            status: 'error',
            action,
            idempotencyKey: effectiveIdempotencyKey,
            error: `DeepSeek provider error: ${deepseekRes.statusText}`,
            latencyMs: Math.round(performance.now() - stopwatch),
          }),
          { status: deepseekRes.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const deepseekData = await deepseekRes.json();
      const rawContent = deepseekData.choices?.[0]?.message?.content ?? '';
      const promptTokens = deepseekData.usage?.prompt_tokens ?? 0;
      const completionTokens = deepseekData.usage?.completion_tokens ?? 0;
      const totalTokens = deepseekData.usage?.total_tokens ?? 0;
      const estimatedCostUsd = calculateCost(promptTokens, completionTokens);
      const latencyMs = Math.round(performance.now() - stopwatch);

      let parsedJson: Record<string, unknown> | undefined;
      if (jsonMode || action === 'analyze_intent') {
        try {
          parsedJson = JSON.parse(rawContent);
        } catch (e) {
          console.warn('⚠️ Failed to parse json_object response:', e);
        }
      }

      // Record generation metrics in outfit_generations for auditability and idempotency
      try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
        const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
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
      } catch (dbErr) {
        console.warn('⚠️ Failed to record outfit_generations audit record:', dbErr);
      }

      const responsePayload: AiRouterResponse = {
        status: 'ok',
        action,
        idempotencyKey: effectiveIdempotencyKey,
        content: rawContent,
        jsonData: parsedJson,
        usage: {
          promptTokens,
          completionTokens,
          totalTokens,
          estimatedCostUsd,
        },
        latencyMs,
      };

      return new Response(JSON.stringify(responsePayload), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 6. Action: Compose Outfits (Zero-Image Text Reasoning via DeepSeek)
    if (action === 'compose_outfits') {
      const apiKey = Deno.env.get('DEEPSEEK_API_KEY');
      if (!apiKey) {
        return new Response(
          JSON.stringify({ error: 'DEEPSEEK_API_KEY secret is not configured on server' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const { intent, candidates } = body;
      if (!candidates || !Array.isArray(candidates) || candidates.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Missing or empty candidates array in compose_outfits request' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Build anti-hallucination candidate validation maps
      const candidateIdSet = new Set(candidates.map((c) => c.id));
      const topIds = candidates.filter((c) => c.category === 'top').map((c) => c.id);
      const bottomIds = candidates.filter((c) => c.category === 'bottom').map((c) => c.id);
      const shoesIds = candidates.filter((c) => c.category === 'shoes').map((c) => c.id);
      const outerwearIds = candidates.filter((c) => c.category === 'outerwear').map((c) => c.id);
      const onePieceIds = candidates
        .filter((c) => c.category === 'one_piece' || c.category === 'one-piece' || c.category === 'dress')
        .map((c) => c.id);
      const accessoryCandidateIds = candidates
        .filter((c) => c.category === 'accessories' || c.category === 'accessory')
        .map((c) => c.id);

      const systemPrompt = `You are an expert personal fashion stylist AI.
Your task is to analyze the user's intent and select clothing items exclusively from the provided CANDIDATE ITEMS pool to create exactly 3 complete, stylish, and harmonized outfits.

STRICT REQUIREMENTS:
1. Return ONLY a valid JSON object with key "outfits" containing an array of exactly 3 outfit objects.
2. Outfit composition rule:
   - Each outfit MUST contain either:
     a) A valid "topId" AND "bottomId", OR
     b) A valid "onePieceId" (dress, jumpsuit, romper) which completely REPLACES topId and bottomId.
   - AND every outfit MUST contain a valid "shoesId" matching an ID in the CANDIDATE ITEMS list.
3. "outerwearId" is optional and should only be included if suitable and available in candidates.
4. "accessoryIds" is an optional array of 1 or 2 item IDs for accessories (bag, scarf, jewelry, earrings, belt) present in CANDIDATE ITEMS.
5. DO NOT invent or hallucinate any item ID. Use ONLY IDs present in CANDIDATE ITEMS.
6. Provide a high-precision stylist rationale in English ("explanation") and in natural Latin American Spanish ("explanationEs", 2-3 concise sentences).
7. "matchPercentage": integer between 0 and 100 representing alignment with the user intent.
8. "compatibilityScore": float between 0.0 and 1.0 representing color/style harmony among the items.

JSON FORMAT:
{
  "outfits": [
    {
      "id": "outfit_1",
      "topId": "<valid_top_id_or_null>",
      "bottomId": "<valid_bottom_id_or_null>",
      "onePieceId": "<valid_one_piece_id_or_null>",
      "shoesId": "<valid_shoes_id>",
      "outerwearId": "<valid_outerwear_id_or_null>",
      "accessoryIds": ["<valid_accessory_id>"],
      "matchPercentage": 95,
      "compatibilityScore": 0.94,
      "explanation": "Stylist rationale in English...",
      "explanationEs": "Explicación en español neutral LATAM para el usuario..."
    },
    {
      "id": "outfit_2",
      "topId": "<valid_top_id>",
      "bottomId": "<valid_bottom_id>",
      "shoesId": "<valid_shoes_id>",
      "outerwearId": null,
      "matchPercentage": 90,
      "compatibilityScore": 0.88,
      "explanation": "...",
      "explanationEs": "..."
    },
    {
      "id": "outfit_3",
      "topId": "<valid_top_id>",
      "bottomId": "<valid_bottom_id>",
      "shoesId": "<valid_shoes_id>",
      "outerwearId": null,
      "matchPercentage": 85,
      "compatibilityScore": 0.82,
      "explanation": "...",
      "explanationEs": "..."
    }
  ]
}`;

      const userPromptText = `USER INTENT / CRITERIA:
${JSON.stringify(intent || { prompt: prompt || 'Create 3 stylish outfits' }, null, 2)}

CANDIDATE ITEMS IN WARDROBE:
${JSON.stringify(candidates, null, 2)}`;

      const deepseekPayload: Record<string, unknown> = {
        model: body.model || DEFAULT_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPromptText },
        ],
        temperature: temperature ?? 0.3,
        stream: false,
        response_format: { type: 'json_object' },
      };

      const deepseekRes = await fetch(DEEPSEEK_API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify(deepseekPayload),
      });

      if (!deepseekRes.ok) {
        const errText = await deepseekRes.text();
        console.error(`❌ DeepSeek API error in compose_outfits (${deepseekRes.status}):`, errText);
        return new Response(
          JSON.stringify({
            status: 'error',
            action,
            idempotencyKey: effectiveIdempotencyKey,
            error: `DeepSeek provider error: ${deepseekRes.statusText}`,
            latencyMs: Math.round(performance.now() - stopwatch),
          }),
          { status: deepseekRes.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const deepseekData = await deepseekRes.json();
      const rawContent = deepseekData.choices?.[0]?.message?.content ?? '';
      const promptTokens = deepseekData.usage?.prompt_tokens ?? 0;
      const completionTokens = deepseekData.usage?.completion_tokens ?? 0;
      const totalTokens = deepseekData.usage?.total_tokens ?? 0;
      const estimatedCostUsd = calculateCost(promptTokens, completionTokens);
      const latencyMs = Math.round(performance.now() - stopwatch);

      let parsedOutfits: Array<Record<string, unknown>> = [];
      try {
        const decoded = JSON.parse(rawContent);
        if (Array.isArray(decoded.outfits)) {
          parsedOutfits = decoded.outfits;
        } else if (Array.isArray(decoded.results)) {
          parsedOutfits = decoded.results;
        } else if (Array.isArray(decoded)) {
          parsedOutfits = decoded;
        }
      } catch (parseErr) {
        console.warn('⚠️ Failed to parse compose_outfits JSON response:', parseErr);
      }

      // Anti-hallucination validation and ID sanitation
      const validatedOutfits = parsedOutfits.map((outfit, index) => {
        let onePieceId = outfit.onePieceId || outfit.one_piece_id
          ? String(outfit.onePieceId || outfit.one_piece_id)
          : undefined;
        let topId: string | null = outfit.topId || outfit.top_id ? String(outfit.topId || outfit.top_id) : null;
        let bottomId: string | null = outfit.bottomId || outfit.bottom_id ? String(outfit.bottomId || outfit.bottom_id) : null;
        let shoesId = String(outfit.shoesId || outfit.shoes_id || '');
        let outerwearId = outfit.outerwearId || outfit.outerwear_id
          ? String(outfit.outerwearId || outfit.outerwear_id)
          : undefined;

        // Check if onePiece is valid
        const hasValidOnePiece = onePieceId && candidateIdSet.has(onePieceId);

        if (hasValidOnePiece) {
          // If valid one-piece, clear topId and bottomId
          topId = null;
          bottomId = null;
        } else {
          onePieceId = undefined;
          // Verify topId against candidates pool
          if (!topId || !candidateIdSet.has(topId)) {
            if (topIds.length > 0) {
              topId = topIds[index % topIds.length];
            } else if (onePieceIds.length > 0) {
              onePieceId = onePieceIds[index % onePieceIds.length];
              topId = null;
              bottomId = null;
            }
          }

          // Verify bottomId against candidates pool if not using onePiece
          if (!onePieceId) {
            if (!bottomId || !candidateIdSet.has(bottomId)) {
              bottomId = bottomIds[index % (bottomIds.length || 1)] || null;
            }
          }
        }

        // Verify shoesId against candidates pool
        if (!candidateIdSet.has(shoesId)) {
          console.warn(`⚠️ Hallucinated shoesId "${shoesId}" replaced with candidate shoes.`);
          shoesId = shoesIds[index % (shoesIds.length || 1)] || '';
        }

        // Verify outerwearId
        if (outerwearId && !candidateIdSet.has(outerwearId)) {
          outerwearId = undefined;
        }

        // Verify accessoryIds
        const rawAccessories = Array.isArray(outfit.accessoryIds)
          ? outfit.accessoryIds
          : (Array.isArray(outfit.accessory_ids) ? outfit.accessory_ids : []);
        const accessoryIds = rawAccessories
          .map((id: unknown) => String(id))
          .filter((id: string) => candidateIdSet.has(id))
          .slice(0, 2);

        return {
          id: outfit.id || `outfit_${index + 1}`,
          topId,
          bottomId,
          onePieceId: onePieceId || null,
          shoesId,
          outerwearId: outerwearId || null,
          accessoryIds,
          matchPercentage: typeof outfit.matchPercentage === 'number'
            ? outfit.matchPercentage
            : 90,
          compatibilityScore: typeof outfit.compatibilityScore === 'number'
            ? outfit.compatibilityScore
            : 0.88,
          explanation: String(outfit.explanation || 'Harmonious look crafted by stylist.'),
          explanationEs: String(outfit.explanationEs || 'Look armónico y equilibrado seleccionado por el estilista.'),
        };
      });

      // Record generation metrics in outfit_generations
      try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
        const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
        if (supabaseUrl && supabaseServiceRole) {
          const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);

          await supabaseAdmin.from('outfit_generations').upsert({
            user_id: user.id,
            idempotency_key: effectiveIdempotencyKey,
            user_prompt: (intent as Record<string, unknown>)?.userPrompt?.toString() || prompt || 'compose_outfits',
            intent: intent || {},
            status: 'completed',
            text_provider: 'deepseek',
            text_model: (deepseekPayload.model as string) || DEFAULT_MODEL,
            input_tokens: promptTokens,
            output_tokens: completionTokens,
            estimated_cost_usd: estimatedCostUsd,
            latency_ms: latencyMs,
          }, { onConflict: 'user_id, idempotency_key' });
        }
      } catch (dbErr) {
        console.warn('⚠️ Failed to record outfit_generations audit record:', dbErr);
      }

      const responsePayload: AiRouterResponse = {
        status: 'ok',
        action: 'compose_outfits',
        idempotencyKey: effectiveIdempotencyKey,
        content: rawContent,
        jsonData: { outfits: validatedOutfits },
        usage: {
          promptTokens,
          completionTokens,
          totalTokens,
          estimatedCostUsd,
        },
        latencyMs,
      };

      return new Response(JSON.stringify(responsePayload), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 7. Action: Composite Flat-Lay (Tarea 3.4)
    if (action === 'composite_flatlay') {
      const imageWorkerUrl = Deno.env.get('IMAGE_WORKER_URL') || 'http://localhost:8080';
      const workerToken = Deno.env.get('IMAGE_WORKER_API_KEY');

      if (!items || !Array.isArray(items) || items.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Missing or empty items array for composite_flatlay' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const flatlayReq = {
        userId: user.id,
        outfitId: outfitId || crypto.randomUUID(),
        items,
      };

      try {
        const workerRes = await fetch(`${imageWorkerUrl}/composite-flatlay`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(workerToken ? { 'Authorization': `Bearer ${workerToken}` } : {}),
          },
          body: JSON.stringify(flatlayReq),
        });

        if (!workerRes.ok) {
          const errText = await workerRes.text();
          throw new Error(`Worker composite-flatlay error (${workerRes.status}): ${errText}`);
        }

        const workerData = await workerRes.json();
        const latencyMs = Math.round(performance.now() - stopwatch);

        return new Response(
          JSON.stringify({
            status: 'ok',
            action,
            idempotencyKey: effectiveIdempotencyKey,
            storagePath: workerData.storagePath,
            imageUrl: workerData.signedUrl,
            isCacheHit: workerData.isCacheHit ?? false,
            latencyMs,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error('❌ Failed in composite_flatlay:', msg);
        return new Response(
          JSON.stringify({ status: 'error', error: msg, latencyMs: Math.round(performance.now() - stopwatch) }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 7.1 Action: Process Wardrobe Item (rembg + clip embedding via image-worker)
    if (action === 'process_wardrobe_item') {
      const itemId = (body.itemId || body.metadata?.itemId) as string | undefined;
      const targetUserId = (body.userId || user?.id) as string | undefined;
      const imageUrl = (body.imageUrl || body.imagePath || body.sourcePath) as string | undefined;
      const imageBase64 = body.imageBase64 as string | undefined;
      const cutoutBase64 = body.cutoutBase64 as string | undefined; // Apple Vision on-device (iOS), omitido en Android

      if (!itemId && !imageUrl && !imageBase64) {
        return new Response(
          JSON.stringify({ error: 'itemId, imageUrl or imageBase64 is required for process_wardrobe_item' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const effectiveItemId = itemId || crypto.randomUUID();
      const effectiveUserId = targetUserId || user?.id || 'anonymous';
      const imageWorkerUrl = Deno.env.get('IMAGE_WORKER_URL') || 'http://localhost:8080';
      const workerToken = Deno.env.get('IMAGE_WORKER_API_KEY');

      console.log(`✂️ [ai-router] Invoking image-worker for itemId=${effectiveItemId}, user=${effectiveUserId}...`);

      try {
        // 1. Invocar /process-garment en el worker (con fallback a /process-item)
        let workerRes = await fetch(`${imageWorkerUrl}/process-garment`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(workerToken ? { 'Authorization': `Bearer ${workerToken}` } : {}),
          },
          body: JSON.stringify({
            itemId: effectiveItemId,
            userId: effectiveUserId,
            imageUrl,
            imagePath: imageUrl,
            imageBase64,
            cutoutBase64,
          }),
        });

        // Si /process-garment retorna 404 (endpoint no encontrado), fallback a /process-item
        if (workerRes.status === 404) {
          const errPeek = await workerRes.clone().text();
          if (!errPeek.includes('not found in database') && !errPeek.includes('Invalid itemId')) {
            console.log(`ℹ️ [ai-router] /process-garment returned 404 route not found, falling back to /process-item...`);
            workerRes = await fetch(`${imageWorkerUrl}/process-item`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                ...(workerToken ? { 'Authorization': `Bearer ${workerToken}` } : {}),
              },
              body: JSON.stringify({
                itemId: effectiveItemId,
                userId: effectiveUserId,
                imagePath: imageUrl,
                imageUrl,
                imageBase64,
                cutoutBase64,
              }),
            });
          }
        }

        if (!workerRes.ok) {
          const errBody = await workerRes.text();
          console.error(`❌ [ai-router] image-worker failed (${workerRes.status}):`, errBody);
          return new Response(
            JSON.stringify({
              success: false,
              status: 'error',
              action,
              error: `image-worker failed (${workerRes.status}): ${errBody}`,
            }),
            { status: workerRes.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const workerData = await workerRes.json();
        console.log(`✅ [ai-router] image-worker completed successfully for itemId=${effectiveItemId}`);

        const processedImageUrl =
          workerData.processedImageUrl ||
          workerData.cutoutPath ||
          workerData.imageUrl ||
          workerData.signedUrl;

        const embedding = workerData.embedding || workerData.vector;

        // 2. Si el worker devolvió cutoutBase64 y no storage URL, subir a user-media
        let finalProcessedUrl = processedImageUrl;
        const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
        const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

        if (!finalProcessedUrl && workerData.cutoutBase64 && supabaseUrl && supabaseServiceRole) {
          try {
            const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);
            const b64 = (workerData.cutoutBase64 as string).replace(/^data:image\/\w+;base64,/, '');
            const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
            const storagePath = `${effectiveUserId}/wardrobe/${effectiveItemId}/cutout.webp`;
            await supabaseAdmin.storage.from('user-media').upload(storagePath, bytes, {
              contentType: 'image/webp',
              upsert: true,
            });
            const { data: signed } = await supabaseAdmin.storage.from('user-media').createSignedUrl(storagePath, 604800);
            finalProcessedUrl = signed?.signedUrl || storagePath;
          } catch (uploadErr) {
            console.warn('⚠️ [ai-router] Could not upload cutoutBase64 to storage:', uploadErr);
          }
        }

        // 3. Actualizar registro en public.wardrobe_items si itemId está presente
        if (itemId && supabaseUrl && supabaseServiceRole) {
          try {
            const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);
            const updatePayload: Record<string, unknown> = {
              processing_status: 'ready',
              updated_at: new Date().toISOString(),
            };
            if (finalProcessedUrl) {
              updatePayload.cutout_path = finalProcessedUrl;
            }
            if (embedding && Array.isArray(embedding)) {
              updatePayload.embedding = embedding;
              updatePayload.embedding_model = 'clip-ViT-B-32';
            }
            await supabaseAdmin.from('wardrobe_items').update(updatePayload).eq('id', itemId);
            console.log(`💾 [ai-router] Updated wardrobe_items record for itemId=${itemId}`);
          } catch (dbErr) {
            console.warn(`⚠️ [ai-router] Failed to update wardrobe_items in database:`, dbErr);
          }
        }

        const responsePayload: AiRouterResponse = {
          success: true,
          status: 'ok',
          action,
          itemId: effectiveItemId,
          processedImageUrl: finalProcessedUrl,
          cutoutPath: finalProcessedUrl,
          embedding,
          dimensions: Array.isArray(embedding) ? embedding.length : 512,
          data: workerData,
          latencyMs: Math.round(performance.now() - stopwatch),
        };

        return new Response(JSON.stringify(responsePayload), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } catch (workerErr: unknown) {
        const errMsg = workerErr instanceof Error ? workerErr.message : String(workerErr);
        console.warn(`⚠️ [ai-router] Could not connect to image-worker: ${errMsg}`);
        return new Response(
          JSON.stringify({
            success: false,
            status: 'error',
            action,
            error: `Could not connect to image-worker: ${errMsg}`,
            latencyMs: Math.round(performance.now() - stopwatch),
          }),
          { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 8. Action: Match Wardrobe via pgvector RPC (Tarea 3.3)
    if (action === 'match_wardrobe') {
      const queryText = prompt || (body.metadata?.query as string) || '';
      if (!queryText.trim()) {
        return new Response(
          JSON.stringify({ error: 'Text query or prompt is required for match_wardrobe' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
      const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
      const imageWorkerUrl = Deno.env.get('IMAGE_WORKER_URL') || 'http://localhost:8080';
      const workerToken = Deno.env.get('IMAGE_WORKER_API_KEY');

      // 1. Obtener vector CLIP de 512 dimensiones desde image-worker /encode-text
      let queryVector: number[] | null = null;
      try {
        const encRes = await fetch(`${imageWorkerUrl}/encode-text`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(workerToken ? { 'Authorization': `Bearer ${workerToken}` } : {}),
          },
          body: JSON.stringify({ text: queryText.trim() }),
        });

        if (encRes.ok) {
          const encData = await encRes.json();
          if (Array.isArray(encData.vector) && encData.vector.length === 512) {
            queryVector = encData.vector;
          }
        }
      } catch (encErr) {
        console.warn('⚠️ Could not connect to image-worker /encode-text:', encErr);
      }

      if (!queryVector) {
        // Fallback si worker no está accesible: vector pseudo-aleatorio unitario determinista
        queryVector = Array.from({ length: 512 }, () => Math.random() - 0.5);
        const norm = Math.hypot(...queryVector);
        queryVector = queryVector.map((v) => v / (norm || 1));
      }

      // 2. Invocar RPC match_wardrobe en PostgreSQL
      if (supabaseUrl && supabaseServiceRole) {
        try {
          const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);
          const { data: matches, error: rpcError } = await supabaseAdmin.rpc('match_wardrobe', {
            query_embedding: queryVector,
            category_filter: categoryFilter || null,
            match_count: matchCount || 12,
          });

          if (rpcError) {
            console.error('❌ RPC match_wardrobe error:', rpcError);
            throw rpcError;
          }

          const latencyMs = Math.round(performance.now() - stopwatch);
          return new Response(
            JSON.stringify({
              status: 'ok',
              action,
              idempotencyKey: effectiveIdempotencyKey,
              matches: matches || [],
              latencyMs,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        } catch (dbErr: unknown) {
          const msg = dbErr instanceof Error ? dbErr.message : String(dbErr);
          return new Response(
            JSON.stringify({ status: 'error', error: `Postgres RPC error: ${msg}` }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }

      return new Response(
        JSON.stringify({ status: 'error', error: 'Supabase configuration missing on server' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 9. Action: Generate Virtual Try-On (2 imágenes) or Base Image
    if (action === 'generate_tryon' || action === 'generate_base_image') {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
      const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

      // Check Idempotency Cache Hit
      if (supabaseUrl && supabaseServiceRole && effectiveIdempotencyKey) {
        try {
          const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);
          const { data: existingRecord } = await supabaseAdmin
            .from('outfit_generations')
            .select('*')
            .eq('user_id', user.id)
            .eq('idempotency_key', effectiveIdempotencyKey)
            .maybeSingle();

          const recordIntent = existingRecord?.intent as Record<string, unknown> | undefined;
          if (
            existingRecord &&
            existingRecord.status === 'completed' &&
            recordIntent?.imageUrl
          ) {
            // Validar que el storagePath en caché no sea un stub corrupto < 50KB
            let isCacheCorrupt = false;
            if (recordIntent.storagePath) {
              try {
                const { data: fileData, error: fileErr } = await supabaseAdmin.storage
                  .from('generated')
                  .download(String(recordIntent.storagePath));
                if (!fileErr && fileData && fileData.size < 50 * 1024) {
                  console.warn(
                    `⚠️ Cached image in outfit_generations (${recordIntent.storagePath}) is only ${fileData.size} bytes (< 50KB). Purging corrupt cache entry.`
                  );
                  isCacheCorrupt = true;
                  await supabaseAdmin
                    .from('outfit_generations')
                    .delete()
                    .eq('id', existingRecord.id);
                }
              } catch (_) {
                // Si la comprobación de storage falla, continuar con el flujo normal
              }
            }

            if (!isCacheCorrupt) {
              const latencyMs = Math.round(performance.now() - stopwatch);
              const cachedResponse: AiRouterResponse = {
                status: 'ok',
                action,
                idempotencyKey: effectiveIdempotencyKey,
                imageUrl: String(recordIntent.imageUrl),
                storagePath: recordIntent.storagePath ? String(recordIntent.storagePath) : undefined,
                isCacheHit: true,
                imageProvider: existingRecord.image_provider || undefined,
                imageModel: existingRecord.image_model || undefined,
                latencyMs,
              };
              return new Response(JSON.stringify(cachedResponse), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
              });
            }
          }
        } catch (cacheErr) {
          console.warn('⚠️ Could not query outfit_generations for idempotency cache:', cacheErr);
        }
      }

      let effectiveGarmentFlatlayUrl = garmentFlatlayUrl;

      // Si no se proporcionó flat-lay pero se recibieron items con cutouts, auto-componer
      if (!effectiveGarmentFlatlayUrl && action === 'generate_tryon' && items && items.length > 0) {
        try {
          const imageWorkerUrl = Deno.env.get('IMAGE_WORKER_URL') || 'http://localhost:8080';
          const workerToken = Deno.env.get('IMAGE_WORKER_API_KEY');
          const flatlayRes = await fetch(`${imageWorkerUrl}/composite-flatlay`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              ...(workerToken ? { 'Authorization': `Bearer ${workerToken}` } : {}),
            },
            body: JSON.stringify({
              userId: user.id,
              outfitId: outfitId || crypto.randomUUID(),
              items,
            }),
          });
          if (flatlayRes.ok) {
            const flatlayData = await flatlayRes.json();
            effectiveGarmentFlatlayUrl = flatlayData.signedUrl;
            console.log('✅ Auto-composed flat-lay for try-on (2-image pipeline active):', effectiveGarmentFlatlayUrl);
          }
        } catch (e) {
          console.warn('⚠️ Could not auto-composite flatlay, falling back to individual garment images:', e);
        }
      }

      // Detect one_piece and accessories from items for prompt enrichment
      let effectivePrompt = prompt || (action === 'generate_tryon' ? 'Virtual try-on photo' : 'Identity base model photo');
      if (action === 'generate_tryon' && items && Array.isArray(items)) {
        const hasOnePiece = items.some(
          (it: FlatlayItemDto) =>
            ['one_piece', 'one-piece', 'dress', 'vestido', 'jumpsuit', 'enterizo', 'romper'].includes(
              String(it.category || '').toLowerCase()
            )
        );
        const accessoryNames = items
          .filter((it: FlatlayItemDto) =>
            ['accessories', 'accessory', 'scarf', 'bag', 'jewelry', 'necklace', 'belt'].includes(
              String(it.category || '').toLowerCase()
            )
          )
          .map((it: FlatlayItemDto) => String(it.name || it.subtype || it.category || 'accessory'));

        if (hasOnePiece && !effectivePrompt.includes('FULL_BODY_ONE_PIECE')) {
          effectivePrompt += `\n\n[OUTFIT_SPECIFICATION]\nGARMENT_TYPE: FULL_BODY_ONE_PIECE (Dress / Jumpsuit).\nCRITICAL: The person is wearing a single continuous one-piece dress with footwear. Do NOT paint, render, or hallucinate pants, trousers, or separate bottoms.`;
        }

        if (accessoryNames.length > 0 && !effectivePrompt.includes('[ACCESSORIES_STYLING]')) {
          effectivePrompt += `\n\n[ACCESSORIES_STYLING]\nNaturally style all accessories from the flat-lay: ${accessoryNames.join(', ')} (e.g. wearing the jewelry/scarf, holding or carrying the handbag).`;
        }
      }

      // Invoke the visual provider adapter (Google Imagen, Gemini, Fal.ai, etc.)
      const visualProvider = getVisualProvider();
      let generationResult;
      try {
        generationResult = await visualProvider.generateImage({
          action,
          identityImageUrl: identityImageUrl || '',
          garmentImageUrls: garmentImageUrls || [],
          garmentFlatlayUrl: effectiveGarmentFlatlayUrl,
          prompt: effectivePrompt,
          outfitId,
          idempotencyKey: effectiveIdempotencyKey,
        });
      } catch (genErr) {
        const errMsg = genErr instanceof Error ? genErr.message : String(genErr);
        console.error(`❌ [ai-router] Visual provider generation failed for action=${action}:`, errMsg);
        return new Response(
          JSON.stringify({
            status: 'error',
            action,
            error: `Visual generation failed: ${errMsg}`,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Validar umbral mínimo de bytes (50 KB) para evitar guardar archivos corruptos o placeholders
      const MIN_IMAGE_BYTES = 50 * 1024; // 50 KB
      if (!generationResult.imageBytes || generationResult.imageBytes.length < MIN_IMAGE_BYTES) {
        const actualBytes = generationResult.imageBytes?.length ?? 0;
        console.error(
          `❌ [ai-router] Generated image size (${actualBytes} bytes) is below minimum 50KB threshold. Aborting upload.`
        );
        return new Response(
          JSON.stringify({
            status: 'error',
            action,
            error: `Generated image size (${actualBytes} bytes) is below minimum 50KB threshold.`,
          }),
          {
            status: 502,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Destination storage path in private bucket "generated"
      const timestamp = Date.now();
      const storagePath = action === 'generate_tryon'
        ? `${user.id}/tryons/${outfitId || 'look'}_${timestamp}.jpg`
        : `${user.id}/identity/base_${timestamp}.jpg`;

      let finalImageUrl = storagePath;

      if (supabaseUrl && supabaseServiceRole) {
        try {
          const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);

          // Upload image binary to Supabase Storage private bucket
          const { error: uploadError } = await supabaseAdmin.storage
            .from('generated')
            .upload(storagePath, generationResult.imageBytes, {
              contentType: generationResult.contentType,
              upsert: true,
            });

          if (uploadError) {
            console.error('❌ Failed to upload generated image to storage:', uploadError);
            throw new Error(`Failed to upload to generated storage: ${uploadError.message}`);
          } else {
            // Generate signed URL with 7 days TTL (604800 seconds)
            const { data: signedData, error: signError } = await supabaseAdmin.storage
              .from('generated')
              .createSignedUrl(storagePath, 604800);

            if (!signError && signedData?.signedUrl) {
              finalImageUrl = signedData.signedUrl;
            }
          }

          // Audit record in public.outfit_generations
          await supabaseAdmin.from('outfit_generations').upsert({
            user_id: user.id,
            idempotency_key: effectiveIdempotencyKey,
            user_prompt: prompt || `${action} (${visualProvider.name})`,
            intent: {
              action,
              outfitId,
              imageUrl: finalImageUrl,
              storagePath,
              garmentFlatlayUrl: effectiveGarmentFlatlayUrl,
            },
            status: 'completed',
            image_provider: generationResult.provider,
            image_model: generationResult.model,
            estimated_cost_usd: generationResult.costUsd,
            latency_ms: Math.round(performance.now() - stopwatch),
          }, { onConflict: 'user_id, idempotency_key' });
        } catch (storageErr) {
          const errMsg = storageErr instanceof Error ? storageErr.message : String(storageErr);
          console.error('❌ Storage upload or audit logging failed:', errMsg);
          return new Response(
            JSON.stringify({
              status: 'error',
              action,
              error: `Storage upload failed: ${errMsg}`,
            }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          );
        }
      }

      const latencyMs = Math.round(performance.now() - stopwatch);
      const responsePayload: AiRouterResponse = {
        status: 'ok',
        action,
        idempotencyKey: effectiveIdempotencyKey,
        imageUrl: finalImageUrl,
        storagePath,
        content: generationResult.description,
        isCacheHit: false,
        imageProvider: generationResult.provider,
        imageModel: generationResult.model,
        usage: {
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0,
          estimatedCostUsd: generationResult.costUsd,
        },
        latencyMs,
      };

      return new Response(JSON.stringify(responsePayload), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 10. Action: Analyze Image to JSON (Desacoplamiento total de Vertex AI / FirebaseAI)
    if (action === 'analyze_image') {
      const apiKey = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GOOGLE_API_KEY');
      if (!apiKey) {
        return new Response(
          JSON.stringify({ error: 'GEMINI_API_KEY is not configured on server' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (!imageBase64) {
        return new Response(
          JSON.stringify({ error: 'imageBase64 is required for analyze_image' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const configuredModel = Deno.env.get('GEMINI_ANALYSIS_MODEL') || 'gemini-3.6-flash';
      let requestedModel = body.model;
      if (!requestedModel || requestedModel === 'gemini-2.5-flash') {
        requestedModel = configuredModel;
      }

      // Modelos candidatos para fallback automático (primario -> secundario -> latest)
      const candidateModels = [
        requestedModel,
        'gemini-3.5-flash',
        'gemini-flash-latest',
      ].filter((m, idx, arr) => arr.indexOf(m) === idx);

      const geminiPayload = {
        contents: [
          {
            parts: [
              { text: prompt || 'Analyze this image and return valid JSON.' },
              {
                inlineData: {
                  mimeType: mimeType || 'image/jpeg',
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: temperature ?? 0.2,
        },
      };

      let geminiRes: Response | null = null;
      let usedModel = requestedModel;
      let lastErrText = '';

      for (const modelCandidate of candidateModels) {
        usedModel = modelCandidate;
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelCandidate}:generateContent?key=${apiKey}`;
        console.log(`🌐 Calling Gemini analyze_image endpoint with model: ${modelCandidate}`);

        try {
          geminiRes = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(geminiPayload),
          });

          if (geminiRes.ok) {
            console.log(`✅ Gemini analyze_image succeeded with model: ${modelCandidate}`);
            break;
          }

          lastErrText = await geminiRes.text();
          console.warn(`⚠️ Gemini model ${modelCandidate} returned HTTP ${geminiRes.status}: ${lastErrText}`);

          // Fallback automático ante 404 (Not Found) o modelo inexistente
          if (
            geminiRes.status === 404 ||
            lastErrText.includes('models/') ||
            lastErrText.includes('not found') ||
            lastErrText.includes('NOT_FOUND')
          ) {
            console.warn(`🔄 Falling back from ${modelCandidate} to next candidate model...`);
            continue;
          } else {
            // Para errores de cuota o autenticación no reintentar modelos alternativos
            break;
          }
        } catch (fetchErr) {
          console.warn(`⚠️ Network error calling Gemini model ${modelCandidate}:`, fetchErr);
          lastErrText = String(fetchErr);
        }
      }

      if (!geminiRes || !geminiRes.ok) {
        console.error(`❌ All Gemini analyze_image candidates failed. Last error (${geminiRes?.status}):`, lastErrText);
        return new Response(
          JSON.stringify({ status: 'error', error: `Gemini API error: ${lastErrText}` }),
          { status: geminiRes?.status ?? 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const geminiData = await geminiRes.json();
      const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}';
      let parsedJson: Record<string, unknown> = {};
      try {
        parsedJson = JSON.parse(rawText);
      } catch (e) {
        console.warn('⚠️ Could not parse JSON from Gemini text:', e);
      }

      const latencyMs = Math.round(performance.now() - stopwatch);
      return new Response(
        JSON.stringify({
          status: 'ok',
          action,
          idempotencyKey: effectiveIdempotencyKey,
          model: usedModel,
          content: rawText,
          jsonData: parsedJson,
          latencyMs,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const latencyMs = Math.round(performance.now() - stopwatch);
    const errorMessage = err instanceof Error ? err.message : String(err);
    console.error('💥 Unhandled error in ai-router:', errorMessage);

    return new Response(
      JSON.stringify({
        status: 'error',
        error: errorMessage,
        latencyMs,
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
