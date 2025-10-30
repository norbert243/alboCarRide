import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage();
  final SupabaseClient supabase = Supabase.instance.client;

  static const _kAccessTokenKey = 'supabase_access_token';
  static const _kRefreshTokenKey = 'supabase_refresh_token';
  static const _kSessionExpiryKey = 'supabase_session_expires_at';

  // Session state tracking (preserved from existing implementation)
  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _currentUserRole;

  // Getters (preserved from existing implementation)
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;

  /// Call on app startup
  Future<void> initializeApp() async {
    // nothing heavy here — keep lightweight
  }

  /// Save session tokens to secure storage
  Future<void> saveSessionLocally(Session session) async {
    await _storage.write(key: _kAccessTokenKey, value: session.accessToken);
    await _storage.write(key: _kRefreshTokenKey, value: session.refreshToken);
    if (session.expiresAt != null) {
      await _storage.write(
        key: _kSessionExpiryKey,
        value: session.expiresAt.toString(),
      );
    }
  }

  /// Clears local session storage
  Future<void> clearLocalSession() async {
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
    await _storage.delete(key: _kSessionExpiryKey);

    // Clear local state
    _isAuthenticated = false;
    _currentUserId = null;
    _currentUserRole = null;
  }

  /// Try to restore the session from secure storage and rehydrate Supabase
  Future<bool> restoreSessionFromSecureStorage() async {
    try {
      final access = await _storage.read(key: _kAccessTokenKey);
      final refresh = await _storage.read(key: _kRefreshTokenKey);

      if (access == null || refresh == null) {
        print('❌ No tokens found in secure storage');
        return false;
      }

      print(
        '🔐 Found tokens in secure storage, attempting to restore session...',
      );

      // WhatsApp-style: Use refresh token to restore session
      try {
        // First try with refresh token (more reliable for expired sessions)
        await supabase.auth.setSession(refresh);
        print('✅ Session restored using refresh token');
      } catch (refreshError) {
        print('⚠️ Refresh token failed: $refreshError, trying access token...');

        // Fallback to access token
        try {
          await supabase.auth.setSession(access);
          print('✅ Session restored using access token');
        } catch (accessError) {
          print('❌ Access token also failed: $accessError');
          // Both tokens failed, clear storage and return false
          await clearLocalSession();
          return false;
        }
      }

      // WhatsApp-style: Wait a moment for session to be fully established
      await Future.delayed(const Duration(milliseconds: 500));

      // Update local state if session is restored
      final currentSession = supabase.auth.currentSession;
      final currentUser = supabase.auth.currentUser;

      if (currentSession != null && currentUser != null) {
        _currentUserId = currentUser.id;
        _isAuthenticated = true;

        // Fetch user role from profiles table
        final profileResponse = await supabase
            .from('profiles')
            .select('role')
            .eq('id', currentUser.id)
            .single()
            .catchError((_) => null);

        _currentUserRole = profileResponse['role'] ?? 'customer';

        print(
          '✅ Session restored successfully: User ${currentUser.id} authenticated',
        );
        print('🔐 Current user role: $_currentUserRole');
        return true;
      } else {
        print(
          '❌ Session restoration failed - no current session/user after token set',
        );
        await clearLocalSession();
        return false;
      }
    } catch (e) {
      print('❌ Error restoring session: $e');
      await clearLocalSession();
      return false;
    }
  }

  /// Call after successful sign-in / sign-up
  Future<void> handleSuccessfulAuth(Session session) async {
    await saveSessionLocally(session);
    // ensure supabase.auth has this session already; typically supabase sets this automatically

    // Update local state
    _currentUserId = session.user.id;
    _isAuthenticated = true;

    // Fetch user role from profiles table
    final profileResponse = await supabase
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .single()
        .catchError((_) => null);

    _currentUserRole = profileResponse['role'] ?? 'customer';
  }

  // Preserved methods from existing implementation
  // Sign up with phone number
  Future<Map<String, dynamic>> signUpWithPhone({
    required String phone,
    required String fullName,
    required String role,
  }) async {
    try {
      // Clean phone number
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

      // Send OTP
      await supabase.auth.signInWithOtp(
        phone: cleanPhone,
        data: {'full_name': fullName, 'role': role},
      );

      return {'success': true, 'message': 'OTP sent successfully'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send OTP: ${e.toString()}',
      };
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

      final response = await supabase.auth.verifyOTP(
        phone: cleanPhone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.session != null) {
        await handleSuccessfulAuth(response.session!);

        return {
          'success': true,
          'message': 'OTP verified successfully',
          'userId': _currentUserId,
          'role': _currentUserRole,
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid OTP or session not created',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'OTP verification failed: ${e.toString()}',
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      await clearLocalSession();
    } catch (e) {
      print('Sign out error: $e');
      // Force clear local state even if remote signout fails
      await clearLocalSession();
    }
  }

  // Check if user exists (for duplicate prevention)
  Future<bool> checkUserExists(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('phone', cleanPhone)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Preserved methods that were missing from the new implementation
  Future<void> initializeSession() async {
    await restoreSessionFromSecureStorage();
  }

  // Create driver profile with vehicle details
  Future<Map<String, dynamic>> createDriverProfile({
    required String driverId,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required String licensePlate,
    required int vehicleYear,
  }) async {
    try {
      print('🔧 Creating driver profile for: $driverId');

      // Debug authentication state
      final currentUser = supabase.auth.currentUser;
      final currentSession = supabase.auth.currentSession;
      print('🔐 Current auth state:');
      print('  - User ID: ${currentUser?.id}');
      print('  - Session exists: ${currentSession != null}');
      print('  - Driver ID matches auth: ${currentUser?.id == driverId}');

      if (currentUser?.id != driverId) {
        print(
          '⚠️ WARNING: Driver ID mismatch! Auth: ${currentUser?.id}, Provided: $driverId',
        );
      }

      // Insert complete driver record with all required fields
      await supabase.from('drivers').upsert({
        'id': driverId,
        'vehicle_type': vehicleType,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'license_plate': licensePlate,
        'vehicle_year': vehicleYear,
        'is_approved': false,
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('✅ Driver record created successfully');

      // Create wallet if missing
      print('💰 Creating driver wallet...');
      print('  - Driver ID for wallet: $driverId');
      print('  - Auth UID for RLS check: ${currentUser?.id}');

      final walletResult = await supabase.from('driver_wallets').upsert({
        'driver_id': driverId,
        'balance': 0.00,
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('✅ Driver wallet created successfully');

      return {
        'success': true,
        'message': 'Driver profile created successfully',
      };
    } catch (e) {
      print('❌ Error creating driver profile: $e');
      print('💡 Possible issues:');
      print('  - Authentication session not established');
      print('  - Driver ID mismatch with authenticated user');
      print('  - RLS policy still blocking despite policies being present');
      return {
        'success': false,
        'message': 'Failed to create driver profile: ${e.toString()}',
      };
    }
  }

  // Check driver approval status
  Future<Map<String, dynamic>> checkDriverApprovalStatus(
    String driverId,
  ) async {
    try {
      final response = await supabase
          .from('drivers')
          .select('is_approved')
          .eq('id', driverId)
          .single();

      final bool isApproved = response['is_approved'] ?? false;

      return {'success': true, 'isApproved': isApproved};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to check driver approval status: ${e.toString()}',
        'isApproved': false,
      };
    }
  }

  // Get current session
  Future<Session?> getCurrentSession() async {
    try {
      final access = await _storage.read(key: _kAccessTokenKey);
      final refresh = await _storage.read(key: _kRefreshTokenKey);

      if (access == null || refresh == null) {
        return null;
      }

      // Return the current session from Supabase if available
      final currentSession = supabase.auth.currentSession;
      if (currentSession != null) {
        return currentSession;
      }

      // If no current session, return null
      return null;
    } catch (e) {
      print('Error getting session: $e');
      return null;
    }
  }

  // Static methods for backward compatibility
  static Future<bool> isAuthenticatedStatic() async {
    return _instance._isAuthenticated;
  }

  static Future<String?> getUserIdStatic() async {
    return _instance._currentUserId;
  }

  static Future<bool> attemptAutoLogin() async {
    return await _instance.restoreSessionFromSecureStorage();
  }

  static Future<bool> isLoggedIn() async {
    return _instance._isAuthenticated;
  }

  static Future<void> saveSession(Session session) async {
    await _instance.handleSuccessfulAuth(session);
  }

  static Future<String?> getUserId() async {
    return _instance._currentUserId;
  }

  static Future<void> clearSession() async {
    await _instance.signOut();
  }

  static Future<void> initialize() async {
    await _instance.initializeSession();
  }

  /// Check if auto-login is possible by verifying tokens exist in secure storage
  Future<Map<String, dynamic>> canAutoLogin() async {
    try {
      final accessToken = await _storage.read(key: _kAccessTokenKey);
      final refreshToken = await _storage.read(key: _kRefreshTokenKey);

      final bool hasAccessToken = accessToken != null && accessToken.isNotEmpty;
      final bool hasRefreshToken =
          refreshToken != null && refreshToken.isNotEmpty;
      final bool canAutoLogin = hasAccessToken && hasRefreshToken;

      print('🔐 Session Integrity Check:');
      print('  accessToken = ${hasAccessToken ? "Exists" : "Missing"}');
      print('  refreshToken = ${hasRefreshToken ? "Exists" : "Missing"}');
      print('  canAutoLogin = $canAutoLogin');

      return {
        'accessTokenExists': hasAccessToken,
        'refreshTokenExists': hasRefreshToken,
        'canAutoLogin': canAutoLogin,
      };
    } catch (e) {
      print('❌ Error checking auto-login capability: $e');
      return {
        'accessTokenExists': false,
        'refreshTokenExists': false,
        'canAutoLogin': false,
      };
    }
  }
}
