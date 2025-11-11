import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/driver_location_service.dart';

class DriverMapWidget extends StatefulWidget {
  final double height;
  final double width;
  final bool showRideRequests;

  const DriverMapWidget({
    super.key,
    this.height = 300,
    this.width = double.infinity,
    this.showRideRequests = true,
  });

  @override
  State<DriverMapWidget> createState() => _DriverMapWidgetState();
}

class _DriverMapWidgetState extends State<DriverMapWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isDisposed = false;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    if (_isDisposed) return;

    try {
      if (!_isDisposed) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }

      final position = await DriverLocationService().getCurrentLocation();

      if (!_isDisposed) {
        if (position != null) {
          setState(() {
            _currentPosition = position;
            _isLoading = false;
          });
          _updateMapCamera();
          _addCurrentLocationMarker();
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = 'Unable to get current location';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 14.5,
            tilt: 45.0,
            bearing: 30.0,
          ),
        ),
      );
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.clear();
        _circles.clear();

        // Add current location marker (driver position)
        _markers.add(
          Marker(
            markerId: const MarkerId('driver_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'Driver position',
            ),
            anchor: const Offset(0.5, 0.5),
          ),
        );

        // Add circle around driver location
        _circles.add(
          Circle(
            circleId: const CircleId('driver_circle'),
            center: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            radius: 1000, // 1 km radius
            fillColor: Colors.green.withOpacity(0.1),
            strokeColor: Colors.green.withOpacity(0.3),
            strokeWidth: 2,
          ),
        );
      });
    }
  }

  void _addMockRideRequests() {
    if (_currentPosition == null) return;

    // Add mock ride requests around the driver
    final mockRequests = [
      {
        'id': 'request_1',
        'lat': _currentPosition!.latitude + 0.005,
        'lng': _currentPosition!.longitude + 0.005,
        'title': 'Ride Request',
        'snippet': 'Downtown • R18.75',
      },
      {
        'id': 'request_2',
        'lat': _currentPosition!.latitude - 0.003,
        'lng': _currentPosition!.longitude + 0.008,
        'title': 'Ride Request',
        'snippet': 'Airport • R32.50',
      },
      {
        'id': 'request_3',
        'lat': _currentPosition!.latitude + 0.008,
        'lng': _currentPosition!.longitude - 0.004,
        'title': 'Ride Request',
        'snippet': 'City Center • R15.25',
      },
    ];

    for (final request in mockRequests) {
      _markers.add(
        Marker(
          markerId: MarkerId(request['id'] as String),
          position: LatLng(request['lat'] as double, request['lng'] as double),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: request['title'] as String,
            snippet: request['snippet'] as String,
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _buildMapContent(),
      ),
    );
  }

  Widget _buildMapContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_currentPosition == null) {
      return _buildNoLocationState();
    }

    return Stack(children: [_buildMap(), _buildDriverStatusOverlay()]);
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade50, Colors.lightGreen.shade50],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Getting your location...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up your driver dashboard',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red.shade50, Colors.orange.shade50],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_off,
                  size: 40,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Location Access Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLocationState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade100, Colors.grey.shade200],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.location_searching,
                size: 40,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Not Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.location_on),
              label: const Text('Enable Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _updateMapCamera();
        if (widget.showRideRequests) {
          _addMockRideRequests();
        }
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 14.5,
        tilt: 45.0,
        bearing: 30.0,
      ),
      markers: _markers,
      circles: _circles,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      mapType: MapType.normal,
      buildingsEnabled: true,
      trafficEnabled: true,
      indoorViewEnabled: true,
    );
  }

  Widget _buildDriverStatusOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text(
              'Driver Mode',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapController?.dispose();
    super.dispose();
  }
}
