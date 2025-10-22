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
  final WalletService _walletService = WalletService();
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
  int _tripPage = 0;
  final int _tripPageSize = 20;
  bool _hasMoreTrips = true;

  // Recent payments
  List<Map<String, dynamic>> _recentPayments = [];

  // Wallet subscription
  StreamSubscription<Map<String, dynamic>>? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _subscribeToWalletUpdates();
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

      // Load recent payments
      await _loadRecentPayments();

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });

      debugPrint('Dashboard loaded successfully');
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      debugPrint('Stack trace: ${e.toString()}');
      CustomToast.show(
        context: context,
        message: 'Failed to load dashboard: $e',
      );
      setState(() => _isLoading = false);
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

      setState(() {
        _verificationStatus =
            profileResponse['verification_status'] ?? 'pending';
        _vehicleType = driverResponse['vehicle_type'];
        _driverName = profileResponse['full_name'];
      });
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
      setState(() {
        _verificationStatus = 'pending';
        _vehicleType = null;
        _driverName = null;
      });
    }
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('is_online')
          .eq('id', _driverId!)
          .single();

      setState(() {
        _isOnline = response['is_online'] ?? false;
      });
    } catch (e) {
      debugPrint('Error loading online status: $e');
    }
  }

  Future<void> _loadRecentTrips() async {
    try {
      final trips = await _tripService.getTripHistory(_driverId!, limit: 5);
      setState(() {
        _recentTrips = trips;
      });
    } catch (e) {
      debugPrint('Error loading recent trips: $e');
    }
  }

  Future<void> _loadMoreTrips() async {
    if (!_hasMoreTrips) return;

    try {
      final offset = _tripPage * _tripPageSize;
      final trips = await _walletService.fetchTripHistory(
        _driverId!,
        limit: _tripPageSize,
        offset: offset,
      );

      setState(() {
        _recentTrips.addAll(trips);
        _tripPage++;
        _hasMoreTrips = trips.length == _tripPageSize;
      });
    } catch (e) {
      debugPrint('Error loading more trips: $e');
      await _walletService.logTelemetry('load_more_trips_error', e.toString());
    }
  }

  Future<void> _loadRecentPayments() async {
    try {
      final payments = await _tripService.fetchRecentPayments(
        _driverId!,
        limit: 5,
      );
      setState(() {
        _recentPayments = payments;
      });
    } catch (e) {
      debugPrint('Error loading recent payments: $e');
    }
  }

  void _subscribeToWalletUpdates() {
    if (_driverId != null) {
      _walletSubscription = _tripService
          .subscribeToWallet(_driverId!)
          .listen(
            (walletData) {
              if (mounted && walletData.isNotEmpty) {
                debugPrint('Wallet update received: $walletData');
                // Update dashboard data with new wallet balance
                setState(() {
                  if (_dashboardData != null) {
                    _dashboardData!['wallet_balance'] = walletData['balance'];
                  }
                });
              }
            },
            onError: (error) {
              debugPrint('Wallet subscription error: $error');
            },
          );
    }
  }

  Future<void> _checkActiveTrip() async {
    try {
      final activeTrip = await _tripService.getActiveTrip(_driverId!);
      if (activeTrip != null) {
        final trip = Trip.fromMap(activeTrip);
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
    } catch (e) {
      debugPrint('Error checking active trip: $e');
    }
  }

  void _subscribeToTripUpdates() {
    if (_activeTrip != null) {
      _tripService.subscribeToTrip(_activeTrip!.id).listen((tripUpdate) {
        if (mounted) {
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

      debugPrint('Online status updated: $newStatus');
    } catch (e) {
      debugPrint('Error toggling online status: $e');
      CustomToast.show(
        context: context,
        message: 'Failed to update online status',
      );
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
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/role-selection',
      (route) => false,
    );
  }

  void _redirectToVerification() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/verification',
      (route) => false,
    );
  }

  void _redirectToWaitingForReview() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/waiting-review',
      (route) => false,
    );
  }

  void _redirectToVehicleTypeSelection() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/vehicle-type-selection',
      (route) => false,
    );
  }

  Widget _buildVerificationStatus() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_verificationStatus) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Verified Driver';
        statusIcon = Icons.verified;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Verification Pending';
        statusIcon = Icons.hourglass_top;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Verification Rejected';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Not Verified';
        statusIcon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(102)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
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

  Widget _buildHeader() {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${_driverName ?? 'Driver'}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOnline
                          ? _hasActiveTrip
                                ? 'Active trip in progress'
                                : 'You\'re online and ready to accept rides!'
                          : 'Ready to start earning?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha(229),
                      ),
                    ),
                  ],
                ),
              ),
              _buildVerificationStatus(),
            ],
          ),
          const SizedBox(height: 16),
          if (_vehicleType != null && _vehicleType!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Vehicle: ${_vehicleType == 'car' ? 'Car' : 'Motorcycle'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );
  }

  Widget _buildEarningsSummary() {
    if (_dashboardData == null) return const SizedBox.shrink();

    final balance = (_dashboardData!['balance'] as num?)?.toDouble() ?? 0.0;
    final todayEarnings =
        (_dashboardData!['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final weeklyEarnings =
        (_dashboardData!['weekly_earnings'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
            'Earnings Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEarningItem(
                'R${balance.toStringAsFixed(2)}',
                'Current Balance',
                Icons.account_balance_wallet,
                Colors.green,
              ),
              _buildEarningItem(
                'R${todayEarnings.toStringAsFixed(2)}',
                'Today',
                Icons.today,
                Colors.blue,
              ),
              _buildEarningItem(
                'R${weeklyEarnings.toStringAsFixed(2)}',
                'This Week',
                Icons.calendar_today,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildWalletSection() {
    if (_dashboardData == null) return const SizedBox.shrink();

    final walletBalance =
        (_dashboardData!['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final totalEarnings =
        (_dashboardData!['total_earnings'] as num?)?.toDouble() ?? 0.0;
    final pendingWithdrawals =
        (_dashboardData!['pending_withdrawals'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
            'Wallet Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWalletItem(
                'R${walletBalance.toStringAsFixed(2)}',
                'Available Balance',
                Icons.account_balance_wallet,
                Colors.green,
              ),
              _buildWalletItem(
                'R${totalEarnings.toStringAsFixed(2)}',
                'Total Earnings',
                Icons.attach_money,
                Colors.blue,
              ),
              _buildWalletItem(
                'R${pendingWithdrawals.toStringAsFixed(2)}',
                'Pending Withdrawals',
                Icons.pending,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
    if (_dashboardData == null) return const SizedBox.shrink();

    final completedTrips =
        (_dashboardData!['completed_trips'] as num?)?.toInt() ?? 0;
    final rating = (_dashboardData!['rating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                '$completedTrips',
                'Completed Trips',
                Icons.directions_car,
                Colors.blue,
              ),
              _buildMetricItem(
                rating.toStringAsFixed(1),
                'Rating',
                Icons.star,
                Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRecentTrips() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Recent Trips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_recentTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No recent trips',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                ..._recentTrips.map(
                  (trip) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TripCardWidget(
                      trip: Trip.fromMap(trip),
                      onTripCompleted: _onTripCompleted,
                      onTripCancelled: _onTripCancelled,
                    ),
                  ),
                ),
                if (_hasMoreTrips)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _loadMoreTrips,
                        child: const Text('Load More Trips'),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Recent Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_recentPayments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No recent payments',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._recentPayments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPaymentItem(payment),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final type = payment['type'] ?? 'unknown';
    final status = payment['status'] ?? 'unknown';
    final createdAt = payment['created_at'] != null
        ? DateTime.parse(payment['created_at']).toLocal()
        : DateTime.now();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.pending;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'Failed';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, size: 20, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == 'withdrawal' ? 'Withdrawal' : 'Payment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'R${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: type == 'withdrawal' ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withAlpha(102)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? 'You are online' : 'You are offline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOnline
                        ? 'Ready to accept ride requests'
                        : 'Go online to start earning',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              Switch(
                value: _isOnline,
                onChanged: _isLoading ? null : (value) => _toggleOnlineStatus(),
                activeThumbColor: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrip() {
    if (!_hasActiveTrip || _activeTrip == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Trip',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          TripCardWidget(
            trip: _activeTrip!,
            onTripCompleted: _onTripCompleted,
            onTripCancelled: _onTripCancelled,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferBoard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Available Rides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const OfferBoard(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_dashboardData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver Dashboard')),
        body: const Center(child: Text('No dashboard data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            // Active trip (if any)
            _buildActiveTrip(),
            if (_hasActiveTrip) const SizedBox(height: 16),

            // Online toggle
            _buildOnlineToggle(),
            const SizedBox(height: 16),

            // Earnings summary
            _buildEarningsSummary(),
            const SizedBox(height: 16),

            // Wallet section
            _buildWalletSection(),
            const SizedBox(height: 16),

            // Performance metrics
            _buildPerformanceMetrics(),
            const SizedBox(height: 16),

            // Recent trips
            _buildRecentTrips(),
            const SizedBox(height: 16),

            // Recent payments
            _buildRecentPayments(),
            const SizedBox(height: 16),

            // Offer board (only when online and no active trip)
            if (_isOnline && !_hasActiveTrip) ...[
              _buildOfferBoard(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
