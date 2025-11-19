import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/emergency_sos_service.dart';
import '../../services/session_service.dart';
import '../../widgets/custom_toast.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final EmergencySosService _sosService = EmergencySosService(
    Supabase.instance.client,
  );

  List<EmergencyContact> _contacts = [];
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
      await _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _sosService.getEmergencyContacts(_userId!);
      setState(() {
        _contacts = contacts;
      });
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to load contacts: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();
    bool notifyViaSms = true;
    bool notifyViaWhatsapp = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    hintText: '+243...',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Spouse, Parent, Friend',
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Notify via SMS'),
                  value: notifyViaSms,
                  onChanged: (value) {
                    setState(() => notifyViaSms = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Notify via WhatsApp'),
                  value: notifyViaWhatsapp,
                  onChanged: (value) {
                    setState(() => notifyViaWhatsapp = value ?? true);
                  },
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
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty) {
                  CustomToast.showError(
                    context: context,
                    message: 'Name and phone number are required',
                  );
                  return;
                }

                if (_contacts.length >= 3) {
                  CustomToast.showError(
                    context: context,
                    message: 'Maximum 3 emergency contacts allowed',
                  );
                  return;
                }

                try {
                  await _sosService.addEmergencyContact(
                    userId: _userId!,
                    name: nameController.text,
                    phoneNumber: phoneController.text,
                    relationship: relationshipController.text.isNotEmpty
                        ? relationshipController.text
                        : null,
                    priorityOrder: _contacts.length + 1,
                    notifyViaSms: notifyViaSms,
                    notifyViaWhatsapp: notifyViaWhatsapp,
                  );

                  Navigator.pop(context);
                  await _loadContacts();
                  CustomToast.showSuccess(
                    context: context,
                    message: 'Emergency contact added',
                  );
                } catch (e) {
                  CustomToast.showError(
                    context: context,
                    message: 'Failed to add contact: ${e.toString()}',
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
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
        await _sosService.deleteEmergencyContact(contact.id);
        await _loadContacts();
        CustomToast.showInfo(
          context: context,
          message: 'Contact deleted',
        );
      } catch (e) {
        CustomToast.showError(
          context: context,
          message: 'Failed to delete contact: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.contacts, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Emergency Contacts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Store 3 trusted contacts who will receive an SMS/WhatsApp alert with your live location if you use the SOS button during a trip',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddContactDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Emergency Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.red.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Store 3 trusted contacts who will receive an SMS/WhatsApp alert with your live location if you use the SOS button during a trip.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                contact.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(contact.phoneNumber),
                                  if (contact.relationship != null)
                                    Text(
                                      contact.relationship!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (contact.notifyViaSms)
                                        const Chip(
                                          label: Text('SMS'),
                                          labelStyle: TextStyle(fontSize: 10),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      const SizedBox(width: 4),
                                      if (contact.notifyViaWhatsapp)
                                        const Chip(
                                          label: Text('WhatsApp'),
                                          labelStyle: TextStyle(fontSize: 10),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteContact(contact),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _contacts.length < 3
          ? FloatingActionButton.extended(
              onPressed: _showAddContactDialog,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
            )
          : null,
    );
  }
}
