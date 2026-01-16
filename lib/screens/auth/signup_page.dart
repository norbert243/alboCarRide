import 'package:flutter/material.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/auth_service.dart';

class SignupPage extends StatefulWidget {
  final String role;

  const SignupPage({super.key, required this.role});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (!_otpSent) {
        final success = await AuthService.sendOtp(_phoneController.text);
        if (success) {
          setState(() => _otpSent = true);
          CustomToast.showSuccess(context: context, message: 'OTP sent to your phone!');
        } else {
          CustomToast.showError(context: context, message: 'Failed to send OTP. Please try again.');
        }
      } else {
        final user = await AuthService.verifyOtpAndSignUp(
          phone: _phoneController.text,
          otp: _otpController.text,
          fullName: _fullNameController.text,
          role: widget.role,
        );

        if (user != null && mounted) {
          CustomToast.showSuccess(context: context, message: 'Welcome to AlboCarRide!');
          // Navigate to the appropriate screen based on role
          if (widget.role == 'driver') {
            Navigator.pushNamedAndRemoveUntil(context, '/vehicle-type-selection', (route) => false, arguments: user.id);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, '/customer_home', (route) => false);
          }
        } else if (mounted) {
          CustomToast.showError(context: context, message: 'Invalid OTP or registration failed.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context: context, message: 'An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                Text(
                  'Create your ${widget.role} account',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                _buildFormFields(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Text(
          'Sign Up',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline),
            hintText: 'Full Name',
          ),
          validator: (value) => value!.isEmpty ? 'Please enter your full name' : null,
          enabled: !_otpSent,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.phone_outlined),
            hintText: 'Phone Number',
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your phone number';
            if (!value.startsWith('+')) return 'Include country code (e.g., +27...)';
            return null;
          },
          enabled: !_otpSent,
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
              hintText: 'Enter OTP',
            ),
            keyboardType: TextInputType.number,
            validator: (value) => value!.isEmpty ? 'Please enter the OTP' : null,
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Text(_otpSent ? 'Verify & Sign Up' : 'Send OTP'),
          ),
        ),
        if (_otpSent)
          TextButton(
            onPressed: _isLoading ? null : () => setState(() => _otpSent = false),
            child: const Text('Change Phone Number'),
          ),
      ],
    );
  }
}
