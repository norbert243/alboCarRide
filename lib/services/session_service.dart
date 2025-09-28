import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified Session Management Service
class SessionService with WidgetsBindingObserver {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _sessionExpiryKey = 'session_expiry';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Singleton instance
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  bool _initialized = false;

  /// Initialize service (called in main.dart)
  void initialize() {
    if (_initialized) return;

    WidgetsBinding.instance.addObserver(this);
    _initialized = true;

    _supabase.auth.onAuthStateChange.listen((event) async {
      final session = event.session;
      if (session != null) {
        debugPrint('[SessionService] Session updated/refreshed.');
        await _saveSessionToLocalStorage(session);
      } else {
        debugPrint('[SessionService] User logged out.');
        await clearSession();
      }
    });
  }

  /// Silent refresh when app resumes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        final session = _supabase.auth.currentSession;
        if (session != null) {
          await _supabase.auth.refreshSession();
          debugPrint('[SessionService] Silent refresh successful.');
        }
      } catch (e) {
        debugPrint('[SessionService] Silent refresh failed: $e');
        await logEvent('session_error', 'Silent refresh failed: $e');
      }
    }
  }

  /// Save session to local storage
  Future<void> _saveSessionToLocalStorage(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    final user = _supabase.auth.currentUser;

    if (user != null) {
      final userData = user.userMetadata ?? {};
      final expiry = session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : DateTime.now().add(const Duration(days: 30));

      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userIdKey, user.id);
      await prefs.setString(_userPhoneKey, userData['phone']?.toString() ?? '');
      await prefs.setString(
        _userRoleKey,
        userData['role']?.toString() ?? 'customer',
      );
      await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());
    }
  }

  /// Telemetry logging (to DB or external service)
  Future<void> logEvent(String type, String message) async {
    try {
      await _supabase.from('telemetry_logs').insert({
        'type': type,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SessionService] Failed to log event: $e');
      // Fallback to console logging if DB insert fails
      debugPrint('[Telemetry] $type: $message');
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentSession != null;

  /// Check if local session is valid
  Future<bool> hasValidLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return false;

    final expiryString = prefs.getString(_sessionExpiryKey);
    if (expiryString != null) {
      try {
        final expiry = DateTime.parse(expiryString);
        return expiry.isAfter(DateTime.now());
      } catch (e) {
        await logEvent('session_error', 'Failed to parse expiry date: $e');
        return false;
      }
    }
    return false;
  }

  /// Get session data from local storage
  Future<Map<String, dynamic>?> getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return null;

    final expiryString = prefs.getString(_sessionExpiryKey);
    if (expiryString != null) {
      try {
        final expiry = DateTime.parse(expiryString);
        if (expiry.isBefore(DateTime.now())) {
          await clearSession();
          return null;
        }
      } catch (e) {
        await logEvent('session_error', 'Failed to parse expiry date: $e');
        return null;
      }
    }

    return {
      'userId': prefs.getString(_userIdKey),
      'userPhone': prefs.getString(_userPhoneKey),
      'userRole': prefs.getString(_userRoleKey),
      'expiry': expiryString != null ? DateTime.parse(expiryString) : null,
    };
  }

  /// Force logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
    await clearSession();
    await logEvent('session_logout', 'User logged out manually');
  }

  /// Clear local session
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_sessionExpiryKey);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get user phone
  Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  /// Get user role
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Synchronize sessions between Supabase and local storage
  Future<void> synchronizeSessions() async {
    try {
      final supabaseSession = _supabase.auth.currentSession;
      final hasLocalSession = await hasValidLocalSession();

      if (supabaseSession != null && !hasLocalSession) {
        await _saveSessionToLocalStorage(supabaseSession);
        await logEvent('session_sync', 'Restored local session from Supabase');
      } else if (!isAuthenticated && hasLocalSession) {
        await clearSession();
        await logEvent(
          'session_sync',
          'Cleared local session (no Supabase session)',
        );
      }
    } catch (e) {
      await logEvent('session_error', 'Session synchronization failed: $e');
    }
  }

  /// Dispose observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }

  /// Static methods for backward compatibility
  static Future<void> saveSessionStatic({
    required String userId,
    required String userPhone,
    required String userRole,
    required DateTime expiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userPhoneKey, userPhone);
    await prefs.setString(_userRoleKey, userRole);
    await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());
  }

  static Future<void> clearSessionStatic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_sessionExpiryKey);
  }

  static Future<bool> isLoggedInStatic() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (isLoggedIn) {
      final expiryString = prefs.getString(_sessionExpiryKey);
      if (expiryString != null) {
        try {
          final expiry = DateTime.parse(expiryString);
          if (expiry.isBefore(DateTime.now())) {
            await SessionService.clearSessionStatic();
            return false;
          }
          return true;
        } catch (e) {
          await SessionService.clearSessionStatic();
          return false;
        }
      }
    }
    return isLoggedIn;
  }

  static Future<Map<String, dynamic>?> getSessionDataStatic() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return null;

    final expiryString = prefs.getString(_sessionExpiryKey);
    if (expiryString != null) {
      try {
        final expiry = DateTime.parse(expiryString);
        if (expiry.isBefore(DateTime.now())) {
          await SessionService.clearSessionStatic();
          return null;
        }
      } catch (e) {
        await SessionService.clearSessionStatic();
        return null;
      }
    }

    return {
      'userId': prefs.getString(_userIdKey),
      'userPhone': prefs.getString(_userPhoneKey),
      'userRole': prefs.getString(_userRoleKey),
      'expiry': expiryString != null ? DateTime.parse(expiryString) : null,
    };
  }

  static Future<String?> getUserIdStatic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUserPhoneStatic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  static Future<String?> getUserRoleStatic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<bool> hasValidSessionStatic() async {
    final sessionData = await SessionService.getSessionDataStatic();
    return sessionData != null;
  }
}
