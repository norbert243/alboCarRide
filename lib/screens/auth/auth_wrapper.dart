import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/auth/signup_page.dart';
import 'package:albocarride/screens/auth/vehicle_type_selection_page.dart';
import 'package:albocarride/screens/driver/verification_page.dart';
import 'package:albocarride/screens/driver/waiting_for_review_page.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/enhanced_driver_home_page.dart';
import 'package:albocarride/services/session_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Widget? _targetPage;

  @override
  void initState() {
    super.initState();
    // Delay routing until after first frame to avoid black screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRoute();
    });
  }

  Future<void> _checkAndRoute() async {
    try {
      print('🔐 AuthWrapper: Starting authentication check');

      // Wait for Supabase auth state to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔐 AuthWrapper: Supabase initialization delay completed');

      // WhatsApp-style: Attempt automatic login first
      print('🔐 AuthWrapper: Attempting WhatsApp-style auto-login...');
      final autoLoginSuccess = await AuthService.attemptAutoLogin();
      print('🔐 AuthWrapper: Auto-login result = $autoLoginSuccess');

      if (autoLoginSuccess) {
        print(
          '🔐 AuthWrapper: ✅ WhatsApp-style auto-login successful, routing to homepage',
        );
        await _routeBasedOnUserRole();
        return;
      }

      // Check if user has a valid session stored locally
      print('🔐 AuthWrapper: Checking local session storage...');
      final hasValidSession = await AuthService.isLoggedIn();
      print('🔐 AuthWrapper: hasValidSession = $hasValidSession');

      if (hasValidSession) {
        print(
          '🔐 AuthWrapper: ✅ User has valid session, skipping role selection',
        );
        await _routeBasedOnUserRole();
        return;
      }

      // Check SharedPreferences for basic session info
      print('🔐 AuthWrapper: Checking SharedPreferences for basic session...');
      final prefs = await SharedPreferences.getInstance();
      final sharedUserId = prefs.getString('user_id');
      final sharedRole = prefs.getString('user_role');
      print(
        '🔐 AuthWrapper: SharedPreferences - User ID: $sharedUserId, Role: $sharedRole',
      );

      if (sharedUserId != null && sharedRole != null) {
        print('🔐 AuthWrapper: ✅ Found basic session in SharedPreferences');
        // We have basic session info, try to restore Supabase session
        final supabaseSession = _supabase.auth.currentSession;
        if (supabaseSession != null) {
          print('🔐 AuthWrapper: ✅ Supabase session exists, saving it');
          await AuthService.saveSession(supabaseSession);
          await _routeBasedOnUserRole();
          return;
        } else {
          print('🔐 AuthWrapper: ⚠️ No Supabase session, using basic session');
          // Use basic session info to route
          await _routeBasedOnBasicSession(sharedUserId, sharedRole);
          return;
        }
      }

      // If no local session, check Supabase auth
      print('🔐 AuthWrapper: No local session found, checking Supabase...');
      final session = _supabase.auth.currentSession;
      print(
        '🔐 AuthWrapper: Supabase session = ${session != null ? "✅ EXISTS" : "❌ NULL"}',
      );

      if (session == null) {
        // Not authenticated -> show role selection / login
        print(
          '🔐 AuthWrapper: ❌ No session found, navigating to role selection',
        );
        _navigateToRoleSelection();
        return;
      }

      // User has Supabase session but no local session - save it
      print(
        '🔐 AuthWrapper: ✅ Supabase session exists but no local session, saving session',
      );

      final user = _supabase.auth.currentUser!;
      debugPrint('AuthWrapper: Current user ID = ${user.id}');

      // Fetch profile to get user role
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id);

      if (profileResponse.isEmpty) {
        debugPrint(
          'AuthWrapper: No profile found for user, navigating to signup',
        );
        // No profile yet -> route to signup
        _navigateToSignup();
        return;
      }

      final profile = profileResponse.first;
      final role = profile['role'] as String? ?? 'customer';
      final userPhone = user.phone ?? user.email ?? '';
      debugPrint('AuthWrapper: User role = $role, phone = $userPhone');

      // Save session for future use using AuthService
      final currentSession = _supabase.auth.currentSession!;
      await AuthService.saveSession(currentSession);

      debugPrint(
        'AuthWrapper: Session saved for user: ${user.id} with role: $role',
      );

      // Route based on user role
      await _routeBasedOnUserRole();
    } catch (e) {
      print('❌ Error in AuthWrapper routing: $e');
      // Fallback to role selection on error
      _navigateToRoleSelection();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _routeBasedOnBasicSession(String userId, String role) async {
    try {
      print('🔐 Routing based on basic session:');
      print('  User ID: $userId');
      print('  Role: $role');

      if (role == 'driver') {
        // For drivers, we need to check their verification status
        final profileResponse = await _supabase
            .from('profiles')
            .select('verification_status, is_verified')
            .eq('id', userId)
            .single()
            .catchError((e) {
              print('❌ Error fetching driver profile: $e');
              return null;
            });

        final verificationStatus =
            profileResponse['verification_status'] as String?;
        final isVerified = profileResponse['is_verified'] as bool? ?? false;

        print('  Verification Status: $verificationStatus');
        print('  Is Verified: $isVerified');

        if (verificationStatus == 'approved' && isVerified) {
          _navigateToEnhancedDriverHome();
        } else if (verificationStatus == 'pending') {
          _navigateToWaitingReview();
        } else {
          _navigateToVerification();
        }
            } else {
        // Customer - go to customer home
        _navigateToCustomerHome();
      }
    } catch (e) {
      print('❌ Error in basic session routing: $e');
      _navigateToRoleSelection();
    }
  }

  Future<void> _routeBasedOnUserRole() async {
    try {
      final user = _supabase.auth.currentUser!;
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

      final profile = profileResponse.first;
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
      debugPrint('Error in routing based on user role: $e');
      // Clear any corrupted sessions and fallback to role selection
      await SessionService.clearSessionStatic();
      _navigateToRoleSelection();
    }
  }

  Future<void> _handleDriverRouting(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    // ⚠️ TEMPORARY: BYPASS VERIFICATION FOR TESTING PURPOSES
    // TODO: Remove this bypass before production
    debugPrint('⚠️ TESTING MODE: Bypassing driver verification checks');
    debugPrint('  Routing directly to enhanced driver home');
    _navigateToEnhancedDriverHome();
    return;

    // ORIGINAL CODE (COMMENTED OUT FOR TESTING):
    // Check if verification_status field exists and has a value
    // final verificationStatus = profile['verification_status'] as String?;
    // final isVerified = profile['is_verified'] as bool? ?? false;

    // // Fetch driver record
    // final driverResponse = await _supabase
    //     .from('drivers')
    //     .select()
    //     .eq('id', userId);

    // final driver = driverResponse.isNotEmpty
    //     ? driverResponse.first as Map<String, dynamic>?
    //     : null;
    // final vehicleType = driver != null
    //     ? driver['vehicle_type'] as String?
    //     : null;

    // debugPrint('Driver routing debug:');
    // debugPrint('  verificationStatus: $verificationStatus');
    // debugPrint('  isVerified: $isVerified');
    // debugPrint('  vehicleType: $vehicleType');

    // // Handle the initial state - if verification_status is null, it means the user
    // // hasn't started the verification process yet
    // if (verificationStatus == null) {
    //   // New driver - route to vehicle type selection first
    //   if (vehicleType == null || vehicleType.isEmpty) {
    //     debugPrint('  Routing to vehicle type selection (new driver)');
    //     _navigateToVehicleType(userId);
    //   } else {
    //     // Vehicle type is set but no verification status - route to verification
    //     debugPrint(
    //       '  Routing to verification (vehicle set but no verification)',
    //     );
    //     _navigateToVerification();
    //   }
    // } else if (verificationStatus == 'pending') {
    //   // If pending review, show waiting screen
    //   debugPrint('  Routing to waiting review (pending verification)');
    //   _navigateToWaitingReview();
    // } else if (verificationStatus == 'rejected') {
    //   // If rejected, route to verification page to allow resubmission
    //   debugPrint('  Routing to verification (rejected)');
    //   _navigateToVerification();
    // } else if (verificationStatus == 'approved') {
    //   // If approved but no vehicle_type, route to vehicle selection
    //   if (vehicleType == null || vehicleType.isEmpty) {
    //     debugPrint(
    //       '  Routing to vehicle type selection (approved but no vehicle)',
    //     );
    //     _navigateToVehicleType(userId);
    //   } else {
    //     // All good -> route to enhanced driver home
    //     debugPrint('  Routing to enhanced driver home (fully verified)');
    //     _navigateToEnhancedDriverHome();
    //   }
    // } else {
    //   // Fallback to verification for unknown status
    //   debugPrint(
    //     '  Routing to verification (unknown status: $verificationStatus)',
    //   );
    //   _navigateToVerification();
    // }
  }

  void _navigateToRoleSelection() {
    if (!mounted) return;

    setState(() {
      _targetPage = const RoleSelectionPage();
      _isLoading = false;
    });
  }

  void _navigateToSignup() {
    if (!mounted) return;
    setState(() {
      _targetPage = const SignupPage(role: 'customer');
      _isLoading = false;
    });
  }

  void _navigateToCustomerHome() {
    if (!mounted) return;
    setState(() {
      _targetPage = const CustomerHomePage();
      _isLoading = false;
    });
  }

  void _navigateToVehicleType(String driverId) {
    if (!mounted) return;
    setState(() {
      _targetPage = VehicleTypeSelectionPage(driverId: driverId);
      _isLoading = false;
    });
  }

  void _navigateToVerification() {
    if (!mounted) return;
    setState(() {
      _targetPage = const VerificationPage();
      _isLoading = false;
    });
  }

  void _navigateToWaitingReview() {
    if (!mounted) return;
    setState(() {
      _targetPage = const WaitingForReviewPage();
      _isLoading = false;
    });
  }

  void _navigateToEnhancedDriverHome() {
    if (!mounted) return;
    setState(() {
      _targetPage = const EnhancedDriverHomePage();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If target page is set, return it directly
    if (_targetPage != null) {
      return _targetPage!;
    }

    // Otherwise show loading screen
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/albo_logo.jpeg',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to icon if image fails to load
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      size: 40,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // WhatsApp-style loading text
            Text(
              _isLoading ? 'Checking authentication...' : 'Redirecting...',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            // WhatsApp-style subtle loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                backgroundColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 24),
            // WhatsApp-style subtitle
            if (_isLoading)
              const Text(
                'Please wait while we verify your session',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
