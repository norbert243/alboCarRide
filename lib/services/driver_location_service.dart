import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';

/// Service for managing driver location tracking in background
class DriverLocationService {
  static final DriverLocationService _instance =
      DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationUpdateTimer;
  bool _isTracking = false;
  String? _currentDriverId;

  /// Start background location tracking for driver
  Future<void> startLocationTracking() async {
    if (_isTracking) return;

    try {
      // Get driver ID
      _currentDriverId = await SessionService.getUserIdStatic();
      if (_currentDriverId == null) {
        throw Exception('Driver not authenticated');
      }

      // Check location permissions
      final permission = await _checkLocationPermissions();
      if (!permission) {
        throw Exception('Location permissions not granted');
      }

      // Start location tracking
      await _startLocationUpdates();
      _isTracking = true;

      print('Driver location tracking started for driver: $_currentDriverId');
    } catch (e) {
      print('Error starting location tracking: $e');
      rethrow;
    }
  }

  /// Stop background location tracking
  Future<void> stopLocationTracking() async {
    if (!_isTracking) return;

    try {
      await _stopLocationUpdates();
      _isTracking = false;
      _currentDriverId = null;

      print('Driver location tracking stopped');
    } catch (e) {
      print('Error stopping location tracking: $e');
      rethrow;
    }
  }

  /// Check if location tracking is active
  bool get isTracking => _isTracking;

  /// Check and request location permissions
  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Start receiving location updates
  Future<void> _startLocationUpdates() async {
    // Configure location settings for battery optimization
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 50, // Update every 50 meters
      timeLimit: Duration(seconds: 30), // Maximum update interval
    );

    // Start listening to location updates
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            await _handleLocationUpdate(position);
          },
          onError: (error) {
            print('Location stream error: $error');
          },
        );

    // Also set up a timer for periodic updates (fallback)
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_isTracking) {
        await _forceLocationUpdate();
      }
    });
  }

  /// Stop location updates
  Future<void> _stopLocationUpdates() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  /// Handle location update from stream
  Future<void> _handleLocationUpdate(Position position) async {
    if (!_isTracking || _currentDriverId == null) return;

    try {
      await _updateDriverLocationInDatabase(
        _currentDriverId!,
        position.latitude,
        position.longitude,
        position.speed,
        position.accuracy,
      );

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  /// Force a location update (fallback method)
  Future<void> _forceLocationUpdate() async {
    if (!_isTracking || _currentDriverId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      await _updateDriverLocationInDatabase(
        _currentDriverId!,
        position.latitude,
        position.longitude,
        position.speed,
        position.accuracy,
      );

      print(
        'Forced location update: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('Error in forced location update: $e');
    }
  }

  /// Update driver location in Supabase database
  Future<void> _updateDriverLocationInDatabase(
    String driverId,
    double latitude,
    double longitude,
    double? speed,
    double? accuracy,
  ) async {
    try {
      // Insert new location record
      await _supabase.from('driver_locations').insert({
        'driver_id': driverId,
        'lat': latitude,
        'lng': longitude,
        'speed': speed,
        'accuracy': accuracy,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also update the current location in drivers table for quick access
      await _supabase
          .from('drivers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (e) {
      print('Error updating driver location in database: $e');
      rethrow;
    }
  }

  /// Get current driver location
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Get driver's last known location from database
  Future<Map<String, dynamic>?> getLastKnownLocation(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_locations')
          .select('lat, lng, updated_at')
          .eq('driver_id', driverId)
          .order('updated_at', ascending: false)
          .limit(1)
          .single();

      return response;
    } catch (e) {
      print('Error getting last known location: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _stopLocationUpdates();
    _isTracking = false;
    _currentDriverId = null;
  }
}
