import 'dart:typed_data';

import 'package:aifit/core/services/storage_service.dart';
import 'package:aifit/core/utils/identity_photo_collage.dart';
import 'package:aifit/features/onboarding/services/photo_upload_service.dart';
import 'package:aifit/features/outfit/services/user_base_image_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Identity Board & Base Image Fix Tests', () {
    test('IdentityPhotoCollage.buildIdentityBoard generates valid 1024x1024 image >= 50KB', () async {
      // Generar 2 imágenes de prueba (cuerpo y rostro con detalle de gradiente/ruido)
      final bodyImg = img.Image(width: 400, height: 800);
      for (var y = 0; y < 800; y++) {
        for (var x = 0; x < 400; x++) {
          bodyImg.setPixelRgb(x, y, (x * 3) % 256, (y * 2) % 256, ((x + y) * 5) % 256);
        }
      }
      final bodyBytes = Uint8List.fromList(img.encodeJpg(bodyImg, quality: 90));

      final faceImg = img.Image(width: 400, height: 400);
      for (var y = 0; y < 400; y++) {
        for (var x = 0; x < 400; x++) {
          faceImg.setPixelRgb(x, y, (x * 7) % 256, (y * 5) % 256, (x ^ y) % 256);
        }
      }
      final faceBytes = Uint8List.fromList(img.encodeJpg(faceImg, quality: 90));

      final boardBytes = await IdentityPhotoCollage.buildIdentityBoard(
        facePhotos: [faceBytes],
        bodyPhotos: [bodyBytes],
      );

      expect(boardBytes, isNotNull);
      // Validar umbral mínimo de 50 KB exigido
      expect(
        boardBytes.lengthInBytes,
        greaterThanOrEqualTo(StorageService.minGeneratedImageBytes),
        reason: 'El Identity Board resultante debe ser >= 50KB (${boardBytes.lengthInBytes} bytes)',
      );

      // Decodificar y verificar dimensiones canónicas de 1024x1024
      final decoded = img.decodeImage(boardBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1024));
      expect(decoded.height, equals(1024));
    });

    test('StorageService rejects upload of corrupt 149-byte stub or assets < 50KB', () async {
      final storage = StorageService();

      // Stub de 149 bytes (1x1 pixel)
      final stub1x1Bytes = Uint8List(149);

      expect(
        () => storage.uploadUserBaseImage(userId: 'usr_valid_123', bytes: stub1x1Bytes),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('50KB threshold'),
        )),
      );

      expect(
        () => storage.uploadIdentityCollage(userId: 'usr_valid_123', bytes: stub1x1Bytes),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('50KB threshold'),
        )),
      );

      expect(
        () => storage.uploadOutfitTryOn(userId: 'usr_valid_123', bytes: stub1x1Bytes),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('50KB threshold'),
        )),
      );
    });

    test('UserBaseImageService.isBaseImageCorrupt detects 149-byte stub as corrupt', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter(
        statusCode: 200,
        responseBytes: Uint8List(149), // 149 bytes corrupt stub
      );

      final service = UserBaseImageService(dio: dio);

      final isCorrupt = await service.isBaseImageCorrupt('https://storage.supabase.co/generated/base_1.jpg');
      expect(isCorrupt, isTrue);
    });

    test('UserBaseImageService.isBaseImageCorrupt detects healthy large image as valid', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter(
        statusCode: 200,
        responseBytes: Uint8List(120 * 1024), // 120 KB valid image
      );

      final service = UserBaseImageService(dio: dio);

      final isCorrupt = await service.isBaseImageCorrupt('https://storage.supabase.co/generated/base_valid.jpg');
      expect(isCorrupt, isFalse);
    });

    test('UserBaseImageService.isBaseImageCorrupt detects 206 Partial Content with total < 1024 as corrupt', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter(
        statusCode: 206,
        responseBytes: Uint8List(149),
        headers: {
          'content-range': ['bytes 0-148/149'],
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );

      final service = UserBaseImageService(dio: dio);
      final isCorrupt = await service.isBaseImageCorrupt('https://storage.supabase.co/generated/base_partial.jpg');
      expect(isCorrupt, isTrue);
    });

    test('UserBaseImageService.isBaseImageCorrupt treats empty or mock URLs as corrupt', () async {
      final service = UserBaseImageService();
      expect(await service.isBaseImageCorrupt(''), isTrue);
      expect(await service.isBaseImageCorrupt('mock://sample.jpg'), isTrue);
    });

    test('PhotoUploadService rejects upload when both face and body photos are empty', () async {
      final service = PhotoUploadService();
      expect(
        () => service.uploadOnboardingPhotosAndIdentityBoard(
          userId: 'test_user_123',
          facePhotos: [],
          bodyPhotos: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

class _MockHttpAdapter implements HttpClientAdapter {
  final int statusCode;
  final Uint8List responseBytes;
  final Map<String, List<String>>? headers;

  _MockHttpAdapter({
    required this.statusCode,
    required this.responseBytes,
    this.headers,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      responseBytes,
      statusCode,
      headers: headers ??
          {
            Headers.contentLengthHeader: [responseBytes.length.toString()],
            Headers.contentTypeHeader: ['image/jpeg'],
          },
    );
  }

  @override
  void close({bool force = false}) {}
}
