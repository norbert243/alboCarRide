
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/auth_service.dart';
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

      String userId;
      bool isNewUser = false;

      try {
        // Try to sign up new user
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
          userId = authResponse.user!.id;
          isNewUser = true;
          print('New user created with ID: $userId');
        } else {
          throw Exception('User creation failed - authResponse.user is null');
        }
      } catch (signUpError) {
        // If user already exists, try to sign in
        if (signUpError.toString().contains('user_already_exists') ||
            signUpError.toString().contains('already registered')) {
          print('User already exists, attempting to sign in...');

          try {
            final signInResponse = await Supabase.instance.client.auth
                .signInWithPassword(email: email, password: password);

            if (signInResponse.user != null) {
              userId = signInResponse.user!.id;
              isNewUser = false;
              print('Existing user signed in with ID: $userId');
            } else {
              throw Exception('Sign in failed - user is null');
            }
          } catch (signInError) {
            // If sign in fails, try with a default password
            print('Sign in failed, trying with default password...');

            try {
              final defaultSignInResponse = await Supabase.instance.client.auth
                  .signInWithPassword(
                    email: email,
                    password:
                        'Alb0CarRide123', // Default password for existing users
                  );

              if (defaultSignInResponse.user != null) {
                userId = defaultSignInResponse.user!.id;
                isNewUser = false;
                print(
                  'Existing user signed in with default password, ID: $userId',
                );
              } else {
                throw Exception('Default password sign in failed');
              }
            } catch (defaultError) {
              // If all else fails, create a new user with different email
              print(
                'All sign in attempts failed, creating new user with modified email...',
              );

              final modifiedEmail =
                  '${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}@albocarride.com';
              final authResponse = await Supabase.instance.client.auth.signUp(
                email: modifiedEmail,
                password: password,
                data: {
                  'phone': phoneNumber,
                  'full_name': fullName,
                  'role': widget.role,
                },
              );

              if (authResponse.user != null) {
                userId = authResponse.user!.id;
                isNewUser = true;
                print('New user created with modified email, ID: $userId');
              } else {
                throw Exception('Modified email user creation failed');
              }
            }
          }
        } else {
          // Re-throw other errors
          rethrow;
        }
      }

      // Save user profile to profiles table using UPSERT to prevent duplicate key errors
      try {
        final profileResponse = await _createOrUpdateProfile(
          userId: userId,
          phone: phoneNumber,
          fullName: fullName,
          role: widget.role,
        );

        print('Profile created/updated successfully: $profileResponse');

        // Create driver-specific record if role is driver using UPSERT
        if (widget.role == 'driver') {
          try {
            final driverResponse = await _createOrUpdateDriver(userId: userId);

            print(
              'Driver record created/updated successfully: $driverResponse',
            );
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

        // Create customer-specific record if role is customer using UPSERT
        if (widget.role == 'customer') {
          try {
            final customerResponse = await _createOrUpdateCustomer(
              userId: userId,
            );

            print(
              'Customer record created/updated successfully: $customerResponse',
            );
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
                'User ${isNewUser ? 'created' : 'signed in'} but profile setup incomplete. Please complete your profile later.',
          );
        }
      }

      // Save session to persistent storage using AuthService
      // WhatsApp-style: Wait longer for Supabase to establish the session properly
      await Future.delayed(const Duration(milliseconds: 1500));

      final session = Supabase.instance.client.auth.currentSession;
      print(
        'SignupPage: Current session: ${session != null ? "Exists" : "Null"}',
      );

      if (session == null) {
        // Try to get the session again after a longer delay
        print('SignupPage: Session is null, waiting and retrying...');
        // WhatsApp-style: Longer delay for session establishment
        await Future.delayed(const Duration(milliseconds: 2000));
        final retrySession = Supabase.instance.client.auth.currentSession;
        print(
          'SignupPage: Retry session: ${retrySession != null ? "Exists" : "Null"}',
        );

        if (retrySession != null) {
          await _saveSessionWithDetails(
            retrySession,
            userId,
            phoneNumber,
            widget.role,
          );
        } else {
          print('SignupPage: Still no session available after retry');
          // Even if no session, save basic user info for future reference
          // Create a minimal session object for storage
          final minimalSession = Session(
            accessToken: '',
            refreshToken: '',
            expiresIn: 2592000, // 30 days
            tokenType: 'bearer',
            user: User(
              id: userId,
              appMetadata: {},
              userMetadata: {
                'phone': phoneNumber,
                'role': widget.role,
              },
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          await AuthService.saveSession(minimalSession);
          print('SignupPage: Basic session info saved without tokens');
        }
      } else {
        await _saveSessionWithDetails(
          session,
          userId,
          phoneNumber,
          widget.role,
        );
      }

      if (mounted) {
        print(
          'Navigating based on user status: isNewUser=$isNewUser, role=${widget.role}',
        );

        // WhatsApp-style: Show success message before navigation
        CustomToast.showSuccess(
          context: context,
          message: 'Welcome to AlboCarRide!',
        );

        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Brief delay for UX
        await _navigateBasedOnUserStatus(widget.role, userId, isNewUser);
      }
    } catch (e) {
      print('Error in completeRegistration: $e');
      CustomToast.showError(
        context: context,
        message: 'Error during registration: ${e.toString()}',
      );
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

      print('SignupPage: Saving session for user: $userId, role: $role');
      print('SignupPage: Access token exists: ${session.accessToken != null}');
      print(
        'SignupPage: Refresh token exists: ${session.refreshToken != null}',
      );

      await AuthService.saveSession(session);
      print('SignupPage: Session saved to local storage using AuthService');
    } catch (e) {
      print('SignupPage: Error saving session: $e');
      // Fallback: save basic info without tokens
      // Create a minimal session object for storage
      final minimalSession = Session(
        accessToken: '',
        refreshToken: '',
        expiresIn: 2592000, // 30 days
        tokenType: 'bearer',
        user: User(
          id: userId,
          appMetadata: {},
          userMetadata: {
            'phone': phoneNumber,
            'role': role,
          },
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await AuthService.saveSession(minimalSession);
      print('SignupPage: Basic session info saved as fallback');
    }
  }

  Future<void> _navigateBasedOnUserStatus(
    String role,
    String userId,
    bool isNewUser,
  ) async {
    final supabase = Supabase.instance.client;

    if (role == 'customer') {
      // For customers, always go to customer home
      Navigator.pushNamed(context, '/customer_home');
    } else if (role == 'driver') {
      // For drivers, check their current verification status
      try {
        // Get the current profile to check verification status
        final profileResponse = await supabase
            .from('profiles')
            .select('verification_status')
            .eq('id', userId)
            .single();

        // Get driver vehicle type separately
        final driverResponse = await supabase
            .from('drivers')
            .select('vehicle_type')
            .eq('id', userId)
            .maybeSingle();

        final verificationStatus =
            profileResponse['verification_status'] as String?;
        final vehicleType =
            driverResponse?['vehicle_type'] as String?;

        print('Driver navigation debug:');
        print('  isNewUser: $isNewUser');
        print('  verificationStatus: $verificationStatus');
        print('  vehicleType: $vehicleType');

        // Handle navigation based on verification status and vehicle type
        if (isNewUser) {
          // New driver - start with vehicle type selection
          print('  Routing new driver to vehicle type selection');
          Navigator.pushNamed(
            context,
            '/vehicle-type-selection',
            arguments: userId,
          );
        } else {
          // Existing driver - check what step they need to complete
          if (verificationStatus == null || verificationStatus.isEmpty) {
            // No verification status set - check vehicle type
            if (vehicleType == null || vehicleType.isEmpty) {
              // No vehicle type set - go to vehicle selection
              print('  Routing existing driver to vehicle type selection');
              Navigator.pushNamed(
                context,
                '/vehicle-type-selection',
                arguments: userId,
              );
            } else {
              // Vehicle type set but no verification - go to verification
              print('  Routing existing driver to verification');
              Navigator.pushNamed(context, '/verification');
            }
          } else if (verificationStatus == 'pending') {
            // Verification pending - go to waiting review
            print('  Routing existing driver to waiting review');
            Navigator.pushNamed(context, '/waiting-review');
          } else if (verificationStatus == 'rejected') {
            // Verification rejected - go to verification to resubmit
            print('  Routing existing driver to verification (rejected)');
            Navigator.pushNamed(context, '/verification');
          } else if (verificationStatus == 'approved') {
            // Verification approved - check vehicle type
            if (vehicleType == null || vehicleType.isEmpty) {
              // Approved but no vehicle type - go to vehicle selection
              print(
                '  Routing existing driver to vehicle type selection (approved)',
              );
              Navigator.pushNamed(
                context,
                '/vehicle-type-selection',
                arguments: userId,
              );
            } else {
              // Everything complete - go to driver home
              print('  Routing existing driver to driver home');
              Navigator.pushNamed(context, '/enhanced-driver-home');
            }
          } else {
            // Unknown status - default to verification
            print('  Routing existing driver to verification (unknown status)');
            Navigator.pushNamed(context, '/verification');
          }
        }
      } catch (e) {
        print('Error checking driver status: $e');
        // Fallback to vehicle type selection
        Navigator.pushNamed(
          context,
          '/vehicle-type-selection',
          arguments: userId,
        );
      }
    } else {
      // Fallback to role selection if role is invalid
      Navigator.pushNamed(context, '/role-selection');
    }
  }

  Future<Map<String, dynamic>> _createOrUpdateProfile({
    required String userId,
    required String phone,
    required String fullName,
    required String role,
  }) async {
    final supabase = Supabase.instance.client;

    final payload = {
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'updated_at': DateTime.now().toIso8601String(),
      // Don't set verification_status initially - let it be null
      // This allows the user to go through the proper flow
    };

    try {
      final response = await supabase.from('profiles').upsert(payload).select();

      if (response.isEmpty) {
        throw Exception('Failed to create/update profile: No data returned');
      }

      return response.first;
    } catch (e) {
      throw Exception('Failed to create/update profile: $e');
    }
  }

  Future<Map<String, dynamic>> _createOrUpdateDriver({
    required String userId,
  }) async {
    final supabase = Supabase.instance.client;

    final payload = {
      'id': userId,
      'is_approved': false,
      'is_online': false,
      'rating': 0.0,
      'total_rides': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await supabase.from('drivers').upsert(payload).select();

      if (response.isEmpty) {
        throw Exception(
          'Failed to create/update driver record: No data returned',
        );
      }

      return response.first;
    } catch (e) {
      throw Exception('Failed to create/update driver record: $e');
    }
  }

  Future<Map<String, dynamic>> _createOrUpdateCustomer({
    required String userId,
  }) async {
    final supabase = Supabase.instance.client;

    final payload = {
      'id': userId,
      'preferred_payment_method': 'cash',
      'rating': 0.0,
      'total_rides': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await supabase
          .from('customers')
          .upsert(payload)
          .select();

      if (response.isEmpty) {
        throw Exception(
          'Failed to create/update customer record: No data returned',
        );
      }

      return response.first;
    } catch (e) {
      throw Exception('Failed to create/update customer record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building SignupPage widget tree');
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sign Up as ${widget.role[0].toUpperCase()}${widget.role.substring(1)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const SizedBox(height: 20),
                  Text(
                    'Join AlboCarRide as a ${widget.role}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your details to get started',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+27XXXXXXXXX',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (!value.startsWith('+')) {
                        return 'Please include country code (e.g., +27XXXXXXXXX)';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_otpSent) ...[
                    TextFormField(
                      controller: _otpController,
                      decoration: const InputDecoration(
                        labelText: 'Enter OTP',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the OTP';
                        }
                        if (value.length != 6) {
                          return 'OTP must be 6 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_otpSent) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'We\'ll send you a verification code to confirm your phone number',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _otpSent ? 'Verify & Sign Up' : 'Send OTP',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                              _otpSent = false;
                              _otpController.clear();
                            }),
                      child: const Text(
                        'Change Phone Number',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
