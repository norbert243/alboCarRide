import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/support_service.dart';
import 'package:albocarride/widgets/navigation_header.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final SupportService _supportService = SupportService();

  late TabController _tabController;
  bool _isLoading = false;
  String? _userId;
  String? _userRole;
  String? _selectedCategory;
  String? _selectedTripId;
  List<Map<String, dynamic>> _recentTrips = [];
  List<Map<String, dynamic>> _myTickets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserInfo();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);
    try {
      _userId = await SessionService.getUserId();
      _userRole = await SessionService.getUserRole();

      if (_userId != null && _userRole != null) {
        // Load recent trips for complaint linking
        _recentTrips = await _supportService.getUserRecentTrips(_userId!, _userRole!);
        // Load existing tickets
        _myTickets = await _supportService.getUserTickets(_userId!);
      }
    } catch (e) {
      print('Error loading user info: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a support request'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _supportService.createSupportTicket(
        userId: _userId!,
        userRole: _userRole!,
        subject: _subjectController.text,
        message: _messageController.text,
        tripId: _selectedTripId,
        category: _selectedCategory,
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form and reload tickets
        _subjectController.clear();
        _messageController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedTripId = null;
        });

        // Refresh tickets list
        _myTickets = await _supportService.getUserTickets(_userId!);
        setState(() {});
      } else {
        throw Exception('Failed to create ticket');
      }
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

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Live chat feature coming soon!')),
              );
            },
          ),
          const SizedBox(height: 32),
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
    );
  }

  Widget _buildSubmitComplaintTab() {
    final categories = _supportService.getSupportCategories();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit a Complaint',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We take all feedback seriously. Please provide details about your concern.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat['id'],
                  child: Text(cat['name']!),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Trip Selection (Optional)
            if (_recentTrips.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedTripId,
                decoration: const InputDecoration(
                  labelText: 'Related Trip (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_taxi),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No specific trip'),
                  ),
                  ..._recentTrips.map((trip) {
                    final pickup = trip['pickup_address'] ?? 'Unknown';
                    final dropoff = trip['dropoff_address'] ?? 'Unknown';
                    final shortPickup = pickup.length > 20 ? '${pickup.substring(0, 20)}...' : pickup;
                    final shortDropoff = dropoff.length > 20 ? '${dropoff.substring(0, 20)}...' : dropoff;
                    return DropdownMenuItem(
                      value: trip['id'] as String,
                      child: Text('$shortPickup → $shortDropoff'),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _selectedTripId = value),
              ),
              const SizedBox(height: 16),
            ],

            // Subject
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

            // Message
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe your issue',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: 'Please provide as much detail as possible...',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please describe your issue';
                }
                if (value.length < 20) {
                  return 'Please provide more details (at least 20 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
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
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Complaint',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTicketsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No support tickets yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a complaint if you have any issues',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myTickets.length,
      itemBuilder: (context, index) {
        final ticket = _myTickets[index];
        final status = ticket['status'] ?? 'open';
        final statusColor = status == 'closed'
            ? Colors.grey
            : status == 'in_progress'
                ? Colors.orange
                : Colors.green;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'closed'
                    ? Icons.check_circle
                    : status == 'in_progress'
                        ? Icons.pending
                        : Icons.report,
                color: statusColor,
              ),
            ),
            title: Text(
              ticket['subject'] ?? 'No subject',
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket['category']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'GENERAL',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Status: ${status.toString().replaceAll('_', ' ').toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTicketDetails(ticket),
          ),
        );
      },
    );
  }

  void _showTicketDetails(Map<String, dynamic> ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            ModalNavigationHeader(
              title: 'Ticket Details',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket['subject'] ?? 'No subject',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ticket['category']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'GENERAL',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(ticket['message'] ?? 'No message'),
                    const SizedBox(height: 16),
                    if (ticket['trip_id'] != null) ...[
                      const Text(
                        'Related Trip:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text('Trip ID: ${ticket['trip_id']}'),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Submitted: ${_formatDate(ticket['created_at'])}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.contact_support), text: 'Contact'),
            Tab(icon: Icon(Icons.report_problem), text: 'Complaint'),
            Tab(icon: Icon(Icons.history), text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactTab(),
          _buildSubmitComplaintTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }
}
