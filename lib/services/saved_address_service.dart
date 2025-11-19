import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a saved address
class SavedAddress {
  final String id;
  final String userId;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? addressType; // 'home', 'work', 'other'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SavedAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    this.addressType,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory SavedAddress.fromMap(Map<String, dynamic> map) {
    return SavedAddress(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      label: map['label'] as String,
      address: map['address'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      addressType: map['address_type'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'address_type': addressType,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Service for managing saved addresses
class SavedAddressService {
  final SupabaseClient _supabase;

  SavedAddressService(this._supabase);

  /// Get all saved addresses for a user
  Future<List<SavedAddress>> getSavedAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((address) => SavedAddress.fromMap(address))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch saved addresses: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching saved addresses: $e');
    }
  }

  /// Get saved addresses by type (home, work, other)
  Future<List<SavedAddress>> getSavedAddressesByType(
    String userId,
    String addressType,
  ) async {
    try {
      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .eq('address_type', addressType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((address) => SavedAddress.fromMap(address))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch saved addresses: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching saved addresses: $e');
    }
  }

  /// Create a new saved address
  Future<SavedAddress> createSavedAddress({
    required String userId,
    required String label,
    required String address,
    double? latitude,
    double? longitude,
    String? addressType,
    String? notes,
  }) async {
    try {
      final response = await _supabase
          .from('saved_addresses')
          .insert({
            'user_id': userId,
            'label': label,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'address_type': addressType,
            'notes': notes,
          })
          .select()
          .single();

      return SavedAddress.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create saved address: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating saved address: $e');
    }
  }

  /// Update a saved address
  Future<SavedAddress> updateSavedAddress({
    required String addressId,
    String? label,
    String? address,
    double? latitude,
    double? longitude,
    String? addressType,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (label != null) updateData['label'] = label;
      if (address != null) updateData['address'] = address;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (addressType != null) updateData['address_type'] = addressType;
      if (notes != null) updateData['notes'] = notes;

      final response = await _supabase
          .from('saved_addresses')
          .update(updateData)
          .eq('id', addressId)
          .select()
          .single();

      return SavedAddress.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update saved address: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating saved address: $e');
    }
  }

  /// Delete a saved address
  Future<void> deleteSavedAddress(String addressId) async {
    try {
      await _supabase.from('saved_addresses').delete().eq('id', addressId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete saved address: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting saved address: $e');
    }
  }

  /// Get a specific saved address by ID
  Future<SavedAddress> getSavedAddress(String addressId) async {
    try {
      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('id', addressId)
          .single();

      return SavedAddress.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch saved address: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching saved address: $e');
    }
  }

  /// Check if a label already exists for the user
  Future<bool> labelExists(String userId, String label) async {
    try {
      final response = await _supabase
          .from('saved_addresses')
          .select('id')
          .eq('user_id', userId)
          .eq('label', label);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
