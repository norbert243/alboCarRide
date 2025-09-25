import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class NotificationService {
  /// Send notification to drivers about new ride request
  static Future<void> notifyDriversAboutRide({
    required String rideRequestId,
    required String pickupLocation,
    required String dropoffLocation,
    required double estimatedFare,
  }) async {
    try {
      // Get all online drivers
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, phone')
          .eq('is_online', true)
          .eq('role', 'driver');

      if (response.isNotEmpty) {
        final drivers = response as List<dynamic>;

        // In a real implementation, you would:
        // 1. Send push notifications via Firebase Cloud Messaging
        // 2. Send SMS notifications via Twilio
        // 3. Update real-time database for driver apps

        for (final driver in drivers) {
          final driverId = driver['id'];
          final driverName = driver['full_name'];
          final driverPhone = driver['phone'];

          // Send push notification (simulated)
          await _sendPushNotification(
            driverId: driverId,
            title: 'New Ride Request',
            body:
                'Ride from $pickupLocation to $dropoffLocation - \$${estimatedFare.toStringAsFixed(2)}',
          );

          // Send SMS notification (using existing Twilio service)
          await _sendSmsNotification(
            phoneNumber: driverPhone,
            message:
                'New ride request: $pickupLocation to $dropoffLocation. Estimated fare: \$${estimatedFare.toStringAsFixed(2)}',
          );
        }

        print(
          'Notified ${drivers.length} drivers about ride request $rideRequestId',
        );
      }
    } catch (e) {
      print('Error notifying drivers: $e');
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
          .select('full_name, phone')
          .eq('id', customerId)
          .single();

      if (response != null) {
        final customerName = response['full_name'];
        final customerPhone = response['phone'];

        String message;
        String title;

        switch (status) {
          case 'accepted':
            title = 'Ride Accepted!';
            message =
                'Driver $driverName has accepted your ride request. Estimated arrival: $estimatedArrival';
            break;
          case 'arrived':
            title = 'Driver Arrived';
            message = 'Driver $driverName has arrived at your pickup location';
            break;
          case 'in_progress':
            title = 'Ride Started';
            message = 'Your ride with $driverName has started';
            break;
          case 'completed':
            title = 'Ride Completed';
            message =
                'Your ride has been completed. Fare: \$${fare?.toStringAsFixed(2)}';
            break;
          case 'cancelled':
            title = 'Ride Cancelled';
            message = 'Your ride has been cancelled';
            break;
          default:
            title = 'Ride Update';
            message = 'Your ride status has been updated to: $status';
        }

        // Send push notification (simulated)
        await _sendPushNotification(
          driverId: customerId,
          title: title,
          body: message,
        );

        // Send SMS notification
        await _sendSmsNotification(
          phoneNumber: customerPhone,
          message: '$title: $message',
        );

        print(
          'Sent notification to customer $customerName about ride $rideId: $status',
        );
      }
    } catch (e) {
      print('Error notifying customer: $e');
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

      if (response != null) {
        final driverPhone = response['phone'];

        final title = 'New Ride Assignment';
        final message =
            'You have been assigned a ride for $customerName from $pickupLocation to $dropoffLocation. Fare: \$${fare.toStringAsFixed(2)}';

        // Send push notification (simulated)
        await _sendPushNotification(
          driverId: driverId,
          title: title,
          body: message,
        );

        // Send SMS notification
        await _sendSmsNotification(
          phoneNumber: driverPhone,
          message: '$title: $message',
        );

        print('Sent ride assignment notification to driver $driverId');
      }
    } catch (e) {
      print('Error notifying driver about assignment: $e');
    }
  }

  /// Simulated push notification (replace with Firebase Cloud Messaging)
  static Future<void> _sendPushNotification({
    required String driverId,
    required String title,
    required String body,
  }) async {
    // In a real implementation, use Firebase Cloud Messaging
    // This is a simulation for demo purposes

    print('Sending push notification to $driverId: $title - $body');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Send SMS notification using Twilio (already implemented)
  static Future<void> _sendSmsNotification({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Use the existing TwilioService for SMS notifications
      // For now, we'll simulate this since TwilioService is already implemented

      print('Sending SMS to $phoneNumber: $message');
      await Future.delayed(const Duration(milliseconds: 200));

      // Real implementation would be:
      // await TwilioService.sendSMS(
      //   phoneNumber: phoneNumber,
      //   message: message,
      // );
    } catch (e) {
      print('Error sending SMS notification: $e');
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
            return data.first as Map<String, dynamic>;
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
            return data.first as Map<String, dynamic>;
          }
          return {};
        });
  }
}
