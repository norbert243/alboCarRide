import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// Types of documents that can be uploaded for driver verification
enum DocumentType {
  driver_license,
  id_card,
  insurance,
  vehicle_photo,
  plate_photo,
  driver_photo,
}

/// Service for handling document uploads with compression and Supabase storage
class DocumentUploadService {
  static const String _storageBucket = 'driver-documents';
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int _targetWidth = 1200;
  static const int _targetHeight = 1200;
  static const int _quality = 85;

  final SupabaseClient _supabase;
  final ImagePicker _imagePicker;

  DocumentUploadService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client,
      _imagePicker = ImagePicker();

  /// Uploads a document from file with automatic compression
  Future<String> uploadDocument({
    required XFile file,
    required String userId,
    required DocumentType documentType,
    String? customFileName,
  }) async {
    try {
      // Security validation: Ensure userId matches the authenticated user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser?.id != userId) {
        throw Exception('Cannot upload documents for another user');
      }

      // Validate file size before processing
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        throw Exception('File size exceeds 5MB limit');
      }

      // Compress the image if it's an image file
      final compressedBytes = await _compressImageIfNeeded(file);

      // Generate unique filename
      final fileName =
          customFileName ?? _generateFileName(userId, documentType, file.name);

      // Upload to Supabase storage - IMPORTANT: Path structure must match RLS policies
      // RLS policies expect: user_id/document_type/filename
      final storagePath = '$userId/${documentType.name}/$fileName';

      print('Attempting to upload document to: $storagePath');
      print('File size: ${compressedBytes.length} bytes');
      print('MIME type: ${_getMimeType(file.name)}');

