import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/models/driver_model.dart';
import 'package:albocarride/services/telemetry_service.dart';

class DriverService {
  final _supabase = Supabase.instance.client;
  final _telemetry = TelemetryService.instance;

  static final DriverService instance = DriverService._internal();
  DriverService._internal();

  /// Fetch driver profile by ID
  Future<DriverModel?> fetchDriverProfile(String driverId) async {
    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('id', driverId)
          .single()
          .catchError((_) => null);

      return DriverModel.fromJson(response);
      return null;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_fetch_failed',
        message: 'Failed to fetch driver profile: $e',
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId},
      );
      return null;
    }
  }

  /// Update driver approval status via RPC
  Future<bool> updateApprovalStatus(String driverId, bool isApproved) async {
    try {
      await _supabase.rpc(
        'set_driver_approval',
        params: {'p_driver_id': driverId, 'p_is_approved': isApproved},
      );

      await _telemetry.log('driver_approval_change', 'Approval updated');
      return true;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_approval_update_failed',
        message: 'Failed to update approval status: $e',
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId, 'is_approved': isApproved},
      );
      return false;
    }
  }

  /// Update driver online status
  Future<bool> updateOnlineStatus(String driverId, bool isOnline) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'is_online': isOnline,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);

      await _telemetry.log(
        'driver_online_status_change',
        'Online status updated',
      );
      return true;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_online_update_failed',
        message: 'Failed to update online status: $e',
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId, 'is_online': isOnline},
      );
      return false;
    }
  }

  /// Update driver vehicle type
  Future<bool> updateVehicleType(String driverId, String vehicleType) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'vehicle_type': vehicleType,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);

      await _telemetry.log('driver_vehicle_update', 'Vehicle type updated');
      return true;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_vehicle_update_failed',
        message: 'Failed to update vehicle type: $e',
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId, 'vehicle_type': vehicleType},
      );
      return false;
    }
  }

  /// Get all drivers (admin function)
  Future<List<DriverModel>> getAllDrivers() async {
    try {
      final response = await _supabase
          .from('drivers')
          .select('*, profiles(full_name, phone, verification_status)')
          .order('created_at', ascending: false);

      final drivers = response.map<DriverModel>((driver) {
        return DriverModel.fromJson(driver);
      }).toList();

      return drivers;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_fetch_all_failed',
        message: 'Failed to fetch all drivers: $e',
        stackTrace: st.toString(),
      );
      return [];
    }
  }

  /// Get unapproved drivers (admin function)
  Future<List<DriverModel>> getUnapprovedDrivers() async {
    try {
      final response = await _supabase
          .from('drivers')
          .select('*, profiles(full_name, phone, verification_status)')
          .eq('is_approved', false)
          .order('created_at', ascending: false);

      final drivers = response.map<DriverModel>((driver) {
        return DriverModel.fromJson(driver);
      }).toList();

      return drivers;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_fetch_unapproved_failed',
        message: 'Failed to fetch unapproved drivers: $e',
        stackTrace: st.toString(),
      );
      return [];
    }
  }

  /// Check if driver is approved and can go online
  Future<bool> canGoOnline(String driverId) async {
    try {
      final driver = await fetchDriverProfile(driverId);
      if (driver == null) return false;

      // Driver must be approved to go online
      if (!driver.isApproved) {
        await _telemetry.log(
          'driver_blocked_unapproved',
          'Driver tried to go online without approval',
        );
        return false;
      }

      return true;
    } catch (e, st) {
      await _telemetry.logError(
        type: 'driver_approval_check_failed',
        message: 'Failed to check driver approval: $e',
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId},
      );
      return false;
    }
  }
}
