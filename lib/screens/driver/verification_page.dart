
// lib/screens/driver/verification_page.dart - COMPLETELY REDESIGNED
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
  File? _selectedFile;
  bool _uploading = false;
  bool _uploadComplete = false;
  final _picker = ImagePicker();
  String _docType = 'driverLicense';
  String? _uploadedDocId;
  double _uploadProgress = 0.0;
  String? _uploadError;

  // Document type information with enhanced UX
  final Map<String, Map<String, dynamic>> _docTypeInfo = {
    'driverLicense': {
      'title': 'Driver License',
      'description': 'Clear photo of your valid driver\'s license',
      'icon': Icons.directions_car,
      'required': true,
      'maxSize': 5, // MB
      'allowedTypes': ['jpg', 'jpeg', 'png', 'pdf'],
    },
    'vehicleRegistration': {
      'title': 'Vehicle Registration',
      'description': 'Official vehicle registration certificate',
      'icon': Icons.description,
      'required': true,
      'maxSize': 5,
      'allowedTypes': ['jpg', 'jpeg', 'png', 'pdf'],
    },
    'profilePhoto': {
      'title': 'Profile Photo',
      'description': 'Clear headshot photo for your driver profile',
      'icon': Icons.person,
      'required': true,
      'maxSize': 3,
      'allowedTypes': ['jpg', 'jpeg', 'png'],
    },
    'vehiclePhoto': {
      'title': 'Vehicle Photo',
      'description': 'Clear photo showing your entire vehicle',
      'icon': Icons.photo_camera,
      'required': true,
      'maxSize': 3,
      'allowedTypes': ['jpg', 'jpeg', 'png'],
    },
  };

  // Enhanced file validation
  bool _validateFile(File file, String docType) {
    final info = _docTypeInfo[docType]!;
    final maxSize = info['maxSize'] as int;
    final allowedTypes = info['allowedTypes'] as List<String>;
    
    // Check file size
    final sizeInMB = file.lengthSync() / (1024 * 1024);
    if (sizeInMB > maxSize) {
      _uploadError = 'File size exceeds ${maxSize}MB limit';
      return false;
    }
    
    // Check file type
    final extension = file.path.split('.').last.toLowerCase();
    if (!allowedTypes.contains(extension)) {
      _uploadError = 'File type not allowed. Use: ${allowedTypes.join(', ')}';
      return false;
    }
    
    return true;
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Document Source'),
          content: const Text('Choose how you want to upload your document'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Take Photo'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Choose from Gallery'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (x != null) {
        final file = File(x.path);
        if (_validateFile(file, _docType)) {
          setState(() {
            _selectedFile = file;
            _uploadComplete = false;
            _uploadError = null;
          });
        } else {
          _showErrorSnackBar(_uploadError!);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Camera error: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (x != null) {
        final file = File(x.path);
        if (_validateFile(file, _docType)) {
          setState(() {
            _selectedFile = file;
            _uploadComplete = false;
            _uploadError = null;
          });
        } else {
          _showErrorSnackBar(_uploadError!);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gallery error: $e');
    }
  }

  Future<void> _uploadDocument() async {
    final userId = await AuthService.getUserId();
    if (userId == null || _selectedFile == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      // Simulate progress for better UX
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _uploadProgress = i / 100.0;
        });
      }

      final docId = await DocumentService.instance.uploadDriverDocument(
        driverId: userId,
        documentType: _docType,
        file: _selectedFile!,
      );

      _uploadedDocId = docId;
      setState(() {
        _uploading = false;
        _uploadComplete = true;
        _uploadProgress = 1.0;
      });

      _showSuccessSnackBar('Document uploaded successfully!');
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadError = e.toString();
      });
      _showErrorSnackBar('Upload failed: $e');
    }
  }

  Future<void> _submitForVerification() async {
    final userId = await AuthService.getUserId();
    if (userId == null || !_uploadComplete) return;

    setState(() => _uploading = true);

    try {
      await TelemetryService.instance.log(
        'document_submitted',
        'submitted_for_review',
        {'doc_id': _uploadedDocId, 'driver_id': userId},
      );

      // Update verification status to pending
      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({'verification_status': 'pending'})
          .eq('id', userId);

      _showSuccessSnackBar('Document submitted for review!');

      // Navigate to waiting for review page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/waiting-review',
        (route) => false,
      );
    } catch (e) {
      setState(() => _uploading = false);
      _showErrorSnackBar('Submission failed: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Document Verification',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeaderSection(),
              const SizedBox(height: 32),

              // Document Type Selection
              _buildDocumentTypeSection(),
              const SizedBox(height: 24),

              // File Upload Section
              _buildUploadSection(),
              const SizedBox(height: 24),

              // Progress and Status
              if (_uploading) _buildProgressSection(),
              if (_uploadError != null) _buildErrorSection(),
              if (_uploadComplete) _buildSuccessSection(),

              // Action Buttons
              _buildActionButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Verification Documents',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Please upload clear photos of your documents for verification. This helps us ensure safety and compliance.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All documents are required for verification',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        
        // Replace dropdown with segmented button style
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Column(
            children: _docTypeInfo.entries.map((entry) {
              final info = entry.value;
              final isSelected = _docType == entry.key;
              
              return GestureDetector(
                onTap: () => setState(() {
                  _docType = entry.key;
                  _selectedFile = null;
                  _uploadComplete = false;
                  _uploadError = null;
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.transparent,
                    border: Border(
                      bottom: entry.key != _docTypeInfo.keys.last
                          ? BorderSide(color: Colors.grey[200]!)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        info['icon'] as IconData,
                        size: 24,
                        color: isSelected ? Colors.blue : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  info['title'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? Colors.blue[800] : Colors.grey[800],
                                  ),
                                ),
                                if (info['required'] as bool) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Required',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              info['description'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.blue[600] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    final info = _docTypeInfo[_docType]!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload ${info['title']}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        
        // Drag and Drop Area
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedFile != null ? Colors.green : Colors.grey[300]!,
              width: _selectedFile != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: _selectedFile != null ? Colors.green.withOpacity(0.05) : Colors.grey[50],
          ),
          child: _selectedFile == null
              ? _buildEmptyUploadArea(info)
              : _buildFilePreview(),
        ),
        
        const SizedBox(height: 12),
        Text(
          'Max size: ${info['maxSize']}MB • Allowed: ${(info['allowedTypes'] as List<String>).join(', ')}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyUploadArea(Map<String, dynamic> info) {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload ${info['title']}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to select from camera or gallery',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedFile!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insert_drive_file, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Document Preview',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedFile!.path.split('/').last,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _uploadProgress,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Uploading document...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.blue[100],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          const SizedBox(height: 4),
          Text(
            '${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Failed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _uploadError ?? 'Unknown error occurred',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _uploadDocument,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Document uploaded successfully! Ready for submission.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Camera Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.withOpacity(0.3)),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text(
              'Select Document',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Upload Button (only when image is selected and not uploaded)
        if (_selectedFile != null && !_uploadComplete && !_uploading)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.cloud_upload, size: 20),
              label: const Text(
                'Upload Document',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // Submit Button (only when upload is complete)
        if (_uploadComplete)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _submitForVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
              label: Text(
                _uploading ? 'Submitting...' : 'Submit for Verification',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
