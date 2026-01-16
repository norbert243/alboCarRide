import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:albocarride/utils/map_utils.dart';

class DriverTripManagementPage extends StatefulWidget {
  final String tripId;

  const DriverTripManagementPage({super.key, required this.tripId});

  @override
  State<DriverTripManagementPage> createState() =>
      _DriverTripManagementPageState();
}

class _DriverTripManagementPageState extends State<DriverTripManagementPage> {
  final TripService _tripService = TripService();
  Trip? _currentTrip;
  bool _isLoading = true;
  bool _isUpdating = false;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  
  BitmapDescriptor? carMarker;
  BitmapDescriptor? personMarker;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _loadTrip();
  }
  
  Future<void> _loadMarkers() async {
    carMarker = await getBytesFromAsset('assets/images/car_marker.svg', 100);
    personMarker = await getBytesFromAsset('assets/images/person_marker.svg', 100);
    setState(() {});
  }

  Future<void> _loadTrip() async {
    try {
      final tripData = await _tripService.getTripById(widget.tripId);
      if (tripData != null) {
        if (mounted) {
          setState(() {
            _currentTrip = Trip.fromMap(tripData);
            _isLoading = false;
          });
          _setupTripSubscription();
          _getPolyline();
        }
      } else {
        throw Exception('Trip not found');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Failed to load trip: $e',
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupTripSubscription() {
    _tripService.subscribeToTrip(widget.tripId).listen((tripData) {
      if (mounted && tripData.isNotEmpty) {
        setState(() {
          _currentTrip = Trip.fromMap(tripData);
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
      await _tripService.updateTripStatus(widget.tripId, newStatus, reason: reason);
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Status updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Error updating status: $e',
        );
      }
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _updateTripStatus('cancelled', reason: 'Driver cancelled');
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
  
  import 'package:flutter_dotenv/flutter_dotenv.dart';

void _getPolyline() async {
    if (_currentTrip == null ||
        _currentTrip!.pickupLocation == null ||
        _currentTrip!.dropoffLocation == null) {
      return;
    }

    List<LatLng> polylineCoordinates = [];

    PolylineRequest request = PolylineRequest(
      origin: PointLatLng(_currentTrip!.pickupLocation!.latitude,
          _currentTrip!.pickupLocation!.longitude),
      destination: PointLatLng(_currentTrip!.dropoffLocation!.latitude,
          _currentTrip!.dropoffLocation!.longitude),
      mode: TravelMode.driving,
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!, request: request);

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    setState(() {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        color: AppTheme.primaryColor,
        width: 5,
        points: polylineCoordinates,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentTrip == null
              ? const Center(child: Text('Trip not found'))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 250.0,
                      backgroundColor: AppTheme.primaryColor,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text('Trip with ${_currentTrip?.riderName ?? 'Rider'}'),
                        background: _buildMap(),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatusCard(),
                        _buildTripDetails(),
                        _buildActionButtons(),
                      ]),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildMap() {
    if(_currentTrip?.pickupLocation == null) {
      return const Center(child: Text('Location not available'));
    }
    
    final pickup = _currentTrip!.pickupLocation!;
    
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(pickup.latitude, pickup.longitude),
      infoWindow: const InfoWindow(title: 'Pickup'),
      icon: personMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));
    
    if(_currentTrip?.dropoffLocation != null) {
      final dropoff = _currentTrip!.dropoffLocation!;
       _markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(dropoff.latitude, dropoff.longitude),
        infoWindow: const InfoWindow(title: 'Dropoff'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    if(_currentTrip?.driverLocation != null) {
      final driverLocation = _currentTrip!.driverLocation!;
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(driverLocation.latitude, driverLocation.longitude),
        infoWindow: const InfoWindow(title: 'Driver'),
        icon: carMarker ?? BitmapDescriptor.defaultMarker,
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(pickup.latitude, pickup.longitude),
        zoom: 14,
      ),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      markers: _markers,
      polylines: _polylines,
    );
  }

  Widget _buildStatusCard() {
    if (_currentTrip == null) return const SizedBox.shrink();

    final status = _currentTrip!.status;

    return Card(
      child: ListTile(
        leading: Icon(_getStatusIcon(status), color: AppTheme.primaryColor, size: 40),
        title: Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: AppTheme.theme.textTheme.displayMedium,
        ),
        subtitle: const Text('Current trip status'),
        trailing: Text(
          'R${(_currentTrip!.finalPrice ?? _currentTrip!.proposedPrice).toStringAsFixed(2)}',
          style: AppTheme.theme.textTheme.displayMedium?.copyWith(color: Colors.green.shade700),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'scheduled': return Icons.schedule;
      case 'accepted': return Icons.check_circle_outline;
      case 'driver_arrived': return Icons.location_on;
      case 'in_progress': return Icons.directions_car;
      case 'completed': return Icons.flag;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  Widget _buildTripDetails() {
    if (_currentTrip == null) return const SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Trip Details'),
        children: [
          _buildDetailRow('Rider', _currentTrip!.riderName ?? 'N/A'),
          _buildDetailRow('From', _currentTrip!.pickupAddress),
          _buildDetailRow('To', _currentTrip!.dropoffAddress),
          _buildDetailRow('Status', _currentTrip!.status),
          if (_currentTrip!.startTime != null)
            _buildDetailRow('Started', _currentTrip!.startTime!.toLocal().toString()),
          if (_currentTrip!.endTime != null)
            _buildDetailRow('Ended', _currentTrip!.endTime!.toLocal().toString()),
          if (_currentTrip!.cancellationReason != null)
            _buildDetailRow('Cancellation Reason', _currentTrip!.cancellationReason!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value, style: AppTheme.theme.textTheme.bodyLarge),
    );
  }

  Widget _buildActionButtons() {
    if (_currentTrip == null || _isUpdating) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _currentTrip!.status;
    
    final actions = <Widget>[];

    if (status == 'accepted') {
      actions.add(_buildActionButton('I Have Arrived', () => _updateTripStatus('driver_arrived')));
    }
    if (status == 'driver_arrived') {
      actions.add(_buildActionButton('Start Trip', () => _updateTripStatus('in_progress')));
    }
    if (status == 'in_progress') {
      actions.add(_buildActionButton('Complete Trip', () => _updateTripStatus('completed')));
    }
    if (status != 'completed' && status != 'cancelled') {
      actions.add(_buildActionButton('Cancel Trip', _showCancelDialog, isDestructive: true));
    }
    if (status == 'completed' || status == 'cancelled') {
      actions.add(_buildActionButton('Back to Home', () => Navigator.pop(context)));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: e)).toList(),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed, {bool isDestructive = false}) {
    return ElevatedButton(
      onPressed: _isUpdating ? null : onPressed,
      style: isDestructive ? ElevatedButton.styleFrom(backgroundColor: Colors.red) : null,
      child: _isUpdating
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
          : Text(text),
    );
  }
}
