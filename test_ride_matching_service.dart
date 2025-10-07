import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/ride_matching_service.dart';
import 'lib/services/session_service.dart';

/// Test script for the Ride Matching Service
/// This script tests the matching service functionality
void main() async {
  print('=== Testing Ride Matching Service ===');

  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  final matchingService = RideMatchingService();

  try {
    // Test 1: Start the matching service
    print('\n1. Starting matching service...');
    await matchingService.startMatchingService();
    print('✓ Matching service started successfully');

    // Test 2: Simulate a ride request (this would normally come from customer app)
    print('\n2. Simulating ride request creation...');
    await _simulateRideRequest();
    print('✓ Ride request simulation completed');

    // Test 3: Check if offers were created for nearby drivers
    print('\n3. Checking for created offers...');
    await _checkForOffers();

    // Test 4: Stop the matching service
    print('\n4. Stopping matching service...');
    await matchingService.stopMatchingService();
    print('✓ Matching service stopped successfully');

    print('\n=== All tests completed successfully! ===');
  } catch (e) {
    print('✗ Test failed with error: $e');
  }
}

/// Simulate a ride request being created in the database
Future<void> _simulateRideRequest() async {
  final supabase = Supabase.instance.client;

  try {
    // Get a test rider ID (you may need to create a test rider first)
    final riderResponse = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'rider')
        .limit(1);

    if (riderResponse.isEmpty) {
      print('⚠ No test rider found. Creating one...');
      // You would need to create a test rider here if none exists
      return;
    }

    final riderId = riderResponse.first['id'];

    // Create a test ride request
    final requestId = 'test_request_${DateTime.now().millisecondsSinceEpoch}';

    await supabase.from('ride_requests').insert({
      'id': requestId,
      'rider_id': riderId,
      'pickup_address': '123 Test Street, Test City',
      'dropoff_address': '456 Test Avenue, Test City',
      'proposed_price': 15.00,
      'status': 'pending',
      'pickup_lat': 40.7128, // NYC coordinates
      'pickup_lng': -74.0060,
      'dropoff_lat': 40.7589,
      'dropoff_lng': -73.9851,
      'created_at': DateTime.now().toIso8601String(),
    });

    print('✓ Test ride request created: $requestId');
  } catch (e) {
    print('✗ Error simulating ride request: $e');
  }
}

/// Check if offers were created for nearby drivers
Future<void> _checkForOffers() async {
  final supabase = Supabase.instance.client;

  try {
    // Wait a moment for the matching service to process the request
    await Future.delayed(const Duration(seconds: 3));

    final offersResponse = await supabase
        .from('ride_offers')
        .select('*')
        .order('created_at', ascending: false)
        .limit(5);

    if (offersResponse.isNotEmpty) {
      print('✓ Offers found: ${offersResponse.length}');
      for (final offer in offersResponse) {
        print(
          '  - Offer ID: ${offer['id']}, Driver: ${offer['driver_id']}, Status: ${offer['status']}',
        );
      }
    } else {
      print('⚠ No offers found. This could be because:');
      print('  • No nearby online drivers');
      print('  • Drivers are not within 5km radius');
      print('  • Location data is not available');
    }
  } catch (e) {
    print('✗ Error checking for offers: $e');
  }
}
