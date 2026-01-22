import 'package:flutter/material.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/customer_map_widget.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  bool _canSwitchToDriver = false;
  bool _isCheckingRoles = true;

  @override
  void initState() {
    super.initState();
    _checkAvailableRoles();
  }

  Future<void> _checkAvailableRoles() async {
    try {
      final userId = await SessionService.getUserId();
      if (userId != null) {
        final roles = await SessionService.getAvailableRoles(userId);
        if (mounted) {
          setState(() {
            _canSwitchToDriver = roles.contains('driver');
            _isCheckingRoles = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingRoles = false);
      }
    }
  }

  Future<void> _switchToDriver() async {
    final userId = await SessionService.getUserId();
    if (userId == null) return;

    // Check for active trips
    final hasActiveTrip = await SessionService.hasActiveTrip(userId);
    if (hasActiveTrip) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot switch roles while you have an active trip'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Switch role
    await SessionService.updateUserRole('driver');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/enhanced-driver-home',
        (route) => false,
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.clearSession();
    await SessionService.clearSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/role-selection', (route) => false);
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Where to?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_canSwitchToDriver && !_isCheckingRoles)
                    IconButton(
                      onPressed: _switchToDriver,
                      icon: const Icon(Icons.drive_eta, color: Colors.white),
                      tooltip: 'Switch to Driver Mode',
                    ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/account-settings'),
                    icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                    tooltip: 'Account Settings',
                  ),
                  IconButton(
                    onPressed: () => _signOut(),
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const CustomerMapWidget(),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Request Ride',
                Icons.local_taxi,
                Colors.deepPurple,
                () => Navigator.pushNamed(context, '/customer-ride-request'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context,
                'Ride History',
                Icons.history,
                Colors.blue,
                () => Navigator.pushNamed(context, '/ride-history'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Payments',
                Icons.payment,
                Colors.green,
                () => Navigator.pushNamed(context, '/payments'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context,
                'Support',
                Icons.support_agent,
                Colors.orange,
                () => Navigator.pushNamed(context, '/support'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        _buildActivityItem(context, 'Ride to Downtown', 'Completed • \$15.50', Icons.check_circle, Colors.green),
        _buildActivityItem(context, 'Ride to Airport', 'Cancelled • \$0.00', Icons.cancel, Colors.red),
        _buildActivityItem(context, 'Ride to Mall', 'Completed • \$12.75', Icons.check_circle, Colors.green),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildMapSection(context),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildQuickActions(context),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildRecentActivity(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
