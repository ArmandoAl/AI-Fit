import 'package:flutter/foundation.dart';
import 'package:subject_lift_kit/subject_lift_kit.dart';

/// Recorte de fondo on-device vía Apple Vision Framework
/// (`VNGenerateForegroundInstanceMaskRequest`, iOS 17+).
///
/// No lanza excepciones: si la plataforma no es iOS o el recorte falla
/// (simulador, iOS <17, imagen no soportada), retorna `null` para que el
/// caller haga fallback al pipeline de Cloud Run sin interrumpir al usuario.
class NativeCutoutService {
  NativeCutoutService._();

  static Future<Uint8List?> isolateGarment(Uint8List imageBytes) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;

    try {
      final result = await SubjectLiftKit.extractForeground(imageBytes);
      return result.cutoutImageBytes;
    } catch (e) {
      debugPrint('⚠️ [NativeCutoutService] Vision cutout failed, falling back: $e');
      return null;
    }
  }
}
