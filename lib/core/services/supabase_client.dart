import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Environment constants for Supabase configuration.
/// Injected securely at compile-time via --dart-define.
const String supabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');

const String supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

/// Service responsible for managing Supabase client lifecycle.
///
/// Ensures safe initialization without crashing if environment variables
/// are missing during local development or CI pipelines.
class AppSupabaseClient {
  AppSupabaseClient._();

  static bool _isInitialized = false;

  /// Returns true if both SUPABASE_URL and SUPABASE_ANON_KEY are present in the environment.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Returns true if Supabase SDK was successfully initialized.
  static bool get isInitialized => _isInitialized;

  /// Returns the active [SupabaseClient] instance if initialized, or null otherwise.
  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initializes Supabase SDK if environment credentials are provided via --dart-define.
  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        '⚠️ [AppSupabaseClient] SUPABASE_URL and/or SUPABASE_ANON_KEY not provided via --dart-define. '
        'Supabase client running uninitialized.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('✅ [AppSupabaseClient] Supabase initialized successfully.');
    } catch (e) {
      _isInitialized = false;
      debugPrint('⚠️ [AppSupabaseClient] Failed to initialize Supabase: $e');
    }
  }
}
