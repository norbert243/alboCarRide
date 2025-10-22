// lib/services/history_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'telemetry_service.dart';

class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  final _supabase = Supabase.instance.client;

  /// Fetch paginated trips for driver
  Future<List<Map<String, dynamic>>> fetchDriverTrips({
    required String driverId,
    int limit = 20,
    int offset = 0,
    String? status,
  }) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot fetch trips for another user');
    }

    try {
      var query = _supabase
          .from('trips')
          .select(
            'id, start_time, end_time, final_price, status, request_id, offer_id',
          )
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final res = await query;
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      await TelemetryService.instance.log(
        'fetch_driver_trips_error',
        e.toString(),
      );
      return [];
    }
  }

  /// Fetch paginated earnings for driver
  Future<List<Map<String, dynamic>>> fetchDriverEarnings({
    required String driverId,
    int limit = 20,
    int offset = 0,
  }) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot fetch earnings for another user');
    }

    try {
      final res = await _supabase
          .from('driver_earnings')
          .select('*')
          .eq('driver_id', driverId)
          .order('earned_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      await TelemetryService.instance.log(
        'fetch_driver_earnings_error',
        e.toString(),
      );
      return [];
    }
  }

  /// Get earnings summary for driver (total, this week, this month)
  Future<Map<String, dynamic>> getEarningsSummary(String driverId) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot fetch earnings summary for another user');
    }

    try {
      final response = await _supabase.rpc(
        'get_driver_earnings_summary',
        params: {'driver_id': driverId},
      );

      if (response.error != null) throw response.error!;

      return Map<String, dynamic>.from(response.data ?? {});
    } catch (e) {
      await TelemetryService.instance.log(
        'earnings_summary_error',
        e.toString(),
      );
      return {
        'total_earnings': 0.0,
        'weekly_earnings': 0.0,
        'monthly_earnings': 0.0,
      };
    }
  }

  /// Get trip statistics for driver
  Future<Map<String, dynamic>> getTripStats(String driverId) async {
    // Security validation: ensure driverId matches authenticated user
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId != driverId) {
      throw Exception('Cannot fetch trip stats for another user');
    }

    try {
      final response = await _supabase.rpc(
        'get_driver_trip_stats',
        params: {'driver_id': driverId},
      );

      if (response.error != null) throw response.error!;

      return Map<String, dynamic>.from(response.data ?? {});
    } catch (e) {
      await TelemetryService.instance.log('trip_stats_error', e.toString());
      return {
        'total_trips': 0,
        'completed_trips': 0,
        'cancelled_trips': 0,
        'average_rating': 0.0,
      };
    }
  }
}
