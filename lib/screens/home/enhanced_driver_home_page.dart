import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/screens/home/driver_dashboard_v2_realtime.dart';
import 'package:albocarride/widgets/navigation_header.dart';
import 'package:albocarride/services/ride_negotiation_service.dart';
import 'package:albocarride/widgets/offer_board.dart';

class EnhancedDriverHomePage extends StatefulWidget {
  const EnhancedDriverHomePage({super.key});

  @override
  State<EnhancedDriverHomePage> createState() => _EnhancedDriverHomePageState();
}

class _EnhancedDriverHomePageState extends State<EnhancedDriverHomePage> {
  bool _isOnline = false;
  bool _isLoading = false;
  int _pendingOffersCount = 0;
  List<Map<String, dynamic>> _availableRideRequests = [];
  late StreamSubscription<List<RideOffer>>? _offersSubscription;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
    _startOffersSubscription();
    _fetchAvailableRideRequests();
  }

  @override
  void dispose() {
    _offersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startOffersSubscription() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final service = RideNegotiationService(Supabase.instance.client);
        _offersSubscription = service.watchPendingOffers(user.id).listen((
          offers,
        ) {
          if (mounted) {
            setState(() {
              _pendingOffersCount = offers.length;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting offers subscription: $e');
    }
  }

  Future<void> _fetchAvailableRideRequests() async {
    try {
      debugPrint(
        '🔍 _fetchAvailableRideRequests: Fetching available ride requests',
      );

      // Show loading state
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final response = await Supabase.instance.client
          .from('ride_requests')
          .select(
            'id, pickup_address, dropoff_address, proposed_price, created_at, status',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(5);

      debugPrint(
        '📊 _fetchAvailableRideRequests: Raw response - ${response.length} items',
      );

      if (response.isNotEmpty) {
        debugPrint(
          '📊 _fetchAvailableRideRequests: First item - ${response.first}',
        );
      }

      if (mounted) {
        setState(() {
          _availableRideRequests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        debugPrint(
          '✅ _fetchAvailableRideRequests: Found ${_availableRideRequests.length} available requests',
        );

        // Show feedback to user
        if (_availableRideRequests.isNotEmpty) {
          _showSuccessSnackbar(
            'Found ${_availableRideRequests.length} ride requests',
          );
        } else {
          _showErrorSnackbar('No ride requests found');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ _fetchAvailableRideRequests: Error - $e');
      debugPrint('❌ _fetchAvailableRideRequests: Stack trace - $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Failed to fetch ride requests: ${e.toString()}');
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.clearSession();
  }

  Future<void> _toggleOnlineStatus() async {
    if (_isLoading) {
      debugPrint('⚠️ _toggleOnlineStatus: Already loading, ignoring request');
      _showErrorSnackbar('Please wait, operation in progress');
      return;
    }

    debugPrint(
      '🔄 _toggleOnlineStatus: Starting toggle from $_isOnline to ${!_isOnline}',
    );
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        debugPrint(
          '✅ _toggleOnlineStatus: User authenticated, updating profile',
        );
        final response = await Supabase.instance.client
            .from('profiles')
            .update({'is_online': !_isOnline})
            .eq('id', user.id)
            .select();

        if (response.isEmpty) {
          throw Exception(
            'Failed to update online status - no response from server',
          );
        }
        debugPrint('✅ _toggleOnlineStatus: Profile updated successfully');

        // Update state first
        final newOnlineStatus = !_isOnline;
        setState(() => _isOnline = newOnlineStatus);

        // Show immediate feedback to user
        _showSuccessSnackbar(
          newOnlineStatus
              ? 'You are now online and ready to accept rides!'
              : 'You are now offline. Take a break!',
        );

        // If going online, navigate to ride request screen IMMEDIATELY
        debugPrint(
          '🔍 _toggleOnlineStatus: Checking navigation condition - newOnlineStatus: $newOnlineStatus',
        );
        if (newOnlineStatus) {
          debugPrint(
            '🚗 _toggleOnlineStatus: Driver going online - navigating to ride request screen',
          );
          // Navigate immediately, don't wait for modal
          _navigateToRideRequestScreen();
        } else {
          debugPrint(
            '⚠️ _toggleOnlineStatus: Driver going offline - no navigation needed',
          );
        }

        // Show status change confirmation AFTER navigation (but don't wait for it)
        debugPrint('📱 _toggleOnlineStatus: Showing status change modal');
        _showStatusChangeModal();
      } else {
        debugPrint('❌ _toggleOnlineStatus: No authenticated user found');
        _showErrorSnackbar('Not authenticated. Please log in again.');
      }
    } catch (e) {
      debugPrint('❌ _toggleOnlineStatus: Error - $e');

      // Provide more helpful error message based on error type
      final errorMessage = e.toString();
      if (errorMessage.contains('permission denied for table profiles')) {
        _showErrorSnackbar(
          'Cannot update online status: Database permissions issue. '
          'Please contact support or check RLS policies.',
        );
      } else {
        _showErrorSnackbar('Failed to update online status: ${e.toString()}');
      }

      // Revert state on error
      if (mounted) {
        setState(() => _isOnline = _isOnline); // Keep current state
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('✅ _toggleOnlineStatus: Loading state reset');
      }
    }
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
        if (mounted) setState(() => _isOnline = response['is_online'] ?? false);
      }
    } catch (e) {
      debugPrint('Error loading online status: $e');
    }
  }

  Future<String?> _getDriverIdFromAuth() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      return user?.id;
    } catch (e) {
      debugPrint('⚠️ Could not get driver id: $e');
      return null;
    }
  }

  void _showScheduleModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: 'Schedule',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Schedule Feature',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Coming soon - Schedule your availability and preferred working hours',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEarningsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: 'Earnings Summary',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Quick Stats
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildEarningStat('R245.50', 'Today'),
                            _buildEarningStat('R1,245.80', 'This Week'),
                            _buildEarningStat('R4,892.15', 'This Month'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Detailed Breakdown
                      Column(
                        children: [
                          _buildEarningItem('Monday', 'R312.50', '8 trips'),
                          _buildEarningItem('Tuesday', 'R285.75', '7 trips'),
                          _buildEarningItem('Wednesday', 'R298.25', '6 trips'),
                          _buildEarningItem('Thursday', 'R315.80', '9 trips'),
                          _buildEarningItem('Friday', 'R333.50', '10 trips'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/payments');
                        },
                        child: const Text('View Full Earnings'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: 'Settings',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSettingOption(
                      Icons.notifications,
                      'Notifications',
                      'Manage push notifications',
                      () => _showNotificationsModal(context),
                    ),
                    _buildSettingOption(
                      Icons.security,
                      'Privacy & Safety',
                      'Privacy settings and safety features',
                      () => _showPrivacySafetyModal(context),
                    ),
                    _buildSettingOption(
                      Icons.help_outline,
                      'Help & Support',
                      'Get help and contact support',
                      () {
                        Navigator.pop(context); // Close settings modal first
                        Navigator.pushNamed(context, '/support');
                      },
                    ),
                    _buildSettingOption(
                      Icons.info_outline,
                      'About',
                      'App version and information',
                      () => _showAboutModal(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Rate this app',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: 'Notifications',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Notification Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coming soon - Configure your push notification preferences',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySafetyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: 'Privacy & Safety',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Privacy & Safety Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coming soon - Manage your privacy settings and safety features',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: 'About',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'AlboCarRide Driver App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0\n\nProfessional ride-hailing platform for drivers',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRideRequestScreen() async {
    debugPrint('🔍 _navigateToRideRequestScreen: Starting navigation process');
    try {
      final driverId = await _getDriverIdFromAuth();
      debugPrint('🔍 _navigateToRideRequestScreen: Got driver ID: $driverId');
      debugPrint('🔍 _navigateToRideRequestScreen: Mounted state: $mounted');

      if (driverId != null && mounted) {
        debugPrint(
          '🚗 _navigateToRideRequestScreen: Navigating to ride request screen for driver $driverId',
        );
        final result = await Navigator.pushNamed(
          context,
          '/driver-ride-request',
          arguments: driverId,
        );
        debugPrint(
          '🔍 _navigateToRideRequestScreen: Navigation completed with result: $result',
        );
      } else {
        debugPrint(
          '❌ _navigateToRideRequestScreen: No driver ID found or not mounted',
        );
      }
    } catch (e) {
      debugPrint('❌ _navigateToRideRequestScreen: Error - $e');
      debugPrint(
        '❌ _navigateToRideRequestScreen: Stack trace: ${e.toString()}',
      );
    }
  }

  void _showStatusChangeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header using standardized modal navigation
            ModalNavigationHeader(
              title: _isOnline ? 'You\'re Online!' : 'You\'re Offline',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isOnline ? Icons.check_circle : Icons.offline_bolt,
                        size: 64,
                        color: _isOnline ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isOnline
                            ? 'You are now online and ready to accept rides!'
                            : 'You are now offline. Take a break!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOnline
                            ? 'Riders can now see you on the map and request rides.'
                            : 'You won\'t receive ride requests until you go online again.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          debugPrint(
                            '✅ StatusChangeModal: Got it button pressed - closing modal',
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningStat(String amount, String period) {
    return Column(
      children: [
        Text(
          amount,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 4),
        Text(period, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildEarningItem(String day, String amount, String trips) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                trips,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(26),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.blue),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🔄 EnhancedDriverHomePage: Building with isOnline=$_isOnline, isLoading=$_isLoading',
    );

    // Add diagnostic logging for layout issues
    debugPrint(
      '🔍 EnhancedDriverHomePage: Starting build - checking layout constraints',
    );

    return WillPopScope(
      onWillPop: () async {
        debugPrint(
          '🔙 EnhancedDriverHomePage: Back button pressed - showing exit confirmation',
        );
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text(
              'Do you want to exit the AlboCarRide driver app?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
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
          padding: const EdgeInsets.all(
            16.0,
          ), // Reduced padding for better space management
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Diagnostic logging for layout
              Builder(
                builder: (context) {
                  debugPrint(
                    '🔍 EnhancedDriverHomePage: Column children building - checking constraints',
                  );
                  return const SizedBox.shrink();
                },
              ),
              // 1️⃣ Header
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
                        color: Colors.white.withAlpha(229),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2️⃣ Embedded Realtime Dashboard
              FutureBuilder<String?>(
                future: _getDriverIdFromAuth(),
                builder: (context, snapshot) {
                  final driverId = snapshot.data;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (driverId == null) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: const ListTile(
                        title: Text('Driver Stats Unavailable'),
                        subtitle: Text(
                          'No driver ID found. Please log in again.',
                        ),
                      ),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.dashboard_outlined,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Driver Dashboard',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isOnline
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                color: _isOnline ? Colors.green : Colors.grey,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _isOnline ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          // 🚀 Embed Realtime Dashboard
                          DriverDashboardV2Realtime(driverId: driverId),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // 3️⃣ Earnings Summary with Pending Requests
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('R245.50', 'Today', Icons.attach_money),
                    _buildStatItem('8', 'Rides', Icons.directions_car),
                    _buildStatItem('4.8', 'Rating', Icons.star),
                    _buildStatItem(
                      '$_pendingOffersCount',
                      'Requests',
                      Icons.notifications,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4️⃣ Available Ride Requests Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Ride Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (_pendingOffersCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_pendingOffersCount new',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Real-time ride requests from customers in your area',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Show available ride requests (from ride_requests table)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _availableRideRequests.isNotEmpty
                            ? Colors.blue[50]!
                            : Colors.grey[50]!,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _availableRideRequests.isNotEmpty
                              ? Colors.blue[100]!
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _availableRideRequests.isNotEmpty
                                      ? '${_availableRideRequests.length} ride requests available in your area'
                                      : 'No ride requests available at the moment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _availableRideRequests.isNotEmpty
                                        ? Colors.blue[800]!
                                        : Colors.grey[600]!,
                                  ),
                                ),
                                if (_availableRideRequests.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Tap refresh to check for new requests',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600]!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              size: 16,
                              color: _availableRideRequests.isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            onPressed: _fetchAvailableRideRequests,
                            tooltip: 'Refresh requests',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    if (_availableRideRequests.isNotEmpty && !_isOnline)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50]!,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red[100]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, size: 14, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Go online to accept these requests',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red[700]!,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_availableRideRequests.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50]!,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange[100]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No ride requests found. Check back later or try refreshing.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange[700]!,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Show ride offers (from ride_offers table)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: const OfferBoard(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 5️⃣ Quick Actions - Single section with all buttons visible
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Manage your driver status and access key features',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.6,
                          ),
                      children: [
                        _buildActionCard(
                          icon: _isOnline
                              ? Icons.offline_bolt
                              : Icons.directions_car,
                          title: _isOnline ? 'Go Offline' : 'Go Online',
                          color: _isOnline ? Colors.red : Colors.green,
                          onTap: _isLoading ? null : _toggleOnlineStatus,
                        ),
                        _buildActionCard(
                          icon: Icons.schedule,
                          title: 'Schedule',
                          color: Colors.orange,
                          onTap: () => _showScheduleModal(context),
                        ),
                        _buildActionCard(
                          icon: Icons.analytics,
                          title: 'Earnings',
                          color: Colors.purple,
                          onTap: () => _showEarningsModal(context),
                        ),
                        _buildActionCard(
                          icon: Icons.settings,
                          title: 'Settings',
                          color: Colors.blueGrey,
                          onTap: () => _showSettingsModal(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6️⃣ Recent Activity
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your recent trips and earnings',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        _buildRideItem(
                          'John D.',
                          'Downtown • R18.75 • Completed',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildRideItem(
                          'Sarah M.',
                          'Airport • R32.50 • In Progress',
                          Icons.pending,
                          Colors.orange,
                        ),
                        _buildRideItem(
                          'Mike T.',
                          'Mall • R24.90 • Completed',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/rides-history');
                        },
                        child: const Text('View All Rides'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Use min to fit content
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.green), // Even smaller icon
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12, // Smaller font
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9, // Smaller font
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
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
        onTap: () {
          debugPrint(
            '🎯 ActionCard: "$title" tapped - onTap: ${onTap != null}',
          );
          if (onTap != null) {
            onTap();
          } else {
            debugPrint('⚠️ ActionCard: "$title" has null onTap handler');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Use min to fit content
            children: [
              Container(
                width: 40, // Reduced from 48
                height: 40, // Reduced from 48
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color), // Reduced from 24
              ),
              const SizedBox(height: 8), // Reduced from 12
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12, // Reduced from 14
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Allow text to wrap
                overflow: TextOverflow.ellipsis,
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
            color: Colors.black.withAlpha(13),
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
              color: color.withAlpha(26),
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

  Widget _buildSecondaryActionCard({
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
        onTap: () {
          debugPrint(
            '🎯 SecondaryActionCard: "$title" tapped - onTap: ${onTap != null}',
          );
          if (onTap != null) {
            onTap();
          } else {
            debugPrint(
              '⚠️ SecondaryActionCard: "$title" has null onTap handler',
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
