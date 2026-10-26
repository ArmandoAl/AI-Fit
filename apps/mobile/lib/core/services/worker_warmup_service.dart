import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Servicio para el pre-calentamiento (warm-up) preventivo del microservicio
/// Cloud Run (`aifit-image-worker`), reduciendo la latencia de cold-starts
/// cuando la instancia escala a cero.
class WorkerWarmupService {
  WorkerWarmupService._internal();

  /// Instancia singleton del servicio.
  static final WorkerWarmupService instance = WorkerWarmupService._internal();

  /// URL de healthcheck del microservicio en Cloud Run.
  static const String defaultWorkerUrl = String.fromEnvironment(
    'IMAGE_WORKER_URL',
    defaultValue:
        'https://aifit-image-worker-268248668862.us-central1.run.app',
  );

  static String get healthUrl =>
      '${defaultWorkerUrl.replaceAll(RegExp(r'/+$'), '')}/health';

  /// Timeout preventivo de 30 segundos según especificación.
  static const Duration timeoutDuration = Duration(seconds: 30);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: timeoutDuration,
      receiveTimeout: timeoutDuration,
      sendTimeout: timeoutDuration,
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  bool _isWarmingUp = false;
  DateTime? _lastWarmupSuccess;

  /// Retorna true si hay una petición de warmup en vuelo actualmente.
  bool get isWarmingUp => _isWarmingUp;

  /// Retorna la fecha/hora del último warmup exitoso.
  DateTime? get lastWarmupSuccess => _lastWarmupSuccess;

  /// Indica si el worker ya fue calentado exitosamente en los últimos 2 minutos.
  bool get isRecentlyWarmed =>
      _lastWarmupSuccess != null &&
      DateTime.now().difference(_lastWarmupSuccess!) <
          const Duration(minutes: 2);

  /// Dispara el pre-calentamiento en segundo plano de manera no bloqueante (`unawaited`).
  ///
  /// Atrapa internamente cualquier excepción para garantizar que nunca
  /// interrumpa el flujo normal de la app ni lance errores en la UI.
  static void warmUp() {
    unawaited(instance.triggerWarmUp());
  }

  /// Ejecución asíncrona segura del ping de salud hacia Cloud Run.
  Future<void> triggerWarmUp() async {
    if (_isWarmingUp) {
      debugPrint(
        '⚡ [WorkerWarmupService] Petición de warm-up ya en vuelo, omitiendo duplicada.',
      );
      return;
    }

    if (isRecentlyWarmed) {
      debugPrint(
        '⚡ [WorkerWarmupService] Worker ya pre-calentado recientemente (${_lastWarmupSuccess?.toIso8601String()}).',
      );
      return;
    }

    _isWarmingUp = true;
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '🔥 [WorkerWarmupService] Disparando warm-up preventivo a Cloud Run: $healthUrl...',
    );

    try {
      final response = await _dio.get<dynamic>(
        healthUrl,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        _lastWarmupSuccess = DateTime.now();
        debugPrint(
          '✅ [WorkerWarmupService] Cloud Run worker pre-calentado exitosamente en ${stopwatch.elapsedMilliseconds} ms. '
          'Respuesta: ${response.data}',
        );
      } else {
        debugPrint(
          '⚠️ [WorkerWarmupService] Cloud Run worker respondió con status HTTP ${response.statusCode} en ${stopwatch.elapsedMilliseconds} ms.',
        );
      }
    } catch (e) {
      stopwatch.stop();
      debugPrint(
        '⚠️ [WorkerWarmupService] Error no bloqueante al contactar worker (${stopwatch.elapsedMilliseconds} ms): $e',
      );
    } finally {
      _isWarmingUp = false;
    }
  }
}
