import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';

/// Service for managing trip lifecycle and operations
class TripService {
  final SupabaseClient supabase;

  TripService({SupabaseClient? client})
    : supabase = client ?? Supabase.instance.client;

  /// Accept an offer atomically -> creates trip
  Future<void> acceptOffer(String offerId) async {
    final response = await supabase.rpc(
      'accept_offer_atomic',
      params: {'offer_id': offerId},
    );
    if (response.error != null) {
      throw Exception('Offer acceptance failed: ${response.error!.message}');
    }
  }

  /// Update trip status via RPC
  Future<void> updateTripStatus(String tripId, String newStatus) async {
    final response = await supabase.rpc(
      'update_trip_status',
      params: {'trip_id': tripId, 'new_status': newStatus},
    );
    if (response.error != null) {
      throw Exception('Trip status update failed: ${response.error!.message}');
    }
  }

  /// Status wrappers
  Future<Trip> onMyWay(String tripId) async {
    await updateTripStatus(tripId, 'accepted');
    return await getTripWithDetails(tripId);
  }

  Future<void> arrived(String tripId) =>
      updateTripStatus(tripId, 'driver_arrived');
  Future<void> startTrip(String tripId) =>
      updateTripStatus(tripId, 'in_progress');

  /// Complete trip and finalize payment via RPC
  Future<Map<String, dynamic>> completeTrip(String tripId) async {
    try {
      // 1) Update trip status to 'completed' via safe update
      final resp = await supabase
          .from('trips')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', tripId);

      if (resp.error != null) {
        throw Exception(
          'Failed to mark trip completed: ${resp.error!.message}',
        );
      }

      // 2) Call RPC finalize_trip_payment to atomically create payment & earnings & update wallet
      final rpcResp = await supabase.rpc(
        'finalize_trip_payment',
        params: {'p_trip_id': tripId},
      );

      if (rpcResp.error != null) {
        // consider rolling back or notify admin; for now surface error
        throw Exception(
          'Payment finalization failed: ${rpcResp.error!.message}',
        );
      }

      // rpcResp.data will be JSONB; convert to Map
      final Map<String, dynamic> result = Map<String, dynamic>.from(
        rpcResp.data as Map,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelTrip(String tripId) =>
      updateTripStatus(tripId, 'cancelled');

  /// Subscribe to trip updates
  Stream<Trip> subscribeToTrip(String tripId) {
    return supabase
        .from('trips:id=eq.$tripId')
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows.isNotEmpty ? Trip.fromMap(rows.first) : Trip.empty(),
        );
  }

  /// Get active trip for a driver
  Future<Map<String, dynamic>?> getActiveTrip(String driverId) async {
    try {
      final response = await supabase
          .from('trips')
          .select('''
            *,
            ride_requests!inner(
              rider_id,
              pickup_address,
              dropoff_address,
              proposed_price,
              notes
            ),
            profiles!trips_rider_id_fkey(full_name)
          ''')
          .eq('driver_id', driverId)
          .or('status.eq.scheduled,status.eq.in_progress')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final trip = response.first;
        // Extract rider name from profiles join
        final riderProfile = trip['profiles'] as Map<String, dynamic>?;
        final riderName = riderProfile?['full_name'] ?? 'Rider';

        // Extract request details
        final request = trip['ride_requests'] as Map<String, dynamic>?;

        return {
          ...trip,
          'rider_name': riderName,
          'pickup_address': request?['pickup_address'] ?? '',
          'dropoff_address': request?['dropoff_address'] ?? '',
          'proposed_price': request?['proposed_price'] ?? 0.0,
          'notes': request?['notes'] ?? '',
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get active trip: $e');
    }
  }

  /// Subscribe to driver's active trips
  Stream<List<Map<String, dynamic>>> subscribeToDriverTrips(String driverId) {
    return supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((events) {
          // Filter for active trips manually
          return events
              .where(
                (trip) =>
                    trip['status'] == 'scheduled' ||
                    trip['status'] == 'in_progress',
              )
              .toList();
        });
  }

  /// Get trip history for a driver
  Future<List<Map<String, dynamic>>> getTripHistory(
    String driverId, {
    int limit = 20,
  }) async {
    try {
      final response = await supabase
          .from('trips')
          .select('''
            *,
            ride_requests!inner(
              pickup_address,
              dropoff_address,
              proposed_price
            ),
            profiles!trips_rider_id_fkey(full_name)
          ''')
          .eq('driver_id', driverId)
          .or('status.eq.completed,status.eq.cancelled')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((trip) {
        final riderProfile = trip['profiles'] as Map<String, dynamic>?;
        final request = trip['ride_requests'] as Map<String, dynamic>?;

        return {
          ...trip,
          'rider_name': riderProfile?['full_name'] ?? 'Rider',
          'pickup_address': request?['pickup_address'] ?? '',
          'dropoff_address': request?['dropoff_address'] ?? '',
          'proposed_price': request?['proposed_price'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get trip history: $e');
    }
  }

  /// Calculate trip earnings for a driver
  Future<double> calculateTripEarnings(String tripId) async {
    try {
      final response = await supabase
          .from('trips')
          .select('final_price')
          .eq('id', tripId)
          .single();

      final finalPrice = response['final_price'] as num?;
      return finalPrice?.toDouble() ?? 0.0;
    } catch (e) {
      throw Exception('Failed to calculate trip earnings: $e');
    }
  }

  /// Subscribe to rider's trips for real-time updates
  Stream<List<Trip>> subscribeToRiderTrips(String riderId) {
    return supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('rider_id', riderId)
        .map((events) {
          return events.map((tripData) => Trip.fromMap(tripData)).toList();
        });
  }

  /// Subscribe to driver's trips for real-time updates
  Stream<List<Trip>> subscribeToDriverTripsModel(String driverId) {
    return supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((events) {
          return events.map((tripData) => Trip.fromMap(tripData)).toList();
        });
  }

  /// Get trip with full details including rider and driver info
  Future<Trip> getTripWithDetails(String tripId) async {
    try {
      final response = await supabase
          .from('trips')
          .select('''
            *,
            ride_requests!inner(
              pickup_address,
              dropoff_address,
              proposed_price,
              notes
            ),
            profiles!trips_rider_id_fkey(
              full_name,
              phone,
              avatar_url
            ),
            drivers!trips_driver_id_fkey(
              vehicle_make,
              vehicle_model,
              vehicle_color,
              license_plate
            )
          ''')
          .eq('id', tripId)
          .single();

      return Trip.fromMap(response);
    } catch (e) {
      throw Exception('Failed to get trip details: $e');
    }
  }

  /// Format ride date for display
  String _formatRideDate(String? dateString) {
    if (dateString == null) return 'Unknown date';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Get ride history for a customer or driver from the rides table
  Future<List<Map<String, dynamic>>> getRideHistory(
    String userId, {
    String? userRole,
    int limit = 20,
  }) async {
    try {
      // Determine if we're fetching for customer or driver
      final isCustomer = userRole == 'customer' || userRole == null;
      final columnName = isCustomer ? 'customer_id' : 'driver_id';

      final response = await supabase
          .from('rides')
          .select('''
            *,
            customer:customers!inner(
              id
            ),
            driver:drivers!inner(
              id,
              vehicle_make,
              vehicle_model,
              vehicle_color,
              license_plate
            ),
            profiles!inner(
              full_name,
              avatar_url
            )
          ''')
          .eq(columnName, userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((ride) {
        final customer = ride['customer'] as Map<String, dynamic>?;
        final driver = ride['driver'] as Map<String, dynamic>?;
        final profile = ride['profiles'] as Map<String, dynamic>?;

        String otherPartyName = 'Unknown';
        if (isCustomer) {
          // For customers, show driver info
          otherPartyName = profile?['full_name'] ?? 'Driver';
        } else {
          // For drivers, show customer info
          otherPartyName = profile?['full_name'] ?? 'Customer';
        }

        return {
          'id': ride['id'],
          'pickup_location': ride['pickup_address'],
          'dropoff_location': ride['dropoff_address'],
          'other_party_name': otherPartyName,
          'fare': ride['total_price'] ?? 0.0,
          'status': ride['status'] ?? 'completed',
          'date': _formatRideDate(ride['created_at']),
          'rating': isCustomer
              ? (ride['driver_rating']?.toDouble() ?? 0.0)
              : (ride['customer_rating']?.toDouble() ?? 0.0),
          'vehicle_info': driver != null
              ? '${driver['vehicle_make']} ${driver['vehicle_model']} (${driver['vehicle_color']})'
              : 'Unknown vehicle',
          'actual_distance': ride['actual_distance'],
          'actual_duration': ride['actual_duration'],
          'base_fare': ride['base_fare'],
          'distance_fare': ride['distance_fare'],
          'time_fare': ride['time_fare'],
          'surge_multiplier': ride['surge_multiplier'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get ride history: $e');
    }
  }

  /// Completes the trip with cash payment using the atomic RPC.
  Future<Map<String, dynamic>> completeTripWithCash(String tripId) async {
    try {
      final response = await supabase.rpc(
        'complete_trip_with_cash',
        params: {'p_trip_id': tripId},
      );
      if (response.error != null) {
        throw Exception('RPC error: ${response.error!.message}');
      }
      // response.data is a list of rows from the function — we expect one
      final row = (response.data is List && response.data.isNotEmpty)
          ? response.data[0]
          : response.data;
      return Map<String, dynamic>.from(row);
    } catch (e) {
      // log to telemetry via your telemetry function
      try {
        await supabase.from('telemetry_logs').insert({
          'type': 'complete_trip_error',
          'message': e.toString(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (logError) {
        // If logging fails, just print
        print('Failed to log telemetry: $logError');
      }
      rethrow;
    }
  }
}
