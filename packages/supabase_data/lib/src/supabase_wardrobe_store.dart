import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:supabase/supabase.dart';

/// Lectura, actualización y borrado de `wardrobe_items`. Mismas consultas y reglas que la app móvil.
class SupabaseWardrobeStore {
  SupabaseWardrobeStore(this._client, {String? Function()? userId})
      : _userId = userId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _userId;

  /// Prendas de la persona autenticada, las más recientes primero. Sin sesión devuelve una lista vacía.
  Future<List<WardrobeItem>> list() async {
    final uid = _userId();
    if (uid == null) return const [];
    final rows = await _client.from('wardrobe_items').select().eq('user_id', uid).order('created_at', ascending: false);
    return [for (final row in rows) WardrobeItem.fromSupabase(Map<String, dynamic>.from(row))];
  }

  Future<void> update(WardrobeItem item) async {
    final uid = _userId();
    if (uid == null) throw Exception('User not logged in');
    await _client.from('wardrobe_items').update(item.toSupabase(userId: uid)).eq('id', item.id);
  }

  /// `outfit_items` usa ON DELETE RESTRICT: primero se quitan las referencias de los outfits guardados y
  /// después las prendas. Si el servidor borra menos filas de las pedidas (RLS o ids ajenos) falla.
  Future<void> delete(List<String> ids) async {
    final uid = _userId();
    if (uid == null) throw Exception('User not logged in');
    if (ids.isEmpty) return;
    await _client.from('outfit_items').delete().inFilter('wardrobe_item_id', ids);
    final deleted = await _client.from('wardrobe_items').delete().eq('user_id', uid).inFilter('id', ids).select('id');
    if (deleted.length != ids.toSet().length) {
      throw Exception('No se pudieron eliminar todas las prendas seleccionadas');
    }
  }
}
