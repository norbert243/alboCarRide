import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile_money_service.dart';

/// Trip payment status
enum TripPaymentStatus {
  pending,
  customerConfirmed,
  completed,
  disputed,
  failed;

  String toDbString() {
    switch (this) {
      case TripPaymentStatus.pending:
        return 'pending';
      case TripPaymentStatus.customerConfirmed:
        return 'customer_confirmed';
      case TripPaymentStatus.completed:
        return 'completed';
      case TripPaymentStatus.disputed:
        return 'disputed';
      case TripPaymentStatus.failed:
        return 'failed';
    }
  }

  static TripPaymentStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return TripPaymentStatus.pending;
      case 'customer_confirmed':
        return TripPaymentStatus.customerConfirmed;
      case 'completed':
        return TripPaymentStatus.completed;
      case 'disputed':
        return TripPaymentStatus.disputed;
      case 'failed':
        return TripPaymentStatus.failed;
      default:
        throw ArgumentError('Invalid payment status: $value');
    }
  }
}

/// Represents a trip payment
class TripPayment {
  final String id;
  final String tripId;
  final String customerId;
  final String driverId;
  final double amount;
  final double commissionAmount;
  final double driverNetAmount;
  final MobileMoneyProvider paymentMethod;
  final String? driverMobileMoneyId;
  final String? driverPhoneNumber;
  final bool customerConfirmed;
  final DateTime? customerConfirmedAt;
  final bool driverConfirmed;
  final DateTime? driverConfirmedAt;
  final TripPaymentStatus status;
  final String? disputedBy;
  final String? disputeReason;
  final bool disputeResolved;
  final String? disputeResolution;
  final String? transactionReference;
  final bool commissionDeducted;
  final DateTime? commissionDeductedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TripPayment({
    required this.id,
    required this.tripId,
    required this.customerId,
    required this.driverId,
    required this.amount,
    required this.commissionAmount,
    required this.driverNetAmount,
    required this.paymentMethod,
    this.driverMobileMoneyId,
    this.driverPhoneNumber,
    required this.customerConfirmed,
    this.customerConfirmedAt,
    required this.driverConfirmed,
    this.driverConfirmedAt,
    required this.status,
    this.disputedBy,
    this.disputeReason,
    required this.disputeResolved,
    this.disputeResolution,
    this.transactionReference,
    required this.commissionDeducted,
    this.commissionDeductedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory TripPayment.fromMap(Map<String, dynamic> map) {
    return TripPayment(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      customerId: map['customer_id'] as String,
      driverId: map['driver_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      commissionAmount: (map['commission_amount'] as num).toDouble(),
      driverNetAmount: (map['driver_net_amount'] as num).toDouble(),
      paymentMethod:
          MobileMoneyProvider.fromString(map['payment_method'] as String),
      driverMobileMoneyId: map['driver_mobile_money_id'] as String?,
      driverPhoneNumber: map['driver_phone_number'] as String?,
      customerConfirmed: map['customer_confirmed'] as bool,
      customerConfirmedAt: map['customer_confirmed_at'] != null
          ? DateTime.parse(map['customer_confirmed_at'] as String)
          : null,
      driverConfirmed: map['driver_confirmed'] as bool,
      driverConfirmedAt: map['driver_confirmed_at'] != null
          ? DateTime.parse(map['driver_confirmed_at'] as String)
          : null,
      status: TripPaymentStatus.fromString(map['status'] as String),
      disputedBy: map['disputed_by'] as String?,
      disputeReason: map['dispute_reason'] as String?,
      disputeResolved: map['dispute_resolved'] as bool,
      disputeResolution: map['dispute_resolution'] as String?,
      transactionReference: map['transaction_reference'] as String?,
      commissionDeducted: map['commission_deducted'] as bool,
      commissionDeductedAt: map['commission_deducted_at'] != null
          ? DateTime.parse(map['commission_deducted_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}

/// Service for managing trip payments
class TripPaymentService {
  final SupabaseClient _supabase;

  TripPaymentService(this._supabase);

  /// Create a payment record for a trip
  Future<TripPayment> createTripPayment({
    required String tripId,
    required String customerId,
    required String driverId,
    required double amount,
    required double commissionAmount,
    required MobileMoneyProvider paymentMethod,
    required String driverPhoneNumber,
    String? driverMobileMoneyId,
  }) async {
    try {
      final driverNetAmount = amount - commissionAmount;

      final response = await _supabase
          .from('trip_payments')
          .insert({
            'trip_id': tripId,
            'customer_id': customerId,
            'driver_id': driverId,
            'amount': amount,
            'commission_amount': commissionAmount,
            'driver_net_amount': driverNetAmount,
            'payment_method': paymentMethod.toDbString(),
            'driver_phone_number': driverPhoneNumber,
            'driver_mobile_money_id': driverMobileMoneyId,
          })
          .select()
          .single();

      return TripPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create trip payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating trip payment: $e');
    }
  }

  /// Get payment for a trip
  Future<TripPayment?> getTripPayment(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .select()
          .eq('trip_id', tripId)
          .maybeSingle();

      if (response == null) return null;
      return TripPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch trip payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching trip payment: $e');
    }
  }

  /// Customer confirms they made the payment
  Future<TripPayment> customerConfirmPayment({
    required String tripId,
    String? transactionReference,
  }) async {
    try {
      final updateData = {
        'customer_confirmed': true,
        'customer_confirmed_at': DateTime.now().toIso8601String(),
        'status': TripPaymentStatus.customerConfirmed.toDbString(),
      };

      if (transactionReference != null) {
        updateData['transaction_reference'] = transactionReference;
      }

      final response = await _supabase
          .from('trip_payments')
          .update(updateData)
          .eq('trip_id', tripId)
          .select()
          .single();

      return TripPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to confirm payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error confirming payment: $e');
    }
  }

  /// Driver confirms they received the payment
  Future<TripPayment> driverConfirmPayment(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .update({
            'driver_confirmed': true,
            'driver_confirmed_at': DateTime.now().toIso8601String(),
            'status': TripPaymentStatus.completed.toDbString(),
          })
          .eq('trip_id', tripId)
          .select()
          .single();

      return TripPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to confirm payment receipt: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error confirming payment receipt: $e');
    }
  }

  /// Raise a payment dispute
  Future<TripPayment> raiseDispute({
    required String tripId,
    required String disputedBy, // 'customer' or 'driver'
    required String disputeReason,
  }) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .update({
            'status': TripPaymentStatus.disputed.toDbString(),
            'disputed_by': disputedBy,
            'dispute_reason': disputeReason,
          })
          .eq('trip_id', tripId)
          .select()
          .single();

      return TripPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to raise dispute: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error raising dispute: $e');
    }
  }

  /// Resolve a payment dispute (admin function)
  Future<TripPayment> resolveDispute({
    required String tripId,
    required String resolution,
  }) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .update({
            'dispute_resolved': true,
            'dispute_resolution': resolution,
            'status': TripPaymentStatus.completed.toDbString(),
          })
          .eq('trip_id', tripId)
          .select()
          .single();

      return TripPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to resolve dispute: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error resolving dispute: $e');
    }
  }

  /// Get all payments for a customer
  Future<List<TripPayment>> getCustomerPayments(String customerId) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((payment) => TripPayment.fromMap(payment))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch customer payments: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching customer payments: $e');
    }
  }

  /// Get all payments for a driver
  Future<List<TripPayment>> getDriverPayments(String driverId) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((payment) => TripPayment.fromMap(payment))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch driver payments: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching driver payments: $e');
    }
  }

  /// Get pending payments (not confirmed by both parties)
  Future<List<TripPayment>> getPendingPayments(String userId) async {
    try {
      final response = await _supabase
          .from('trip_payments')
          .select()
          .or('customer_id.eq.$userId,driver_id.eq.$userId')
          .inFilter('status', [
            TripPaymentStatus.pending.toDbString(),
            TripPaymentStatus.customerConfirmed.toDbString(),
          ])
          .order('created_at', ascending: false);

      return (response as List)
          .map((payment) => TripPayment.fromMap(payment))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pending payments: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching pending payments: $e');
    }
  }
}
