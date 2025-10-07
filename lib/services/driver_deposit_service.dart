import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'document_upload_service.dart';

/// Service for handling driver deposit submissions
class DriverDepositService {
  final SupabaseClient supabase;
  final DocumentUploadService uploader;

  DriverDepositService({
    SupabaseClient? client,
    DocumentUploadService? uploader,
  }) : supabase = client ?? Supabase.instance.client,
       uploader = uploader ?? DocumentUploadService();

  /// Submits a deposit with proof of payment
  Future<void> submitDeposit({
    required String driverId,
    required double amount,
    required String method,
    required String accountReference,
    required XFile proofFile,
  }) async {
    try {
      // 1) upload proof
      final proofUrl = await uploader.uploadDocument(
        file: proofFile,
        userId: driverId,
        documentType: DocumentType.depositProof,
        customFileName:
            'deposit_proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // 2) create deposit record
      final response = await supabase.from('driver_deposits').insert({
        'driver_id': driverId,
        'amount': amount,
        'method': method,
        'account_reference': accountReference,
        'proof_url': proofUrl,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (response.error != null) {
        throw Exception(
          'Failed to create deposit record: ${response.error!.message}',
        );
      }
    } catch (e) {
      throw Exception('Deposit submission failed: $e');
    }
  }

  /// Gets driver's deposit history
  Future<List<Map<String, dynamic>>> getDepositHistory(String driverId) async {
    try {
      final deposits = await supabase
          .from('driver_deposits')
          .select('*')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return deposits;
    } catch (e) {
      throw Exception('Failed to get deposit history: $e');
    }
  }

  /// Gets pending deposits for admin review
  Future<List<Map<String, dynamic>>> getPendingDeposits() async {
    try {
      final deposits = await supabase
          .from('driver_deposits')
          .select('''
            *,
            profiles!driver_deposits_driver_id_fkey(
              full_name,
              phone,
              email
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return deposits;
    } catch (e) {
      throw Exception('Failed to get pending deposits: $e');
    }
  }

  /// Approves a deposit (admin only) using RPC function
  Future<void> approveDeposit(String depositId) async {
    try {
      final response = await supabase.rpc(
        'approve_driver_deposit',
        params: {'p_deposit_id': depositId},
      );
      if (response.error != null) {
        throw Exception(
          'Failed to approve deposit: ${response.error!.message}',
        );
      }
    } catch (e) {
      throw Exception('Failed to approve deposit: $e');
    }
  }

  /// Rejects a deposit (admin only) using RPC function
  Future<void> rejectDeposit(String depositId, String reason) async {
    try {
      final response = await supabase.rpc(
        'reject_driver_deposit',
        params: {'p_deposit_id': depositId, 'p_rejection_reason': reason},
      );
      if (response.error != null) {
        throw Exception('Failed to reject deposit: ${response.error!.message}');
      }
    } catch (e) {
      throw Exception('Failed to reject deposit: $e');
    }
  }

  /// Gets driver's current balance from wallet table
  Future<double> getDriverBalance(String driverId) async {
    try {
      final response = await supabase
          .from('driver_wallets')
          .select('balance')
          .eq('driver_id', driverId)
          .single();

      return (response['balance'] as num).toDouble();
    } catch (e) {
      // If wallet doesn't exist, return 0
      if (e.toString().contains('PGRST116')) {
        return 0.0;
      }
      throw Exception('Failed to get driver balance: $e');
    }
  }

  /// Gets deposit statistics for a driver
  Future<Map<String, dynamic>> getDepositStats(String driverId) async {
    try {
      final deposits = await supabase
          .from('driver_deposits')
          .select('amount, status, created_at')
          .eq('driver_id', driverId);

      double totalDeposited = 0;
      double pendingAmount = 0;
      double approvedAmount = 0;
      int pendingCount = 0;
      int approvedCount = 0;

      for (final deposit in deposits) {
        final amount = (deposit['amount'] as num).toDouble();
        final status = deposit['status'] as String;

        if (status == 'approved') {
          approvedAmount += amount;
          approvedCount++;
        } else if (status == 'pending') {
          pendingAmount += amount;
          pendingCount++;
        }
        totalDeposited += amount;
      }

      return {
        'total_deposited': totalDeposited,
        'pending_amount': pendingAmount,
        'approved_amount': approvedAmount,
        'pending_count': pendingCount,
        'approved_count': approvedCount,
      };
    } catch (e) {
      throw Exception('Failed to get deposit statistics: $e');
    }
  }
}
