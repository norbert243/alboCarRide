import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/driver_home_page.dart';
import 'package:albocarride/widgets/custom_toast.dart';

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

    final session = _supabase.auth.currentSession;
    print('Auth check: Session exists: ${session != null}');

    if (session != null) {
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
          }
        }
      }

      // User is authenticated, get their role
      try {
        print('Fetching user profile...');
        final profileResponse = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();

        final role = profileResponse['role'] as String;
        print('User role: $role');

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
              MaterialPageRoute(
                builder: (context) => const RoleSelectionPage(),
              ),
            );
          }
        }
      } catch (e) {
        print('Error fetching profile: $e');
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
    } else {
      print('User not authenticated, redirecting to RoleSelectionPage');
      // User is not authenticated
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
