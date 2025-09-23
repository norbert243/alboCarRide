import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class VehicleTypeSelectionPage extends StatefulWidget {
  final String driverId;
  const VehicleTypeSelectionPage({Key? key, required this.driverId})
    : super(key: key);

  @override
  State<VehicleTypeSelectionPage> createState() =>
      _VehicleTypeSelectionPageState();
}

class _VehicleTypeSelectionPageState extends State<VehicleTypeSelectionPage> {
  String? _vehicleType; // 'car' or 'motorcycle'
  bool _loading = false;

  Future<void> _saveVehicleType() async {
    if (_vehicleType == null) {
      CustomToast.showError(
        context: context,
        message: 'Please choose a vehicle type',
      );
      return;
    }

    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.from('drivers').upsert({
        'id': widget.driverId,
        'vehicle_type': _vehicleType,
        'updated_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isEmpty) {
        throw Exception('Failed to save vehicle type: No data returned');
      }

      CustomToast.showSuccess(
        context: context,
        message: 'Vehicle type saved successfully!',
      );

      // Navigate to AuthWrapper to determine next step
      Navigator.pushNamed(context, '/auth_wrapper');
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to save vehicle type: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
          'Select Vehicle Type',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: 20),
              const Text(
                'Choose Your Vehicle',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the type of vehicle you will be driving',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Vehicle Type Selection
              _buildVehicleTypeCard(
                title: 'Car',
                description: 'Standard passenger vehicle',
                icon: Icons.directions_car,
                value: 'car',
              ),
              const SizedBox(height: 16),
              _buildVehicleTypeCard(
                title: 'Motorcycle',
                description: 'Two-wheeled vehicle',
                icon: Icons.motorcycle,
                value: 'motorcycle',
              ),

              const SizedBox(height: 40),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveVehicleType,
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
                          'Save and Continue',
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

  Widget _buildVehicleTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _vehicleType == value;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: Colors.deepPurple, width: 2)
            : BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () => setState(() => _vehicleType = value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurple.withAlpha(26)
                      : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: isSelected ? Colors.deepPurple : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.deepPurple : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
