import 'package:flutter/material.dart';

import 'image_preview_io.dart'
    if (dart.library.html) 'image_preview_web.dart';
import 'app_image.dart';

/// Vista previa cross-platform de [AppImage].
Widget imageSourcePreview(
  AppImage source, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? cacheWidth,
  int? cacheHeight,
}) {
  return buildImageSourcePreview(
    source,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
  );
}
