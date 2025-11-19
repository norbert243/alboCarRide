import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/emergency_sos_service.dart';
import '../services/session_service.dart';
import '../widgets/custom_toast.dart';

class SosButton extends StatefulWidget {
  final String? tripId;
  final bool isDriver;
  final VoidCallback? onSosTriggered;

  const SosButton({
    super.key,
    this.tripId,
    this.isDriver = false,
    this.onSosTriggered,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  final EmergencySosService _sosService = EmergencySosService(
    Supabase.instance.client,
  );

  bool _isTriggering = false;
  bool _longPressActive = false;
  double _progress = 0.0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // 3 seconds hold to trigger
    )..addListener(() {
        setState(() {
          _progress = _animationController.value;
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _triggerSos() async {
    if (_isTriggering) return;

    setState(() => _isTriggering = true);

    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get user ID
      final userId = await SessionService.getUserIdStatic();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Trigger appropriate SOS based on user type
      if (widget.isDriver) {
        await _sosService.triggerDriverSos(
          userId: userId,
          currentLocation: position,
          tripId: widget.tripId,
        );
      } else {
        await _sosService.triggerPassengerSos(
          userId: userId,
          currentLocation: position,
          tripId: widget.tripId,
        );
      }

      // Show success message
      if (mounted) {
        _showSosConfirmationDialog();
        widget.onSosTriggered?.call();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'Failed to trigger SOS: ${e.toString()}',
        );
      }
    } finally {
      setState(() => _isTriggering = false);
    }
  }

  void _showSosConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('SOS Alert Sent!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isDriver) ...[
              Text(
                '✓ Your emergency contacts have been notified',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '✓ SMS and WhatsApp alerts sent with your live location',
                style: TextStyle(fontSize: 14),
              ),
            ] else ...[
              Text(
                '✓ Nearby drivers have been alerted',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '✓ Help is on the way',
                style: TextStyle(fontSize: 14),
              ),
            ],
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'If you are in immediate danger, please call local emergency services.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _longPressActive = true);
    _animationController.forward();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() => _longPressActive = false);
    if (_animationController.value >= 1.0) {
      // SOS triggered
      _triggerSos();
    }
    _animationController.reverse();
  }

  void _onLongPressCancel() {
    setState(() => _longPressActive = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress circle
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 4,
              backgroundColor: Colors.red.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
            ),
          ),
          // SOS Button
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _longPressActive ? Colors.red.shade700 : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isTriggering
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Floating SOS button that can be placed anywhere
class FloatingSosButton extends StatelessWidget {
  final String? tripId;
  final bool isDriver;
  final VoidCallback? onSosTriggered;

  const FloatingSosButton({
    super.key,
    this.tripId,
    this.isDriver = false,
    this.onSosTriggered,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hold for 3s',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SosButton(
            tripId: tripId,
            isDriver: isDriver,
            onSosTriggered: onSosTriggered,
          ),
        ],
      ),
    );
  }
}
