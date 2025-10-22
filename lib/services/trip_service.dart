import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'db_service.dart';

/// Service for managing trip lifecycle and operations
class TripService {
  final SupabaseClient _client = Supabase.instance.client;
  final supabase = DBService.instance.supabase;

  /// Start a trip: set status to 'in_progress'
  Future<void> startTrip(String tripId) async {
    try {
      await _client
          .from('trips')
          .update({
            'status': 'in_progress',
            'start_time': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);

      // Also update the corresponding ride status for consistency
      await _client
          .from('rides')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to start trip: $e');
    }
  }

  /// Complete a trip: set status to 'completed'
  Future<void> completeTrip(String tripId) async {
    try {
      await _client
          .from('trips')
          .update({
            'status': 'completed',
            'end_time': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);

      // Also update the corresponding ride status
      await _client
          .from('rides')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to complete trip: $e');
    }
  }

  /// Cancel a trip with reason
  Future<void> cancelTrip(String tripId, String reason) async {
    try {
      await _client
          .from('trips')
          .update({
            'status': 'cancelled',
            'end_time': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);

      // Also update the corresponding ride status
      await _client
          .from('rides')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to cancel trip: $e');
    }
  }

  /// Get active trip for a driver
  Future<Map<String, dynamic>?> getActiveTrip(String driverId) async {
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
  }) async {
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
  Stream<List<Map<String, dynamic>>> subscribeToDriverTripsModel(String driverId) {
    return subscribeToDriverTrips(driverId);
  }
  /// Fetch driver dashboard data using RPC
  Future<Map<String, dynamic>?> fetchDriverDashboard(String driverId) async {
    try {
      final res = await supabase.rpc('get_driver_dashboard', params: {'p_driver_id': driverId}).maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
      return (res as Map).cast<String, dynamic>();
    } catch (e, st) {
      log('[TripService] Dashboard fetch error: $e\n$st');
      // log into telemetry table via RPC if you want
      await supabase.from('telemetry_logs').insert({
        'type': 'dashboard_error',
        'message': e.toString(),
        'meta': {'driver_id': driverId}
      });
      return null;
    }
  }

  /// Accept offer using atomic RPC
  Future<String?> acceptOfferAtomic(String offerId, String driverId) async {
    final res = await supabase.rpc('accept_offer_atomic', params: {'p_offer_id': offerId, 'p_driver_id': driverId}).maybeSingle();
    if (res == null) return null;
    if (res.containsKey('trip_id')) return res['trip_id'].toString();
    return res.toString();
  }
}
