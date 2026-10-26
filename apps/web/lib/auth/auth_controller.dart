import 'dart:async';

import 'package:aifit_core/features/auth/domain/user_model.dart';

/// Acceso a la autenticación del backend. La implementación real (Supabase + Google) vive en el adaptador web.
abstract interface class AuthGateway {
  User? get currentUser;
  Stream<User?> get changes;

  /// Completa el regreso de OAuth si la URL trae un `code` (o un error). Sin retorno pendiente no hace nada.
  Future<void> completeRedirect();

  /// Inicia el acceso con Google: el navegador sale hacia el proveedor y vuelve a esta página.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

enum AuthStatus { starting, signedOut, signedIn, failed }

/// Máquina de estados del acceso, sin navegador: se prueba en la VM.
class AuthController {
  AuthController(this._gateway, {this.onChange});

  final AuthGateway _gateway;
  void Function()? onChange;
  StreamSubscription<User?>? _subscription;

  AuthStatus status = AuthStatus.starting;
  User? user;
  String? error;

  Future<void> start() async {
    _subscription = _gateway.changes.listen((next) => _settle(next));
    try {
      await _gateway.completeRedirect();
      _settle(_gateway.currentUser);
    } on Object catch (e) {
      _fail('No se pudo completar el acceso: ${_clean(e)}');
    }
  }

  Future<void> signIn() async {
    error = null;
    try {
      await _gateway.signInWithGoogle();
    } on Object catch (e) {
      _fail('No se pudo iniciar el acceso con Google: ${_clean(e)}');
    }
  }

  Future<void> signOut() async {
    try {
      await _gateway.signOut();
    } on Object catch (e) {
      _fail('No se pudo cerrar la sesión: ${_clean(e)}');
      return;
    }
    _settle(null);
  }

  void dispose() => _subscription?.cancel();

  void _settle(User? next) {
    user = next;
    status = next == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    if (next != null) error = null;
    onChange?.call();
  }

  void _fail(String message) {
    error = message;
    status = user == null ? AuthStatus.failed : status;
    onChange?.call();
  }

  static String _clean(Object e) => e.toString().replaceFirst(RegExp(r'^(Exception|StateError|Bad state): '), '');
}
