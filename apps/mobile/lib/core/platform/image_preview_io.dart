import 'dart:io';

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
  if (source.localPath != null && source.localPath!.isNotEmpty) {
    return Image.file(
      File(source.localPath!),
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }
  return Image.memory(
    source.bytes,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
  );
}
