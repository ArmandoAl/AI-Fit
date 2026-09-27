// ==============================================================================
// image_providers.ts — Adaptador Desacoplado de Proveedores Visuales
// ==============================================================================
// Soluciona la obsolescencia de gemini-2.5-flash-image (retiro 2 de octubre de 2026)
// mediante una arquitectura multi-proveedor desacoplada (Google/Imagen, Fal.ai, Replicate).

import { ImageGenerationOptions, ImageGenerationResult } from './types.ts';

export interface ImageProvider {
  name: string;
  generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult>;
}

// ------------------------------------------------------------------------------
// 1. Google Gemini / Imagen Provider (Moderna API de Generación Visual)
// ------------------------------------------------------------------------------
export class GoogleImageProvider implements ImageProvider {
  public readonly name = 'google';
  private readonly defaultModel = 'imagen-3.0-generate-001';

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    const apiKey = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GOOGLE_API_KEY');
    const model = Deno.env.get('IMAGE_MODEL') || this.defaultModel;

    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not configured in Supabase environment secrets');
    }

    // generate_tryon SIEMPRE requiere el camino multimodal de Gemini: es el único que
    // adjunta identityImageUrl y garmentFlatlayUrl como inlineData. Imagen 3 (:predict)
    // es texto-a-imagen puro y no acepta imágenes de referencia, por lo que usarlo aquí
    // genera un modelo/outfit genérico ajeno al usuario y a sus prendas reales.
    if (options.action === 'generate_tryon') {
      return await this.generateWithGemini(options, apiKey, model.startsWith('imagen-3') ? undefined : model);
    }

    if (model.startsWith('imagen-3')) {
      try {
        return await this.generateWithImagen(options, apiKey, model);
      } catch (imagenErr) {
        const errMsg = imagenErr instanceof Error ? imagenErr.message : String(imagenErr);
        console.warn(
          `⚠️ Google Imagen (${model}) failed: ${errMsg}. Activating automatic fallback to Gemini multimodal (gemini-2.5-flash)...`
        );
        return await this.generateWithGemini(options, apiKey);
      }
    } else {
      return await this.generateWithGemini(options, apiKey, model);
    }
  }

  private async generateWithImagen(
    options: ImageGenerationOptions,
    apiKey: string,
    model: string
  ): Promise<ImageGenerationResult> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict?key=${apiKey}`;
    // Nota: generate_tryon nunca llega aquí (ver generateImage), por lo que este método
    // solo compone prompts de texto puro para generate_base_image.
    const imagenPrompt = options.action === 'generate_base_image'
      ? `Photorealistic full-body studio photograph of a fashion ecommerce mannequin model on a seamless neutral light-gray background, soft studio lighting. Subject standing in a natural relaxed A-pose facing the camera. Wearing minimalist neutral dark-charcoal athletic base-layer clothing (fitted sleeveless tank top and leggings) showing clear body silhouette and natural skin tone. ${options.prompt}`
      : options.prompt;

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        instances: [{ prompt: imagenPrompt }],
        parameters: {
          sampleCount: 1,
          aspectRatio: '3:4',
          personGeneration: 'ALLOW_ADULT',
        },
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Imagen API error (${response.status}): ${errText}`);
    }

    const data = await response.json();
    const b64 = data.predictions?.[0]?.bytesBase64Encoded;
    if (!b64) throw new Error('No image bytes in Imagen response');

    const imageBytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return {
      provider: 'google-imagen',
      model,
      imageBytes,
      contentType: 'image/jpeg',
      costUsd: 0.03, // ~$0.03 por imagen Imagen 3
    };
  }

  private async generateWithGemini(
    options: ImageGenerationOptions,
    apiKey: string,
    requestedModel?: string
  ): Promise<ImageGenerationResult> {
    const parts: Array<Record<string, unknown>> = [];

    // Image 1: Identity image (User Face / Body)
    if (options.identityImageUrl) {
      try {
        const imgRes = await fetch(options.identityImageUrl);
        if (imgRes.ok) {
          const arrayBuf = await imgRes.arrayBuffer();
          const b64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuf)));
          parts.push({
            inlineData: { mimeType: 'image/jpeg', data: b64 },
          });
        }
      } catch (e) {
        console.warn('⚠️ Could not fetch identityImageUrl:', e);
      }
    }

    // Image 2: Unified Garment Flat-Lay (2-image payload)
    if (options.garmentFlatlayUrl) {
      try {
        const flatlayRes = await fetch(options.garmentFlatlayUrl);
        if (flatlayRes.ok) {
          const arrayBuf = await flatlayRes.arrayBuffer();
          const b64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuf)));
          parts.push({
            inlineData: { mimeType: 'image/jpeg', data: b64 },
          });
          console.log('✅ Loaded unified garment flat-lay into visual provider payload (2-image mode active)');
        }
      } catch (e) {
        console.warn('⚠️ Could not fetch garmentFlatlayUrl:', e);
      }
    } else if (options.garmentImageUrls && options.garmentImageUrls.length > 0) {
      // Fallback legacy if flat-lay is not available
      for (const gUrl of options.garmentImageUrls.slice(0, 4)) {
        try {
          const gRes = await fetch(gUrl);
          if (gRes.ok) {
            const arrayBuf = await gRes.arrayBuffer();
            const b64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuf)));
            parts.push({
              inlineData: { mimeType: 'image/jpeg', data: b64 },
            });
          }
        } catch (e) {
          console.warn('⚠️ Could not fetch garment image:', e);
        }
      }
    }

    // Text prompt instruction
    let finalPrompt = options.prompt;
    if (options.garmentFlatlayUrl) {
      finalPrompt = `[INPUT_IMAGE_ROLES]\nImage 1: Person Identity Reference.\nImage 2: Consolidated Garment Flat-Lay showing the complete outfit (one-piece or top/bottom, shoes, and accessories) on a pure white background.\nTransfer all garments and accessories onto the person naturally and accurately.\n\n${options.prompt}`;
    }
    parts.push({ text: finalPrompt });

    // Candidate Gemini models for multimodal generation / assisted composition fallback
    const configuredModel = Deno.env.get('GEMINI_IMAGE_MODEL');
    const rawCandidates = [
      requestedModel && !requestedModel.startsWith('imagen-3') ? requestedModel : null,
      configuredModel,
      'gemini-2.5-flash-image',
      'gemini-2.5-flash',
      'gemini-3.6-flash',
      'gemini-flash-latest',
    ];
    const candidateModels = rawCandidates.filter((m, i, arr): m is string => Boolean(m) && arr.indexOf(m) === i);

    let lastError = '';
    const attemptLog: string[] = [];

    for (const modelCandidate of candidateModels) {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelCandidate}:generateContent?key=${apiKey}`;
      console.log(`🌐 [image_providers] action=${options.action} Calling Gemini visual endpoint with model: ${modelCandidate}`);

      // Attempt 1: Request with IMAGE response modality
      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: {
              responseModalities: ['IMAGE'],
            },
          }),
        });

        if (response.ok) {
          const data = await response.json();
          const candidateParts = data.candidates?.[0]?.content?.parts || [];
          const imagePart = candidateParts.find((p: Record<string, unknown>) => p.inlineData);
          if (imagePart?.inlineData?.data) {
            const b64 = imagePart.inlineData.data;
            const imageBytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
            console.log(`✅ [image_providers] Gemini generated image successfully with model: ${modelCandidate} (${imageBytes.length} bytes)`);
            return {
              provider: 'google-gemini',
              model: modelCandidate,
              imageBytes,
              contentType: imagePart.inlineData.mimeType || 'image/jpeg',
              costUsd: 0.02,
            };
          }
          const blockReason = data.promptFeedback?.blockReason;
          const finishReason = data.candidates?.[0]?.finishReason;
          attemptLog.push(`${modelCandidate}[IMAGE]: no inlineData (finishReason=${finishReason ?? 'n/a'}, blockReason=${blockReason ?? 'n/a'})`);
        } else {
          const errText = await response.text();
          attemptLog.push(`${modelCandidate}[IMAGE]: HTTP ${response.status} ${errText.slice(0, 200)}`);
        }
      } catch (modalityErr) {
        console.warn(`⚠️ [image_providers] Model ${modelCandidate} failed with responseModalities IMAGE:`, modalityErr);
        attemptLog.push(`${modelCandidate}[IMAGE]: exception ${String(modalityErr)}`);
      }

      // Attempt 2: Request without the IMAGE constraint (some models only honor plain generateContent)
      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: {
              temperature: 0.4,
            },
          }),
        });

        if (response.ok) {
          const data = await response.json();
          const candidateParts = data.candidates?.[0]?.content?.parts || [];
          const imagePart = candidateParts.find((p: Record<string, unknown>) => p.inlineData);
          if (imagePart?.inlineData?.data) {
            const b64 = imagePart.inlineData.data;
            const imageBytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
            console.log(`✅ [image_providers] Gemini generated image successfully with model: ${modelCandidate} (plain generateContent, ${imageBytes.length} bytes)`);
            return {
              provider: 'google-gemini',
              model: modelCandidate,
              imageBytes,
              contentType: imagePart.inlineData.mimeType || 'image/jpeg',
              costUsd: 0.02,
            };
          }
          const foundText = candidateParts.find((p: Record<string, unknown>) => p.text)?.text;
          attemptLog.push(`${modelCandidate}[plain]: no inlineData (returned text instead: ${foundText ? 'yes' : 'no'})`);
        } else {
          lastError = await response.text();
          attemptLog.push(`${modelCandidate}[plain]: HTTP ${response.status} ${lastError.slice(0, 200)}`);
          console.warn(`⚠️ [image_providers] Gemini model ${modelCandidate} returned HTTP ${response.status}: ${lastError}`);
        }
      } catch (fetchErr) {
        lastError = String(fetchErr);
        attemptLog.push(`${modelCandidate}[plain]: exception ${lastError}`);
        console.warn(`⚠️ [image_providers] Network error calling Gemini model ${modelCandidate}:`, fetchErr);
      }
    }

    // Nunca degradar en silencio devolviendo la foto de identidad/flat-lay original como si fuera el
    // resultado generado (bug detectado: producía un "try-on" indistinguible de un fallo, sin que la
    // app pudiera saber que la imagen no fue realmente generada por el modelo). Si ningún candidato
    // devolvió una imagen real, se propaga un error explícito con el detalle de cada intento.
    console.error(`❌ [image_providers] All Gemini candidates failed for action=${options.action}. Attempts:\n${attemptLog.join('\n')}`);
    throw new Error(
      `Google Gemini image generation failed across all candidate models (${candidateModels.join(', ')}). Details: ${attemptLog.join(' | ')}`
    );
  }
}

// ------------------------------------------------------------------------------
// 2. Fal.ai Provider (Esqueleto de Contingencia)
// ------------------------------------------------------------------------------
export class FalAiImageProvider implements ImageProvider {
  public readonly name = 'fal';

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    const apiKey = Deno.env.get('FAL_KEY');
    if (!apiKey) {
      throw new Error('FAL_KEY is not configured in Supabase environment secrets');
    }

    const endpoint = 'https://queue.fal.run/fal-ai/flux-realism';
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Key ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        prompt: options.prompt,
        image_size: 'portrait_4_3',
      }),
    });

    if (!response.ok) {
      throw new Error(`Fal.ai error (${response.status}): ${await response.text()}`);
    }

    const data = await response.json();
    const resultUrl = data.images?.[0]?.url;
    if (!resultUrl) throw new Error('No image URL in Fal.ai response');

    const downloadRes = await fetch(resultUrl);
    const arrayBuf = await downloadRes.arrayBuffer();

    return {
      provider: 'fal.ai',
      model: 'flux-realism',
      imageBytes: new Uint8Array(arrayBuf),
      contentType: 'image/jpeg',
      costUsd: 0.025,
    };
  }
}

// ------------------------------------------------------------------------------
// 3. Replicate Provider (Esqueleto de Contingencia)
// ------------------------------------------------------------------------------
export class ReplicateImageProvider implements ImageProvider {
  public readonly name = 'replicate';

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    const apiToken = Deno.env.get('REPLICATE_API_TOKEN');
    if (!apiToken) {
      throw new Error('REPLICATE_API_TOKEN is not configured in Supabase environment secrets');
    }

    const response = await fetch('https://api.replicate.com/v1/predictions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        version: 'bytedance/sdxl-lightning-4step:5f24084160c9f86f773a116bb106be4f0d2bbd6e90e70b39e46acc63b463e79e',
        input: { prompt: options.prompt },
      }),
    });

    if (!response.ok) {
      throw new Error(`Replicate error (${response.status}): ${await response.text()}`);
    }

    const data = await response.json();
    const outputUrl = Array.isArray(data.output) ? data.output[0] : data.output;
    const downloadRes = await fetch(outputUrl);
    const arrayBuf = await downloadRes.arrayBuffer();

    return {
      provider: 'replicate',
      model: 'sdxl-lightning',
      imageBytes: new Uint8Array(arrayBuf),
      contentType: 'image/jpeg',
      costUsd: 0.02,
    };
  }
}

// ------------------------------------------------------------------------------
// Fábrica de Proveedores
// ------------------------------------------------------------------------------
export function getVisualProvider(): ImageProvider {
  const providerName = (Deno.env.get('IMAGE_PROVIDER') || 'google').toLowerCase();

  switch (providerName) {
    case 'fal':
    case 'fal.ai':
      return new FalAiImageProvider();
    case 'replicate':
      return new ReplicateImageProvider();
    case 'google':
    case 'gemini':
    case 'imagen':
    default:
      return new GoogleImageProvider();
  }
}
