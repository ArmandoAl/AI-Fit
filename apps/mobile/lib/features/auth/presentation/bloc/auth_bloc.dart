import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/bootstrap/web_auth_bootstrap.dart';
import '../../../../core/services/worker_warmup_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart' as app_model;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  StreamSubscription<app_model.User?>? _sessionSubscription;

  AuthBloc({required this.authRepository}) : super(const AuthLoading()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthSessionChanged>(_onAuthSessionChanged);

    _sessionSubscription = authRepository.authStateChanges.listen((user) {
      add(AuthSessionChanged(user));
    });

    add(const AuthCheckRequested());
  }

  @override
  Future<void> close() {
    _sessionSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Web: sesión resuelta en main (getRedirectResult solo se consume una vez).
      final bootstrapUser = WebAuthBootstrap.takePendingUser();
      if (bootstrapUser != null) {
        debugPrint('✅ AuthBloc: sesión desde bootstrap web');
        WorkerWarmupService.warmUp();
        emit(AuthAuthenticated(bootstrapUser));
        return;
      }

      final user = authRepository.currentUser;
      if (user != null) {
        WorkerWarmupService.warmUp();
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      debugPrint('⚠️ AuthBloc check error: $e');
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint('🔵 AuthBloc: Login requested');
    emit(const AuthSigningIn());

    try {
      final user = await authRepository.signInWithGoogle();

      if (user != null) {
        debugPrint('✅ AuthBloc: Login exitoso (${user.id})');
        WorkerWarmupService.warmUp();
        emit(AuthAuthenticated(user));
        return;
      }

      // Popup cancelado o redirect en curso — Firebase stream puede confirmar sesión.
      if (authRepository.currentUser != null) {
        debugPrint('✅ AuthBloc: sesión detectada vía currentUser tras login');
        WorkerWarmupService.warmUp();
        emit(AuthAuthenticated(authRepository.currentUser!));
        return;
      }

      debugPrint('⚠️ AuthBloc: Login sin usuario (cancelado o pendiente)');
      emit(const AuthUnauthenticated());
    } catch (e) {
      debugPrint('❌ AuthBloc: Login error - $e');
      if (authRepository.currentUser != null) {
        WorkerWarmupService.warmUp();
        emit(AuthAuthenticated(authRepository.currentUser!));
        return;
      }
      emit(AuthError(e.toString()));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      emit(const AuthUnauthenticated());
    }
  }

  void _onAuthSessionChanged(
    AuthSessionChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.user != null) {
      if (state is AuthAuthenticated &&
          (state as AuthAuthenticated).user.id == event.user!.id) {
        return;
      }
      debugPrint('✅ AuthBloc: authStateChanges → autenticado');
      WorkerWarmupService.warmUp();
      emit(AuthAuthenticated(event.user!));
      return;
    }

    // Solo pasar a no autenticado si no estamos en medio de un login.
    if (state is AuthSigningIn || state is AuthLoading) return;
    if (state is AuthUnauthenticated) return;

    debugPrint('🔓 AuthBloc: authStateChanges → sin sesión');
    emit(const AuthUnauthenticated());
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await authRepository.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
