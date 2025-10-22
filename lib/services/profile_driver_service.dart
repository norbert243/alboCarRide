import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileDriverService {
  ProfileDriverService._();
  static final ProfileDriverService instance = ProfileDriverService._();

  final SupabaseClient supabase = Supabase.instance.client;

  /// payload: { profile: {...}, driver: {...} }
  Future<String?> createOrUpdateProfileAndDriver(Map<String, dynamic> payload) async {
    try {
      final res = await supabase.rpc('create_or_update_profile_and_driver', params: {'p_payload': payload});
      if (res.error != null) {
        throw res.error!;
      }
      // Depending on your supabase client, rpc returns data differently — adjust:
      final returnedId = res.data; // may be uuid string
      return returnedId?.toString();
    } catch (e) {
      // Fallback to direct upsert if RPC fails
      print('RPC failed, using direct upsert: $e');
      return await _fallbackUpsert(payload);
    }
  }

  /// Simple convenience to upsert profile then driver from client (if RPC not used)
  Future<String?> _fallbackUpsert(Map<String, dynamic> payload) async {
    final profile = payload['profile'] as Map<String, dynamic>?;
    final driver = payload['driver'] as Map<String, dynamic>?;

    if (profile == null || driver == null) {
      throw Exception('Profile and driver data are required');
    }

    // upsert profile
    final up1 = await supabase.from('profiles').upsert(profile);
    if (up1.error != null) throw up1.error!;
    
    // upsert driver (must have same id)
    final up2 = await supabase.from('drivers').upsert(driver);
    if (up2.error != null) throw up2.error!;

    return profile['id']?.toString();
  }

  /// Convenience method for driver registration
  Future<String?> registerDriver({
    required String userId,
    required String fullName,
    required String phone,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required String licensePlate,
    required int vehicleYear,
    String? licenseNumber,
  }) async {
    final payload = {
      'profile': {
        'id': userId,
        'full_name': fullName,
        'phone': phone,
        'role': 'driver',
        'updated_at': DateTime.now().toIso8601String(),
      },
      'driver': {
        'id': userId,
        'license_number': licenseNumber,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear.toString(),
        'license_plate': licensePlate,
        'vehicle_type': vehicleType,
        'is_approved': false,
        'updated_at': DateTime.now().toIso8601String(),
      }
    };

    return await createOrUpdateProfileAndDriver(payload);
  }
}