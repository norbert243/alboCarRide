# PayFast Implementation Guide for AlboCarRide

This guide provides step-by-step instructions for integrating PayFast payment processing into your Flutter ride-sharing app.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [PayFast Account Setup](#payfast-account-setup)
3. [Backend Setup](#backend-setup)
4. [Flutter Integration](#flutter-integration)
5. [Testing](#testing)
6. [Production Deployment](#production-deployment)

---

## Prerequisites

### Required Accounts
- ✅ PayFast merchant account
- ✅ South African bank account (for settlements)
- ✅ Valid South African ID or company registration
- ✅ Backend server (Node.js, Python, or similar)

### Development Tools
- Flutter SDK installed
- Postman or similar API testing tool
- Code editor (VS Code recommended)

---

## PayFast Account Setup

### Step 1: Register for PayFast

1. Visit https://www.payfast.co.za/
2. Click "Sign Up" → "Create an Account"
3. Choose account type:
   - **Individual**: For sole proprietors
   - **Business**: For registered companies
4. Complete registration form with:
   - Business/personal details
   - Bank account information
   - Tax information (VAT number if applicable)
5. Verify email address

### Step 2: Get API Credentials

1. Log in to PayFast Dashboard
2. Navigate to **Settings** → **Integration**
3. Note your credentials:
   ```
   Merchant ID: 10000100
   Merchant Key: 46f0cd694581a
   Passphrase: (set this yourself for security)
   ```
4. Set a **Passphrase** (required for signature generation)

### Step 3: Configure Settings

1. **Payment Notifications (IPN)**:
   - URL: `https://yourdomain.com/api/webhook/payfast`
   - Enable IPN

2. **Security**:
   - Enable 3D Secure
   - Set transaction limits (optional)

3. **Payment Methods**:
   - Enable: Cards, EFT, SnapScan, etc.

---

## Backend Setup

### Option 1: Node.js/Express

#### Install Dependencies

```bash
npm install express body-parser crypto md5
```

#### Create Payment Endpoint

```javascript
// backend/routes/payfast.js
const express = require('express');
const crypto = require('crypto');
const md5 = require('md5');
const router = express.Router();

// PayFast credentials (from environment variables)
const PAYFAST_MERCHANT_ID = process.env.PAYFAST_MERCHANT_ID;
const PAYFAST_MERCHANT_KEY = process.env.PAYFAST_MERCHANT_KEY;
const PAYFAST_PASSPHRASE = process.env.PAYFAST_PASSPHRASE;

// Sandbox or Production
const PAYFAST_URL = process.env.NODE_ENV === 'production'
  ? 'https://www.payfast.co.za/eng/process'
  : 'https://sandbox.payfast.co.za/eng/process';

// Generate PayFast signature
function generateSignature(data, passPhrase = null) {
  // Create parameter string
  let pfOutput = '';
  for (let key in data) {
    if (data.hasOwnProperty(key)) {
      if (data[key] !== '') {
        pfOutput += `${key}=${encodeURIComponent(data[key].toString().trim()).replace(/%20/g, '+')}&`;
      }
    }
  }

  // Remove last ampersand
  let getString = pfOutput.slice(0, -1);

  // Add passphrase if provided
  if (passPhrase !== null) {
    getString += `&passphrase=${encodeURIComponent(passPhrase.trim()).replace(/%20/g, '+')}`;
  }

  return md5(getString);
}

// Create payment intent
router.post('/create-payment', async (req, res) => {
  try {
    const { tripId, customerId, amount, customerEmail, customerName } = req.body;

    // Validate amount
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    // Generate unique merchant reference
    const merchantReference = `TRIP_${tripId}_${Date.now()}`;

    // Prepare payment data
    const paymentData = {
      merchant_id: PAYFAST_MERCHANT_ID,
      merchant_key: PAYFAST_MERCHANT_KEY,
      return_url: `${process.env.APP_URL}/payment/success`,
      cancel_url: `${process.env.APP_URL}/payment/cancel`,
      notify_url: `${process.env.API_URL}/api/webhook/payfast`,
      name_first: customerName.split(' ')[0] || 'Customer',
      name_last: customerName.split(' ').slice(1).join(' ') || 'Name',
      email_address: customerEmail,
      m_payment_id: merchantReference,
      amount: parseFloat(amount).toFixed(2),
      item_name: `AlboCarRide - Trip #${tripId}`,
      item_description: `Payment for ride booking`,
      custom_str1: customerId,
      custom_str2: tripId,
      custom_int1: Date.now(),
    };

    // Generate signature
    const signature = generateSignature(paymentData, PAYFAST_PASSPHRASE);
    paymentData.signature = signature;

    // Store payment reference in database
    await storePaymentIntent(tripId, merchantReference, amount);

    // Return payment data to Flutter app
    res.json({
      success: true,
      paymentUrl: PAYFAST_URL,
      paymentData,
      merchantReference,
    });

  } catch (error) {
    console.error('Payment creation error:', error);
    res.status(500).json({ error: 'Failed to create payment' });
  }
});

// Webhook to receive PayFast IPN (Instant Payment Notification)
router.post('/webhook/payfast', async (req, res) => {
  try {
    console.log('PayFast IPN received:', req.body);

    const pfData = req.body;

    // Step 1: Verify signature
    const pfParamString = Object.keys(pfData)
      .filter(key => key !== 'signature')
      .sort()
      .map(key => `${key}=${encodeURIComponent(pfData[key]).replace(/%20/g, '+')}`)
      .join('&');

    const passphrase = PAYFAST_PASSPHRASE;
    const pfParamStringWithPassphrase = `${pfParamString}&passphrase=${encodeURIComponent(passphrase)}`;
    const calculatedSignature = md5(pfParamStringWithPassphrase);

    if (calculatedSignature !== pfData.signature) {
      console.error('Invalid signature');
      return res.status(403).send('Invalid signature');
    }

    // Step 2: Verify payment status
    const paymentStatus = pfData.payment_status;
    const tripId = pfData.custom_str2;
    const merchantReference = pfData.m_payment_id;
    const amount = parseFloat(pfData.amount_gross);

    // Step 3: Update database based on payment status
    if (paymentStatus === 'COMPLETE') {
      // Payment successful
      await updateTripPaymentStatus(tripId, {
        status: 'paid',
        paymentReference: merchantReference,
        amount: amount,
        paidAt: new Date(),
      });

      // TODO: Trigger driver payout process
      // TODO: Send confirmation notifications

      console.log(`Payment successful for trip ${tripId}`);
    } else {
      // Payment failed or cancelled
      await updateTripPaymentStatus(tripId, {
        status: 'payment_failed',
        paymentReference: merchantReference,
      });

      console.log(`Payment failed for trip ${tripId}: ${paymentStatus}`);
    }

    // Acknowledge receipt
    res.status(200).send('OK');

  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).send('Error processing webhook');
  }
});

