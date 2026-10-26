import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../platform/network_image_loader.dart';
import '../utils/concurrent_task_pool.dart';
import '../utils/image_compression_util.dart';
import '../utils/image_pipeline_config.dart';
import '../utils/ui_frame_yield.dart';

/// Session-level cache for garment image bytes (raw + AI-ready).
class ImageByteCache {
  ImageByteCache._();

  static final ImageByteCache instance = ImageByteCache._();

  final Map<String, Uint8List> _rawBytes = {};
  final Map<String, Uint8List> _aiReadyBytes = {};

  void clear() {
    _rawBytes.clear();
    _aiReadyBytes.clear();
  }

  Uint8List? rawBytesForUrl(String url) => _rawBytes[url];

  Uint8List? aiReadyBytesForUrl(String url) => _aiReadyBytes[url];

  void putRaw(String url, Uint8List bytes) {
    if (url.isEmpty || bytes.isEmpty) return;
    _rawBytes[url] = bytes;
  }

  void putAiReady(String url, Uint8List bytes) {
    if (url.isEmpty || bytes.isEmpty) return;
    _aiReadyBytes[url] = bytes;
  }

  Future<Uint8List?> getOrDownloadRaw(Dio dio, String url) async {
    if (url.isEmpty) return null;
    final cached = _rawBytes[url];
    if (cached != null) return cached;

    try {
      final bytes = await NetworkImageLoader.downloadBytes(dio, url);
      _rawBytes[url] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('⚠️ ImageByteCache download failed for $url: $e');
      return null;
    }
  }

  Future<Uint8List?> getOrCompressGarment(Dio dio, String url) async {
    if (url.isEmpty) return null;

    final aiCached = _aiReadyBytes[url];
    if (aiCached != null) return aiCached;

    final raw = await getOrDownloadRaw(dio, url);
    if (raw == null) return null;

    return compressGarmentFromRaw(url, raw);
  }

  Future<Uint8List?> compressGarmentFromRaw(String url, Uint8List raw) async {
    final aiCached = _aiReadyBytes[url];
    if (aiCached != null) return aiCached;

    try {
      final compressed = await ImageCompressionUtil.compressBytes(
        raw,
        payload: AiImagePayload.garment,
      );
      _aiReadyBytes[url] = compressed;
      return compressed;
    } catch (e) {
      debugPrint('⚠️ ImageByteCache compress failed for $url: $e');
      return null;
    }
  }

  /// Parallel download + garment compression with platform-specific scheduling.
  Future<Map<String, Uint8List>> prepareGarmentImages({
    required Dio dio,
    required List<({String id, String imageUrl})> items,
    int? concurrency,
  }) async {
    if (items.isEmpty) return {};

    if (kIsWeb) {
      return _prepareGarmentImagesWeb(dio: dio, items: items);
    }

    final results = await ConcurrentTaskPool.mapConcurrent(
      items,
      (item) async {
        final bytes = await getOrCompressGarment(dio, item.imageUrl);
        if (bytes == null) return null;
        return MapEntry(item.id, bytes);
      },
      concurrency:
          concurrency ?? ImagePipelineConfig.downloadAndCompressConcurrency,
    );

    return _entriesToMap(results);
  }

  /// Ordered garment bytes for try-on (reuses cache; web-safe scheduling).
  Future<List<Uint8List>> prepareGarmentBytesForUrls({
    required Dio dio,
    required List<String> urls,
  }) async {
    if (urls.isEmpty) return [];

    if (kIsWeb) {
      final bytes = <Uint8List>[];
      for (final url in urls) {
        if (url.isEmpty) continue;
        await yieldToUi();
        final prepared = await getOrCompressGarment(dio, url);
        if (prepared != null) bytes.add(prepared);
        await yieldToUi();
      }
      return bytes;
    }

    final results = await ConcurrentTaskPool.mapConcurrent(
      urls,
      (url) => getOrCompressGarment(dio, url),
      concurrency: ImagePipelineConfig.downloadAndCompressConcurrency,
    );
    return results.whereType<Uint8List>().toList();
  }

  /// Web: downloads in a small pool, compresses one-by-one with frame yields.
  Future<Map<String, Uint8List>> _prepareGarmentImagesWeb({
    required Dio dio,
    required List<({String id, String imageUrl})> items,
  }) async {
    final downloaded = await ConcurrentTaskPool.mapConcurrent(
      items,
      (item) async {
        if (item.imageUrl.isEmpty) return null;
        final raw = await getOrDownloadRaw(dio, item.imageUrl);
        if (raw == null) return null;
        return (id: item.id, url: item.imageUrl);
      },
      concurrency: ImagePipelineConfig.downloadConcurrency,
    );

    final map = <String, Uint8List>{};
    for (final row in downloaded) {
      if (row == null) continue;
      await yieldToUi();
      final compressed = await compressGarmentFromRaw(
        row.url,
        _rawBytes[row.url]!,
      );
      if (compressed != null) {
        map[row.id] = compressed;
      }
      await yieldToUi();
    }
    return map;
  }

  Map<String, Uint8List> _entriesToMap(List<MapEntry<String, Uint8List>?> results) {
    final map = <String, Uint8List>{};
    for (final entry in results) {
      if (entry != null) {
        map[entry.key] = entry.value;
      }
    }
    return map;
  }
}
