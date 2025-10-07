import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/document_upload_service.dart';
import '../../utils/auth_error_handler.dart';
import '../../widgets/custom_toast.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final DocumentUploadService _uploadService = DocumentUploadService();
  final Map<DocumentType, bool> _uploadingStates = {};
  final Map<DocumentType, String?> _uploadedUrls = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize uploading states
    for (var type in DocumentType.values) {
      _uploadingStates[type] = false;
    }
  }

  Future<void> _pickDocument(DocumentType documentType) async {
    final currentContext = context;

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: currentContext,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        setState(() {
          _uploadingStates[documentType] = true;
        });

        final url = await _uploadService.pickAndUploadDocument(
          source: source,
          userId: Supabase.instance.client.auth.currentUser!.id,
          documentType: documentType,
        );

        if (!mounted) return;
        setState(() {
          _uploadedUrls[documentType] = url;
          _uploadingStates[documentType] = false;
        });

        if (mounted) {
          CustomToast.showSuccess(
            context: currentContext,
            message: '${documentType.displayName} uploaded successfully!',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingStates[documentType] = false;
      });

      if (mounted) {
        AuthErrorHandler.handleAuthError(
          currentContext,
          e,
          operation: 'document_upload',
        );
      }
    }
  }

  Future<void> _submitVerification() async {
    final currentContext = context;

    // Check if all required documents are uploaded
    final missingDocuments = DocumentType.values
        .where((type) => type.isRequired && _uploadedUrls[type] == null)
        .toList();

    if (missingDocuments.isNotEmpty) {
      final missingNames = missingDocuments
          .map((e) => e.displayName)
          .join(', ');
      CustomToast.showError(
        context: currentContext,
        message: 'Please upload all required documents: $missingNames',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Insert document records into database
      for (final entry in _uploadedUrls.entries) {
        if (entry.value != null) {
          await Supabase.instance.client.from('driver_documents').upsert({
            'driver_id': userId,
            'document_type': entry.key.name,
            'document_url': entry.value,
            'uploaded_at': DateTime.now().toIso8601String(),
            'status': 'pending',
          });
        }
      }

      // Update user verification status to 'pending' for admin review
      await Supabase.instance.client
          .from('profiles')
          .update({
            'verification_status': 'pending',
            'verification_submitted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      if (mounted) {
        CustomToast.showSuccess(
          context: currentContext,
          message:
              'Verification submitted successfully! Your documents are under review.',
        );
      }

      // Navigate to waiting for review page
      if (!mounted) return;
      Navigator.pushNamed(currentContext, '/waiting-review');
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.handleAuthError(
          currentContext,
          e,
          operation: 'verification_submission',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildDocumentCard(DocumentType documentType) {
    final isUploading = _uploadingStates[documentType] ?? false;
    final isUploaded = _uploadedUrls[documentType] != null;
    final isRequired = documentType.isRequired;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentType.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        documentType.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (isRequired)
                        Text(
                          '* Required',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isUploaded)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            if (isUploading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: () => _pickDocument(documentType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUploaded ? Colors.green : null,
                  foregroundColor: isUploaded ? Colors.white : null,
                ),
                child: Text(isUploaded ? 'Uploaded ✓' : 'Upload Document'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Driver Verification'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Your Driver Verification',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please upload the following documents to complete your driver verification process. '
                'This helps us ensure the safety and reliability of our service.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Document upload sections
              _buildDocumentCard(DocumentType.driverLicense),
              _buildDocumentCard(DocumentType.vehicleRegistration),
              _buildDocumentCard(DocumentType.profilePhoto),
              _buildDocumentCard(DocumentType.vehiclePhoto),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Verification',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Info text
              Text(
                'Note: All documents will be reviewed by our team. '
                'You will receive a notification once your verification is complete. '
                'This process typically takes 1-2 business days.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
