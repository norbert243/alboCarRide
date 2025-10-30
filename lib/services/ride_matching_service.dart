import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/location_service.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';

/// Service for matching ride requests with nearby drivers
class RideMatchingService {
  static final RideMatchingService _instance = RideMatchingService._internal();
  factory RideMatchingService() => _instance;
  RideMatchingService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final TripService _tripService = TripService();
  StreamSubscription? _rideRequestSubscription;
  final Map<String, Timer> _expirationTimers = {};
  final StreamController<Trip> _tripController =
      StreamController<Trip>.broadcast();

  /// Getter for Supabase client (for external access)
  SupabaseClient get supabaseClient => _supabase;

  /// Start listening for new ride requests and match with nearby drivers
  Future<void> startMatchingService() async {
    try {
      // Subscribe to new ride requests
      _rideRequestSubscription = _supabase
          .from('ride_requests')
          .stream(primaryKey: ['id'])
          .listen((event) async {
            for (final request in event) {
              if (request['status'] == 'pending') {
                await _handleNewRideRequest(request);
              }
            }
          });

      print('Ride matching service started');
    } catch (e) {
      print('Error starting matching service: $e');
      rethrow;
    }
  }

  /// Stop the matching service
  Future<void> stopMatchingService() async {
    await _rideRequestSubscription?.cancel();
    _rideRequestSubscription = null;

    // Cancel all expiration timers
    _expirationTimers.forEach((requestId, timer) {
      timer.cancel();
    });
    _expirationTimers.clear();

    print('Ride matching service stopped');
  }

  /// Handle new ride request and find nearby drivers
  Future<void> _handleNewRideRequest(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;
    final riderId = request['rider_id'] as String;
    final proposedPrice = (request['proposed_price'] as num).toDouble();
    final pickupAddress = request['pickup_address'] as String;
    final dropoffAddress = request['dropoff_address'] as String;

    try {
      // Get rider's pickup location coordinates
      final pickupLocation = await LocationService.geocodeAddress(
        pickupAddress,
      );
      if (pickupLocation == null) {
        throw Exception('Could not geocode pickup address');
      }

      final pickupLat = pickupLocation['latitude'] as double;
      final pickupLng = pickupLocation['longitude'] as double;

      // Find nearby online drivers
      final nearbyDrivers = await _findNearbyDrivers(pickupLat, pickupLng);

      if (nearbyDrivers.isEmpty) {
        print('No nearby drivers found for request $requestId');
        return;
      }

      // Create offers for nearby drivers
      for (final driver in nearbyDrivers) {
        await _createRideOffer(
          requestId: requestId,
          riderId: riderId,
          driverId: driver['id'] as String,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          proposedPrice: proposedPrice,
        );
      }

      print('Created ${nearbyDrivers.length} offers for request $requestId');

      // Set expiration timer for this request
      _setExpirationTimer(requestId);
    } catch (e) {
      print('Error handling ride request $requestId: $e');
      // Mark request as failed if we can't process it
      await _markRequestAsFailed(requestId);
    }
  }

  /// Find nearby online drivers within 5km radius
  Future<List<Map<String, dynamic>>> _findNearbyDrivers(
    double pickupLat,
    double pickupLng, {
    double radiusKm = 5.0,
  }) async {
    try {
      // Get drivers with recent location updates (last 5 minutes)
      final fiveMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 5),
      );

      final response = await _supabase
          .from('drivers')
          .select('id, current_latitude, current_longitude, vehicle_type')
          .eq('is_online', true)
          .gte('updated_at', fiveMinutesAgo.toIso8601String());

      final nearbyDrivers = <Map<String, dynamic>>[];

      for (final driver in response) {
        final driverLat = driver['current_latitude'] as double?;
        final driverLng = driver['current_longitude'] as double?;

        if (driverLat != null && driverLng != null) {
          final distance = _calculateDistance(
            pickupLat,
            pickupLng,
            driverLat,
            driverLng,
          );

          if (distance <= radiusKm) {
            nearbyDrivers.add({
              'id': driver['id'],
              'distance': distance,
              'vehicle_type': driver['vehicle_type'],
            });
          }
        }
      }

