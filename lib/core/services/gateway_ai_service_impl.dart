import 'package:flutter/foundation.dart';
import '../interfaces/ai_service.dart';
import '../platform/app_image.dart';
import '../utils/ai_telemetry_logger.dart';
import '../utils/image_compression_util.dart';
import 'deepseek_service.dart';

/// Implementación de [AIService] que delega completamente al gateway server-side
/// (`ai-router` en Supabase Edge Functions), erradicando las dependencias directas
/// de FirebaseAI / Vertex AI en el cliente.
class GatewayAIServiceImpl implements AIService {
  final DeepSeekService _gateway;

  GatewayAIServiceImpl({DeepSeekService? gateway})
      : _gateway = gateway ?? const DeepSeekService();

  @override
  Future<AIResponse> generateContent({
    required String prompt,
    List<AppImage>? images,
    String? modelId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final effectiveModel = modelId ?? 'deepseek-chat';

    try {
      final text = await _gateway.sendChatMessage([
        {'role': 'user', 'content': prompt},
      ], model: effectiveModel);
      stopwatch.stop();

      AiTelemetryLogger.logEvent(
        operation: 'generate_content',
        model: effectiveModel,
        inputCount: images?.length ?? 0,
        inputBytesTotal: 0,
        latencyMs: stopwatch.elapsedMilliseconds,
        status: 'success',
      );

      return AIResponse(
        text: text.isNotEmpty ? text : "No se pudo generar respuesta.",
      );
    } catch (e) {
      stopwatch.stop();
      AiTelemetryLogger.logEvent(
        operation: 'generate_content',
        model: effectiveModel,
        latencyMs: stopwatch.elapsedMilliseconds,
        status: 'failed',
        errorCode: e.runtimeType.toString(),
      );
      throw Exception("Error en Gateway AI: $e");
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeImageToJson({
    required AppImage image,
    required String promptInstruction,
    AiImagePayload imagePayload = AiImagePayload.garment,
  }) async {
    final stopwatch = Stopwatch()..start();
    final opName = imagePayload == AiImagePayload.identity
        ? 'analyze_identity'
        : 'analyze_garment';

    try {
      final bytes = imagePayload == AiImagePayload.raw
          ? image.bytes
          : await ImageCompressionUtil.compressBytes(
              image.bytes,
              payload: imagePayload,
            );

      final jsonResult = await _gateway.analyzeImageToJson(
        imageBytes: bytes,
        promptInstruction: promptInstruction,
      );
      stopwatch.stop();

      AiTelemetryLogger.logEvent(
        operation: opName,
        model: 'gemini-3.6-flash-server',
        inputCount: 1,
        inputBytesTotal: bytes.lengthInBytes,
        latencyMs: stopwatch.elapsedMilliseconds,
        status: 'success',
      );

      return jsonResult;
    } catch (e) {
      stopwatch.stop();
      AiTelemetryLogger.logEvent(
        operation: opName,
        model: 'gemini-3.6-flash-server',
        latencyMs: stopwatch.elapsedMilliseconds,
        status: 'failed',
        errorCode: e.runtimeType.toString(),
      );
      debugPrint("Error analizando imagen en gateway: $e");
      throw Exception("Fallo al analizar la imagen: $e");
    }
  }
}
