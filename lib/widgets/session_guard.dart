import 'package:flutter/material.dart';
import '../services/session_service.dart';

class SessionGuard extends StatelessWidget {
  final Widget child;

  const SessionGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SessionService.isAuthenticated,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!) {
          // Redirect unauthorized users
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/role-selection',
              (route) => false,
            );
          });

          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Unauthorized. Redirecting to login...'),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
