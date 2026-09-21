import 'package:flutter/material.dart';

import 'app_image.dart';

Widget buildImageSourcePreview(
  AppImage source, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? cacheWidth,
  int? cacheHeight,
}) {
  return Image.memory(
    source.bytes,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
  );
}
