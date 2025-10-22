import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionDebugService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _sessionExpiryKey = 'session_expiry';

  static Future<Map<String, dynamic>> debugSessionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final supabase = Supabase.instance.client;

    final debugInfo = <String, dynamic>{};

    // Check local session storage
    debugInfo['local_session'] = {
      'is_logged_in': prefs.getBool(_isLoggedInKey) ?? false,
      'user_id': prefs.getString(_userIdKey),
      'user_phone': prefs.getString(_userPhoneKey),
      'user_role': prefs.getString(_userRoleKey),
      'session_expiry': prefs.getString(_sessionExpiryKey),
    };

    // Check Supabase auth session
    final supabaseSession = supabase.auth.currentSession;
    final supabaseUser = supabase.auth.currentUser;

    debugInfo['supabase_session'] = {
      'session_exists': supabaseSession != null,
      'user_exists': supabaseUser != null,
      'user_id': supabaseUser?.id,
      'user_email': supabaseUser?.email,
      'session_expiry': supabaseSession?.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              supabaseSession!.expiresAt! * 1000,
            ).toIso8601String()
          : null,
    };

    // Check session validity
    final localIsLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final expiryString = prefs.getString(_sessionExpiryKey);
    DateTime? expiry;

    if (expiryString != null) {
      try {
        expiry = DateTime.parse(expiryString);
      } catch (e) {
        debugInfo['local_session_error'] = 'Failed to parse expiry date: $e';
      }
    }

    debugInfo['session_validity'] = {
      'local_session_valid':
          localIsLoggedIn && expiry != null && expiry.isAfter(DateTime.now()),
      'supabase_session_valid': supabaseSession != null,
      'sessions_synced': _areSessionsSynced(debugInfo),
    };

    return debugInfo;
  }

  static bool _areSessionsSynced(Map<String, dynamic> debugInfo) {
    final local = debugInfo['local_session'] as Map<String, dynamic>;
    final supabase = debugInfo['supabase_session'] as Map<String, dynamic>;

    final localUserId = local['user_id'] as String?;
    final supabaseUserId = supabase['user_id'] as String?;

    // If both sessions exist, check if they're for the same user
    if (localUserId != null && supabaseUserId != null) {
      return localUserId == supabaseUserId;
    }

    // If one session exists and the other doesn't, they're not synced
    if ((localUserId != null && supabaseUserId == null) ||
        (localUserId == null && supabaseUserId != null)) {
      return false;
    }

    // If both sessions don't exist, they're technically "synced" (both missing)
    return true;
  }

  static Future<void> clearAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final supabase = Supabase.instance.client;

    // Clear local session
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_sessionExpiryKey);

    // Clear Supabase session
    await supabase.auth.signOut();
  }

  static Future<void> forceSessionSync() async {
    final prefs = await SharedPreferences.getInstance();
    final supabase = Supabase.instance.client;

    final supabaseSession = supabase.auth.currentSession;
    final supabaseUser = supabase.auth.currentUser;

    if (supabaseSession != null && supabaseUser != null) {
      // Save Supabase session to local storage
      final expiry = supabaseSession.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              supabaseSession.expiresAt! * 1000,
            )
          : DateTime.now().add(const Duration(days: 30));

      final userData = supabaseUser.userMetadata ?? {};

      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userIdKey, supabaseUser.id);
      await prefs.setString(_userPhoneKey, userData['phone']?.toString() ?? '');
      await prefs.setString(
        _userRoleKey,
        userData['role']?.toString() ?? 'customer',
      );
      await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());
    } else {
      // Clear local session if no Supabase session
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_sessionExpiryKey);
    }
  }

  static Future<String> getDebugReport() async {
    final debugInfo = await debugSessionStatus();

    final report = StringBuffer();
    report.writeln('=== SESSION DEBUG REPORT ===');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln();

    // Local Session Info
    report.writeln('LOCAL SESSION STORAGE:');
    final localSession = debugInfo['local_session'] as Map<String, dynamic>;
    report.writeln('  is_logged_in: ${localSession['is_logged_in']}');
    report.writeln('  user_id: ${localSession['user_id'] ?? "null"}');
    report.writeln('  user_phone: ${localSession['user_phone'] ?? "null"}');
    report.writeln('  user_role: ${localSession['user_role'] ?? "null"}');
    report.writeln(
      '  session_expiry: ${localSession['session_expiry'] ?? "null"}',
    );

    // Check expiry validity
    final expiryString = localSession['session_expiry'] as String?;
    if (expiryString != null) {
      try {
        final expiry = DateTime.parse(expiryString);
        final isValid = expiry.isAfter(DateTime.now());
        report.writeln(
          '  expiry_valid: $isValid (${isValid ? "VALID" : "EXPIRED"})',
        );
      } catch (e) {
        report.writeln('  expiry_valid: ERROR - $e');
      }
    }
    report.writeln();

    // Supabase Session Info
    report.writeln('SUPABASE AUTH SESSION:');
    final supabaseSession =
        debugInfo['supabase_session'] as Map<String, dynamic>;
    report.writeln('  session_exists: ${supabaseSession['session_exists']}');
    report.writeln('  user_exists: ${supabaseSession['user_exists']}');
    report.writeln('  user_id: ${supabaseSession['user_id'] ?? "null"}');
    report.writeln('  user_email: ${supabaseSession['user_email'] ?? "null"}');
    report.writeln(
      '  session_expiry: ${supabaseSession['session_expiry'] ?? "null"}',
    );
    report.writeln();

    // Session Validity
    report.writeln('SESSION VALIDITY:');
    final validity = debugInfo['session_validity'] as Map<String, dynamic>;
    report.writeln('  local_session_valid: ${validity['local_session_valid']}');
    report.writeln(
      '  supabase_session_valid: ${validity['supabase_session_valid']}',
    );
    report.writeln('  sessions_synced: ${validity['sessions_synced']}');
    report.writeln();

    // Recommendations
    report.writeln('RECOMMENDATIONS:');
    if (!validity['sessions_synced']) {
      report.writeln('  ⚠️  Sessions are not synchronized');
      report.writeln('  💡 Run forceSessionSync() to synchronize sessions');
    }

    if (!validity['local_session_valid'] &&
        validity['supabase_session_valid'] as bool) {
      report.writeln('  ⚠️  Local session invalid but Supabase session valid');
      report.writeln('  💡 Run forceSessionSync() to restore local session');
    }

    if (validity['local_session_valid'] as bool &&
        !validity['supabase_session_valid']) {
      report.writeln('  ⚠️  Local session valid but Supabase session invalid');
      report.writeln('  💡 User needs to re-authenticate');
    }

    if (!validity['local_session_valid'] &&
        !validity['supabase_session_valid']) {
      report.writeln('  ✅ No valid sessions - user needs to log in');
    }

    if (validity['local_session_valid'] as bool &&
        validity['supabase_session_valid'] as bool &&
        validity['sessions_synced'] as bool) {
      report.writeln('  ✅ Sessions are properly synchronized and valid');
    }

    return report.toString();
  }
}
