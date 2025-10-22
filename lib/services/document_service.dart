// lib/services/document_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'telemetry_service.dart';

class DocumentService {
  DocumentService._private();
  static final DocumentService instance = DocumentService._private();

  final _supabase = Supabase.instance.client;
  final _bucket = 'driver-docs'; // ensure bucket created in Supabase UI

  /// Upload file to Supabase Storage then create a driver_documents row.
  /// Returns document id or throws.
  Future<String> uploadDriverDocument({
    required String driverId,
    required String docType,
    required File file,
    ValueChanged<double>? onProgress, // 0.0 - 1.0
  }) async {
    final uuid = const Uuid().v4();
    final ext = file.path.split('.').last;
    final path = '$driverId/$uuid.$ext';

    try {
      // Upload to storage
      final bytes = await file.readAsBytes();
      await _supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: _contentTypeForExt(ext)),
      );

      // Create a public URL
      final publicUrl = _supabase.storage.from(_bucket).getPublicUrl(path);

      // Insert record into driver_documents table
      final insertResponse = await _supabase
          .from('driver_documents')
          .insert({
            'driver_id': driverId,
            'document_type': docType,
            'document_url': publicUrl,
            'storage_path': path,
            'status': 'pending',
          })
          .select()
          .single();

      final docId = insertResponse['id'] as String;

      // Log successful upload
      await TelemetryService.instance.log(
        'document_upload',
        'uploaded_driver_document',
        {'driver_id': driverId, 'doc_id': docId, 'doc_type': docType},
      );

      return docId;
    } catch (e, st) {
      // Log error with proper TelemetryService interface
      await TelemetryService.instance.logError(
        type: 'document_upload_failed',
        message: e.toString(),
        stackTrace: st.toString(),
        metadata: {'driver_id': driverId, 'doc_type': docType},
      );
      rethrow;
    }
  }

  String _contentTypeForExt(String ext) {
    ext = ext.toLowerCase();
    if (ext == 'png') return 'image/png';
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    return 'application/octet-stream';
  }

  /// Fetch documents for driver
  Future<List<Map<String, dynamic>>> listDriverDocuments(String driverId) async {
    final res = await _supabase
        .from('driver_documents')
        .select('*')
        .eq('driver_id', driverId)
        .order('uploaded_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }
}