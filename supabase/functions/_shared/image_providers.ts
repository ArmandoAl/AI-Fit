// ==============================================================================
// image_providers.ts — Adaptador Desacoplado de Proveedores Visuales
// ==============================================================================
// Soluciona la obsolescencia de gemini-2.5-flash-image (retiro 2 de octubre de 2026)
// mediante una arquitectura multi-proveedor desacoplada (Google/Imagen, Fal.ai, Replicate).

import { ImageGenerationOptions, ImageGenerationResult } from './types.ts';

export const DEFAULT_TRY_ON_PROVIDER = 'seedream' as const;

export interface ImageProvider {
  name: string;
  generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult>;
}

// ------------------------------------------------------------------------------
// 1. Google Gemini / Imagen Provider (Moderna API de Generación Visual)
// ------------------------------------------------------------------------------
export class GoogleImageProvider implements ImageProvider {
  public readonly name = 'google-gemini';
  private readonly model = 'gemini-3.1-flash-image';

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    const apiKey = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GOOGLE_API_KEY');
    if (!apiKey) throw new Error('GEMINI_API_KEY is not configured in Supabase secrets');

    const imageSize = Deno.env.get('GEMINI_IMAGE_SIZE') || '2K';
    if (!['1K', '2K', '4K'].includes(imageSize)) {
      throw new Error('GEMINI_IMAGE_SIZE must be 1K, 2K, or 4K');
    }

    const personUrls = options.identityImageUrls?.length
      ? options.identityImageUrls.slice(0, 4)
      : options.identityImageUrl ? [options.identityImageUrl] : [];
    const garmentUrls = options.garmentImageUrls?.length
      ? options.garmentImageUrls
      : options.garmentFlatlayUrl ? [options.garmentFlatlayUrl] : [];
    if (personUrls.length === 0) throw new Error('At least one person reference is required');
    if (options.action === 'generate_tryon' && garmentUrls.length === 0) {
      throw new Error('At least one garment reference is required');
    }
    if (garmentUrls.length > 10 || personUrls.length + garmentUrls.length > 14) {
      throw new Error('Gemini reference limit exceeded (4 person, 10 garments)');
    }

