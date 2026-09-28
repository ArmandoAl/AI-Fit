import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Remoción de fondo on-device usando Apple Vision (`VNGenerateForegroundInstanceMaskRequest`).
///
/// Solo disponible en iOS 17+. En cualquier otra plataforma (Android, web, iOS < 17)
/// [removeBackground] retorna `null` y el item se procesa sin cutout server-side,
/// según la decisión de producto de no dar soporte de remoción de fondo en Android.
class AppleVisionBackgroundRemovalService {
  static const MethodChannel _channel =
      MethodChannel('com.aifit/background_removal');

  /// Recorta el fondo de [imageBytes] y retorna un PNG con canal alfa transparente.
  /// Retorna `null` si la plataforma no es iOS o el OS no soporta Vision (< iOS 17),
  /// o si Vision no detecta ningún objeto en foreground.
  static Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'removeBackground',
        {'imageBytes': imageBytes},
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [AppleVisionBackgroundRemovalService] Vision unavailable or failed: ${e.code} - ${e.message}');
      return null;
    } on MissingPluginException {
      debugPrint('⚠️ [AppleVisionBackgroundRemovalService] Native channel not registered on this build');
      return null;
    }
  }
}
