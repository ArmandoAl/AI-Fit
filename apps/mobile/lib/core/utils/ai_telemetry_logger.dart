import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight structured telemetry logger for AI operations.
///
/// Strictly enforces privacy: no prompts, raw images, signed URLs or user identifiers are logged.
class AiTelemetryLogger {
  AiTelemetryLogger._();

  /// Logs a structured AI telemetry event.
  static void logEvent({
    required String operation,
    String? model,
    int inputCount = 0,
    int inputBytesTotal = 0,
    required int latencyMs,
    int? inputTokens,
    int? outputTokens,
    required String status,
    String? errorCode,
    Map<String, dynamic>? extraMetadata,
  }) {
    final payload = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'operation': operation,
      if (model != null) 'model': model,
      'input_count': inputCount,
      'input_bytes_total': inputBytesTotal,
      'latency_ms': latencyMs,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      'status': status,
      if (errorCode != null) 'error_code': errorCode,
      if (extraMetadata != null) ...extraMetadata,
    };

    final jsonStr = jsonEncode(payload);

    if (kDebugMode) {
      developer.log(
        jsonStr,
        name: 'AI_TELEMETRY',
        level: status == 'failed' ? 1000 : 800,
      );

      final kbs = (inputBytesTotal / 1024).toStringAsFixed(1);
      final tokensInfo = (inputTokens != null || outputTokens != null)
          ? ' | tokens: in=${inputTokens ?? 0}, out=${outputTokens ?? 0}'
          : '';
      final errorInfo = errorCode != null ? ' | error: $errorCode' : '';
      debugPrint(
        '📊 [AI_TELEMETRY] op=$operation | model=${model ?? "n/a"} | status=$status '
        '| latency=${latencyMs}ms | inputs=$inputCount (${kbs}KB)$tokensInfo$errorInfo',
      );
    }
  }
}
