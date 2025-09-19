import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:flutter/material.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  // Session keys
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _sessionExpiryKey = 'session_expiry';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _accessTokenKey = 'access_token';

  // Session configuration
  static const Duration _sessionDuration = Duration(days: 30);
  static const Duration _refreshThreshold = Duration(minutes: 5);
  static const Duration _sessionTimeout = Duration(minutes: 30);

  /// Initialize authentication service and restore session if available
  static Future<void> initialize() async {
    try {
      // Check if we have a valid session stored
      final hasValidSession = await _hasValidSecureSession();
      if (hasValidSession) {
        // Restore session from secure storage
        await _restoreSessionFromSecureStorage();
      }
    } catch (e) {
      print('Error initializing auth service: $e');
    }
  }

  /// Save session with secure storage for tokens
  static Future<void> saveSession({
    required String userId,
    required String userPhone,
    required String userRole,
    required DateTime expiry,
    String? accessToken,
    String? refreshToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save basic session info to shared preferences
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userPhoneKey, userPhone);
      await prefs.setString(_userRoleKey, userRole);
      await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());

      // Save sensitive tokens to secure storage
      if (accessToken != null) {
        await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      }
      if (refreshToken != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      }

      print('Session saved successfully for user: $userId');
    } catch (e) {
      print('Error saving session: $e');
      throw Exception('Failed to save session');
    }
  }

  /// Clear all session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear shared preferences
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_sessionExpiryKey);

      // Clear secure storage
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);

      // Clear Supabase session
      await _supabase.auth.signOut();

      print('Session cleared successfully');
    } catch (e) {
      print('Error clearing session: $e');
    }
  }

  /// Check if user is logged in with valid session
  static Future<bool> isLoggedIn() async {
    try {
      // Check local session validity first
      final hasLocalSession = await _hasValidLocalSession();
      if (!hasLocalSession) return false;

      // Check if session needs refresh
      if (await _needsRefresh()) {
        return await _refreshSession();
      }

      return true;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  /// Refresh session tokens automatically
  static Future<bool> _refreshSession() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        await clearSession();
        return false;
      }

      // Attempt to refresh session
      final response = await _supabase.auth.refreshSession();

      if (response.session != null) {
        // Save refreshed session
        await saveSession(
          userId: response.session!.user.id,
          userPhone: await getUserPhone() ?? '',
          userRole: await getUserRole() ?? '',
          expiry: DateTime.now().add(_sessionDuration),
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken,
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Error refreshing session: $e');
      await clearSession();
      return false;
    }
  }

  /// Check if session needs refresh
  static Future<bool> _needsRefresh() async {
    final expiryString = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getString(_sessionExpiryKey),
    );

    if (expiryString == null) return true;

    final expiry = DateTime.parse(expiryString);
    final timeUntilExpiry = expiry.difference(DateTime.now());

    return timeUntilExpiry <= _refreshThreshold;
  }

  /// Get session data with validation
  static Future<Map<String, dynamic>?> getSessionData() async {
    try {
      if (!await isLoggedIn()) return null;

      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString(_sessionExpiryKey);

      return {
        'userId': prefs.getString(_userIdKey),
        'userPhone': prefs.getString(_userPhoneKey),
        'userRole': prefs.getString(_userRoleKey),
        'expiry': expiryString != null ? DateTime.parse(expiryString) : null,
        'accessToken': await _secureStorage.read(key: _accessTokenKey),
        'refreshToken': await _secureStorage.read(key: _refreshTokenKey),
      };
    } catch (e) {
      print('Error getting session data: $e');
      return null;
    }
  }

  /// Check if session exists in secure storage
  static Future<bool> _hasValidSecureSession() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      return accessToken != null &&
          refreshToken != null &&
          await _hasValidLocalSession();
    } catch (e) {
      return false;
    }
  }

  /// Check local session validity
  static Future<bool> _hasValidLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return false;

    final expiryString = prefs.getString(_sessionExpiryKey);
    if (expiryString == null) return false;

    final expiry = DateTime.parse(expiryString);
    return expiry.isAfter(DateTime.now());
  }

  /// Restore session from secure storage
  static Future<void> _restoreSessionFromSecureStorage() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      if (accessToken != null && refreshToken != null) {
        // Set the tokens in Supabase client
        await _supabase.auth.setSession(accessToken);
        print('Session restored from secure storage');
      }
    } catch (e) {
      print('Error restoring session: $e');
      await clearSession();
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get user phone
  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Monitor session state changes
  static Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  /// Handle authentication errors with user feedback
  static void handleAuthError(BuildContext context, dynamic error) {
    print('Authentication error: $error');

    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          CustomToast.showError(
            context: context,
            message: 'Invalid credentials. Please try again.',
          );
          break;
        case 'Email not confirmed':
          CustomToast.showError(
            context: context,
            message: 'Please verify your email address.',
          );
          break;
        case 'User already registered':
          CustomToast.showError(
            context: context,
            message: 'User already exists. Please sign in.',
          );
          break;
        default:
          CustomToast.showError(
            context: context,
            message: 'Authentication failed: ${error.message}',
          );
      }
    } else if (error is PostgrestException) {
      CustomToast.showError(
        context: context,
        message: 'Database error: ${error.message}',
      );
    } else {
      CustomToast.showError(
        context: context,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }
}
