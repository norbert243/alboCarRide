import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a ride offer from a customer to a driver
class RideOffer {
  final String id;
  final String customerId;
  final String driverId;
  final String pickupLocation;
  final String destination;
  final double proposedPrice;
  final double? counterPrice;
  final String status; // 'pending', 'accepted', 'rejected', 'countered'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;

  RideOffer({
    required this.id,
    required this.customerId,
    required this.driverId,
    required this.pickupLocation,
    required this.destination,
    required this.proposedPrice,
    this.counterPrice,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory RideOffer.fromMap(Map<String, dynamic> map) {
    return RideOffer(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      driverId: map['driver_id'] as String,
      pickupLocation: map['pickup_location'] as String,
      destination: map['destination'] as String,
      proposedPrice: (map['proposed_price'] as num).toDouble(),
      counterPrice: map['counter_price'] != null
          ? (map['counter_price'] as num).toDouble()
          : null,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'driver_id': driverId,
      'pickup_location': pickupLocation,
      'destination': destination,
      'proposed_price': proposedPrice,
      'counter_price': counterPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Creates a copy with updated values
  RideOffer copyWith({
    String? id,
    String? customerId,
    String? driverId,
    String? pickupLocation,
    String? destination,
    double? proposedPrice,
    double? counterPrice,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return RideOffer(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destination: destination ?? this.destination,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      counterPrice: counterPrice ?? this.counterPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }
}

/// Service for managing ride offers and negotiations
class RideNegotiationService {
  final SupabaseClient _supabase;

  RideNegotiationService(this._supabase);

  /// Creates a new ride offer
  Future<RideOffer> createOffer({
    required String customerId,
    required String driverId,
    required String pickupLocation,
    required String destination,
    required double proposedPrice,
    String? notes,
  }) async {
    try {
      final offerId = _generateUuid();
      final now = DateTime.now();

      final response = await _supabase
          .from('ride_offers')
          .insert({
            'id': offerId,
            'customer_id': customerId,
            'driver_id': driverId,
            'pickup_location': pickupLocation,
            'destination': destination,
            'proposed_price': proposedPrice,
            'status': 'pending',
            'created_at': now.toIso8601String(),
            'notes': notes,
          })
          .select()
          .single();

      return RideOffer.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create ride offer: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating ride offer: $e');
    }
  }

  /// Accepts a ride offer using the atomic RPC function
  Future<RideOffer> acceptOffer(String offerId) async {
    try {
      final response = await _supabase
          .rpc('accept_offer_atomic', params: {'offer_id': offerId})
          .select()
          .single();

      return RideOffer.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') {
        throw Exception('Offer no longer available or already accepted');
      }
      throw Exception('Failed to accept offer: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error accepting offer: $e');
    }
  }

  /// Rejects a ride offer
  Future<RideOffer> rejectOffer(String offerId) async {
    try {
      final response = await _supabase
          .from('ride_offers')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', offerId)
          .eq('status', 'pending') // Only reject pending offers
          .select()
          .single();

      return RideOffer.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to reject offer: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error rejecting offer: $e');
    }
  }

  /// Counter a ride offer with a new price
  Future<RideOffer> counterOffer(String offerId, double counterPrice) async {
    try {
      final response = await _supabase
          .from('ride_offers')
          .update({
            'counter_price': counterPrice,
            'status': 'countered',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', offerId)
          .eq('status', 'pending') // Only counter pending offers
          .select()
          .single();

      return RideOffer.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to counter offer: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error countering offer: $e');
    }
  }

  /// Gets all offers for a specific driver
  Future<List<RideOffer>> getDriverOffers(String driverId) async {
    try {
      final response = await _supabase
          .from('ride_offers')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((offer) => RideOffer.fromMap(offer))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch driver offers: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching driver offers: $e');
    }
  }

  /// Gets pending offers for a specific driver
  Future<List<RideOffer>> getPendingOffers(String driverId) async {
    try {
      final response = await _supabase
          .from('ride_offers')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((offer) => RideOffer.fromMap(offer))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pending offers: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching pending offers: $e');
    }
  }

  /// Gets a specific offer by ID
  Future<RideOffer> getOffer(String offerId) async {
    try {
      final response = await _supabase
          .from('ride_offers')
          .select()
          .eq('id', offerId)
          .single();

      return RideOffer.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch offer: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching offer: $e');
    }
  }

  /// Subscribes to real-time updates for a driver's offers
  Stream<List<RideOffer>> watchDriverOffers(String driverId) {
    final controller = StreamController<List<RideOffer>>();

    // Get initial data
    getDriverOffers(driverId)
        .then((offers) {
          controller.add(offers);
        })
        .catchError((error) {
          controller.addError(error);
        });

    // Set up real-time subscription
    final subscription = _supabase
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .listen((event) {
          try {
            // Filter for this driver's offers
            final offers =
                (event as List)
                    .where((offer) => offer['driver_id'] == driverId)
                    .map((offer) => RideOffer.fromMap(offer))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(offers);
          } catch (e) {
            controller.addError(e);
          }
        });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Subscribes to real-time updates for pending offers
  Stream<List<RideOffer>> watchPendingOffers(String driverId) {
    final controller = StreamController<List<RideOffer>>();

    // Get initial data
    getPendingOffers(driverId)
        .then((offers) {
          controller.add(offers);
        })
        .catchError((error) {
          controller.addError(error);
        });

    // Set up real-time subscription
    final subscription = _supabase
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .listen((event) {
          try {
            // Filter for this driver's pending offers
            final offers =
                (event as List)
                    .where(
                      (offer) =>
                          offer['driver_id'] == driverId &&
                          offer['status'] == 'pending',
                    )
                    .map((offer) => RideOffer.fromMap(offer))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(offers);
          } catch (e) {
            controller.addError(e);
          }
        });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Gets offer statistics for a driver
  Future<Map<String, int>> getOfferStats(String driverId) async {
    try {
      final response = await _supabase
          .from('ride_offers')
          .select('status')
          .eq('driver_id', driverId);

      final stats = {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'rejected': 0,
        'countered': 0,
      };

      for (final offer in response) {
        stats['total'] = (stats['total'] ?? 0) + 1;
        final status = offer['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch offer statistics: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching offer statistics: $e');
    }
  }

  /// Cleans up expired offers (older than 1 hour)
  Future<int> cleanupExpiredOffers() async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      final response = await _supabase
          .from('ride_offers')
          .update({
            'status': 'expired',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('status', 'pending')
          .lt('created_at', oneHourAgo.toIso8601String())
          .select();

      return response.length;
    } on PostgrestException catch (e) {
      throw Exception('Failed to cleanup expired offers: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error cleaning up expired offers: $e');
    }
  }

  /// Generates a UUID v4
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant (8, 9, A, or B)
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
