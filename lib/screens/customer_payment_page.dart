import 'package:flutter/material.dart';
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
      
      if (trip.driverId == null) {
        throw Exception('Driver ID is missing for this trip.');
      }

      final paymentDetailsRes = await Supabase.instance.client
          .from('driver_payment_details')
          .select()
          .eq('id', trip.driverId!)
          .single();

      setState(() {
        _trip = trip;
        _driverPaymentDetails = paymentDetailsRes;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        CustomToast.show(context: context, message: 'Error loading payment details: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsPaid() async {
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
      appBar: AppBar(title: const Text('Complete Your Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null || _driverPaymentDetails == null
              ? const Center(child: Text('Could not load payment details.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFareCard(),
                      const SizedBox(height: 24),
                      _buildPaymentDetailsCard(),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _markAsPaid,
                        child: const Text('I Have Paid'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFareCard() {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Total Fare', style: AppTheme.theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'R${_trip!.finalPrice?.toStringAsFixed(2) ?? _trip!.proposedPrice.toStringAsFixed(2)}',
              style: AppTheme.theme.textTheme.displayLarge?.copyWith(color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay to Driver:', style: AppTheme.theme.textTheme.displayMedium),
            const SizedBox(height: 16),
            if(_driverPaymentDetails!['bank_name'] != null && _driverPaymentDetails!['account_number'] != null)
              ..._buildBankDetails(),
            if(_driverPaymentDetails!['mobile_money_number'] != null)
              ..._buildMobileMoneyDetails(),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildBankDetails() {
    return [
      const Divider(),
      Text('Bank Transfer', style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ListTile(
        leading: const Icon(Icons.account_balance),
        title: const Text('Bank Name'),
        subtitle: Text(_driverPaymentDetails!['bank_name']),
      ),
      ListTile(
        leading: const Icon(Icons.pin),
        title: const Text('Account Number'),
        subtitle: Text(_driverPaymentDetails!['account_number']),
      ),
       if(_driverPaymentDetails!['branch_code'] != null)
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Branch Code'),
          subtitle: Text(_driverPaymentDetails!['branch_code']),
        ),
    ];
  }
  
  List<Widget> _buildMobileMoneyDetails() {
    return [
      const Divider(),
      Text('Mobile Money', style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
       ListTile(
        leading: const Icon(Icons.phone_android),
        title: const Text('Mobile Money Number'),
        subtitle: Text(_driverPaymentDetails!['mobile_money_number']),
      ),
    ];
  }
}
