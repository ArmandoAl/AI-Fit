import 'package:flutter/foundation.dart';

/// Platform-tuned limits for garment download / compression pipelines.
class ImagePipelineConfig {
  ImagePipelineConfig._();

  /// On web, [compute] copies large buffers to workers — hurts WASM UI thread.
  static bool get useIsolateForCompression => !kIsWeb;

  /// Parallel download cap (compression is separate on web).
  static int get downloadConcurrency => kIsWeb ? 2 : 5;

  /// Parallel download+compress cap (mobile/desktop only).
  static int get downloadAndCompressConcurrency => kIsWeb ? 1 : 5;
}
