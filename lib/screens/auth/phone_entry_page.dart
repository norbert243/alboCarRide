import 'package:flutter/material.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/services/connectivity_service.dart';

/// Phone-first entry page - the starting point of authentication
/// Flow:
/// 1. User enters phone number
/// 2. We check if phone exists in database
/// 3. If exists → go to OTP verification (login)
/// 4. If not exists → go to signup page to collect name/role
class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    // Check connectivity
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'No internet connection. Please check your network.',
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();

      // Step 1: Check if phone exists
      final result = await AuthService.checkPhoneExists(phone);

      if (!mounted) return;

      if (result.exists) {
        // Existing user - send OTP and go to login verification
        final otpSent = await AuthService.sendOtp(phone);

        if (!mounted) return;

        if (otpSent) {
          CustomToast.showSuccess(
            context: context,
            message: 'Welcome back, ${result.fullName}! OTP sent.',
          );

          // Navigate to OTP verification for login
          Navigator.pushNamed(
            context,
            '/otp-verify',
            arguments: {
              'phone': phone,
              'isLogin': true,
              'fullName': result.fullName,
              'role': result.role,
            },
          );
        } else {
          CustomToast.showError(
            context: context,
            message: 'Failed to send OTP. Please try again.',
          );
        }
      } else {
        // New user - go to role selection, then signup
        Navigator.pushNamed(
          context,
          '/role-selection',
          arguments: {'phone': phone},
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'An error occurred. Please try again.',
        );
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildPhoneInput(),
                  const SizedBox(height: 32),
                  _buildContinueButton(),
                  const SizedBox(height: 16),
                  _buildTermsText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.directions_car_filled,
          size: 64,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'AlboCarRide',
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Your ride, your way.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        Text(
          'Enter your phone number to get started',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.phone_outlined),
        hintText: 'Phone Number (e.g., +27123456789)',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned)) {
          return 'Please enter a valid phone number';
        }
        if (!value.startsWith('+')) {
          return 'Include country code (e.g., +27...)';
        }
        return null;
      },
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _continue,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Text(
      'By continuing, you agree to our Terms of Service and Privacy Policy',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
      textAlign: TextAlign.center,
    );
  }
}
