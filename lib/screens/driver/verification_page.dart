// lib/screens/driver/verification_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/document_service.dart';
import '../../services/auth_service.dart';
import '../../services/telemetry_service.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  File? _picked;
  bool _uploading = false;
  final _picker = ImagePicker();
  String _docType = 'driverLicense';

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (x != null) setState(() => _picked = File(x.path));
  }

  Future<void> _submit() async {
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    if (_picked == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a photo first')));
      return;
    }

    setState(() => _uploading = true);

    try {
      final docId = await DocumentService.instance.uploadDriverDocument(
        driverId: userId,
        docType: _docType,
        file: _picked!,
      );

      await TelemetryService.instance.log(
        'document_submitted',
        'submitted_for_review',
        {'doc_id': docId, 'driver_id': userId},
      );

      // Update verification status to pending
      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({'verification_status': 'pending'})
          .eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded for review')),
      );

      // Navigate to waiting for review page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/waiting-review',
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Verification Document')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _docType,
              items: const [
                DropdownMenuItem(
                  value: 'driverLicense',
                  child: Text('Driver License'),
                ),
                DropdownMenuItem(
                  value: 'vehicleRegistration',
                  child: Text('Vehicle Registration'),
                ),
                DropdownMenuItem(
                  value: 'profilePhoto',
                  child: Text('Profile Photo'),
                ),
                DropdownMenuItem(
                  value: 'vehiclePhoto',
                  child: Text('Vehicle Photo'),
                ),
              ],
              onChanged: (v) => setState(() => _docType = v ?? 'driverLicense'),
            ),
            const SizedBox(height: 12),
            _picked == null
                ? Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Image.file(_picked!, height: 200),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Pick Photo'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _submit,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_uploading ? 'Uploading...' : 'Upload & Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
