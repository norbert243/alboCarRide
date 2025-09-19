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
      final phoneNumber = _phoneController.text;
      final fullName = _fullNameController.text;

      // Create a proper email based on phone number for authentication
      final email = '$phoneNumber@albocarride.com';
      final password = 'Alb0CarRide${DateTime.now().millisecondsSinceEpoch}';

      print('Creating user with email: $email');
      print('User role: ${widget.role}');

      // Create user in Supabase with proper credentials
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'phone': phoneNumber,
          'full_name': fullName,
          'role': widget.role,
        },
      );

      print(
        'Auth response: ${authResponse.user != null ? "Success" : "Failed"}',
      );

      if (authResponse.user != null) {
        print('User created with ID: ${authResponse.user!.id}');

        // Save user profile to profiles table
        try {
          final profileResponse =
              await Supabase.instance.client.from('profiles').insert({
                'id': authResponse.user!.id,
                'full_name': fullName,
                'phone': phoneNumber,
                'role': widget.role,
              }).select();

          print('Profile created successfully: $profileResponse');

          // Create driver-specific record if role is driver
          if (widget.role == 'driver') {
            try {
              final driverResponse =
                  await Supabase.instance.client.from('drivers').insert({
                    'id': authResponse.user!.id,
                    'is_approved': false,
                    'is_online': false,
                    'rating': 0.0,
                    'total_rides': 0,
                  }).select();

              print('Driver record created successfully: $driverResponse');
            } catch (driverError) {
              print('Error creating driver record: $driverError');
              if (mounted) {
                CustomToast.showInfo(
                  context: context,
                  message:
                      'Profile created but driver setup incomplete. Please complete your driver profile later.',
                );
              }
            }
          }

          // Create customer-specific record if role is customer
          if (widget.role == 'customer') {
            try {
              final customerResponse =
                  await Supabase.instance.client.from('customers').insert({
                    'id': authResponse.user!.id,
                    'preferred_payment_method': 'cash',
                    'rating': 0.0,
                    'total_rides': 0,
                  }).select();

              print('Customer record created successfully: $customerResponse');
            } catch (customerError) {
              print('Error creating customer record: $customerError');
              if (mounted) {
                CustomToast.showInfo(
                  context: context,
                  message:
                      'Profile created but customer setup incomplete. Please complete your customer profile later.',
                );
              }
            }
          }
        } catch (profileError) {
          print('Error creating profile: $profileError');
          // Show warning but continue - user can complete profile later
          if (mounted) {
            CustomToast.showInfo(
              context: context,
              message:
                  'User created but profile setup incomplete. Please complete your profile later.',
            );
          }
        }

        // Save session to persistent storage
        final session = Supabase.instance.client.auth.currentSession;
        print('Current session: ${session != null ? "Exists" : "Null"}');

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
          print('Session saved to local storage');
        }

        if (mounted) {
          print('Navigating to ${widget.role} homepage');
          _navigateBasedOnRole(widget.role);
        }
      } else {
        print('User creation failed - authResponse.user is null');
        CustomToast.showError(
          context: context,
          message: 'Registration failed. Please try again.',
        );
      }
    } catch (e) {
      print('Error in completeRegistration: $e');
      CustomToast.showError(
        context: context,
        message: 'Error creating profile: ${e.toString()}',
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
