import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import '../models/earning.dart';
import 'telemetry_service.dart';

class TripHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TelemetryService _telemetry = TelemetryService.instance;

  // page starts at 0
  Future<List<Trip>> fetchTripsPage({
    required String driverId,
    required int page,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    try {
      final resp = await _supabase
          .from('trips_paged') // view created in Migration v7
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .range(from, to);

      if (resp.isEmpty) return [];
      final rows = resp;
      return rows.map((r) => Trip.fromMap(r)).toList();
    } catch (e) {
      await _telemetry.log(
        'fetch_trips_page_error',
        'driver=$driverId page=$page err=$e',
      );
      rethrow;
    }
  }

  Future<List<Earning>> fetchEarningsPage({
    required String driverId,
    required int page,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    try {
      final resp = await _supabase
          .from('driver_earnings_paged') // view created in Migration v7
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .range(from, to);
      if (resp.isEmpty) return [];
      final rows = resp;
      return rows.map((r) => Earning.fromMap(r)).toList();
    } catch (e) {
      await _telemetry.log(
        'fetch_earnings_page_error',
        'driver=$driverId page=$page err=$e',
      );
      rethrow;
    }
  }
}
