import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class WaitingForReviewPage extends StatefulWidget {
  const WaitingForReviewPage({Key? key}) : super(key: key);

  @override
  State<WaitingForReviewPage> createState() => _WaitingForReviewPageState();
}

class _WaitingForReviewPageState extends State<WaitingForReviewPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isCheckingStatus = false;

  /// Check the current verification status from the database
  Future<void> _checkVerificationStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        CustomToast.show(context: context, message: 'Please log in again');
        return;
      }

      // Get the current verification status
      final response = await _supabase
          .from('profiles')
          .select('verification_status')
          .eq('id', userId)
          .single();

      final verificationStatus = response['verification_status'] as String?;

      debugPrint('Current verification status: $verificationStatus');

      if (verificationStatus == 'approved') {
        CustomToast.show(
          context: context,
          message: 'Your verification has been approved!',
        );
        // Navigate to driver home page
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/driver-home',
          (route) => false,
        );
      } else if (verificationStatus == 'rejected') {
        CustomToast.show(
          context: context,
          message:
              'Your verification was rejected. Please resubmit your documents.',
        );
        // Navigate to verification page to resubmit
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/verification',
          (route) => false,
        );
      } else if (verificationStatus == 'pending') {
        CustomToast.show(
          context: context,
          message:
              'Your documents are still under review. Please check back later.',
        );
        // Stay on this page
      } else {
        CustomToast.show(
          context: context,
          message: 'Unknown verification status. Please contact support.',
        );
      }
    } catch (e) {
      debugPrint('Error checking verification status: $e');
      CustomToast.show(
        context: context,
        message: 'Failed to check status. Please try again.',
      );
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
    }
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
          'Verification Pending',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top,
                size: 60,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 32),

            // Title
            const Text(
              'Documents Under Review',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Your documents have been submitted and are currently being reviewed by our team.',
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Timeline Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTimelineItem(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    title: 'Documents Submitted',
                    description:
                        'Your documents have been successfully uploaded',
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem(
                    icon: Icons.hourglass_top,
                    color: Colors.orange,
                    title: 'Under Review',
                    description: 'Our team is verifying your documents',
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem(
                    icon: Icons.notifications,
                    color: Colors.blue,
                    title: 'Notification',
                    description:
                        'You will receive a notification once approved',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Estimated Time
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Review Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Typically 24-48 hours',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Column(
              children: [
                ElevatedButton(
                  onPressed: _isCheckingStatus
                      ? null
                      : _checkVerificationStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isCheckingStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Check Status'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    // Contact support
                    // This could open email or support chat
                  },
                  child: const Text(
                    'Contact Support',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
