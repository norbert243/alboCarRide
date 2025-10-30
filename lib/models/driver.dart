enum ApprovalStatus { pending, approved, rejected }

enum VehicleType { car, motorcycle }

class Driver {
  final String id;
  final String profileId;
  final ApprovalStatus approvalStatus;
  final bool onlineStatus;
  final VehicleType vehicleType;
  final String licensePlate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Driver({
    required this.id,
    required this.profileId,
    required this.approvalStatus,
    required this.onlineStatus,
    required this.vehicleType,
    required this.licensePlate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Driver.fromMap(Map<String, dynamic> m) => Driver(
    id: m['id'] as String,
    profileId: m['profile_id'] as String,
    approvalStatus: ApprovalStatus.values.firstWhere(
      (e) => e.toString().split('.').last == m['approval_status'],
      orElse: () => ApprovalStatus.pending,
    ),
    onlineStatus: m['online_status'] as bool,
    vehicleType: VehicleType.values.firstWhere(
      (e) => e.toString().split('.').last == m['vehicle_type'],
      orElse: () => VehicleType.car,
    ),
    licensePlate: m['license_plate'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'profile_id': profileId,
    'approval_status': approvalStatus.toString().split('.').last,
    'online_status': onlineStatus,
    'vehicle_type': vehicleType.toString().split('.').last,
    'license_plate': licensePlate,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Driver copyWith({
    String? id,
    String? profileId,
    ApprovalStatus? approvalStatus,
    bool? onlineStatus,
    VehicleType? vehicleType,
    String? licensePlate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Driver(id: $id, profileId: $profileId, approvalStatus: $approvalStatus, onlineStatus: $onlineStatus, vehicleType: $vehicleType, licensePlate: $licensePlate)';
  }
}
