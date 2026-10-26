import 'package:supabase/supabase.dart';
import 'package:web/web.dart' as web;

/// `localStorage` como almacén asíncrono para el verificador PKCE de GoTrue (igual que supabase-js).
class BrowserAsyncStorage extends GotrueAsyncStorage {
  const BrowserAsyncStorage();

  @override
  Future<String?> getItem({required String key}) async => _safe<String?>(() => web.window.localStorage.getItem(key));

  @override
  Future<void> setItem({required String key, required String value}) async => _safe<void>(() => web.window.localStorage.setItem(key, value));

  @override
  Future<void> removeItem({required String key}) async => _safe<void>(() => web.window.localStorage.removeItem(key));

  static T? _safe<T>(T Function() action) {
    try {
      return action();
    } on Object {
      return null; // modo privado o almacenamiento bloqueado: la sesión sólo dura la pestaña
    }
  }
}