      // Sort by distance (closest first)
      nearbyDrivers.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      return nearbyDrivers;
    } catch (e) {
      print('Error finding nearby drivers: $e');
      return [];
    }
  }

  /// Create a ride offer for a specific driver
  Future<void> _createRideOffer({
    required String requestId,
    required String riderId,
    required String driverId,
    required String pickupAddress,
    required String dropoffAddress,
    required double proposedPrice,
  }) async {
    try {
      await _supabase.from('ride_offers').insert({
        'id': _generateUuid(),
        'request_id': requestId,
        'driver_id': driverId,
        'offer_price': proposedPrice,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      });

      // Send push notification to driver (would be implemented with FCM)
      await _notifyDriver(driverId, proposedPrice, pickupAddress);
    } catch (e) {
      print('Error creating ride offer for driver $driverId: $e');
    }
  }

  /// Set expiration timer for a ride request
  void _setExpirationTimer(String requestId) {
    final timer = Timer(const Duration(minutes: 15), () async {
      await _expireRideRequest(requestId);
      _expirationTimers.remove(requestId);
    });

    _expirationTimers[requestId] = timer;
  }

  /// Expire a ride request if no driver accepts
  Future<void> _expireRideRequest(String requestId) async {
    try {
      await _supabase
          .from('ride_requests')
          .update({
            'status': 'expired',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'pending');

      print('Ride request $requestId expired');

      // Also expire all pending offers for this request
      await _supabase
          .from('ride_offers')
          .update({
            'status': 'expired',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId)
          .eq('status', 'pending');
    } catch (e) {
      print('Error expiring ride request $requestId: $e');
    }
  }

  /// Mark request as failed
  Future<void> _markRequestAsFailed(String requestId) async {
    try {
      await _supabase
          .from('ride_requests')
          .update({
            'status': 'failed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      print('Error marking request $requestId as failed: $e');
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  /// Generate UUID v4
  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return '${random}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Notify driver about new ride offer (placeholder for FCM integration)
  Future<void> _notifyDriver(
    String driverId,
    double price,
    String pickupAddress,
  ) async {
    // This would integrate with Firebase Cloud Messaging
    // For now, just log the notification
    print(
      'Notifying driver $driverId: New ride offer for \$$price at $pickupAddress',
    );

    // TODO: Implement FCM push notification
    // await FirebaseMessaging.instance.send(
    //   message: {
    //     'notification': {
    //       'title': 'New Ride Offer',
    //       'body': '\$$price - $pickupAddress',
    //     },
    //     'data': {
    //       'type': 'ride_offer',
    //       'driver_id': driverId,
    //     },
    //   },
    // );
  }

  /// Accept a ride offer using atomic trip creation
  Future<void> acceptOffer(String offerId) async {
    try {
      // Use the TripService to handle atomic offer acceptance
      await _tripService.acceptOffer(offerId);

      print('Offer accepted and trip created successfully');

      // Note: Trip creation is now handled by the SQL function
      // Real-time updates will come through the trip subscription
    } catch (e) {
      print('Error accepting offer: $e');
      rethrow;
    }
  }

  /// Stream for trip updates
  Stream<Trip> get tripStream => _tripController.stream;

  /// Get active trip for current driver
  Future<Map<String, dynamic>?> getActiveTrip(String driverId) async {
    return await _tripService.getActiveTrip(driverId);
  }

  /// Subscribe to driver's active trips
  Stream<List<Trip>> subscribeToDriverTrips(String driverId) {
    return _tripService.subscribeToDriverTripsModel(driverId).map((tripMaps) {
      return tripMaps.map((tripMap) => Trip.fromMap(tripMap)).toList();
    });
  }

  /// Get rider ID from ride request
  Future<String> _getRiderIdFromRequest(String requestId) async {
    final request = await _supabase
        .from('ride_requests')
        .select('rider_id')
        .eq('id', requestId)
        .single();
    return request['rider_id'] as String;
  }

  /// Clean up resources
  void dispose() {
    stopMatchingService();
    _tripController.close();
  }
}
