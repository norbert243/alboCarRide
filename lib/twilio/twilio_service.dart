import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TwilioService {
  static String get _accountSid => dotenv.get('TWILIO_ACCOUNT_SID', fallback: '');
  static String get _authToken => dotenv.get('TWILIO_AUTH_TOKEN', fallback: '');
  static String get _phoneNumber => dotenv.get('TWILIO_PHONE_NUMBER', fallback: '');
  static String get _messagingServiceSid => dotenv.get('TWILIO_MESSAGE_SERVICE_SID', fallback: '');

  static Future<bool> sendSMS({
    required String to,
    required String message,
  }) async {
    try {
      // Debug: Print credentials (masked)
      print('🔑 Twilio Account SID: ${_accountSid.isNotEmpty ? "${_accountSid.substring(0, 6)}..." : "EMPTY"}');
      print('🔑 Twilio Auth Token: ${_authToken.isNotEmpty ? "${_authToken.substring(0, 4)}..." : "EMPTY"}');
      print('📱 Twilio Phone: $_phoneNumber');
      print('📨 Messaging Service SID: ${_messagingServiceSid.isNotEmpty ? "${_messagingServiceSid.substring(0, 6)}..." : "EMPTY"}');

      if (_accountSid.isEmpty || _authToken.isEmpty) {
        print('❌ Twilio credentials not configured');
        return false;
      }

      final uri = Uri.https(
        'api.twilio.com',
        '/2010-04-01/Accounts/$_accountSid/Messages.json',
      );

      // Use messaging service SID if available, otherwise use phone number
      final Map<String, String> body = _messagingServiceSid.isNotEmpty
          ? {'MessagingServiceSid': _messagingServiceSid, 'To': to, 'Body': message}
          : {'From': _phoneNumber, 'To': to, 'Body': message};

      final response = await http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        print('✅ SMS sent to $to');
        return true;
      } else {
        print('❌ Failed to send SMS: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception sending SMS: $e');
      return false;
    }
  }

  static Future<bool> sendOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    final message =
        'Your AlboCar verification code is: $otp. This code will expire in 10 minutes.';

    return await sendSMS(to: phoneNumber, message: message);
  }

  static String generateOTP() {
    // Generate a 6-digit OTP
    final random = DateTime.now().millisecondsSinceEpoch;
    final otp = (random % 900000 + 100000).toString();
    return otp;
  }
}
