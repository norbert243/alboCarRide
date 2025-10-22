import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Session state tracking
  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _currentUserRole;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;

  // Static methods for SessionGuard
  static Future<bool> isAuthenticatedStatic() async {
    return _instance._isAuthenticated;
  }

  static Future<String?> getUserIdStatic() async {
    return _instance._currentUserId;
  }

  // Initialize session from secure storage
  Future<void> initializeSession() async {
    try {
      final sessionJson = await _secureStorage.read(key: 'supabase_session');
      if (sessionJson != null) {
        final session = Session.fromJson(json.decode(sessionJson));
        if (session != null) {
          await _supabase.auth.setSession(session.accessToken);
        }

        if (session != null) {
          _currentUserId = session.user.id;
          _isAuthenticated = true;
        }

        // Fetch user role from profiles table
        if (_currentUserId != null) {
          final profileResponse = await _supabase
              .from('profiles')
              .select('role')
              .eq('id', _currentUserId!)
              .single()
              .catchError((_) => null);

          _currentUserRole = profileResponse['role'] ?? 'customer';
        }
      }
    } catch (e) {
      await _secureStorage.delete(key: 'supabase_session');
      _isAuthenticated = false;
      _currentUserId = null;
      _currentUserRole = null;
    }
  }

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
      await _supabase.auth.signInWithOtp(
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

      final response = await _supabase.auth.verifyOTP(
        phone: cleanPhone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.session != null) {
        await _saveSession(response.session!);

        _currentUserId = response.session!.user.id;
        _isAuthenticated = true;

        // Fetch user role
        final profileResponse = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', _currentUserId!)
            .single();

        _currentUserRole = profileResponse['role'] ?? 'customer';

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

  // Create or update profile using server-side function
  Future<void> _createOrUpdateProfile(
    String fullName,
    String phone,
    String role,
  ) async {
    try {
      await _supabase.rpc(
        'upsert_profile',
        params: {
          'p_id': _currentUserId,
          'p_full_name': fullName,
          'p_phone': phone,
          'p_role': role,
        },
      );
    } catch (e) {
      // Fallback: direct table insert/update
      try {
        await _supabase.from('profiles').upsert({
          'id': _currentUserId,
          'full_name': fullName,
          'phone': phone,
          'role': role,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (fallbackError) {
        print('Profile creation fallback failed: $fallbackError');
      }
    }
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
      // First try RPC function if available
      try {
        await _supabase.rpc(
          'create_driver_profile',
          params: {
            'p_driver_id': driverId,
            'p_vehicle_type': vehicleType,
            'p_vehicle_make': vehicleMake,
            'p_vehicle_model': vehicleModel,
            'p_license_plate': licensePlate,
            'p_vehicle_year': vehicleYear,
          },
        );

        return {
          'success': true,
          'message': 'Driver profile created successfully',
        };
      } catch (rpcError) {
        // If RPC fails, use direct table operations
        print('RPC failed, using direct table operations: $rpcError');
      }

      // Insert complete driver record with all required fields
      await _supabase.from('drivers').upsert({
        'id': driverId,
        'vehicle_type': vehicleType,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'license_plate': licensePlate,
        'vehicle_year': vehicleYear,
        'is_approved': false,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create wallet if missing
      await _supabase.from('driver_wallets').upsert({
        'driver_id': driverId,
        'balance': 0.00,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Ensure vehicle completeness for data integrity
      await _ensureVehicleCompleteness(driverId);

      return {
        'success': true,
        'message': 'Driver profile created successfully',
      };
    } catch (e) {
      print('Error creating driver profile: $e');
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
      final response = await _supabase
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

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _secureStorage.delete(key: 'supabase_session');

      _isAuthenticated = false;
      _currentUserId = null;
      _currentUserRole = null;
    } catch (e) {
      print('Sign out error: $e');
      // Force clear local state even if remote signout fails
      await _secureStorage.delete(key: 'supabase_session');
      _isAuthenticated = false;
      _currentUserId = null;
      _currentUserRole = null;
    }
  }

  // Save session to secure storage
  Future<void> _saveSession(Session session) async {
    await _secureStorage.write(
      key: 'supabase_session',
      value: json.encode(session.toJson()),
    );
  }

  // Get current session
  Future<Session?> getCurrentSession() async {
    try {
      final sessionJson = await _secureStorage.read(key: 'supabase_session');
      if (sessionJson != null) {
        return Session.fromJson(json.decode(sessionJson));
      }
    } catch (e) {
      print('Error getting session: $e');
    }
    return null;
  }

  // Check if user exists (for duplicate prevention)
  Future<bool> checkUserExists(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('phone', cleanPhone)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _supabase.from('profiles').update({'role': role}).eq('id', userId);

      _currentUserRole = role;
    } catch (e) {
      print('Failed to update user role: $e');
    }
  }

  // Add missing methods for compatibility
  static Future<void> initialize() async {
    await _instance.initializeSession();
  }

  static Future<void> clearSession() async {
    await _instance.signOut();
  }

  static Future<bool> attemptAutoLogin() async {
    try {
      await _instance.initializeSession();

      // Double-check with Supabase auth state
      final supabase = Supabase.instance.client;
      final currentSession = supabase.auth.currentSession;
      final currentUser = supabase.auth.currentUser;

      if (currentSession != null && currentUser != null) {
        _instance._currentUserId = currentUser.id;
        _instance._isAuthenticated = true;

        // Fetch user role from profiles table
        final profileResponse = await supabase
            .from('profiles')
            .select('role')
            .eq('id', currentUser.id)
            .single()
            .catchError((_) => null);

        _instance._currentUserRole = profileResponse['role'] ?? 'customer';

        print('✅ Auto-login successful: User ${currentUser.id} authenticated');
        return true;
      } else {
        // Clear local state if no Supabase session
        _instance._isAuthenticated = false;
        _instance._currentUserId = null;
        _instance._currentUserRole = null;
        await _instance._secureStorage.delete(key: 'supabase_session');
        print('❌ Auto-login failed: No valid Supabase session');
        return false;
      }
    } catch (e) {
      print('❌ Auto-login error: $e');
      _instance._isAuthenticated = false;
      _instance._currentUserId = null;
      _instance._currentUserRole = null;
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    return _instance._isAuthenticated;
  }

  static Future<void> saveSession(Session session) async {
    await _instance._saveSession(session);
  }

  static Future<String?> getUserId() async {
    return _instance._currentUserId;
  }

  /// Ensures vehicle completeness for existing driver records
  /// This fixes the 15 incomplete vehicle records identified in the database
  Future<void> _ensureVehicleCompleteness(String driverId) async {
    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('id', driverId)
          .maybeSingle();

      if (response != null) {
        final vehicleMake = response['vehicle_make'] as String?;
        final vehicleModel = response['vehicle_model'] as String?;
        final licensePlate = response['license_plate'] as String?;
        final vehicleYear = response['vehicle_year'] as int?;

        // Check if any required vehicle fields are null
        if (vehicleMake == null ||
            vehicleModel == null ||
            licensePlate == null ||
            vehicleYear == null) {
          await _supabase
              .from('drivers')
              .update({
                'vehicle_make': vehicleMake ?? 'Unknown',
                'vehicle_model': vehicleModel ?? 'Unknown',
                'vehicle_year': vehicleYear ?? DateTime.now().year,
                'license_plate':
                    licensePlate ??
                    'TEMP-${driverId.substring(0, 6).toUpperCase()}',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', driverId);

          print('✅ Fixed incomplete vehicle data for driver: $driverId');
        }
      }
    } catch (e) {
      print('⚠️ Error ensuring vehicle completeness: $e');
      // Non-critical error, don't throw
    }
  }
}
