import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class VehicleDetailsPage extends StatefulWidget {
  final String driverId;
  final String vehicleType;
  const VehicleDetailsPage({super.key, required this.driverId, required this.vehicleType});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Form fields
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _vehicleMakeController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _vehicleColorController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _licenseExpiryController = TextEditingController();

  // Vehicle makes for dropdown
  final List<String> _vehicleMakes = [
    'Toyota', 'Honda', 'Ford', 'Chevrolet', 'Nissan',
    'BMW', 'Mercedes-Benz', 'Audi', 'Volkswagen', 'Hyundai',
    'Kia', 'Mazda', 'Subaru', 'Lexus', 'Volvo',
    'Other'
  ];

  // Vehicle years for dropdown
  final List<String> _vehicleYears = List.generate(25, (index) => (DateTime.now().year - index).toString());

  @override
  void dispose() {
    _licensePlateController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicleDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      // Create complete driver profile with all vehicle details
      final result = await AuthService().createDriverProfile(
        driverId: widget.driverId,
        vehicleType: widget.vehicleType,
        vehicleMake: _vehicleMakeController.text,
        vehicleModel: _vehicleModelController.text,
        licensePlate: _licensePlateController.text,
        vehicleYear: int.parse(_vehicleYearController.text),
      );

      if (result['success'] == true) {
        CustomToast.showSuccess(
          context: context,
          message: 'Vehicle details saved successfully!',
        );

        // Navigate to verification page
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/verification',
          (route) => false,
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to save vehicle details');
      }
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to save vehicle details: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectLicenseExpiry() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) {
      _licenseExpiryController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
          'Vehicle Details',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              const SizedBox(height: 20),
              const Text(
                'Complete Your Vehicle Information',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide all required details about your ${widget.vehicleType}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Vehicle Type Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.vehicleType == 'car' ? Icons.directions_car : Icons.motorcycle,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Vehicle Type: ${widget.vehicleType == 'car' ? 'Car' : 'Motorcycle'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // License Plate
              _buildFormField(
                label: 'License Plate Number',
                hintText: 'ABC 123 GP',
                controller: _licensePlateController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter license plate number';
                  }
                  if (value.length < 3) {
                    return 'License plate must be at least 3 characters';
                  }
                  return null;
                },
                icon: Icons.confirmation_number,
              ),
              const SizedBox(height: 16),

              // Vehicle Make
              _buildDropdownField(
                label: 'Vehicle Make',
                hintText: 'Select vehicle brand',
                value: _vehicleMakeController.text.isEmpty ? null : _vehicleMakeController.text,
                items: _vehicleMakes,
                onChanged: (value) {
                  setState(() {
                    _vehicleMakeController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select vehicle make';
                  }
                  return null;
                },
                icon: Icons.business,
              ),
              const SizedBox(height: 16),

              // Vehicle Model
              _buildFormField(
                label: 'Vehicle Model',
                hintText: 'Corolla, Civic, etc.',
                controller: _vehicleModelController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle model';
                  }
                  return null;
                },
                icon: Icons.directions_car,
              ),
              const SizedBox(height: 16),

              // Vehicle Year
              _buildDropdownField(
                label: 'Vehicle Year',
                hintText: 'Select vehicle year',
                value: _vehicleYearController.text.isEmpty ? null : _vehicleYearController.text,
                items: _vehicleYears,
                onChanged: (value) {
                  setState(() {
                    _vehicleYearController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select vehicle year';
                  }
                  return null;
                },
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 16),

              // Vehicle Color
              _buildFormField(
                label: 'Vehicle Color',
                hintText: 'Red, Blue, Black, etc.',
                controller: _vehicleColorController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle color';
                  }
                  return null;
                },
                icon: Icons.color_lens,
              ),
              const SizedBox(height: 16),

              // Driver License Number
              _buildFormField(
                label: 'Driver License Number',
                hintText: 'DRV123456789',
                controller: _licenseNumberController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter driver license number';
                  }
                  if (value.length < 5) {
                    return 'License number must be at least 5 characters';
                  }
                  return null;
                },
                icon: Icons.card_membership,
              ),
              const SizedBox(height: 16),

              // License Expiry Date
              _buildDateField(
                label: 'License Expiry Date',
                hintText: 'Select expiry date',
                controller: _licenseExpiryController,
                onTap: _selectLicenseExpiry,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select license expiry date';
                  }
                  return null;
                },
                icon: Icons.event,
              ),
              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveVehicleDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save and Continue to Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
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
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hintText,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required String? Function(String?) validator,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
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
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required VoidCallback onTap,
    required String? Function(String?) validator,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
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
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
          ),
        ),
      ],
    );
  }
}