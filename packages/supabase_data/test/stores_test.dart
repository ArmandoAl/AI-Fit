import 'dart:convert';

import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:aifit_supabase_data/aifit_supabase_data.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

/// Servidor REST simulado: registra cada petición y responde con lo que decida la prueba.
class Rest {
  final requests = <http.Request>[];
  http.Response Function(http.Request request)? reply;

  SupabaseClient client() => SupabaseClient(
        'https://example.supabase.co',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final response = reply?.call(request) ?? http.Response('[]', 200, headers: {'content-type': 'application/json'});
          // postgrest lee `response.request`; la respuesta simulada debe llevarla.
          return http.Response(response.body, response.statusCode, headers: response.headers, request: request);
        }),
      );

  http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

Map<String, dynamic> row(String id, {String category = 'top'}) => {
      'id': id, 'name': id, 'category': category, 'subtype': 'x', 'source_path': '$id.jpg', 'created_at': '2026-10-20T00:00:00Z',
    };

void main() {
  late Rest rest;
  setUp(() => rest = Rest());

  group('SupabaseWardrobeStore', () {
    test('list consulta sólo las prendas de la persona, recientes primero, y mapea las filas', () async {
      rest.reply = (_) => rest.json([row('a'), row('b', category: 'Dress')]);
      final items = await SupabaseWardrobeStore(rest.client(), userId: () => 'u1').list();
      expect(items.map((i) => (i.id, i.type)), [('a', 'top'), ('b', 'one_piece')]);
      final request = rest.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/wardrobe_items');
      expect(request.url.queryParameters['user_id'], 'eq.u1');
      expect(request.url.queryParameters['order'], 'created_at.desc.nullslast');
    });

    test('sin sesión no hace peticiones y devuelve vacío', () async {
      expect(await SupabaseWardrobeStore(rest.client(), userId: () => null).list(), isEmpty);
      expect(rest.requests, isEmpty);
    });

    test('un error del servidor se propaga (cada cliente decide cómo mostrarlo)', () async {
      rest.reply = (_) => rest.json({'message': 'JWT expired', 'code': 'PGRST301'}, 401);
      await expectLater(SupabaseWardrobeStore(rest.client(), userId: () => 'u1').list(), throwsA(isA<PostgrestException>()));
    });

    test('delete quita primero las referencias en outfit_items y luego las prendas de esa persona', () async {
      rest.reply = (request) => request.url.path.endsWith('wardrobe_items') ? rest.json([{'id': 'a'}, {'id': 'b'}]) : rest.json([]);
      await SupabaseWardrobeStore(rest.client(), userId: () => 'u1').delete(['a', 'b']);
      expect(rest.requests.map((r) => '${r.method} ${r.url.path}'), ['DELETE /rest/v1/outfit_items', 'DELETE /rest/v1/wardrobe_items']);
      expect(rest.requests[0].url.queryParameters['wardrobe_item_id'], 'in.("a","b")');
      expect(rest.requests[1].url.queryParameters['user_id'], 'eq.u1');
      expect(rest.requests[1].url.queryParameters['id'], 'in.("a","b")');
    });

    test('delete falla si el servidor borra menos filas de las pedidas (RLS o ids ajenos)', () async {
      rest.reply = (request) => request.url.path.endsWith('wardrobe_items') ? rest.json([{'id': 'a'}]) : rest.json([]);
      await expectLater(SupabaseWardrobeStore(rest.client(), userId: () => 'u1').delete(['a', 'b']), throwsException);
    });

    test('delete: lista vacía no hace nada; sin sesión falla', () async {
      await SupabaseWardrobeStore(rest.client(), userId: () => 'u1').delete([]);
      expect(rest.requests, isEmpty);
      await expectLater(SupabaseWardrobeStore(rest.client(), userId: () => null).delete(['a']), throwsException);
    });

    test('update envía el cuerpo con el user_id y filtra por id', () async {
      final item = WardrobeItem(id: 'a', name: 'Camisa', type: 'top', subType: 'shirt', imageUrl: 'a.jpg', colors: const ['blue']);
      await SupabaseWardrobeStore(rest.client(), userId: () => 'u1').update(item);
      final request = rest.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.a');
      expect(jsonDecode(request.body)['user_id'], 'u1');
    });
  });

  group('SupabaseProfileStore', () {
    test('arma el mapa del perfil con las rutas de fotos de cuerpo y rostro', () async {
      rest.reply = (request) {
        if (request.url.path.endsWith('profiles')) {
          return rest.json({'id': 'u1', 'display_name': 'Ana', 'avatar_path': 'p.png', 'onboarding_completed': true, 'identity_version': 2});
        }
        return rest.json([
          {'kind': 'body', 'storage_path': 'b1.jpg'}, {'kind': 'face', 'storage_path': 'f1.jpg'}, {'kind': 'body', 'storage_path': 'b2.jpg'},
        ]);
      };
      final profile = await SupabaseProfileStore(rest.client()).fetch('u1');
      expect(profile!['displayName'], 'Ana');
      expect(profile['onboardingCompleted'], isTrue);
      expect(profile['preferences'], isEmpty);
      expect(profile['bodyPhotos'], ['b1.jpg', 'b2.jpg']);
      expect(profile['facePhotos'], ['f1.jpg']);
      expect(rest.requests.map((r) => r.url.path), ['/rest/v1/profiles', '/rest/v1/user_photos']);
      expect(rest.requests[0].url.queryParameters['id'], 'eq.u1');
    });

    test('sin fila en profiles devuelve null y no pide fotos', () async {
      rest.reply = (_) => rest.json([]);
      expect(await SupabaseProfileStore(rest.client()).fetch('u1'), isNull);
      expect(rest.requests, hasLength(1));
    });
  });
}
