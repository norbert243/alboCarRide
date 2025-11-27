import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:albocarride/screens/home/indrive_book_ride_complete.dart';

/// Bolt-style customer home screen
/// Full-screen map with floating menu and "Where to?" search card
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _centerPosition;
  bool _isLoadingLocation = true;
  bool _isEditingLocation = false;
  String _currentAddress = 'Getting location...';

  // Mock nearby drivers (you can load real drivers from database)
  final Set<Marker> _driverMarkers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _centerPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
          _currentAddress = _getAddressFromPosition(position);
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );

        // Generate mock nearby drivers
        _generateMockDrivers(position.latitude, position.longitude);
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _centerPosition = const LatLng(-4.3217, 15.3125); // Kinshasa default
          _isLoadingLocation = false;
          _currentAddress = 'Location unavailable';
        });
      }
    }
  }

  String _getAddressFromPosition(Position position) {
    // This is a simplified version - in production you'd use Google Maps Geocoding API
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  void _refreshLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    await _getCurrentLocation();
  }

  void _toggleEditLocation() {
    setState(() {
      _isEditingLocation = !_isEditingLocation;
    });
  }

  void _updateLocationManually() {
    // Show dialog to manually enter location
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Enter your current location',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // In production, you'd use Google Places API for autocomplete
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Current: $_currentAddress',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // In production, you'd geocode the address and update the map
              setState(() {
                _currentAddress = 'New Location (Manual)';
                _isEditingLocation = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _generateMockDrivers(double centerLat, double centerLng) {
    // Generate 5-10 mock drivers scattered around user
    final random = DateTime.now().millisecondsSinceEpoch;
    final markers = <Marker>{};

    for (int i = 0; i < 7; i++) {
      final latOffset = ((random + i * 13) % 100 - 50) / 10000.0;
      final lngOffset = ((random + i * 17) % 100 - 50) / 10000.0;

      markers.add(
        Marker(
          markerId: MarkerId('driver_$i'),
          position: LatLng(centerLat + latOffset, centerLng + lngOffset),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          flat: true,
          rotation: (random + i * 45) % 360.0,
        ),
      );
    }

    setState(() {
      _driverMarkers.addAll(markers);
    });
  }

  void _openMenu() {
    // Open drawer or navigate to menu
    // For now, just show a simple drawer
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/support');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openBookRide() {
    // Navigate to inDriver-style booking flow and show search immediately
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const InDriverBookRideComplete(showSearchImmediately: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FULL-SCREEN MAP (Primary element)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _centerPosition ?? const LatLng(-4.3217, 15.3125),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _driverMarkers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Loading indicator
          if (_isLoadingLocation)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            ),

          // 2. TOP BAR WITH LOCATION AND MENU
          SafeArea(
            child: Column(
              children: [
                // Location Bar
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Location Icon
                      Icon(
                        Icons.location_on,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      // Location Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Refresh Button
                      IconButton(
                        onPressed: _refreshLocation,
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        tooltip: 'Refresh Location',
                      ),
                      // Edit Button
                      IconButton(
                        onPressed: _isEditingLocation
                            ? _updateLocationManually
                            : _toggleEditLocation,
                        icon: Icon(
                          _isEditingLocation ? Icons.check : Icons.edit,
                          color: _isEditingLocation
                              ? Colors.green
                              : Colors.blue[700],
                          size: 20,
                        ),
                        tooltip: _isEditingLocation
                            ? 'Save Location'
                            : 'Edit Location',
                      ),
                    ],
                  ),
                ),
                // Menu Button (Top-right)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16, top: 8),
                    child: FloatingActionButton(
                      onPressed: _openMenu,
                      backgroundColor: Colors.white,
                      elevation: 6,
                      mini: true,
                      child: const Icon(
                        Icons.menu,
                        color: Color(0xFF424242),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. BOTTOM SEARCH CARD (Above bottom nav)
          Positioned(
            bottom: 72, // 60dp nav bar + 12dp spacing
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _openBookRide,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                    bottom: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 24,
                      color: Color(0xFF757575),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Where to?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