      final uploadResponse = await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            storagePath,
            compressedBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getMimeType(file.name),
            ),
          );

      print('Upload response: $uploadResponse');

      // Get public URL
      final publicUrl = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Document upload error: $e');
      print('Error type: ${e.runtimeType}');

      if (e is StorageException) {
        print('StorageException details:');
        print('  Message: ${e.message}');
        print('  Status code: ${e.statusCode}');

        if (e.message.contains('bucket') ?? false) {
          throw Exception(
            'Storage bucket not found. Please ensure the "driver-documents" bucket is created in Supabase Storage. Error: ${e.message}',
          );
        } else if (e.message.contains('permission') ?? false) {
          throw Exception(
            'Permission denied. Please check if the user is authenticated and has proper permissions. Error: ${e.message}',
          );
        } else if (e.message.contains('size') ?? false) {
          throw Exception(
            'File size exceeds limit. Please ensure files are under 5MB. Error: ${e.message}',
          );
        }
        throw Exception('Storage upload failed: ${e.message}');
      } else if (e is Exception) {
        print('General Exception: $e');
        throw Exception('Document upload failed: $e');
      }
      rethrow;
    }
  }

  /// Picks an image from camera or gallery and uploads it
  Future<String> pickAndUploadDocument({
    required ImageSource source,
    required String userId,
    required DocumentType documentType,
    String? customFileName,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: _targetWidth.toDouble(),
        maxHeight: _targetHeight.toDouble(),
        imageQuality: _quality,
      );

      if (pickedFile == null) {
        throw Exception('No image selected');
      }

      return await uploadDocument(
        file: pickedFile,
        userId: userId,
        documentType: documentType,
        customFileName: customFileName,
      );
    } catch (e) {
      if (e.toString().contains('bucket not found')) {
        throw Exception(
          'Storage configuration error: Document upload bucket not found. Please contact support.',
        );
      }
      throw Exception('Failed to pick and upload document: $e');
    }
  }

  /// Downloads a document from storage
  Future<Uint8List> downloadDocument(String storagePath) async {
    try {
      final response = await _supabase.storage
          .from(_storageBucket)
          .download(storagePath);

      return response;
    } catch (e) {
      throw Exception('Failed to download document: $e');
    }
  }

  /// Deletes a document from storage
  Future<void> deleteDocument(String storagePath) async {
    try {
      await _supabase.storage.from(_storageBucket).remove([storagePath]);
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  /// Lists all documents for a user
  Future<List<Map<String, dynamic>>> listUserDocuments(String userId) async {
    try {
      // Security validation: Ensure userId matches the authenticated user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser?.id != userId) {
        throw Exception('Cannot fetch documents for another user');
      }

      final response = await _supabase.storage
          .from(_storageBucket)
          .list(path: userId);

      // Convert FileObject list to Map list for compatibility
      return response
          .map(
            (file) => {
              'name': file.name,
              'id': file.id,
              'updated_at': file.updatedAt,
              'created_at': file.createdAt,
              'metadata': file.metadata,
            },
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to list documents: $e');
    }
  }

  /// Compresses image if it's an image file
  Future<Uint8List> _compressImageIfNeeded(XFile file) async {
    final fileExtension = path.extension(file.name).toLowerCase();
    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(fileExtension);

    if (!isImage) {
      // For non-image files, read as bytes
      return await file.readAsBytes();
    }

    try {
      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: _targetWidth,
        minHeight: _targetHeight,
        quality: _quality,
        format: _getCompressFormat(fileExtension),
      );

      if (compressedBytes == null) {
        throw Exception('Image compression failed');
      }

      return compressedBytes;
    } catch (e) {
      // Fallback to original file if compression fails
      return await file.readAsBytes();
    }
  }

  /// Generates a unique filename for the document
  String _generateFileName(
    String userId,
    DocumentType documentType,
    String originalName,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalName);
    final baseName = path.basenameWithoutExtension(originalName);

    return '${documentType.name}_${baseName}_$userId$timestamp$extension';
  }

  /// Gets MIME type from file extension
  String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();

    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Gets compression format from file extension
  CompressFormat _getCompressFormat(String extension) {
    switch (extension) {
      case '.png':
        return CompressFormat.png;
      case '.webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg;
    }
  }

  /// Validates if a file is supported
  bool isFileSupported(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    final supportedExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.pdf',
      '.doc',
      '.docx',
    ];

    return supportedExtensions.contains(extension);
  }

  /// Gets maximum file size in MB
  double get maxFileSizeMB => _maxFileSize / (1024 * 1024);

  /// Gets supported file extensions for UI display
  List<String> get supportedExtensions => [
    'JPG',
    'JPEG',
    'PNG',
    'GIF',
    'BMP',
    'WEBP',
    'PDF',
    'DOC',
    'DOCX',
  ];
}

/// Extension methods for DocumentType
extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.driver_license:
        return 'Driver License';
      case DocumentType.id_card:
        return 'ID Card';
      case DocumentType.insurance:
        return 'Insurance Document';
      case DocumentType.vehicle_photo:
        return 'Vehicle Photo';
      case DocumentType.plate_photo:
        return 'License Plate Photo';
      case DocumentType.driver_photo:
        return 'Driver Photo';
    }
  }

  String get description {
    switch (this) {
      case DocumentType.driver_license:
        return 'Upload a clear photo of your valid driver\'s license';
      case DocumentType.id_card:
        return 'Upload a clear photo of your national ID or passport';
      case DocumentType.insurance:
        return 'Upload your vehicle insurance documents';
      case DocumentType.vehicle_photo:
        return 'Upload clear photos of your vehicle from multiple angles';
      case DocumentType.plate_photo:
        return 'Upload a clear photo of your license plate';
      case DocumentType.driver_photo:
        return 'Upload a clear profile photo for identification';
    }
  }

  bool get isRequired {
    switch (this) {
      case DocumentType.driver_license:
      case DocumentType.id_card:
      case DocumentType.insurance:
      case DocumentType.vehicle_photo:
      case DocumentType.plate_photo:
      case DocumentType.driver_photo:
        return true;
    }
  }
}
