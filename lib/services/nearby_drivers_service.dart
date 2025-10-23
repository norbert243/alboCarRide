import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class NearbyDriver {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String vehicleType;
  final double rating;
  final bool isOnline;

  NearbyDriver({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.vehicleType,
    required this.rating,
    required this.isOnline,
  });

  factory NearbyDriver.fromJson(Map<String, dynamic> json) {
    return NearbyDriver(
      id: json['id'] ?? '',
      name: json['profiles']?['full_name'] ?? 'Driver',
      latitude: (json['current_latitude'] ?? 0.0).toDouble(),
      longitude: (json['current_longitude'] ?? 0.0).toDouble(),
      vehicleType: json['vehicle_type'] ?? 'car',
      rating: (json['rating'] ?? 4.5).toDouble(),
      isOnline: json['is_online'] ?? false,
    );
  }
}

class NearbyDriversService {
  final _supabase = Supabase.instance.client;

  static final NearbyDriversService instance = NearbyDriversService._internal();
  NearbyDriversService._internal();

  /// Fetch nearby available drivers within a specified radius (in kilometers)
  Future<List<NearbyDriver>> getNearbyDrivers({
    required double userLatitude,
    required double userLongitude,
    double radiusKm = 5.0,
  }) async {
    try {
      // Calculate bounding box for the search radius
      final distance = radiusKm / 111.0; // Approximate degrees per km
      final minLat = userLatitude - distance;
      final maxLat = userLatitude + distance;
      final minLng = userLongitude - distance;
      final maxLng = userLongitude + distance;

      final response = await _supabase
          .from('drivers')
          .select('''
            id,
            current_latitude,
            current_longitude,
            vehicle_type,
            rating,
            is_online,
            profiles(full_name)
          ''')
          .gte('current_latitude', minLat)
          .lte('current_latitude', maxLat)
          .gte('current_longitude', minLng)
          .lte('current_longitude', maxLng)
          .eq('is_online', true)
          .eq('is_approved', true);

      final drivers = response.map<NearbyDriver>((driver) {
        return NearbyDriver.fromJson(driver);
      }).toList();

      // Filter by actual distance using Haversine formula
      final nearbyDrivers = drivers.where((driver) {
        final distance =
            Geolocator.distanceBetween(
              userLatitude,
              userLongitude,
              driver.latitude,
              driver.longitude,
            ) /
            1000.0; // Convert to kilometers
        return distance <= radiusKm;
      }).toList();

      return nearbyDrivers;
    } catch (e) {
      print('Error fetching nearby drivers: $e');
      return [];
    }
  }

  /// Get mock nearby drivers for development/testing
  List<NearbyDriver> getMockNearbyDrivers({
    required double userLatitude,
    required double userLongitude,
    int count = 8,
  }) {
    final drivers = <NearbyDriver>[];
    final vehicleTypes = ['car', 'car', 'car', 'car', 'suv', 'luxury'];
    final names = [
      'John D.',
      'Sarah M.',
      'Mike T.',
      'Lisa K.',
      'David W.',
      'Emma R.',
      'Alex B.',
      'Sophia L.',
    ];

    for (int i = 0; i < count; i++) {
      // Generate random positions within 5km radius
      final randomOffsetLat = (i % 4 - 1.5) * 0.01; // ~1km offset
      final randomOffsetLng = (i % 3 - 1.0) * 0.01; // ~1km offset

      drivers.add(
        NearbyDriver(
          id: 'mock_driver_$i',
          name: names[i % names.length],
          latitude: userLatitude + randomOffsetLat,
          longitude: userLongitude + randomOffsetLng,
          vehicleType: vehicleTypes[i % vehicleTypes.length],
          rating: 4.0 + (i % 5) * 0.1, // Ratings between 4.0 and 4.5
          isOnline: true,
        ),
      );
    }

    return drivers;
  }
}
