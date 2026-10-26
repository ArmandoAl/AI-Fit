import 'package:equatable/equatable.dart';
import '../../domain/user_model.dart' as app_model;

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Firebase Auth cambió la sesión (popup, redirect o nativo).
class AuthSessionChanged extends AuthEvent {
  final app_model.User? user;

  const AuthSessionChanged(this.user);

  @override
  List<Object?> get props => [user];
}
