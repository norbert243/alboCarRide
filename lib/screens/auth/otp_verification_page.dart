import 'dart:async';
import 'package:flutter/material.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/services/connectivity_service.dart';

/// OTP Verification Page
/// Handles both login (existing users) and signup (new users) OTP verification
class OtpVerificationPage extends StatefulWidget {
  final String phone;
  final bool isLogin;
  final String? fullName;
  final String? role;

  const OtpVerificationPage({
    super.key,
    required this.phone,
    required this.isLogin,
    this.fullName,
    this.role,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _remainingTime = 300; // 5 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = await AuthService.getOtpRemainingTime();
      if (mounted) {
        setState(() => _remainingTime = remaining);
        if (remaining <= 0) {
          timer.cancel();
        }
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      final success = await AuthService.resendOtp(widget.phone);

      if (!mounted) return;

      if (success) {
        CustomToast.showSuccess(context: context, message: 'New OTP sent!');
        setState(() => _remainingTime = 300);
        _startCountdown();
      } else {
        CustomToast.showError(
          context: context,
          message: 'Failed to resend OTP. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
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
      final otp = _otpController.text.trim();

      if (widget.isLogin) {
        // Login flow - existing user
        final result = await AuthService.loginWithOtp(
          phone: widget.phone,
          otp: otp,
        );

        if (!mounted) return;

        if (result.success && result.user != null) {
          CustomToast.showSuccess(
            context: context,
            message: 'Welcome back!',
          );

          // Navigate based on role
          if (widget.role == 'driver') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/enhanced-driver-home',
              (route) => false,
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/customer_home',
              (route) => false,
            );
          }
        } else {
          CustomToast.showError(
            context: context,
            message: result.error ?? 'Login failed. Please try again.',
          );
        }
      } else {
        // Signup flow - new user
        final result = await AuthService.signUpWithOtp(
          phone: widget.phone,
          otp: otp,
          fullName: widget.fullName!,
          role: widget.role!,
        );

        if (!mounted) return;

        if (result.success && result.user != null) {
          CustomToast.showSuccess(
            context: context,
            message: 'Welcome to AlboCarRide!',
          );

          // Navigate based on role
          if (widget.role == 'driver') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/vehicle-type-selection',
              (route) => false,
              arguments: {
                'driverId': result.user!.id,
                'fullName': widget.fullName,
                'phone': widget.phone,
              },
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/customer_home',
              (route) => false,
            );
          }
        } else {
          CustomToast.showError(
            context: context,
            message: result.error ?? 'Signup failed. Please try again.',
          );
        }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildInfoSection(),
                const SizedBox(height: 24),
                _buildOtpInput(),
                const SizedBox(height: 16),
                _buildTimer(),
                const SizedBox(height: 32),
                _buildVerifyButton(),
                const SizedBox(height: 16),
                _buildResendButton(),
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
          'Verify OTP',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isLogin ? 'Welcome back!' : 'Almost there!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (widget.isLogin && widget.fullName != null)
          Text(
            'Hi ${widget.fullName},',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryColor,
                ),
          ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge,
            children: [
              const TextSpan(text: 'Enter the 6-digit code sent to '),
              TextSpan(
                text: widget.phone,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return TextFormField(
      controller: _otpController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline),
        hintText: 'Enter 6-digit OTP',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        counterText: '',
      ),
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        letterSpacing: 8,
        fontWeight: FontWeight.bold,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the OTP';
        }
        if (value.length < 6) {
          return 'OTP must be 6 digits';
        }
        if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
          return 'OTP must contain only numbers';
        }
        return null;
      },
    );
  }

  Widget _buildTimer() {
    final isExpired = _remainingTime <= 0;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isExpired ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpired ? Icons.timer_off : Icons.timer_outlined,
              size: 18,
              color: isExpired ? Colors.red : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              isExpired ? 'OTP Expired' : 'Expires in ${_formatTime(_remainingTime)}',
              style: TextStyle(
                color: isExpired ? Colors.red : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOtp,
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
            : Text(
                widget.isLogin ? 'Verify & Login' : 'Verify & Create Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildResendButton() {
    return Center(
      child: TextButton(
        onPressed: _isResending ? null : _resendOtp,
        child: _isResending
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                "Didn't receive code? Resend OTP",
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
