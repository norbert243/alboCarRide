class Trip {
  final String id;
  final String driverId;
  final String customerId;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double fare;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Trip({
    required this.id,
    required this.driverId,
    required this.customerId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory Trip.fromMap(Map<String, dynamic> m) => Trip(
    id: m['id'] as String,
    driverId: m['driver_id'] as String,
    customerId: m['customer_id'] as String,
    pickupAddress: m['pickup_address'] as String,
    dropoffAddress: m['dropoff_address'] as String,
    pickupLat: (m['pickup_lat'] as num).toDouble(),
    pickupLng: (m['pickup_lng'] as num).toDouble(),
    dropoffLat: (m['dropoff_lat'] as num).toDouble(),
    dropoffLng: (m['dropoff_lng'] as num).toDouble(),
    fare: (m['fare'] as num).toDouble(),
    status: m['status'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
    startedAt: m['started_at'] != null
        ? DateTime.parse(m['started_at'] as String)
        : null,
    completedAt: m['completed_at'] != null
        ? DateTime.parse(m['completed_at'] as String)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'driver_id': driverId,
    'customer_id': customerId,
    'pickup_address': pickupAddress,
    'dropoff_address': dropoffAddress,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'fare': fare,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };
}
