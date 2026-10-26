import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/app_image.dart';
import '../utils/image_compression_util.dart';
import 'supabase_client.dart';

/// Servicio de almacenamiento desacoplado que opera 100% sobre Supabase Storage
/// en los buckets privados `user-media` y `generated`.
class StorageService {
  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  /// Detecta el MIME type a partir de la firma de bytes.
  static String detectMimeType(Uint8List bytes) {
    if (bytes.length >= 12) {
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      // WebP: RIFF .... WEBP
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'image/webp';
      }
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
    }
    return 'image/jpeg';
  }

  /// Mapea el MIME type a extensión de archivo común.
  static String extensionForMime(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  void _assertAuthenticatedUpload(String userId) {
    if (userId.startsWith('mock_') || userId.contains('mock_user')) {
      throw Exception('Invalid user ID format. Please log in with Google.');
    }

    if (AppSupabaseClient.isInitialized && AppSupabaseClient.client != null) {
      final supabaseUser = _supabase.auth.currentUser;
      if (supabaseUser != null && supabaseUser.id != userId) {
        debugPrint(
          'ℹ️ [StorageService] Supabase session user: ${supabaseUser.id}',
        );
      }
    }
  }

  Future<String> _uploadToSupabase({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bucket == 'generated') {
      _assertValidGeneratedBytes(bytes, 'generated asset ($path)');
    }
    debugPrint(
      '📤 [StorageService -> Supabase] Uploading to $bucket/$path ($mimeType)',
    );

    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    // Generar URL firmada con 7 días de validez (604800 segundos) para buckets privados
    final signedUrl = await _supabase.storage
        .from(bucket)
        .createSignedUrl(path, 604800);

    debugPrint('✅ [StorageService -> Supabase] Upload complete: $signedUrl');
    return signedUrl;
  }

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  Future<String> uploadUserPhoto({
    required String userId,
    required AppImage image,
    required String photoType,
  }) async {
    try {
      _assertAuthenticatedUpload(userId);

      if (image.bytes.isEmpty) {
        throw Exception('Image is empty');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final normalizedBytes = await ImageCompressionUtil.compressIdentity(
        image,
      );
      final mime = detectMimeType(normalizedBytes);
      final ext = extensionForMime(mime);

      final path = '$userId/photos/${photoType}_$timestamp.$ext';
      return await _uploadToSupabase(
        bucket: 'user-media',
        path: path,
        bytes: normalizedBytes,
        mimeType: mime,
      );
    } catch (e) {
      debugPrint('❌ Error uploading photo: $e');
      throw Exception('Failed to upload photo: $e');
    }
  }

  Future<List<String>> uploadMultiplePhotos({
    required String userId,
    required List<AppImage> images,
    required String photoType,
  }) async {
    final urls = <String>[];

    for (final image in images) {
      final url = await uploadUserPhoto(
        userId: userId,
        image: image,
        photoType: photoType,
      );
      urls.add(url);
    }

    return urls;
  }

  Future<String> uploadWardrobeItem({
    required String userId,
    required AppImage image,
  }) async {
    try {
      _assertAuthenticatedUpload(userId);

      if (image.bytes.isEmpty) {
        throw Exception('Image is empty');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final normalizedBytes = await ImageCompressionUtil.compressGarment(image);
      final mime = detectMimeType(normalizedBytes);
      final ext = extensionForMime(mime);

      final path = '$userId/wardrobe/item_$timestamp.$ext';
      return await _uploadToSupabase(
        bucket: 'user-media',
        path: path,
        bytes: normalizedBytes,
        mimeType: mime,
      );
    } catch (e) {
      debugPrint('❌ Error uploading wardrobe item: $e');
      throw Exception('Failed to upload wardrobe item: $e');
    }
  }

  /// Sube un cutout PNG con transparencia generada on-device (Apple Vision)
  /// sin pasar por el pipeline de compresión JPEG (destruiría el canal alfa).
  Future<String> uploadWardrobeCutout({
    required String userId,
    required String itemId,
    required Uint8List bytes,
  }) async {
    _assertAuthenticatedUpload(userId);
    if (bytes.isEmpty) {
      throw Exception('Cutout image is empty');
    }

    final path = '$userId/wardrobe/$itemId/cutout.png';
    return await _uploadToSupabase(
      bucket: 'user-media',
      path: path,
      bytes: bytes,
      mimeType: 'image/png',
    );
  }

  static const int minGeneratedImageBytes = 50 * 1024; // 50 KB

  void _assertValidGeneratedBytes(Uint8List bytes, String purpose) {
    if (bytes.lengthInBytes < minGeneratedImageBytes) {
      throw ArgumentError(
        'Cannot upload $purpose: size (${bytes.lengthInBytes} bytes) is below minimum required 50KB threshold.',
      );
    }
  }

  Future<String> uploadUserBaseImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    _assertValidGeneratedBytes(bytes, 'user base image');
    _assertAuthenticatedUpload(userId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mime = detectMimeType(bytes);
    final ext = extensionForMime(mime);

    final path = '$userId/identity/base_image_$timestamp.$ext';
    return await _uploadToSupabase(
      bucket: 'generated',
      path: path,
      bytes: bytes,
      mimeType: mime,
    );
  }

  Future<String> uploadOutfitTryOn({
    required String userId,
    required Uint8List bytes,
  }) async {
    _assertValidGeneratedBytes(bytes, 'outfit try-on');
    _assertAuthenticatedUpload(userId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mime = detectMimeType(bytes);
    final ext = extensionForMime(mime);

    final path = '$userId/tryons/tryon_$timestamp.$ext';
    return await _uploadToSupabase(
      bucket: 'generated',
      path: path,
      bytes: bytes,
      mimeType: mime,
    );
  }

  Future<String> uploadIdentityCollage({
    required String userId,
    required Uint8List bytes,
  }) async {
    _assertValidGeneratedBytes(bytes, 'identity collage');
    _assertAuthenticatedUpload(userId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mime = detectMimeType(bytes);
    final ext = extensionForMime(mime);

    final path = '$userId/identity/collage_$timestamp.$ext';
    return await _uploadToSupabase(
      bucket: 'generated',
      path: path,
      bytes: bytes,
      mimeType: mime,
    );
  }

  Future<void> deletePhoto(String downloadUrl) async {
    try {
      final uri = Uri.parse(downloadUrl);
      final segments = uri.pathSegments;
      final objectIdx = segments.indexOf('object');
      if (objectIdx != -1 && segments.length > objectIdx + 2) {
        final isSign =
            segments[objectIdx + 1] == 'sign' ||
            segments[objectIdx + 1] == 'public' ||
            segments[objectIdx + 1] == 'authenticated';
        final bucket = isSign
            ? segments[objectIdx + 2]
            : segments[objectIdx + 1];
        final pathStartIndex = isSign ? objectIdx + 3 : objectIdx + 2;
        final objectPath = segments.sublist(pathStartIndex).join('/');
        await _supabase.storage.from(bucket).remove([objectPath]);
        debugPrint(
          '🗑️ [StorageService -> Supabase] Deleted $bucket/$objectPath',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [StorageService] deletePhoto error: $e');
    }
  }

  Future<void> deleteMultiplePhotos(List<String> downloadUrls) async {
    for (final url in downloadUrls) {
      try {
        await deletePhoto(url);
      } catch (e) {
        debugPrint('Error deleting photo $url: $e');
      }
    }
  }
}
