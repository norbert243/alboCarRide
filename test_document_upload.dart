import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'lib/services/document_upload_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (you'll need to add your credentials)
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(DocumentUploadTestApp());
}

class DocumentUploadTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DocumentUploadTestPage());
  }
}

class DocumentUploadTestPage extends StatefulWidget {
  @override
  _DocumentUploadTestPageState createState() => _DocumentUploadTestPageState();
}

class _DocumentUploadTestPageState extends State<DocumentUploadTestPage> {
  final DocumentUploadService _uploadService = DocumentUploadService();
  String _status = 'Ready to test';
  String _uploadedUrl = '';

  Future<void> _testDocumentUpload() async {
    setState(() {
      _status = 'Testing document upload...';
      _uploadedUrl = '';
    });

    try {
      // Test with a sample user ID
      final testUserId = 'test-user-123';

      // Try to pick and upload a document
      final url = await _uploadService.pickAndUploadDocument(
        source: ImageSource.gallery,
        userId: testUserId,
        documentType: DocumentType.driverLicense,
      );

      setState(() {
        _status = 'Upload successful!';
        _uploadedUrl = url;
      });

      print('Upload successful: $url');
    } catch (e) {
      setState(() {
        _status = 'Upload failed: $e';
      });

      print('Upload failed: $e');
      print('Error type: ${e.runtimeType}');
    }
  }

  Future<void> _testBucketConnection() async {
    setState(() {
      _status = 'Testing bucket connection...';
    });

    try {
      final supabase = Supabase.instance.client;

      // Test if we can list the bucket contents
      final response = await supabase.storage.from('driver-documents').list();

      setState(() {
        _status =
            'Bucket connection successful! Found ${response.length} items';
      });

      print('Bucket contents: $response');
    } catch (e) {
      setState(() {
        _status = 'Bucket connection failed: $e';
      });

      print('Bucket connection failed: $e');
      print('Error type: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Upload Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Document Upload Service Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Status: $_status',
              style: TextStyle(
                fontSize: 16,
                color: _status.contains('failed') ? Colors.red : Colors.green,
              ),
            ),
            SizedBox(height: 10),
            if (_uploadedUrl.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uploaded URL:'),
                  SelectableText(
                    _uploadedUrl,
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _testBucketConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text('Test Bucket Connection'),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: _testDocumentUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text('Test Document Upload'),
            ),
            SizedBox(height: 30),
            Text(
              'Debug Information:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '• Bucket: driver-documents\n'
              '• Path structure: user_id/document_type/filename\n'
              '• Max file size: 5MB\n'
              '• Supported formats: Images + PDF/DOC',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
