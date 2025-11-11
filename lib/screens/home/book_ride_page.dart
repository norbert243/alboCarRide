import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/location_service.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class BookRidePage extends StatefulWidget {
  const BookRidePage({super.key});

  @override
  State<BookRidePage> createState() => _BookRidePageState();
}

class _BookRidePageState extends State<BookRidePage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isCalculatingFare = false;
  String? _customerId;
  double? _estimatedFare;
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropoffSuggestions = [];
  FocusNode _pickupFocusNode = FocusNode();
  FocusNode _dropoffFocusNode = FocusNode();
  bool _showPickupSuggestions = false;
  bool _showDropoffSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerId();
    _setupFocusListeners();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _notesController.dispose();
    _pickupFocusNode.dispose();
    _dropoffFocusNode.dispose();
    super.dispose();
  }

  void _setupFocusListeners() {
    _pickupFocusNode.addListener(() {
      if (!_pickupFocusNode.hasFocus) {
        setState(() {
          _showPickupSuggestions = false;
        });
      }
    });

    _dropoffFocusNode.addListener(() {
      if (!_dropoffFocusNode.hasFocus) {
        setState(() {
          _showDropoffSuggestions = false;
        });
      }
    });
  }

  Future<void> _loadCustomerId() async {
    _customerId = await SessionService.getUserIdStatic();
  }

  Future<void> _onPickupChanged(String value) async {
    if (value.length > 2) {
      final suggestions = await LocationService.getPlaceSuggestions(value);
      setState(() {
        _pickupSuggestions = suggestions;
        _showPickupSuggestions = true;
      });
    } else {
      setState(() {
        _pickupSuggestions = [];
        _showPickupSuggestions = false;
      });
    }
    _calculateFare();
  }

  Future<void> _onDropoffChanged(String value) async {
    if (value.length > 2) {
      final suggestions = await LocationService.getPlaceSuggestions(value);
      setState(() {
        _dropoffSuggestions = suggestions;
        _showDropoffSuggestions = true;
      });
    } else {
      setState(() {
        _dropoffSuggestions = [];
        _showDropoffSuggestions = false;
      });
    }
    _calculateFare();
  }

  void _selectPickupSuggestion(Map<String, dynamic> suggestion) {
    _pickupController.text = suggestion['description'];
    setState(() {
      _showPickupSuggestions = false;
    });
    _calculateFare();
  }

  void _selectDropoffSuggestion(Map<String, dynamic> suggestion) {
    _dropoffController.text = suggestion['description'];
    setState(() {
      _showDropoffSuggestions = false;
    });
    _calculateFare();
  }

  Future<void> _calculateFare() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
      setState(() {
        _estimatedFare = null;
        _isCalculatingFare = false;
      });
      return;
    }

    setState(() {
      _isCalculatingFare = true;
    });

    try {
      // Get coordinates for pickup location
      final pickupDetails = await LocationService.geocodeAddress(
        _pickupController.text,
      );
      if (pickupDetails == null) return;

      // Get coordinates for dropoff location
      final dropoffDetails = await LocationService.geocodeAddress(
        _dropoffController.text,
      );
      if (dropoffDetails == null) return;

      final pickupLat = pickupDetails['latitude'] as double;
      final pickupLng = pickupDetails['longitude'] as double;
      final dropoffLat = dropoffDetails['latitude'] as double;
      final dropoffLng = dropoffDetails['longitude'] as double;

      // Calculate fare
      final fare = await LocationService.estimateFare(
        pickupLat,
        pickupLng,
        dropoffLat,
        dropoffLng,
      );

      setState(() {
        _estimatedFare = fare;
        _isCalculatingFare = false;
      });
    } catch (e) {
      print('Error calculating fare: $e');
      setState(() {
        _estimatedFare = null;
        _isCalculatingFare = false;
      });
    }
  }

  Future<void> _bookRide() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_customerId == null) {
        CustomToast.showError(
          context: context,
          message: 'Please log in again to book a ride',
        );
        return;
      }

      // Create ride request in database
      final response =
          await Supabase.instance.client.from('ride_requests').insert({
            'customer_id': _customerId,
            'pickup_location': _pickupController.text,
            'dropoff_location': _dropoffController.text,
            'notes': _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }).select();

      if (response.isNotEmpty) {
        CustomToast.showSuccess(
          context: context,
          message: 'Ride request submitted! Drivers will be notified.',
        );

        // Navigate back to home page
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create ride request');
      }
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to book ride: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Book a Ride',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Where would you like to go?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your pickup and dropoff locations',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Pickup Location with Autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _pickupController,
                    label: 'Pickup Location',
                    icon: Icons.location_on_outlined,
                    hint: 'Enter your current location',
                    focusNode: _pickupFocusNode,
                    onChanged: _onPickupChanged,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter pickup location';
                      }
                      return null;
                    },
                  ),
                  if (_showPickupSuggestions && _pickupSuggestions.isNotEmpty)
                    _buildSuggestionsList(
                      _pickupSuggestions,
                      _selectPickupSuggestion,
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Dropoff Location with Autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _dropoffController,
                    label: 'Dropoff Location',
                    icon: Icons.flag_outlined,
                    hint: 'Enter your destination',
                    focusNode: _dropoffFocusNode,
                    onChanged: _onDropoffChanged,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter dropoff location';
                      }
                      return null;
                    },
                  ),
                  if (_showDropoffSuggestions && _dropoffSuggestions.isNotEmpty)
                    _buildSuggestionsList(
                      _dropoffSuggestions,
                      _selectDropoffSuggestion,
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Additional Notes
              _buildTextField(
                controller: _notesController,
                label: 'Additional Notes (Optional)',
                icon: Icons.note_outlined,
                hint: 'Any special instructions for the driver',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Book Ride Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _bookRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Book Ride',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Estimated Fare Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _isCalculatingFare
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Fare',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _estimatedFare != null
                              ? Text(
                                  '\$${_estimatedFare!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                )
                              : Text(
                                  _isCalculatingFare
                                      ? 'Calculating fare...'
                                      : 'Fare will be calculated based on distance and time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    FocusNode? focusNode,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      focusNode: focusNode,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(
    List<Map<String, dynamic>> suggestions,
    Function(Map<String, dynamic>) onSuggestionSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: suggestions.map((suggestion) {
          return ListTile(
            leading: const Icon(
              Icons.location_on,
              size: 20,
              color: Colors.grey,
            ),
            title: Text(
              suggestion['mainText'] ?? suggestion['description'],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle:
                suggestion['secondaryText'] != null &&
                    (suggestion['secondaryText'] as String).isNotEmpty
                ? Text(
                    suggestion['secondaryText'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                : null,
            onTap: () => onSuggestionSelected(suggestion),
            dense: true,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }
}
