import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/saved_address_service.dart';
import '../../services/session_service.dart';
import '../../services/location_service.dart';
import '../../widgets/custom_toast.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  final SavedAddressService _addressService = SavedAddressService(
    Supabase.instance.client,
  );

  List<SavedAddress> _addresses = [];
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _userId = await SessionService.getUserIdStatic();
    if (_userId != null) {
      await _loadAddresses();
    }
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final addresses = await _addressService.getSavedAddresses(_userId!);
      setState(() {
        _addresses = addresses;
      });
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to load addresses: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddAddressDialog({SavedAddress? editAddress}) async {
    final labelController = TextEditingController(text: editAddress?.label);
    final addressController = TextEditingController(text: editAddress?.address);
    final notesController = TextEditingController(text: editAddress?.notes);
    String selectedType = editAddress?.addressType ?? 'other';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editAddress == null ? 'Add Address' : 'Edit Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Address Type'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'home', label: Text('Home'), icon: Icon(Icons.home)),
                    ButtonSegment(value: 'work', label: Text('Work'), icon: Icon(Icons.work)),
                    ButtonSegment(value: 'other', label: Text('Other'), icon: Icon(Icons.place)),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() => selectedType = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Home, Office, Gym',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    border: OutlineInputBorder(),
                    hintText: 'Enter full address',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Additional details',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (labelController.text.isEmpty ||
                    addressController.text.isEmpty) {
                  CustomToast.showError(
                    context: context,
                    message: 'Label and address are required',
                  );
                  return;
                }

                try {
                  // Geocode the address
                  final coords = await LocationService.geocodeAddress(
                    addressController.text,
                  );

                  if (editAddress == null) {
                    // Create new address
                    await _addressService.createSavedAddress(
                      userId: _userId!,
                      label: labelController.text,
                      address: addressController.text,
                      latitude: coords?['latitude'] as double?,
                      longitude: coords?['longitude'] as double?,
                      addressType: selectedType,
                      notes: notesController.text.isNotEmpty
                          ? notesController.text
                          : null,
                    );
                  } else {
                    // Update existing address
                    await _addressService.updateSavedAddress(
                      addressId: editAddress.id,
                      label: labelController.text,
                      address: addressController.text,
                      latitude: coords?['latitude'] as double?,
                      longitude: coords?['longitude'] as double?,
                      addressType: selectedType,
                      notes: notesController.text.isNotEmpty
                          ? notesController.text
                          : null,
                    );
                  }

                  Navigator.pop(context);
                  await _loadAddresses();
                  CustomToast.showSuccess(
                    context: context,
                    message: editAddress == null
                        ? 'Address added'
                        : 'Address updated',
                  );
                } catch (e) {
                  CustomToast.showError(
                    context: context,
                    message: 'Failed to save address: ${e.toString()}',
                  );
                }
              },
              child: Text(editAddress == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAddress(SavedAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete "${address.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _addressService.deleteSavedAddress(address.id);
        await _loadAddresses();
        CustomToast.showInfo(context: context, message: 'Address deleted');
      } catch (e) {
        CustomToast.showError(
          context: context,
          message: 'Failed to delete: ${e.toString()}',
        );
      }
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Saved Addresses',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Save your frequent addresses for quick access',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddAddressDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Address'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          child: Icon(_getIconForType(address.addressType)),
                        ),
                        title: Text(
                          address.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(address.address),
                            if (address.notes != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                address.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddAddressDialog(editAddress: address);
                            } else if (value == 'delete') {
                              _deleteAddress(address);
                            }
                          },
                        ),
                        onTap: () {
                          // Return the selected address
                          Navigator.pop(context, address);
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }
}
