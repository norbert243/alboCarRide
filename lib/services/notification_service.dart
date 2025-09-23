import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing real-time notifications
class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Send a notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending notification: $e');
      throw Exception('Failed to send notification: $e');
    }
  }

  /// Send trip-related notifications
  Future<void> sendTripNotification({
    required String userId,
    required String tripId,
    required String eventType,
    String? additionalInfo,
  }) async {
    String title;
    String message;

    switch (eventType) {
      case 'trip_accepted':
        title = 'Trip Accepted';
        message = 'Your trip request has been accepted by a driver.';
        break;
      case 'trip_started':
        title = 'Trip Started';
        message = 'Your driver has started the trip.';
        break;
      case 'trip_completed':
        title = 'Trip Completed';
        message = 'Your trip has been completed successfully.';
        break;
      case 'trip_cancelled':
        title = 'Trip Cancelled';
        message = 'Your trip has been cancelled.';
        break;
      case 'offer_received':
        title = 'New Ride Offer';
        message = 'You have received a new ride offer.';
        break;
      case 'offer_accepted':
        title = 'Offer Accepted';
        message = 'Your ride offer has been accepted.';
        break;
      case 'offer_rejected':
        title = 'Offer Rejected';
        message = 'Your ride offer has been rejected.';
        break;
      default:
        title = 'Trip Update';
        message = 'There has been an update to your trip.';
    }

    if (additionalInfo != null) {
      message += ' $additionalInfo';
    }

    await sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'ride_update',
    );
  }

  /// Get unread notifications for a user
  Future<List<Map<String, dynamic>>> getUnreadNotifications(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('Error getting unread notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Get all notifications for a user
  Future<List<Map<String, dynamic>>> getAllNotifications(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response;
    } catch (e) {
      print('Error getting notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Subscribe to real-time notifications for a user
  Stream<List<Map<String, dynamic>>> subscribeToNotifications(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((events) => events);
  }

  /// Get notification statistics
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('is_read, type')
          .eq('user_id', userId);

      final stats = {
        'total': response.length,
        'unread': 0,
        'read': 0,
        'ride_updates': 0,
        'payments': 0,
        'promotions': 0,
        'system': 0,
      };

      for (final notification in response) {
        if (notification['is_read'] == true) {
          stats['read'] = (stats['read'] ?? 0) + 1;
        } else {
          stats['unread'] = (stats['unread'] ?? 0) + 1;
        }

        final type = notification['type'] as String? ?? 'system';
        switch (type) {
          case 'ride_update':
            stats['ride_updates'] = (stats['ride_updates'] ?? 0) + 1;
            break;
          case 'payment':
            stats['payments'] = (stats['payments'] ?? 0) + 1;
            break;
          case 'promotion':
            stats['promotions'] = (stats['promotions'] ?? 0) + 1;
            break;
          case 'system':
            stats['system'] = (stats['system'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting notification stats: $e');
      throw Exception('Failed to get notification stats: $e');
    }
  }

  /// Clean up old notifications (older than 30 days)
  Future<int> cleanupOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final response = await _client
          .from('notifications')
          .delete()
          .lt('created_at', thirtyDaysAgo.toIso8601String())
          .select();

      return response.length;
    } catch (e) {
      print('Error cleaning up old notifications: $e');
      throw Exception('Failed to cleanup old notifications: $e');
    }
  }

  /// Send batch notifications to multiple users
  Future<void> sendBatchNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final notifications = userIds
          .map(
            (userId) => {
              'user_id': userId,
              'title': title,
              'message': message,
              'type': type,
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _client.from('notifications').insert(notifications);
    } catch (e) {
      print('Error sending batch notifications: $e');
      throw Exception('Failed to send batch notifications: $e');
    }
  }
}
