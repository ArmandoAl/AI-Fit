import 'package:supabase/supabase.dart';

/// Convierte lo guardado en `source_path`/`cutout_path` en una URL que el navegador pueda cargar.
/// La app móvil guarda URLs firmadas (7 días); los buckets son privados, así que una ruta de Storage se firma aquí.
class ImageResolver {
  ImageResolver(this._client, {this.bucket = 'user-media', this.ttlSeconds = 3600});

  final SupabaseClient? _client;
  final String bucket;
  final int ttlSeconds;
  final _cache = <String, Future<String>>{};

  static bool isLoadable(String value) => RegExp(r'^(https?:|blob:|data:)').hasMatch(value);

  Future<String> resolve(String pathOrUrl) {
    if (pathOrUrl.isEmpty || isLoadable(pathOrUrl)) return Future.value(pathOrUrl);
    final client = _client;
    if (client == null) return Future.value('');
    return _cache.putIfAbsent(pathOrUrl, () async {
      try {
        return await client.storage.from(bucket).createSignedUrl(pathOrUrl, ttlSeconds);
      } on Object {
        _cache.remove(pathOrUrl);
        return '';
      }
    });
  }
}
