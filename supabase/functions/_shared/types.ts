export type AiRouterAction =
  | 'ping'
  | 'chat'
  | 'analyze_intent'
  | 'compose_outfits'
  | 'generate_tryon'
  | 'generate_base_image'
  | 'match_wardrobe'
  | 'composite_flatlay'
  | 'process_wardrobe_item'
  | 'analyze_image';

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface CandidateItem {
  id: string;
  name: string;
  category: string; // 'top' | 'bottom' | 'shoes' | 'outerwear' | 'one_piece' | 'accessories'
  subtype?: string;
  colors?: string[];
  styleTags?: string[];
  seasons?: string[];
  formalityScore?: number;
  weatherCompatibility?: string[];
}

export interface ComposeOutfitProposal {
  id: string;
  topId?: string | null;
  bottomId?: string | null;
  onePieceId?: string | null;
  shoesId: string;
  outerwearId?: string | null;
  accessoryIds?: string[];
  matchPercentage: number;
  compatibilityScore: number;
  explanation: string;
  explanationEs: string;
}

export interface FlatlayItemDto {
  category: string;
  cutoutPath: string;
  name?: string;
  subtype?: string;
}

export interface ImageGenerationOptions {
  action: 'generate_tryon' | 'generate_base_image';
  identityImageUrl: string;
  identityImageUrls?: string[];
  garmentImageUrls?: string[];
  garmentDescriptions?: string[];
  scenePrompt?: string;
  garmentFlatlayUrl?: string; // Tarea 3.4: Flat-lay unificado (2 imágenes en try-on)
  prompt: string;
  outfitId?: string;
  idempotencyKey?: string;
}

export interface ImageGenerationResult {
  provider: string;
  model: string;
  imageBytes: Uint8Array;
  contentType: string;
  costUsd: number;
  description?: string;
}

export interface WardrobeMatchDto {
  id: string;
  category: string;
  similarity: number;
  metadata?: Record<string, unknown>;
}

export interface AiRouterRequest {
  action: AiRouterAction;
  idempotencyKey?: string;
  messages?: ChatMessage[];
  prompt?: string;
  intent?: Record<string, unknown>;
  candidates?: CandidateItem[];
  identityImageUrl?: string;
  wardrobeItemIds?: string[];
  garmentImageUrls?: string[];
  garmentFlatlayUrl?: string; // Tarea 3.4
  scenePrompt?: string;
  tryOnProvider?: 'gemini' | 'seedream' | 'kling';
  items?: FlatlayItemDto[];
  outfitId?: string;
  categoryFilter?: string;
  matchCount?: number;
  imageBase64?: string;
  mimeType?: string;
  temperature?: number;
  model?: string;
  jsonMode?: boolean;
  itemId?: string;
  userId?: string;
  imageUrl?: string;
  imagePath?: string;
  sourcePath?: string;
  cutoutBase64?: string; // Cutout ya generado on-device (Apple Vision, iOS-only)
  metadata?: Record<string, unknown>;
}

export interface AiRouterResponse {
  status: 'ok' | 'error';
  action: AiRouterAction;
  success?: boolean;
  idempotencyKey?: string;
  content?: string;
  jsonData?: Record<string, unknown> | unknown[];
  imageUrl?: string;
  processedImageUrl?: string;
  cutoutPath?: string;
  embedding?: number[];
  dimensions?: number;
  itemId?: string;
  data?: unknown;
  storagePath?: string;
  isCacheHit?: boolean;
  imageProvider?: string;
  imageModel?: string;
  matches?: WardrobeMatchDto[];
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
    estimatedCostUsd: number;
  };
  latencyMs: number;
  error?: string;
}
