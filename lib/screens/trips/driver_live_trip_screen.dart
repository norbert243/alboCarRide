import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/driver_eta_widget.dart';

class DriverLiveTripScreen extends StatefulWidget {
  final String driverId;
  final String tripId;
  const DriverLiveTripScreen({required this.driverId, required this.tripId, super.key});

  @override
  State<DriverLiveTripScreen> createState() => _DriverLiveTripScreenState();
}

class _DriverLiveTripScreenState extends State<DriverLiveTripScreen> {
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _locationSubscription;
  final supabase = Supabase.instance.client;
  bool _updating = false;
  String _tripStatus = 'in_progress';
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 DriverLiveTripScreen: Initializing for trip ${widget.tripId}');
    _startLocationUpdates();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    try {
      debugPrint('📋 DriverLiveTripScreen: Loading trip data for ${widget.tripId}');
      final tripData = await supabase
          .from('trips')
          .select('status, pickup_lat, pickup_lng, destination_lat, destination_lng')
          .eq('id', widget.tripId)
          .single();
      
      if (mounted) {
        setState(() {
          _tripStatus = tripData['status'] ?? 'in_progress';
        });
        debugPrint('✅ DriverLiveTripScreen: Trip status loaded: $_tripStatus');
        
        // Add pickup and destination markers
        _addTripMarkers(tripData);
      }
    } catch (e) {
      debugPrint('❌ DriverLiveTripScreen: Failed to load trip data: $e');
    }
  }

  void _addTripMarkers(Map<String, dynamic> tripData) {
    final pickupLat = tripData['pickup_lat'];
    final pickupLng = tripData['pickup_lng'];
    final destLat = tripData['destination_lat'];
    final destLng = tripData['destination_lng'];

    if (pickupLat != null && pickupLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupLat.toDouble(), pickupLng.toDouble()),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    if (destLat != null && destLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat.toDouble(), destLng.toDouble()),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Add route polyline (simplified - in production use Directions API)
    if (pickupLat != null && pickupLng != null && destLat != null && destLng != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: [
            LatLng(pickupLat.toDouble(), pickupLng.toDouble()),
            LatLng(destLat.toDouble(), destLng.toDouble()),
          ],
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startLocationUpdates() async {
    debugPrint('📍 DriverLiveTripScreen: Requesting location permissions');
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('❌ DriverLiveTripScreen: Location permission denied');
      return;
    }

    debugPrint('✅ DriverLiveTripScreen: Location permission granted, starting updates');
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((position) async {
      final newPosition = LatLng(position.latitude, position.longitude);
      debugPrint('📍 DriverLiveTripScreen: New position - lat: ${position.latitude}, lng: ${position.longitude}, speed: ${position.speed}');
      
      setState(() => _currentPosition = newPosition);

      // Update driver location in database (debounced)
      if (!_updating) {
        _updating = true;
        try {
          await supabase.rpc('update_driver_location', params: {
            'p_driver_id': widget.driverId,
            'p_lat': position.latitude,
            'p_lng': position.longitude,
            'p_speed': position.speed
          });
          debugPrint('✅ DriverLiveTripScreen: Location updated in database');
        } catch (e) {
          debugPrint('❌ DriverLiveTripScreen: Failed to update location: $e');
        }
        
        // Debounce updates to prevent database overload
        Future.delayed(const Duration(seconds: 2), () => _updating = false);
      }

      // Update map camera to follow driver
      _mapController.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
        }, onError: (error) {
      debugPrint('❌ DriverLiveTripScreen: Location stream error: $error');
    });
  }

  Future<void> _updateTripStatus(String status) async {
    debugPrint('🔄 DriverLiveTripScreen: Updating trip status to: $status');
    try {
      final result = await supabase.rpc('update_trip_status', params: {
        'p_driver_id': widget.driverId,
        'p_trip_id': widget.tripId,
        'p_status': status,
      });
      
      if (mounted) {
        setState(() => _tripStatus = result.data['new_status']);
        debugPrint('✅ DriverLiveTripScreen: Trip status updated to: $_tripStatus');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip status updated: $_tripStatus')),
        );
      }
    } catch (e) {
      debugPrint('❌ DriverLiveTripScreen: Failed to update trip status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 DriverLiveTripScreen: Disposing resources');
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ DriverLiveTripScreen: Building with status $_tripStatus, position: $_currentPosition');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trip Navigation'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(-26.2041, 28.0473), // Default to Johannesburg
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              debugPrint('🗺️ DriverLiveTripScreen: Map controller initialized');
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            polylines: _polylines,
          ),
          
          // ETA Widget positioned at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: DriverEtaWidget(
              tripId: widget.tripId,
              driverId: widget.driverId,
              showNotifications: true,
              refreshInterval: const Duration(seconds: 15),
            ),
          ),
          
          // Trip status controls positioned at bottom
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Status: $_tripStatus',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusButton('driver_arrived', 'Arrived', Colors.orange),
                      _buildStatusButton('in_progress', 'Start Trip', Colors.green),
                      _buildStatusButton('completed', 'Complete', Colors.blue),
                    ],
                  ),
                  if (_currentPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Current Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, String label, Color color) {
    return ElevatedButton(
      onPressed: () => _updateTripStatus(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}