import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/location_service.dart';

/// Represents a ride request from a customer
class RideRequest {
  final String id;
  final String riderId;
  final String pickupAddress;
  final String dropoffAddress;
  final double proposedPrice;
  final String status; // 'pending', 'accepted', 'expired', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  RideRequest({
    required this.id,
    required this.riderId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.proposedPrice,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      id: map['id'] as String,
      riderId: map['rider_id'] as String,
      pickupAddress: map['pickup_address'] as String,
      dropoffAddress: map['dropoff_address'] as String,
      proposedPrice: (map['proposed_price'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      notes: map['notes'] as String?,
      pickupLat: map['pickup_lat'] as double?,
      pickupLng: map['pickup_lng'] as double?,
      dropoffLat: map['dropoff_lat'] as double?,
      dropoffLng: map['dropoff_lng'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rider_id': riderId,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'proposed_price': proposedPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'notes': notes,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
    };
  }
}

/// Service for managing ride requests
class RideRequestService {
  final SupabaseClient _supabase;

  RideRequestService(this._supabase);

  /// Create a new ride request
  Future<RideRequest> createRequest({
    required String riderId,
    required String pickupAddress,
    required String dropoffAddress,
    required double proposedPrice,
    String? notes,
  }) async {
    try {
      // Geocode addresses to get coordinates
      final pickupCoords = await LocationService.geocodeAddress(pickupAddress);
      final dropoffCoords = await LocationService.geocodeAddress(
        dropoffAddress,
      );

      if (pickupCoords == null) {
        throw Exception('Could not geocode pickup address');
      }

      final requestId = _generateUuid();
      final now = DateTime.now();

      final response = await _supabase
          .from('ride_requests')
          .insert({
            'id': requestId,
            'rider_id': riderId,
            'pickup_address': pickupAddress,
            'dropoff_address': dropoffAddress,
            'proposed_price': proposedPrice,
            'status': 'pending',
            'created_at': now.toIso8601String(),
            'notes': notes,
            'pickup_lat': pickupCoords['latitude'],
            'pickup_lng': pickupCoords['longitude'],
            'dropoff_lat': dropoffCoords?['latitude'],
            'dropoff_lng': dropoffCoords?['longitude'],
          })
          .select()
          .single();

      return RideRequest.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create ride request: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating ride request: $e');
    }
  }

  /// Cancel a ride request
  Future<RideRequest> cancelRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('ride_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'pending') // Only cancel pending requests
          .select()
          .single();

      return RideRequest.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to cancel ride request: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error cancelling ride request: $e');
    }
  }

  /// Get a specific ride request by ID
  Future<RideRequest> getRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('ride_requests')
          .select()
          .eq('id', requestId)
          .single();

      return RideRequest.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch ride request: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching ride request: $e');
    }
  }

  /// Get all ride requests for a specific rider
  Future<List<RideRequest>> getRiderRequests(String riderId) async {
    try {
      final response = await _supabase
          .from('ride_requests')
          .select()
          .eq('rider_id', riderId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((request) => RideRequest.fromMap(request))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch rider requests: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching rider requests: $e');
    }
  }

  /// Get active (pending) ride requests for a rider
  Future<List<RideRequest>> getActiveRequests(String riderId) async {
    try {
      final response = await _supabase
          .from('ride_requests')
          .select()
          .eq('rider_id', riderId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((request) => RideRequest.fromMap(request))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch active requests: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching active requests: $e');
    }
  }

  /// Subscribe to real-time updates for a rider's requests
  Stream<List<RideRequest>> watchRiderRequests(String riderId) {
    final controller = StreamController<List<RideRequest>>();

    // Get initial data
    getRiderRequests(riderId)
        .then((requests) {
          controller.add(requests);
        })
        .catchError((error) {
          controller.addError(error);
        });

    // Set up real-time subscription
    final subscription = _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .listen((event) {
          try {
            // Filter for this rider's requests
            final requests =
                (event as List)
                    .where((request) => request['rider_id'] == riderId)
                    .map((request) => RideRequest.fromMap(request))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(requests);
          } catch (e) {
            controller.addError(e);
          }
        });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Subscribe to real-time updates for active requests
  Stream<List<RideRequest>> watchActiveRequests(String riderId) {
    final controller = StreamController<List<RideRequest>>();

    // Get initial data
    getActiveRequests(riderId)
        .then((requests) {
          controller.add(requests);
        })
        .catchError((error) {
          controller.addError(error);
        });

    // Set up real-time subscription
    final subscription = _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .listen((event) {
          try {
            // Filter for this rider's active requests
            final requests =
                (event as List)
                    .where(
                      (request) =>
                          request['rider_id'] == riderId &&
                          request['status'] == 'pending',
                    )
                    .map((request) => RideRequest.fromMap(request))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(requests);
          } catch (e) {
            controller.addError(e);
          }
        });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Get request statistics for a rider
  Future<Map<String, int>> getRequestStats(String riderId) async {
    try {
      final response = await _supabase
          .from('ride_requests')
          .select('status')
          .eq('rider_id', riderId);

      final stats = {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'expired': 0,
        'cancelled': 0,
      };

      for (final request in response) {
        stats['total'] = (stats['total'] ?? 0) + 1;
        final status = request['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch request statistics: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching request statistics: $e');
    }
  }

  /// Estimate ride price based on distance
  Future<double> estimatePrice({
    required String pickupAddress,
    required String dropoffAddress,
  }) async {
    try {
      // Get coordinates for both addresses
      final pickupCoords = await LocationService.geocodeAddress(pickupAddress);
      final dropoffCoords = await LocationService.geocodeAddress(
        dropoffAddress,
      );

      if (pickupCoords == null || dropoffCoords == null) {
        throw Exception('Could not geocode addresses');
      }

      // Calculate distance
      final distance = _calculateDistance(
        pickupCoords['latitude'] as double,
        pickupCoords['longitude'] as double,
        dropoffCoords['latitude'] as double,
        dropoffCoords['longitude'] as double,
      );

      // Simple pricing model: base fare + distance rate
      const baseFare = 2.50;
      const perKmRate = 1.20;
      final estimatedPrice = baseFare + (distance * perKmRate);

      // Round to nearest 0.50
      return (estimatedPrice * 2).roundToDouble() / 2;
    } catch (e) {
      throw Exception('Failed to estimate price: $e');
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
    return degrees * (pi / 180.0);
  }

  /// Generate UUID
  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return '${random}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
