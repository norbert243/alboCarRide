import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class CustomerPaymentPage extends StatefulWidget {
  final String tripId;
  const CustomerPaymentPage({super.key, required this.tripId});

  @override
  State<CustomerPaymentPage> createState() => _CustomerPaymentPageState();
}

class _CustomerPaymentPageState extends State<CustomerPaymentPage> {
  Trip? _trip;
  Map<String, dynamic>? _driverPaymentDetails;
  String? _driverName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripAndPaymentDetails();
  }

  Future<void> _loadTripAndPaymentDetails() async {
    try {
      final tripRes = await Supabase.instance.client
          .from('trips')
          .select('*, ride_requests!inner(*), profiles!trips_driver_id_fkey(full_name)')
          .eq('id', widget.tripId)
          .single();

      final trip = Trip.fromMap(tripRes);
      final driverProfile = tripRes['profiles'] as Map<String, dynamic>?;

      if (trip.driverId == null) {
        throw Exception('Driver ID is missing for this trip.');
      }

      final paymentDetailsRes = await Supabase.instance.client
          .from('driver_payment_details')
          .select()
          .eq('id', trip.driverId!)
          .maybeSingle();

      setState(() {
        _trip = trip;
        _driverPaymentDetails = paymentDetailsRes;
        _driverName = driverProfile?['full_name'] ?? 'Your Driver';
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        CustomToast.show(context: context, message: 'Error loading payment details: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    CustomToast.show(context: context, message: '$label copied to clipboard');
  }

  Future<void> _markAsPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 12),
            const Text('Confirm Payment'),
          ],
        ),
        content: const Text(
          'Are you sure you have completed the payment to the driver? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, I Have Paid'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('trips')
          .update({'payment_status': 'paid'})
          .eq('id', widget.tripId);

      if(mounted) {
        CustomToast.show(context: context, message: 'Payment marked as complete!');
        Navigator.pop(context);
      }
    } catch (e) {
       if(mounted) {
        CustomToast.show(context: context, message: 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? _buildErrorState()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFareCard(),
                            const SizedBox(height: 16),
                            if (_driverPaymentDetails != null)
                              _buildPaymentDetailsCard()
                            else
                              _buildNoPaymentDetailsCard(),
                            const SizedBox(height: 24),
                            _buildPayButton(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Could not load payment details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.payment,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Payment to $_driverName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete your ride payment',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    final amount = _trip!.finalPrice ?? _trip!.proposedPrice;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade600,
              Colors.green.shade800,
            ],
          ),
        ),
        child: Column(
          children: [
            const Text(
              'TOTAL AMOUNT DUE',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'R${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Trip: ${_trip!.pickupAddress} to ${_trip!.dropoffAddress}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPaymentDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            const Text(
              'Payment Details Not Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'The driver has not set up payment details yet. Please pay cash directly to the driver.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    final hasBankDetails = _driverPaymentDetails!['bank_name'] != null &&
                           _driverPaymentDetails!['account_number'] != null;
    final hasMobileMoney = _driverPaymentDetails!['mobile_money_number'] != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Pay to: $_driverName',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred payment method below',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (hasBankDetails) ...[
              const SizedBox(height: 20),
              _buildPaymentMethodSection(
                icon: Icons.account_balance,
                title: 'Bank Transfer',
                color: Colors.blue.shade600,
                children: [
                  _buildDetailRow('Bank', _driverPaymentDetails!['bank_name'], copyable: true),
                  _buildDetailRow('Account No.', _driverPaymentDetails!['account_number'], copyable: true),
                  if (_driverPaymentDetails!['branch_code'] != null)
                    _buildDetailRow('Branch Code', _driverPaymentDetails!['branch_code'], copyable: true),
                ],
              ),
            ],
            if (hasMobileMoney) ...[
              const SizedBox(height: 16),
              _buildPaymentMethodSection(
                icon: Icons.phone_android,
                title: 'Mobile Money',
                color: Colors.orange.shade600,
                children: [
                  _buildDetailRow('Number', _driverPaymentDetails!['mobile_money_number'], copyable: true),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          if (copyable)
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: Colors.grey.shade600),
              onPressed: () => _copyToClipboard(value, label),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return ElevatedButton(
      onPressed: _markAsPaid,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 24),
          SizedBox(width: 12),
          Text(
            'I Have Completed Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
