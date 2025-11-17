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
        });
      }
    }
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
        builder: (context) => const InDriverBookRideComplete(
          showSearchImmediately: true,
        ),
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
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
              ),
            ),

          // 2. FLOATING MENU BUTTON (Top-left overlay)
          SafeArea(
            child: Positioned(
              top: 16,
              left: 16,
              child: FloatingActionButton(
                onPressed: _openMenu,
                backgroundColor: Colors.white,
                elevation: 6,
                child: const Icon(
                  Icons.menu,
                  color: Color(0xFF424242),
                  size: 24,
                ),
              ),
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
