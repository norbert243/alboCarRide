import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Basic location service for driver tracking
/// Note: This is a simplified version that will be enhanced with geolocator
class LocationService {
  final SupabaseClient _client = Supabase.instance.client;
  Timer? _locationTimer;
  bool _isTracking = false;
  String? _currentDriverId;

  /// Start tracking driver location (simulated for now)
  Future<void> startTracking(String driverId) async {
    try {
      if (_isTracking) {
        await stopTracking();
      }

      _currentDriverId = driverId;
      _isTracking = true;

      // Simulate location updates every 30 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 30), (
        timer,
      ) async {
        if (_isTracking && _currentDriverId != null) {
          await _simulateLocationUpdate(_currentDriverId!);
        }
      });

      print('Location tracking started for driver: $driverId');
    } catch (e) {
      print('Error starting location tracking: $e');
      throw Exception('Failed to start location tracking: $e');
    }
  }

  /// Stop tracking driver location
  Future<void> stopTracking() async {
    try {
      _isTracking = false;
      _currentDriverId = null;

      _locationTimer?.cancel();
      _locationTimer = null;

      print('Location tracking stopped');
    } catch (e) {
      print('Error stopping location tracking: $e');
    }
  }

  /// Simulate location update (placeholder for real GPS)
  Future<void> _simulateLocationUpdate(String driverId) async {
    try {
      // For now, we'll just update with a placeholder location
      // In production, this should use real GPS coordinates
      final simulatedLat = 34.0522; // Example: Los Angeles
      final simulatedLon = -118.2437;

      // Update driver_locations table
      await _client.from('driver_locations').upsert({
        'driver_id': driverId,
        'latitude': simulatedLat,
        'longitude': simulatedLon,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also update drivers table with current location
      await _client
          .from('drivers')
          .update({
            'current_latitude': simulatedLat,
            'current_longitude': simulatedLon,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);

      print('Location updated (simulated): $simulatedLat, $simulatedLon');
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  /// Update driver location with provided coordinates
  Future<void> updateLocation(
    String driverId,
    double latitude,
    double longitude,
  ) async {
    try {
      // Update driver_locations table
      await _client.from('driver_locations').upsert({
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also update drivers table with current location
      await _client
          .from('drivers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);

      print('Location updated: $latitude, $longitude');
    } catch (e) {
      print('Error updating driver location: $e');
      throw Exception('Failed to update location: $e');
    }
  }

  /// Get driver's last known location from database
  Future<Map<String, dynamic>?> getLastKnownLocation(String driverId) async {
    try {
      final response = await _client
          .from('driver_locations')
          .select()
          .eq('driver_id', driverId)
          .order('updated_at', ascending: false)
          .limit(1)
          .single()
          .catchError((_) => null);

      return response;
    } catch (e) {
      print('Error getting last known location: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in meters (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }

  /// Check if driver is within pickup/dropoff radius
  bool isWithinRadius(
    double driverLat,
    double driverLon,
    double targetLat,
    double targetLon,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      driverLat,
      driverLon,
      targetLat,
      targetLon,
    );
    return distance <= radiusMeters;
  }

  /// Get estimated time of arrival (ETA) in minutes
  Future<int?> getETA(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) async {
    try {
      final distance = calculateDistance(startLat, startLon, endLat, endLon);

      // Assume average speed of 30 km/h (8.33 m/s) in city traffic
      const averageSpeedMps = 8.33;
      final etaSeconds = distance / averageSpeedMps;
      final etaMinutes = (etaSeconds / 60).ceil();

      return etaMinutes > 0 ? etaMinutes : 1; // Minimum 1 minute
    } catch (e) {
      print('Error calculating ETA: $e');
      return null;
    }
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Get current driver ID being tracked
  String? get currentDriverId => _currentDriverId;

  /// Dispose of resources
  void dispose() {
    stopTracking();
  }
}

/// Math utilities for calculations
class Math {
  static double sin(double x) => _sin(x);
  static double cos(double x) => _cos(x);
  static double tan(double x) => _tan(x);
  static double atan2(double y, double x) => _atan2(y, x);
  static double sqrt(double x) => _sqrt(x);
  static const double pi = 3.14159265358979323846;

  static double _sin(double x) {
    // Simple sine approximation
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  static double _cos(double x) {
    // Simple cosine approximation
    return 1 - (x * x) / 2 + (x * x * x * x) / 24;
  }

  static double _tan(double x) => _sin(x) / _cos(x);

  static double _atan2(double y, double x) {
    // Simple atan2 approximation
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + pi;
    if (x < 0 && y < 0) return _atan(y / x) - pi;
    if (x == 0 && y > 0) return pi / 2;
    if (x == 0 && y < 0) return -pi / 2;
    return 0;
  }

  static double _atan(double x) {
    // Simple arctangent approximation
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }

  static double _sqrt(double x) {
    // Simple square root approximation (Newton's method)
    if (x < 0) return 0;
    if (x == 0) return 0;

    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
