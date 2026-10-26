import 'package:equatable/equatable.dart';
import '../../domain/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Arranque inicial (splash / comprobar sesión).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Usuario pulsó login; no redirigir a splash.
class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
