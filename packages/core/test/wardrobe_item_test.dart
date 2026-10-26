import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:test/test.dart';

void main() {
  group('categorías', () {
    test('normaliza sinónimos en español e inglés', () {
      expect({
        for (final raw in ['Dress', 'vestido', 'one-piece', 'JUMPSUIT', 'enterizo', 'romper', 'accesorio', 'Accessories', ' Top ', 'shoes'])
          raw: WardrobeItem.normalizeCategory(raw),
      }, {
        'Dress': 'one_piece', 'vestido': 'one_piece', 'one-piece': 'one_piece', 'JUMPSUIT': 'one_piece', 'enterizo': 'one_piece', 'romper': 'one_piece',
        'accesorio': 'accessories', 'Accessories': 'accessories', ' Top ': 'top', 'shoes': 'shoes',
      });
    });

    test('matchesCategory acepta «All» y compara normalizado', () {
      final dress = WardrobeItem(id: '1', name: 'Vestido', type: 'one_piece', subType: 'dress', imageUrl: 'u', colors: const []);
      expect(dress.matchesCategory('all'), isTrue);
      expect(dress.matchesCategory('vestido'), isTrue);
      expect(dress.matchesCategory('top'), isFalse);
    });
  });

  group('fromSupabase', () {
    test('mapea las columnas de la tabla wardrobe_items', () {
      final item = WardrobeItem.fromSupabase({
        'id': 'a1', 'name': 'Camisa azul', 'category': 'Top', 'subtype': 'shirt', 'source_path': 'user/a1.jpg',
        'cutout_path': 'user/a1.webp', 'colors': ['blue'], 'style_tags': ['casual'], 'seasons': ['summer'],
        'brand': 'X', 'created_at': '2026-10-20T12:00:00Z', 'processing_status': 'ready',
      });
      expect(item.type, 'top');
      expect(item.subType, 'shirt');
      expect(item.imageUrl, 'user/a1.jpg');
      expect(item.displayImageUrl, 'user/a1.webp', reason: 'el recorte tiene prioridad sobre el original');
      expect(item.colors, ['blue']);
      expect(item.season, ['summer']);
      expect(item.createdAt, DateTime.utc(2026, 10, 20, 12));
      expect(item.isProcessing, isFalse);
    });

    test('tolera columnas ausentes y estados de procesamiento', () {
      final item = WardrobeItem.fromSupabase({'id': 7, 'subtype': 'jeans', 'processing_status': 'failed'});
      expect(item.id, '7');
      expect(item.name, 'jeans');
      expect(item.type, 'top', reason: 'sin categoría se asume top, igual que la app móvil');
      expect(item.imageUrl, '');
      expect(item.displayImageUrl, '');
      expect(item.processingFailed, isTrue);
      expect(item.colors, isEmpty);
    });

    test('un recorte vacío no sustituye a la imagen original', () {
      final item = WardrobeItem.fromSupabase({'id': 'b', 'source_path': 'o.jpg', 'cutout_path': '  '});
      expect(item.displayImageUrl, 'o.jpg');
    });
  });
}
