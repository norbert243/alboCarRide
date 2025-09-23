import 'package:flutter_dotenv/flutter_dotenv.dart';

class TwilioService {
  static final String _accountSid = dotenv.get('TWILIO_ACCOUNT_SID');
  static final String _authToken = dotenv.get('TWILIO_AUTH_TOKEN');
  static final String _phoneNumber = dotenv.get('TWILIO_PHONE_NUMBER');

  static Future<bool> sendSMS({
    required String to,
    required String message,
  }) async {
    try {
      // Mock implementation for testing without verified numbers
      print('\n📱 === MOCK SMS SENT (Twilio Trial Mode) ===');
      print('📞 To: $to');
      print('💬 Message: $message');
      print('📱 ==========================================\n');

      // Extract OTP from message for easy testing
      final otpMatch = RegExp(r'\b\d{6}\b').firstMatch(message);
      if (otpMatch != null) {
        print('🎯 VERIFICATION CODE: ${otpMatch.group(0)}');
        print('📋 Copy this code to verify your phone number');
        print(
          '🔒 Note: Verify numbers at: https://console.twilio.com/us1/develop/phone-numbers/verified\n',
        );
      }

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Always return true for testing
      return true;
    } catch (e) {
      print('Error in mock SMS: $e');
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
