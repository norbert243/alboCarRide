// Simple test to verify document upload service functionality
// Run this to test if the driver-documents bucket is accessible

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('=== Document Upload Service Test ===');

  try {
    // Initialize Supabase (you'll need to configure your credentials)
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL', // Replace with your Supabase URL
      anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with your anon key
    );

    final supabase = Supabase.instance.client;

    print('1. Testing Supabase connection...');

    // Test authentication
    final session = supabase.auth.currentSession;
    if (session == null) {
      print('   ❌ No active session - user needs to be authenticated');
      print('   ℹ️  Document upload requires authenticated user');
      return;
    }

    print('   ✅ User authenticated: ${session.user.email}');

    print('2. Testing bucket access...');

    // Test if we can access the driver-documents bucket
    try {
      final bucketList = await supabase.storage.from('driver-documents').list();

      print('   ✅ Bucket accessible! Found ${bucketList.length} items');
      print('   📁 Bucket contents:');
      for (final item in bucketList) {
        print('      - ${item.name} (${item.id})');
      }
    } catch (e) {
      print('   ❌ Bucket access failed: $e');
      print('   ℹ️  This could be due to:');
      print('      • Bucket not existing');
      print('      • RLS policies blocking access');
      print('      • Network connectivity issues');
      return;
    }

    print('3. Testing file upload permissions...');

    // Test if we can upload a small test file
    final testUserId = session.user.id;
    final testPath = '$testUserId/test_folder/test_file.txt';
    final testContent = 'Test file content - ${DateTime.now()}';

    try {
      await supabase.storage
          .from('driver-documents')
          .uploadBinary(
            testPath,
            Uint8List.fromList(testContent.codeUnits),
            fileOptions: FileOptions(upsert: true),
          );

      print('   ✅ File upload successful!');
      print('   📄 Uploaded to: $testPath');

      // Clean up test file
      await supabase.storage.from('driver-documents').remove([testPath]);

      print('   🧹 Test file cleaned up');
    } catch (e) {
      print('   ❌ File upload failed: $e');
      print('   ℹ️  This could be due to:');
      print('      • Insufficient permissions');
      print('      • RLS policy restrictions');
      print('      • File size/type restrictions');
      return;
    }

    print('4. Testing document upload service...');

    try {
      // Import and test the actual DocumentUploadService
      // This would require the full Flutter environment
      print('   ⚠️  Full service test requires Flutter environment');
      print('   ℹ️  Run the main app to test complete document upload flow');
    } catch (e) {
      print('   ❌ Service test failed: $e');
    }

    print('\n=== Test Summary ===');
    print('✅ Supabase connection: Working');
    print('✅ Bucket access: Working');
    print('✅ File upload permissions: Working');
    print('⚠️  Full service test: Requires Flutter app');
    print('\nNext steps:');
    print('1. Run the main Flutter app');
    print('2. Test document upload in driver verification flow');
    print('3. Check console logs for any upload errors');
  } catch (e) {
    print('❌ Test failed with error: $e');
    print('\nTroubleshooting steps:');
    print('1. Check Supabase credentials in .env file');
    print('2. Verify driver-documents bucket exists in Supabase dashboard');
    print('3. Check RLS policies for the storage bucket');
    print('4. Ensure user is properly authenticated');
  }
}