// Verify payment status (called by Flutter app)
router.get('/verify-payment/:merchantReference', async (req, res) => {
  try {
    const { merchantReference } = req.params;

    // Query database for payment status
    const payment = await getPaymentByReference(merchantReference);

    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    res.json({
      success: true,
      status: payment.status,
      amount: payment.amount,
      paidAt: payment.paidAt,
    });

  } catch (error) {
    console.error('Payment verification error:', error);
    res.status(500).json({ error: 'Failed to verify payment' });
  }
});

// Helper functions (implement based on your database)
async function storePaymentIntent(tripId, merchantReference, amount) {
  // Store in your database
  // Example with Supabase:
  // await supabase.from('payments').insert({
  //   trip_id: tripId,
  //   merchant_reference: merchantReference,
  //   amount: amount,
  //   status: 'pending',
  //   created_at: new Date(),
  // });
}

async function updateTripPaymentStatus(tripId, paymentData) {
  // Update trip payment status in database
  // Example with Supabase:
  // await supabase.from('trips').update({
  //   payment_status: paymentData.status,
  //   payment_reference: paymentData.paymentReference,
  //   updated_at: new Date(),
  // }).eq('id', tripId);
}

async function getPaymentByReference(merchantReference) {
  // Query payment from database
  // return await supabase.from('payments')
  //   .select('*')
  //   .eq('merchant_reference', merchantReference)
  //   .single();
}

