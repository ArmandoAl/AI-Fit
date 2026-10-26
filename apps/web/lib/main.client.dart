import 'package:aifit_supabase_data/aifit_supabase_data.dart';
import 'package:jaspr/client.dart';

import 'app.dart';
import 'config.dart';
import 'data/backend.dart';
import 'data/image_resolver.dart';
import 'data/web_wardrobe_repository.dart';
import 'platform/supabase_auth_gateway.dart';

Future<void> main() async {
  const config = AppConfig.fromEnvironment;
  runApp(App(backend: await _backend(config)), attachTo: '#app');
}

/// Composición real: un solo cliente de Supabase para acceso, consultas y Storage.
Future<Backend> _backend(AppConfig config) async {
  if (!config.configured) return const Backend.unavailable();
  final client = SupabaseAuthGateway.createClient(config);
  final gateway = SupabaseAuthGateway(client);
  await gateway.restoreSession();
  return Backend(
    auth: gateway,
    wardrobe: WebWardrobeRepository(SupabaseWardrobeStore(client)),
    images: ImageResolver(client),
    loadProfile: SupabaseProfileStore(client).fetch,
  );
}
