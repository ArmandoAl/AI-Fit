import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/user_model.dart' as app_model;

/// Sesión resuelta en [main] antes de que el router consuma la URL.
class WebAuthBootstrap {
  WebAuthBootstrap._();

  static app_model.User? _pendingUser;

  static app_model.User? takePendingUser() {
    final user = _pendingUser;
    _pendingUser = null;
    return user;
  }

  static Future<void> initialize(AuthRepository repository) async {
    if (!kIsWeb) return;

    final uri = Uri.base;
    debugPrint('🌐 Web auth bootstrap');
    debugPrint('   URL: $uri');
    debugPrint(
      '   isRedirectReturn: ${repository.isWebAuthRedirectReturn(uri)}',
    );

    _pendingUser = await repository.bootstrapWebSession();
    if (_pendingUser != null) {
      debugPrint('✅ Bootstrap: sesión lista (${_pendingUser!.email})');
    } else {
      debugPrint('ℹ️ Bootstrap: sin sesión');
    }
  }
}
