import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/twilio/twilio_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage();
  final SupabaseClient supabase = Supabase.instance.client;

  static const _kAccessTokenKey = 'supabase_access_token';
  static const _kRefreshTokenKey = 'supabase_refresh_token';
  static const _kOtpKey = 'pending_otp';
  static const _kOtpPhoneKey = 'pending_otp_phone';

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

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
    _currentUserId = null;
  }

  static Future<bool> sendOtp(String phone) async {
    try {
      // Generate OTP and send via Twilio
      final otp = TwilioService.generateOTP();

      // Store OTP temporarily for verification
      await instance._storage.write(key: _kOtpKey, value: otp);
      await instance._storage.write(key: _kOtpPhoneKey, value: phone);

      // Send OTP via Twilio
      final success = await TwilioService.sendOTP(phoneNumber: phone, otp: otp);

      if (success) {
        print('OTP sent successfully to $phone');
        return true;
      } else {
        print('Failed to send OTP to $phone');
        // Clear stored OTP on failure
        await instance._storage.delete(key: _kOtpKey);
        await instance._storage.delete(key: _kOtpPhoneKey);
        return false;
      }
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  static Future<User?> verifyOtpAndSignUp({
    required String phone,
    required String otp,
    required String fullName,
    required String role,
  }) async {
    try {
      // Verify OTP against stored value
      final storedOtp = await instance._storage.read(key: _kOtpKey);
      final storedPhone = await instance._storage.read(key: _kOtpPhoneKey);

      // Verify OTP matches and phone matches
      if (storedOtp == null || storedOtp != otp) {
        throw 'Invalid OTP';
      }
      if (storedPhone == null || storedPhone != phone) {
        throw 'Phone number mismatch';
      }

      // Clear OTP after successful verification
      await instance._storage.delete(key: _kOtpKey);
      await instance._storage.delete(key: _kOtpPhoneKey);

      final email = '$phone@albocarride.com';
      final password = 'password'; // In a real app, generate a secure password

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role, 'phone': phone},
      );

      if (authResponse.user != null) {
        final user = authResponse.user!;
        // Save profile
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
          'role': role,
          'phone': phone,
        });

        if (role == 'driver') {
          await Supabase.instance.client.from('drivers').upsert({'id': user.id});
        }

        await instance.saveSession(authResponse.session!);
        return user;
      }
      return null;
    } catch (e) {
      print('Error during sign up: $e');
      // Attempt to sign in if user already exists
      if (e.toString().contains('user_already_exists')) {
        return await _signIn(phone: phone);
      }
      return null;
    }
  }
  
  static Future<User?> _signIn({required String phone}) async {
    try {
      final email = '$phone@albocarride.com';
      final password = 'password'; // Use the same password as in signUp

      final signInResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (signInResponse.user != null) {
        await instance.saveSession(signInResponse.session!);
        return signInResponse.user;
      }
      return null;
    } catch(e) {
      print('Error during sign in: $e');
      return null;
    }
  }
    // Static methods for backward compatibility
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
}
