import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/services/wallet_service.dart';
import 'package:albocarride/services/driver_location_service.dart';
import 'package:albocarride/services/ride_matching_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/trip_card_widget.dart';
import 'package:albocarride/widgets/offer_board.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/services/telemetry_service.dart';
import '../driver/deposit_upload_page.dart';

class ComprehensiveDriverDashboard extends StatefulWidget {
  const ComprehensiveDriverDashboard({super.key});

  @override
  State<ComprehensiveDriverDashboard> createState() =>
      _ComprehensiveDriverDashboardState();
}

class _ComprehensiveDriverDashboardState
    extends State<ComprehensiveDriverDashboard> {
  final TripService _tripService = TripService();
  final WalletService _walletService = WalletService.instance;
  final DriverLocationService _locationService = DriverLocationService();
  final RideMatchingService _matchingService = RideMatchingService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Dashboard data
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _isOnline = false;
  bool _hasActiveTrip = false;
  Trip? _activeTrip;
  String? _driverId;
  String? _verificationStatus;
  String? _vehicleType;
  String? _driverName;

  // Recent trips
  List<Map<String, dynamic>> _recentTrips = [];
  int _tripPage = 1; // Start with page 1
  final int _tripPageSize = 5;
  bool _hasMoreTrips = true;

  // Recent payments
  List<Map<String, dynamic>> _recentPayments = [];

  // Wallet subscription
  StreamSubscription? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _locationService.dispose();
    _matchingService.dispose();
    _walletSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      debugPrint('Starting dashboard load...');

      // Get driver ID from session
      _driverId = await SessionService.getUserIdStatic();
      debugPrint('Driver ID: $_driverId');

      if (_driverId == null) {
        debugPrint('No driver ID found, redirecting to login');
        _redirectToLogin();
        return;
      }

      // Subscribe to wallet updates
      _subscribeToWalletUpdates();

      // Load dashboard data via single RPC call
      debugPrint('Fetching dashboard data...');
      final data = await _tripService.fetchDriverDashboard(_driverId!);
      debugPrint('Dashboard data received: $data');

      // Load verification status and profile data
      await _loadDriverProfile();

      // Handle verification status
      debugPrint('Verification status: $_verificationStatus');
      if (_verificationStatus == 'pending') {
        debugPrint('Verification pending, redirecting to waiting review');
        _redirectToWaitingForReview();
        return;
      } else if (_verificationStatus != 'approved') {
        debugPrint('Verification not approved, redirecting to verification');
        _redirectToVerification();
        return;
      }

      // Check if vehicle type is set
      debugPrint('Vehicle type: $_vehicleType');
      if (_vehicleType == null || _vehicleType!.isEmpty) {
        debugPrint('No vehicle type set, redirecting to vehicle selection');
        _redirectToVehicleTypeSelection();
        return;
      }

      // Load online status and active trip
      await _loadOnlineStatus();
      await _checkActiveTrip();
      
      // Load initial trips
      await _loadRecentTrips();

      // Load recent payments
      await _loadRecentPayments();

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }

      debugPrint('Dashboard loaded successfully');
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      debugPrint('Stack trace: ${e.toString()}');
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Failed to load dashboard: $e',
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      // Load profile verification status and name
      final profileResponse = await _supabase
          .from('profiles')
          .select('verification_status, full_name, rating, total_ratings')
          .eq('id', _driverId!)
          .single();

      // Load driver vehicle type
      final driverResponse = await _supabase
          .from('drivers')
          .select('vehicle_type')
          .eq('id', _driverId!)
          .single();

      if (mounted) {
        setState(() {
          _verificationStatus =
              profileResponse['verification_status'] ?? 'pending';
          _vehicleType = driverResponse['vehicle_type'];
          _driverName = profileResponse['full_name'];
        });
      }
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
      if (mounted) {
        setState(() {
          _verificationStatus = 'pending';
          _vehicleType = null;
          _driverName = null;
        });
      }
    }
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('is_online')
          .eq('id', _driverId!)
          .single();
      if (mounted) {
        setState(() {
          _isOnline = response['is_online'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading online status: $e');
    }
  }

  Future<void> _loadRecentTrips() async {
    if (_driverId == null) return;
    try {
      final trips = await _tripService.getTripHistory(_driverId!, limit: _tripPageSize, offset: 0);
      if (mounted) {
        setState(() {
          _recentTrips = trips;
          _hasMoreTrips = trips.length == _tripPageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent trips: $e');
    }
  }

  Future<void> _loadMoreTrips() async {
    if (!_hasMoreTrips || _driverId == null) return;

    try {
      final offset = _tripPage * _tripPageSize;
      final trips = await _tripService.getTripHistory(
        _driverId!,
        limit: _tripPageSize,
        offset: offset,
      );

      if (mounted) {
        setState(() {
          _recentTrips.addAll(trips);
          _tripPage++;
          _hasMoreTrips = trips.length == _tripPageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading more trips: $e');
      await TelemetryService.instance.log('load_more_trips_error', e.toString(), {'driver_id': _driverId});
    }
  }

  Future<void> _loadRecentPayments() async {
    if (_driverId == null) return;
    try {
      // This method does not exist in TripService, assuming it should be there.
      // If not, this needs to be implemented in TripService or another service.
      // For now, let's create a placeholder in TripService or just ignore it.
      // final payments = await _tripService.fetchRecentPayments(
      //   _driverId!,
      //   limit: 5,
      // );
      // if (mounted) {
      //   setState(() {
      //     _recentPayments = payments;
      //   });
      // }
    } catch (e) {
      debugPrint('Error loading recent payments: $e');
    }
  }

  void _subscribeToWalletUpdates() {
    if (_driverId != null) {
      _walletService.subscribeToWallet(_driverId!, (newBalance) {
        if (mounted) {
          debugPrint('Wallet update received: $newBalance');
          setState(() {
            if (_dashboardData != null) {
              _dashboardData!['wallet_balance'] = newBalance;
              _dashboardData!['balance'] = newBalance; // Also update this for consistency
            }
          });
        }
      });
    }
  }

  Future<void> _checkActiveTrip() async {
    if (_driverId == null) return;
    try {
      final activeTripData = await _tripService.getActiveTrip(_driverId!);
      if (mounted) {
        if (activeTripData != null) {
          final trip = Trip.fromMap(activeTripData);
          setState(() {
            _hasActiveTrip = true;
            _activeTrip = trip;
          });
          _subscribeToTripUpdates();
        } else {
          setState(() {
            _hasActiveTrip = false;
            _activeTrip = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking active trip: $e');
    }
  }

  void _subscribeToTripUpdates() {
    if (_activeTrip != null) {
      _tripService.subscribeToTrip(_activeTrip!.id).listen((tripData) {
        if (mounted && tripData.isNotEmpty) {
          final tripUpdate = Trip.fromMap(tripData);
          setState(() {
            _activeTrip = tripUpdate;
            _hasActiveTrip =
                tripUpdate.status != 'completed' &&
                    tripUpdate.status != 'cancelled';
          });
        }
      });
    }
  }

  Future<bool> _canGoOnline(String driverId) async {
    try {
      final allowed = await _walletService.canGoOnlineEnhanced(driverId);
      return allowed;
    } catch (e) {
      debugPrint('Error checking wallet lockout: $e');
      return false;
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_isLoading) return;

    // Check if driver can go online (has sufficient balance)
    if (!_isOnline) {
      final canGoOnline = await _canGoOnline(_driverId!);
      if (!canGoOnline) {
        _showDepositRequiredDialog();
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final newStatus = !_isOnline;

      await _supabase
          .from('profiles')
          .update({'is_online': newStatus})
          .eq('id', _driverId!);

      if(mounted) {
        setState(() => _isOnline = newStatus);

        // Start/stop location tracking and matching service based on online status
        if (newStatus) {
          await _locationService.startLocationTracking();
          await _matchingService.startMatchingService();
          CustomToast.show(
            context: context,
            message: 'You are now online and ready to accept rides',
          );
        } else {
          await _locationService.stopLocationTracking();
          await _matchingService.stopMatchingService();
          CustomToast.show(context: context, message: 'You are now offline');
        }
      }

      debugPrint('Online status updated: $newStatus');
    } catch (e) {
      debugPrint('Error toggling online status: $e');
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Failed to update online status',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDepositRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deposit Required'),
        content: const Text(
          'Your wallet is below the required deposit amount. '
          'Please submit a deposit and upload proof to go online.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToDepositUpload();
            },
            child: const Text('Submit Deposit'),
          ),
        ],
      ),
    );
  }

  void _navigateToDepositUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DepositUploadPage()),
    );
  }

  void _onTripCompleted() {
    setState(() {
      _hasActiveTrip = false;
      _activeTrip = null;
    });

    // Refresh dashboard data after trip completion
    _loadDashboard();
    _loadRecentTrips();

    // Automatically go back online after trip completion
    if (!_isOnline) {
      _toggleOnlineStatus();
    }
  }

  void _onTripCancelled() {
    setState(() {
      _hasActiveTrip = false;
      _activeTrip = null;
    });
  }

  Future<void> _signOut() async {
    await _locationService.stopLocationTracking();
    await _matchingService.stopMatchingService();
    await _supabase.auth.signOut();
    await SessionService.clearSessionStatic();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/role-selection',
        (route) => false,
      );
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/role-selection',
        (route) => false,
      );
    }
  }

  void _redirectToVerification() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/verification',
        (route) => false,
      );
    }
  }

  void _redirectToWaitingForReview() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/waiting-review',
        (route) => false,
      );
    }
  }

  void _redirectToVehicleTypeSelection() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/vehicle-type-selection',
        (route) => false,
      );
    }
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: AppTheme.theme.textTheme.displayMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 200.0,
                  backgroundColor: AppTheme.primaryColor,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: _signOut,
                      tooltip: 'Sign Out',
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(_isOnline ? 'You are Online' : 'You are Offline', style: const TextStyle(fontSize: 16)),
                    background: _buildHeader(),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      ..._buildOnlineToggle(),
                      ..._buildActiveTrip(),
                      if (_isOnline && !_hasActiveTrip) ..._buildOfferBoard(),
                      ..._buildEarningsSummary(),
                      ..._buildWalletSection(),
                      ..._buildPerformanceMetrics(),
                      ..._buildRecentTrips(),
                      ..._buildRecentPayments(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildOnlineToggle() {
    return [
      _buildSectionTitle('Online Status'),
      Card(
        child: SwitchListTile(
          title: Text(_isOnline ? 'You are Online' : 'You are Offline'),
          subtitle: Text(_isOnline ? 'Ready to accept new rides' : 'Go online to start earning'),
          value: _isOnline,
          onChanged: _isLoading ? null : (value) => _toggleOnlineStatus(),
          secondary: Icon(_isOnline ? Icons.power : Icons.power_off, color: _isOnline ? Colors.green : Colors.red),
        ),
      ),
    ];
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isOnline
              ? [Colors.green.shade700, Colors.green.shade400]
              : [AppTheme.primaryColor, Colors.blue.shade400],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _driverName ?? 'Driver',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildVerificationStatus(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_verificationStatus) {
      case 'approved':
        statusColor = Colors.lightGreenAccent;
        statusText = 'Verified';
        statusIcon = Icons.verified;
        break;
      case 'pending':
        statusColor = Colors.amberAccent;
        statusText = 'Pending';
        statusIcon = Icons.hourglass_top;
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusText = 'Rejected';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Not Verified';
        statusIcon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEarningsSummary() {
    if (_dashboardData == null) return [const SizedBox.shrink()];

    final balance = (_dashboardData!['balance'] as num?)?.toDouble() ?? 0.0;
    final todayEarnings = (_dashboardData!['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final weeklyEarnings = (_dashboardData!['weekly_earnings'] as num?)?.toDouble() ?? 0.0;

    return [
      _buildSectionTitle('Earnings'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEarningItem('Current Balance', 'R${balance.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.green),
              _buildEarningItem('Today', 'R${todayEarnings.toStringAsFixed(2)}', Icons.today, Colors.blue),
              _buildEarningItem('This Week', 'R${weeklyEarnings.toStringAsFixed(2)}', Icons.calendar_today, Colors.purple),
            ],
          ),
        ),
      )
    ];
  }

  Widget _buildEarningItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 8),
        Text(label, style: AppTheme.theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: 18)),
      ],
    );
  }

  import 'package:albocarride/screens/driver/payment_details_page.dart';

