import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'telemetry_service.dart';

class RealtimeWalletService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static RealtimeWalletService? _instance;
  RealtimeWalletService._internal();

  factory RealtimeWalletService() {
    _instance ??= RealtimeWalletService._internal();
    return _instance!;
  }

  // Active subscriptions
  final Map<String, RealtimeChannel> _activeSubscriptions = {};

  /// Subscribe to realtime wallet updates for a driver
  Future<void> subscribeToWalletUpdates(
    String driverId,
    Function(double newBalance) onBalanceUpdate,
  ) async {
    try {
      // Unsubscribe from existing subscription for this driver
      await _unsubscribeFromWalletUpdates(driverId);

      final channel = _supabase
          .channel('driver_wallets:driver_id=eq.$driverId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'driver_wallets',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'driver_id',
              value: driverId,
            ),
            callback: (payload) {
              final newBalance = payload.newRecord['balance']?.toDouble();
              if (newBalance != null) {
                onBalanceUpdate(newBalance);

                // Log successful realtime update
                TelemetryService.instance.logError(
                  type: 'REALTIME_WALLET_UPDATE',
                  message: 'Driver $driverId balance updated to $newBalance',
                );
              }
            },
          )
          .subscribe();

      _activeSubscriptions[driverId] = channel;

      // Log subscription success
      await TelemetryService.instance.logError(
        type: 'WALLET_SUBSCRIPTION_CREATED',
        message: 'Realtime wallet subscription created for driver $driverId',
      );
    } catch (e, stackTrace) {
      await TelemetryService.instance.logError(
        type: 'WALLET_SUBSCRIPTION_ERROR',
        message:
            'Failed to subscribe to wallet updates for driver $driverId: $e',
        stackTrace: stackTrace.toString(),
      );
      rethrow;
    }
  }

  /// Unsubscribe from wallet updates for a specific driver
  Future<void> _unsubscribeFromWalletUpdates(String driverId) async {
    final channel = _activeSubscriptions[driverId];
    if (channel != null) {
      await _supabase.removeChannel(channel);
      _activeSubscriptions.remove(driverId);

      await TelemetryService.instance.logError(
        type: 'WALLET_SUBSCRIPTION_REMOVED',
        message: 'Realtime wallet subscription removed for driver $driverId',
      );
    }
  }

  /// Unsubscribe from all wallet updates
  Future<void> unsubscribeFromAllWalletUpdates() async {
    for (final channel in _activeSubscriptions.values) {
      await _supabase.removeChannel(channel);
    }
    _activeSubscriptions.clear();

    await TelemetryService.instance.logError(
      type: 'ALL_WALLET_SUBSCRIPTIONS_REMOVED',
      message: 'All realtime wallet subscriptions removed',
    );
  }

  /// Register FCM token for push notifications
  Future<void> registerFCMToken(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _supabase.from('fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });

        await TelemetryService.instance.logError(
          type: 'FCM_TOKEN_REGISTERED',
          message: 'FCM token registered for user $userId',
        );
      }
    } catch (e, stackTrace) {
      await TelemetryService.instance.logError(
        type: 'FCM_TOKEN_REGISTRATION_ERROR',
        message: 'Failed to register FCM token for user $userId: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Unregister FCM token
  Future<void> unregisterFCMToken(String userId) async {
    try {
      await _supabase.from('fcm_tokens').delete().eq('user_id', userId);

      await TelemetryService.instance.logError(
        type: 'FCM_TOKEN_UNREGISTERED',
        message: 'FCM token unregistered for user $userId',
      );
    } catch (e, stackTrace) {
      await TelemetryService.instance.logError(
        type: 'FCM_TOKEN_UNREGISTRATION_ERROR',
        message: 'Failed to unregister FCM token for user $userId: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Subscribe to FCM topics for driver notifications
  Future<void> subscribeToDriverTopics(String driverId) async {
    try {
      await _firebaseMessaging.subscribeToTopic('driver_$driverId');
      await _firebaseMessaging.subscribeToTopic('low_balance_alerts');
      await _firebaseMessaging.subscribeToTopic('trip_updates');

      await TelemetryService.instance.logError(
        type: 'FCM_TOPICS_SUBSCRIBED',
        message: 'Driver $driverId subscribed to FCM topics',
      );
    } catch (e, stackTrace) {
      await TelemetryService.instance.logError(
        type: 'FCM_TOPICS_SUBSCRIPTION_ERROR',
        message: 'Failed to subscribe driver $driverId to FCM topics: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Unsubscribe from FCM topics
  Future<void> unsubscribeFromDriverTopics(String driverId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('driver_$driverId');
      await _firebaseMessaging.unsubscribeFromTopic('low_balance_alerts');
      await _firebaseMessaging.unsubscribeFromTopic('trip_updates');

      await TelemetryService.instance.logError(
        type: 'FCM_TOPICS_UNSUBSCRIBED',
        message: 'Driver $driverId unsubscribed from FCM topics',
      );
    } catch (e, stackTrace) {
      await TelemetryService.instance.logError(
        type: 'FCM_TOPICS_UNSUBSCRIPTION_ERROR',
        message: 'Failed to unsubscribe driver $driverId from FCM topics: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Check if realtime subscription is active for driver
  bool isSubscribedToWallet(String driverId) {
    return _activeSubscriptions.containsKey(driverId);
  }

  /// Get list of active subscriptions
  List<String> getActiveSubscriptions() {
    return _activeSubscriptions.keys.toList();
  }
}
