import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TwilioService {
  static final String _accountSid = dotenv.get('TWILIO_ACCOUNT_SID');
  static final String _authToken = dotenv.get('TWILIO_AUTH_TOKEN');
  static final String _phoneNumber = dotenv.get('TWILIO_PHONE_NUMBER');

  static Future<bool> sendSMS({
    required String to,
    required String message,
  }) async {
    final uri = Uri.https(
      'api.twilio.com',
      '/2010-04-01/Accounts/$_accountSid/Messages.json',
    );
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Authorization':
            'Basic ' + base64Encode(utf8.encode('$_accountSid:$_authToken')),
      },
      body: <String, String>{'From': _phoneNumber, 'To': to, 'Body': message},
    );
    if (response.statusCode == 201) {
      print('✅ SMS sent to $to');
      return true;
    } else {
      print('❌ Failed to send SMS: ${response.statusCode} ${response.body}');
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
