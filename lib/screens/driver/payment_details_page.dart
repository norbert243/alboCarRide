import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class PaymentDetailsPage extends StatefulWidget {
  const PaymentDetailsPage({super.key});

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _mobileMoneyController = TextEditingController();

  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    if (_userId == null) {
      if (mounted) {
        CustomToast.show(context: context, message: 'You are not logged in.');
        setState(() => _isLoading = false);
      }
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('driver_payment_details')
          .select()
          .eq('id', _userId!)
          .single();
      
      _bankNameController.text = response['bank_name'] ?? '';
      _accountNumberController.text = response['account_number'] ?? '';
      _branchCodeController.text = response['branch_code'] ?? '';
      _mobileMoneyController.text = response['mobile_money_number'] ?? '';

    } catch (e) {
      // It's okay if it fails, it might be the first time.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePaymentDetails() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        if (_userId == null) {
          throw Exception('You are not logged in.');
        }
        
        await Supabase.instance.client.from('driver_payment_details').upsert({
          'id': _userId!,
          'bank_name': _bankNameController.text,
          'account_number': _accountNumberController.text,
          'branch_code': _branchCodeController.text,
          'mobile_money_number': _mobileMoneyController.text,
        });

        if(mounted) {
          CustomToast.show(context: context, message: 'Payment details saved!');
        }

      } catch (e) {
        if (mounted) {
          CustomToast.show(context: context, message: 'Error saving details: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(labelText: 'Bank Name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(labelText: 'Account Number'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _branchCodeController,
                      decoration: const InputDecoration(labelText: 'Branch Code'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileMoneyController,
                      decoration: const InputDecoration(labelText: 'Mobile Money Number'),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _savePaymentDetails,
                      child: const Text('Save Details'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
