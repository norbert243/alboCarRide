import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Service for real-time location sharing
class LiveLocationService {
  final SupabaseClient _supabase;
  StreamSubscription<Position>? _locationSubscription;
  Position? _currentPosition;

  LiveLocationService(this._supabase);

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start live location tracking and updates to database
  Future<void> startLiveLocationTracking({
    required String userId,
    required String userRole, // 'customer' or 'driver'
    required Function(Position) onLocationUpdate,
  }) async {
    try {
      // Get initial location
      final initialPosition = await getCurrentLocation();
      if (initialPosition != null) {
        await _updateUserLocation(userId, userRole, initialPosition);
        onLocationUpdate(initialPosition);
      }

      // Start continuous tracking
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          _currentPosition = position;
          await _updateUserLocation(userId, userRole, position);
          onLocationUpdate(position);
        },
        onError: (error) {
          print('Location tracking error: $error');
        },
      );
    } catch (e) {
      print('Error starting live location tracking: $e');
      rethrow;
    }
  }

  /// Stop live location tracking
  void stopLiveLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Update user location in database
  Future<void> _updateUserLocation(
    String userId,
    String userRole,
    Position position,
  ) async {
    try {
      await _supabase.from('profiles').update({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('Error updating user location in database: $e');
    }
  }

  /// Generate shareable location link (Google Maps)
  String generateLocationLink(Position position) {
    return 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
  }

  /// Generate shareable location link with custom message
  String generateLocationLinkWithMessage({
    required Position position,
    String? customMessage,
  }) {
    final link = generateLocationLink(position);
    if (customMessage != null) {
      return '$customMessage\n\n📍 My Location: $link';
    }
    return '📍 My Location: $link';
  }

  /// Share location via system share dialog
  Future<void> shareLocation({
    required Position position,
    String? customMessage,
  }) async {
    try {
      final message = generateLocationLinkWithMessage(
        position: position,
        customMessage: customMessage ?? 'Here is my current location:',
      );

      await Share.share(message);
    } catch (e) {
      print('Error sharing location: $e');
      rethrow;
    }
  }

  /// Share live location for a specific duration
  /// Returns a stream of location updates that can be shared
  Stream<String> shareLiveLocationStream({
    required Duration duration,
    String? customMessage,
  }) async* {
    final startTime = DateTime.now();
    const updateInterval = Duration(seconds: 30); // Update every 30 seconds

    while (DateTime.now().difference(startTime) < duration) {
      final position = await getCurrentLocation();
      if (position != null) {
        final message = generateLocationLinkWithMessage(
          position: position,
          customMessage: customMessage,
        );
        yield message;
      }

      await Future.delayed(updateInterval);
    }
  }

  /// Watch another user's location (for trip tracking)
  Stream<Position?> watchUserLocation(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((records) {
          if (records.isEmpty) return null;

          final record = records.first;
          final lat = record['current_latitude'];
          final lng = record['current_longitude'];

          if (lat == null || lng == null) return null;

          return Position(
            latitude: (lat as num).toDouble(),
            longitude: (lng as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        });
  }

  /// Get driver's current location for a trip
  Future<Position?> getDriverLocation(String driverId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('current_latitude, current_longitude, last_location_update')
          .eq('id', driverId)
          .single();

      final lat = response['current_latitude'];
      final lng = response['current_longitude'];

      if (lat == null || lng == null) return null;

      return Position(
        latitude: (lat as num).toDouble(),
        longitude: (lng as num).toDouble(),
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (e) {
      print('Error getting driver location: $e');
      return null;
    }
  }

  /// Calculate distance between two positions (in kilometers)
  double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
          pos1.latitude,
          pos1.longitude,
          pos2.latitude,
          pos2.longitude,
        ) /
        1000; // Convert to kilometers
  }

  /// Calculate ETA (estimated time of arrival) based on distance and average speed
  Duration calculateETA({
    required Position from,
    required Position to,
    double averageSpeedKmh = 40, // Default: 40 km/h in city traffic
  }) {
    final distanceKm = calculateDistance(from, to);
    final hours = distanceKm / averageSpeedKmh;
    return Duration(milliseconds: (hours * 60 * 60 * 1000).round());
  }

  /// Get current position (cached)
  Position? get currentPosition => _currentPosition;

  /// Check if location tracking is active
  bool get isTrackingActive => _locationSubscription != null;

  /// Dispose resources
  void dispose() {
    stopLiveLocationTracking();
  }
}
