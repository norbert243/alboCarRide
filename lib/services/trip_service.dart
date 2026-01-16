import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'db_service.dart';
import 'notification_service.dart';

/// Service for managing trip lifecycle and operations
class TripService {
  final SupabaseClient _client = Supabase.instance.client;
  final supabase = DBService.instance.supabase;

  /// Start a trip: set status to 'in_progress'
  Future<void> startTrip(String tripId) async {
    try {
      await updateTripStatus(tripId, 'in_progress');
    } catch (e) {
      throw Exception('Failed to start trip: $e');
    }
  }

  /// Complete a trip: set status to 'completed'
  Future<void> completeTrip(String tripId) async {
    try {
      await updateTripStatus(tripId, 'completed');
    } catch (e) {
      throw Exception('Failed to complete trip: $e');
    }
  }

  /// Cancel a trip with reason
  Future<void> cancelTrip(String tripId, String reason) async {
    try {
      await updateTripStatus(tripId, 'cancelled', reason: reason);
    } catch (e) {
      throw Exception('Failed to cancel trip: $e');
    }
  }

  /// Get active trip for a driver
  Future<Map<String, dynamic>?> getActiveTrip(String driverId) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot access active trip for another user');
    }

    try {
      final response = await _client
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

  /// Subscribe to a specific trip's updates
  Stream<Map<String, dynamic>> subscribeToTrip(String tripId) {
    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((events) => events.isNotEmpty ? events.first : {});
  }

  /// Subscribe to driver's active trips
  Stream<List<Map<String, dynamic>>> subscribeToDriverTrips(String driverId) {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot subscribe to trips for another user');
    }

    return _client
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
    int offset = 0,
  }) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot access trip history for another user');
    }

    try {
      final response = await _client
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
          .limit(limit)
          .range(offset, offset + limit - 1);

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
      final response = await _client
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

  /// Accept a ride offer and create a trip
  Future<void> acceptOffer(String offerId) async {
    try {
      // Call RPC function to accept offer and create trip
      final response = await _client.rpc(
        'accept_ride_offer',
        params: {'p_offer_id': offerId},
      );

      if (response.error != null) {
        throw Exception('Failed to accept offer: ${response.error!.message}');
      }
    } catch (e) {
      throw Exception('Failed to accept offer: $e');
    }
  }

  /// Subscribe to driver's trips model (alias for subscribeToDriverTrips)
  Stream<List<Map<String, dynamic>>> subscribeToDriverTripsModel(
    String driverId,
  ) {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot subscribe to trips model for another user');
    }

    return subscribeToDriverTrips(driverId);
  }

  /// Fetch driver dashboard data using RPC
  Future<Map<String, dynamic>?> fetchDriverDashboard(String driverId) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot access dashboard for another user');
    }

    try {
      final res = await supabase
          .rpc('get_driver_dashboard', params: {'p_driver_id': driverId})
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } catch (e, st) {
      log('[TripService] Dashboard fetch error: $e\n$st');
      // log into telemetry table via RPC if you want
      await supabase.from('telemetry_logs').insert({
        'type': 'dashboard_error',
        'message': e.toString(),
        'meta': {'driver_id': driverId},
      });
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTripById(String tripId) async {
    try {
      final response = await _client
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
          .eq('id', tripId)
          .single();

      // Extract rider name from profiles join
      final riderProfile = response['profiles'] as Map<String, dynamic>?;
      final riderName = riderProfile?['full_name'] ?? 'Rider';

      // Extract request details
      final request = response['ride_requests'] as Map<String, dynamic>?;

      return {
        ...response,
        'rider_name': riderName,
        'pickup_address': request?['pickup_address'] ?? '',
        'dropoff_address': request?['dropoff_address'] ?? '',
        'proposed_price': request?['proposed_price'] ?? 0.0,
        'notes': request?['notes'] ?? '',
      };
    } catch (e) {
      throw Exception('Failed to get trip by ID: $e');
    }
  }
  
  /// Update trip status and notify customer
  Future<void> updateTripStatus(String tripId, String status, {String? reason}) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'in_progress') {
        updates['start_time'] = DateTime.now().toIso8601String();
      } else if (status == 'completed' || status == 'cancelled') {
        updates['end_time'] = DateTime.now().toIso8601String();
        if (reason != null) {
          updates['cancellation_reason'] = reason;
        }
      }
      
      final trip = await _client.from('trips').update(updates).eq('id', tripId).select().single();
      
      // Also update the corresponding ride status
      final rideUpdates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'in_progress') {
        rideUpdates['started_at'] = DateTime.now().toIso8601String();
      } else if (status == 'completed') {
        rideUpdates['completed_at'] = DateTime.now().toIso8601String();
      } else if (status == 'cancelled') {
        rideUpdates['cancelled_at'] = DateTime.now().toIso8601String();
        if (reason != null) {
          rideUpdates['cancellation_reason'] = reason;
        }
      }

      await _client.from('rides').update(rideUpdates).eq('id', tripId);

      // Notify customer
      final customerId = trip['rider_id'];
      final driverId = trip['driver_id'];
      
      final driver = await _client.from('profiles').select('full_name').eq('id', driverId).single();
      final driverName = driver['full_name'];

      await NotificationService.notifyCustomerAboutRideStatus(
        customerId: customerId,
        rideId: tripId,
        status: status,
        driverName: driverName,
        fare: trip['final_price']
      );

    } catch (e) {
      throw Exception('Failed to update trip status: $e');
    }
  }

  /// Accept offer using atomic RPC
  Future<String?> acceptOfferAtomic(String offerId, String driverId) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot accept offers for another user');
    }

    final res = await supabase
        .rpc(
          'accept_offer_atomic',
          params: {'p_offer_id': offerId, 'p_driver_id': driverId},
        )
        .maybeSingle();
        
    if (res != null && res.containsKey('trip_id')) {
      final tripId = res['trip_id'].toString();
      final trip = await getTripById(tripId);
      
      if (trip != null) {
        await NotificationService.notifyCustomerAboutRideStatus(
          customerId: trip['rider_id'],
          rideId: tripId,
          status: 'accepted',
          driverName: trip['driver_name'],
          estimatedArrival: '5 minutes', // Placeholder
        );
      }
      return tripId;
    }
    
    return null;
  }
}
