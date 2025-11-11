import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

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

  /// Get payment history for a customer
  static Future<List<Map<String, dynamic>>> getPaymentHistory(
    String customerId,
  ) async {
    try {
      final response = await _supabase
          .from('payments')
          .select('''
            *,
            trip:trips(
              request_id,
              status
            ),
            request:trips!inner(
              ride_request:ride_requests(
                pickup_address,
                dropoff_address
              )
            )
          ''')
          .eq('rider_id', customerId)
          .order('created_at', ascending: false);

      if (response != null) {
        final List<Map<String, dynamic>> payments = [];

        for (final payment in response) {
          final trip = payment['trip'] as Map<String, dynamic>?;
          final request = payment['request'] as Map<String, dynamic>?;
          final rideRequest = request?['ride_request'] as Map<String, dynamic>?;

          String description = 'Payment';
          if (rideRequest != null) {
            final pickup = rideRequest['pickup_address'] ?? 'Unknown pickup';
            final dropoff = rideRequest['dropoff_address'] ?? 'Unknown dropoff';
            description = 'Ride from $pickup to $dropoff';
          }

          payments.add({
            'id': payment['id'],
            'amount': payment['amount'] ?? 0.0,
            'description': description,
            'date': _formatPaymentDate(payment['created_at']),
            'status': payment['status'] ?? 'completed',
            'payment_method': _formatPaymentMethod(payment['payment_method']),
            'transaction_id': payment['transaction_id'],
            'processed_at': payment['processed_at'],
          });
        }

        return payments;
      }
    } catch (e) {
      print('Error getting payment history: $e');
    }

    return [];
  }

  /// Format payment date for display
  static String _formatPaymentDate(String? dateString) {
    if (dateString == null) return 'Unknown date';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Format payment method for display
  static String _formatPaymentMethod(String? method) {
    switch (method) {
      case 'card':
        return 'Credit Card';
      case 'cash':
        return 'Cash';
      case 'mobile_money':
        return 'Mobile Money';
      default:
        return 'Unknown';
    }
  }
}
