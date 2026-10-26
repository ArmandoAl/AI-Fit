import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Imagen en memoria, compatible con móvil y web (sin `dart:io`).
class AppImage {
  final Uint8List bytes;
  final String? localPath;
  final String? name;

  const AppImage({
    required this.bytes,
    this.localPath,
    this.name,
  });

  String get storageKey =>
      name ?? localPath?.split('/').last ?? 'img_${bytes.lengthInBytes}';

  static Future<AppImage> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return AppImage(
      bytes: bytes,
      localPath: file.path,
      name: file.name,
    );
  }

  static Future<List<AppImage>> fromXFiles(List<XFile> files) async {
    return Future.wait(files.map(fromXFile));
  }
}
