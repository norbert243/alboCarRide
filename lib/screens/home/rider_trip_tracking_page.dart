import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class RiderTripTrackingPage extends StatefulWidget {
  final String tripId;

  const RiderTripTrackingPage({super.key, required this.tripId});

  @override
  State<RiderTripTrackingPage> createState() => _RiderTripTrackingPageState();
}

class _RiderTripTrackingPageState extends State<RiderTripTrackingPage> {
  late TripService _tripService;
  Trip? _currentTrip;
  bool _isLoading = true;

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

  Future<void> _cancelTrip() async {
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _tripService.cancelTrip(widget.tripId);
                CustomToast.showSuccess(
                  context: context,
                  message: 'Trip cancelled successfully',
                );
              } catch (e) {
                CustomToast.showError(
                  context: context,
                  message: 'Failed to cancel trip: $e',
                );
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_currentTrip == null) return Container();

    final statusSteps = [
      {'status': 'scheduled', 'label': 'Requested', 'icon': Icons.schedule},
      {
        'status': 'accepted',
        'label': 'Accepted',
        'icon': Icons.check_circle_outline,
      },
      {
        'status': 'driver_arrived',
        'label': 'Driver Arrived',
        'icon': Icons.location_on,
      },
      {
        'status': 'in_progress',
        'label': 'In Progress',
        'icon': Icons.directions_car,
      },
      {'status': 'completed', 'label': 'Completed', 'icon': Icons.flag},
    ];

    final currentIndex = statusSteps.indexWhere(
      (step) => step['status'] == _currentTrip!.status,
    );
    final isCancelled = _currentTrip!.status == 'cancelled';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isCancelled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trip Cancelled',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...statusSteps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isCompleted = index <= currentIndex;
                final isCurrent = index == currentIndex;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step['icon'] as IconData,
                          color: isCompleted ? Colors.white : Colors.grey[600],
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['label'] as String,
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? Colors.green
                                    : Colors.black87,
                                fontSize: isCurrent ? 16 : 14,
                              ),
                            ),
                            if (isCurrent &&
                                _currentTrip!.status != 'completed')
                              const Text(
                                'Current status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfo() {
    if (_currentTrip == null) return Container();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Driver ID', _currentTrip!.driverId),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Final Price',
              '\$${(_currentTrip!.finalPrice ?? 0).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Status',
              _currentTrip!.status.replaceAll('_', ' ').toUpperCase(),
            ),
            if (_currentTrip!.startTime != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Start Time',
                _currentTrip!.startTime!.toLocal().toString(),
              ),
            ],
            if (_currentTrip!.endTime != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'End Time',
                _currentTrip!.endTime!.toLocal().toString(),
              ),
            ],
            if (_currentTrip!.cancellationReason != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Cancellation Reason',
                _currentTrip!.cancellationReason!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
    if (_currentTrip == null) return Container();

    final status = _currentTrip!.status;
    final isActive = status != 'completed' && status != 'cancelled';

    if (!isActive) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Back to Home',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (status != 'cancelled')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cancelTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
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
            Text('Live Trip Tracking'),
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
        title: const Text('Trip Tracking'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentTrip == null
          ? const Center(child: Text('Trip not found'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatusIndicator(),
                  _buildMapPlaceholder(),
                  _buildTripInfo(),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }
}
