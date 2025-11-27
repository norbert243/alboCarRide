import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/location_service.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'dart:async';

/// inDriver/Bolt style ride booking - full screen map with overlays
class InDriverStyleBookRide extends StatefulWidget {
  const InDriverStyleBookRide({super.key});

  @override
  State<InDriverStyleBookRide> createState() => _InDriverStyleBookRideState();
}

class _InDriverStyleBookRideState extends State<InDriverStyleBookRide> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _pickupAddress = 'Detecting your location...';
  String _dropoffAddress = '';
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  double _suggestedPrice = 25.0; // Default starting price
  bool _isLoadingLocation = true;
  bool _isRequestActive = false;
  String? _customerId;
  String? _activeRequestId;
  int _driversViewing = 0;
  List<Map<String, dynamic>> _driverOffers = [];
  Timer? _viewingCounterTimer;
  StreamSubscription? _offersSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCustomer();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _viewingCounterTimer?.cancel();
    _offersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeCustomer() async {
    _customerId = await SessionService.getUserIdStatic();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _pickupLatLng = LatLng(position.latitude, position.longitude);
      });

      // Reverse geocode to get address
      final address = await LocationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _pickupAddress = address ?? 'Current Location';
        _isLoadingLocation = false;
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupLatLng!, 15),
      );
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _pickupAddress = 'Unable to detect location';
        _isLoadingLocation = false;
      });
    }
  }

  void _increasePrice() {
    setState(() {
      _suggestedPrice += 3;
    });
  }

  void _decreasePrice() {
    setState(() {
      if (_suggestedPrice > 3) {
        _suggestedPrice -= 3;
      }
    });
  }

  Future<void> _showWhereToSearch() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WhereToSearchSheet(currentLocation: _pickupLatLng),
    );

    if (result != null) {
      setState(() {
        _dropoffAddress = result['address'];
        _dropoffLatLng = result['latlng'];
      });

      // Update map to show both pickup and dropoff
      if (_pickupLatLng != null && _dropoffLatLng != null) {
        _updateMapBounds();
      }
    }
  }

  void _updateMapBounds() {
    if (_pickupLatLng == null || _dropoffLatLng == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickupLatLng!.latitude < _dropoffLatLng!.latitude
            ? _pickupLatLng!.latitude
            : _dropoffLatLng!.latitude,
        _pickupLatLng!.longitude < _dropoffLatLng!.longitude
            ? _pickupLatLng!.longitude
            : _dropoffLatLng!.longitude,
      ),
      northeast: LatLng(
        _pickupLatLng!.latitude > _dropoffLatLng!.latitude
            ? _pickupLatLng!.latitude
            : _dropoffLatLng!.latitude,
        _pickupLatLng!.longitude > _dropoffLatLng!.longitude
            ? _pickupLatLng!.longitude
            : _dropoffLatLng!.longitude,
      ),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _findDriver() async {
    if (_dropoffAddress.isEmpty) {
      CustomToast.showError(
        context: context,
        message: 'Please select your destination',
      );
      return;
    }

    if (_customerId == null) return;

    try {
      // Create ride request
      final response =
          await Supabase.instance.client.from('ride_requests').insert({
            'customer_id': _customerId,
            'pickup_location': _pickupAddress,
            'pickup_latitude': _pickupLatLng!.latitude,
            'pickup_longitude': _pickupLatLng!.longitude,
            'dropoff_location': _dropoffAddress,
            'dropoff_latitude': _dropoffLatLng!.latitude,
            'dropoff_longitude': _dropoffLatLng!.longitude,
            'suggested_price': _suggestedPrice,
            'status': 'pending',
          }).select();

      if (response.isNotEmpty) {
        setState(() {
          _isRequestActive = true;
          _activeRequestId = response[0]['id'];
        });

        // Start monitoring driver views and offers
        _startDriverViewingCounter();
        _subscribeToDriverOffers();

        CustomToast.showSuccess(
          context: context,
          message: 'Finding drivers...',
        );
      }
    } catch (e) {
      print('Error creating ride request: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to create ride request',
      );
    }
  }

  void _startDriverViewingCounter() {
    _viewingCounterTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (_activeRequestId == null) {
        timer.cancel();
        return;
      }

      // Simulate driver viewing count (in production, get from realtime)
      // This would be tracked when drivers view the request
      setState(() {
        _driversViewing = (DateTime.now().second % 7) + 1; // Demo: 1-7 drivers
      });
    });
  }

  void _subscribeToDriverOffers() {
    if (_activeRequestId == null) return;

    try {
      final channel = Supabase.instance.client.channel(
        'driver_offers_${_activeRequestId}',
      );

      _offersSubscription =
          channel
                  .onPostgresChanges(
                    event: PostgresChangeEvent.insert,
                    schema: 'public',
                    table: 'ride_offers',
                    filter: PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'ride_request_id',
                      value: _activeRequestId,
                    ),
                    callback: (payload) {
                      if (mounted) {
                        _loadDriverOffer(payload.newRecord['id']);
                      }
                    },
                  )
                  .subscribe()
              as StreamSubscription?;
    } catch (e) {
      print('Error subscribing to driver offers: $e');
    }
  }

  Future<void> _loadDriverOffer(String offerId) async {
    try {
      final response = await Supabase.instance.client
          .from('ride_offers')
          .select('''
            *,
            driver:profiles!ride_offers_driver_id_fkey(
              full_name,
              rating
            ),
            driver_details:drivers!ride_offers_driver_id_fkey(
              vehicle_type,
              license_plate
            )
          ''')
          .eq('id', offerId)
          .single();

      if (mounted) {
        setState(() {
          _driverOffers.add(response);
        });
      }

      // Show offer bottom sheet
      _showDriverOfferSheet(response);
    } catch (e) {
      print('Error loading driver offer: $e');
    }
  }

  void _showDriverOfferSheet(Map<String, dynamic> offer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => _DriverOfferSheet(
        offer: offer,
        pickupLocation: _pickupLatLng!,
        onAccept: () {
          _acceptOffer(offer['id']);
          Navigator.pop(context);
        },
        onDecline: () {
          _declineOffer(offer['id']);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      // Accept the offer and create trip
      await Supabase.instance.client.rpc(
        'accept_ride_offer',
        params: {'p_offer_id': offerId},
      );

      CustomToast.showSuccess(
        context: context,
        message: 'Driver accepted! Preparing your trip...',
      );

      // Navigate to trip tracking
      Navigator.pop(context);
    } catch (e) {
      print('Error accepting offer: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to accept offer',
      );
    }
  }

  Future<void> _declineOffer(String offerId) async {
    try {
      await Supabase.instance.client
          .from('ride_offers')
          .update({'status': 'declined'})
          .eq('id', offerId);
    } catch (e) {
      print('Error declining offer: $e');
    }
  }

  void _cancelRequest() {
    setState(() {
      _isRequestActive = false;
      _activeRequestId = null;
      _driversViewing = 0;
      _driverOffers.clear();
    });
    _viewingCounterTimer?.cancel();
    _offersSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  _pickupLatLng ??
                  const LatLng(-4.3217, 15.3125), // Kinshasa default
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_pickupLatLng != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(_pickupLatLng!),
                );
              }
            },
            markers: {
              if (_pickupLatLng != null)
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: _pickupLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              if (_dropoffLatLng != null)
                Marker(
                  markerId: const MarkerId('dropoff'),
                  position: _dropoffLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Top overlay - Pickup and Dropoff
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Pickup location (auto-detected)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickupAddress,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoadingLocation)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Where to? (Dropoff)
                InkWell(
                  onTap: _showWhereToSearch,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dropoffAddress.isEmpty
                                ? 'Where to?'
                                : _dropoffAddress,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _dropoffAddress.isEmpty
                                  ? Colors.grey[600]
                                  : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.search, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom overlay - Price and Find Driver
          if (!_isRequestActive && _dropoffAddress.isNotEmpty)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Price selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _decreasePrice,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove, size: 20),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          '\$${_suggestedPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          onPressed: _increasePrice,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your offer',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),

                    // Find Driver button
                    ElevatedButton(
                      onPressed: _findDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Find a Driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Active request overlay - Drivers viewing
          if (_isRequestActive)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '$_driversViewing ${_driversViewing == 1 ? 'driver' : 'drivers'} viewing your request',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for offers...',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _cancelRequest,
                      child: const Text(
                        'Cancel Request',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Where to search bottom sheet
class _WhereToSearchSheet extends StatefulWidget {
  final LatLng? currentLocation;

  const _WhereToSearchSheet({this.currentLocation});

  @override
  State<_WhereToSearchSheet> createState() => _WhereToSearchSheetState();
}

class _WhereToSearchSheetState extends State<_WhereToSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() => _suggestions = []);
      }
      return;
    }

    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      final results = await LocationService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search destination...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (mounted) {
                            setState(() => _suggestions = []);
                          }
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchLocation,
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final place = _suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(place['name'] ?? ''),
                        subtitle: Text(place['address'] ?? ''),
                        onTap: () {
                          Navigator.pop(context, {
                            'address': place['address'] ?? place['name'],
                            'latlng': LatLng(
                              place['latitude'],
                              place['longitude'],
                            ),
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Driver offer bottom sheet
class _DriverOfferSheet extends StatelessWidget {
  final Map<String, dynamic> offer;
  final LatLng pickupLocation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _DriverOfferSheet({
    required this.offer,
    required this.pickupLocation,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = offer['driver']?['full_name'] ?? 'Driver';
    final driverRating = offer['driver']?['rating']?.toDouble() ?? 0.0;
    final vehicleType = offer['driver_details']?['vehicle_type'] ?? 'Sedan';
    final offerPrice = offer['offer_price']?.toDouble() ?? 0.0;
    final distance = 2.5; // Calculate actual distance in production

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Driver info
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue,
                child: Text(
                  driverName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          driverRating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          vehicleType,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${distance.toStringAsFixed(1)} km',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Offer price
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Offer: ', style: TextStyle(fontSize: 16)),
                Text(
                  '\$${offerPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
