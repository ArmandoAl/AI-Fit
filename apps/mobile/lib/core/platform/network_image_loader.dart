import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Descarga imágenes remotas a bytes (web + móvil).
class NetworkImageLoader {
  NetworkImageLoader._();

  static Future<Uint8List> downloadBytes(
    Dio dio,
    String url, {
    Duration? connectTimeout,
  }) async {
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        sendTimeout: connectTimeout,
        receiveTimeout: connectTimeout ?? const Duration(seconds: 60),
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Empty image response from $url');
    }
    return Uint8List.fromList(data);
  }
}
