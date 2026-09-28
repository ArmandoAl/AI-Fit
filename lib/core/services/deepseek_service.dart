import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Cliente del Gateway Server-Side (`ai-router`) para inferencia de IA.
///
/// Centraliza todas las llamadas de razonamiento hacia el backend en Supabase Edge Functions,
/// evitando la exposición de claves API en la aplicación cliente y garantizando
/// auditoría, idempotencia y cálculo de costos server-side.
class DeepSeekService {
  final Duration timeout;
  final int maxRetries;
  final double backoffBaseSeconds;
  final Future<void> Function(Duration duration)? customDelay;
  final Future<FunctionResponse> Function(
    String function,
    Map<String, dynamic> body,
  )?
  customInvoker;

  const DeepSeekService({
    this.timeout = const Duration(seconds: 45),
    this.maxRetries = 3,
    this.backoffBaseSeconds = 1.5,
    this.customDelay,
    this.customInvoker,
  });

  /// Determina si un código de estado HTTP representa un error transitorio de gateway / cold start.
  static bool isTransientStatusCode(int status) {
    return status == 502 || status == 503 || status == 504;
  }

  /// Determina si una excepción es transitoria (cold start, timeout o caída momentánea de red).
  static bool isTransientError(Object error) {
    if (error is _TransientGatewayException) {
      return isTransientStatusCode(error.status);
    }
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is FunctionException) {
      final s = error.status;
      if (s == 502 || s == 503 || s == 504) return true;
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('socketexception') ||
        msg.contains('timeoutexception') ||
        msg.contains('timed out') ||
        msg.contains('connection closed') ||
        msg.contains('connection refused') ||
        msg.contains('network is unreachable') ||
        msg.contains('failed host lookup') ||
        msg.contains('cold start')) {
      return true;
    }
    return false;
  }

  /// Invoca la Supabase Edge Function `ai-router` con autenticación JWT, timeout base de 45s
  /// y reintento automático (hasta 3 intentos) con retroceso exponencial ante cold starts y fallos transitorios.
  Future<Map<String, dynamic>> invokeGateway(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
    Duration? timeoutOverride,
    int? maxRetriesOverride,
    void Function(int attempt, Duration delay, dynamic error)? onRetry,
  }) async {
    final client = AppSupabaseClient.client;
    if (customInvoker == null &&
        (client == null || !AppSupabaseClient.isInitialized)) {
      throw Exception(
        'AppSupabaseClient is not initialized or configured. Server-side AI gateway unavailable.',
      );
    }

    final effectiveTimeout = timeoutOverride ?? timeout;
    final effectiveMaxRetries = maxRetriesOverride ?? maxRetries;

    final body = Map<String, dynamic>.from(payload);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      body['idempotencyKey'] = idempotencyKey;
    }

    dynamic lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 0; attempt < effectiveMaxRetries; attempt++) {
      try {
        debugPrint(
          '🌐 [DeepSeekService] Invoking ai-router (attempt ${attempt + 1}/$effectiveMaxRetries)...',
        );

        final Future<FunctionResponse> invokeFuture = customInvoker != null
            ? customInvoker!('ai-router', body)
            : client!.functions.invoke('ai-router', body: body);

        final response = await invokeFuture.timeout(
          effectiveTimeout,
          onTimeout: () {
            throw TimeoutException(
              'ai-router gateway request timed out after ${effectiveTimeout.inSeconds} seconds.',
            );
          },
        );

        if (response.status != 200) {
          final isTransient = isTransientStatusCode(response.status);
          final errorMsg =
              'ai-router returned HTTP ${response.status}: ${response.data}';
          if (isTransient && attempt < effectiveMaxRetries - 1) {
            throw _TransientGatewayException(response.status, errorMsg);
          }
          throw Exception(errorMsg);
        }

        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['status'] == 'error') {
            throw Exception(data['error'] ?? 'Unknown ai-router error');
          }
          return data;
        } else if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            if (decoded['status'] == 'error') {
              throw Exception(decoded['error'] ?? 'Unknown ai-router error');
            }
            return decoded;
          }
        }

        throw Exception(
          'Unexpected response payload format from ai-router: $data',
        );
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        final isTransient = isTransientError(e);
        final hasMoreRetries = attempt < maxRetries - 1;

        if (isTransient && hasMoreRetries) {
          // Fórmula: delay = 1.5 * pow(2, attempt)
          final delaySeconds = backoffBaseSeconds * math.pow(2, attempt);
          final delay = Duration(milliseconds: (delaySeconds * 1000).round());
          debugPrint(
            '⚠️ [DeepSeekService] Transient error (Cold start/Network) on attempt ${attempt + 1}: $e. Retrying in ${delaySeconds}s...',
          );
          if (onRetry != null) {
            try {
              onRetry(attempt + 1, delay, e);
            } catch (_) {}
          }
          if (customDelay != null) {
            await customDelay!(delay);
          } else {
            await Future.delayed(delay);
          }
          continue;
        }

        Error.throwWithStackTrace(e, st);
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(
        lastError,
        lastStackTrace ?? StackTrace.current,
      );
    }
    throw Exception('ai-router invocation failed after $maxRetries attempts');
  }

  /// Invocación estructurada en modo JSON para prompts del sistema y usuario.
  Future<Map<String, dynamic>> chatJson({
    required String systemPrompt,
    required String userPrompt,
    String model = 'deepseek-chat',
    double temperature = 0.2,
    String? idempotencyKey,
  }) async {
    final result = await invokeGateway({
      'action': 'chat',
      'model': model,
      'temperature': temperature,
      'jsonMode': true,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    }, idempotencyKey: idempotencyKey);

    if (result['jsonData'] is Map<String, dynamic>) {
      return result['jsonData'] as Map<String, dynamic>;
    }

    final rawContent = result['content'] as String?;
    if (rawContent != null && rawContent.isNotEmpty) {
      final clean = rawContent
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    }

    throw Exception('No valid JSON content in ai-router gateway response');
  }

  /// Analiza la intención de outfit del usuario a través de `action: analyze_intent`.
  Future<Map<String, dynamic>?> analyzeIntent(
    String prompt, {
    String? idempotencyKey,
  }) async {
    final result = await invokeGateway({
      'action': 'analyze_intent',
      'prompt': prompt,
      'jsonMode': true,
    }, idempotencyKey: idempotencyKey);

    if (result['jsonData'] is Map<String, dynamic>) {
      return result['jsonData'] as Map<String, dynamic>;
    }

    final rawContent = result['content'] as String?;
    if (rawContent != null && rawContent.isNotEmpty) {
      final clean = rawContent
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    }

    return null;
  }

  /// Compone 3 outfits completos estructurados a partir del intent y candidatos balanceados.
  Future<List<Map<String, dynamic>>> composeOutfits({
    required Map<String, dynamic> intent,
    required List<Map<String, dynamic>> candidates,
    String? idempotencyKey,
  }) async {
    final result = await invokeGateway({
      'action': 'compose_outfits',
      'intent': intent,
      'candidates': candidates,
      'jsonMode': true,
      'temperature': 0.3,
    }, idempotencyKey: idempotencyKey);

    if (result['jsonData'] is Map<String, dynamic>) {
      final jsonMap = result['jsonData'] as Map<String, dynamic>;
      final list = jsonMap['outfits'] ?? jsonMap['results'];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    final rawContent = result['content'] as String?;
    if (rawContent != null && rawContent.isNotEmpty) {
      final clean = rawContent
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(clean);
      if (decoded is Map && decoded['outfits'] is List) {
        return (decoded['outfits'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    throw Exception(
      'No valid outfits list found in ai-router compose_outfits response',
    );
  }

  /// Genera una imagen de Virtual Try-On a través del adaptador visual de ai-router.
  /// En el flujo optimizado de 2 imágenes (Tarea 3.4), si se proporciona [garmentFlatlayUrl],
  /// el adaptador visual consume únicamente la imagen de identidad y el flat-lay compuesto.
  Future<Map<String, dynamic>> generateTryOn({
    required List<String> wardrobeItemIds,
    String tryOnProvider = 'seedream',
    String? scenePrompt,
    required String prompt,
    String? outfitId,
    String? idempotencyKey,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{
      'action': 'generate_tryon',
      'wardrobeItemIds': wardrobeItemIds,
      'tryOnProvider': tryOnProvider,
      if (scenePrompt != null) 'scenePrompt': scenePrompt,
      'prompt': prompt,
      if (outfitId != null) 'outfitId': outfitId,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };

    return invokeGateway(
      body,
      idempotencyKey: idempotencyKey,
      timeoutOverride: timeout ?? const Duration(seconds: 120),
      // Prevent a timed-out VTON request from submitting a second paid generation.
      maxRetriesOverride: 1,
    );
  }

  /// Tarea 3.4: Solicita la composición del flat-lay unificado sobre canvas sRGB blanco 1024x1024
  Future<Map<String, dynamic>> compositeFlatlay({
    required String userId,
    required String outfitId,
    required List<Map<String, String>> items,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await invokeGateway({
      'action': 'composite_flatlay',
      'outfitId': outfitId,
      'items': items,
    }, timeoutOverride: timeout);
    return res;
  }

  /// Tarea 3.3: Búsqueda semántica vectorial vía pgvector en PostgreSQL.
  /// Reducido a 8s con 1 solo intento para que ante latencia el fallback por reglas
  /// entre de inmediato sin congelar la app.
  Future<List<Map<String, dynamic>>> matchWardrobe({
    required String query,
    String? category,
    int matchCount = 12,
    Duration timeout = const Duration(seconds: 8),
    int maxRetries = 1,
  }) async {
    final res = await invokeGateway(
      {
        'action': 'match_wardrobe',
        'prompt': query,
        if (category != null) 'categoryFilter': category,
        'matchCount': matchCount,
      },
      timeoutOverride: timeout,
      maxRetriesOverride: maxRetries,
    );

    if (res['matches'] is List) {
      return (res['matches'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  /// Genera una imagen base de identidad a través del adaptador visual de ai-router.
  Future<Map<String, dynamic>> generateBaseImage({
    required String identityImageUrl,
    required String prompt,
    String? idempotencyKey,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{
      'action': 'generate_base_image',
      'identityImageUrl': identityImageUrl,
      'prompt': prompt,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };

    return invokeGateway(
      body,
      idempotencyKey: idempotencyKey,
      timeoutOverride: timeout,
    );
  }

  /// Envía una lista de mensajes conversacionales a través del gateway.
  Future<String> sendChatMessage(
    List<Map<String, String>> messages, {
    String model = 'deepseek-chat',
    double temperature = 0.7,
    String? idempotencyKey,
  }) async {
    final result = await invokeGateway({
      'action': 'chat',
      'model': model,
      'temperature': temperature,
      'messages': messages,
    }, idempotencyKey: idempotencyKey);

    return result['content']?.toString() ?? '';
  }

  /// Analiza una imagen binaria devolviendo JSON estructurado mediante ai-router
  Future<Map<String, dynamic>> analyzeImageToJson({
    required List<int> imageBytes,
    required String promptInstruction,
    String mimeType = 'image/jpeg',
    String? model,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final b64 = base64Encode(imageBytes);
    final result = await invokeGateway({
      'action': 'analyze_image',
      'prompt': promptInstruction,
      'imageBase64': b64,
      'mimeType': mimeType,
      if (model != null) 'model': model,
      'jsonMode': true,
    }, timeoutOverride: timeout);

    if (result['jsonData'] is Map<String, dynamic>) {
      return result['jsonData'] as Map<String, dynamic>;
    }

    final rawContent = result['content'] as String?;
    if (rawContent != null && rawContent.isNotEmpty) {
      final clean = rawContent
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    }

    return {};
  }

  /// Invoca el pipeline de segmentación (rembg) y embedding CLIP para una prenda.
  /// Configurado con un timeout de 12s por defecto y 1 solo intento para no bloquear
  /// la experiencia del usuario si el worker tarda.
  Future<Map<String, dynamic>> processWardrobeItem({
    required String itemId,
    required String userId,
    String? imagePath,
    String? cutoutBase64,
    Duration timeout = const Duration(seconds: 12),
    int maxRetries = 1,
  }) async {
    return await invokeGateway(
      {
        'action': 'process_wardrobe_item',
        'itemId': itemId,
        'userId': userId,
        if (imagePath != null) 'imagePath': imagePath,
        // Cutout ya generado on-device (Apple Vision, iOS-only). Sin soporte en Android.
        if (cutoutBase64 != null) 'cutoutBase64': cutoutBase64,
      },
      timeoutOverride: timeout,
      maxRetriesOverride: maxRetries,
    );
  }
}

/// Excepción interna para identificar fallos HTTP transitorios en el Gateway (502, 503, 504).
class _TransientGatewayException implements Exception {
  final int status;
  final String message;

  _TransientGatewayException(this.status, this.message);

  @override
  String toString() =>
      '_TransientGatewayException(status: $status, message: $message)';
}
