// lib/services/document_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'telemetry_service.dart';

class DocumentService {
  DocumentService._private();
  static final DocumentService instance = DocumentService._private();

  final _supabase = Supabase.instance.client;
  final _bucket = 'driver-documents';

  /// Upload a file and register metadata row (returns document id)
  Future<String> uploadDriverDocument({
    required String driverId,
    required String documentType, // e.g., 'driverLicense'
    required File file,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      // Verify authentication
      final currentUser = _supabase.auth.currentUser;
      print('🔐 Current Auth User: ${currentUser?.id}');
      print('🔐 Driver ID: $driverId');

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (currentUser.id != driverId) {
        throw Exception(
          'User ID mismatch. Cannot upload documents for another user.',
        );
      }

      // Generate filename
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final extension = p.extension(file.path);
      final fileName = '${documentType}_${timestamp}$extension';

      // IMPORTANT: Storage path must start with driverId for RLS
      final storagePath = '$driverId/$fileName';

      // Read file bytes
      final bytes = await file.readAsBytes();
      print('📤 Uploading to: $_bucket/$storagePath');
      print('📊 File size: ${bytes.length} bytes');

      // Upload to storage
      await _supabase.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: _getMimeType(fileName),
            ),
          );

      print('✅ Storage upload successful');

      // Get public URL
      final publicUrl = _supabase.storage
          .from(_bucket)
          .getPublicUrl(storagePath);

      print('🔗 Public URL: $publicUrl');

      // Insert metadata into database
      print('💾 Inserting database record...');

      final response = await _supabase
          .from('driver_documents')
          .insert({
            'driver_id': driverId,
            'document_type': documentType,
            'document_url': publicUrl,
            'status': 'pending',
          })
          .select('id')
          .single();

      final docId = response['id'] as String;
      print('✅ Database record created: $docId');

      // Log successful upload
      await TelemetryService.instance.log(
        'document_upload',
        'uploaded_driver_document',
        {'driver_id': driverId, 'doc_id': docId, 'doc_type': documentType},
      );

      return docId;
    } on StorageException catch (e) {
      print('❌ Storage Error: ${e.message}');
      await TelemetryService.instance.logError(
        type: 'storage_upload_failed',
        message: e.message,
        stackTrace: e.toString(),
        metadata: {'driver_id': driverId, 'doc_type': documentType},
      );
      rethrow;
    } on PostgrestException catch (e) {
      print('❌ Database Error: ${e.message}');
      print('💡 Code: ${e.code}, Details: ${e.details}');

      // Check for RLS policy violation
      if (e.code == '42501' || e.message.contains('row-level security')) {
        print('🚫 RLS Policy Violation - Check your policies!');
        throw Exception(
          'Permission denied: Unable to insert document record. Please ensure RLS policies are configured correctly.',
        );
      }

      await TelemetryService.instance.logError(
        type: 'database_insert_failed',
        message: e.message,
        stackTrace: e.toString(),
        metadata: {
          'driver_id': driverId,
          'doc_type': documentType,
          'code': e.code,
        },
      );
      rethrow;
    } catch (e, st) {
      print('❌ Unexpected Error: $e');
      await TelemetryService.instance.logError(
        type: 'document_upload_failed',
        message: e.toString(),
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId, 'doc_type': documentType},
      );
      rethrow;
    }
  }

  /// Fetch documents for driver
  Future<List<Map<String, dynamic>>> listDriverDocuments(
    String driverId,
  ) async {
    try {
      final res = await _supabase
          .from('driver_documents')
          .select('*')
          .eq('driver_id', driverId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('❌ Failed to list documents: $e');
      rethrow;
    }
  }

  /// Delete a document (both storage and database)
  Future<void> deleteDriverDocument({
    required String documentId,
    required String storagePath,
  }) async {
    try {
      // Delete from storage
      await _supabase.storage.from(_bucket).remove([storagePath]);

      // Delete from database
      await _supabase.from('driver_documents').delete().eq('id', documentId);

      print('✅ Document deleted: $documentId');
    } catch (e) {
      print('❌ Failed to delete document: $e');
      rethrow;
    }
  }

  /// Get MIME type from filename
  String _getMimeType(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
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
}
