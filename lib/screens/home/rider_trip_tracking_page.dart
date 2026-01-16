import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:albocarride/utils/map_utils.dart';
import 'package:albocarride/screens/customer_payment_page.dart';

class RiderTripTrackingPage extends StatefulWidget {
  final String tripId;

  const RiderTripTrackingPage({super.key, required this.tripId});

  @override
  State<RiderTripTrackingPage> createState() => _RiderTripTrackingPageState();
}

class _RiderTripTrackingPageState extends State<RiderTripTrackingPage> {
  final TripService _tripService = TripService();
  Trip? _currentTrip;
  bool _isLoading = true;

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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _tripService.cancelTrip(widget.tripId, 'Rider cancelled');
                if (mounted) {
                  CustomToast.show(
                    context: context,
                    message: 'Trip cancelled successfully',
                  );
                }
              } catch (e) {
                if (mounted) {
                  CustomToast.show(
                    context: context,
                    message: 'Failed to cancel trip: $e',
                  );
                }
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _getPolyline() async {
    if (_currentTrip == null || _currentTrip!.pickupLocation == null || _currentTrip!.dropoffLocation == null) {
      return;
    }
    
    List<LatLng> polylineCoordinates = [];
    
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      // TODO: Add your Google Maps API Key here
      "YOUR_GOOGLE_MAPS_API_KEY",
      PointLatLng(_currentTrip!.pickupLocation!.latitude, _currentTrip!.pickupLocation!.longitude),
      PointLatLng(_currentTrip!.dropoffLocation!.latitude, _currentTrip!.dropoffLocation!.longitude),
      travelMode: TravelMode.driving,
    );

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
                        title: Text('Tracking Trip with ${_currentTrip?.driverName ?? 'Driver'}'),
                        background: _buildMap(),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatusIndicator(),
                        _buildTripInfo(),
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

  Widget _buildStatusIndicator() {
    if (_currentTrip == null) return const SizedBox.shrink();

    final statusSteps = [
      {'status': 'scheduled', 'label': 'Requested', 'icon': Icons.schedule},
      {'status': 'accepted', 'label': 'Driver on the way', 'icon': Icons.directions_car},
      {'status': 'driver_arrived', 'label': 'Driver has arrived', 'icon': Icons.location_on},
      {'status': 'in_progress', 'label': 'Trip in progress', 'icon': Icons.navigation},
      {'status': 'completed', 'label': 'Trip Completed', 'icon': Icons.flag},
    ];

    final currentIndex = statusSteps.indexWhere((step) => step['status'] == _currentTrip!.status);
    final isCancelled = _currentTrip!.status == 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trip Status', style: AppTheme.theme.textTheme.displayMedium),
            const SizedBox(height: 16),
            if (isCancelled)
              _buildCancelledIndicator()
            else
              Stepper(
                currentStep: currentIndex,
                controlsBuilder: (context, details) => const SizedBox.shrink(),
                steps: [
                  for (var i = 0; i < statusSteps.length; i++)
                    Step(
                      title: Text(statusSteps[i]['label'] as String),
                      content: const SizedBox.shrink(),
                      isActive: i <= currentIndex,
                      state: i < currentIndex ? StepState.complete : (i == currentIndex ? StepState.indexed : StepState.disabled),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text('Trip Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTripInfo() {
    if (_currentTrip == null) return const SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Trip Details'),
        children: [
          _buildInfoRow('Driver', _currentTrip!.driverName ?? 'N/A'),
          _buildInfoRow('From', _currentTrip!.pickupAddress),
          _buildInfoRow('To', _currentTrip!.dropoffAddress),
          _buildInfoRow('Price', 'R${_currentTrip!.proposedPrice.toStringAsFixed(2)}'),
          if (_currentTrip!.cancellationReason != null)
            _buildInfoRow('Cancellation Reason', _currentTrip!.cancellationReason!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value, style: AppTheme.theme.textTheme.bodyLarge),
    );
  }

  Widget _buildActionButtons() {
    if (_currentTrip == null) return const SizedBox.shrink();

    final status = _currentTrip!.status;
    final isActive = status != 'completed' && status != 'cancelled';
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if(isActive)
            ElevatedButton(
              onPressed: _cancelTrip,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Trip'),
            )
          else if(status == 'completed')
             ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CustomerPaymentPage(tripId: _currentTrip!.id)),
                );
              },
              child: const Text('Pay Now'),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home'),
            ),
        ],
      ),
    );
  }
}
