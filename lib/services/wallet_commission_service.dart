import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Payment method for commission
enum CommissionPaymentMethod {
  bankTransfer,
  mpesa,
  orangeMoney,
  airtelMoney,
  cash;

  String get displayName {
    switch (this) {
      case CommissionPaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case CommissionPaymentMethod.mpesa:
        return 'M-Pesa';
      case CommissionPaymentMethod.orangeMoney:
        return 'Orange Money';
      case CommissionPaymentMethod.airtelMoney:
        return 'Airtel Money';
      case CommissionPaymentMethod.cash:
        return 'Cash';
    }
  }

  String toDbString() {
    switch (this) {
      case CommissionPaymentMethod.bankTransfer:
        return 'bank_transfer';
      case CommissionPaymentMethod.mpesa:
        return 'mpesa';
      case CommissionPaymentMethod.orangeMoney:
        return 'orange_money';
      case CommissionPaymentMethod.airtelMoney:
        return 'airtel_money';
      case CommissionPaymentMethod.cash:
        return 'cash';
    }
  }

  static CommissionPaymentMethod fromString(String value) {
    switch (value) {
      case 'bank_transfer':
        return CommissionPaymentMethod.bankTransfer;
      case 'mpesa':
        return CommissionPaymentMethod.mpesa;
      case 'orange_money':
        return CommissionPaymentMethod.orangeMoney;
      case 'airtel_money':
        return CommissionPaymentMethod.airtelMoney;
      case 'cash':
        return CommissionPaymentMethod.cash;
      default:
        throw ArgumentError('Invalid commission payment method: $value');
    }
  }
}

/// Status of commission payment
enum CommissionPaymentStatus {
  pending,
  verified,
  rejected;

  String toDbString() {
    switch (this) {
      case CommissionPaymentStatus.pending:
        return 'pending';
      case CommissionPaymentStatus.verified:
        return 'verified';
      case CommissionPaymentStatus.rejected:
        return 'rejected';
    }
  }

  static CommissionPaymentStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return CommissionPaymentStatus.pending;
      case 'verified':
        return CommissionPaymentStatus.verified;
      case 'rejected':
        return CommissionPaymentStatus.rejected;
      default:
        throw ArgumentError('Invalid commission payment status: $value');
    }
  }
}

/// Represents a commission payment made by a driver
class WalletCommissionPayment {
  final String id;
  final String driverId;
  final double amount;
  final CommissionPaymentMethod paymentMethod;
  final String? transactionReference;
  final String? paymentProofUrl;
  final CommissionPaymentStatus status;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? driverNotes;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WalletCommissionPayment({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    this.paymentProofUrl,
    required this.status,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    this.driverNotes,
    this.adminNotes,
    required this.createdAt,
    this.updatedAt,
  });

  factory WalletCommissionPayment.fromMap(Map<String, dynamic> map) {
    return WalletCommissionPayment(
      id: map['id'] as String,
      driverId: map['driver_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: CommissionPaymentMethod.fromString(
        map['payment_method'] as String,
      ),
      transactionReference: map['transaction_reference'] as String?,
      paymentProofUrl: map['payment_proof_url'] as String?,
      status: CommissionPaymentStatus.fromString(map['status'] as String),
      verifiedBy: map['verified_by'] as String?,
      verifiedAt: map['verified_at'] != null
          ? DateTime.parse(map['verified_at'] as String)
          : null,
      rejectionReason: map['rejection_reason'] as String?,
      driverNotes: map['driver_notes'] as String?,
      adminNotes: map['admin_notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'amount': amount,
      'payment_method': paymentMethod.toDbString(),
      'transaction_reference': transactionReference,
      'payment_proof_url': paymentProofUrl,
      'status': status.toDbString(),
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'driver_notes': driverNotes,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Service for managing driver wallet commission payments
class WalletCommissionService {
  final SupabaseClient _supabase;

  WalletCommissionService(this._supabase);

  /// Submit a commission payment
  Future<WalletCommissionPayment> submitCommissionPayment({
    required String driverId,
    required double amount,
    required CommissionPaymentMethod paymentMethod,
    String? transactionReference,
    String? paymentProofUrl,
    String? driverNotes,
  }) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .insert({
            'driver_id': driverId,
            'amount': amount,
            'payment_method': paymentMethod.toDbString(),
            'transaction_reference': transactionReference,
            'payment_proof_url': paymentProofUrl,
            'driver_notes': driverNotes,
          })
          .select()
          .single();

      return WalletCommissionPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to submit commission payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error submitting commission payment: $e');
    }
  }

  /// Get all commission payments for a driver
  Future<List<WalletCommissionPayment>> getDriverCommissionPayments(
    String driverId,
  ) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((payment) => WalletCommissionPayment.fromMap(payment))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch commission payments: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching commission payments: $e');
    }
  }

  /// Get pending commission payments for a driver
  Future<List<WalletCommissionPayment>> getPendingCommissionPayments(
    String driverId,
  ) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .select()
          .eq('driver_id', driverId)
          .eq('status', CommissionPaymentStatus.pending.toDbString())
          .order('created_at', ascending: false);

