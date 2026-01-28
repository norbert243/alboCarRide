import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/models/vehicle.dart';
import 'package:albocarride/utils/app_theme.dart';
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
  double _estimatedPrice = 0.0;
  Vehicle? _selectedVehicle;

  final List<Vehicle> _vehicles = [
    Vehicle(name: 'Standard', description: 'Affordable, everyday rides', icon: Icons.directions_car, capacity: 4, priceMultiplier: 1.0),
    Vehicle(name: 'Comfort', description: 'Newer cars with extra legroom', icon: Icons.directions_car_filled, capacity: 4, priceMultiplier: 1.2),
    Vehicle(name: 'XL', description: 'Affordable rides for groups up to 6', icon: Icons.people, capacity: 6, priceMultiplier: 1.5),
  ];

  @override
  void initState() {
    super.initState();
    _selectedVehicle = _vehicles.first;
    _initializeRider();
  }

  Future<void> _initializeRider() async {
    setState(() => _isLoading = true);
    try {
      _riderId = await SessionService.getUserIdStatic();
      // Auto-populate pickup location with current location
      await _autoSetCurrentLocation();
    } catch (e) {
      debugPrint('Error initializing rider: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _autoSetCurrentLocation() async {
    try {
      final locationService = DriverLocationService();
      final position = await locationService.getCurrentLocation();
      if (position != null && mounted) {
        final geocodedAddress = await LocationService.geocodeAddress(
          '${position.latitude},${position.longitude}',
        );
        if (geocodedAddress != null && mounted) {
          setState(() {
            _pickupController.text = geocodedAddress['address'] ?? '';
          });
        } else if (mounted) {
          setState(() {
            _pickupController.text = '${position.latitude}, ${position.longitude}';
          });
        }
      }
    } catch (e) {
      debugPrint('Auto-location failed (non-critical): $e');
      // Silent failure - user can still manually enter or tap location button
    }
  }

  Future<void> _estimatePrice() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
      CustomToast.showError(context: context, message: 'Please enter both pickup and dropoff addresses');
      return;
    }

    setState(() => _isEstimating = true);
    try {
      final basePrice = await _requestService.estimatePrice(
        pickupAddress: _pickupController.text,
        dropoffAddress: _dropoffController.text,
      );
      final finalPrice = basePrice * (_selectedVehicle?.priceMultiplier ?? 1.0);

      setState(() {
        _estimatedPrice = finalPrice;
        _priceController.text = finalPrice.toStringAsFixed(2);
      });

      CustomToast.showSuccess(context: context, message: 'Estimated price: \$${finalPrice.toStringAsFixed(2)}');
    } catch (e) {
      CustomToast.showError(context: context, message: 'Failed to estimate price: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isEstimating = false);
      }
    }
  }

  Future<void> _requestRide() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
      CustomToast.showError(context: context, message: 'Please enter both pickup and dropoff addresses');
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      CustomToast.showError(context: context, message: 'Please enter a valid price');
      return;
    }
    if (_selectedVehicle == null) {
      CustomToast.showError(context: context, message: 'Please select a vehicle type');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final notes = _notesController.text.isNotEmpty
          ? 'Vehicle: ${_selectedVehicle!.name}. Notes: ${_notesController.text}'
          : 'Vehicle: ${_selectedVehicle!.name}';

      await _requestService.createRequest(
        riderId: _riderId!,
        pickupAddress: _pickupController.text,
        dropoffAddress: _dropoffController.text,
        proposedPrice: price,
        notes: notes,
      );

      _pickupController.clear();
      _dropoffController.clear();
      _priceController.clear();
      _notesController.clear();
      _estimatedPrice = 0.0;

      CustomToast.showSuccess(context: context, message: 'Ride request sent! Drivers will be notified.');
      Navigator.pop(context); // Go back after successful request
    } catch (e) {
      CustomToast.showError(context: context, message: 'Failed to request ride: ${e.toString()}');
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
        final geocodedAddress = await LocationService.geocodeAddress('${position.latitude},${position.longitude}');
        if (geocodedAddress != null) {
          setState(() {
            _pickupController.text = geocodedAddress['address'] ?? '';
          });
        } else {
          setState(() {
            _pickupController.text = '${position.latitude}, ${position.longitude}';
          });
        }
      }
    } catch (e) {
      CustomToast.showError(context: context, message: 'Failed to get current location: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildVehicleSelection(),
              const SizedBox(height: 32),
              _buildLocationForm(),
              const SizedBox(height: 32),
              _buildPriceAndNotes(),
              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Text(
          'Request a Ride',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ],
    );
  }

  Widget _buildVehicleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a Vehicle', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = _vehicles[index];
              final isSelected = _selectedVehicle == vehicle;
              return GestureDetector(
                onTap: () => setState(() => _selectedVehicle = vehicle),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(vehicle.icon, size: 36, color: isSelected ? Colors.white : AppTheme.textColor),
                      const SizedBox(height: 8),
                      Text(vehicle.name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textColor)),
                      Text('${vehicle.capacity} seats', style: TextStyle(color: isSelected ? Colors.white70 : AppTheme.subtleTextColor)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationForm() {
    return Column(
      children: [
        TextField(
          controller: _pickupController,
          readOnly: true, // Pickup is always current location
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryColor),
            hintText: _isLoading ? 'Getting your location...' : 'Your current location',
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _useCurrentLocation,
              tooltip: 'Refresh current location',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _dropoffController,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.flag, color: AppTheme.primaryColor),
            hintText: 'Dropoff Location',
          ),
        ),
      ],
    );
  }

  Widget _buildPriceAndNotes() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: 'Proposed Price',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isEstimating ? null : _estimatePrice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: AppTheme.secondaryColor,
                ),
                child: _isEstimating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Estimate'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.note),
            hintText: 'Notes for driver (optional)',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _requestRide,
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : const Text('Request Ride'),
      ),
    );
  }
}
