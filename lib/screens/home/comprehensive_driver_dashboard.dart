import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/services/driver_location_service.dart';
import 'package:albocarride/services/ride_matching_service.dart';
import 'package:albocarride/services/driver_deposit_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/trip_card_widget.dart';
import 'package:albocarride/widgets/offer_board.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import '../driver/verification_page.dart';
import '../driver/waiting_for_review_page.dart';

class ComprehensiveDriverDashboard extends StatefulWidget {
  const ComprehensiveDriverDashboard({super.key});

  @override
  State<ComprehensiveDriverDashboard> createState() =>
      _ComprehensiveDriverDashboardState();
}

class _ComprehensiveDriverDashboardState
    extends State<ComprehensiveDriverDashboard> {
  final TripService _tripService = TripService();
  final DriverLocationService _locationService = DriverLocationService();
  final RideMatchingService _matchingService = RideMatchingService();
  final DriverDepositService _depositService = DriverDepositService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Driver state
  bool _isOnline = false;
  bool _isLoading = false;
  bool _hasActiveTrip = false;
  Trip? _activeTrip;
  String? _driverId;
  String? _verificationStatus;
  String? _vehicleType;
  String? _driverName;

  // Earnings and metrics
  double _currentBalance = 0.0;
  double _todayEarnings = 0.0;
  double _weeklyEarnings = 0.0;
  int _completedTripsToday = 0;
  int _completedTripsWeekly = 0;
  double _averageRating = 0.0;
  int _totalRatings = 0;

  // Recent trips
  List<Map<String, dynamic>> _recentTrips = [];

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  @override
  void dispose() {
    _locationService.dispose();
    _matchingService.dispose();
    super.dispose();
  }

  Future<void> _initializeDriver() async {
    setState(() => _isLoading = true);
    try {
      // Get driver ID from session
      _driverId = await SessionService.getUserIdStatic();
      if (_driverId == null) {
        _redirectToLogin();
        return;
      }

      // Check verification status and load profile data
      await _loadDriverProfile();

      // Handle verification status
      if (_verificationStatus == 'pending') {
        _redirectToWaitingForReview();
        return;
      } else if (_verificationStatus != 'approved') {
        _redirectToVerification();
        return;
      }

      // Check if vehicle type is set
      if (_vehicleType == null || _vehicleType!.isEmpty) {
        _redirectToVehicleTypeSelection();
        return;
      }

      // Load all driver data
      await _loadDriverData();
    } catch (e) {
      debugPrint('Error initializing driver: $e');
      CustomToast.show(context: context, message: 'Failed to load driver data');
    } finally {
      if (mounted) {
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

      setState(() {
        _verificationStatus =
            profileResponse['verification_status'] ?? 'pending';
        _vehicleType = driverResponse['vehicle_type'];
        _driverName = profileResponse['full_name'];
        _averageRating = (profileResponse['rating'] as num?)?.toDouble() ?? 0.0;
        _totalRatings =
            (profileResponse['total_ratings'] as num?)?.toInt() ?? 0;
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

  Future<void> _loadDriverData() async {
    try {
      // Load online status
      await _loadOnlineStatus();

      // Load earnings and balance
      await _loadEarningsData();

      // Load recent trips
      await _loadRecentTrips();

      // Check for active trip
      await _checkActiveTrip();
    } catch (e) {
      debugPrint('Error loading driver data: $e');
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

  Future<void> _loadEarningsData() async {
    try {
      // Get current balance from wallet
      final balance = await _depositService.getDriverBalance(_driverId!);

      // Calculate today's earnings (trips completed today)
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final todayTrips = await _supabase
          .from('trips')
          .select('final_price, commission_amount')
          .eq('driver_id', _driverId!)
          .eq('status', 'completed')
          .gte('end_time', todayStart.toIso8601String());

      double todayEarnings = 0.0;
      for (final trip in todayTrips) {
        final price = (trip['final_price'] as num?)?.toDouble() ?? 0;
        final commission = (trip['commission_amount'] as num?)?.toDouble() ?? 0;
        todayEarnings += (price - commission);
      }

      // Calculate weekly earnings (last 7 days)
      final weekStart = today.subtract(const Duration(days: 7));
      final weeklyTrips = await _supabase
          .from('trips')
          .select('final_price, commission_amount')
          .eq('driver_id', _driverId!)
          .eq('status', 'completed')
          .gte('end_time', weekStart.toIso8601String());

      double weeklyEarnings = 0.0;
      for (final trip in weeklyTrips) {
        final price = (trip['final_price'] as num?)?.toDouble() ?? 0;
        final commission = (trip['commission_amount'] as num?)?.toDouble() ?? 0;
        weeklyEarnings += (price - commission);
      }

      setState(() {
        _currentBalance = balance;
        _todayEarnings = todayEarnings;
        _weeklyEarnings = weeklyEarnings;
        _completedTripsToday = todayTrips.length;
        _completedTripsWeekly = weeklyTrips.length;
      });
    } catch (e) {
      debugPrint('Error loading earnings data: $e');
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

  Future<void> _toggleOnlineStatus() async {
    if (_isLoading) return;

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

  void _onTripCompleted() {
    setState(() {
      _hasActiveTrip = false;
      _activeTrip = null;
    });

    // Refresh earnings data after trip completion
    _loadEarningsData();
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
                '\$${_currentBalance.toStringAsFixed(2)}',
                'Current Balance',
                Icons.account_balance_wallet,
                Colors.green,
              ),
              _buildEarningItem(
                '\$${_todayEarnings.toStringAsFixed(2)}',
                'Today',
                Icons.today,
                Colors.blue,
              ),
              _buildEarningItem(
                '\$${_weeklyEarnings.toStringAsFixed(2)}',
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

  Widget _buildPerformanceMetrics() {
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
                '$_completedTripsToday',
                'Trips Today',
                Icons.directions_car,
                Colors.blue,
              ),
              _buildMetricItem(
                '$_completedTripsWeekly',
                'Weekly Trips',
                Icons.calendar_today,
                Colors.green,
              ),
              _buildMetricItem(
                '${_averageRating.toStringAsFixed(1)}',
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
                activeColor: Colors.green,
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

            // Performance metrics
            _buildPerformanceMetrics(),
            const SizedBox(height: 16),

            // Recent trips
            _buildRecentTrips(),
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