    const parts: Array<Record<string, unknown>> = [];
    const references = [
      ...personUrls.map((url, index) => ({ url, label: `PERSON ${index + 1}: identity and body reference for the same individual` })),
      ...garmentUrls.map((url, index) => ({
        url,
        label: `OUTFIT ITEM ${index + 1}: ${options.garmentDescriptions?.[index] || 'garment or accessory'}; reproduce its visible design`,
      })),
    ];
    for (const reference of references) {
      const response = await fetch(reference.url);
      if (!response.ok) throw new Error(`Could not load ${reference.label} (HTTP ${response.status})`);
      const mimeType = response.headers.get('content-type')?.split(';')[0] || 'image/jpeg';
      if (!mimeType.startsWith('image/')) throw new Error(`${reference.label} is not an image`);
      const bytes = new Uint8Array(await response.arrayBuffer());
      if (bytes.length === 0 || bytes.length > 20 * 1024 * 1024) {
        throw new Error(`${reference.label} has invalid size`);
      }
      const chunks: string[] = [];
      for (let i = 0; i < bytes.length; i += 8192) {
        chunks.push(String.fromCharCode(...bytes.subarray(i, i + 8192)));
      }
      parts.push({ text: reference.label }, { inlineData: { mimeType, data: btoa(chunks.join('')) } });
    }
    parts.push({ text: options.prompt });
    if (options.scenePrompt?.trim()) {
      parts.push({
        text: `[USER SCENE / POSE REQUEST — scene and pose only; selected outfit references remain authoritative]\n${options.scenePrompt.trim().slice(0, 400)}`,
      });
    }

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/${this.model}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body: JSON.stringify({
          contents: [{ role: 'user', parts }],
          generationConfig: {
            responseModalities: ['IMAGE'],
            imageConfig: { aspectRatio: '3:4', imageSize },
          },
        }),
      },
    );
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Gemini ${this.model} failed (HTTP ${response.status}): ${detail.slice(0, 500)}`);
    }
    const data = await response.json();
    const candidate = data.candidates?.[0];
    const imagePart = candidate?.content?.parts?.filter(
      (part: { inlineData?: { data?: string } }) => part.inlineData?.data,
    ).at(-1);
    if (!imagePart?.inlineData?.data) {
      throw new Error(`Gemini returned no image (finishReason=${candidate?.finishReason || 'unknown'}, blockReason=${data.promptFeedback?.blockReason || 'none'})`);
    }
    const imageBytes = Uint8Array.from(atob(imagePart.inlineData.data), (char) => char.charCodeAt(0));
    const outputCost = imageSize === '4K' ? 0.151 : imageSize === '2K' ? 0.101 : 0.067;
    const inputCost = ((data.usageMetadata?.promptTokenCount || 0) / 1_000_000) * 0.5;
    console.log(`✅ Gemini ${this.model}: ${personUrls.length} identity + ${garmentUrls.length} outfit references, ${imageSize}, ${imageBytes.length} bytes`);
    return {
      provider: this.name,
      model: this.model,
      imageBytes,
      contentType: imagePart.inlineData.mimeType || 'image/png',
      costUsd: Number((outputCost + inputCost).toFixed(4)),
    };
  }
}

export class FalTryOnProvider implements ImageProvider {
  readonly name = 'fal';
  readonly model: string;

  constructor(readonly variant: 'seedream' | 'kling') {
    this.model = variant === 'seedream'
      ? 'bytedance/seedream/v5/flash/edit'
      : 'fal-ai/kling-image/o3/image-to-image';
  }

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    const apiKey = Deno.env.get('FAL_KEY');
    if (!apiKey) throw new Error('FAL_KEY is not configured in Supabase secrets');
    const personUrls = options.identityImageUrls?.length
      ? options.identityImageUrls
      : options.identityImageUrl ? [options.identityImageUrl] : [];
    const garmentUrls = options.garmentImageUrls?.length
      ? options.garmentImageUrls
      : options.garmentFlatlayUrl ? [options.garmentFlatlayUrl] : [];
    if (!personUrls.length || !garmentUrls.length) {
      throw new Error('Person and garment references are required for try-on');
    }
    if (personUrls.length + garmentUrls.length > 10) {
      throw new Error(`${this.model} accepts at most 10 reference images`);
    }

    const ref = (index: number) => this.variant === 'kling' ? `@Image${index}` : `#${index}`;
    const prompt = [
      options.prompt,
      `${personUrls.map((_, index) => ref(index + 1)).join(', ')} are person identity/body references for the same individual. Preserve recognizable identity, natural skin tone, hair, glasses, and body proportions. A natural pose may change.`,
      ...garmentUrls.map((_, index) =>
        `${ref(personUrls.length + index + 1)} is selected outfit item ${index + 1}: ${(options.garmentDescriptions?.[index] || 'garment or accessory').slice(0, 80)}. Match its visible color, cut, silhouette, fabric, pattern, and details.`,
      'Wear every selected item and no unselected clothing or fashion accessories. Never recolor, replace, duplicate, or omit a selected item. Keep selected garments recognizable when the pose changes.',
      `Scene/pose only: ${options.scenePrompt?.trim().slice(0, 250) || 'natural relaxed pose in a simple, realistic setting'}. Clothing and accessory details in this request do not override the selected item references.`,
      'Return one coherent photorealistic vertical 3:4 full-body photograph. Keep the person centered with head, all garments, and shoes visible. No text, captions, logos, watermarks, borders, split panels, product cutouts, collage, or moodboard.',
    ].join('\n');
    if (this.variant === 'kling' && prompt.length > 2500) {
      throw new Error('Try-on prompt exceeds Kling image limit');
    }

    const response = await fetch(`https://fal.run/${this.model}`, {
      method: 'POST',
      headers: { Authorization: `Key ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt,
        image_urls: [...personUrls, ...garmentUrls],
        ...(this.variant === 'seedream'
          ? { image_size: { width: 1728, height: 2304 }, num_images: 1, max_images: 1 }
          : { resolution: '2K', aspect_ratio: '3:4', num_images: 1, result_type: 'single' }),
      }),
    });
    if (!response.ok) {
      throw new Error(`${this.model} failed (HTTP ${response.status}): ${(await response.text()).slice(0, 500)}`);
    }
    const result = await response.json();
    const imageUrl = result.images?.[0]?.url;
    if (!imageUrl || !imageUrl.startsWith('https://')) {
      throw new Error(`${this.model} returned no HTTPS image URL`);
    }
    const imageResponse = await fetch(imageUrl);
    if (!imageResponse.ok) throw new Error(`${this.model} image download failed (HTTP ${imageResponse.status})`);
    const contentType = imageResponse.headers.get('content-type')?.split(';')[0] || 'image/png';
    if (!contentType.startsWith('image/')) throw new Error(`${this.model} returned a non-image file`);
    return {
      provider: this.name,
      model: this.model,
      imageBytes: new Uint8Array(await imageResponse.arrayBuffer()),
      contentType,
      costUsd: this.variant === 'seedream' ? 0.027 : 0.028,
    };
  }
}

// Dedicated fashion try-on endpoint. Keep the key server-side and never fall back
// to a text-to-image model: that would silently produce a different person/outfit.
export class FashnTryOnProvider implements ImageProvider {
  public readonly name = 'fashn';

  async generateImage(options: ImageGenerationOptions): Promise<ImageGenerationResult> {
    if (options.action !== 'generate_tryon') {
      throw new Error('FASHN provider only supports generate_tryon');
    }

    const apiKey = Deno.env.get('FASHN_API_KEY');
    if (!apiKey) throw new Error('FASHN_API_KEY is not configured in Supabase secrets');
    if (!options.identityImageUrl) throw new Error('identityImageUrl is required for FASHN try-on');

    const productImage = options.garmentFlatlayUrl ||
      (options.garmentImageUrls?.length === 1 ? options.garmentImageUrls[0] : undefined);
    if (!productImage) {
      throw new Error('A composed outfit flat-lay is required for FASHN try-on');
    }

    const model = Deno.env.get('FASHN_TRYON_MODEL') || 'tryon-max';
    if (model !== 'tryon-max' && model !== 'tryon-v1.6') {
      throw new Error(`Unsupported FASHN_TRYON_MODEL: ${model}`);
    }
    const generationMode = Deno.env.get('FASHN_GENERATION_MODE') || 'quality';
    const resolution = Deno.env.get('FASHN_RESOLUTION') || '1k';
    const inputs = model === 'tryon-max'
      ? {
        model_image: options.identityImageUrl,
        product_image: productImage,
        prompt: 'Apply the complete outfit shown in the product image to the person. Keep the person, face, body shape, pose, and background consistent.',
        generation_mode: generationMode,
        resolution,
        output_format: 'jpeg',
        return_base64: false,
      }
      : {
        model_image: options.identityImageUrl,
        garment_image: productImage,
        category: 'auto',
        mode: generationMode,
        garment_photo_type: 'flat-lay',
        num_samples: 1,
        output_format: 'jpeg',
        return_base64: false,
      };
    const response = await fetch('https://api.fashn.ai/v1/run', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model_name: model,
        inputs,
      }),
    });

    if (!response.ok) {
      throw new Error(`FASHN run failed (${response.status}): ${(await response.text()).slice(0, 500)}`);
    }

    const run = await response.json();
    if (!run.id) throw new Error('FASHN response did not include a prediction id');

    // ponytail: inline polling capped at 105s; use provider webhooks if this becomes a long-tail bottleneck.
    let status: Record<string, unknown> = {};
    for (let attempt = 0; attempt < 35; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, 3000));
      const statusResponse = await fetch(
        `https://api.fashn.ai/v1/status/${encodeURIComponent(String(run.id))}`,
        { headers: { Authorization: `Bearer ${apiKey}` } },
      );
      if (!statusResponse.ok) {
        throw new Error(`FASHN status failed (${statusResponse.status}): ${(await statusResponse.text()).slice(0, 300)}`);
      }
      status = await statusResponse.json();
      if (status.status === 'completed') break;
      if (status.status === 'failed' || status.status === 'error') {
        throw new Error(`FASHN prediction failed: ${JSON.stringify(status.error || status)}`);
      }
    }

    const outputUrl = Array.isArray(status.output) ? status.output[0] : undefined;
    if (status.status !== 'completed' || typeof outputUrl !== 'string' || !outputUrl) {
      throw new Error(`FASHN prediction timed out or returned no image (status=${String(status.status)})`);
    }

    const imageResponse = await fetch(outputUrl);
    if (!imageResponse.ok) throw new Error(`Could not download FASHN output (${imageResponse.status})`);
    const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
    const credits: Record<string, number> = {
      'fast:1k': 1, 'fast:2k': 2, 'fast:4k': 3,
      'balanced:1k': 2, 'balanced:2k': 3, 'balanced:4k': 4,
      'quality:1k': 3, 'quality:2k': 4, 'quality:4k': 5,
    };

    return {
      provider: this.name,
      model,
      imageBytes,
      contentType: imageResponse.headers.get('content-type') || 'image/jpeg',
      costUsd: Number((0.075 * (model === 'tryon-v1.6'
        ? 1
        : credits[`${generationMode}:${resolution}`] || 3)).toFixed(3)),
    };
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
