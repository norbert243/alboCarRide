import 'package:flutter_test/flutter_test.dart';
import 'package:albocarride/services/ride_negotiation_service.dart';

void main() {
  group('RideOffer Model', () {
    test('should create from map correctly', () {
      // Arrange
      final offerMap = {
        'id': 'test-offer-123',
        'customer_id': 'customer-456',
        'driver_id': 'driver-789',
        'pickup_location': '123 Main Street',
        'destination': '456 Oak Avenue',
        'proposed_price': 25.5,
        'counter_price': 30.0,
        'status': 'pending',
        'created_at': '2024-01-01T10:00:00.000Z',
        'updated_at': '2024-01-01T10:05:00.000Z',
        'notes': 'Test ride offer',
      };

      // Act
      final offer = RideOffer.fromMap(offerMap);

      // Assert
      expect(offer.id, 'test-offer-123');
      expect(offer.customerId, 'customer-456');
      expect(offer.driverId, 'driver-789');
      expect(offer.pickupLocation, '123 Main Street');
      expect(offer.destination, '456 Oak Avenue');
      expect(offer.proposedPrice, 25.5);
      expect(offer.counterPrice, 30.0);
      expect(offer.status, 'pending');
      expect(offer.notes, 'Test ride offer');
      expect(offer.createdAt, DateTime(2024, 1, 1, 10, 0));
      expect(offer.updatedAt, DateTime(2024, 1, 1, 10, 5));
    });

    test('should handle null optional fields', () {
      // Arrange
      final offerMap = {
        'id': 'test-offer-123',
        'customer_id': 'customer-456',
        'driver_id': 'driver-789',
        'pickup_location': '123 Main Street',
        'destination': '456 Oak Avenue',
        'proposed_price': 25.5,
        'status': 'pending',
        'created_at': '2024-01-01T10:00:00.000Z',
      };

      // Act
      final offer = RideOffer.fromMap(offerMap);

      // Assert
      expect(offer.id, 'test-offer-123');
      expect(offer.counterPrice, isNull);
      expect(offer.updatedAt, isNull);
      expect(offer.notes, isNull);
    });

    test('should convert to map correctly', () {
      // Arrange
      final offer = RideOffer(
        id: 'test-offer-123',
        customerId: 'customer-456',
        driverId: 'driver-789',
        pickupLocation: '123 Main Street',
        destination: '456 Oak Avenue',
        proposedPrice: 25.5,
        counterPrice: 30.0,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1, 10, 0),
        updatedAt: DateTime(2024, 1, 1, 10, 5),
        notes: 'Test ride offer',
      );

      // Act
      final map = offer.toMap();

      // Assert
      expect(map['id'], 'test-offer-123');
      expect(map['customer_id'], 'customer-456');
      expect(map['driver_id'], 'driver-789');
      expect(map['pickup_location'], '123 Main Street');
      expect(map['destination'], '456 Oak Avenue');
      expect(map['proposed_price'], 25.5);
      expect(map['counter_price'], 30.0);
      expect(map['status'], 'pending');
      expect(map['notes'], 'Test ride offer');
      expect(map['created_at'], '2024-01-01T10:00:00.000');
      expect(map['updated_at'], '2024-01-01T10:05:00.000');
    });

    test('should copy with new values', () {
      // Arrange
      final original = RideOffer(
        id: 'original-id',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 20.0,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      // Act
      final copied = original.copyWith(
        status: 'accepted',
        counterPrice: 25.0,
        updatedAt: DateTime(2024, 1, 1, 1, 0),
        notes: 'Accepted offer',
      );

      // Assert
      expect(copied.id, 'original-id');
      expect(copied.customerId, 'customer-1');
      expect(copied.driverId, 'driver-1');
      expect(copied.pickupLocation, 'Location A');
      expect(copied.destination, 'Location B');
      expect(copied.proposedPrice, 20.0);
      expect(copied.status, 'accepted');
      expect(copied.counterPrice, 25.0);
      expect(copied.updatedAt, DateTime(2024, 1, 1, 1, 0));
      expect(copied.notes, 'Accepted offer');
    });

    test('should handle copy with partial values', () {
      // Arrange
      final original = RideOffer(
        id: 'original-id',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 20.0,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
        notes: 'Original notes',
      );

      // Act
      final copied = original.copyWith(status: 'rejected');

      // Assert
      expect(copied.id, 'original-id');
      expect(copied.status, 'rejected');
      expect(copied.notes, 'Original notes'); // Should remain unchanged
      expect(copied.counterPrice, isNull); // Should remain unchanged
    });

    test('should handle different status values', () {
      const statusValues = [
        'pending',
        'accepted',
        'rejected',
        'countered',
        'expired',
      ];

      for (final status in statusValues) {
        final offer = RideOffer(
          id: 'test-$status',
          customerId: 'customer-1',
          driverId: 'driver-1',
          pickupLocation: 'Location A',
          destination: 'Location B',
          proposedPrice: 20.0,
          status: status,
          createdAt: DateTime(2024, 1, 1),
        );

        expect(offer.status, status);
      }
    });

    test('should handle price precision correctly', () {
      final offer = RideOffer(
        id: 'test-price',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 19.999,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(offer.proposedPrice, 19.999);
    });

    test('should handle empty notes', () {
      final offer = RideOffer(
        id: 'test-notes',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 20.0,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
        notes: '',
      );

      expect(offer.notes, '');
    });
  });

  group('RideOffer Edge Cases', () {
    test('should handle very long locations', () {
      final longLocation = 'A' * 500;

      final offer = RideOffer(
        id: 'test-long',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: longLocation,
        destination: longLocation,
        proposedPrice: 20.0,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(offer.pickupLocation, longLocation);
      expect(offer.destination, longLocation);
    });

    test('should handle zero price', () {
      final offer = RideOffer(
        id: 'test-zero',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 0.0,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(offer.proposedPrice, 0.0);
    });

    test('should handle very high price', () {
      final offer = RideOffer(
        id: 'test-high',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 999999.99,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(offer.proposedPrice, 999999.99);
    });

    test('should handle future dates', () {
      final futureDate = DateTime.now().add(const Duration(days: 365));

      final offer = RideOffer(
        id: 'test-future',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 20.0,
        status: 'pending',
        createdAt: futureDate,
      );

      expect(offer.createdAt, futureDate);
    });

    test('should handle very old dates', () {
      final oldDate = DateTime(2000, 1, 1);

      final offer = RideOffer(
        id: 'test-old',
        customerId: 'customer-1',
        driverId: 'driver-1',
        pickupLocation: 'Location A',
        destination: 'Location B',
        proposedPrice: 20.0,
        status: 'pending',
        createdAt: oldDate,
      );

      expect(offer.createdAt, oldDate);
    });
  });
}
