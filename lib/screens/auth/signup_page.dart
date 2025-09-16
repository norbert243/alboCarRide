import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/driver_home_page.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/twilio/twilio_service.dart';

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

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  bool _otpSent = false;
  String? _generatedOtp;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (!_otpSent) {
        // Send OTP for verification
        final phoneNumber = _phoneController.text;
        _generatedOtp = TwilioService.generateOTP();

        final otpSent = await TwilioService.sendOTP(
          phoneNumber: phoneNumber,
          otp: _generatedOtp!,
        );

        if (otpSent) {
          setState(() => _otpSent = true);
          CustomToast.showSuccess(
            context: context,
            message: 'OTP sent to your phone number',
          );
        } else {
          CustomToast.showError(
            context: context,
            message: 'Failed to send OTP. Please try again.',
          );
        }
      } else {
        // Verify OTP and complete registration
        final enteredOtp = _otpController.text;
        if (enteredOtp == _generatedOtp) {
          await _completeRegistration();
        } else {
          CustomToast.showError(
            context: context,
            message: 'Invalid OTP. Please try again.',
          );
        }
      }
    } catch (error) {
      print('Unexpected error: $error');
      CustomToast.showError(
        context: context,
        message: 'An unexpected error occurred: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeRegistration() async {
    try {
      // Generate a unique user ID and email for Supabase (since we need email for auth)
      final phoneNumber = _phoneController.text;
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final dummyEmail = '$userId@albocarride.com';
      final dummyPassword =
          'Alb0CarRide${DateTime.now().millisecondsSinceEpoch}';

      // Create user in Supabase with dummy credentials
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: dummyEmail,
        password: dummyPassword,
      );

      if (authResponse.user != null) {
        // Save user profile to profiles table
        await Supabase.instance.client.from('profiles').insert({
          'id': authResponse.user!.id,
          'full_name': _fullNameController.text,
          'phone': phoneNumber,
          'role': widget.role,
        });

        print('Profile created successfully for role: ${widget.role}');

        // Save session to persistent storage
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final expiry = session.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
              : DateTime.now().add(const Duration(days: 30));

          await SessionService.saveSession(
            userId: authResponse.user!.id,
            userPhone: phoneNumber,
            userRole: widget.role,
            expiry: expiry,
          );
        }

        if (mounted) {
          _navigateBasedOnRole(widget.role);
        }
      }
    } catch (e) {
      print('Error creating profile: $e');
      CustomToast.showError(
        context: context,
        message: 'Error creating profile. Please try again.',
      );
    }
  }

  void _navigateBasedOnRole(String role) {
    if (role == 'customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerHomePage()),
      );
    } else if (role == 'driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomePage()),
      );
    } else {
      // Fallback to role selection if role is invalid
      Navigator.pushReplacementNamed(context, '/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Sign Up as ${widget.role.capitalize()}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const SizedBox(height: 20),
              Text(
                'Create Account',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Join AlboCarRide as a ${widget.role}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Form Fields
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              if (_otpSent) ...[
                _buildTextField(
                  controller: _otpController,
                  label: 'Verification Code',
                  icon: Icons.sms_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length != 6) {
                      return 'Verification code must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              if (!_otpSent) ...[
                const SizedBox(height: 8),
                Text(
                  'We\'ll send a verification code to your phone',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to your phone',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ],

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _otpSent
                            ? 'Verify & Continue'
                            : 'Send Verification Code',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              if (_otpSent) ...[
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _otpSent = false;
                          _otpController.clear();
                        }),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                  child: const Text(
                    'Change phone number',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
