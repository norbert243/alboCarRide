import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:albocarride/services/location_service.dart';
import 'package:albocarride/screens/home/name_saved_place_page.dart';
import 'dart:async';

/// Step 1 of Add Saved Place flow: Map search with center pin
/// User can search for address or drag map to select location
class AddSavedPlacePage extends StatefulWidget {
  final Map<String, dynamic>? existingPlace;

  const AddSavedPlacePage({
    super.key,
    this.existingPlace,
  });

  @override
  State<AddSavedPlacePage> createState() => _AddSavedPlacePageState();
}

class _AddSavedPlacePageState extends State<AddSavedPlacePage> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng? _currentCenter;
  String _selectedAddress = '';
  bool _isGeocodingAddress = false;
  bool _isLoadingLocation = true;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    // If editing, set initial location
    if (widget.existingPlace != null) {
      _currentCenter = LatLng(
        widget.existingPlace!['latitude'],
        widget.existingPlace!['longitude'],
      );
      _selectedAddress = widget.existingPlace!['address'] ?? '';
      _searchController.text = _selectedAddress;
      _isLoadingLocation = false;
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final center = LatLng(position.latitude, position.longitude);
      final address = await LocationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentCenter = center;
          _selectedAddress = address ?? 'Current Location';
          _searchController.text = _selectedAddress;
          _isLoadingLocation = false;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(center, 16),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _currentCenter = const LatLng(-4.3217, 15.3125); // Kinshasa default
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _onCameraMove(CameraPosition position) async {
    _currentCenter = position.target;

    // Debounce reverse geocoding
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocodeCenter();
    });
  }

  Future<void> _reverseGeocodeCenter() async {
    if (_currentCenter == null || _isGeocodingAddress) return;

    setState(() {
      _isGeocodingAddress = true;
    });

    try {
      final address = await LocationService.reverseGeocode(
        _currentCenter!.latitude,
        _currentCenter!.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = address ?? 'Unknown location';
          _searchController.text = _selectedAddress;
          _isGeocodingAddress = false;
        });
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
      if (mounted) {
        setState(() {
          _isGeocodingAddress = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final results = await LocationService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      print('Search error: $e');
    }
  }

  void _selectSearchResult(Map<String, dynamic> place) {
    final lat = place['latitude'] as double;
    final lng = place['longitude'] as double;
    final address = place['address'] ?? place['name'] ?? '';

    setState(() {
      _currentCenter = LatLng(lat, lng);
      _selectedAddress = address;
      _searchController.text = address;
      _searchResults = [];
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );
  }

  void _confirmLocation() {
    if (_currentCenter == null || _selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    // Navigate to Step 2: Name & Icon selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NameSavedPlacePage(
          address: _selectedAddress,
          latitude: _currentCenter!.latitude,
          longitude: _currentCenter!.longitude,
          existingPlace: widget.existingPlace, // Pass existing place for editing
        ),
      ),
    ).then((result) {
      // If place was saved successfully, pop back to Account Details
      if (result == true) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF424242)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add place',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        ),
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter ?? const LatLng(-4.3217, 15.3125),
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Center pin (fixed in center of screen)
          Center(
            child: Icon(
              Icons.location_pin,
              size: 48,
              color: const Color(0xFF2196F3),
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),

          // Search bar at top
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
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
                        const Padding(
                          padding: EdgeInsets.only(left: 16, right: 12),
                          child: Icon(
                            Icons.search,
                            size: 20,
                            color: Color(0xFF757575),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search for address...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF757575),
                              ),
                            ),
                            onChanged: (value) {
                              _debounceTimer?.cancel();
                              _debounceTimer = Timer(
                                const Duration(milliseconds: 300),
                                () => _performSearch(value),
                              );
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 20,
                              color: Color(0xFF757575),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Autocomplete results
                if (_searchResults.isNotEmpty)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              size: 20,
                              color: Color(0xFF757575),
                            ),
                            title: Text(
                              place['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              place['address'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => _selectSearchResult(place),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Confirm button at bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _isGeocodingAddress ? null : _confirmLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                disabledBackgroundColor: const Color(0xFFE0E0E0),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF9E9E9E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
              ),
              child: _isGeocodingAddress
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