      return (response as List)
          .map((payment) => WalletCommissionPayment.fromMap(payment))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pending payments: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching pending payments: $e');
    }
  }

  /// Get verified (approved) commission payments for a driver
  Future<List<WalletCommissionPayment>> getVerifiedCommissionPayments(
    String driverId,
  ) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .select()
          .eq('driver_id', driverId)
          .eq('status', CommissionPaymentStatus.verified.toDbString())
          .order('verified_at', ascending: false);

      return (response as List)
          .map((payment) => WalletCommissionPayment.fromMap(payment))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch verified payments: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching verified payments: $e');
    }
  }

  /// Get a specific commission payment
  Future<WalletCommissionPayment> getCommissionPayment(
    String paymentId,
  ) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .select()
          .eq('id', paymentId)
          .single();

      return WalletCommissionPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch commission payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching commission payment: $e');
    }
  }

  /// Upload payment proof (receipt/screenshot)
  Future<String> uploadPaymentProof({
    required String driverId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      // Upload to Supabase storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'commission_proofs/$driverId/$timestamp-$fileName';

      final file = File(filePath);
      final fileBytes = await file.readAsBytes();

      await _supabase.storage
          .from('documents')
          .uploadBinary(storagePath, fileBytes);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('documents')
          .getPublicUrl(storagePath);

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception('Failed to upload payment proof: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading payment proof: $e');
    }
  }

  /// Update commission payment with proof URL
  Future<WalletCommissionPayment> updatePaymentProof({
    required String paymentId,
    required String paymentProofUrl,
  }) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .update({'payment_proof_url': paymentProofUrl})
          .eq('id', paymentId)
          .select()
          .single();

      return WalletCommissionPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update payment proof: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating payment proof: $e');
    }
  }

  /// Get driver's wallet balance and outstanding commission
  Future<Map<String, double>> getDriverWalletSummary(String driverId) async {
    try {
      // Get wallet balance
      final walletResponse = await _supabase
          .from('driver_wallet')
          .select('balance, total_earned')
          .eq('driver_id', driverId)
          .maybeSingle();

      double balance = 0.0;
      double totalEarned = 0.0;

      if (walletResponse != null) {
        balance = (walletResponse['balance'] as num?)?.toDouble() ?? 0.0;
        totalEarned = (walletResponse['total_earned'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate outstanding commission (negative balance means driver owes)
      final outstandingCommission = balance < 0 ? balance.abs() : 0.0;

      // Get total pending payments
      final pendingPayments = await getPendingCommissionPayments(driverId);
      final totalPending = pendingPayments.fold<double>(
        0.0,
        (sum, payment) => sum + payment.amount,
      );

      // Get total verified payments
      final verifiedPayments = await getVerifiedCommissionPayments(driverId);
      final totalVerified = verifiedPayments.fold<double>(
        0.0,
        (sum, payment) => sum + payment.amount,
      );

      return {
        'balance': balance,
        'total_earned': totalEarned,
        'outstanding_commission': outstandingCommission,
        'total_pending': totalPending,
        'total_verified': totalVerified,
      };
    } catch (e) {
      throw Exception('Failed to get wallet summary: $e');
    }
  }

  /// Get payment instructions based on payment method
  String getPaymentInstructions(CommissionPaymentMethod method) {
    switch (method) {
      case CommissionPaymentMethod.bankTransfer:
        return '''Bank Transfer Instructions:

1. Bank: Example Bank Name
2. Account Name: AlboCarRide Ltd
3. Account Number: 1234567890
4. Reference: Your Driver ID

After transferring, please upload the bank receipt as proof.''';

      case CommissionPaymentMethod.mpesa:
        return '''M-Pesa Payment Instructions:

1. Dial *555# on your phone
2. Select "Send Money"
3. Enter number: 0700123456
4. Enter amount
5. Enter your PIN
6. Enter Driver ID as reference

After payment, enter the M-Pesa transaction code below.''';

      case CommissionPaymentMethod.orangeMoney:
        return '''Orange Money Payment Instructions:

1. Dial *144# on your phone
2. Select "Transfer Money"
3. Enter number: 0700123456
4. Enter amount
5. Enter your PIN
6. Enter Driver ID as reference

After payment, enter the Orange Money transaction code below.''';

      case CommissionPaymentMethod.airtelMoney:
        return '''Airtel Money Payment Instructions:

1. Dial *150# on your phone
2. Select "Send Money"
3. Enter number: 0700123456
4. Enter amount
5. Enter your PIN
6. Enter Driver ID as reference

After payment, enter the Airtel Money transaction code below.''';

      case CommissionPaymentMethod.cash:
        return '''Cash Payment Instructions:

Please visit any AlboCarRide office or authorized agent to make a cash payment.

Bring:
1. Your Driver ID
2. Cash amount
3. Valid ID

You will receive a receipt after payment.''';
    }
  }

  // ========== ADMIN FUNCTIONS (for future implementation) ==========

  /// Verify a commission payment (admin only)
  Future<WalletCommissionPayment> verifyPayment({
    required String paymentId,
    required String verifiedBy,
    String? adminNotes,
  }) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .update({
            'status': CommissionPaymentStatus.verified.toDbString(),
            'verified_by': verifiedBy,
            'verified_at': DateTime.now().toIso8601String(),
            'admin_notes': adminNotes,
          })
          .eq('id', paymentId)
          .select()
          .single();

      return WalletCommissionPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to verify payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error verifying payment: $e');
    }
  }

  /// Reject a commission payment (admin only)
  Future<WalletCommissionPayment> rejectPayment({
    required String paymentId,
    required String verifiedBy,
    required String rejectionReason,
    String? adminNotes,
  }) async {
    try {
      final response = await _supabase
          .from('wallet_commission_payments')
          .update({
            'status': CommissionPaymentStatus.rejected.toDbString(),
            'verified_by': verifiedBy,
            'verified_at': DateTime.now().toIso8601String(),
            'rejection_reason': rejectionReason,
            'admin_notes': adminNotes,
          })
          .eq('id', paymentId)
          .select()
          .single();

      return WalletCommissionPayment.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to reject payment: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error rejecting payment: $e');
    }
  }
}
