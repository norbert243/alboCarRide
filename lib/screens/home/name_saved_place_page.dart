import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/utils/place_icon_helper.dart';

/// Step 2 of Add Saved Place flow: Name and icon selection
/// User enters a name and selects an icon for the place
class NameSavedPlacePage extends StatefulWidget {
  final String address;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? existingPlace; // For editing existing place

  const NameSavedPlacePage({
    super.key,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.existingPlace,
  });

  @override
  State<NameSavedPlacePage> createState() => _NameSavedPlacePageState();
}

class _NameSavedPlacePageState extends State<NameSavedPlacePage> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  String? _selectedIcon;
  bool _isSaving = false;
  String? _nameError;

  // Icon options using Material icons
  final List<MapEntry<String, IconData>> _iconOptions = PlaceIconHelper.getAllIcons();

  @override
  void initState() {
    super.initState();

    // If editing, pre-fill name and icon
    if (widget.existingPlace != null) {
      _nameController.text = widget.existingPlace!['name'] ?? '';
      _selectedIcon = widget.existingPlace!['icon'];
    }

    // Auto-focus name field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool _validateName() {
    final name = _nameController.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() {
        _nameError = 'Please enter a name (2-30 characters)';
      });
      return false;
    }

    if (name.length > 30) {
      setState(() {
        _nameError = 'Name must be 30 characters or less';
      });
      return false;
    }

    setState(() {
      _nameError = null;
    });
    return true;
  }

  Future<void> _savePlace() async {
    if (!_validateName()) {
      // Shake animation (optional)
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = await SessionService.getUserIdStatic();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final name = _nameController.text.trim();
      final icon = _selectedIcon ?? 'place'; // Default to place icon if not selected

      if (widget.existingPlace != null) {
        // UPDATE existing place
        await Supabase.instance.client
            .from('saved_places')
            .update({
          'name': name,
          'address': widget.address,
          'latitude': widget.latitude,
          'longitude': widget.longitude,
          'icon': icon,
        }).eq('id', widget.existingPlace!['id']);
      } else {
        // INSERT new place
        await Supabase.instance.client.from('saved_places').insert({
          'user_id': userId,
          'name': name,
          'address': widget.address,
          'latitude': widget.latitude,
          'longitude': widget.longitude,
          'icon': icon,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(widget.existingPlace != null
                    ? 'Place updated successfully'
                    : 'Place saved successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );

        // Pop back to Account Details (navigate back twice)
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error saving place: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save place: ${e.toString()}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNameValid = _nameController.text.trim().length >= 2 &&
        _nameController.text.trim().length <= 30;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF424242)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingPlace != null ? 'Edit place' : 'Name this place',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selected address display
                    _buildAddressCard(),

                    const SizedBox(height: 24),

                    // Name input section
                    _buildNameInput(),

                    const SizedBox(height: 32),

                    // Icon selection section
                    _buildIconSelection(),
                  ],
                ),
              ),
            ),

            // Save button (fixed at bottom)
            _buildSaveButton(isNameValid),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on,
            size: 20,
            color: Color(0xFF2196F3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Address:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF212121),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Name this place',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g., Home, Work, Mom\'s house',
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2196F3),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF44336),
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF44336),
                width: 2,
              ),
            ),
            errorText: _nameError,
            counterText: '', // Hide character counter
          ),
          onChanged: (value) {
            setState(() {
              if (_nameError != null) {
                _nameError = null; // Clear error when user types
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildIconSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose an icon (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _iconOptions.length,
          itemBuilder: (context, index) {
            final iconEntry = _iconOptions[index];
            final iconName = iconEntry.key;
            final iconData = iconEntry.value;
            final isSelected = _selectedIcon == iconName;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIcon = iconName;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2196F3).withOpacity(0.15)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2196F3)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    iconData,
                    size: 24,
                    color: isSelected
                        ? const Color(0xFF2196F3)
                        : const Color(0xFF757575),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEnabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: (_isSaving || !isEnabled) ? null : _savePlace,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF9E9E9E),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          minimumSize: const Size(double.infinity, 56),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save Place',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
