import { FashnTryOnProvider, GoogleImageProvider } from './image_providers.ts';
import type { ImageGenerationOptions } from './types.ts';

Deno.test('FASHN try-on submits the outfit and downloads the completed image', async () => {
  const originalFetch = globalThis.fetch;
  const oldKey = Deno.env.get('FASHN_API_KEY');
  let requestBody: Record<string, unknown> | undefined;

  Deno.env.set('FASHN_API_KEY', 'test-key');
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith('/v1/run')) {
      requestBody = JSON.parse(String(init?.body));
      return Response.json({ id: 'test-prediction' });
    }
    if (url.endsWith('/v1/status/test-prediction')) {
      return Response.json({ status: 'completed', output: ['https://cdn.test/result.jpg'] });
    }
    if (url === 'https://cdn.test/result.jpg') {
      return new Response(new Uint8Array(60 * 1024), {
        headers: { 'content-type': 'image/jpeg' },
      });
    }
    throw new Error(`Unexpected fetch: ${url}`);
  }) as typeof fetch;

  try {
    const options: ImageGenerationOptions = {
      action: 'generate_tryon',
      identityImageUrl: 'https://storage.test/person.jpg',
      garmentFlatlayUrl: 'https://storage.test/outfit.jpg',
      prompt: 'Complete outfit',
    };
    const result = await new FashnTryOnProvider().generateImage(options);
    const inputs = requestBody?.inputs as Record<string, unknown>;

    if (requestBody?.model_name !== 'tryon-max') throw new Error('Wrong model');
    if (inputs?.model_image !== options.identityImageUrl) throw new Error('Person image missing');
    if (inputs?.product_image !== options.garmentFlatlayUrl) throw new Error('Outfit image missing');
    if (result.imageBytes.length !== 60 * 1024) throw new Error('Output image missing');
    if (result.costUsd !== 0.225) throw new Error('Wrong quality-mode cost estimate');
  } finally {
    globalThis.fetch = originalFetch;
    if (oldKey == null) Deno.env.delete('FASHN_API_KEY');
    else Deno.env.set('FASHN_API_KEY', oldKey);
  }
});

Deno.test('Gemini 3.1 receives separate person and outfit references at 2K', async () => {
  const originalFetch = globalThis.fetch;
  const oldKey = Deno.env.get('GEMINI_API_KEY');
  const oldSize = Deno.env.get('GEMINI_IMAGE_SIZE');
  let requestBody: Record<string, unknown> | undefined;
  Deno.env.set('GEMINI_API_KEY', 'test-key');
  Deno.env.set('GEMINI_IMAGE_SIZE', '2K');
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.startsWith('https://storage.test/')) {
      return new Response(new Uint8Array([255, 216, 255, 217]), {
        headers: { 'content-type': 'image/jpeg' },
      });
    }
    if (url.includes('gemini-3.1-flash-image:generateContent')) {
      requestBody = JSON.parse(String(init?.body));
      return Response.json({
        candidates: [{ content: { parts: [{ inlineData: {
          mimeType: 'image/png', data: btoa('generated-image'),
        } }] } }],
        usageMetadata: { promptTokenCount: 1000 },
      });
    }
    throw new Error(`Unexpected fetch: ${url}`);
  }) as typeof fetch;

  try {
    const result = await new GoogleImageProvider().generateImage({
      action: 'generate_tryon',
      identityImageUrl: '',
      identityImageUrls: ['https://storage.test/body.jpg', 'https://storage.test/face.jpg'],
      garmentImageUrls: ['https://storage.test/coat.jpg', 'https://storage.test/ring.jpg'],
      garmentDescriptions: ['outerwear: coat', 'accessories: ring'],
      prompt: 'New winter sidewalk portrait, visible hands',
    });
    const config = requestBody?.generationConfig as Record<string, unknown>;
    const imageConfig = config?.imageConfig as Record<string, unknown>;
    const parts = ((requestBody?.contents as Array<Record<string, unknown>>)[0].parts as Array<Record<string, unknown>>);
    if (imageConfig?.aspectRatio !== '3:4' || imageConfig?.imageSize !== '2K') {
      throw new Error('Wrong output image configuration');
    }
    if (config?.responseFormat) throw new Error('responseFormat.image expects enum values in the REST API');
    if (parts.filter((part) => part.inlineData).length !== 4) throw new Error('Missing image references');
    if (!parts.some((part) => String(part.text || '').includes('ring'))) throw new Error('Missing ring label');
    if (result.model !== 'gemini-3.1-flash-image') throw new Error('Wrong model');
    if (result.contentType !== 'image/png') throw new Error('Wrong content type');
  } finally {
    globalThis.fetch = originalFetch;
    if (oldKey == null) Deno.env.delete('GEMINI_API_KEY'); else Deno.env.set('GEMINI_API_KEY', oldKey);
    if (oldSize == null) Deno.env.delete('GEMINI_IMAGE_SIZE'); else Deno.env.set('GEMINI_IMAGE_SIZE', oldSize);
  }
});
