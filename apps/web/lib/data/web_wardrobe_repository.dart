import 'package:aifit_core/features/wardrobe/data/wardrobe_repository.dart';
import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:aifit_supabase_data/aifit_supabase_data.dart';

/// `WardrobeRepository` de la web: lee, actualiza y borra con las mismas consultas que la app móvil.
/// Agregar prendas y reprocesarlas necesita el worker de imágenes y la IA: sólo existe en la app por ahora.
class WebWardrobeRepository implements WardrobeRepository {
  WebWardrobeRepository(this._store);

  final SupabaseWardrobeStore _store;

  @override
  Future<List<WardrobeItem>> getWardrobeItems() => _store.list();

  @override
  Future<void> updateWardrobeItem(WardrobeItem item) => _store.update(item);

  @override
  Future<void> deleteWardrobeItems(List<String> ids) => _store.delete(ids);

  @override
  Future<void> deleteWardrobeItem(String id) => _store.delete([id]);

  @override
  Future<void> retryProcessing(WardrobeItem item) =>
      Future.error(UnsupportedError('Reprocesar una prenda requiere el worker de imágenes: hazlo desde la app.'));

  @override
  Stream<WardrobeProcessedUpdate> get onItemProcessed => const Stream.empty();
}
