import 'package:google_maps_flutter/google_maps_flutter.dart';

class Trip {
  final String id;
  final String? driverId;
  final String customerId;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final double fare;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes; // Added notes property

  // Added fields from other parts of the app that were missing
  final String? driverName;
  final String? riderName;
  final LatLng? driverLocation;
  final double proposedPrice;
  final String? cancellationReason;
  final DateTime? endTime;
  final double? finalPrice;
  final String? vehicleType;


  Trip({
    required this.id,
    this.driverId,
    required this.customerId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.notes, // Added to constructor
    this.driverName,
    this.riderName,
    this.driverLocation,
    this.proposedPrice = 0.0,
    this.cancellationReason,
    this.endTime,
    this.finalPrice,
    this.vehicleType,
  });

  factory Trip.fromMap(Map<String, dynamic> m) {
    // Helper to safely extract LatLng
    LatLng? safeLatLng(dynamic lat, dynamic lng) {
      if (lat != null && lng != null) {
        return LatLng((lat as num).toDouble(), (lng as num).toDouble());
      }
      return null;
    }

    final pickupLocation = safeLatLng(m['pickup_lat'] ?? m['pickup_latitude'], m['pickup_lng'] ?? m['pickup_longitude']);
    final dropoffLocation = safeLatLng(m['dropoff_lat'] ?? m['dropoff_latitude'], m['dropoff_lng'] ?? m['dropoff_longitude']);
    final driverLocation = safeLatLng(m['driver_lat'], m['driver_lng']);

    if (pickupLocation == null || dropoffLocation == null) {
      throw Exception('Pickup or dropoff location is missing or invalid in Trip.fromMap');
    }

    return Trip(
      id: m['id'] as String,
      driverId: m['driver_id'] as String?,
      customerId: m['customer_id'] as String,
      pickupAddress: m['pickup_address'] as String,
      dropoffAddress: m['dropoff_address'] as String,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      fare: (m['fare'] as num? ?? m['total_price'] as num? ?? 0.0).toDouble(),
      status: m['status'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      startedAt: m['started_at'] != null ? DateTime.parse(m['started_at'] as String) : null,
      completedAt: m['completed_at'] != null ? DateTime.parse(m['completed_at'] as String) : null,
      notes: m['notes'] as String?, // Added to fromMap
      driverName: m['driver_name'] as String?,
      riderName: m['rider_name'] as String?,
      driverLocation: driverLocation,
      proposedPrice: (m['proposed_price'] as num? ?? m['estimated_price'] as num? ?? 0.0).toDouble(),
      cancellationReason: m['cancellation_reason'] as String?,
      endTime: m['end_time'] != null ? DateTime.parse(m['end_time'] as String) : null,
      finalPrice: (m['final_price'] as num?)?.toDouble(),
      vehicleType: m['vehicle_type'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'driver_id': driverId,
    'customer_id': customerId,
    'pickup_address': pickupAddress,
    'dropoff_address': dropoffAddress,
    'pickup_lat': pickupLocation.latitude,
    'pickup_lng': pickupLocation.longitude,
    'dropoff_lat': dropoffLocation.latitude,
    'dropoff_lng': dropoffLocation.longitude,
    'fare': fare,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'notes': notes, // Added to toMap
    'driver_name': driverName,
    'rider_name': riderName,
    'driver_lat': driverLocation?.latitude,
    'driver_lng': driverLocation?.longitude,
    'proposed_price': proposedPrice,
    'cancellation_reason': cancellationReason,
    'end_time': endTime?.toIso8601String(),
    'final_price': finalPrice,
    'vehicle_type': vehicleType,
  };
}
