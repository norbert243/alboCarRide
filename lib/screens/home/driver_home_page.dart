import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/auth_service.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool _isOnline = false;
  bool _isLoading = false;

  Future<void> _signOut() async {
    await AuthService.clearSession();
  }

  Future<void> _toggleOnlineStatus() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .update({'is_online': !_isOnline})
            .eq('id', user.id)
            .select();

        if (response.isEmpty) {
          throw Exception('Failed to update online status');
        }

        setState(() {
          _isOnline = !_isOnline;
        });

        if (_isOnline) {
          // Start listening for ride offers when going online
          // Real-time subscription is handled by the OfferBoard widget
        }
      }
    } catch (e) {
      debugPrint('Error toggling online status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('is_online')
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _isOnline = response['is_online'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading online status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isOnline ? 'Online - Ready to Drive' : 'Driver Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _isOnline ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: _isOnline ? Colors.green : Colors.white,
        elevation: 1,
        foregroundColor: _isOnline ? Colors.white : Colors.black87,
        actions: [
          if (_isOnline)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51), // 0.2 opacity
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              final navigatorContext = context;
              _signOut().then((_) {
                if (navigatorContext.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    navigatorContext,
                    '/role-selection',
                    (route) => false,
                  );
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green : Colors.blue,
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isOnline
                      ? [Colors.green, Colors.lightGreen]
                      : [Colors.blue, Colors.lightBlue],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline
                        ? 'You\'re online and ready to accept rides!'
                        : 'Ready to start earning?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withAlpha(229), // 0.9 opacity
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Earnings Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13), // 0.05 opacity
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    '\$245.50',
                    'Today\'s Earnings',
                    Icons.attach_money,
                  ),
                  _buildStatItem('8', 'Completed Rides', Icons.directions_car),
                  _buildStatItem('4.8', 'Rating', Icons.star),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              children: [
                _buildActionCard(
                  icon: _isOnline ? Icons.offline_bolt : Icons.directions_car,
                  title: _isOnline ? 'Go Offline' : 'Go Online',
                  color: _isOnline ? Colors.red : Colors.blue,
                  onTap: _isLoading ? null : () => _toggleOnlineStatus(),
                ),
                _buildActionCard(
                  icon: Icons.schedule,
                  title: 'Schedule',
                  color: Colors.orange,
                  onTap: () {},
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  title: 'Earnings',
                  color: Colors.purple,
                  onTap: () {},
                ),
                _buildActionCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  color: Colors.grey,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Rides
            const Text(
              'Recent Rides',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildRideItem(
              'John D.',
              'Downtown • \$18.75',
              Icons.check_circle,
              Colors.green,
            ),
            _buildRideItem(
              'Sarah M.',
              'Airport • \$32.50',
              Icons.pending,
              Colors.orange,
            ),
            _buildRideItem(
              'Mike T.',
              'City Center • \$15.25',
              Icons.check_circle,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.green),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(26), // 0.1 opacity
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideItem(
    String passenger,
    String details,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 opacity
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(26), // 0.1 opacity
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passenger,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
