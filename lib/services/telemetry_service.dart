// lib/services/telemetry_service.dart
import 'dart:async';
import 'db_service.dart';

class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  final supabase = DBService.instance.supabase;
  final List<Map<String,dynamic>> _buffer = [];
  Timer? _flushTimer;

  Future<void> log(String type, String message, [Map<String, dynamic>? meta]) async {
    final payload = {'type': type, 'message': message, 'meta': meta ?? {}};
    _buffer.add(payload);
    if (_buffer.length >= 100) {
      await flush();
      return;
    }
    _flushTimer ??= Timer(Duration(seconds: 30), () => flush());
  }

  // Alias methods for compatibility with existing code
  Future<void> logError({
    required String type,
    required String message,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    final meta = {
      if (stackTrace != null) 'stack_trace': stackTrace,
      if (metadata != null) ...metadata,
    };
    return log('error', '$type: $message', meta);
  }

  Future<void> logPushNotification({
    required String eventType,
    required String message,
    String? status,
    String? pushId,
    Map<String, dynamic>? metadata,
  }) async {
    final meta = {
      'event_type': eventType,
      if (status != null) 'status': status,
      if (pushId != null) 'push_id': pushId,
      if (metadata != null) ...metadata,
    };
    return log('push_notification', message, meta);
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty) return;
    try {
      final batch = List<Map<String,dynamic>>.from(_buffer);
      _buffer.clear();
      await supabase.from('telemetry_logs').insert(batch.map((e) => {
        'type': e['type'],
        'message': e['message'],
        'meta': e['meta']
      }).toList());
    } catch (e) {
      // swallow, keep a tiny buffer or write fallback to local storage
    }
  }
}
