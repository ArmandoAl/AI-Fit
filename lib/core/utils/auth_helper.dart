import 'package:flutter/foundation.dart';
import '../services/supabase_client.dart';

/// Helper class for authentication-related utilities
/// 
/// Provides centralized methods to get the current user's ID
/// and validate authentication state with Supabase Auth.
class AuthHelper {
  /// Get the current user's ID
  /// 
  /// Returns null if no user is authenticated.
  /// Throws an exception if a mock user ID is detected.
  static String? getCurrentUserId() {
    final user = AppSupabaseClient.client?.auth.currentUser;
    if (user == null) {
      return null;
    }

    final uid = user.id;
    
    // Validate that we're not using a mock ID
    if (uid.startsWith('mock_') || uid.contains('mock_user')) {
      debugPrint('❌ ERROR: Detected mock user ID: $uid');
      throw Exception('Invalid authentication state. Please log in with Google.');
    }

    return uid;
  }

  /// Get the current user's ID, throwing if not authenticated
  /// 
  /// Throws an exception if:
  /// - No user is authenticated
  /// - A mock user ID is detected
  static String requireCurrentUserId() {
    final uid = getCurrentUserId();
    if (uid == null) {
      throw Exception('User not authenticated. Please log in.');
    }
    return uid;
  }

  /// Check if a user is currently authenticated
  static bool isAuthenticated() {
    return AppSupabaseClient.client?.auth.currentUser != null;
  }

  /// Validate that a provided userId matches the current authenticated user
  /// 
  /// Throws an exception if:
  /// - No user is authenticated
  /// - The provided userId doesn't match the current user's ID
  /// - A mock user ID is detected
  static void validateUserId(String userId) {
    final currentUid = requireCurrentUserId();
    
    if (userId.startsWith('mock_') || userId.contains('mock_user')) {
      debugPrint('❌ ERROR: Provided userId is a mock ID: $userId');
      throw Exception('Invalid user ID format. Please log in with Google.');
    }
    
    if (currentUid != userId) {
      debugPrint('❌ User ID mismatch:');
      debugPrint('   Current user: $currentUid');
      debugPrint('   Provided: $userId');
      throw Exception('User ID mismatch. The provided ID does not match the authenticated user.');
    }
  }
}
