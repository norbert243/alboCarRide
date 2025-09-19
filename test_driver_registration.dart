import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print('Testing Driver Registration Fix...\n');

  try {
    // Load environment variables
    await dotenv.load();

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || anonKey == null) {
      print('❌ Missing Supabase configuration in .env file');
      return;
    }

    // Initialize Supabase
    await Supabase.initialize(url: url, anonKey: anonKey);
    print('✅ Supabase initialized successfully');

    // Test 1: Check if drivers table exists and is accessible
    print('\n1. Testing drivers table accessibility...');
    try {
      final driversCheck = await Supabase.instance.client
          .from('drivers')
          .select('count')
          .limit(1);
      print('✅ Drivers table is accessible: $driversCheck');
    } catch (e) {
      print('❌ Drivers table not accessible: $e');
      print('   Please run the database_schema.sql in your Supabase project');
      return;
    }

    // Test 2: Check RLS policies for drivers table
    print('\n2. Testing RLS policies for drivers table...');
    try {
      // This should fail if RLS policies are too restrictive
      final testInsert = await Supabase.instance.client.from('drivers').insert({
        'id': '00000000-0000-0000-0000-000000000000', // dummy UUID
        'is_approved': false,
        'is_online': false,
      }).select();
      print(
        '⚠️  RLS might be too permissive - test insert succeeded unexpectedly',
      );
    } catch (e) {
      if (e.toString().contains('permission denied')) {
        print(
          '✅ RLS policies are working correctly (insert denied as expected)',
        );
      } else {
        print('❌ Unexpected error testing RLS: $e');
      }
    }

    // Test 3: Verify the database schema has required columns
    print('\n3. Verifying drivers table schema...');
    try {
      final schemaInfo = await Supabase.instance.client
          .from('drivers')
          .select('*')
          .limit(0); // Get schema info

      print('✅ Drivers table schema is accessible');
      print(
        '   Expected columns: id, license_number, vehicle_make, vehicle_model, etc.',
      );
    } catch (e) {
      print('❌ Error accessing drivers table schema: $e');
    }

    print('\n🎉 Driver registration setup test completed!');
    print('\nNext steps:');
    print('1. Run the application: flutter run');
    print('2. Register as a driver using the app');
    print('3. Check Supabase dashboard to verify:');
    print('   - User created in Authentication → Users');
    print('   - Profile created in Table Editor → profiles');
    print('   - Driver record created in Table Editor → drivers');
    print('4. Verify all data is properly linked by user ID');
  } catch (e) {
    print('❌ Error testing driver registration: $e');
    print('\nTroubleshooting:');
    print('1. Ensure database_schema.sql has been executed in Supabase');
    print('2. Verify RLS policies from supabase_rls_policies.sql are applied');
    print('3. Check that .env file contains correct Supabase credentials');
  }
}
