import 'dart:convert';

import 'package:aifit_web/data/image_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

SupabaseClient client(List<http.Request> seen, {int status = 200}) => SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        seen.add(request);
        return http.Response(jsonEncode({'signedURL': '/object/sign/user-media/${request.url.pathSegments.skip(5).join('/')}?token=t'}), status,
            headers: {'content-type': 'application/json'}, request: request);
      }),
    );

void main() {
  test('URLs completas, blob y data se devuelven tal cual sin llamar al servidor', () async {
    final seen = <http.Request>[];
    final resolver = ImageResolver(client(seen));
    for (final value in ['https://cdn/x.png', 'http://127.0.0.1/y.png', 'blob:abc', 'data:image/png;base64,AA']) {
      expect(await resolver.resolve(value), value);
    }
    expect(await resolver.resolve(''), '');
    expect(seen, isEmpty);
  });

  test('una ruta de Storage se firma contra el bucket privado y se memoriza', () async {
    final seen = <http.Request>[];
    final resolver = ImageResolver(client(seen), ttlSeconds: 600);
    final url = await resolver.resolve('u1/camisa.jpg');
    expect(url, 'https://example.supabase.co/storage/v1/object/sign/user-media/u1/camisa.jpg?token=t');
    expect(await resolver.resolve('u1/camisa.jpg'), url);
    expect(seen, hasLength(1), reason: 'la segunda consulta sale de la caché');
    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, '/storage/v1/object/sign/user-media/u1/camisa.jpg');
    expect(jsonDecode(seen.single.body)['expiresIn'], 600);
  });

  test('si el servidor falla devuelve vacío y permite reintentar', () async {
    final seen = <http.Request>[];
    final resolver = ImageResolver(client(seen, status: 400));
    expect(await resolver.resolve('u1/a.jpg'), '');
    expect(await resolver.resolve('u1/a.jpg'), '');
    expect(seen, hasLength(2), reason: 'un fallo no se memoriza');
  });

  test('sin cliente (sin configuración) devuelve vacío', () async {
    expect(await ImageResolver(null).resolve('u1/a.jpg'), '');
  });
}
