import 'package:flutter/material.dart';
import 'package:albocarride/utils/app_theme.dart';

/// Role selection page for new users
/// Shows after phone entry when user is not found in database
class RoleSelectionPage extends StatelessWidget {
  final String? phone;

  const RoleSelectionPage({super.key, this.phone});

  @override
  Widget build(BuildContext context) {
    // Get phone from arguments if not passed directly
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final phoneNumber = phone ?? args?['phone'] as String?;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildSubheader(context, phoneNumber),
              const SizedBox(height: 32),
              Text(
                'How would you like to use the app?',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              RoleCard(
                title: 'Customer',
                description: 'Book rides and get to your destination.',
                icon: Icons.person_outline,
                color: AppTheme.primaryColor,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/signup',
                  arguments: {
                    'role': 'customer',
                    'phone': phoneNumber,
                  },
                ),
              ),
              const SizedBox(height: 20),
              RoleCard(
                title: 'Driver',
                description: 'Offer rides and earn money.',
                icon: Icons.drive_eta_outlined,
                color: AppTheme.secondaryColor,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/signup',
                  arguments: {
                    'role': 'driver',
                    'phone': phoneNumber,
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildBackButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.directions_car_filled,
          size: 64,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'AlboCarRide',
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(color: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Widget _buildSubheader(BuildContext context, String? phoneNumber) {
    return Column(
      children: [
        Text(
          "You're new here!",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (phoneNumber != null) ...[
          const SizedBox(height: 4),
          Text(
            'Creating account for $phoneNumber',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('Use a different number'),
    );
  }
}

class RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
