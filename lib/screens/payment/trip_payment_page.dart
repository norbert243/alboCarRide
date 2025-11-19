import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/mobile_money_service.dart';
import '../../services/trip_payment_service.dart';
import '../../widgets/custom_toast.dart';

class TripPaymentPage extends StatefulWidget {
  final String tripId;
  final String driverId;
  final double amount;
  final double commissionRate; // e.g., 0.10 for 10%

  const TripPaymentPage({
    super.key,
    required this.tripId,
    required this.driverId,
    required this.amount,
    this.commissionRate = 0.10,
  });

  @override
  State<TripPaymentPage> createState() => _TripPaymentPageState();
}

class _TripPaymentPageState extends State<TripPaymentPage> {
  final MobileMoneyService _mobileMoneyService = MobileMoneyService(
    Supabase.instance.client,
  );
  final TripPaymentService _paymentService = TripPaymentService(
    Supabase.instance.client,
  );

  final TextEditingController _transactionRefController =
      TextEditingController();

  DriverMobileMoneyAccount? _driverAccount;
  bool _isLoading = false;
  bool _paymentConfirmed = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadDriverMobileMoneyAccount();
  }

  @override
  void dispose() {
    _transactionRefController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverMobileMoneyAccount() async {
    setState(() => _isLoading = true);
    try {
      final account = await _mobileMoneyService.getPrimaryAccount(
        widget.driverId,
      );
      setState(() {
        _driverAccount = account;
      });

      if (_driverAccount == null) {
        CustomToast.showError(
          context: context,
          message: 'Driver has not set up mobile money account',
        );
      }
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to load payment details: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double get commissionAmount => widget.amount * widget.commissionRate;
  double get driverNetAmount => widget.amount - commissionAmount;

  Future<void> _confirmPayment() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Create payment record
      await _paymentService.createTripPayment(
        tripId: widget.tripId,
        customerId: userId,
        driverId: widget.driverId,
        amount: widget.amount,
        commissionAmount: commissionAmount,
        paymentMethod: _driverAccount!.provider,
        driverPhoneNumber: _driverAccount!.phoneNumber,
        driverMobileMoneyId: _driverAccount!.id,
      );

      // Customer confirms they made the payment
      await _paymentService.customerConfirmPayment(
        tripId: widget.tripId,
        transactionReference: _transactionRefController.text.isNotEmpty
            ? _transactionRefController.text
            : null,
      );

      setState(() => _paymentConfirmed = true);

      CustomToast.showSuccess(
        context: context,
        message: 'Payment confirmed! Waiting for driver verification.',
      );

      // Wait a bit then pop
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to confirm payment: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStepContent() {
    if (_driverAccount == null) {
      return const Center(
        child: Text('Driver payment information not available'),
      );
    }

    switch (_currentStep) {
      case 0:
        return _buildPaymentDetails();
      case 1:
        return _buildPaymentInstructions();
      case 2:
        return _buildConfirmation();
      default:
        return Container();
    }
  }

  Widget _buildPaymentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildDetailRow('Trip Amount', '\$${widget.amount.toStringAsFixed(2)}'),
        const Divider(),
        _buildDetailRow(
          'Platform Commission (${(widget.commissionRate * 100).toInt()}%)',
          '\$${commissionAmount.toStringAsFixed(2)}',
          isRed: true,
        ),
        const Divider(),
        _buildDetailRow(
          'Driver Receives',
          '\$${driverNetAmount.toStringAsFixed(2)}',
          isBold: true,
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _driverAccount!.provider.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Account: ${_driverAccount!.accountName}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Instructions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Driver\'s ${_driverAccount!.provider.displayName} Number',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _driverAccount!.phoneNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _driverAccount!.phoneNumber),
                      );
                      CustomToast.showInfo(
                        context: context,
                        message: 'Phone number copied',
                      );
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _driverAccount!.provider.instructions,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount to send: \$${widget.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.amount.toStringAsFixed(2)),
                        );
                        CustomToast.showInfo(
                          context: context,
                          message: 'Amount copied',
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Payment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text(
          'Have you completed the payment transfer?',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _transactionRefController,
          decoration: const InputDecoration(
            labelText: 'Transaction Reference (Optional)',
            hintText: 'Enter M-Pesa/Orange/Airtel transaction code',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.receipt),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Only confirm if you have successfully transferred the money to the driver.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isRed = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isRed ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay for Trip'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _driverAccount == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stepper
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: List.generate(3, (index) {
                      final isActive = index <= _currentStep;
                      final isCompleted = index < _currentStep;
                      return Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            if (index < 2) const SizedBox(width: 8),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildStepContent(),
                  ),
                ),

                // Navigation buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _currentStep--);
                            },
                            child: const Text('Back'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_currentStep < 2) {
                                    setState(() => _currentStep++);
                                  } else {
                                    _confirmPayment();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentStep == 2
                                ? Colors.green
                                : Colors.blue,
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
                              : Text(
                                  _currentStep < 2
                                      ? 'Next'
                                      : 'Confirm Payment',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
