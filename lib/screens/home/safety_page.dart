import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/emergency_sos_service.dart';
import 'package:albocarride/services/live_location_service.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/widgets/sos_button.dart';
import 'package:albocarride/screens/emergency/emergency_contacts_page.dart';

/// Safety & Emergency features page
class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final EmergencySosService _sosService = EmergencySosService(
    Supabase.instance.client,
  );
  final LiveLocationService _locationService = LiveLocationService(
    Supabase.instance.client,
  );

  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoadingContacts = true;
  bool _isSharingLocation = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final userId = await SessionService.getUserIdStatic();
      if (userId != null) {
        final contacts = await _sosService.getEmergencyContacts(userId);
        if (mounted) {
          setState(() {
            _emergencyContacts = contacts;
          });
        }
      }
    } catch (e) {
      print('Error loading emergency contacts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }
  }

  Future<void> _shareCurrentLocation() async {
    try {
      setState(() => _isSharingLocation = true);

      // Get current location
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      setState(() => _currentPosition = position);

      // Share via system share dialog
      await _locationService.shareLocation(
        position: position,
        customMessage: '📍 Sharing my live location with you for safety:',
      );

      if (mounted) {
        CustomToast.showSuccess(
          context: context,
          message: 'Location shared successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'Failed to share location: ${e.toString()}',
        );
      }
    } finally {
      setState(() => _isSharingLocation = false);
    }
  }

  void _showSosInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'How SOS Works',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoStep(
              number: '1',
              title: 'Hold the SOS button for 3 seconds',
              description:
                  'Press and hold the red SOS button to activate emergency mode',
            ),
            const SizedBox(height: 16),
            _buildInfoStep(
              number: '2',
              title: 'Automatic alerts sent',
              description:
                  'Your emergency contacts receive SMS and WhatsApp messages with your exact location',
            ),
            const SizedBox(height: 16),
            _buildInfoStep(
              number: '3',
              title: 'Nearby drivers notified',
              description:
                  'Drivers within 5km radius are alerted and can provide assistance',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'For immediate danger, call local emergency services directly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF424242)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Safety',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Emergency SOS Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency SOS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Hold for 3 seconds to trigger',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SosButton(
                        isDriver: false,
                        onSosTriggered: () {
                          // Optionally reload contacts or show confirmation
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Alerts emergency contacts & nearby drivers with your location',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _showSosInfo,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('How does SOS work?'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Emergency Contacts Section
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.contact_phone,
                        color: Color(0xFFE91E63),
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Emergency contacts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: _isLoadingContacts
                        ? const Text('Loading...')
                        : Text(
                            _emergencyContacts.isEmpty
                                ? 'No contacts added yet'
                                : '${_emergencyContacts.length} contact${_emergencyContacts.length > 1 ? "s" : ""} configured',
                            style: const TextStyle(fontSize: 14),
                          ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: Color(0xFFBDBDBD),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmergencyContactsPage(),
                        ),
                      );
                      // Reload contacts when returning
                      _loadEmergencyContacts();
                    },
                  ),
                  if (_emergencyContacts.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[800]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add emergency contacts to enable SOS alerts',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Share Location Section
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.share_location,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Share live location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Send your current location to someone',
                      style: TextStyle(fontSize: 14),
                    ),
                    trailing: _isSharingLocation
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            size: 24,
                            color: Color(0xFFBDBDBD),
                          ),
                    onTap: _isSharingLocation ? null : _shareCurrentLocation,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Shares a Google Maps link with your real-time location',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // How SOS Works - Visual Workflow Section (Blueprint2 specification)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'How the SOS System Works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Passenger SOS Section
                  const Text(
                    '🧑‍🤝‍🧑 Passenger SOS (Your Personal Alert)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWorkflowStep(
                    icon: '🚨',
                    step: '1. Tap Panic Button',
                    description:
                        'You tap and confirm the silent alert mechanism within the app during a ride.',
                  ),
                  _buildWorkflowStep(
                    icon: '📡',
                    step: '2. Get Location',
                    description:
                        'The app instantly fetches your Live GPS Location (Silent).',
                  ),
                  _buildWorkflowStep(
                    icon: '💬',
                    step: '3. Send Alert',
                    description:
                        'An SMS/WhatsApp message with a Live Location Link is sent to your 3 pre-set contacts.',
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Driver SOS Section
                  const Text(
                    '🚕 Driver SOS (Driver Peer-to-Peer Safety)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWorkflowStep(
                    icon: '🚕',
                    step: '1. Driver Triggers SOS',
                    description:
                        'Your driver triggers a silent alert (for their safety).',
                  ),
                  _buildWorkflowStep(
                    icon: '🗺️',
                    step: '2. Server Filters',
                    description:
                        'The server identifies all active AlboCarRide drivers within a 3–5 km radius.',
                  ),
                  _buildWorkflowStep(
                    icon: '🔔',
                    step: '3. Nearby Help',
                    description:
                        'Those nearby drivers receive an urgent push notification with the SOS driver\'s live location, requesting immediate assistance.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Safety Tips Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Safety tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSafetyTip(
                    '✓ Always verify driver details before entering the vehicle',
                  ),
                  _buildSafetyTip(
                    '✓ Share your trip details with friends or family',
                  ),
                  _buildSafetyTip(
                    '✓ Sit in the back seat for added security',
                  ),
                  _buildSafetyTip(
                    '✓ Trust your instincts - if something feels wrong, speak up',
                  ),
                  _buildSafetyTip(
                    '✓ Keep your phone charged and location services enabled',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStep({
    required String icon,
    required String step,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.arrow_forward,
            size: 16,
            color: Color(0xFFBDBDBD),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        tip,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
