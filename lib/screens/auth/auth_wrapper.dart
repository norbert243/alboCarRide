import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/driver_home_page.dart';
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
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    print('Checking authentication state...');
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Small delay for UI to show

    // First check if we have a valid session stored locally
    final hasValidSession = await SessionService.hasValidSession();
    print('Has valid local session: $hasValidSession');

    final session = _supabase.auth.currentSession;
    print('Supabase session exists: ${session != null}');

    if (session != null) {
      await _handleAuthenticatedSession(session);
    } else if (hasValidSession) {
      // We have a local session but no Supabase session - try to restore
      await _tryRestoreSession();
    } else {
      print('No valid session found, redirecting to RoleSelectionPage');
      // No session at all, redirect to role selection
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuthenticatedSession(Session session) async {
    print('User authenticated: ${session.user.id}');
    print('Session expires at: ${session.expiresAt}');
    print('Current time: ${DateTime.now()}');

    // Check if session is expired (expiresAt is a timestamp in seconds)
    if (session.expiresAt != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        session.expiresAt! * 1000,
      );
      print('Session expires at: $expiresAt');

      if (expiresAt.isBefore(DateTime.now())) {
        print('Session expired, refreshing...');
        try {
          await _supabase.auth.refreshSession();
          print('Session refreshed successfully');
        } catch (e) {
          print('Error refreshing session: $e');
          await SessionService.clearSession();
          return;
        }
      }
    }

    // Save session to persistent storage
    try {
      final profileResponse = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .single();

      final role = profileResponse['role'] as String;
      print('User role: $role');

      // Save session data
      final expiry = session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : DateTime.now().add(const Duration(days: 30));

      // For phone-based authentication, we need to get the phone from the profile
      final profileData = await _supabase
          .from('profiles')
          .select('phone')
          .eq('id', session.user.id)
          .single();

      final phoneNumber = profileData['phone'] as String? ?? '';

      await SessionService.saveSession(
        userId: session.user.id,
        userPhone: phoneNumber,
        userRole: role,
        expiry: expiry,
      );

      // Redirect based on role
      if (mounted) {
        if (role == 'customer') {
          print('Redirecting to CustomerHomePage');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerHomePage()),
          );
        } else if (role == 'driver') {
          print('Redirecting to DriverHomePage');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomePage()),
          );
        } else {
          print('Invalid role, redirecting to RoleSelectionPage');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
          );
        }
      }
    } catch (e) {
      print('Error fetching profile or saving session: $e');
      // Error fetching profile (likely no profile exists), redirect to role selection
      if (mounted) {
        CustomToast.showInfo(
          context: context,
          message: 'Please complete your profile setup',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
        );
      }
    }
  }

  Future<void> _tryRestoreSession() async {
    print('Attempting to restore session from local storage...');
    final sessionData = await SessionService.getSessionData();

    if (sessionData != null) {
      print('Found local session data, redirecting based on role');
      final role = sessionData['userRole'] as String?;

      if (mounted) {
        if (role == 'customer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerHomePage()),
          );
        } else if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomePage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
          );
        }
      }
    } else {
      print('No valid local session found');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : const Text('Redirecting...'),
      ),
    );
  }
}
