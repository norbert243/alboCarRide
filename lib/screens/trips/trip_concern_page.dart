import 'package:flutter/material.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/support_service.dart';

class TripConcernPage extends StatefulWidget {
  final String tripId;
  final String? tripDetails;

  const TripConcernPage({
    super.key,
    required this.tripId,
    this.tripDetails,
  });

  @override
  State<TripConcernPage> createState() => _TripConcernPageState();
}

class _TripConcernPageState extends State<TripConcernPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final SupportService _supportService = SupportService();

  bool _isLoading = false;
  String? _selectedCategory;
  String? _userId;
  String? _userRole;

  final List<Map<String, String>> _tripConcernCategories = [
    {'id': 'safety', 'name': 'Safety Concern', 'icon': 'warning'},
    {'id': 'driver_behavior', 'name': 'Driver Behavior', 'icon': 'person'},
    {'id': 'rider_behavior', 'name': 'Rider Behavior', 'icon': 'person'},
    {'id': 'route_issue', 'name': 'Route Issue', 'icon': 'route'},
    {'id': 'vehicle_condition', 'name': 'Vehicle Condition', 'icon': 'car'},
    {'id': 'payment_dispute', 'name': 'Payment Dispute', 'icon': 'payment'},
    {'id': 'lost_item', 'name': 'Lost Item', 'icon': 'search'},
    {'id': 'other', 'name': 'Other', 'icon': 'more'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    _userId = await SessionService.getUserId();
    _userRole = await SessionService.getUserRole();
    setState(() {});
  }

  IconData _getIconForCategory(String iconName) {
    switch (iconName) {
      case 'warning':
        return Icons.warning;
      case 'person':
        return Icons.person;
      case 'route':
        return Icons.route;
      case 'car':
        return Icons.directions_car;
      case 'payment':
        return Icons.payment;
      case 'search':
        return Icons.search;
      case 'more':
        return Icons.more_horiz;
      default:
        return Icons.help;
    }
  }

  Future<void> _submitConcern() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a concern category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a concern'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final categoryName = _tripConcernCategories
          .firstWhere((cat) => cat['id'] == _selectedCategory)['name'];

      final result = await _supportService.createSupportTicket(
        userId: _userId!,
        userRole: _userRole!,
        subject: 'Trip Concern: $categoryName',
        message: _messageController.text,
        tripId: widget.tripId,
        category: _selectedCategory,
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Concern submitted successfully! We will review it shortly.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to submit concern');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting concern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Report a Concern'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_taxi, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trip ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            widget.tripId.length > 20
                                ? '${widget.tripId.substring(0, 20)}...'
                                : widget.tripId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.tripDetails != null)
                            Text(
                              widget.tripDetails!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category Selection
              const Text(
                'What is your concern about?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Category Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: _tripConcernCategories.length,
                itemBuilder: (context, index) {
                  final category = _tripConcernCategories[index];
                  final isSelected = _selectedCategory == category['id'];

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category['id']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconForCategory(category['icon']!),
                            size: 20,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              category['name']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Description
              const Text(
                'Describe your concern',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide as much detail as possible to help us address your concern.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe your concern';
                  }
                  if (value.length < 20) {
                    return 'Please provide more details (at least 20 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitConcern,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                          'Submit Concern',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Info Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Our support team will review your concern and may contact you for more information.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