module.exports = router;
```

#### Environment Variables

Create `.env` file:

```env
# PayFast Credentials (Sandbox)
PAYFAST_MERCHANT_ID=10000100
PAYFAST_MERCHANT_KEY=46f0cd694581a
PAYFAST_PASSPHRASE=your_secure_passphrase

# URLs
API_URL=https://your-backend.com
APP_URL=albocarride://payment

# Environment
NODE_ENV=development
```

---

## Flutter Integration

### Step 1: Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  url_launcher: ^6.1.10
  webview_flutter: ^4.0.0
  http: ^1.2.2
```

Run:
```bash
flutter pub get
```

### Step 2: Create PayFast Service

```dart
// lib/services/payfast_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PayFastService {
  final String baseUrl = 'https://your-backend.com/api';

  /// Create payment and launch PayFast checkout
  Future<bool> processPayment({
    required String tripId,
    required String customerId,
    required double amount,
    required String customerEmail,
    required String customerName,
  }) async {
    try {
      // Step 1: Create payment intent on backend
      final response = await http.post(
        Uri.parse('$baseUrl/payfast/create-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'tripId': tripId,
          'customerId': customerId,
          'amount': amount,
          'customerEmail': customerEmail,
          'customerName': customerName,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment');
      }

      final data = json.decode(response.body);
      final paymentUrl = data['paymentUrl'];
      final paymentData = data['paymentData'];
      final merchantReference = data['merchantReference'];

      // Step 2: Build PayFast checkout URL with parameters
      final Uri payfastUri = Uri.parse(paymentUrl).replace(
        queryParameters: paymentData.map<String, String>(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );

      // Step 3: Launch PayFast in browser or webview
      if (await canLaunchUrl(payfastUri)) {
        await launchUrl(
          payfastUri,
          mode: LaunchMode.externalApplication,
        );

        // Return merchant reference for verification
        return await _waitForPaymentConfirmation(merchantReference);
      } else {
        throw Exception('Could not launch PayFast');
      }
    } catch (e) {
      print('PayFast payment error: $e');
      return false;
    }
  }

  /// Poll backend to check payment status
  Future<bool> _waitForPaymentConfirmation(String merchantReference) async {
    // Wait for user to complete payment and return to app
    // In a real implementation, you would:
    // 1. Use deep linking to return to app
    // 2. Poll backend for payment status
    // 3. Show loading indicator to user

    await Future.delayed(const Duration(seconds: 2));

    // Check payment status
    return await verifyPaymentStatus(merchantReference);
  }

  /// Verify payment status with backend
  Future<bool> verifyPaymentStatus(String merchantReference) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payfast/verify-payment/$merchantReference'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'paid';
      }

      return false;
    } catch (e) {
      print('Payment verification error: $e');
      return false;
    }
  }
}
```

### Step 3: Create Payment UI

```dart
// lib/screens/payment/payment_page.dart
import 'package:flutter/material.dart';
import '../../services/payfast_service.dart';
import '../../services/session_service.dart';
import '../../widgets/custom_toast.dart';

class PaymentPage extends StatefulWidget {
  final String tripId;
  final double amount;

  const PaymentPage({
    super.key,
    required this.tripId,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final PayFastService _paymentService = PayFastService();
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Get customer details
      final customerId = await SessionService.getUserIdStatic();
      final profile = await SessionService.getProfile();

      if (customerId == null || profile == null) {
        throw Exception('User not authenticated');
      }

      final customerName = profile['full_name'] ?? 'Customer';
      final customerEmail = profile['email'] ?? 'customer@example.com';

      // Process payment
      final success = await _paymentService.processPayment(
        tripId: widget.tripId,
        customerId: customerId,
        amount: widget.amount,
        customerEmail: customerEmail,
        customerName: customerName,
      );

      if (success && mounted) {
        CustomToast.showSuccess(
          context: context,
          message: 'Payment successful!',
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'Payment failed. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(
          context: context,
          message: 'Payment error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Complete Payment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Total',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'R ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentMethodOption(
              icon: Icons.credit_card,
              title: 'Card Payment',
              subtitle: 'Visa, Mastercard',
            ),
            _buildPaymentMethodOption(
              icon: Icons.account_balance,
              title: 'Instant EFT',
              subtitle: 'Bank transfer',
            ),
            _buildPaymentMethodOption(
              icon: Icons.qr_code,
              title: 'SnapScan / Zapper',
              subtitle: 'QR code payment',
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
```

