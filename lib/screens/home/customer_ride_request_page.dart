import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/session_service.dart';
import '../../services/ride_request_service.dart';
import '../../services/location_service.dart';
import '../../services/driver_location_service.dart';
import '../../widgets/custom_toast.dart';

class CustomerRideRequestPage extends StatefulWidget {
  const CustomerRideRequestPage({super.key});

  @override
  State<CustomerRideRequestPage> createState() =>
      _CustomerRideRequestPageState();
}

class _CustomerRideRequestPageState extends State<CustomerRideRequestPage> {
  final RideRequestService _requestService = RideRequestService(
    Supabase.instance.client,
  );
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isEstimating = false;
  String? _riderId;
  List<Map<String, dynamic>> _activeRequests = [];
  double _estimatedPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeRider();
  }

  Future<void> _initializeRider() async {
    setState(() => _isLoading = true);
    try {
      _riderId = await SessionService.getUserIdStatic();
      if (_riderId != null) {
        await _loadActiveRequests();
      }
    } catch (e) {
      debugPrint('Error initializing rider: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadActiveRequests() async {
    try {
      final requests = await _requestService.getActiveRequests(_riderId!);
      setState(() {
        _activeRequests = requests.map((request) => request.toMap()).toList();
      });
    } catch (e) {
      debugPrint('Error loading active requests: $e');
    }
  }

  Future<void> _estimatePrice() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
      CustomToast.showError(
        context: context,
        message: 'Please enter both pickup and dropoff addresses',
      );
      return;
    }

    setState(() => _isEstimating = true);
    try {
      final estimatedPrice = await _requestService.estimatePrice(
        pickupAddress: _pickupController.text,
        dropoffAddress: _dropoffController.text,
      );

      setState(() {
        _estimatedPrice = estimatedPrice;
        _priceController.text = estimatedPrice.toStringAsFixed(2);
      });

      CustomToast.showSuccess(
        context: context,
        message: 'Estimated price: \$${estimatedPrice.toStringAsFixed(2)}',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to estimate price: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isEstimating = false);
      }
    }
  }

  Future<void> _requestRide() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
      CustomToast.showError(
        context: context,
        message: 'Please enter both pickup and dropoff addresses',
      );
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      CustomToast.showError(
        context: context,
        message: 'Please enter a valid price',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _requestService.createRequest(
        riderId: _riderId!,
        pickupAddress: _pickupController.text,
        dropoffAddress: _dropoffController.text,
        proposedPrice: price,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Clear form
      _pickupController.clear();
      _dropoffController.clear();
      _priceController.clear();
      _notesController.clear();
      _estimatedPrice = 0.0;

      // Reload active requests
      await _loadActiveRequests();

      CustomToast.showSuccess(
        context: context,
        message: 'Ride request sent! Drivers will be notified.',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to request ride: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    setState(() => _isLoading = true);
    try {
      await _requestService.cancelRequest(requestId);
      await _loadActiveRequests();
      CustomToast.showInfo(context: context, message: 'Ride request cancelled');
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to cancel request: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final locationService = DriverLocationService();
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        // Use geocoding to get address from coordinates
        final geocodedAddress = await LocationService.geocodeAddress(
          '${position.latitude},${position.longitude}',
        );
        if (geocodedAddress != null) {
          setState(() {
            _pickupController.text = geocodedAddress['address'] ?? '';
          });
        } else {
          // Fallback: just show coordinates if geocoding fails
          setState(() {
            _pickupController.text =
                '${position.latitude}, ${position.longitude}';
          });
        }
      }
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to get current location: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRequestForm() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request a Ride',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Pickup Location
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                hintText: 'Enter pickup address',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _useCurrentLocation,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Dropoff Location
            TextField(
              controller: _dropoffController,
              decoration: const InputDecoration(
                labelText: 'Dropoff Location',
                hintText: 'Enter destination address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Price Input with Estimate Button
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Proposed Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: _isEstimating ? null : _estimatePrice,
                    icon: _isEstimating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_money, size: 16),
                    label: const Text('Estimate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _requestRide,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Request Ride'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequests() {
    if (_activeRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._activeRequests
                .map(
                  (request) => ListTile(
                    title: Text(request['pickup_address'] ?? ''),
                    subtitle: Text(request['dropoff_address'] ?? ''),
                    trailing: Text(
                      '\$${request['proposed_price']?.toStringAsFixed(2) ?? '0.00'}',
                    ),
                    leading: const Icon(Icons.directions_car),
                    onTap: () {
                      // Show request details
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Ride Request'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From: ${request['pickup_address']}'),
                              Text('To: ${request['dropoff_address']}'),
                              Text(
                                'Price: \$${request['proposed_price']?.toStringAsFixed(2) ?? '0.00'}',
                              ),
                              if (request['notes'] != null)
                                Text('Notes: ${request['notes']}'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _cancelRequest(request['id']);
                              },
                              child: const Text('Cancel Request'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
                ,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Ride'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _riderId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRequestForm(),
                  const SizedBox(height: 20),
                  _buildActiveRequests(),
                ],
              ),
            ),
    );
  }
}
