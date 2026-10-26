import 'dart:async';

import 'package:aifit_core/features/auth/domain/user_model.dart';
import 'package:aifit_web/auth/auth_controller.dart';
import 'package:test/test.dart';

class FakeGateway implements AuthGateway {
  User? user;
  Object? redirectError, signInError, signOutError;
  final controller = StreamController<User?>.broadcast();
  int signIns = 0;

  @override
  User? get currentUser => user;
  @override
  Stream<User?> get changes => controller.stream;
  @override
  Future<void> completeRedirect() async {
    if (redirectError != null) throw redirectError!;
  }

  @override
  Future<void> signInWithGoogle() async {
    signIns++;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
    user = null;
  }
}

final ana = User(id: 'u1', name: 'Ana', avatarUrl: '');

void main() {
  late FakeGateway gateway;
  late AuthController auth;
  var changes = 0;

  setUp(() {
    gateway = FakeGateway();
    changes = 0;
    auth = AuthController(gateway, onChange: () => changes++);
  });
  tearDown(() => auth.dispose());

  test('empieza en «starting» y sin sesión pasa a signedOut', () async {
    expect(auth.status, AuthStatus.starting);
    await auth.start();
    expect(auth.status, AuthStatus.signedOut);
    expect(auth.user, isNull);
    expect(changes, greaterThan(0));
  });

  test('con sesión restaurada pasa a signedIn y reacciona a cambios posteriores', () async {
    gateway.user = ana;
    await auth.start();
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.user!.name, 'Ana');
    gateway.controller.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(auth.status, AuthStatus.signedOut);
  });

  test('un fallo al completar la redirección queda en «failed» con el motivo sin prefijos técnicos', () async {
    gateway.redirectError = Exception('PKCE: el verificador no coincide');
    await auth.start();
    expect(auth.status, AuthStatus.failed);
    expect(auth.error, 'No se pudo completar el acceso: PKCE: el verificador no coincide');
  });

  test('iniciar sesión delega en el gateway y un error se muestra sin perder el estado', () async {
    await auth.start();
    await auth.signIn();
    expect(gateway.signIns, 1);
    expect(auth.error, isNull);
    gateway.signInError = StateError('popup bloqueado');
    await auth.signIn();
    expect(auth.status, AuthStatus.failed);
    expect(auth.error, 'No se pudo iniciar el acceso con Google: popup bloqueado');
  });

  test('un acceso correcto posterior borra el error', () async {
    gateway.redirectError = Exception('x');
    await auth.start();
    expect(auth.error, isNotNull);
    gateway.controller.add(ana);
    await Future<void>.delayed(Duration.zero);
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.error, isNull);
  });

  test('cerrar sesión: éxito vuelve a signedOut; si falla conserva la sesión y avisa', () async {
    gateway.user = ana;
    await auth.start();
    gateway.signOutError = Exception('sin red');
    await auth.signOut();
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.error, 'No se pudo cerrar la sesión: sin red');
    gateway.signOutError = null;
    await auth.signOut();
    expect(auth.status, AuthStatus.signedOut);
  });
}
