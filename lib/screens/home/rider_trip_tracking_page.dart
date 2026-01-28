import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/trip_service.dart';
import 'package:albocarride/models/trip.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:albocarride/utils/custom_map_markers.dart';
import 'package:albocarride/screens/customer_payment_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RiderTripTrackingPage extends StatefulWidget {
  final String tripId;

  const RiderTripTrackingPage({super.key, required this.tripId});

  @override
  State<RiderTripTrackingPage> createState() => _RiderTripTrackingPageState();
}

class _RiderTripTrackingPageState extends State<RiderTripTrackingPage> {
  final TripService _tripService = TripService();
  final SupabaseClient _supabase = Supabase.instance.client;
  Trip? _currentTrip;
  bool _isLoading = true;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();

  bool _markersInitialized = false;

  // Real-time driver location tracking
  LatLng? _currentDriverLocation;
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _tripSubscription;
  Timer? _locationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
    _loadTrip();
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _tripSubscription?.cancel();
    _locationRefreshTimer?.cancel();
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
          _setupDriverLocationTracking();
          _updateRoutePolylines();
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

  /// Subscribe to real-time driver location updates
  void _setupDriverLocationTracking() {
    if (_currentTrip?.driverId == null) return;

    final driverId = _currentTrip!.driverId!;

    // Subscribe to real-time updates from driver_locations table
    _driverLocationSubscription = _supabase
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final location = data.first;
            final newLocation = LatLng(
              (location['lat'] as num).toDouble(),
              (location['lng'] as num).toDouble(),
            );
            _updateDriverLocation(newLocation);
          }
        });

    // Also set up a fallback timer to fetch location every 10 seconds
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchDriverLocation(driverId);
    });

    // Fetch initial location
    _fetchDriverLocation(driverId);
  }

  /// Fetch driver location from database
  Future<void> _fetchDriverLocation(String driverId) async {
    try {
      // Try driver_locations table first
      final response = await _supabase
          .from('driver_locations')
          .select('lat, lng')
          .eq('driver_id', driverId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        final newLocation = LatLng(
          (response['lat'] as num).toDouble(),
          (response['lng'] as num).toDouble(),
        );
        _updateDriverLocation(newLocation);
      } else {
        // Fallback to drivers table
        final driverResponse = await _supabase
            .from('drivers')
            .select('current_latitude, current_longitude')
            .eq('id', driverId)
            .maybeSingle();

        if (driverResponse != null &&
            driverResponse['current_latitude'] != null &&
            driverResponse['current_longitude'] != null &&
            mounted) {
          final newLocation = LatLng(
            (driverResponse['current_latitude'] as num).toDouble(),
            (driverResponse['current_longitude'] as num).toDouble(),
          );
          _updateDriverLocation(newLocation);
        }
      }
    } catch (e) {
      print('Error fetching driver location: $e');
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
      _updateRoutePolylines();
      _animateCameraToDriver();
    }
  }

  /// Animate camera to follow driver
  void _animateCameraToDriver() {
    if (_mapController == null || _currentDriverLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(_currentDriverLocation!),
    );
  }

  /// Update map markers with current positions
  void _updateMapMarkers() {
    if (_currentTrip == null) return;

    _markers.clear();

    // Pickup marker
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _currentTrip!.pickupLocation,
      infoWindow: const InfoWindow(title: 'Pickup Location'),
      icon: CustomMapMarkers.getPickupMarker(),
    ));

    // Dropoff marker
    _markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: _currentTrip!.dropoffLocation,
      infoWindow: const InfoWindow(title: 'Destination'),
      icon: CustomMapMarkers.getDropoffMarker(),
    ));

    // Driver marker (real-time position)
    final driverPos = _currentDriverLocation ?? _currentTrip!.driverLocation;
    if (driverPos != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        infoWindow: InfoWindow(title: _currentTrip!.driverName ?? 'Driver'),
        icon: CustomMapMarkers.getCarMarker(_currentTrip!.vehicleType ?? 'standard'),
      ));
    }
  }

  /// Update route polylines based on trip status
  Future<void> _updateRoutePolylines() async {
    if (_currentTrip == null) return;

    _polylines.clear();

    final status = _currentTrip!.status;
    final driverPos = _currentDriverLocation ?? _currentTrip!.driverLocation;
    final pickup = _currentTrip!.pickupLocation;
    final dropoff = _currentTrip!.dropoffLocation;

    // Show route based on trip status
    if (status == 'accepted' || status == 'driver_arrived') {
      // Driver is on the way to pickup - show driver to pickup route
      if (driverPos != null) {
        await _drawRoute(driverPos, pickup, 'driver_to_pickup', Colors.blue);
      }
      // Also show pickup to dropoff route (faded)
      await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor.withOpacity(0.5));
    } else if (status == 'in_progress') {
      // Trip in progress - show driver to dropoff route
      if (driverPos != null) {
        await _drawRoute(driverPos, dropoff, 'driver_to_dropoff', AppTheme.primaryColor);
      } else {
        await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor);
      }
    } else {
      // Default: show pickup to dropoff
      await _drawRoute(pickup, dropoff, 'pickup_to_dropoff', AppTheme.primaryColor);
    }

    if (mounted) setState(() {});
  }

  /// Draw a route between two points
  Future<void> _drawRoute(LatLng origin, LatLng destination, String routeId, Color color) async {
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
          width: 5,
          points: coordinates,
        ));
      }
    } catch (e) {
      print('Error drawing route $routeId: $e');
    }
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

  /// Fit map to show all markers and route
  void _fitMapToBounds() {
    if (_mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds();
    if (bounds != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  /// Calculate bounds that contain all markers
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
                        _buildDriverCard(),
                        _buildTripInfo(),
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
    final driverPos = _currentDriverLocation ?? _currentTrip!.driverLocation;
    final initialTarget = driverPos ?? _currentTrip!.pickupLocation!;

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
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
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
  
  Widget _buildDriverCard() {
    if (_currentTrip == null || _currentTrip!.driverName == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Driver Profile Picture
            FutureBuilder<String?>(
              future: _getDriverProfilePicture(),
              builder: (context, snapshot) {
                return CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: snapshot.data != null
                      ? NetworkImage(snapshot.data!)
                      : null,
                  child: snapshot.data == null
                      ? Icon(Icons.person, size: 35, color: Colors.grey[400])
                      : null,
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTrip!.driverName ?? 'Driver',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[600]),
                      const SizedBox(width: 4),
                      Text(
                        '4.8',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _currentTrip!.vehicleType ?? 'Standard',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Call Driver Button
            IconButton(
              onPressed: () {
                // TODO: Implement call driver
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling driver...')),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getDriverProfilePicture() async {
    if (_currentTrip?.driverId == null) return null;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('profile_picture_url')
          .eq('id', _currentTrip!.driverId!)
          .single();
      return response['profile_picture_url'];
    } catch (e) {
      return null;
    }
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
          const SizedBox(height: 12),
          // Report Concern Button
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
        ],
      ),
    );
  }
}