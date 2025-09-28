import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/auth/signup_page.dart';
import 'package:albocarride/screens/auth/vehicle_type_selection_page.dart';
import 'package:albocarride/screens/driver/verification_page.dart';
import 'package:albocarride/screens/driver/waiting_for_review_page.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/enhanced_driver_home_page.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/session_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    try {
      // Wait for Supabase auth state to be ready
      await Future.delayed(const Duration(milliseconds: 500));

      // Check both Supabase auth session and local session storage
      final supabaseSession = _supabase.auth.currentSession;
      final localSessionData = await SessionService.getSessionDataStatic();
      final hasLocalSession = await SessionService.hasValidSessionStatic();

      debugPrint('Session check:');
      debugPrint(
        '  Supabase session: ${supabaseSession != null ? "Exists" : "Null"}',
      );
      debugPrint(
        '  Local session: ${hasLocalSession ? "Valid" : "Invalid/Expired"}',
      );
      debugPrint('  Local session data: $localSessionData');

      // If no session exists in either storage, go to role selection
      if (supabaseSession == null && !hasLocalSession) {
        debugPrint('No valid session found, routing to role selection');
        _navigateToRoleSelection();
        return;
      }

      // If Supabase session exists but local session doesn't, save local session
      if (supabaseSession != null && !hasLocalSession) {
        debugPrint(
          'Supabase session exists but local session missing, saving local session',
        );
        final user = _supabase.auth.currentUser!;
        final userData = user.userMetadata ?? {};
        final expiry = supabaseSession.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(
                supabaseSession.expiresAt! * 1000,
              )
            : DateTime.now().add(const Duration(days: 30));

        await SessionService.saveSessionStatic(
          userId: user.id,
          userPhone: userData['phone']?.toString() ?? '',
          userRole: userData['role']?.toString() ?? 'customer',
          expiry: expiry,
        );
      }

      // If local session exists but Supabase session doesn't, try to restore auth
      if (!hasLocalSession && supabaseSession == null) {
        debugPrint(
          'Local session exists but Supabase session missing, attempting to restore',
        );
        // For now, we'll treat this as no session since we can't restore Supabase auth
        // In a production app, you might implement token refresh logic here
        await SessionService.clearSessionStatic();
        _navigateToRoleSelection();
        return;
      }

      // Get the current user (either from Supabase or local session)
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User is null, routing to role selection');
        _navigateToRoleSelection();
        return;
      }

      // Fetch profile
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id);

      if (profileResponse.isEmpty) {
        debugPrint('No profile found for user ${user.id}, routing to signup');
        // No profile yet -> route to signup with role from session
        final sessionRole =
            await SessionService.getUserRoleStatic() ?? 'customer';
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/signup',
          (route) => false,
          arguments: sessionRole,
        );
        return;
      }

      final profile = profileResponse.first as Map<String, dynamic>;
      final role = profile['role'] as String? ?? 'customer';

      debugPrint('User authenticated successfully:');
      debugPrint('  User ID: ${user.id}');
      debugPrint('  Role: $role');

      if (role == 'driver') {
        await _handleDriverRouting(user.id, profile);
      } else {
        // Customer: go to customer home
        _navigateToCustomerHome();
      }
    } catch (e) {
      debugPrint('Error in AuthWrapper routing: $e');
      // Clear any corrupted sessions and fallback to role selection
      await SessionService.clearSessionStatic();
      _navigateToRoleSelection();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDriverRouting(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    // Check if verification_status field exists and has a value
    final verificationStatus = profile['verification_status'] as String?;
    final isVerified = profile['is_verified'] as bool? ?? false;

    // Fetch driver record
    final driverResponse = await _supabase
        .from('drivers')
        .select()
        .eq('id', userId);

    final driver = driverResponse.isNotEmpty
        ? driverResponse.first as Map<String, dynamic>?
        : null;
    final vehicleType = driver != null
        ? driver['vehicle_type'] as String?
        : null;

    debugPrint('Driver routing debug:');
    debugPrint('  verificationStatus: $verificationStatus');
    debugPrint('  isVerified: $isVerified');
    debugPrint('  vehicleType: $vehicleType');

    // Handle the initial state - if verification_status is null, it means the user
    // hasn't started the verification process yet
    if (verificationStatus == null) {
      // New driver - route to vehicle type selection first
      if (vehicleType == null || vehicleType.isEmpty) {
        debugPrint('  Routing to vehicle type selection (new driver)');
        _navigateToVehicleType(userId);
      } else {
        // Vehicle type is set but no verification status - route to verification
        debugPrint(
          '  Routing to verification (vehicle set but no verification)',
        );
        _navigateToVerification();
      }
    } else if (verificationStatus == 'pending') {
      // If pending review, show waiting screen
      debugPrint('  Routing to waiting review (pending verification)');
      _navigateToWaitingReview();
    } else if (verificationStatus == 'rejected') {
      // If rejected, route to verification page to allow resubmission
      debugPrint('  Routing to verification (rejected)');
      _navigateToVerification();
    } else if (verificationStatus == 'approved') {
      // If approved but no vehicle_type, route to vehicle selection
      if (vehicleType == null || vehicleType.isEmpty) {
        debugPrint(
          '  Routing to vehicle type selection (approved but no vehicle)',
        );
        _navigateToVehicleType(userId);
      } else {
        // All good -> route to enhanced driver home
        debugPrint('  Routing to enhanced driver home (fully verified)');
        _navigateToEnhancedDriverHome();
      }
    } else {
      // Fallback to verification for unknown status
      debugPrint(
        '  Routing to verification (unknown status: $verificationStatus)',
      );
      _navigateToVerification();
    }
  }

  void _navigateToRoleSelection() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/role-selection',
      (route) => false,
    );
  }

  void _navigateToSignup() {
    Navigator.pushNamedAndRemoveUntil(context, '/signup', (route) => false);
  }

  void _navigateToCustomerHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/customer_home',
      (route) => false,
    );
  }

  void _navigateToVehicleType(String driverId) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/vehicle-type-selection',
      (route) => false,
      arguments: driverId,
    );
  }

  void _navigateToVerification() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/verification',
      (route) => false,
    );
  }

  void _navigateToWaitingReview() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/waiting-review',
      (route) => false,
    );
  }

  void _navigateToEnhancedDriverHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/enhanced-driver-home',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _isLoading ? 'Checking authentication...' : 'Redirecting...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
