import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:albocarride/twilio/twilio_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Send notification to drivers about new ride request
  static Future<void> notifyDriversAboutRide({
    required String rideRequestId,
    required String pickupLocation,
    required String dropoffLocation,
    required double estimatedFare,
  }) async {
    try {
      // Get all online drivers with their FCM tokens
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, phone, fcm_token')
          .eq('is_online', true)
          .eq('role', 'driver');

      if (response.isNotEmpty) {
        final drivers = response as List<dynamic>;

        for (final driver in drivers) {
          final driverId = driver['id'];
          final driverPhone = driver['phone'];
          final fcmToken = driver['fcm_token'];

          // Send push notification via FCM
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _sendPushNotification(
              userId: driverId,
              title: '🚗 New Ride Request!',
              body: 'From: $pickupLocation\nTo: $dropoffLocation\nFare: \$${estimatedFare.toStringAsFixed(2)}',
              data: {
                'type': 'new_ride_request',
                'ride_request_id': rideRequestId,
                'pickup': pickupLocation,
                'dropoff': dropoffLocation,
                'fare': estimatedFare.toString(),
              },
            );
          }

          // Send SMS notification using Twilio
          if (driverPhone != null && driverPhone.isNotEmpty) {
            await _sendSmsNotification(
              phoneNumber: driverPhone,
              message: '🚗 New ride request: $pickupLocation to $dropoffLocation. Fare: \$${estimatedFare.toStringAsFixed(2)}. Open the app to accept!',
            );
          }
        }

        print('✅ Notified ${drivers.length} drivers about ride request $rideRequestId');
      }
    } catch (e) {
      print('❌ Error notifying drivers: $e');
    }
  }

  /// Send notification to customer about ride status
  static Future<void> notifyCustomerAboutRideStatus({
    required String customerId,
    required String rideId,
    required String status,
    String? driverName,
    String? estimatedArrival,
    double? fare,
  }) async {
    try {
      // Get customer details
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone, fcm_token')
          .eq('id', customerId)
          .single();

      final customerName = response['full_name'];
      final customerPhone = response['phone'] ?? '';

      String message;
      String title;
      String emoji;

      switch (status) {
        case 'accepted':
          emoji = '🎉';
          title = 'Driver Found!';
          message = '$driverName has accepted your ride and is on the way! ETA: ${estimatedArrival ?? "Soon"}';
          break;
        case 'arrived':
          emoji = '📍';
          title = 'Driver Arrived!';
          message = '$driverName has arrived at your pickup location. Please meet your driver.';
          break;
        case 'in_progress':
          emoji = '🚗';
          title = 'Ride Started';
          message = 'Your ride with $driverName has started. Enjoy your trip!';
          break;
        case 'completed':
          emoji = '✅';
          title = 'Ride Completed';
          message = 'Your ride is complete. Total fare: \$${fare?.toStringAsFixed(2) ?? "0.00"}. Thank you for riding with us!';
          break;
        case 'cancelled':
          emoji = '❌';
          title = 'Ride Cancelled';
          message = 'Your ride has been cancelled. Please request a new ride.';
          break;
        default:
          emoji = 'ℹ️';
          title = 'Ride Update';
          message = 'Your ride status: $status';
      }

      // Send push notification
      await _sendPushNotification(
        userId: customerId,
        title: '$emoji $title',
        body: message,
        data: {
          'type': 'ride_status_update',
          'ride_id': rideId,
          'status': status,
          'driver_name': driverName ?? '',
        },
      );

      // Send SMS notification
      if (customerPhone.isNotEmpty) {
        await _sendSmsNotification(
          phoneNumber: customerPhone,
          message: '$emoji $title: $message',
        );
      }

      print('✅ Notified customer $customerName about ride $rideId: $status');
    } catch (e) {
      print('❌ Error notifying customer: $e');
    }
  }

  /// Send notification to driver about ride assignment
  static Future<void> notifyDriverAboutRideAssignment({
    required String driverId,
    required String rideId,
    required String customerName,
    required String pickupLocation,
    required String dropoffLocation,
    required double fare,
  }) async {
    try {
      // Get driver details
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', driverId)
          .single();

      final driverPhone = response['phone'];

      final title = 'New Ride Assignment';
      final message =
          'You have been assigned a ride for $customerName from $pickupLocation to $dropoffLocation. Fare: \$${fare.toStringAsFixed(2)}';

      // Send push notification (simulated)
      await _sendPushNotification(
        userId: driverId,
        title: title,
        body: message,
      );

      // Send SMS notification
      await _sendSmsNotification(
        phoneNumber: driverPhone,
        message: '$title: $message',
      );

      print('Sent ride assignment notification to driver $driverId');
    } catch (e) {
      print('Error notifying driver about assignment: $e');
    }
  }

  /// Send push notification via Firebase Cloud Messaging
  static Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get user's FCM token from database
      final userResponse = await Supabase.instance.client
          .from('profiles')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();

      final fcmToken = userResponse?['fcm_token'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Send via Supabase Edge Function that handles FCM
        await Supabase.instance.client.functions.invoke('send-notification', body: {
          'fcm_token': fcmToken,
          'user_id': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        });
        print('✅ Push notification sent to $userId: $title');
      } else {
        print('⚠️ No FCM token for user $userId');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  /// Send SMS notification using Twilio
  static Future<void> _sendSmsNotification({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      if (phoneNumber.isEmpty) {
        print('⚠️ No phone number provided for SMS');
        return;
      }

      // Use the TwilioService for SMS notifications
      final success = await TwilioService.sendSMS(
        to: phoneNumber,
        message: message,
      );

      if (success) {
        print('✅ SMS sent to $phoneNumber');
      } else {
        print('⚠️ SMS failed to send to $phoneNumber');
      }
    } catch (e) {
      print('❌ Error sending SMS notification: $e');
    }
  }

  /// Subscribe to ride updates
  static Stream<Map<String, dynamic>> subscribeToRideUpdates(String rideId) {
    return Supabase.instance.client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .map((data) {
          if (data.isNotEmpty) {
            return data.first;
          }
          return {};
        });
  }

  /// Subscribe to driver location updates
  static Stream<Map<String, dynamic>> subscribeToDriverLocation(
    String driverId,
  ) {
    return Supabase.instance.client
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((data) {
          if (data.isNotEmpty) {
            return data.first;
          }
          return {};
        });
  }
}
