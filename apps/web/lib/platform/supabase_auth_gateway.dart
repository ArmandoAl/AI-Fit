import 'dart:async';
import 'dart:convert';

import 'package:aifit_core/features/auth/domain/user_model.dart' as app;
import 'package:supabase/supabase.dart' as sb;
import 'package:web/web.dart' as web;

import '../auth/auth_controller.dart';
import '../config.dart';
import 'browser_storage.dart';

/// Acceso con Google mediante Supabase (OAuth con PKCE y redirección), como la versión web de la app Flutter.
/// La sesión se guarda en `localStorage` y se restaura al abrir la página.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client) {
    client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      _write(session == null ? null : jsonEncode(session.toJson()));
    });
  }

  static const _sessionKey = 'aifit.web.session';
  final sb.SupabaseClient client;

  static sb.SupabaseClient createClient(AppConfig config) => sb.SupabaseClient(
        config.supabaseUrl,
        config.supabaseKey,
        authOptions: const sb.AuthClientOptions(
          authFlowType: sb.AuthFlowType.pkce,
          pkceAsyncStorage: BrowserAsyncStorage(),
          autoRefreshToken: true,
        ),
      );

  /// Devuelve la sesión guardada si sigue siendo válida (renueva con el refresh token si hace falta).
  Future<void> restoreSession() async {
    final saved = _read();
    if (saved == null) return;
    try {
      await client.auth.recoverSession(saved);
    } on Object {
      _write(null);
    }
  }

  @override
  app.User? get currentUser => _map(client.auth.currentUser);

  @override
  Stream<app.User?> get changes => client.auth.onAuthStateChange.map((event) => _map(event.session?.user));

  @override
  Future<void> completeRedirect() async {
    final uri = Uri.parse(web.window.location.href);
    final error = uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
    final code = uri.queryParameters['code'];
    if (error == null && code == null) return;
    _cleanUrl(uri);
    if (error != null) throw Exception(error);
    await client.auth.exchangeCodeForSession(code!);
  }

  @override
  Future<void> signInWithGoogle() async {
    final response = await client.auth.getOAuthSignInUrl(provider: sb.OAuthProvider.google, redirectTo: web.window.location.origin);
    web.window.location.assign(response.url);
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut();
    _write(null);
  }

  /// Quita `?code=…` de la barra de direcciones sin recargar y conserva la ruta con hash.
  void _cleanUrl(Uri uri) => web.window.history.replaceState(null, '', '${uri.path}${uri.hasFragment ? '#${uri.fragment}' : ''}');

  // Misma construcción de nombre y avatar que AuthRepository de la app móvil.
  app.User? _map(sb.User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const {};
    String? text(String key) {
      final value = meta[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    final email = user.email?.trim();
    return app.User(
      id: user.id,
      name: text('full_name') ?? text('name') ?? (email != null && email.isNotEmpty ? email : 'User'),
      avatarUrl: meta['avatar_url']?.toString() ?? meta['picture']?.toString() ?? '',
      email: user.email,
    );
  }

  String? _read() {
    try {
      return web.window.localStorage.getItem(_sessionKey);
    } on Object {
      return null;
    }
  }

  void _write(String? value) {
    try {
      if (value == null) {
        web.window.localStorage.removeItem(_sessionKey);
      } else {
        web.window.localStorage.setItem(_sessionKey, value);
      }
    } on Object {
      // sin almacenamiento: la sesión vive sólo en memoria
    }
  }
}
