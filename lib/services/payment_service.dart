import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PaymentService {
  /// Create a payment intent for a ride
  static Future<Map<String, dynamic>?> createPaymentIntent({
    required double amount,
    required String currency,
    required String customerId,
    String? description,
  }) async {
    try {
      // In a real implementation, this should be done on your server
      // for security reasons (never expose secret keys in client-side code)

      // For demo purposes, we'll simulate a payment intent creation
      // In production, make a request to your backend server

      final simulatedResponse = {
        'id': 'pi_${DateTime.now().millisecondsSinceEpoch}',
        'client_secret': 'pi_${DateTime.now().millisecondsSinceEpoch}_secret',
        'amount': (amount * 100).toInt(), // Convert to cents
        'currency': currency,
        'status': 'requires_payment_method',
      };

      return simulatedResponse;

      // Real implementation (server-side only):
      /*
      final response = await http.post(
        Uri.parse('${ApiConfig.stripeBaseUrl}/payment_intents'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.stripeSecretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).toInt().toString(),
          'currency': currency,
          'customer': customerId,
          if (description != null) 'description': description,
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      */
    } catch (e) {
      print('Error creating payment intent: $e');
    }

    return null;
  }

  /// Confirm a payment
  static Future<bool> confirmPayment(String paymentIntentId) async {
    try {
      // In a real implementation, this should be done on your server
      // For demo purposes, we'll simulate a successful payment

      await Future.delayed(const Duration(seconds: 2)); // Simulate processing

      // Simulate 90% success rate for demo
      final randomSuccess = DateTime.now().millisecond % 10 < 9;

      return randomSuccess;

      // Real implementation (server-side only):
      /*
      final response = await http.post(
        Uri.parse('${ApiConfig.stripeBaseUrl}/payment_intents/$paymentIntentId/confirm'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.stripeSecretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'succeeded';
      }
      */
    } catch (e) {
      print('Error confirming payment: $e');
    }

    return false;
  }

  /// Create a customer in Stripe
  static Future<String?> createCustomer({
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      // In a real implementation, this should be done on your server
      // For demo purposes, we'll simulate customer creation

      final customerId = 'cus_${DateTime.now().millisecondsSinceEpoch}';
      return customerId;

      // Real implementation (server-side only):
      /*
      final response = await http.post(
        Uri.parse('${ApiConfig.stripeBaseUrl}/customers'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.stripeSecretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': email,
          'name': name,
          if (phone != null) 'phone': phone,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      }
      */
    } catch (e) {
      print('Error creating customer: $e');
    }

    return null;
  }

  /// Save payment method for future use
  static Future<bool> savePaymentMethod({
    required String customerId,
    required String paymentMethodId,
  }) async {
    try {
      // In a real implementation, this should be done on your server
      // For demo purposes, we'll simulate saving payment method

      await Future.delayed(const Duration(seconds: 1));
      return true;

      // Real implementation (server-side only):
      /*
      final response = await http.post(
        Uri.parse('${ApiConfig.stripeBaseUrl}/payment_methods/$paymentMethodId/attach'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.stripeSecretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
        },
      );
      
      return response.statusCode == 200;
      */
    } catch (e) {
      print('Error saving payment method: $e');
    }

    return false;
  }

  /// Get saved payment methods for a customer
  static Future<List<Map<String, dynamic>>> getSavedPaymentMethods(
    String customerId,
  ) async {
    try {
      // In a real implementation, this should be done on your server
      // For demo purposes, we'll return sample payment methods

      return [
        {
          'id': 'pm_1',
          'type': 'card',
          'card': {
            'brand': 'visa',
            'last4': '4242',
            'exp_month': 12,
            'exp_year': 2025,
          },
          'isDefault': true,
        },
        {
          'id': 'pm_2',
          'type': 'card',
          'card': {
            'brand': 'mastercard',
            'last4': '8888',
            'exp_month': 6,
            'exp_year': 2024,
          },
          'isDefault': false,
        },
      ];

      // Real implementation (server-side only):
      /*
      final response = await http.get(
        Uri.parse('${ApiConfig.stripeBaseUrl}/payment_methods?customer=$customerId&type=card'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.stripeSecretKey}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List).cast<Map<String, dynamic>>();
      }
      */
    } catch (e) {
      print('Error getting payment methods: $e');
    }

    return [];
  }
}
