import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

      if (_phoneNumber.isEmpty && _messagingServiceSid.isEmpty) {
        print('❌ No Twilio phone number or messaging service configured');
        return false;
      }

      final uri = Uri.https(
        'api.twilio.com',
        '/2010-04-01/Accounts/$_accountSid/Messages.json',
      );

      // Always use From phone number directly - more reliable than Messaging Service
      // Messaging Service requires additional setup and can silently fail
      final Map<String, String> body = {
        'From': _phoneNumber,
        'To': to,
        'Body': message,
      };

      print('📤 Sending SMS from $_phoneNumber to $to');

      final response = await http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      print('📥 Twilio Response Status: ${response.statusCode}');
      print('📥 Twilio Response Body: ${response.body}');

      if (response.statusCode == 201) {
        // Parse response to verify message was actually queued
        final responseData = jsonDecode(response.body);
        final status = responseData['status'] as String?;
        final errorCode = responseData['error_code'];
        final errorMessage = responseData['error_message'];

        if (errorCode != null) {
          print('❌ Twilio error: $errorCode - $errorMessage');
          return false;
        }

        // Valid statuses: queued, sending, sent, delivered
        if (status == 'queued' || status == 'sending' || status == 'sent' || status == 'delivered') {
          print('✅ SMS successfully queued with status: $status (SID: ${responseData['sid']})');
          return true;
        } else if (status == 'failed' || status == 'undelivered') {
          print('❌ SMS failed with status: $status');
          return false;
        }

        print('✅ SMS sent to $to (status: $status)');
        return true;
      } else {
        // Parse error response for more details
        try {
          final errorData = jsonDecode(response.body);
          final errorCode = errorData['code'];
          final errorMessage = errorData['message'];
          print('❌ Twilio API Error $errorCode: $errorMessage');

          // Common error codes:
          // 21608 - The 'From' phone number is not a valid, SMS-capable Twilio number
          // 21211 - Invalid 'To' phone number
          // 21614 - 'To' number is not a valid mobile number
          // 21610 - Message cannot be sent to the 'To' number (blocked/unsubscribed)
          if (errorCode == 21608) {
            print('💡 Hint: Your Twilio phone number may not be SMS-capable or verified');
          } else if (errorCode == 21211 || errorCode == 21614) {
            print('💡 Hint: The destination phone number format may be invalid');
          } else if (errorCode == 21610) {
            print('💡 Hint: The destination number may have unsubscribed from SMS');
          }
        } catch (_) {
          print('❌ Failed to send SMS: ${response.statusCode} ${response.body}');
        }
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
        'Your AlboCar verification code is: $otp. This code will expire in 5 minutes.';

    return await sendSMS(to: phoneNumber, message: message);
  }

  static String generateOTP() {
    // Generate a secure 6-digit OTP using Random.secure()
    final random = Random.secure();
    final otp = (100000 + random.nextInt(900000)).toString();
    return otp;
  }
}
