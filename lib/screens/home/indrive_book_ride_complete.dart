import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/location_service.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'dart:async';
import 'dart:math' as math;

/// Complete inDriver-style ride booking with two states:
/// Screen 1: Search state with "Where to & for how much?"
/// Screen 2: Route confirmation with fare negotiation
class InDriverBookRideComplete extends StatefulWidget {
  final bool showSearchImmediately;
  final VoidCallback? onNavigateToAccount;

  const InDriverBookRideComplete({
    super.key,
    this.showSearchImmediately = false,
    this.onNavigateToAccount,
  });

  @override
  State<InDriverBookRideComplete> createState() =>
      _InDriverBookRideCompleteState();
}

class _InDriverBookRideCompleteState extends State<InDriverBookRideComplete> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  String _pickupAddress = '';
  String _dropoffAddress = '';

  bool _isScreen2 = false; // false = Screen 1 (search), true = Screen 2 (route)
  bool _isLoadingLocation = true;
  bool _isRequestActive = false;
  bool _autoAccept = false;
  String _selectedPaymentMethod = 'Cash'; // Default payment method

  double? _suggestedPrice;
  double? _distance; // in km
  int? _duration; // in minutes
  String? _customerId;
  String? _activeRequestId;
  String _userName = 'User';
  double _userRating = 0.0;

  int _passengerCount = 1;
  int _driversViewing = 0;
  Timer? _viewingCounterTimer;
  Timer? _searchTimeoutTimer;
  StreamSubscription? _offersSubscription;
  List<Map<String, dynamic>> _recentAddresses = [];
  List<Map<String, dynamic>> _driverOffers = [];

  final TextEditingController _priceController = TextEditingController();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeCustomer();
    _getCurrentLocation();
    _loadRecentAddresses();

    // Show destination search immediately if requested
    if (widget.showSearchImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDestinationSearch();
      });
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _viewingCounterTimer?.cancel();
    _searchTimeoutTimer?.cancel();
    _offersSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCustomer() async {
    _customerId = await SessionService.getUserIdStatic();
    if (_customerId != null) {
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', _customerId!)
            .single();

        print('🔍 Profile loaded for drawer: $profileResponse');

        if (mounted) {
          setState(() {
            _userName = profileResponse['full_name'] ??
                       profileResponse['name'] ??
                       'User';
            _userRating = (profileResponse['rating'] as num?)?.toDouble() ?? 0.0;
          });
        }
      } catch (e) {
        print('❌ Error loading user profile: $e');
      }
    }
  }

  Future<void> _loadRecentAddresses() async {
    if (_customerId == null) return;

    try {
      // Load recent destinations from database
      final response = await Supabase.instance.client
          .from('recent_destinations')
          .select()
          .eq('user_id', _customerId!)
          .order('last_visited_at', ascending: false)
          .limit(5);

      setState(() {
        _recentAddresses = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading recent addresses: $e');
    }
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

      // Reverse geocode
      final address = await LocationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _pickupAddress = address ?? 'Current Location';
        _isLoadingLocation = false;
      });

      // Update map
      _updateMapCamera();
      _updateMarkers();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _pickupAddress = 'Location unavailable';
        _isLoadingLocation = false;
      });
    }
  }

  void _updateMapCamera() {
    if (_mapController == null) return;

    if (_isScreen2 && _pickupLatLng != null && _dropoffLatLng != null) {
      // Screen 2: Fit both markers
      final bounds = _calculateBounds(_pickupLatLng!, _dropoffLatLng!);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } else if (_pickupLatLng != null) {
      // Screen 1: Center on pickup
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupLatLng!, 15),
      );
    }
  }

  LatLngBounds _calculateBounds(LatLng pos1, LatLng pos2) {
    return LatLngBounds(
      southwest: LatLng(
        math.min(pos1.latitude, pos2.latitude),
        math.min(pos1.longitude, pos2.longitude),
      ),
      northeast: LatLng(
        math.max(pos1.latitude, pos2.latitude),
        math.max(pos1.longitude, pos2.longitude),
      ),
    );
  }

  void _updateMarkers() {
    Set<Marker> markers = {};

    if (_pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (_dropoffLatLng != null && _isScreen2) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _drawRoute() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) return;

    try {
      final routeInfo = await LocationService.calculateRoute(
        _pickupLatLng!.latitude,
        _pickupLatLng!.longitude,
        _dropoffLatLng!.latitude,
        _dropoffLatLng!.longitude,
      );

      if (routeInfo != null) {
        // Get polyline points (you'll need to decode the polyline from directions API)
        // For now, draw a simple line
        setState(() {
          _distance = (routeInfo['distanceMeters'] ?? 0) / 1000; // Convert to km
          _duration = ((routeInfo['durationSeconds'] ?? 0) / 60).round();

          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [_pickupLatLng!, _dropoffLatLng!],
              color: Colors.blue,
              width: 4,
            ),
          };
        });

        // Calculate suggested price
        _calculateSuggestedPrice();
      }
    } catch (e) {
      print('Error drawing route: $e');
    }
  }

  void _calculateSuggestedPrice() {
    if (_distance == null) return;

    // Basic fare calculation: Base fare + distance rate
    const baseFare = 10.0;
    const perKmRate = 3.0;

    final calculatedPrice = baseFare + (_distance! * perKmRate);

    setState(() {
      _suggestedPrice = (calculatedPrice / 3).round() * 3; // Round to nearest 3
      _priceController.text = _suggestedPrice!.toStringAsFixed(0);
    });
  }

  void _increasePrice() {
    setState(() {
      final current = double.tryParse(_priceController.text) ?? _suggestedPrice ?? 0;
      final newPrice = current + 3;
      _priceController.text = newPrice.toStringAsFixed(0);
    });
  }

  void _decreasePrice() {
    setState(() {
      final current = double.tryParse(_priceController.text) ?? _suggestedPrice ?? 0;
      if (current > 3) {
        final newPrice = current - 3;
        _priceController.text = newPrice.toStringAsFixed(0);
      }
    });
  }

  void _showPriceEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Your Fare'),
        content: TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefix: Text('\$'),
            hintText: 'Enter amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDestination(String address, double lat, double lng) async {
    setState(() {
      _dropoffAddress = address;
      _dropoffLatLng = LatLng(lat, lng);
      _isScreen2 = true;
    });

    _updateMarkers();
    await _drawRoute();
    _updateMapCamera();
  }

  void _goBackToSearch() {
    setState(() {
      _isScreen2 = false;
      _dropoffAddress = '';
      _dropoffLatLng = null;
      _suggestedPrice = null;
      _distance = null;
      _duration = null;
      _polylines = {};
    });
    _updateMarkers();
    _updateMapCamera();
  }

  Future<void> _findDriver() async {
    if (_customerId == null || _pickupLatLng == null || _dropoffLatLng == null) return;

    final price = double.tryParse(_priceController.text) ?? _suggestedPrice ?? 0;

    try {
      final response = await Supabase.instance.client
          .from('ride_requests')
          .insert({
        'customer_id': _customerId,
        'pickup_address': _pickupAddress,
        'pickup_latitude': _pickupLatLng!.latitude,
        'pickup_longitude': _pickupLatLng!.longitude,
        'dropoff_address': _dropoffAddress,
        'dropoff_latitude': _dropoffLatLng!.latitude,
        'dropoff_longitude': _dropoffLatLng!.longitude,
        'proposed_price': price,
        'status': 'pending',
      }).select();

      if (response.isNotEmpty) {
        setState(() {
          _isRequestActive = true;
          _activeRequestId = response[0]['id'];
        });

        _startDriverViewingCounter();
        _subscribeToDriverOffers();

        // Start 2-minute timeout
        _searchTimeoutTimer = Timer(
          const Duration(minutes: 2),
          () => _showTimeoutDialog(),
        );

        // Save to recent destinations
        if (_customerId != null) {
          try {
            await Supabase.instance.client.rpc('upsert_recent_destination', params: {
              'p_user_id': _customerId!,
              'p_address': _dropoffAddress,
              'p_latitude': _dropoffLatLng!.latitude,
              'p_longitude': _dropoffLatLng!.longitude,
            });
          } catch (e) {
            print('Error saving recent destination: $e');
          }
        }

        CustomToast.showSuccess(
          context: context,
          message: 'Finding drivers...',
        );
      }
    } catch (e) {
      print('Error creating ride request: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to create request. Please try again.',
      );
    }
  }

  void _startDriverViewingCounter() {
    // Query REAL driver view count from database
    _viewingCounterTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        if (_activeRequestId == null) {
          timer.cancel();
          return;
        }

        try {
          // Count unique drivers who have viewed this ride request
          final response = await Supabase.instance.client
              .from('ride_request_views')
              .select('driver_id')
              .eq('ride_request_id', _activeRequestId!);

          if (mounted) {
            setState(() {
              _driversViewing = response.length;
            });
          }
        } catch (e) {
          print('Error fetching driver view count: $e');
          // If table doesn't exist yet, keep counter at 0
        }
      },
    );
  }

  void _subscribeToDriverOffers() {
    // Subscribe to real-time driver offers
    // Implementation would go here
  }

  void _cancelRequest() {
    setState(() {
      _isRequestActive = false;
      _activeRequestId = null;
      _driversViewing = 0;
    });
    _viewingCounterTimer?.cancel();
    _searchTimeoutTimer?.cancel();
    _offersSubscription?.cancel();
  }

  void _showTimeoutDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No drivers available yet'),
        content: const Text(
          'We haven\'t found a driver for your request yet. Would you like to continue searching or increase your price to attract more drivers?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Continue searching - restart the 2-minute timer
              _searchTimeoutTimer = Timer(
                const Duration(minutes: 2),
                () => _showTimeoutDialog(),
              );

              if (mounted) {
                CustomToast.showSuccess(
                  context: context,
                  message: 'Continuing search...',
                );
              }
            },
            child: const Text('Continue Searching'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPriceIncreaseDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF76FF03),
              foregroundColor: Colors.black,
            ),
            child: const Text('Increase Price'),
          ),
        ],
      ),
    );
  }

  void _showPriceIncreaseDialog() {
    if (!mounted) return;

    final currentPrice = double.tryParse(_priceController.text) ?? _suggestedPrice ?? 0;
    final suggestedIncrease = (currentPrice * 0.2).round().toDouble(); // 20% increase
    final newPrice = currentPrice + suggestedIncrease;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Increase Your Fare'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current fare: \$${currentPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Suggested increase: +\$${suggestedIncrease.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New fare: \$${newPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Increasing your fare can help attract more drivers.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Update the price
              setState(() {
                _priceController.text = newPrice.toStringAsFixed(0);
              });

              // Update the ride request in database
              try {
                await Supabase.instance.client
                    .from('ride_requests')
                    .update({'proposed_price': newPrice})
                    .eq('id', _activeRequestId!);

                // Restart the search timer
                _searchTimeoutTimer = Timer(
                  const Duration(minutes: 2),
                  () => _showTimeoutDialog(),
                );

                if (mounted) {
                  CustomToast.showSuccess(
                    context: context,
                    message: 'Price increased! Searching with new fare...',
                  );
                }
              } catch (e) {
                print('Error updating price: $e');
                if (mounted) {
                  CustomToast.showError(
                    context: context,
                    message: 'Failed to update price. Please try again.',
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF76FF03),
              foregroundColor: Colors.black,
            ),
            child: const Text('Increase & Search'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Payment Method',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Payment methods
            _buildPaymentOption(
              icon: Icons.money,
              title: 'Cash',
              subtitle: 'Pay with cash after ride',
            ),
            _buildPaymentOption(
              icon: Icons.phone_android,
              title: 'M-Pesa',
              subtitle: 'Mobile money payment',
            ),
            _buildPaymentOption(
              icon: Icons.phone_android,
              title: 'Orange Money',
              subtitle: 'Mobile money payment',
            ),
            _buildPaymentOption(
              icon: Icons.phone_android,
              title: 'Airtel Money',
              subtitle: 'Mobile money payment',
            ),
            _buildPaymentOption(
              icon: Icons.credit_card,
              title: 'Card',
              subtitle: 'Debit or credit card',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedPaymentMethod == title;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.green : Colors.grey[600],
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.green : Colors.black87,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _selectedPaymentMethod = title;
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLatLng ?? const LatLng(-4.3217, 15.3125),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapCamera();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Screen 1: Search bar overlay
          if (!_isScreen2) _buildScreen1SearchOverlay(),

          // Screen 2: Address card and ride options
          if (_isScreen2) _buildScreen2RouteOverlay(),

          // Active request overlay
          if (_isRequestActive) _buildActiveRequestOverlay(),
        ],
      ),
    );
  }

  Widget _buildScreen1SearchOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Menu hamburger icon
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () => _showMenuDrawer(),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Floating search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showDestinationSearch(),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 28, color: Colors.grey),
                    const SizedBox(width: 16),
                    Text(
                      'Where to & for how much?',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Service selection - Ride only
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ride',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildScreen2RouteOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Address confirmation card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Pickup row
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Entrance',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dropoff row
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$_dropoffAddress ${_duration != null ? "~$_duration min" : ""}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Back button
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: _goBackToSearch,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Ride options bottom sheet
          _buildRideOptionsSheet(),
        ],
      ),
    );
  }

  Widget _buildRideOptionsSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section 1: Ride details
          Row(
            children: [
              const Icon(Icons.directions_car, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ride',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Affordable rides',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$_passengerCount • ${_duration ?? 0} min',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 18, color: Colors.grey),
            ],
          ),

          const SizedBox(height: 20),

          // Section 2: Fare negotiation
          GestureDetector(
            onTap: _showPriceEditDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove, size: 20),
                    ),
                    onPressed: _decreasePrice,
                  ),
                  Expanded(
                    child: Text(
                      _priceController.text.isEmpty
                          ? 'Tap to offer your fare'
                          : '\$${_priceController.text}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _priceController.text.isEmpty ? 15 : 24,
                        fontWeight: _priceController.text.isEmpty
                            ? FontWeight.w500
                            : FontWeight.bold,
                        color: _priceController.text.isEmpty
                            ? Colors.grey[700]
                            : Colors.green,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 20),
                    ),
                    onPressed: _increasePrice,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Section 3: Auto-accept option
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.near_me, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Automatically accept the nearest driver for your fare',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Switch(
                  value: _autoAccept,
                  onChanged: (value) => setState(() => _autoAccept = value),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment method display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPaymentMethod == 'Cash'
                      ? Icons.money
                      : _selectedPaymentMethod == 'Card'
                          ? Icons.credit_card
                          : Icons.phone_android,
                  size: 20,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedPaymentMethod,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showPaymentMethodSelector,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 4: Find a driver button
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _findDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF76FF03), // Lime green
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Find a driver',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.payment),
                  onPressed: _showPaymentMethodSelector,
                  tooltip: _selectedPaymentMethod,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestOverlay() {
    return Positioned(
      bottom: 32,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '$_driversViewing ${_driversViewing == 1 ? "driver" : "drivers"} viewing your request',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for offers...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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
    );
  }

  void _showMenuDrawer() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
        child: SafeArea(
          child: Column(
          children: [
            // Profile section
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFF5F5F5),
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name and "My account"
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onNavigateToAccount?.call();
                          },
                          child: const Text(
                            'My account',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF00C853), // Green
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rating
            if (_userRating > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Color(0xFF00C853),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_userRating.toStringAsFixed(2)} Rating',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerMenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Payment',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to payment
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'My Rides',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to rides history
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.shield_outlined,
                    title: 'Safety',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to safety
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.help_outline,
                    title: 'Support',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/support');
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to about
                    },
                  ),
                ],
              ),
            ),

            // Become a driver banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1), // Light green
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Become a driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Earn money on your schedule',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _showDestinationSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DestinationSearchSheet(
        recentAddresses: _recentAddresses,
        onSelectDestination: _selectDestination,
      ),
    );
  }
}

