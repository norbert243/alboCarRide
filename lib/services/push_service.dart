// lib/services/push_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'db_service.dart';
import 'telemetry_service.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final supabase = DBService.instance.supabase;

  Future<void> init(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await supabase.from('profiles').update({'fcm_token': token}).eq('id', userId);
        
        await TelemetryService.instance.logError(
          type: 'DEVICE_TOKEN_SAVED',
          message: 'Device token saved for user $userId',
        );
      }
      
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        TelemetryService.instance.log(
          'fcm_message', 
          'foreground message received', 
          {'msg': msg.data}
        );
      });
      
      await TelemetryService.instance.logError(
        type: 'PUSH_SERVICE_INIT',
        message: 'PushService initialized successfully',
      );
    } catch (e, stackTrace) {
      await TelemetryService.instance.logError(
        type: 'PUSH_SERVICE_INIT_ERROR',
        message: 'Failed to initialize PushService: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }
}
