import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/telemetry_service.dart';

/// PushWorkerClient for server-side push processing and retry logic
/// Handles fetching pending pushes, marking them as sent/failed, and retry logic
class PushWorkerClient {
  static final PushWorkerClient instance = PushWorkerClient._internal();

  final SupabaseClient _client = Supabase.instance.client;

  PushWorkerClient._internal();

  /// Fetch pending push notifications that need to be sent
  Future<List<Map<String, dynamic>>> fetchPendingPushes({
    int limit = 50,
  }) async {
    try {
      await TelemetryService.instance.logPushNotification(
        eventType: 'fetch_pending',
        message: 'Fetching pending push notifications',
        status: 'fetching',
      );

      final response = await _client
          .from('push_notifications')
          .select()
          .eq('status', 'pending')
          .lt('retry_count', 3) // Only fetch pushes with less than 3 retries
          .order('created_at', ascending: true)
          .limit(limit);

      await TelemetryService.instance.logPushNotification(
        eventType: 'fetch_success',
        message: 'Fetched ${response.length} pending push notifications',
        status: 'success',
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to fetch pending pushes: $e',
        stackTrace: st.toString(),
        metadata: {'context': 'fetch_pending_pushes'},
      );
      rethrow;
    }
  }

  /// Mark a push notification as sent
  Future<void> markPushSent(String pushId) async {
    try {
      await TelemetryService.instance.logPushNotification(
        eventType: 'mark_sent',
        message: 'Marking push as sent',
        pushId: pushId,
        status: 'sent',
      );

      await _client
          .from('push_notifications')
          .update({
            'status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pushId);

      await TelemetryService.instance.logPushNotification(
        eventType: 'mark_sent_success',
        message: 'Successfully marked push as sent',
        pushId: pushId,
        status: 'sent',
      );
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to mark push as sent: $e',
        stackTrace: st.toString(),
        metadata: {'context': 'mark_push_sent', 'push_id': pushId},
      );
      rethrow;
    }
  }

  /// Mark a push notification as failed and increment retry count
  Future<void> markPushFailed(String pushId, String error) async {
    try {
      await TelemetryService.instance.logPushNotification(
        eventType: 'mark_failed',
        message: 'Marking push as failed: $error',
        pushId: pushId,
        status: 'failed',
      );

      // First get current retry count
      final currentPush = await _client
          .from('push_notifications')
          .select('retry_count')
          .eq('id', pushId)
          .single();

      final currentRetryCount = currentPush['retry_count'] as int? ?? 0;
      final newRetryCount = currentRetryCount + 1;

      await _client
          .from('push_notifications')
          .update({
            'status': newRetryCount >= 3 ? 'failed_permanently' : 'failed',
            'retry_count': newRetryCount,
            'last_error': error,
            'last_retry_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pushId);

      await TelemetryService.instance.logPushNotification(
        eventType: 'mark_failed_success',
        message: 'Successfully marked push as failed (retry $newRetryCount)',
        pushId: pushId,
        status: newRetryCount >= 3 ? 'failed_permanently' : 'failed',
      );
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to mark push as failed: $e',
        stackTrace: st.toString(),
        metadata: {
          'context': 'mark_push_failed',
          'push_id': pushId,
          'original_error': error,
        },
      );
      rethrow;
    }
  }

  /// Process a batch of pending push notifications
  Future<void> processPendingPushes({int batchSize = 10}) async {
    try {
      await TelemetryService.instance.logPushNotification(
        eventType: 'batch_process_start',
        message: 'Starting batch processing of pending pushes',
        status: 'processing',
      );

      final pendingPushes = await fetchPendingPushes(limit: batchSize);

      if (pendingPushes.isEmpty) {
        await TelemetryService.instance.logPushNotification(
          eventType: 'batch_process_empty',
          message: 'No pending pushes to process',
          status: 'completed',
        );
        return;
      }

      int successCount = 0;
      int failureCount = 0;

      for (final push in pendingPushes) {
        try {
          final pushId = push['id'] as String;
          final deviceToken = push['device_token'] as String?;
          final title = push['title'] as String?;
          final body = push['body'] as String?;

          if (deviceToken == null) {
            await markPushFailed(pushId, 'Missing device token');
            failureCount++;
            continue;
          }

          // In a real implementation, you would send the push via FCM here
          // For now, we'll simulate successful sending
          await _simulatePushSending(pushId, deviceToken, title, body);

          await markPushSent(pushId);
          successCount++;
        } catch (e) {
          await markPushFailed(push['id'] as String, e.toString());
          failureCount++;
        }
      }

      await TelemetryService.instance.logPushNotification(
        eventType: 'batch_process_complete',
        message:
            'Batch processing completed: $successCount success, $failureCount failures',
        status: 'completed',
      );
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to process pending pushes: $e',
        stackTrace: st.toString(),
        metadata: {'context': 'process_pending_pushes'},
      );
      rethrow;
    }
  }

  /// Get push notification statistics
  Future<Map<String, dynamic>> getPushStatistics() async {
    try {
      final response = await _client.rpc('get_push_statistics');

      await TelemetryService.instance.logPushNotification(
        eventType: 'statistics_fetched',
        message: 'Fetched push notification statistics',
        status: 'success',
      );

      return Map<String, dynamic>.from(response);
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to fetch push statistics: $e',
        stackTrace: st.toString(),
        metadata: {'context': 'get_push_statistics'},
      );

      // Return default statistics if RPC fails
      return {
        'total_pushes': 0,
        'sent_count': 0,
        'failed_count': 0,
        'pending_count': 0,
        'success_rate': 0.0,
      };
    }
  }

  /// Clean up old push notifications (older than 30 days)
  Future<void> cleanupOldPushes() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

      await TelemetryService.instance.logPushNotification(
        eventType: 'cleanup_start',
        message: 'Starting cleanup of old push notifications',
        status: 'cleaning',
      );

      final result = await _client
          .from('push_notifications')
          .delete()
          .lt('created_at', cutoffDate.toIso8601String());

      await TelemetryService.instance.logPushNotification(
        eventType: 'cleanup_complete',
        message: 'Cleanup completed: ${result.length} records deleted',
        status: 'completed',
      );
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to cleanup old pushes: $e',
        stackTrace: st.toString(),
        metadata: {'context': 'cleanup_old_pushes'},
      );
      rethrow;
    }
  }

  /// Simulate push sending (for development/testing)
  Future<void> _simulatePushSending(
    String pushId,
    String deviceToken,
    String? title,
    String? body,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Simulate random failures (10% failure rate for testing)
    if (DateTime.now().millisecond % 10 == 0) {
      throw Exception('Simulated FCM send failure');
    }

    // Log successful simulation
    await TelemetryService.instance.logPushNotification(
      eventType: 'simulated_send',
      message: 'Simulated push sent successfully',
      pushId: pushId,
      status: 'sent',
      metadata: {'title': title},
    );
  }

  /// Initialize the push worker client
  Future<void> initialize() async {
    try {
      await TelemetryService.instance.logPushNotification(
        eventType: 'worker_initialized',
        message: 'PushWorkerClient initialized successfully',
        status: 'initialized',
      );
    } catch (e, st) {
      await TelemetryService.instance.logError(
        type: 'push_worker_client',
        message: 'Failed to initialize PushWorkerClient: $e',
        stackTrace: st.toString(),
        metadata: {'context': 'initialization'},
      );
      rethrow;
    }
  }
}
