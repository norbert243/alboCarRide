import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a trip created when a driver accepts a ride offer
class Trip {
  final String id;
  final String riderId;
  final String driverId;
  final String requestId;
  final String offerId;
  final DateTime? startTime;
  final DateTime? endTime;
  final double finalPrice;
  final String status; // 'scheduled', 'in_progress', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? cancellationReason;

  Trip({
    required this.id,
    required this.riderId,
    required this.driverId,
    required this.requestId,
    required this.offerId,
    this.startTime,
    this.endTime,
    required this.finalPrice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.cancellationReason,
  });

  /// Creates an empty trip instance
  factory Trip.empty() {
    return Trip(
      id: '',
      riderId: '',
      driverId: '',
      requestId: '',
      offerId: '',
      finalPrice: 0.0,
      status: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      riderId: map['rider_id'] as String,
      driverId: map['driver_id'] as String,
      requestId: map['request_id'] as String,
      offerId: map['offer_id'] as String,
      startTime: map['start_time'] != null
          ? DateTime.parse(map['start_time'] as String)
          : null,
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      finalPrice: (map['final_price'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      cancellationReason: map['cancellation_reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rider_id': riderId,
      'driver_id': driverId,
      'request_id': requestId,
      'offer_id': offerId,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'final_price': finalPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'cancellation_reason': cancellationReason,
    };
  }

  /// Creates a copy with updated values
  Trip copyWith({
    String? id,
    String? riderId,
    String? driverId,
    String? requestId,
    String? offerId,
    DateTime? startTime,
    DateTime? endTime,
    double? finalPrice,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? cancellationReason,
  }) {
    return Trip(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      driverId: driverId ?? this.driverId,
      requestId: requestId ?? this.requestId,
      offerId: offerId ?? this.offerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      finalPrice: finalPrice ?? this.finalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  /// Check if trip is active (scheduled or in progress)
  bool get isActive => status == 'scheduled' || status == 'in_progress';

  /// Check if trip is completed
  bool get isCompleted => status == 'completed';

  /// Check if trip is cancelled
  bool get isCancelled => status == 'cancelled';

  @override
  String toString() {
    return 'Trip(id: $id, riderId: $riderId, driverId: $driverId, status: $status, finalPrice: $finalPrice)';
  }
}
