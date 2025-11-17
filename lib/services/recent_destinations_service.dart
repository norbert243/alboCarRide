import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a recent destination
class RecentDestination {
  final String id;
  final String userId;
  final String address;
  final double? latitude;
  final double? longitude;
  final int visitCount;
  final DateTime lastVisitedAt;
  final DateTime createdAt;

  RecentDestination({
    required this.id,
    required this.userId,
    required this.address,
    this.latitude,
    this.longitude,
    required this.visitCount,
    required this.lastVisitedAt,
    required this.createdAt,
  });

  factory RecentDestination.fromMap(Map<String, dynamic> map) {
    return RecentDestination(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      address: map['address'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      visitCount: map['visit_count'] as int,
      lastVisitedAt: DateTime.parse(map['last_visited_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'visit_count': visitCount,
      'last_visited_at': lastVisitedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Service for managing recent destinations
class RecentDestinationsService {
  final SupabaseClient _supabase;

  RecentDestinationsService(this._supabase);

  /// Get recent destinations for a user (ordered by last visited)
  Future<List<RecentDestination>> getRecentDestinations(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('recent_destinations')
          .select()
          .eq('user_id', userId)
          .order('last_visited_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((destination) => RecentDestination.fromMap(destination))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch recent destinations: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching recent destinations: $e');
    }
  }

  /// Get most frequently visited destinations
  Future<List<RecentDestination>> getMostFrequentDestinations(
    String userId, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('recent_destinations')
          .select()
          .eq('user_id', userId)
          .order('visit_count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((destination) => RecentDestination.fromMap(destination))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch frequent destinations: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching frequent destinations: $e');
    }
  }

  /// Add or update a recent destination (upsert)
  /// This uses the database function to handle incrementing visit count
  Future<void> addRecentDestination({
    required String userId,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Call the database function to upsert
      await _supabase.rpc('upsert_recent_destination', params: {
        'p_user_id': userId,
        'p_address': address,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to add recent destination: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error adding recent destination: $e');
    }
  }

  /// Clear all recent destinations for a user
  Future<void> clearRecentDestinations(String userId) async {
    try {
      await _supabase
          .from('recent_destinations')
          .delete()
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to clear recent destinations: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error clearing recent destinations: $e');
    }
  }

  /// Delete a specific recent destination
  Future<void> deleteRecentDestination(String destinationId) async {
    try {
      await _supabase
          .from('recent_destinations')
          .delete()
          .eq('id', destinationId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete recent destination: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting recent destination: $e');
    }
  }

  /// Search recent destinations by address
  Future<List<RecentDestination>> searchRecentDestinations(
    String userId,
    String searchQuery,
  ) async {
    try {
      final response = await _supabase
          .from('recent_destinations')
          .select()
          .eq('user_id', userId)
          .ilike('address', '%$searchQuery%')
          .order('last_visited_at', ascending: false)
          .limit(10);

      return (response as List)
          .map((destination) => RecentDestination.fromMap(destination))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to search recent destinations: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error searching recent destinations: $e');
    }
  }
}