// Destination search bottom sheet
class _DestinationSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> recentAddresses;
  final Function(String, double, double) onSelectDestination;

  const _DestinationSearchSheet({
    required this.recentAddresses,
    required this.onSelectDestination,
  });

  @override
  State<_DestinationSearchSheet> createState() =>
      _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<_DestinationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _savedPlaces = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    try {
      final userId = await SessionService.getUserIdStatic();
      if (userId != null) {
        final response = await Supabase.instance.client
            .from('saved_places')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _savedPlaces = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      print('Error loading saved places: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Search saved places by name
      final matchingSavedPlaces = _savedPlaces.where((place) {
        final name = place['name']?.toString().toLowerCase() ?? '';
        final address = place['address']?.toString().toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        return name.contains(queryLower) || address.contains(queryLower);
      }).map((place) => {
        'description': '${place['name']} - ${place['address']}',
        'place_id': 'saved_${place['id']}',
        'is_saved_place': true,
        'latitude': place['latitude'],
        'longitude': place['longitude'],
        'name': place['name'],
        'icon': place['icon'],
      }).toList();

      // Search online places
      final onlineResults = await LocationService.searchPlaces(query);

      setState(() {
        // Combine saved places and online results (saved places first)
        _searchResults = [...matchingSavedPlaces, ...onlineResults];
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
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
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _performSearch,
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.isEmpty
                        ? widget.recentAddresses.length
                        : _searchResults.length,
                    itemBuilder: (context, index) {
                      final isRecent = _searchResults.isEmpty;
                      final item = isRecent
                          ? widget.recentAddresses[index]
                          : _searchResults[index];

                      return ListTile(
                        leading: Icon(
                          isRecent ? Icons.access_time : Icons.location_on,
                          color: Colors.grey[600],
                        ),
                        title: Text(item['address'] ?? item['name'] ?? ''),
                        subtitle: isRecent ? null : Text(item['address'] ?? ''),
                        onTap: () {
                          widget.onSelectDestination(
                            item['address'] ?? item['name'] ?? '',
                            item['latitude'],
                            item['longitude'],
                          );
                          Navigator.pop(context);
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
