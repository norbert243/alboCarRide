import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:flutter/material.dart';

class EnhancedSessionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Session keys
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _sessionExpiryKey = 'session_expiry';
  static const String _lastActivityKey = 'last_activity';

  // Session configuration
  static const Duration _sessionDuration = Duration(days: 30);
  static const Duration _refreshThreshold = Duration(minutes: 5);
  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const Duration _inactivityTimeout = Duration(hours: 24);

  /// Enhanced session saving with automatic refresh tracking
  static Future<void> saveSession({
    required String userId,
    required String userPhone,
    required String userRole,
    required DateTime expiry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userPhoneKey, userPhone);
      await prefs.setString(_userRoleKey, userRole);
      await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());
      await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());

      print('Enhanced session saved for user: $userId');
    } catch (e) {
      print('Error saving enhanced session: $e');
      throw Exception('Failed to save session');
    }
  }

  /// Clear all session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_sessionExpiryKey);
      await prefs.remove(_lastActivityKey);

      await _supabase.auth.signOut();

      print('Enhanced session cleared successfully');
    } catch (e) {
      print('Error clearing enhanced session: $e');
    }
  }

  /// Comprehensive session validation with multiple checks
  static Future<bool> validateSession() async {
    try {
      // Check basic session existence
      if (!await _hasBasicSession()) return false;

      // Check session expiration
      if (await _isSessionExpired()) {
        await clearSession();
        return false;
      }

      // Check inactivity timeout
      if (await _isInactivityTimeout()) {
        await clearSession();
        return false;
      }

      // Update last activity timestamp
      await _updateLastActivity();

      // Check if session needs refresh
      if (await _needsRefresh()) {
        return await _attemptRefresh();
      }

      return true;
    } catch (e) {
      print('Error validating session: $e');
      return false;
    }
  }

  /// Check if session needs automatic refresh
  static Future<bool> _needsRefresh() async {
    final expiryString = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getString(_sessionExpiryKey),
    );

    if (expiryString == null) return true;

    final expiry = DateTime.parse(expiryString);
    final timeUntilExpiry = expiry.difference(DateTime.now());

    return timeUntilExpiry <= _refreshThreshold;
  }

  /// Attempt to refresh session tokens
  static Future<bool> _attemptRefresh() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      await _supabase.auth.refreshSession();

      // Update session expiry
      final newExpiry = DateTime.now().add(_sessionDuration);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionExpiryKey, newExpiry.toIso8601String());

      print('Session refreshed successfully');
      return true;
    } catch (e) {
      print('Error refreshing session: $e');
      await clearSession();
      return false;
    }
  }

  /// Check basic session existence
  static Future<bool> _hasBasicSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Check if session is expired
  static Future<bool> _isSessionExpired() async {
    final expiryString = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getString(_sessionExpiryKey),
    );

    if (expiryString == null) return true;

    final expiry = DateTime.parse(expiryString);
    return expiry.isBefore(DateTime.now());
  }

  /// Check inactivity timeout
  static Future<bool> _isInactivityTimeout() async {
    final lastActivityString = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getString(_lastActivityKey),
    );

    if (lastActivityString == null) return true;

    final lastActivity = DateTime.parse(lastActivityString);
    final timeSinceActivity = DateTime.now().difference(lastActivity);

    return timeSinceActivity > _inactivityTimeout;
  }

  /// Update last activity timestamp
  static Future<void> _updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  /// Get comprehensive session data
  static Future<Map<String, dynamic>?> getSessionData() async {
    try {
      if (!await validateSession()) return null;

      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString(_sessionExpiryKey);
      final lastActivityString = prefs.getString(_lastActivityKey);

      return {
        'userId': prefs.getString(_userIdKey),
        'userPhone': prefs.getString(_userPhoneKey),
        'userRole': prefs.getString(_userRoleKey),
        'expiry': expiryString != null ? DateTime.parse(expiryString) : null,
        'lastActivity': lastActivityString != null
            ? DateTime.parse(lastActivityString)
            : null,
        'needsRefresh': await _needsRefresh(),
        'isValid': await validateSession(),
      };
    } catch (e) {
      print('Error getting session data: $e');
      return null;
    }
  }

  /// Monitor session state and auto-refresh
  static Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  /// Handle authentication errors with detailed feedback
  static void handleAuthError(
    BuildContext context,
    dynamic error, {
    String? customMessage,
  }) {
    print('Authentication error: $error');

    String errorMessage = customMessage ?? 'An authentication error occurred.';

    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          errorMessage =
              'Invalid credentials. Please check your information and try again.';
          break;
        case 'Email not confirmed':
          errorMessage = 'Please verify your email address before signing in.';
          break;
        case 'User already registered':
          errorMessage = 'This account already exists. Please sign in instead.';
          break;
        case 'Token expired':
          errorMessage = 'Your session has expired. Please sign in again.';
          // Schedule session clearing without await to avoid blocking UI
          Future.microtask(() => clearSession());
          break;
        default:
          errorMessage = 'Authentication error: ${error.message}';
      }
    } else if (error is PostgrestException) {
      errorMessage = 'Database error: ${error.message}';
    } else if (error.toString().contains('network')) {
      errorMessage =
          'Network connection failed. Please check your internet connection.';
    } else if (error.toString().contains('timeout')) {
      errorMessage = 'Request timeout. Please try again.';
    }

    CustomToast.showError(context: context, message: errorMessage);
  }

  /// Get user ID with validation
  static Future<String?> getUserId() async {
    if (!await validateSession()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get user phone with validation
  static Future<String?> getUserPhone() async {
    if (!await validateSession()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  /// Get user role with validation
  static Future<String?> getUserRole() async {
    if (!await validateSession()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Check if user has a valid session
  static Future<bool> hasValidSession() async {
    return await validateSession();
  }

  /// Force session validation (useful after app resume)
  static Future<void> validateOnResume() async {
    try {
      if (await _hasBasicSession()) {
        final isValid = await validateSession();
        if (!isValid) {
          print('Session invalidated on app resume');
        }
      }
    } catch (e) {
      print('Error validating session on resume: $e');
    }
  }
}
