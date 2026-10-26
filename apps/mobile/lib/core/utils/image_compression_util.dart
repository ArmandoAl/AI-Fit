import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../platform/app_image.dart';

/// Tipo de payload para optimización de imágenes en cliente antes de envío/almacenamiento.
enum AiImagePayload {
  garment,
  identity,
  raw,
}

/// Utilidad de preprocesamiento, normalización y compresión local de imágenes.
///
/// Implementa corrección de orientación EXIF, preservación del canal alfa (transparencia)
/// y límites estrictos de dimensiones para prevenir OOM en dispositivos móviles.
class ImageCompressionUtil {
  ImageCompressionUtil._();

  /// Prendas: Lado largo máximo 1600 px y peso máximo de 1.5 MB.
  static const int garmentMaxLongSide = 1600;
  static const int garmentJpegQuality = 85;
  static const int maxGarmentSizeBytes = 1572864; // 1.5 MB (1.5 * 1024 * 1024)

  /// Fotos de Identidad: Límite estricto de 1920 px en lado largo para prevenir OOM.
  static const int identityMaxLongSide = 1920;
  static const int identityJpegQuality = 90;

  static Future<Uint8List> compressGarment(AppImage image) {
    return compressBytes(image.bytes, payload: AiImagePayload.garment);
  }

  static Future<Uint8List> compressIdentity(AppImage image) {
    return compressBytes(image.bytes, payload: AiImagePayload.identity);
  }

  static Future<Uint8List> compressIdentityBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return bytes;
    return _runEncode(bytes, payload: AiImagePayload.identity);
  }

  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    AiImagePayload payload = AiImagePayload.garment,
  }) async {
    if (payload == AiImagePayload.raw) return bytes;
    if (bytes.isEmpty) return bytes;
    return _runEncode(bytes, payload: payload);
  }

  /// Web: encode en UI isolate con un pequeño delay para evitar jank.
  /// Móvil/desktop: [compute] mantiene el decode/resize fuera del hilo principal.
  static Future<Uint8List> _runEncode(
    Uint8List bytes, {
    required AiImagePayload payload,
  }) async {
    final params = _EncodeParams(bytes: bytes, payload: payload);

    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return _encodeInIsolate(params);
    }

    return compute(_encodeInIsolate, params);
  }
}

class _EncodeParams {
  final Uint8List bytes;
  final AiImagePayload payload;

  const _EncodeParams({required this.bytes, required this.payload});
}

Uint8List _encodeInIsolate(_EncodeParams params) {
  try {
    var image = img.decodeImage(params.bytes);
    if (image == null) return params.bytes;

    // 1. Corregir orientación EXIF antes de redimensionar o codificar
    image = img.bakeOrientation(image);

    final hasAlpha = image.hasAlpha;

    switch (params.payload) {
      case AiImagePayload.garment:
        image = _resizeToMaxLongSide(image, ImageCompressionUtil.garmentMaxLongSide);

        // 2. Preservar canal alfa si existe (fondos transparentes PNG/cutouts)
        if (hasAlpha) {
          final pngBytes = Uint8List.fromList(img.encodePng(image));
          if (pngBytes.lengthInBytes <= ImageCompressionUtil.maxGarmentSizeBytes) {
            return pngBytes;
          }
        }

        // Si no tiene alfa o el PNG excede 1.5MB, codificar en JPEG adaptativo
        var quality = ImageCompressionUtil.garmentJpegQuality;
        var encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));

        while (encoded.lengthInBytes > ImageCompressionUtil.maxGarmentSizeBytes && quality > 50) {
          quality -= 10;
          encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
        }
        return encoded;

      case AiImagePayload.identity:
        // Límite máximo estricto para evitar OOM (sin forzar upscale innecesario)
        image = _resizeToMaxLongSide(image, ImageCompressionUtil.identityMaxLongSide);

        if (hasAlpha) {
          return Uint8List.fromList(img.encodePng(image));
        }

        return Uint8List.fromList(
          img.encodeJpg(
            image,
            quality: ImageCompressionUtil.identityJpegQuality,
          ),
        );

      case AiImagePayload.raw:
        return params.bytes;
    }
  } catch (_) {
    return params.bytes;
  }
}

/// Redimensiona proporcionalmente para que el lado más largo no supere [maxLongSide].
/// Si la imagen es menor o igual al límite, se devuelve sin alteraciones (sin upscale destructivo).
img.Image _resizeToMaxLongSide(img.Image image, int maxLongSide) {
  final width = image.width;
  final height = image.height;
  final currentLongSide = width > height ? width : height;

  if (currentLongSide <= maxLongSide) {
    return image;
  }

  if (width >= height) {
    return img.copyResize(image, width: maxLongSide);
  } else {
    return img.copyResize(image, height: maxLongSide);
  }
}