//... other code

  List<Widget> _buildWalletSection() {
    if (_dashboardData == null) return [const SizedBox.shrink()];
    
    final walletBalance = (_dashboardData!['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final totalEarnings = (_dashboardData!['total_earnings'] as num?)?.toDouble() ?? 0.0;
    final pendingWithdrawals = (_dashboardData!['pending_withdrawals'] as num?)?.toDouble() ?? 0.0;

    return [
      _buildSectionTitle('Wallet'),
      Card(
        child: Column(
          children: [
            _buildWalletItem('Available Balance', 'R${walletBalance.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.green),
            _buildWalletItem('Total Earnings', 'R${totalEarnings.toStringAsFixed(2)}', Icons.attach_money, Colors.blue),
            _buildWalletItem('Pending Withdrawals', 'R${pendingWithdrawals.toStringAsFixed(2)}', Icons.pending, Colors.orange),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Manage Payment Methods'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentDetailsPage()),
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildWalletItem(String label, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(value, style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _buildPerformanceMetrics() {
    if (_dashboardData == null) return [const SizedBox.shrink()];

    final completedTrips = (_dashboardData!['completed_trips'] as num?)?.toInt() ?? 0;
    final rating = (_dashboardData!['rating'] as num?)?.toDouble() ?? 0.0;

    return [
      _buildSectionTitle('Performance'),
      Card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildEarningItem('Completed Trips', '$completedTrips', Icons.directions_car, Colors.blue),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildEarningItem('Rating', rating.toStringAsFixed(1), Icons.star, Colors.amber),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildActiveTrip() {
    if (!_hasActiveTrip || _activeTrip == null) {
      return [const SizedBox.shrink()];
    }

    return [
      _buildSectionTitle('Active Trip'),
      Card(
        color: AppTheme.primaryColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TripCardWidget(
            trip: _activeTrip!,
            onTripCompleted: _onTripCompleted,
            onTripCancelled: _onTripCancelled,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildOfferBoard() {
    return [
      _buildSectionTitle('Available Rides'),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: OfferBoard(),
        ),
      ),
    ];
  }
  
  List<Widget> _buildRecentTrips() {
    return [
      _buildSectionTitle('Recent Trips'),
      if (_recentTrips.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('No recent trips'))))
      else
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentTrips.length,
          itemBuilder: (context, index) {
            final trip = _recentTrips[index];
            return Card(
              child: TripCardWidget(
                trip: Trip.fromMap(trip),
                onTripCompleted: _onTripCompleted,
                onTripCancelled: _onTripCancelled,
              ),
            );
          },
        ),
      if (_hasMoreTrips)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ElevatedButton(
              onPressed: _loadMoreTrips,
              child: const Text('Load More'),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildRecentPayments() {
    return [
      _buildSectionTitle('Recent Payments'),
      if (_recentPayments.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('No recent payments'))))
      else
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentPayments.length,
          itemBuilder: (context, index) {
            final payment = _recentPayments[index];
            return Card(
              child: _buildPaymentItem(payment),
            );
          },
        ),
    ];
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final type = payment['type'] ?? 'unknown';
    final status = payment['status'] ?? 'unknown';
    final createdAt = payment['created_at'] != null
        ? DateTime.parse(payment['created_at']).toLocal()
        : DateTime.now();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(type == 'withdrawal' ? 'Withdrawal' : 'Payment'),
      subtitle: Text('${createdAt.day}/${createdAt.month}/${createdAt.year}'),
      trailing: Text(
        'R${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: type == 'withdrawal' ? Colors.red : Colors.green,
        ),
      ),
    );
  }
}
