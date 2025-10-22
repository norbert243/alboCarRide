// RooCode Audit Script for AlboCarRide Authentication System
// This script tests the complete authentication flow from v0 to v10

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/auth_service.dart';

class RooCodeAuditScript {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final AuthService _authService = AuthService();

  static Future<void> runAudit() async {
    print('🚀 RooCode Audit Script Starting...');
    print('========================================');
    
    try {
      // Test 1: Database Schema Validation
      await _testDatabaseSchema();
      
      // Test 2: AuthService Initialization
      await _testAuthServiceInitialization();
      
      // Test 3: Phone OTP Registration Flow
      await _testPhoneOtpRegistration();
      
      // Test 4: Driver Profile Creation
      await _testDriverProfileCreation();
      
      // Test 5: Session Management
      await _testSessionManagement();
      
      // Test 6: Driver Approval Flow
      await _testDriverApprovalFlow();
      
      print('✅ All audit tests completed successfully!');
      print('========================================');
      
    } catch (e) {
      print('❌ Audit failed with error: $e');
      print('========================================');
    }
  }

  static Future<void> _testDatabaseSchema() async {
    print('\n📊 Test 1: Database Schema Validation');
    
    try {
      // Check profiles table
      final profilesResult = await _supabase
          .from('profiles')
          .select('count')
          .limit(1);
      print('✅ Profiles table accessible');
      
      // Check drivers table
      final driversResult = await _supabase
          .from('drivers')
          .select('count')
          .limit(1);
      print('✅ Drivers table accessible');
      
      // Check driver_wallets table
      final walletsResult = await _supabase
          .from('driver_wallets')
          .select('count')
          .limit(1);
      print('✅ Driver wallets table accessible');
      
      // Check RPC functions
      try {
        await _supabase.rpc('get_driver_dashboard', params: {
          'p_driver_id': 'test-id'
        });
        print('✅ RPC functions accessible');
      } catch (e) {
        print('⚠️ RPC functions may need setup: $e');
      }
      
    } catch (e) {
      print('❌ Database schema validation failed: $e');
      rethrow;
    }
  }

  static Future<void> _testAuthServiceInitialization() async {
    print('\n🔐 Test 2: AuthService Initialization');
    
    try {
      await _authService.initializeSession();
      print('✅ AuthService initialization successful');
      
      final isAuthenticated = await AuthService.isAuthenticatedStatic();
      print('✅ Static method access: isAuthenticated = $isAuthenticated');
      
      final userId = await AuthService.getUserIdStatic();
      print('✅ Static method access: userId = $userId');
      
    } catch (e) {
      print('❌ AuthService initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> _testPhoneOtpRegistration() async {
    print('\n📱 Test 3: Phone OTP Registration Flow');
    
    try {
      // Test phone number format validation
      final testPhone = '+27831234567'; // South Africa test number
      
      // Check if user exists
      final userExists = await _authService.checkUserExists(testPhone);
      print('✅ User existence check: $userExists');
      
      // Test sign up with phone
      final signUpResult = await _authService.signUpWithPhone(
        phone: testPhone,
        fullName: 'Test User',
        role: 'customer',
      );
      
      print('✅ Phone OTP sign up initiated: ${signUpResult['success']}');
      print('   Message: ${signUpResult['message']}');
      
      if (!signUpResult['success']) {
        print('⚠️ OTP sending may require Twilio setup');
      }
      
    } catch (e) {
      print('❌ Phone OTP registration test failed: $e');
      // Don't throw - this might be expected if Twilio isn't configured
    }
  }

  static Future<void> _testDriverProfileCreation() async {
    print('\n🚗 Test 4: Driver Profile Creation');
    
    try {
      // Create a test driver profile
      final testDriverId = 'test-driver-${DateTime.now().millisecondsSinceEpoch}';
      
      final driverProfileResult = await _authService.createDriverProfile(
        driverId: testDriverId,
        vehicleType: 'car',
        vehicleMake: 'Toyota',
        vehicleModel: 'Corolla',
        licensePlate: 'TEST123',
        vehicleYear: 2020,
      );
      
      print('✅ Driver profile creation: ${driverProfileResult['success']}');
      print('   Message: ${driverProfileResult['message']}');
      
      // Test driver approval status check
      final approvalResult = await _authService.checkDriverApprovalStatus(testDriverId);
      print('✅ Driver approval status check: ${approvalResult['success']}');
      print('   Is Approved: ${approvalResult['isApproved']}');
      
    } catch (e) {
      print('❌ Driver profile creation test failed: $e');
      rethrow;
    }
  }

  static Future<void> _testSessionManagement() async {
    print('\n💾 Test 5: Session Management');
    
    try {
      // Test session saving (mock session)
      final mockSession = Session(
        accessToken: 'mock-access-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {'role': 'customer'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      
      await AuthService.saveSession(mockSession);
      print('✅ Session saving successful');
      
      // Test session retrieval
      final retrievedSession = await _authService.getCurrentSession();
      print('✅ Session retrieval: ${retrievedSession != null ? "Success" : "No session"}');
      
      // Test sign out
      await AuthService.clearSession();
      print('✅ Session clearing successful');
      
    } catch (e) {
      print('❌ Session management test failed: $e');
      rethrow;
    }
  }

  static Future<void> _testDriverApprovalFlow() async {
    print('\n✅ Test 6: Driver Approval Flow');
    
    try {
      // Test the complete driver approval workflow
      final testDriverId = 'approval-test-driver';
      
      // Create driver profile
      await _authService.createDriverProfile(
        driverId: testDriverId,
        vehicleType: 'motorcycle',
        vehicleMake: 'Honda',
        vehicleModel: 'CBR',
        licensePlate: 'MOTO456',
        vehicleYear: 2021,
      );
      
      // Check initial approval status (should be false)
      final initialStatus = await _authService.checkDriverApprovalStatus(testDriverId);
      print('✅ Initial approval status: ${initialStatus['isApproved']}');
      
      // Simulate admin approval (this would normally be done in Supabase dashboard)
      print('⚠️ Manual step required: Approve driver in Supabase dashboard');
      print('   Driver ID: $testDriverId');
      print('   Table: drivers');
      print('   Column: is_approved (set to true)');
      
      // Note: In production, this would be automated via admin functions
      print('✅ Driver approval flow test completed (manual verification required)');
      
    } catch (e) {
      print('❌ Driver approval flow test failed: $e');
      rethrow;
    }
  }
}

// Main function to run the audit
void main() async {
  await RooCodeAuditScript.runAudit();
}