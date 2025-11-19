import 'package:supabase_flutter/supabase_flutter.dart';

/// Mobile money providers
enum MobileMoneyProvider {
  mpesa,
  orangeMoney,
  airtelMoney;

  String get displayName {
    switch (this) {
      case MobileMoneyProvider.mpesa:
        return 'M-Pesa';
      case MobileMoneyProvider.orangeMoney:
        return 'Orange Money';
      case MobileMoneyProvider.airtelMoney:
        return 'Airtel Money';
    }
  }

  String get ussdCode {
    switch (this) {
      case MobileMoneyProvider.mpesa:
        return '*555#';
      case MobileMoneyProvider.orangeMoney:
        return '*144#';
      case MobileMoneyProvider.airtelMoney:
        return '*150#';
    }
  }

  String get instructions {
    switch (this) {
      case MobileMoneyProvider.mpesa:
        return '1. Dial *555# on your phone\n2. Select "Send Money"\n3. Enter the driver\'s number\n4. Enter the amount\n5. Confirm with your PIN';
      case MobileMoneyProvider.orangeMoney:
        return '1. Dial *144# on your phone\n2. Select "Transfer Money"\n3. Enter the driver\'s number\n4. Enter the amount\n5. Confirm with your PIN';
      case MobileMoneyProvider.airtelMoney:
        return '1. Dial *150# on your phone\n2. Select "Send Money"\n3. Enter the driver\'s number\n4. Enter the amount\n5. Confirm with your PIN';
    }
  }

  static MobileMoneyProvider fromString(String value) {
    switch (value) {
      case 'mpesa':
        return MobileMoneyProvider.mpesa;
      case 'orange_money':
        return MobileMoneyProvider.orangeMoney;
      case 'airtel_money':
        return MobileMoneyProvider.airtelMoney;
      default:
        throw ArgumentError('Invalid mobile money provider: $value');
    }
  }

  String toDbString() {
    switch (this) {
      case MobileMoneyProvider.mpesa:
        return 'mpesa';
      case MobileMoneyProvider.orangeMoney:
        return 'orange_money';
      case MobileMoneyProvider.airtelMoney:
        return 'airtel_money';
    }
  }
}

/// Represents driver's mobile money account
class DriverMobileMoneyAccount {
  final String id;
  final String driverId;
  final MobileMoneyProvider provider;
  final String phoneNumber;
  final String accountName;
  final bool isPrimary;
  final bool isActive;
  final bool isVerified;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DriverMobileMoneyAccount({
    required this.id,
    required this.driverId,
    required this.provider,
    required this.phoneNumber,
    required this.accountName,
    required this.isPrimary,
    required this.isActive,
    required this.isVerified,
    this.verifiedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory DriverMobileMoneyAccount.fromMap(Map<String, dynamic> map) {
    return DriverMobileMoneyAccount(
      id: map['id'] as String,
      driverId: map['driver_id'] as String,
      provider: MobileMoneyProvider.fromString(map['provider'] as String),
      phoneNumber: map['phone_number'] as String,
      accountName: map['account_name'] as String,
      isPrimary: map['is_primary'] as bool,
      isActive: map['is_active'] as bool,
      isVerified: map['is_verified'] as bool,
      verifiedAt: map['verified_at'] != null
          ? DateTime.parse(map['verified_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'provider': provider.toDbString(),
      'phone_number': phoneNumber,
      'account_name': accountName,
      'is_primary': isPrimary,
      'is_active': isActive,
      'is_verified': isVerified,
      'verified_at': verifiedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Service for managing mobile money accounts
class MobileMoneyService {
  final SupabaseClient _supabase;

  MobileMoneyService(this._supabase);

  /// Get all mobile money accounts for a driver
  Future<List<DriverMobileMoneyAccount>> getDriverAccounts(
    String driverId,
  ) async {
    try {
      final response = await _supabase
          .from('driver_mobile_money')
          .select()
          .eq('driver_id', driverId)
          .order('is_primary', ascending: false);

      return (response as List)
          .map((account) => DriverMobileMoneyAccount.fromMap(account))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch mobile money accounts: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching mobile money accounts: $e');
    }
  }

  /// Get driver's primary mobile money account
  Future<DriverMobileMoneyAccount?> getPrimaryAccount(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_mobile_money')
          .select()
          .eq('driver_id', driverId)
          .eq('is_primary', true)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return DriverMobileMoneyAccount.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch primary account: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching primary account: $e');
    }
  }

  /// Get mobile money account for a specific trip's driver
  Future<DriverMobileMoneyAccount?> getDriverAccountForTrip(
    String tripId,
  ) async {
    try {
      // First get the driver ID from the trip
      final tripResponse =
          await _supabase.from('trips').select('driver_id').eq('id', tripId).single();

      final driverId = tripResponse['driver_id'] as String;

      // Then get the primary mobile money account
      return await getPrimaryAccount(driverId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch driver account for trip: ${e.message}');
    } catch (e) {
      throw Exception(
        'Unexpected error fetching driver account for trip: $e',
      );
    }
  }

  /// Create a new mobile money account for a driver
  Future<DriverMobileMoneyAccount> createAccount({
    required String driverId,
    required MobileMoneyProvider provider,
    required String phoneNumber,
    required String accountName,
    bool isPrimary = false,
  }) async {
    try {
      final response = await _supabase
          .from('driver_mobile_money')
          .insert({
            'driver_id': driverId,
            'provider': provider.toDbString(),
            'phone_number': phoneNumber,
            'account_name': accountName,
            'is_primary': isPrimary,
          })
          .select()
          .single();

      return DriverMobileMoneyAccount.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create mobile money account: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating mobile money account: $e');
    }
  }

  /// Update a mobile money account
  Future<DriverMobileMoneyAccount> updateAccount({
    required String accountId,
    String? phoneNumber,
    String? accountName,
    bool? isPrimary,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (accountName != null) updateData['account_name'] = accountName;
      if (isPrimary != null) updateData['is_primary'] = isPrimary;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _supabase
          .from('driver_mobile_money')
          .update(updateData)
          .eq('id', accountId)
          .select()
          .single();

      return DriverMobileMoneyAccount.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update mobile money account: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating mobile money account: $e');
    }
  }

  /// Set an account as primary
  Future<DriverMobileMoneyAccount> setPrimaryAccount(String accountId) async {
    return await updateAccount(accountId: accountId, isPrimary: true);
  }

  /// Delete a mobile money account
  Future<void> deleteAccount(String accountId) async {
    try {
      await _supabase.from('driver_mobile_money').delete().eq('id', accountId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete mobile money account: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting mobile money account: $e');
    }
  }

  /// Get active mobile money accounts (for customer payment selection)
  Future<List<DriverMobileMoneyAccount>> getActiveAccounts(
    String driverId,
  ) async {
    try {
      final response = await _supabase
          .from('driver_mobile_money')
          .select()
          .eq('driver_id', driverId)
          .eq('is_active', true)
          .order('is_primary', ascending: false);

      return (response as List)
          .map((account) => DriverMobileMoneyAccount.fromMap(account))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch active accounts: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching active accounts: $e');
    }
  }
}
