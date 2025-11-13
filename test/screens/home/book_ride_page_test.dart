import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/location_service.dart';
import 'package:albocarride/services/session_service.dart';

@GenerateMocks([SupabaseClient, GoTrueClient, FunctionsClient, RealtimeClient, PostgrestClient, SupabaseQueryBuilder, PostgrestFilterBuilder, PostgrestTransformBuilder, LocationService, SessionService])
void main() {
  // This file is used to generate mocks for the Supabase client.
  // It should not contain any tests.
}
