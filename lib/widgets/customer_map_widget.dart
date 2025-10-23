import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/customer_location_service.dart';
import '../services/nearby_drivers_service.dart';

class CustomerMapWidget extends StatefulWidget {
  final double height;
  final double width;
  final bool showNearbyDrivers;

  const CustomerMapWidget({
    super.key,
    this.height = 300,
    this.width = double.infinity,
    this.showNearbyDrivers = true,
  });

  @override
  State<CustomerMapWidget> createState() => _CustomerMapWidgetState();
}

class _CustomerMapWidgetState extends State<CustomerMapWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isDisposed = false;
  bool _loadingDrivers = false;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  List<NearbyDriver> _nearbyDrivers = [];

  final _nearbyDriversService = NearbyDriversService.instance;

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

      final position = await CustomerLocationService().getCurrentPosition();

      if (!_isDisposed) {
        if (position != null) {
          setState(() {
            _currentPosition = position;
            _isLoading = false;
          });
          _updateMapCamera();
          _addCurrentLocationMarker();
          if (widget.showNearbyDrivers) {
            _fetchNearbyDrivers();
          }
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

  Future<void> _fetchNearbyDrivers() async {
    if (_currentPosition == null) return;

    if (!_isDisposed) {
      setState(() {
        _loadingDrivers = true;
      });
    }

    try {
      // Use mock drivers for development
      final drivers = _nearbyDriversService.getMockNearbyDrivers(
        userLatitude: _currentPosition!.latitude,
        userLongitude: _currentPosition!.longitude,
        count: 8,
      );

      if (!_isDisposed) {
        setState(() {
          _nearbyDrivers = drivers;
          _loadingDrivers = false;
        });
        _addDriverMarkers();
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _loadingDrivers = false;
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

        // Add current location marker
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'Current position',
            ),
            anchor: const Offset(0.5, 0.5),
          ),
        );

        // Add circle around current location
        _circles.add(
          Circle(
            circleId: const CircleId('location_circle'),
            center: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            radius: 500, // 500 meters
            fillColor: Colors.blue.withOpacity(0.1),
            strokeColor: Colors.blue.withOpacity(0.3),
            strokeWidth: 2,
          ),
        );
      });
    }
  }

  void _addDriverMarkers() {
    if (_currentPosition == null) return;

    for (final driver in _nearbyDrivers) {
      final markerId = MarkerId('driver_${driver.id}');

      // Choose car icon based on vehicle type
      Color carColor;
      String carType;
      switch (driver.vehicleType) {
        case 'suv':
          carColor = Colors.orange;
          carType = 'SUV';
          break;
        case 'luxury':
          carColor = Colors.purple;
          carType = 'Luxury';
          break;
        default:
          carColor = Colors.green;
          carType = 'Standard';
      }

      _markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(driver.latitude, driver.longitude),
          icon: _createCarIcon(carColor),
          infoWindow: InfoWindow(
            title: driver.name,
            snippet: '$carType • ⭐ ${driver.rating}',
          ),
          anchor: const Offset(0.5, 0.5),
          onTap: () {
            // Show driver details when marker is tapped
            _showDriverInfo(driver);
          },
        ),
      );
    }
  }

  BitmapDescriptor _createCarIcon(Color color) {
    // Create a custom car icon using Flutter's painting capabilities
    // For now, we'll use a colored marker that represents a car
    // In a real app, you would create custom bitmap icons
    return BitmapDescriptor.defaultMarkerWithHue(_colorToHue(color));
  }

  double _colorToHue(Color color) {
    // Convert color to hue value for bitmap descriptor
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.purple) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueBlue;
  }

  void _showDriverInfo(NearbyDriver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${driver.name} - ${driver.vehicleType.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  driver.vehicleType == 'suv'
                      ? Icons.directions_car_filled
                      : Icons.directions_car,
                  color: driver.vehicleType == 'suv'
                      ? Colors.orange
                      : driver.vehicleType == 'luxury'
                      ? Colors.purple
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  '${driver.vehicleType.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${driver.rating}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Distance: ${_calculateDistance(driver.latitude, driver.longitude).toStringAsFixed(1)} km',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(double lat, double lng) {
    if (_currentPosition == null) return 0.0;

    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        ) /
        1000; // Convert to kilometers
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

    return Stack(
      children: [
        _buildMap(),
        if (_loadingDrivers) _buildDriverLoadingOverlay(),
        if (_nearbyDrivers.isNotEmpty) _buildDriverCountOverlay(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.lightBlue.shade50],
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Finding your location...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up your ride experience',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.withOpacity(0.7),
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
                backgroundColor: Colors.blue,
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
      zoomControlsEnabled: true, // Enable zoom controls
      mapToolbarEnabled: true, // Enable map toolbar
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      mapType: MapType.normal,
      buildingsEnabled: true,
      trafficEnabled: true,
      indoorViewEnabled: true,
      onCameraMove: (CameraPosition position) {
        // Camera is moving - user is interacting with the map
      },
      onCameraIdle: () {
        // Camera has stopped moving
      },
      onTap: (LatLng position) {
        // Map was tapped
      },
      onLongPress: (LatLng position) {
        // Map was long pressed
      },
    );
  }

  Widget _buildDriverLoadingOverlay() {
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
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Finding drivers...',
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

  Widget _buildDriverCountOverlay() {
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
              '${_nearbyDrivers.length} cars nearby',
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
