import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _sessionExpiryKey = 'session_expiry';

  static Future<void> saveSession({
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

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userPhoneKey);
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
      'userPhone': prefs.getString(_userPhoneKey),
      'userRole': prefs.getString(_userRoleKey),
      'expiry': expiryString != null ? DateTime.parse(expiryString) : null,
    };
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<bool> hasValidSession() async {
    final sessionData = await getSessionData();
    return sessionData != null;
  }

  /// Static method to get user ID (alias for getUserId)
  static Future<String?> getUserIdStatic() async {
    return getUserId();
  }

  /// Check if user is authenticated
  static Future<bool> get isAuthenticated async {
    return await isLoggedIn();
  }
}
