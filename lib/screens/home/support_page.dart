import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  String? _customerId;
  String? _customerName;
  String? _customerEmail;
  String? _customerPhone;
  String _selectedIssueType = 'General Inquiry';

  // Formspree endpoint - Replace with your actual Formspree form ID
  // Format: https://formspree.io/f/YOUR_FORM_ID
  static const String _formspreeEndpoint = 'https://formspree.io/f/xdkpangw';

  final List<String> _issueTypes = [
    'General Inquiry',
    'App Crash/Technical Issue',
    'Booking Problem',
    'Payment Issue',
    'Driver Issue',
    'Account Problem',
    'Feature Request',
    'Safety Concern',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerInfo() async {
    try {
      _customerId = await SessionService.getUserIdStatic();

      if (_customerId != null) {
        // Try to load from profiles table
        try {
          final response = await Supabase.instance.client
              .from('profiles')
              .select('full_name, phone, email')
              .eq('id', _customerId!)
              .single();

          setState(() {
            _customerName = response['full_name'] ?? '';
            _customerPhone = response['phone'];
            _customerEmail = response['email'];
            _nameController.text = _customerName ?? '';
            _emailController.text = _customerEmail ?? '';
          });
        } catch (e) {
          print('Error loading from profiles: $e');
        }

        // Fallback: Try to get email from auth user if not in profiles
        if (_customerEmail == null || _customerEmail!.isEmpty) {
          try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null && user.email != null) {
              setState(() {
                _customerEmail = user.email;
                _emailController.text = _customerEmail!;
              });
            }
          } catch (e) {
            print('Error loading from auth user: $e');
          }
        }
      }
    } catch (e) {
      print('Error loading customer info: $e');
      // Even if we can't load user info, the form should still work
    }
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Prepare the data to send to Formspree
      final formData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'issueType': _selectedIssueType,
        'message': _messageController.text.trim(),
        'userId': _customerId ?? 'unknown',
        'phone': _customerPhone ?? 'not provided',
        'timestamp': DateTime.now().toIso8601String(),
        'platform': 'mobile_app',
      };

      // Send request to Formspree with timeout and retry logic
      final response = await _sendToFormspree(formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Support request submitted successfully! We\'ll get back to you soon.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          // Clear form
          _messageController.clear();
          setState(() {
            _selectedIssueType = 'General Inquiry';
          });
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // Network error
      if (mounted) {
        _showErrorDialog(
          'Network Error',
          'Unable to connect to the server. Please check your internet connection and try again.',
          showRetry: true,
        );
      }
      print('Network error submitting support request: $e');
    } on Exception catch (e) {
      // Other errors
      if (mounted) {
        _showErrorDialog(
          'Submission Failed',
          'We couldn\'t submit your request right now. Please try again or contact us directly at support@albocarride.com',
          showRetry: true,
        );
      }
      print('Error submitting support request: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sends data to Formspree with timeout and proper error handling
  Future<http.Response> _sendToFormspree(Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse(_formspreeEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(data),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      return response;
    } catch (e) {
      print('Formspree submission error: $e');
      rethrow;
    }
  }

  /// Shows an error dialog with optional retry functionality
  void _showErrorDialog(String title, String message, {bool showRetry = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          if (showRetry)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _submitSupportRequest();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchEmail(String email) async {
    final url = 'mailto:$email?subject=AlboCarRide Support';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: TextStyle(color: Colors.grey[700])),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Support',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Contact Options
            const Text(
              'Quick Contact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildContactOption(
              icon: Icons.phone,
              title: 'Call Support',
              subtitle: 'Speak directly with our team',
              color: Colors.green,
              onTap: () => _launchPhone('+1-800-ALBO-RIDE'),
            ),

            _buildContactOption(
              icon: Icons.email,
              title: 'Email Support',
              subtitle: 'Send us an email',
              color: Colors.blue,
              onTap: () => _launchEmail('support@albocarride.com'),
            ),

            _buildContactOption(
              icon: Icons.chat,
              title: 'Live Chat',
              subtitle: 'Chat with support agent',
              color: Colors.orange,
              onTap: () {
                // In a real app, this would open a chat interface
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live chat feature coming soon!'),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Support Request Form
            const Text(
              'Submit Support Request',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Enter your full name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      hintText: 'your.email@example.com',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      // Basic email validation
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Issue Type Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedIssueType,
                    decoration: const InputDecoration(
                      labelText: 'Issue Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _issueTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedIssueType = newValue;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an issue type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Message Field
                  TextFormField(
                    controller: _messageController,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Message / Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      hintText: 'Please describe your issue or question in detail...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.trim().length < 20) {
                        return 'Please provide more details (at least 20 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitSupportRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Support Request',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Info text
                  Text(
                    'We typically respond within 24 hours',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildFaqItem(
              'How do I book a ride?',
              'Go to the Book Ride page, enter your pickup and dropoff locations, and confirm your ride request. Drivers will be notified and can accept your request.',
            ),

            _buildFaqItem(
              'How is the fare calculated?',
              'Fares are calculated based on distance, time, and base fare. You can see the estimated fare before confirming your ride.',
            ),

            _buildFaqItem(
              'What payment methods are accepted?',
              'We accept credit/debit cards through our secure payment system. You can save payment methods for faster checkout.',
            ),

            _buildFaqItem(
              'How do I cancel a ride?',
              'You can cancel a ride from the active ride screen. Cancellation fees may apply depending on when you cancel.',
            ),

            _buildFaqItem(
              'What if I have issues with my driver?',
              'Contact support immediately. We take all reports seriously and will investigate any issues with drivers.',
            ),

            const SizedBox(height: 40),

            // Emergency Contact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For emergencies, please contact local authorities immediately.',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _launchPhone('911'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Call Emergency Services'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