### Step 4: Integrate with Trip Completion

```dart
// In trip_card_widget.dart or wherever trip is completed
Future<void> _completeTrip() async {
  setState(() => _isLoading = true);

  try {
    // 1. Complete the trip in database
    await _tripService.completeTrip(widget.trip.id);

    // 2. Navigate to payment page
    final paymentSuccess = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          tripId: widget.trip.id,
          amount: widget.trip.finalPrice,
        ),
      ),
    );

    if (paymentSuccess == true && mounted) {
      CustomToast.showSuccess(
        context: context,
        message: 'Trip completed and paid!',
      );
      widget.onTripCompleted();
    }
  } catch (e) {
    CustomToast.showError(
      context: context,
      message: 'Failed to complete trip: $e',
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

---

## Testing

### Sandbox Testing

PayFast provides a sandbox environment for testing:

**Sandbox Credentials:**
```
Merchant ID: 10000100
Merchant Key: 46f0cd694581a
URL: https://sandbox.payfast.co.za/eng/process
```

**Test Cards:**
```
Card Number: 4000 0000 0000 0002
CVV: 123
Expiry: Any future date
```

### Testing Checklist

- [ ] ✅ Create payment intent
- [ ] ✅ Launch PayFast checkout
- [ ] ✅ Complete successful payment
- [ ] ✅ Test payment cancellation
- [ ] ✅ Test payment failure
- [ ] ✅ Verify webhook receives IPN
- [ ] ✅ Verify database updates correctly
- [ ] ✅ Test signature validation
- [ ] ✅ Test return to app after payment

---

## Production Deployment

### Checklist Before Going Live

1. **Switch to Production Credentials**
   ```env
   PAYFAST_MERCHANT_ID=your_production_id
   PAYFAST_MERCHANT_KEY=your_production_key
   PAYFAST_URL=https://www.payfast.co.za/eng/process
   NODE_ENV=production
   ```

2. **SSL Certificate**
   - Ensure backend has valid SSL certificate
   - Webhook URL must be HTTPS

3. **Webhook Configuration**
   - Update PayFast dashboard with production webhook URL
   - Test webhook in production environment

4. **Error Handling**
   - Implement comprehensive error logging
   - Set up monitoring alerts

5. **Compliance**
   - Review POPIA compliance
   - Ensure PCI DSS compliance
   - Update terms and privacy policy

---

## Troubleshooting

### Common Issues

**1. Invalid Signature Error**
```
Solution: Verify passphrase matches in both app and PayFast dashboard
```

**2. Webhook Not Firing**
```
Solution:
- Check webhook URL is publicly accessible
- Verify HTTPS is enabled
- Check PayFast dashboard logs
```

**3. Payment Not Updating**
```
Solution:
- Check database connection
- Verify webhook signature validation
- Check payment status mapping
```

**4. Deep Link Not Working**
```
Solution:
- Verify return URL scheme is registered
- Test deep link configuration
- Check URL encoding
```

---

## Support

- **PayFast Documentation:** https://developers.payfast.co.za/
- **Support Email:** support@payfast.co.za
- **Phone:** +27 21 202 7251
- **Business Hours:** Mon-Fri, 8am-5pm SAST

---

## Next Steps

1. ✅ Complete PayFast merchant registration
2. ✅ Implement backend payment endpoints
3. ✅ Integrate Flutter payment UI
4. ✅ Test in sandbox environment
5. ✅ Deploy to production
6. ✅ Monitor transactions and optimize

Good luck with your payment integration! 🚀
