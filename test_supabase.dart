import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print('Testing Supabase connection...');

  try {
    // Load environment variables
    await dotenv.load();

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    print('Supabase URL: $url');
    print('Anon Key: ${anonKey?.substring(0, 20)}...');

    if (url == null || anonKey == null) {
      print('❌ Missing Supabase configuration in .env file');
      return;
    }

    // Initialize Supabase
    await Supabase.initialize(url: url, anonKey: anonKey);

    print('✅ Supabase initialized successfully');

    // Test connection by fetching auth settings
    final authSettings = Supabase.instance.client.auth;
    print('✅ Auth service available');

    // Test database connection
    final response = await Supabase.instance.client
        .from('profiles')
        .select('count')
        .limit(1);
    print('✅ Database connection successful: $response');

    print('\n🎉 All tests passed! Supabase is configured correctly.');
  } catch (e) {
    print('❌ Error testing Supabase: $e');
    print('\nPlease check:');
    print('1. Your Supabase project is active');
    print('2. The database schema is applied (run database_schema.sql)');
    print('3. RLS policies are properly configured');
  }
}
