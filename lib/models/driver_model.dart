class DriverModel {
  final String id;
  final bool isOnline;
  final bool isApproved; // ✅ New field
  final double rating;
  final int totalRides;
  final String? vehicleType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DriverModel({
    required this.id,
    required this.isOnline,
    required this.isApproved,
    required this.rating,
    required this.totalRides,
    this.vehicleType,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'],
      isOnline: json['is_online'] ?? false,
      isApproved: json['is_approved'] ?? false, // ✅ synced
      rating: (json['rating'] ?? 0).toDouble(),
      totalRides: json['total_rides'] ?? 0,
      vehicleType: json['vehicle_type'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_online': isOnline,
      'is_approved': isApproved,
      'rating': rating,
      'total_rides': totalRides,
      'vehicle_type': vehicleType,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DriverModel copyWith({
    String? id,
    bool? isOnline,
    bool? isApproved,
    double? rating,
    int? totalRides,
    String? vehicleType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverModel(
      id: id ?? this.id,
      isOnline: isOnline ?? this.isOnline,
      isApproved: isApproved ?? this.isApproved,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      vehicleType: vehicleType ?? this.vehicleType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DriverModel(id: $id, isOnline: $isOnline, isApproved: $isApproved, rating: $rating, totalRides: $totalRides, vehicleType: $vehicleType)';
  }
}
