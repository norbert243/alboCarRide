import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/screens/home/book_ride_page.dart';
import 'package:albocarride/widgets/available_rides_widget.dart';
import 'package:albocarride/screens/home/comprehensive_driver_dashboard.dart';
import 'driver_and_customer_interaction_test.mocks.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  PostgrestClient,
  PostgrestQueryBuilder,
  PostgrestFilterBuilder,
  RealtimeClient,
  RealtimeChannel
])
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockPostgrestQueryBuilder<Map<String, dynamic>> mockPostgrestQueryBuilder;
  late MockPostgrestFilterBuilder<Map<String, dynamic>> mockPostgrestFilterBuilder;
  late MockRealtimeClient mockRealtimeClient;
  late MockRealtimeChannel mockRealtimeChannel;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockPostgrestQueryBuilder = MockPostgrestQueryBuilder<Map<String, dynamic>>();
    mockPostgrestFilterBuilder = MockPostgrestFilterBuilder<Map<String, dynamic>>();
    mockRealtimeClient = MockRealtimeClient();
    mockRealtimeChannel = MockRealtimeChannel();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockSupabaseClient.from(any)).thenReturn(mockPostgrestQueryBuilder);
    when(mockPostgrestQueryBuilder.insert(any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestQueryBuilder.update(any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.eq(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.select()).thenAnswer((_) async => []);
    when(mockSupabaseClient.realtime).thenReturn(mockRealtimeClient);
    when(mockRealtimeClient.channel(any)).thenReturn(mockRealtimeChannel);
    when(mockRealtimeChannel.on(any, any)).thenReturn(mockRealtimeChannel);
    when(mockRealtimeChannel.subscribe(any)).thenReturn(mockRealtimeChannel);
  });

  testWidgets('Customer books a ride and driver accepts it', (WidgetTester tester) async {
    // --- Customer side ---
    await tester.pumpWidget(MaterialApp(
      home: BookRidePage(),
    ));

    // Mock Supabase.instance.client
    final originalSupabaseClient = Supabase.instance.client;
    Supabase.instance.client = mockSupabaseClient;

    // Enter pickup and dropoff locations
    await tester.enterText(find.byType(TextFormField).at(0), 'Pickup Location');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dropoff Location');
    await tester.pumpAndSettle();

    // Tap the book ride button
    await tester.tap(find.text('Book Ride'));
    await tester.pumpAndSettle();

    // Verify that the insert method was called on the ride_requests table
    final verificationResult = verify(mockPostgrestQueryBuilder.insert(captureAny));
    verificationResult.called(1);
    final capturedInsert = verificationResult.captured.first as Map<String, dynamic>;
    expect(capturedInsert['pickup_address'], 'Pickup Location');
    expect(capturedInsert['dropoff_address'], 'Dropoff Location');

    // --- Driver side ---
    await tester.pumpWidget(MaterialApp(
      home: ComprehensiveDriverDashboard(),
    ));

    // Mock the ride requests stream
    when(mockPostgrestQueryBuilder.stream(primaryKey: ['id'])).thenAnswer((_) => Stream.value([
          {
            'id': '1',
            'pickup_address': 'Pickup Location',
            'dropoff_address': 'Dropoff Location',
            'estimated_price': 25.0,
            'status': 'pending'
          }
        ]));

    await tester.pumpAndSettle();

    // Verify that the available ride is displayed
    expect(find.text('Pickup Location'), findsOneWidget);
    expect(find.text('Dropoff Location'), findsOneWidget);

    // Tap on the ride to open the offer dialog
    await tester.tap(find.text('Pickup Location'));
    await tester.pumpAndSettle();

    // Verify the dialog is shown
    expect(find.text('Accept Ride'), findsOneWidget);
    expect(find.text('Send Counter-Offer'), findsOneWidget);

    // Tap the accept button
    await tester.tap(find.text('Accept Ride'));
    await tester.pumpAndSettle();

    // Verify that a new trip is created
    final tripInsertVerification = verify(mockPostgrestQueryBuilder.insert(captureAny, value: anyNamed('value')));
    tripInsertVerification.called(1);
    final capturedTripInsert = tripInsertVerification.captured.first as Map<String, dynamic>;
    expect(capturedTripInsert['pickup_address'], 'Pickup Location');
    expect(capturedTripInsert['dropoff_address'], 'Dropoff Location');
    expect(capturedTripInsert['status'], 'accepted');

    // Restore original Supabase client
    Supabase.instance.client = originalSupabaseClient;
  });
}
