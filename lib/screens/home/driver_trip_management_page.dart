import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:albocarride/utils/custom_map_markers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  bool _markersInitialized = false;

  // Real-time driver location tracking
  LatLng? _currentDriverLocation;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _tripSubscription;
  Timer? _routeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
    _loadTrip();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _tripSubscription?.cancel();
    _routeUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMarkers() async {
    if (!_markersInitialized) {
      await CustomMapMarkers.initialize();
      _markersInitialized = true;
      if (mounted) setState(() {});
    }
  }

  /// Start tracking driver's own location
  void _startLocationTracking() async {
    try {
      // Get initial location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _updateDriverLocation(LatLng(position.latitude, position.longitude));

      // Subscribe to location updates
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 20, // Update every 20 meters
      );

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        _updateDriverLocation(LatLng(position.latitude, position.longitude));
      });

      // Update route every 30 seconds
      _routeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _updateRoutePolylines();
      });
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  /// Update driver location and refresh map
  void _updateDriverLocation(LatLng newLocation) {
    if (!mounted) return;

    final bool locationChanged = _currentDriverLocation == null ||
        (_currentDriverLocation!.latitude != newLocation.latitude ||
         _currentDriverLocation!.longitude != newLocation.longitude);

    if (locationChanged) {
      setState(() {
        _currentDriverLocation = newLocation;
      });
      _updateMapMarkers();
      // Don't update route on every location change to save API calls
    }
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
          _updateRoutePolylines();
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
    _tripSubscription = _tripService.subscribeToTrip(widget.tripId).listen((tripData) {
      if (mounted && tripData.isNotEmpty) {
        final previousStatus = _currentTrip?.status;
        setState(() {
          _currentTrip = Trip.fromMap(tripData);
        });
        // Update routes when status changes
        if (previousStatus != _currentTrip?.status) {
          _updateRoutePolylines();
        }
      }
    });
  }

  /// Update map markers with current positions
  void _updateMapMarkers() {
    if (_currentTrip == null) return;

    _markers.clear();

    // Customer/Pickup marker
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _currentTrip!.pickupLocation,
      infoWindow: InfoWindow(
        title: 'Pickup: ${_currentTrip!.riderName ?? 'Customer'}',
        snippet: _currentTrip!.pickupAddress,
      ),
      icon: CustomMapMarkers.getPersonMarker(),
    ));

    // Destination marker
    _markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: _currentTrip!.dropoffLocation,
      infoWindow: InfoWindow(
        title: 'Destination',
        snippet: _currentTrip!.dropoffAddress,
      ),
      icon: CustomMapMarkers.getDropoffMarker(),
    ));

    // Driver marker (your location)
    if (_currentDriverLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentDriverLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: CustomMapMarkers.getCarMarker(_currentTrip!.vehicleType ?? 'standard'),
      ));
    }
  }

  /// Update route polylines based on trip status
  Future<void> _updateRoutePolylines() async {
    if (_currentTrip == null) return;

    _polylines.clear();

    final status = _currentTrip!.status;
    final driverPos = _currentDriverLocation;
    final pickup = _currentTrip!.pickupLocation;
    final dropoff = _currentTrip!.dropoffLocation;

    // Show routes based on trip status
    if (status == 'accepted' || status == 'scheduled') {
      // Driver needs to go to pickup first
      if (driverPos != null) {
        await _drawRoute(driverPos, pickup, 'driver_to_pickup', Colors.blue, 6);
      }
      // Show pickup to dropoff route (faded preview)
      await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor.withOpacity(0.4), 4);
    } else if (status == 'driver_arrived') {
      // Driver is at pickup, show route to destination
      await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor, 5);
    } else if (status == 'in_progress') {
      // Trip in progress - show driver to dropoff route
      if (driverPos != null) {
        await _drawRoute(driverPos, dropoff, 'driver_to_dropoff', AppTheme.primaryColor, 6);
      } else {
        await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor, 5);
      }
    } else {
      // Default: show full route
      await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor, 5);
    }

    if (mounted) setState(() {});
  }

  /// Draw a route between two points
  Future<void> _drawRoute(LatLng origin, LatLng destination, String routeId, Color color, int width) async {
    try {
      final request = PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      );

      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!,
        request: request,
      );

      if (result.points.isNotEmpty) {
        final coordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        _polylines.add(Polyline(
          polylineId: PolylineId(routeId),
          color: color,
          width: width,
          points: coordinates,
        ));
      }
    } catch (e) {
      print('Error drawing route $routeId: $e');
    }
  }

  /// Fit map to show all markers
  void _fitMapToBounds() {
    if (_mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds();
    if (bounds != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  /// Calculate bounds containing all markers
  LatLngBounds? _calculateBounds() {
    if (_markers.isEmpty) return null;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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
    if (_currentTrip?.pickupLocation == null) {
      return const Center(child: Text('Location not available'));
    }

    // Update markers before building map
    _updateMapMarkers();

    // Determine initial camera target
    final initialTarget = _currentDriverLocation ?? _currentTrip!.pickupLocation!;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: 14,
      ),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // Fit map to show all markers after creation
        Future.delayed(const Duration(milliseconds: 500), () {
          _fitMapToBounds();
        });
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
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
          if (_currentTrip!.startedAt != null)
            _buildDetailRow('Started', _currentTrip!.startedAt!.toLocal().toString()), // Changed from startTime
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

    // Add Report Concern button
    actions.add(
      OutlinedButton.icon(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/trip-concern',
            arguments: {
              'tripId': _currentTrip!.id,
              'tripDetails': '${_currentTrip!.pickupAddress} → ${_currentTrip!.dropoffAddress}',
            },
          );
        },
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Report a Concern'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: const BorderSide(color: Colors.orange),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );

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
