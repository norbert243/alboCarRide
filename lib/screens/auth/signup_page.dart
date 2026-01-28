import 'package:flutter/material.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/services/connectivity_service.dart';

/// Signup page for new users
/// Flow: Phone already verified as new → Collect name → Send OTP → Verify
class SignupPage extends StatefulWidget {
  final String role;
  final String? phone;

  const SignupPage({
    super.key,
    required this.role,
    this.phone,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  late String _phone;

  @override
  void initState() {
    super.initState();
    // Phone will be set from arguments in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get phone from arguments if not passed directly
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _phone = args['phone'] as String? ?? widget.phone ?? '';
    } else {
      _phone = widget.phone ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_phone.isEmpty) {
      CustomToast.showError(
        context: context,
        message: 'Phone number is missing. Please go back and try again.',
      );
      return;
    }

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
      // Send OTP
      final success = await AuthService.sendOtp(_phone);

      if (!mounted) return;

      if (success) {
        CustomToast.showSuccess(context: context, message: 'OTP sent to $_phone');

        // Navigate to OTP verification
        Navigator.pushNamed(
          context,
          '/otp-verify',
          arguments: {
            'phone': _phone,
            'isLogin': false,
            'fullName': _fullNameController.text.trim(),
            'role': widget.role,
          },
        );
      } else {
        CustomToast.showError(
          context: context,
          message: 'Failed to send OTP. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'An error occurred: ${e.toString()}',
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
    // Get role from arguments if needed
    final args = ModalRoute.of(context)?.settings.arguments;
    final role = args is Map<String, dynamic>
        ? (args['role'] as String? ?? widget.role)
        : widget.role;

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
                _buildTitle(role),
                const SizedBox(height: 8),
                _buildPhoneInfo(),
                const SizedBox(height: 24),
                _buildNameInput(),
                const SizedBox(height: 32),
                _buildContinueButton(),
                const SizedBox(height: 16),
                _buildBackButton(),
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
          'Create Account',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ],
    );
  }

  Widget _buildTitle(String role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your name?",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: role == 'driver'
                ? AppTheme.secondaryColor.withOpacity(0.1)
                : AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                role == 'driver' ? Icons.drive_eta : Icons.person,
                size: 16,
                color: role == 'driver'
                    ? AppTheme.secondaryColor
                    : AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Signing up as ${role == 'driver' ? 'Driver' : 'Customer'}',
                style: TextStyle(
                  color: role == 'driver'
                      ? AppTheme.secondaryColor
                      : AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            _phone.isNotEmpty ? _phone : 'No phone number',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return TextFormField(
      controller: _fullNameController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.person_outline),
        hintText: 'Enter your full name',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your name';
        }
        if (value.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        if (value.trim().length > 100) {
          return 'Name must be less than 100 characters';
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
                'Continue & Send OTP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Change role'),
      ),
    );
  }
}
