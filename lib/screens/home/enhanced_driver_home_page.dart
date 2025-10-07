import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../../services/driver_location_service.dart';
import '../../services/ride_matching_service.dart';
import '../../models/trip.dart';
import '../../widgets/trip_card_widget.dart';
import '../../widgets/offer_board.dart';
import '../driver/verification_page.dart';
import '../driver/waiting_for_review_page.dart';

class EnhancedDriverHomePage extends StatefulWidget {
  const EnhancedDriverHomePage({super.key});

  @override
  State<EnhancedDriverHomePage> createState() => _EnhancedDriverHomePageState();
}

class _EnhancedDriverHomePageState extends State<EnhancedDriverHomePage> {
  final TripService _tripService = TripService();
  final DriverLocationService _locationService = DriverLocationService();
  final RideMatchingService _matchingService = RideMatchingService();

  bool _isOnline = false;
  bool _isLoading = false;
  bool _hasActiveTrip = false;
  Trip? _activeTrip;
  String? _driverId;
  String? _verificationStatus;
  String? _vehicleType;

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
      _driverId = await AuthService.getUserId();
      if (_driverId == null) {
        _redirectToLogin();
        return;
      }

      // Check verification status and vehicle type
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

      // Load online status and active trip
      await _loadOnlineStatus();
      await _checkActiveTrip();
    } catch (e) {
      debugPrint('Error initializing driver: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      // Load profile verification status
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('verification_status')
          .eq('id', _driverId!)
          .single();

      // Load driver vehicle type
      final driverResponse = await Supabase.instance.client
          .from('drivers')
          .select('vehicle_type')
          .eq('id', _driverId!)
          .single();

      setState(() {
        _verificationStatus =
            profileResponse['verification_status'] ?? 'pending';
        _vehicleType = driverResponse['vehicle_type'];
      });
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
      setState(() {
        _verificationStatus = 'pending';
        _vehicleType = null;
      });
    }
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final response = await Supabase.instance.client
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

  Future<void> _checkActiveTrip() async {
    try {
      final activeTrip = await _tripService.getActiveTrip(_driverId!);
      if (activeTrip != null) {
        // Convert Map to Trip object
        final trip = Trip.fromMap(activeTrip);
        setState(() {
          _hasActiveTrip = true;
          _activeTrip = trip;
        });

        // Subscribe to trip updates if there's an active trip
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

      await Supabase.instance.client
          .from('profiles')
          .update({'is_online': newStatus})
          .eq('id', _driverId!);

      setState(() => _isOnline = newStatus);

      // Start/stop location tracking and matching service based on online status
      if (newStatus) {
        // Start location tracking when going online
        await _locationService.startLocationTracking();
        // Start matching service to listen for ride requests
        await _matchingService.startMatchingService();
      } else {
        // Stop location tracking when going offline
        await _locationService.stopLocationTracking();
        // Stop matching service
        await _matchingService.stopMatchingService();
      }

      debugPrint('Online status updated: $newStatus');
    } catch (e) {
      debugPrint('Error toggling online status: $e');
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
    await AuthService.clearSession();
    await Supabase.instance.client.auth.signOut();

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
                ? _hasActiveTrip
                      ? 'Active trip in progress'
                      : 'You\'re online and ready to accept rides!'
                : 'Ready to start earning?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withAlpha(229), // 0.9 opacity
            ),
          ),
          if (_vehicleType != null && _vehicleType!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51), // 0.2 opacity
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
            ),
          const SizedBox(height: 16),
          if (_isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51), // 0.2 opacity
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

  Widget _buildOnlineToggle() {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isOnline ? 'You\'re Online' : 'You\'re Offline',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
            onChanged: _isLoading ? null : (_) => _toggleOnlineStatus(),
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasActiveTrip && _activeTrip != null) {
      return TripCardWidget(
        trip: _activeTrip!,
        onTripCompleted: _onTripCompleted,
        onTripCancelled: _onTripCancelled,
      );
    }

    if (_isOnline) {
      return const OfferBoard();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Go Online to Start',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toggle the switch above to go online\nand start receiving ride requests',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _isOnline ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _hasActiveTrip
              ? 'Active Trip'
              : _isOnline
              ? 'Online - Ready to Drive'
              : 'Driver Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _isOnline ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: _isOnline ? Colors.green : Colors.white,
        elevation: 1,
        foregroundColor: _isOnline ? Colors.white : Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildOnlineToggle(),
            const SizedBox(height: 24),
            _buildContent(),
          ],
        ),
      ),
    );
  }
}
