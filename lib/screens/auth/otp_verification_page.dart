import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OtpVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String role;

  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    final otp = _getOtpCode();

    if (otp.length != 6) {
      CustomToast.showError(
        context: context,
        message: 'Please enter the complete 6-digit code',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'phoneNumber': widget.phoneNumber,
          'otp': otp,
          'fullName': widget.fullName,
          'role': widget.role,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final userId = responseData['userId'];
        final isNewUser = responseData['isNewUser'] ?? false;
        final role = responseData['role'];

        // Try to get the current session
        await Future.delayed(const Duration(milliseconds: 1500));
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // Save session with tokens
          await _saveSessionWithDetails(
            session,
            userId,
            widget.phoneNumber,
            role,
          );
        } else {
          // Save basic session info without tokens
          await AuthService.saveSession(
            userId: userId,
            userPhone: widget.phoneNumber,
            userRole: role,
            expiry: DateTime.now().add(const Duration(days: 30)),
            accessToken: null,
            refreshToken: null,
          );
        }

        if (mounted) {
          CustomToast.showSuccess(
            context: context,
            message: 'Welcome to AlboCarRide!',
          );

          await Future.delayed(const Duration(milliseconds: 500));
          await _navigateBasedOnUserStatus(role, userId, isNewUser);
        }
      } else {
        final errorMessage = responseData['error'] ?? 'Invalid OTP';
        final attemptsRemaining = responseData['attemptsRemaining'];

        if (mounted) {
          CustomToast.showError(
            context: context,
            message: attemptsRemaining != null
                ? '$errorMessage. $attemptsRemaining attempts remaining.'
                : errorMessage,
          );
        }

        // Clear OTP fields on error
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'Failed to verify OTP. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSessionWithDetails(
    Session session,
    String userId,
    String phoneNumber,
    String role,
  ) async {
    try {
      final expiry = session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : DateTime.now().add(const Duration(days: 30));

      await AuthService.saveSession(
        userId: userId,
        userPhone: phoneNumber,
        userRole: role,
        expiry: expiry,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
    } catch (e) {
      print('Error saving session: $e');
      // Fallback: save basic info without tokens
      await AuthService.saveSession(
        userId: userId,
        userPhone: phoneNumber,
        userRole: role,
        expiry: DateTime.now().add(const Duration(days: 30)),
        accessToken: null,
        refreshToken: null,
      );
    }
  }

  Future<void> _navigateBasedOnUserStatus(
    String role,
    String userId,
    bool isNewUser,
  ) async {
    final supabase = Supabase.instance.client;

    if (role == 'customer') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/customer_home',
        (route) => false,
      );
    } else if (role == 'driver') {
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('verification_status, drivers(vehicle_type)')
            .eq('id', userId)
            .single();

        final verificationStatus =
            profileResponse['verification_status'] as String?;
        final vehicleType =
            profileResponse['drivers']?['vehicle_type'] as String?;

        if (isNewUser) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/vehicle-type-selection',
            (route) => false,
            arguments: userId,
          );
        } else {
          if (verificationStatus == null || verificationStatus.isEmpty) {
            if (vehicleType == null || vehicleType.isEmpty) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/vehicle-type-selection',
                (route) => false,
                arguments: userId,
              );
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/verification',
                (route) => false,
              );
            }
          } else if (verificationStatus == 'pending') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/waiting-review',
              (route) => false,
            );
          } else if (verificationStatus == 'rejected') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/verification',
              (route) => false,
            );
          } else if (verificationStatus == 'approved') {
            if (vehicleType == null || vehicleType.isEmpty) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/vehicle-type-selection',
                (route) => false,
                arguments: userId,
              );
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/enhanced-driver-home',
                (route) => false,
              );
            }
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/verification',
              (route) => false,
            );
          }
        }
      } catch (e) {
        print('Error checking driver status: $e');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/vehicle-type-selection',
          (route) => false,
          arguments: userId,
        );
      }
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/role-selection',
        (route) => false,
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _secondsRemaining > 0) return;

    setState(() => _isResending = true);

    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'phoneNumber': widget.phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CustomToast.showSuccess(
            context: context,
            message: 'OTP sent successfully',
          );
        }
        _startTimer();

        // Clear existing OTP inputs
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      } else {
        if (mounted) {
          CustomToast.showError(
            context: context,
            message: 'Failed to resend OTP. Please try again.',
          );
        }
      }
    } catch (e) {
      print('Error resending OTP: $e');
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'Failed to resend OTP. Please check your connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Enter verification code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a code to ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }

                        // Auto-submit when all fields are filled
                        if (index == 5 && value.isNotEmpty) {
                          _verifyOtp();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Resend OTP
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code in $_secondsRemaining seconds',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Resend code',
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
              ),
              const Spacer(),
              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
