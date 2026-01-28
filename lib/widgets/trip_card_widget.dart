import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../widgets/custom_toast.dart';
import 'package:albocarride/models/trip.dart'; // Added import for Trip model

/// Widget that displays active trip information and controls
class TripCardWidget extends StatefulWidget {
  final Trip trip; // Changed type from Map<String, dynamic> to Trip
  final VoidCallback onTripCompleted;
  final VoidCallback onTripCancelled;

  const TripCardWidget({
    super.key,
    required this.trip,
    required this.onTripCompleted,
    required this.onTripCancelled,
  });

  @override
  State<TripCardWidget> createState() => _TripCardWidgetState();
}

class _TripCardWidgetState extends State<TripCardWidget> {
  final TripService _tripService = TripService();
  bool _isLoading = false;

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.orange;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _startTrip() async {
    setState(() => _isLoading = true);
    try {
      await _tripService.startTrip(widget.trip.id); // Changed from widget.trip['id']
      CustomToast.showSuccess(
        context: context,
        message: 'Trip started successfully!',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to start trip: $e',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeTrip() async {
    setState(() => _isLoading = true);
    try {
      await _tripService.completeTrip(widget.trip.id); // Changed from widget.trip['id']
      CustomToast.showSuccess(
        context: context,
        message: 'Trip completed successfully!',
      );
      widget.onTripCompleted();
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to complete trip: $e',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelTrip() async {
    final reason = await _showCancelDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _tripService.cancelTrip(widget.trip.id, reason); // Changed from widget.trip['id']
      CustomToast.showInfo(context: context, message: 'Trip cancelled');
      widget.onTripCancelled();
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to cancel trip: $e',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showCancelDialog() async {
    final reasonController = TextEditingController();

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = widget.trip.status; // Changed from widget.trip['status']

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (status == 'scheduled')
          ElevatedButton(
            onPressed: _startTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Trip'),
          ),

        if (status == 'in_progress')
          ElevatedButton(
            onPressed: _completeTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Trip'),
          ),

        ElevatedButton(
          onPressed: _cancelTrip,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel Trip'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final riderName = trip.riderName ?? 'Rider'; // Changed from trip['rider_name']
    final pickupAddress = trip.pickupAddress; // Changed from trip['pickup_address']
    final dropoffAddress = trip.dropoffAddress; // Changed from trip['dropoff_address']
    final proposedPrice = trip.proposedPrice; // Changed from trip['proposed_price']
    final finalPrice = trip.finalPrice ?? proposedPrice; // Changed from trip['final_price']
    final status = trip.status; // Changed from trip['status']
    final notes = trip.notes ?? ''; // Changed from trip['notes']

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trip with $riderName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Trip details
            _buildInfoRow(Icons.location_on, 'Pickup:', pickupAddress),
            _buildInfoRow(Icons.flag, 'Destination:', dropoffAddress),
            _buildInfoRow(
              Icons.attach_money,
              'Fare:',
              '\$${finalPrice.toStringAsFixed(2)}',
            ),

            if (notes.isNotEmpty) _buildInfoRow(Icons.note, 'Notes:', notes),

            // Trip timing
            if (trip.startedAt != null) // Changed from trip['start_time']
              _buildInfoRow(
                Icons.access_time,
                'Started:',
                _formatDateTime(trip.startedAt), // Changed from trip['start_time']
              ),

            if (trip.createdAt != null) // Changed from trip['created_at']
              _buildInfoRow(
                Icons.schedule,
                'Requested:',
                _formatDateTime(trip.createdAt), // Changed from trip['created_at']
              ),

            const SizedBox(height: 16),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) { // Changed parameter type
    if (dateTime == null) return 'N/A';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}