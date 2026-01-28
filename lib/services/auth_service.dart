import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/twilio/twilio_service.dart';

/// Result of checking if a phone number exists
class PhoneCheckResult {
  final bool exists;
  final String? userId;
  final String? fullName;
  final String? role;

  PhoneCheckResult({
    required this.exists,
    this.userId,
    this.fullName,
    this.role,
  });
}

/// Result of OTP verification and auth
class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult({required this.success, this.user, this.error});

  factory AuthResult.success(User user) => AuthResult(success: true, user: user);
  factory AuthResult.failure(String error) => AuthResult(success: false, error: error);
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  final SupabaseClient supabase = Supabase.instance.client;

  static const _kAccessTokenKey = 'supabase_access_token';
  static const _kRefreshTokenKey = 'supabase_refresh_token';
  static const _kOtpKey = 'pending_otp';
  static const _kOtpPhoneKey = 'pending_otp_phone';
  static const _kOtpTimestampKey = 'pending_otp_timestamp';

  // OTP expires after 5 minutes (300 seconds)
  static const int otpExpirySeconds = 300;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  /// Generate a consistent password from phone number
  static String _generatePassword(String phone) {
    final bytes = utf8.encode('albocar_${phone}_secret_salt_2024');
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32);
  }

  Future<void> initialize() async {
    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final accessToken = await _storage.read(key: _kAccessTokenKey);
      final refreshToken = await _storage.read(key: _kRefreshTokenKey);

      if (accessToken != null && refreshToken != null) {
        final response = await supabase.auth.setSession(refreshToken);
        if (response.session != null) {
          _currentUserId = response.session!.user.id;
          await saveSession(response.session!);
        } else {
          await clearSession();
        }
      }
    } catch (e) {
      await clearSession();
    }
  }

  Future<void> saveSession(Session session) async {
    await _storage.write(key: _kAccessTokenKey, value: session.accessToken);
    await _storage.write(key: _kRefreshTokenKey, value: session.refreshToken);
    _currentUserId = session.user.id;
  }

  Future<void> clearSession() async {
    await supabase.auth.signOut();
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
    await _clearOtpData();
    _currentUserId = null;
  }

  Future<void> _clearOtpData() async {
    await _storage.delete(key: _kOtpKey);
    await _storage.delete(key: _kOtpPhoneKey);
    await _storage.delete(key: _kOtpTimestampKey);
  }

  // ============================================================
  // PHONE-FIRST AUTH FLOW
  // ============================================================

  /// Step 1: Check if phone number exists in the database
  /// Returns user info if exists, null otherwise
  static Future<PhoneCheckResult> checkPhoneExists(String phone) async {
    try {
      final normalizedPhone = phone.trim();
      print('🔍 Checking if phone exists: $normalizedPhone');

      // First check profiles table
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, role, phone')
          .eq('phone', normalizedPhone)
          .maybeSingle();

      if (response != null) {
        print('✅ Phone found in profiles: ${response['full_name']}');
        return PhoneCheckResult(
          exists: true,
          userId: response['id'] as String?,
          fullName: response['full_name'] as String?,
          role: response['role'] as String?,
        );
      }

      // Also try to sign in to check if user exists in auth but not in profiles
      // This handles the edge case of orphaned auth users
      final email = '$normalizedPhone@albocarride.com';
      try {
        // Try with generated password
        final password = _generatePassword(normalizedPhone);
        final signInResult = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (signInResult.user != null) {
          print('✅ User found in auth (orphaned) - treating as existing user');
          await instance.saveSession(signInResult.session!);
          // Get role from user metadata if available
          final metadata = signInResult.user!.userMetadata;
          return PhoneCheckResult(
            exists: true,
            userId: signInResult.user!.id,
            fullName: metadata?['full_name'] as String? ?? 'User',
            role: metadata?['role'] as String? ?? 'customer',
          );
        }
      } catch (_) {
        // Try legacy password
        try {
          const legacyPassword = 'password';
          final signInResult = await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: legacyPassword,
          );
          if (signInResult.user != null) {
            print('✅ User found in auth with legacy password');
            await instance.saveSession(signInResult.session!);
            final metadata = signInResult.user!.userMetadata;
            return PhoneCheckResult(
              exists: true,
              userId: signInResult.user!.id,
              fullName: metadata?['full_name'] as String? ?? 'User',
              role: metadata?['role'] as String? ?? 'customer',
            );
          }
        } catch (_) {
          // User doesn't exist or wrong password - that's fine, treat as new
        }
      }

      print('📱 Phone not found - new user');
      return PhoneCheckResult(exists: false);
    } catch (e) {
      print('❌ Error checking phone: $e');
      return PhoneCheckResult(exists: false);
    }
  }

  /// Step 2: Send OTP with expiration timestamp
  static Future<bool> sendOtp(String phone) async {
    try {
      // Validate phone number format
      if (!phone.startsWith('+')) {
        print('❌ Phone number must include country code (e.g., +27...)');
        return false;
      }

      // Generate OTP
      final otp = TwilioService.generateOTP();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      print('🔐 Generated OTP: $otp for phone: $phone');

      // Send OTP via Twilio FIRST
      final success = await TwilioService.sendOTP(phoneNumber: phone, otp: otp);

      if (success) {
        // Store OTP with timestamp for expiry checking
        await instance._storage.write(key: _kOtpKey, value: otp);
        await instance._storage.write(key: _kOtpPhoneKey, value: phone);
        await instance._storage.write(key: _kOtpTimestampKey, value: timestamp);
        print('✅ OTP sent and stored with expiry timestamp');
        return true;
      } else {
        print('❌ Failed to send OTP via Twilio');
        await instance._clearOtpData();
        return false;
      }
    } catch (e) {
      print('❌ Error sending OTP: $e');
      await instance._clearOtpData();
      return false;
    }
  }

  /// Verify OTP (checks expiry and match)
  static Future<bool> _verifyOtp(String phone, String otp) async {
    final storedOtp = await instance._storage.read(key: _kOtpKey);
    final storedPhone = await instance._storage.read(key: _kOtpPhoneKey);
    final storedTimestamp = await instance._storage.read(key: _kOtpTimestampKey);

    print('🔍 Verifying OTP...');
    print('🔍 Entered: "$otp" | Stored: "$storedOtp"');
    print('🔍 Phone: "$phone" | Stored: "$storedPhone"');

    // Check if OTP data exists
    if (storedOtp == null || storedPhone == null || storedTimestamp == null) {
      print('❌ No OTP data found - request a new OTP');
      return false;
    }

    // Check expiry (5 minutes)
    final sentTime = int.tryParse(storedTimestamp) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (now - sentTime) ~/ 1000;

    if (elapsedSeconds > otpExpirySeconds) {
      print('❌ OTP expired (sent ${elapsedSeconds}s ago, max ${otpExpirySeconds}s)');
      await instance._clearOtpData();
      return false;
    }

    // Check phone match
    if (storedPhone.trim() != phone.trim()) {
      print('❌ Phone mismatch');
      return false;
    }

    // Check OTP match
    if (storedOtp.trim() != otp.trim()) {
      print('❌ OTP mismatch');
      return false;
    }

    print('✅ OTP verified successfully! (${elapsedSeconds}s elapsed)');
    return true;
  }

  /// Step 3a: Login existing user with OTP
  static Future<AuthResult> loginWithOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      // Verify OTP first
      if (!await _verifyOtp(phone, otp)) {
        final remaining = await getOtpRemainingTime();
        if (remaining <= 0) {
          return AuthResult.failure('OTP expired. Please request a new one.');
        }
        return AuthResult.failure('Invalid OTP. Please check and try again.');
      }

      // Clear OTP data after verification
      await instance._clearOtpData();

      // Sign in the existing user
      final user = await _signIn(phone: phone);
      if (user != null) {
        print('✅ Login successful for $phone');
        return AuthResult.success(user);
      }
      return AuthResult.failure('Login failed. Please try again or contact support.');
    } catch (e) {
      print('❌ Error during login: $e');
      return AuthResult.failure('Login failed: ${e.toString()}');
    }
  }

  /// Step 3b: Sign up new user with OTP
  static Future<AuthResult> signUpWithOtp({
    required String phone,
    required String otp,
    required String fullName,
    required String role,
  }) async {
    try {
      // Verify OTP first
      if (!await _verifyOtp(phone, otp)) {
        final remaining = await getOtpRemainingTime();
        if (remaining <= 0) {
          return AuthResult.failure('OTP expired. Please request a new one.');
        }
        return AuthResult.failure('Invalid OTP. Please check and try again.');
      }

      // Clear OTP data after verification
      await instance._clearOtpData();

      // Create Supabase user
      final email = '$phone@albocarride.com';
      final password = _generatePassword(phone);

      print('📝 Creating new user: $email');

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role, 'phone': phone},
      );

      if (authResponse.user != null) {
        final user = authResponse.user!;

        // Save profile to database
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
          'role': role,
          'phone': phone,
        });

        // Create driver record if driver
        if (role == 'driver') {
          await Supabase.instance.client.from('drivers').upsert({
            'id': user.id,
          });
        }

        await instance.saveSession(authResponse.session!);
        print('✅ Signup successful for $fullName ($role)');
        return AuthResult.success(user);
      }

      return AuthResult.failure('Signup failed. Please try again.');
    } catch (e) {
      print('❌ Error during sign up: $e');

      // If user already exists in auth but not in profiles, try to sign in
      if (e.toString().contains('user_already_exists')) {
        print('👤 User already exists in auth, attempting sign in...');
        final user = await _signIn(phone: phone);
        if (user != null) {
          // Update profile to ensure it exists
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'full_name': fullName,
            'role': role,
            'phone': phone,
          });
          return AuthResult.success(user);
        }
        // User exists but we can't sign in - password mismatch
        return AuthResult.failure(
          'Account exists but login failed. Please contact support or try a different phone number.'
        );
      }
      return AuthResult.failure('Signup failed: ${e.toString()}');
    }
  }

  /// Internal sign in method
  static Future<User?> _signIn({required String phone}) async {
    final email = '$phone@albocarride.com';

    // Try with generated password first
    try {
      final password = _generatePassword(phone);
      print('🔐 Attempting sign in for $email');

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('✅ Sign in successful!');
        await instance.saveSession(response.session!);
        return response.user;
      }
    } catch (e) {
      print('⚠️ Sign in with generated password failed: $e');
    }

    // Fallback: Try legacy password for old accounts
    try {
      const legacyPassword = 'password';
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: legacyPassword,
      );

      if (response.user != null) {
        print('✅ Sign in successful with legacy password');
        await instance.saveSession(response.session!);
        return response.user;
      }
    } catch (e) {
      print('❌ Sign in with legacy password also failed: $e');
    }

    return null;
  }

  /// Resend OTP (with rate limiting info)
  static Future<bool> resendOtp(String phone) async {
    // Clear old OTP first
    await instance._clearOtpData();
    // Send new OTP
    return await sendOtp(phone);
  }

  /// Get remaining OTP validity time in seconds (0 if expired)
  static Future<int> getOtpRemainingTime() async {
    final storedTimestamp = await instance._storage.read(key: _kOtpTimestampKey);
    if (storedTimestamp == null) return 0;

    final sentTime = int.tryParse(storedTimestamp) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (now - sentTime) ~/ 1000;
    final remaining = otpExpirySeconds - elapsedSeconds;

    return remaining > 0 ? remaining : 0;
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  static Future<bool> isAuthenticatedStatic() async {
    return instance._currentUserId != null;
  }

  static Future<String?> getUserIdStatic() async {
    return instance._currentUserId;
  }

  static Future<bool> attemptAutoLogin() async {
    await instance._restoreSession();
    return instance._currentUserId != null;
  }

  static Future<bool> isLoggedIn() async {
    return instance._currentUserId != null;
  }

  /// Get current user's profile
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (instance._currentUserId == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', instance._currentUserId!)
          .single();
      return response;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }
}
