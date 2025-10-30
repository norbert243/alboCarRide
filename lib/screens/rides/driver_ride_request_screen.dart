import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class DriverRideRequestScreen extends StatefulWidget {
  final String driverId;
  const DriverRideRequestScreen({super.key, required this.driverId});

  @override
  State<DriverRideRequestScreen> createState() => _DriverRideRequestScreenState();
}

class _DriverRideRequestScreenState extends State<DriverRideRequestScreen> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _currentRequest;
  RealtimeChannel? _subscription;
  bool _loading = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  GoogleMapController? _mapController;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _subscribeToRideRequests();
    _startLocationTracking();
    _updateDriverOnlineStatus(true);
  }

  void _subscribeToRideRequests() {
    debugPrint('🔍 DriverRideRequestScreen: Subscribing to ride requests');
    _subscription = _sb.channel('ride_requests_driver_${widget.driverId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'ride_requests',
        callback: (payload) {
          debugPrint('🚗 DriverRideRequestScreen: New ride request received: ${payload.newRecord}');
          setState(() => _currentRequest = payload.newRecord);
        },
      )
      .subscribe();
  }

  void _startLocationTracking() async {
    debugPrint('📍 DriverRideRequestScreen: Starting location tracking');
    try {
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 DriverRideRequestScreen: Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('📍 DriverRideRequestScreen: Requesting location permission');
        permission = await Geolocator.requestPermission();
        debugPrint('📍 DriverRideRequestScreen: Permission request result: $permission');
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ DriverRideRequestScreen: Location permission permanently denied');
        _showLocationPermissionDialog();
        return;
      }
      
      if (permission == LocationPermission.denied) {
        debugPrint('❌ DriverRideRequestScreen: Location permission denied');
        return;
      }
      
      // Get current position first
      debugPrint('📍 DriverRideRequestScreen: Getting current position');
      _currentPosition = await Geolocator.getCurrentPosition();
      debugPrint('📍 DriverRideRequestScreen: Got position - ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      setState(() {});

      // Start continuous location updates
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        debugPrint('📍 DriverRideRequestScreen: Location updated - ${position.latitude}, ${position.longitude}');
        setState(() => _currentPosition = position);
        
        // Update driver location in database
        _updateDriverLocation(position);
      });
    } catch (e) {
      debugPrint('❌ DriverRideRequestScreen: Location tracking error - $e');
    }
  }

  Future<void> _updateDriverLocation(Position position) async {
    try {
      await _sb.from('driver_locations').upsert({
        'driver_id': widget.driverId,
        'lat': position.latitude,
        'lng': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('📍 DriverRideRequestScreen: Location updated in database');
    } catch (e) {
      debugPrint('❌ DriverRideRequestScreen: Location update error - $e');
    }
  }
  
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'AlboCarRide needs location access to track your position and match you with nearby riders. '
          'Please enable location permissions in your device settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDriverOnlineStatus(bool online) async {
    try {
      await _sb.from('profiles')
        .update({'is_online': online})
        .eq('id', widget.driverId);
    } catch (e) {
      debugPrint('❌ DriverRideRequestScreen: Online status update error - $e');
    }
  }

  Future<void> _acceptRide() async {
    if (_currentRequest == null) return;
    setState(() => _loading = true);
    try {
      debugPrint('✅ DriverRideRequestScreen: Accepting ride request ${_currentRequest!['id']}');
      final result = await _sb.rpc('driver_accept_ride', params: {
        'p_driver_id': widget.driverId,
        'p_request_id': _currentRequest!['id'],
        'p_offer_price': _currentRequest!['proposed_price'],
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride accepted! Trip created.')),
      );
      
      // Navigate to live trip screen
      Navigator.pushNamed(
        context,
        '/driver-live-trip',
        arguments: {
          'tripId': result['id'],
          'driverId': widget.driverId,
        },
      );
    } catch (e) {
      debugPrint('❌ DriverRideRequestScreen: Accept ride error - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting ride: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _goOffline() async {
    setState(() => _isOnline = false);
    await _updateDriverOnlineStatus(false);
    _positionSubscription?.cancel();
    Navigator.pop(context);
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 8),
          const Text(
            'Live Driver Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${_currentPosition?.latitude?.toStringAsFixed(6) ?? 'N/A'}, Lng: ${_currentPosition?.longitude?.toStringAsFixed(6) ?? 'N/A'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '(Google Maps integration ready)',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideRequestCard() {
    final r = _currentRequest!;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'New Ride Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'R ${r['proposed_price']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationRow(Icons.location_on, 'Pickup', r['pickup_address']),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.flag, 'Dropoff', r['dropoff_address']),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _acceptRide,
                    icon: const Icon(Icons.check),
                    label: const Text('Accept Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () {
                      setState(() => _currentRequest = null);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Request Board'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.white : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.offline_bolt),
            onPressed: _goOffline,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Section
            _buildMapPlaceholder(),
            const SizedBox(height: 16),
            
            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _currentRequest == null ? Icons.search : Icons.notifications_active,
                      color: _currentRequest == null ? Colors.blue : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentRequest == null
                            ? 'Waiting for new ride requests...'
                            : 'New ride request available!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Ride Request Card (if available)
            if (_currentRequest != null) _buildRideRequestCard(),
            
            // Instructions when no requests
            if (_currentRequest == null) ...[
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.directions_car, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready to Accept Rides',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will receive ride requests here automatically',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}