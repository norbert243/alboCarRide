import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

/// Service for ETA calculation and rider notification management
class EtaService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Calculate ETA for a trip using Supabase RPC
  Future<Map<String, dynamic>?> calculateEta(String tripId) async {
    try {
      final response = await _client.rpc(
        'calculate_eta',
        params: {'p_trip_id': tripId},
      );

      if (response.error != null) {
        log('❌ EtaService: RPC error - ${response.error!.message}');
        return null;
      }

      // Handle different response formats from Supabase
      Map<String, dynamic>? etaData;
      if (response.data is Map<String, dynamic>) {
        etaData = response.data as Map<String, dynamic>;
      } else if (response.data is List && (response.data as List).isNotEmpty) {
        etaData = (response.data as List).first as Map<String, dynamic>;
      }

      if (etaData?['status'] == 'ok') {
        log('✅ EtaService: ETA calculated successfully - ${etaData?['eta_minutes']} min');
        return etaData;
      } else {
        log('❌ EtaService: ETA calculation failed - ${etaData?['error']}');
        return etaData;
      }
    } catch (e) {
      log('❌ EtaService: Exception calculating ETA - $e');
      return null;
    }
  }

  /// Send ETA notification to rider
  Future<bool> notifyRiderEta(String tripId, int etaMinutes) async {
    try {
      final response = await _client.rpc(
        'notify_rider_eta',
        params: {
          'p_trip_id': tripId,
          'p_eta_minutes': etaMinutes,
        },
      );

      if (response.error != null) {
        log('❌ EtaService: Notification RPC error - ${response.error!.message}');
        return false;
      }

      final result = response.data as Map<String, dynamic>?;
      final success = result?['notification_sent'] == true;

      if (success) {
        log('✅ EtaService: Rider notified successfully - $etaMinutes min');
      } else {
        log('❌ EtaService: Failed to notify rider');
      }

      return success;
    } catch (e) {
      log('❌ EtaService: Exception notifying rider - $e');
      return false;
    }
  }

  /// Subscribe to driver location updates for real-time ETA
  Stream<Map<String, dynamic>> subscribeToDriverLocation(String driverId) {
    return _client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((events) => events.isNotEmpty ? events.first : {});
  }

  /// Subscribe to trip status updates
  Stream<Map<String, dynamic>> subscribeToTrip(String tripId) {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((events) => events.isNotEmpty ? events.first : {});
  }

  /// Auto-refresh ETA every 15 seconds with rider notification
  Stream<Map<String, dynamic>?> autoRefreshEta(
    String tripId, {
    Duration interval = const Duration(seconds: 15),
    bool notifyRider = true,
  }) {
    return Stream.periodic(interval, (_) async {
      final etaData = await calculateEta(tripId);
      
      // Notify rider if ETA is available and notification is enabled
      if (notifyRider && etaData?['status'] == 'ok') {
        final etaMinutes = etaData?['eta_minutes'] as int?;
        if (etaMinutes != null) {
          await notifyRiderEta(tripId, etaMinutes);
        }
      }
      
      return etaData;
    }).asyncMap((future) => future);
  }

  /// Get driver's current location
  Future<Map<String, dynamic>?> getDriverLocation(String driverId) async {
    try {
      final response = await _client
          .from('drivers')
          .select('current_latitude, current_longitude, updated_at')
          .eq('id', driverId)
          .single();

      return response;
    } catch (e) {
      log('❌ EtaService: Failed to get driver location - $e');
      return null;
    }
  }

  /// Get trip details for ETA calculation
  Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final response = await _client
          .from('rides')
          .select('''
            id,
            driver_id,
            status,
            pickup_latitude,
            pickup_longitude,
            dropoff_latitude,
            dropoff_longitude,
            customer_id
          ''')
          .eq('id', tripId)
          .single();

      return response;
    } catch (e) {
      log('❌ EtaService: Failed to get trip details - $e');
      return null;
    }
  }

  /// Validate if ETA calculation is possible for a trip
  Future<bool> canCalculateEta(String tripId) async {
    try {
      final tripDetails = await getTripDetails(tripId);
      if (tripDetails == null) return false;

      final driverId = tripDetails['driver_id'] as String?;
      if (driverId == null) return false;

      final driverLocation = await getDriverLocation(driverId);
      if (driverLocation == null) return false;

      final hasPickupCoords = 
          tripDetails['pickup_latitude'] != null && 
          tripDetails['pickup_longitude'] != null;
      final hasDropoffCoords = 
          tripDetails['dropoff_latitude'] != null && 
          tripDetails['dropoff_longitude'] != null;
      final hasDriverCoords = 
          driverLocation['current_latitude'] != null && 
          driverLocation['current_longitude'] != null;

      return hasPickupCoords && hasDropoffCoords && hasDriverCoords;
    } catch (e) {
      log('❌ EtaService: ETA validation failed - $e');
      return false;
    }
  }
}