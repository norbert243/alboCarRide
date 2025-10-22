import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class DriverTripManagementPage extends StatefulWidget {
  final String tripId;

  const DriverTripManagementPage({super.key, required this.tripId});

  @override
  State<DriverTripManagementPage> createState() =>
      _DriverTripManagementPageState();
}

class _DriverTripManagementPageState extends State<DriverTripManagementPage> {
  late TripService _tripService;
  Trip? _currentTrip;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tripService = Provider.of<TripService>(context, listen: false);
    _loadTrip();
    _setupTripSubscription();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await _tripService.getTripWithDetails(widget.tripId);
      setState(() {
        _currentTrip = trip;
        _isLoading = false;
      });
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to load trip: $e',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupTripSubscription() {
    _tripService.subscribeToTrip(widget.tripId).listen((trip) {
      if (mounted && trip.id.isNotEmpty) {
        setState(() {
          _currentTrip = trip;
        });
      }
    });
  }

  Future<void> _updateTripStatus(String newStatus, {String? reason}) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _tripService.updateTripStatus(widget.tripId, newStatus);

      CustomToast.showSuccess(
        context: context,
        message: 'Status updated successfully',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Error updating status: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Trip'),
        content: const Text('Are you sure you want to cancel this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateTripStatus('cancelled', reason: 'Driver cancelled');
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_currentTrip == null) return Container();

    final statusColors = {
      'scheduled': Colors.orange,
      'accepted': Colors.blue,
      'driver_arrived': Colors.purple,
      'in_progress': Colors.green,
      'completed': Colors.grey,
      'cancelled': Colors.red,
    };

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColors[_currentTrip!.status]?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColors[_currentTrip!.status] ?? Colors.grey,
                    ),
                  ),
                  child: Text(
                    _currentTrip!.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: statusColors[_currentTrip!.status],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if ((_currentTrip!.finalPrice ?? 0) > 0)
                  Text(
                    '\$${(_currentTrip!.finalPrice ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTripDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetails() {
    if (_currentTrip == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Rider ID', _currentTrip!.riderId),
        const SizedBox(height: 8),
        _buildDetailRow('Driver ID', _currentTrip!.driverId),
        const SizedBox(height: 8),
        if (_currentTrip!.requestId != null) ...[
          _buildDetailRow('Request ID', _currentTrip!.requestId!),
          const SizedBox(height: 8),
        ],
        if (_currentTrip!.offerId != null) ...[
          _buildDetailRow('Offer ID', _currentTrip!.offerId!),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _buildDetailRow('Status', _currentTrip!.status),
        const SizedBox(height: 8),
        _buildDetailRow(
          'Final Price',
          '\$${(_currentTrip!.finalPrice ?? 0).toStringAsFixed(2)}',
        ),
        const SizedBox(height: 8),
        if (_currentTrip!.startTime != null)
          _buildDetailRow(
            'Start Time',
            _currentTrip!.startTime!.toLocal().toString(),
          ),
        if (_currentTrip!.endTime != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            'End Time',
            _currentTrip!.endTime!.toLocal().toString(),
          ),
        ],
        if (_currentTrip!.cancellationReason != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            'Cancellation Reason',
            _currentTrip!.cancellationReason!,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_currentTrip == null || _isUpdating) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _currentTrip!.status;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (status == 'accepted') ...[
            _buildActionButton(
              'I\'m On My Way',
              Colors.blue,
              () => _updateTripStatus('driver_arrived'),
            ),
            const SizedBox(height: 12),
          ],
          if (status == 'driver_arrived') ...[
            _buildActionButton(
              'Start Trip',
              Colors.green,
              () => _updateTripStatus('in_progress'),
            ),
            const SizedBox(height: 12),
          ],
          if (status == 'in_progress') ...[
            _buildActionButton(
              'Complete Trip',
              Colors.green,
              () => _updateTripStatus('completed'),
            ),
            const SizedBox(height: 12),
          ],
          if (status != 'completed' && status != 'cancelled') ...[
            _buildActionButton('Cancel Trip', Colors.red, _showCancelDialog),
          ],
          if (status == 'completed' || status == 'cancelled') ...[
            _buildActionButton(
              'Back to Home',
              Colors.blue,
              () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isUpdating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Map View'),
            Text('(Will integrate with Google Maps API)'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentTrip == null
          ? const Center(child: Text('Trip not found'))
          : Column(
              children: [
                _buildStatusCard(),
                _buildMapPlaceholder(),
                const Spacer(),
                _buildActionButtons(),
              ],
            ),
    );
  }
}
