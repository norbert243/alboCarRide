import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  String? _customerId;
  String? _customerName;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerInfo() async {
    try {
      _customerId = await SessionService.getUserId();

      if (_customerId != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', _customerId!)
            .single();

        if (response != null) {
          setState(() {
            _customerName = response['full_name'];
          });
        }
      }
    } catch (e) {
      print('Error loading customer info: $e');
    }
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // In a real implementation, this would send the support request to your backend
      // For demo purposes, we'll simulate the submission

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.subject),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.length < 10) {
                        return 'Please provide more details';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitSupportRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Submit Request',
                              style: TextStyle(fontSize: 16),
                            ),
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
