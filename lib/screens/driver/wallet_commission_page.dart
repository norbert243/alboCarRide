import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/wallet_commission_service.dart';
import '../../services/session_service.dart';
import '../../widgets/custom_toast.dart';

class WalletCommissionPage extends StatefulWidget {
  const WalletCommissionPage({super.key});

  @override
  State<WalletCommissionPage> createState() => _WalletCommissionPageState();
}

class _WalletCommissionPageState extends State<WalletCommissionPage> {
  final WalletCommissionService _commissionService = WalletCommissionService(
    Supabase.instance.client,
  );

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Map<String, double>? _walletSummary;
  List<WalletCommissionPayment> _recentPayments = [];
  bool _isLoading = false;
  String? _driverId;
  CommissionPaymentMethod _selectedMethod = CommissionPaymentMethod.mpesa;
  File? _proofImage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _driverId = await SessionService.getUserIdStatic();
    if (_driverId != null) {
      await _loadWalletSummary();
      await _loadRecentPayments();
    }
  }

  Future<void> _loadWalletSummary() async {
    try {
      final summary =
          await _commissionService.getDriverWalletSummary(_driverId!);
      setState(() {
        _walletSummary = summary;
      });
    } catch (e) {
      print('Failed to load wallet summary: $e');
    }
  }

  Future<void> _loadRecentPayments() async {
    try {
      final payments =
          await _commissionService.getDriverCommissionPayments(_driverId!);
      setState(() {
        _recentPayments = payments.take(5).toList();
      });
    } catch (e) {
      print('Failed to load recent payments: $e');
    }
  }

  Future<void> _pickProofImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _proofImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_amountController.text.isEmpty) {
      CustomToast.showError(context: context, message: 'Enter amount');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      CustomToast.showError(context: context, message: 'Invalid amount');
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? proofUrl;

      // Upload proof if image is selected
      if (_proofImage != null) {
        proofUrl = await _commissionService.uploadPaymentProof(
          driverId: _driverId!,
          filePath: _proofImage!.path,
          fileName: 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      await _commissionService.submitCommissionPayment(
        driverId: _driverId!,
        amount: amount,
        paymentMethod: _selectedMethod,
        transactionReference: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        paymentProofUrl: proofUrl,
        driverNotes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
      );

      // Clear form
      _amountController.clear();
      _referenceController.clear();
      _notesController.clear();
      setState(() => _proofImage = null);

      await _loadWalletSummary();
      await _loadRecentPayments();

      CustomToast.showSuccess(
        context: context,
        message: 'Payment submitted for verification',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to submit payment: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstandingCommission =
        _walletSummary?['outstanding_commission'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Payment'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Summary Card
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Wallet Balance:'),
                        Text(
                          '\$${_walletSummary?['balance']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Outstanding Commission:'),
                        Text(
                          '\$${outstandingCommission.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: outstandingCommission > 0
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Form
            const Text(
              'Pay Commission',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method
            const Text('Payment Method'),
            const SizedBox(height: 8),
            ...CommissionPaymentMethod.values.map((method) {
              return RadioListTile<CommissionPaymentMethod>(
                title: Text(method.displayName),
                value: method,
                groupValue: _selectedMethod,
                onChanged: (value) {
                  setState(() => _selectedMethod = value!);
                },
              );
            }),
            const SizedBox(height: 16),

            // Payment Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _commissionService.getPaymentInstructions(_selectedMethod),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transaction Reference
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Transaction Reference (Optional)',
                border: OutlineInputBorder(),
                hintText: 'M-Pesa/Orange/Airtel transaction code',
              ),
            ),
            const SizedBox(height: 16),

            // Upload Proof
            OutlinedButton.icon(
              onPressed: _pickProofImage,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _proofImage == null
                    ? 'Upload Payment Proof (Optional)'
                    : 'Proof Uploaded',
              ),
            ),
            if (_proofImage != null) ...[
              const SizedBox(height: 8),
              Image.file(_proofImage!, height: 100),
            ],
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Payment', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Payments
            if (_recentPayments.isNotEmpty) ...[
              const Text(
                'Recent Payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._recentPayments.map((payment) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      payment.status == CommissionPaymentStatus.verified
                          ? Icons.check_circle
                          : payment.status == CommissionPaymentStatus.rejected
                              ? Icons.cancel
                              : Icons.pending,
                      color: payment.status == CommissionPaymentStatus.verified
                          ? Colors.green
                          : payment.status == CommissionPaymentStatus.rejected
                              ? Colors.red
                              : Colors.orange,
                    ),
                    title: Text('\$${payment.amount.toStringAsFixed(2)}'),
                    subtitle: Text(
                      '${payment.paymentMethod.displayName} • ${payment.status.toDbString()}',
                    ),
                    trailing: Text(
                      payment.createdAt.toString().split(' ')[0],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
