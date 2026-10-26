import 'package:aifit_core/features/wardrobe/data/wardrobe_repository.dart';

import '../auth/auth_controller.dart';
import 'image_resolver.dart';

/// Lo que la interfaz necesita del servidor. La composición real vive en `main.client.dart`.
class Backend {
  const Backend({required this.auth, required this.wardrobe, required this.images, required this.loadProfile, this.available = true});

  /// Sin configuración de Supabase: la interfaz explica qué falta en lugar de fallar al iniciar sesión.
  const Backend.unavailable()
      : auth = const _NoAuth(),
        wardrobe = const _NoWardrobe(),
        images = null,
        loadProfile = _noProfile,
        available = false;

  final AuthGateway auth;
  final WardrobeRepository wardrobe;
  final ImageResolver? images;
  final Future<Map<String, dynamic>?> Function(String userId) loadProfile;
  final bool available;

  static Future<Map<String, dynamic>?> _noProfile(String userId) async => null;
}

class _NoAuth implements AuthGateway {
  const _NoAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Supabase no está configurado.');
}

class _NoWardrobe implements WardrobeRepository {
  const _NoWardrobe();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Supabase no está configurado.');
}
