import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';
  static const String _sessionExpiryKey = 'session_expiry';

  static Future<void> saveSession({
    required String userId,
    required String userEmail,
    required String userRole,
    required DateTime expiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userEmailKey, userEmail);
    await prefs.setString(_userRoleKey, userRole);
    await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_sessionExpiryKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    // Check if session is expired
    if (isLoggedIn) {
      final expiryString = prefs.getString(_sessionExpiryKey);
      if (expiryString != null) {
        final expiry = DateTime.parse(expiryString);
        if (expiry.isBefore(DateTime.now())) {
          // Session expired, clear it
          await clearSession();
          return false;
        }
        return true;
      }
    }
    return isLoggedIn;
  }

  static Future<Map<String, dynamic>?> getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return null;

    final expiryString = prefs.getString(_sessionExpiryKey);
    if (expiryString != null) {
      final expiry = DateTime.parse(expiryString);
      if (expiry.isBefore(DateTime.now())) {
        await clearSession();
        return null;
      }
    }

    return {
      'userId': prefs.getString(_userIdKey),
      'userEmail': prefs.getString(_userEmailKey),
      'userRole': prefs.getString(_userRoleKey),
      'expiry': expiryString != null ? DateTime.parse(expiryString) : null,
    };
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<bool> hasValidSession() async {
    final sessionData = await getSessionData();
    return sessionData != null;
  }
}
