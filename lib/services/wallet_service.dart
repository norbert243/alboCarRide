// lib/services/wallet_service.dart
import 'dart:async';
import 'db_service.dart';
import 'telemetry_service.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  final supabase = DBService.instance.supabase;
  num? _balance;
  StreamSubscription? _walletSub;

  Future<num> getBalance(String driverId) async {
    try {
      final row = await supabase.from('driver_wallets').select('balance').eq('driver_id', driverId).maybeSingle();
      if (row == null) return 0;
      final balance = (row['balance'] as num?) ?? 0;
      
      await TelemetryService.instance.logError(
        type: 'BALANCE_RETRIEVAL',
        message: 'Driver $driverId balance retrieved: $balance',
      );
      
      return balance;
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'BALANCE_RETRIEVAL_ERROR',
        message: 'Failed to get balance for driver $driverId: $e',
        stackTrace: st.toString(),
      );
      return 0;
    }
  }

  Future<bool> canGoOnline(String driverId, {num threshold = 50}) async {
    final bal = await getBalance(driverId);
    if (bal >= threshold) return true;
    await TelemetryService.instance.log(
      'wallet_lockout',
      'driver blocked from going online',
      {'driver_id': driverId, 'balance': bal}
    );
    return false;
  }

  // Alias method for compatibility with existing code
  Future<bool> canGoOnlineEnhanced(String driverId) async {
    return canGoOnline(driverId);
  }

  // Method for compatibility with existing code
  Future<List<Map<String, dynamic>>> fetchTripHistory(String driverId) async {
    try {
      final response = await supabase
        .from('trips')
        .select('*')
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(10);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'TRIP_HISTORY_FETCH_ERROR',
        message: 'Failed to fetch trip history for driver $driverId: $e',
        stackTrace: st.toString(),
      );
      return [];
    }
  }

  void subscribeToWallet(String driverId, void Function(num newBalance) onChange) {
    _walletSub?.cancel();
    _walletSub = supabase
      .from('driver_wallets')
      .stream(primaryKey: ['driver_id'])
      .eq('driver_id', driverId)
      .listen((List<Map<String, dynamic>> data) {
        try {
          if (data.isNotEmpty) {
            final newBalance = data.first['balance'];
            if (newBalance != null) onChange(num.parse(newBalance.toString()));
          }
        } catch (e) {
          TelemetryService.instance.log(
            'wallet_subscription_error',
            e.toString(),
            {'driver_id': driverId}
          );
        }
      });
  }

  void disposeSubscription() {
    _walletSub?.cancel();
    _walletSub = null;
  }
}
