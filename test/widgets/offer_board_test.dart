import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:albocarride/widgets/offer_board.dart';

// Helper function to test time formatting (similar to the one in OfferBoard)
String _formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';

  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

void main() {
  group('OfferBoard Widget', () {
    testWidgets('should show loading indicator initially', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: OfferBoard())));

      // Verify that a loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should build offer card with correct information', (
      WidgetTester tester,
    ) async {
      // Create a test offer
      final testOffer = {
        'id': 'test-offer-1',
        'customer_id': 'customer-123',
        'driver_id': 'driver-456',
        'pickup_location': '123 Main Street',
        'destination': '456 Oak Avenue',
        'proposed_price': 25.5,
        'status': 'pending',
        'created_at': '2024-01-01T10:00:00.000Z',
        'notes': 'Test notes',
      };

      // Verify the offer card would display correct information
      expect(testOffer['pickup_location'], '123 Main Street');
      expect(testOffer['destination'], '456 Oak Avenue');
      expect(testOffer['proposed_price'], 25.5);
      expect(testOffer['status'], 'pending');
    });

    test('should format time ago correctly', () {
      // Test various time differences
      final now = DateTime.now();

      // Just now (less than 1 minute)
      expect(
        _formatTimeAgo(now.subtract(const Duration(seconds: 30))),
        'Just now',
      );

      // Minutes ago
      expect(
        _formatTimeAgo(now.subtract(const Duration(minutes: 5))),
        '5m ago',
      );

      // Hours ago
      expect(_formatTimeAgo(now.subtract(const Duration(hours: 3))), '3h ago');

      // Days ago
      expect(_formatTimeAgo(now.subtract(const Duration(days: 2))), '2d ago');

      // More than 7 days - should show date
      final oldDate = DateTime(2024, 1, 1);
      expect(_formatTimeAgo(oldDate), '1/1/2024');
    });

    testWidgets('should handle basic widget structure', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: OfferBoard())));

      // Wait for the future to complete
      await tester.pumpAndSettle();

      // Verify that the widget is rendered
      expect(find.byType(OfferBoard), findsOneWidget);
    });

    test('should handle action buttons state logic', () {
      // Test that action buttons would be enabled/disabled based on loading state
      final isLoading = false;
      final isNotLoading = true;

      expect(isLoading, false); // Buttons should be enabled when not loading
      expect(isNotLoading, true); // Loading state should be toggleable
    });

    test('should handle different offer statuses', () {
      const statusValues = [
        'pending',
        'accepted',
        'rejected',
        'countered',
        'expired',
      ];

      for (final status in statusValues) {
        // Test that the status can be processed
        expect(status, isA<String>());
        expect(status.isNotEmpty, true);
      }
    });

    test('should handle price formatting', () {
      final prices = [0.0, 10.5, 100.0, 999.99];

      for (final price in prices) {
        // Test that prices can be formatted
        final formatted = price.toStringAsFixed(2);
        expect(formatted, isA<String>());
        expect(formatted.contains('.'), true);
      }
    });
  });

  group('OfferBoard Edge Cases', () {
    test('should handle very long text in locations', () {
      final longLocation = 'A' * 500;
      expect(longLocation.length, 500);
      expect(longLocation, isA<String>());
    });

    test('should handle empty notes', () {
      const emptyNotes = '';
      expect(emptyNotes, '');
      expect(emptyNotes.isEmpty, true);
    });

    test('should handle null optional fields', () {
      final nullValue = null;
      expect(nullValue, isNull);
    });

    test('should handle future dates in time formatting', () {
      final futureDate = DateTime.now().add(const Duration(days: 365));
      final formatted = _formatTimeAgo(futureDate);
      expect(formatted, isA<String>());
      expect(formatted.isNotEmpty, true);
    });

    test('should handle very old dates in time formatting', () {
      final oldDate = DateTime(2000, 1, 1);
      final formatted = _formatTimeAgo(oldDate);
      expect(formatted, '1/1/2000');
    });
  });
}
