import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/trip_service.dart';
import '../services/location_service.dart';
import '../services/driver_location_service.dart';
import '../models/trip.dart';
import '../widgets/custom_toast.dart';
import '../widgets/ride_map_widget.dart';

/// Widget that displays active trip information and controls
class TripCardWidget extends StatefulWidget {
  final Trip trip;
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
  final DriverLocationService _locationService = DriverLocationService();
  bool _isLoading = false;
  bool _isLoadingLocation = true;
  double? _driverLat;
  double? _driverLng;
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;
  String? _pickupAddress;
  String? _dropoffAddress;
  List<LatLng> _routePolyline = [];

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Get driver's current location
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _driverLat = position.latitude;
          _driverLng = position.longitude;
        });
      }

      // Fetch ride request details using the trip's requestId
      final request = await Supabase.instance.client
          .from('ride_requests')
          .select(
            'pickup_address, dropoff_address, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng',
          )
          .eq('id', widget.trip.requestId)
          .maybeSingle();

      if (request != null && mounted) {
        final pickupLat = request['pickup_lat'] as double?;
        final pickupLng = request['pickup_lng'] as double?;
        final dropoffLat = request['dropoff_lat'] as double?;
        final dropoffLng = request['dropoff_lng'] as double?;

        // Fetch route polyline
        List<LatLng> polyline = [];
        if (pickupLat != null &&
            pickupLng != null &&
            dropoffLat != null &&
            dropoffLng != null) {
          polyline = await LocationService.getRoutePolyline(
            pickupLat,
            pickupLng,
            dropoffLat,
            dropoffLng,
          );
        }

        setState(() {
          _pickupAddress = request['pickup_address'];
          _dropoffAddress = request['dropoff_address'];
          _pickupLat = pickupLat;
          _pickupLng = pickupLng;
          _dropoffLat = dropoffLat;
          _dropoffLng = dropoffLng;
          _routePolyline = polyline;
        });
      }
    } catch (e) {
      print('Error loading location data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

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
      await _tripService.startTrip(widget.trip.id);
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
      await _tripService.completeTrip(widget.trip.id);
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
      await _tripService.cancelTrip(widget.trip.id);
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
    final status = widget.trip.status;

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
    final finalPrice = trip.finalPrice;
    final status = trip.status;

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
                const Text(
                  'Active Trip',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

            // Map Widget
            if (!_isLoadingLocation && _pickupLat != null && _pickupLng != null)
              Column(
                children: [
                  RideMapWidget(
                    currentLat: _driverLat,
                    currentLng: _driverLng,
                    pickupLat: _pickupLat,
                    pickupLng: _pickupLng,
                    dropoffLat: _dropoffLat,
                    dropoffLng: _dropoffLng,
                    pickupAddress: _pickupAddress,
                    dropoffAddress: _dropoffAddress,
                    polylinePoints: _routePolyline,
                    height: 250,
                    showCurrentLocation: true,
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Loading indicator for map
            if (_isLoadingLocation)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),

            // Trip details
            if (_pickupAddress != null)
              _buildInfoRow(
                Icons.location_on,
                'Pickup:',
                _pickupAddress!,
              ),
            if (_dropoffAddress != null)
              _buildInfoRow(
                Icons.flag,
                'Dropoff:',
                _dropoffAddress!,
              ),
            _buildInfoRow(Icons.person, 'Rider ID:', trip.riderId),
            _buildInfoRow(Icons.directions_car, 'Driver ID:', trip.driverId),
            _buildInfoRow(
              Icons.attach_money,
              'Fare:',
              '\$${finalPrice.toStringAsFixed(2)}',
            ),

            // Trip timing
            if (trip.startTime != null)
              _buildInfoRow(
                Icons.access_time,
                'Started:',
                _formatDateTime(trip.startTime!.toIso8601String()),
              ),

            if (trip.createdAt != null)
              _buildInfoRow(
                Icons.schedule,
                'Requested:',
                _formatDateTime(trip.createdAt.toIso8601String()),
              ),

            if (trip.cancellationReason != null)
              _buildInfoRow(
                Icons.cancel,
                'Cancellation Reason:',
                trip.cancellationReason!,
              ),

            const SizedBox(height: 16),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
