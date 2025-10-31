import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';
import 'custom_toast.dart';

/// Widget that displays all available ride requests for drivers to select from
class AvailableRidesWidget extends StatefulWidget {
  final Position? driverLocation;
  const AvailableRidesWidget({super.key, this.driverLocation});

  @override
  State<AvailableRidesWidget> createState() => _AvailableRidesWidgetState();
}

class _AvailableRidesWidgetState extends State<AvailableRidesWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _availableRides = [];
  bool _isLoading = false;
  String? _driverId;
  StreamSubscription<List<Map<String, dynamic>>>? _rideRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDriverIdAndSubscribe();
  }

  @override
  void dispose() {
    _rideRequestsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDriverIdAndSubscribe() async {
    _driverId = await SessionService.getUserIdStatic();
    if (_driverId != null) {
      _subscribeToRideRequests();
    }
  }

  void _subscribeToRideRequests() {
    _loadAvailableRides(); 

    _rideRequestsSubscription = _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .listen((_) => _loadAvailableRides());
  }

  Future<void> _loadAvailableRides() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rideRequests = await _supabase
          .from('ride_requests')
          .select(
            '''
              id,
              pickup_location,
              pickup_latitude,
              pickup_longitude,
              dropoff_location,
              dropoff_latitude,
              dropoff_longitude,
              estimated_fare,
              suggested_price,
              notes,
              created_at,
              customer_id,
              status,
              driver_id
            '''
          )
          .eq('status', 'pending')
          .isFilter('driver_id', null)
          .order('created_at', ascending: false);

      final pendingRides = rideRequests.where((ride) =>
              ride['status'] == 'pending' &&
              ride['driver_id'] == null
          ).toList();

      final List<Map<String, dynamic>> ridesWithCustomerInfo = [];
      for (var ride in pendingRides) {
        final customerProfile = await _supabase
            .from('profiles')
            .select('full_name, phone_number')
            .eq('id', ride['customer_id'])
            .single();
        ridesWithCustomerInfo.add({
          ...ride,
          'customer_name': customerProfile['full_name'] ?? 'Unknown Customer',
          'customer_phone': customerProfile['phone_number'] ?? '',
          'pickup_latitude': ride['pickup_latitude'] as double?,
          'pickup_longitude': ride['pickup_longitude'] as double?,
          'dropoff_latitude': ride['dropoff_latitude'] as double?,
          'dropoff_longitude': ride['dropoff_longitude'] as double?,
        });
      }

      if (mounted) {
        setState(() {
          _availableRides = ridesWithCustomerInfo;
        });
      }
    } catch (e) {
      print('Error loading available rides: $e');
      if (mounted) {
        CustomToast.showError(context: context, message: 'Error loading rides');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectRide(Map<String, dynamic> ride) async {
    final customerPrice = ride['suggested_price'] ?? ride['estimated_fare'] ?? 0.0;

    // Show dialog with accept or counter-offer options
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RideOfferDialog(
        ride: ride,
        customerPrice: customerPrice,
      ),
    );

    if (result != null) {
      if (result['action'] == 'accept') {
        await _acceptRideAtCustomerPrice(ride);
      } else if (result['action'] == 'counter') {
        await _sendCounterOffer(ride, result['price']);
      }
    }
  }

  Future<void> _acceptRideAtCustomerPrice(Map<String, dynamic> ride) async {
    setState(() => _isLoading = true);

    try {
      final customerPrice = ride['suggested_price'] ?? ride['estimated_fare'] ?? 0.0;

      // Create an offer at the customer's price
      final offerResponse = await _supabase.from('ride_offers').insert({
        'ride_request_id': ride['id'],
        'driver_id': _driverId,
        'offer_price': customerPrice,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (offerResponse.isNotEmpty) {
        // Immediately accept the offer and create trip
        final tripResponse = await _supabase.from('trips').insert({
          'customer_id': ride['customer_id'],
          'driver_id': _driverId,
          'pickup_location': ride['pickup_location'],
          'dropoff_location': ride['dropoff_location'],
          'final_price': customerPrice,
          'status': 'accepted',
          'start_time': DateTime.now().toIso8601String(),
        }).select();

        if (tripResponse.isNotEmpty) {
          // Update offer status
          await _supabase
              .from('ride_offers')
              .update({'status': 'accepted'})
              .eq('id', offerResponse[0]['id']);

          // Update ride request status
          await _supabase
              .from('ride_requests')
              .update({'status': 'accepted'})
              .eq('id', ride['id']);

          CustomToast.showSuccess(
            context: context,
            message: 'Ride accepted! Trip created at \$${customerPrice.toStringAsFixed(2)}',
          );
        }
      }
    } catch (e) {
      print('Error accepting ride: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to accept ride: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendCounterOffer(Map<String, dynamic> ride, double counterPrice) async {
    setState(() => _isLoading = true);

    try {
      // Create a counter-offer
      final offerResponse = await _supabase.from('ride_offers').insert({
        'ride_request_id': ride['id'],
        'driver_id': _driverId,
        'offer_price': counterPrice,
        'status': 'countered',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (offerResponse.isNotEmpty) {
        // Update ride request status to show there are offers
        await _supabase
            .from('ride_requests')
            .update({'status': 'offered'})
            .eq('id', ride['id']);

        CustomToast.showSuccess(
          context: context,
          message: 'Counter-offer sent at \$${counterPrice.toStringAsFixed(2)}',
        );
      }
    } catch (e) {
      print('Error sending counter-offer: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to send counter-offer: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    setState(() => _isLoading = true);

    try {
      // Create a trip from the ride request
      final tripResponse = await _supabase.from('trips').insert({
        'customer_id': ride['customer_id'],
        'driver_id': _driverId,
        'pickup_location': ride['pickup_location'],
        'dropoff_location': ride['dropoff_location'],
        'final_price': ride['suggested_price'] ?? ride['estimated_fare'],
        'status': 'accepted',
        'start_time': DateTime.now().toIso8601String(),
      }).select();

      if (tripResponse.isNotEmpty) {
        // Update ride request status
        await _supabase
            .from('ride_requests')
            .update({'status': 'accepted'})
            .eq('id', ride['id']);

        CustomToast.showSuccess(
          context: context,
          message: 'Ride accepted! Trip created.',
        );

        // Reload available rides
        await _loadAvailableRides();
      }
    } catch (e) {
      print('Error accepting ride: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to accept ride: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimeAgo(String createdAt) {
    final now = DateTime.now();
    final dateTime = DateTime.parse(createdAt);
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final price = ride['suggested_price'] ?? ride['estimated_fare'] ?? 0.0;

    String distanceText = '';
    if (widget.driverLocation != null && ride['pickup_latitude'] != null && ride['pickup_longitude'] != null) {
      final distance = LocationService.calculateDistance(
        widget.driverLocation!.latitude,
        widget.driverLocation!.longitude,
        ride['pickup_latitude'],
        ride['pickup_longitude'],
      );
      distanceText = '${distance.toStringAsFixed(1)} miles away';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride['customer_name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (ride['customer_phone'] != null &&
                          (ride['customer_phone'] as String).isNotEmpty)
                        Text(
                          ride['customer_phone'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.location_on_outlined,
              'From',
              ride['pickup_location'],
            ),
            _buildLocationRow(
              Icons.flag_outlined,
              'To',
              ride['dropoff_location'],
            ),
            if (distanceText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.alt_route, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      distanceText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            if (ride['notes'] != null && (ride['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride['notes'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeAgo(ride['created_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _selectRide(ride),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String location) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: location),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _availableRides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableRides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Available Rides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New ride requests will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAvailableRides,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableRides.length,
        itemBuilder: (context, index) => _buildRideCard(_availableRides[index]),
      ),
    );
  }
}

/// Dialog for driver to accept customer's price or make a counter-offer
class _RideOfferDialog extends StatefulWidget {
  final Map<String, dynamic> ride;
  final double customerPrice;

  const _RideOfferDialog({
    required this.ride,
    required this.customerPrice,
  });

  @override
  State<_RideOfferDialog> createState() => _RideOfferDialogState();
}

class _RideOfferDialogState extends State<_RideOfferDialog> {
  final _counterPriceController = TextEditingController();
  bool _showCounterOffer = false;

  @override
  void initState() {
    super.initState();
    // Set default counter-offer to 10% higher than customer's price
    _counterPriceController.text =
        (widget.customerPrice * 1.1).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _counterPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ride Request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${widget.ride['customer_name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.ride['pickup_location'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.ride['dropoff_location'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withAlpha(51)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Customer\'s Offered Price',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${widget.customerPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.ride['notes'] != null &&
                (widget.ride['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_outlined, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.ride['notes'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_showCounterOffer) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Your Counter-Offer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _counterPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Your Price',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Enter your counter-offer price',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_showCounterOffer) ...[
          OutlinedButton(
            onPressed: () {
              setState(() {
                _showCounterOffer = true;
              });
            },
            child: const Text('Counter-Offer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'action': 'accept',
                'price': widget.customerPrice,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept Price'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(_counterPriceController.text);
              if (price != null && price >= 3.0) {
                Navigator.pop(context, {
                  'action': 'counter',
                  'price': price,
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price (minimum \$3.00)'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Counter-Offer'),
          ),
        ],
      ],
    );
  }
}
