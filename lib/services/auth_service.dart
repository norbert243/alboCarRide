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
      print('🔐 AuthService.initialize: Starting initialization');
      print('🔐 AuthService.initialize: Checking for existing session...');

      // Check if we have a valid session stored
      final hasValidSession = await _hasValidSecureSession();
      print(
        '🔐 AuthService.initialize: hasValidSecureSession = $hasValidSession',
      );

      if (hasValidSession) {
        // Restore session from secure storage
        print(
          '🔐 AuthService.initialize: ✅ Valid session found, restoring from secure storage',
        );
        await _restoreSessionFromSecureStorage();
        print('🔐 AuthService.initialize: ✅ Session restoration completed');
      } else {
        print('🔐 AuthService.initialize: ❌ No valid secure session found');
        print('🔐 AuthService.initialize: User will need to log in again');
      }

      // Check Supabase session after restoration
      final supabaseSession = Supabase.instance.client.auth.currentSession;
      print(
        '🔐 AuthService.initialize: Supabase session after restore = ${supabaseSession != null ? "✅ EXISTS" : "❌ NULL"}',
      );

      // Additional debug: Check if we have tokens in secure storage
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      print(
        '🔐 AuthService.initialize: accessToken in storage = ${accessToken != null ? "EXISTS" : "NULL"}',
      );
      print(
        '🔐 AuthService.initialize: refreshToken in storage = ${refreshToken != null ? "EXISTS" : "NULL"}',
      );
    } catch (e) {
      print('❌ Error initializing auth service: $e');
      print('❌ Stack trace: ${e.toString()}');
    }
  }

  /// WhatsApp-style seamless authentication - check if user can be automatically logged in
  static Future<bool> canAutoLogin() async {
    try {
      print('🔐 AuthService.canAutoLogin: Checking for auto-login capability');

      // Check if we have valid tokens in secure storage
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      print(
        '🔐 AuthService.canAutoLogin: accessToken = ${accessToken != null ? "Exists" : "Null"}',
      );
      print(
        '🔐 AuthService.canAutoLogin: refreshToken = ${refreshToken != null ? "Exists" : "Null"}',
      );

      // If we have both tokens, we can attempt auto-login
      final canAutoLogin = accessToken != null && refreshToken != null;
      print('🔐 AuthService.canAutoLogin: canAutoLogin = $canAutoLogin');

      return canAutoLogin;
    } catch (e) {
      print('❌ Error checking auto-login capability: $e');
      return false;
    }
  }

  /// Attempt automatic login using stored tokens (WhatsApp-style)
  static Future<bool> attemptAutoLogin() async {
    try {
      print('🔐 AuthService.attemptAutoLogin: Starting automatic login');

      if (!await canAutoLogin()) {
        print(
          '🔐 AuthService.attemptAutoLogin: Cannot auto-login - missing tokens',
        );
        return false;
      }

      // Restore session from secure storage
      await _restoreSessionFromSecureStorage();

      // Verify the session was successfully restored
      final currentSession = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = currentSession != null;

      print(
        '🔐 AuthService.attemptAutoLogin: Auto-login ${isAuthenticated ? "✅ SUCCESS" : "❌ FAILED"}',
      );
      print(
        '🔐 AuthService.attemptAutoLogin: Session exists = ${isAuthenticated ? "Yes" : "No"}',
      );

      return isAuthenticated;
    } catch (e) {
      print('❌ Error during auto-login: $e');
      return false;
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
      print('🔐 AuthService.isLoggedIn: Starting session validation');

      // Check local session validity first
      final hasLocalSession = await _hasValidLocalSession();
      print('🔐 AuthService.isLoggedIn: hasLocalSession = $hasLocalSession');

      // Check if we have Supabase session
      final supabaseSession = Supabase.instance.client.auth.currentSession;
      print(
        '🔐 AuthService.isLoggedIn: supabaseSession = ${supabaseSession != null ? "EXISTS" : "NULL"}',
      );

      // If we have local session but no Supabase session, we're still considered logged in
      // The user will be redirected to login if Supabase session restoration fails
      if (hasLocalSession) {
        print('🔐 AuthService.isLoggedIn: ✅ User has local session data');
        return true;
      }

      print('🔐 AuthService.isLoggedIn: ❌ No valid local session found');
      return false;
    } catch (e) {
      print('❌ Error checking login status: $e');
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

      print(
        'AuthService._hasValidSecureSession: accessToken = ${accessToken != null ? "Exists" : "Null"}',
      );
      print(
        'AuthService._hasValidSecureSession: refreshToken = ${refreshToken != null ? "Exists" : "Null"}',
      );

      final hasTokens = accessToken != null && refreshToken != null;
      final hasLocalSession = await _hasValidLocalSession();

      print(
        'AuthService._hasValidSecureSession: hasTokens = $hasTokens, hasLocalSession = $hasLocalSession',
      );

      return hasTokens && hasLocalSession;
    } catch (e) {
      print('AuthService._hasValidSecureSession: Error = $e');
      return false;
    }
  }

  /// Check local session validity
  static Future<bool> _hasValidLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    print('AuthService._hasValidLocalSession: isLoggedIn = $isLoggedIn');

    if (!isLoggedIn) return false;

    final expiryString = prefs.getString(_sessionExpiryKey);
    print('AuthService._hasValidLocalSession: expiryString = $expiryString');
    if (expiryString == null) return false;

    final expiry = DateTime.parse(expiryString);
    final isValid = expiry.isAfter(DateTime.now());
    print(
      'AuthService._hasValidLocalSession: expiry = $expiry, isValid = $isValid',
    );
    return isValid;
  }

  /// Restore session from secure storage
  static Future<void> _restoreSessionFromSecureStorage() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      print(
        'AuthService._restoreSessionFromSecureStorage: accessToken = ${accessToken != null ? "Exists" : "Null"}',
      );
      print(
        'AuthService._restoreSessionFromSecureStorage: refreshToken = ${refreshToken != null ? "Exists" : "Null"}',
      );

      if (accessToken != null && refreshToken != null) {
        // Set the tokens in Supabase client using the correct method
        print(
          'AuthService._restoreSessionFromSecureStorage: Setting session in Supabase',
        );

        // Use the correct Supabase method to restore session
        // The setSession method expects an access token string
        try {
          await _supabase.auth.setSession(accessToken);
          print(
            'AuthService._restoreSessionFromSecureStorage: Session restored from secure storage',
          );

          // Verify the session was set
          final currentSession = _supabase.auth.currentSession;
          print(
            'AuthService._restoreSessionFromSecureStorage: Supabase session after restore = ${currentSession != null ? "Exists" : "Null"}',
          );

          if (currentSession == null) {
            print(
              'AuthService._restoreSessionFromSecureStorage: Session restoration failed, but keeping local session for manual login',
            );
            // Don't clear session immediately - let user try to login manually
            // await clearSession();
          }
        } catch (e) {
          print('Error setting session: $e');
          print(
            'This is normal if tokens are expired - user will need to login again',
          );
          // Don't clear session on error - let the user login manually
          // await clearSession();
        }
      } else {
        print(
          'AuthService._restoreSessionFromSecureStorage: Missing tokens, cannot restore session',
        );
        // Don't clear session if tokens are missing - user might have logged out
        // await clearSession();
      }
    } catch (e) {
      print('Error restoring session: $e');
      print('Keeping local session data for manual login');
      // Don't clear session on general errors
      // await clearSession();
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
