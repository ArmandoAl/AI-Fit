import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_client.dart';
import '../domain/user_model.dart' as app_model;

/// Repositorio de Autenticación migrado 100% a Supabase Auth.
/// Erradica por completo las dependencias de FirebaseAuth y Firestore.
class AuthRepository {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInit;

  static const String _webClientId =
      '268248668862-f1fp960traqm1i0t6ir8sms4qt23339d.apps.googleusercontent.com';

  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInit ??= _googleSignIn.initialize(
      serverClientId: _webClientId,
    );
  }

  app_model.User? _toAppUser(User user) {
    final meta = user.userMetadata ?? {};
    final name = (meta['full_name']?.toString().trim().isNotEmpty ?? false)
        ? meta['full_name'].toString().trim()
        : (meta['name']?.toString().trim().isNotEmpty ?? false)
            ? meta['name'].toString().trim()
            : (user.email?.trim().isNotEmpty ?? false)
                ? user.email!.trim()
                : 'User';
    final avatar = meta['avatar_url']?.toString() ??
        meta['picture']?.toString() ??
        '';

    return app_model.User(
      id: user.id,
      name: name,
      avatarUrl: avatar,
      email: user.email,
    );
  }

  Stream<app_model.User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map(
        (data) => data.session?.user == null ? null : _toAppUser(data.session!.user),
      );

  app_model.User? get currentUser {
    final u = _supabase.auth.currentUser;
    return u == null ? null : _toAppUser(u);
  }

  /// URL de retorno tras autenticación OAuth (hash con access_token o query con code).
  bool isWebAuthRedirectReturn(Uri uri) {
    if (!kIsWeb) return false;
    final frag = uri.fragment;
    final query = uri.queryParameters;
    return frag.contains('access_token=') ||
        frag.contains('refresh_token=') ||
        query.containsKey('code') ||
        query.containsKey('error');
  }

  /// Inicializa y sincroniza la sesión web persistente desde Supabase Auth.
  Future<app_model.User?> bootstrapWebSession() async {
    if (!kIsWeb) return null;

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        debugPrint('✅ [AuthRepository] bootstrap session found: ${user.email}');
        await _syncUserToProfiles(user);
        return _toAppUser(user);
      }
    } catch (e) {
      debugPrint('⚠️ [AuthRepository] bootstrap session error: $e');
    }

    return null;
  }

  Future<app_model.User?> signInWithGoogle() async {
    try {
      debugPrint('🔐 Google Sign-In with Supabase Auth - Starting...');
      debugPrint('   kIsWeb: $kIsWeb');
      debugPrint('   Platform: ${defaultTargetPlatform.name}');

      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      }

      final user = await _signInWithGoogleNative();
      if (user != null) {
        await _syncUserToProfiles(user);
        _logAuthenticatedUser(user);
        return _toAppUser(user);
      }
      return null;
    } on AuthException catch (e) {
      debugPrint('❌ Supabase Auth Error: ${e.message}');
      throw Exception('Google Sign-In Error: ${e.message}');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('⚠️ Google Sign-In cancelled by user');
        return null;
      }
      debugPrint('❌ Google Sign-In Error: $e');
      throw Exception('Google Sign-In Error: $e');
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      throw Exception('Google Sign-In Error: $e');
    }
  }

  /// Flujo web mediante Supabase OAuth
  Future<app_model.User?> _signInWithGoogleWeb() async {
    debugPrint('🌐 Using Supabase signInWithOAuth (web)');
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _syncUserToProfiles(user);
      _logAuthenticatedUser(user);
      return _toAppUser(user);
    }
    return null;
  }

  /// Flujo nativo móvil con GoogleSignIn + Supabase signInWithIdToken
  Future<User?> _signInWithGoogleNative() async {
    await _ensureGoogleInitialized();
    debugPrint('✅ Google Sign-In initialized (native)');

    final googleUser = await _googleSignIn.authenticate();
    debugPrint('✅ Google user authenticated: ${googleUser.email}');

    final googleAuth = googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Google Sign-In failed: missing idToken');
    }

    final authResponse = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
    );

    return authResponse.user;
  }

  void _logAuthenticatedUser(User user) {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('✅ USUARIO AUTENTICADO EN SUPABASE AUTH');
    debugPrint('   UID: ${user.id}');
    debugPrint('   Email: ${user.email ?? 'N/A'}');
    debugPrint('═══════════════════════════════════════════════════');
  }

  /// Sincroniza el usuario autenticado con la tabla public.profiles.
  /// Garantiza que el registro exista usando únicamente columnas estándar existentes:
  /// id, updated_at, display_name y opcionalmente avatar_path.
  Future<void> ensureProfileSynced(User user) async {
    final meta = user.userMetadata ?? {};
    final name = (meta['full_name']?.toString().trim().isNotEmpty ?? false)
        ? meta['full_name'].toString().trim()
        : (meta['name']?.toString().trim().isNotEmpty ?? false)
            ? meta['name'].toString().trim()
            : (user.email?.trim().isNotEmpty ?? false)
                ? user.email!.trim()
                : 'User';
    final avatar = meta['avatar_url']?.toString() ??
        meta['picture']?.toString() ??
        '';

    final payload = <String, dynamic>{
      'id': user.id,
      'display_name': name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (avatar.isNotEmpty) {
      payload['avatar_path'] = avatar;
    }

    try {
      await _supabase.from('profiles').upsert(payload, onConflict: 'id');
      debugPrint('✅ [AuthRepository] Profile synced to public.profiles for ${user.id}');
    } catch (e) {
      debugPrint('⚠️ [AuthRepository] Profiles sync failed with full payload ($e). Retrying with minimal payload...');
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id');
        debugPrint('✅ [AuthRepository] Minimal profile synced to public.profiles for ${user.id}');
      } catch (fallbackError) {
        debugPrint('❌ [AuthRepository] Critical profiles sync failed: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> _syncUserToProfiles(User user) => ensureProfileSynced(user);

  Future<void> signOut() async {
    debugPrint('🔓 Sign out from Supabase');
    await _supabase.auth.signOut();
    if (kIsWeb) return;

    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.disconnect();
    } catch (_) {
      // No-op
    }
  }
}
