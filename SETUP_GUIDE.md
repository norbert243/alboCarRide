# AlboCarRide API Setup Guide

This guide will help you set up the essential APIs needed for the ride-hailing system to function properly.

## Required APIs

### 1. Google Maps Platform (Recommended)

**Purpose**: Location services, geocoding, route calculation, distance estimation

**Setup Steps**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - Places API
   - Directions API  
   - Distance Matrix API
   - Geocoding API
4. Create an API key
5. Restrict the API key to your app's domain for security

**Configuration**:
Update `lib/config/api_config.dart`:
```dart
static const String googleMapsApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

### 2. Mapbox (Alternative to Google Maps)

**Purpose**: Location services alternative

**Setup Steps**:
1. Sign up at [Mapbox](https://www.mapbox.com/)
2. Get your access token from the account dashboard
3. Enable the necessary APIs

**Configuration**:
Update `lib/config/api_config.dart`:
```dart
static const String mapboxAccessToken = 'YOUR_ACCESS_TOKEN_HERE';
```

### 3. Stripe (Payment Processing)

**Purpose**: Secure payment processing for rides

**Setup Steps**:
1. Sign up at [Stripe](https://stripe.com/)
2. Get your publishable key and secret key from the dashboard
3. Set up webhooks for payment confirmation
4. Configure your business information

**Important Security Note**: Never expose your Stripe secret key in client-side code. Implement a backend server to handle payment processing.

**Configuration**:
Update `lib/config/api_config.dart`:
```dart
static const String stripePublishableKey = 'YOUR_PUBLISHABLE_KEY_HERE';
// Keep secret key on your server only!
```

### 4. Firebase Cloud Messaging (Push Notifications)

**Purpose**: Real-time notifications to drivers and customers

**Setup Steps**:
1. Create a project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Cloud Messaging
3. For Android: Download `google-services.json` and place in `android/app/`
4. For iOS: Download `GoogleService-Info.plist` and place in `ios/Runner/`
5. Configure push notification settings

**Configuration**:
Update `lib/config/api_config.dart`:
```dart
static const String firebaseProjectId = 'YOUR_PROJECT_ID_HERE';
static const String firebaseMessagingSenderId = 'YOUR_SENDER_ID_HERE';
```

### 5. Twilio (SMS/Communication) - Already Implemented

**Purpose**: SMS notifications and OTP verification

**Setup**: Already configured in the existing `TwilioService`

## Environment Variables Setup

Create or update your `.env` file with the following variables:

```env
# Google Maps
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here

# Stripe (client-side only)
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key_here

# Firebase
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_MESSAGING_SENDER_ID=your_firebase_sender_id

# Mapbox (alternative)
MAPBOX_ACCESS_TOKEN=your_mapbox_access_token_here
```

## Database Schema Updates

The following tables need to be created in your Supabase database:

### Ride Requests Table
```sql
CREATE TABLE ride_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES profiles(id) NOT NULL,
  driver_id UUID REFERENCES profiles(id),
  pickup_location TEXT NOT NULL,
  dropoff_location TEXT NOT NULL,
  pickup_lat DECIMAL,
  pickup_lng DECIMAL,
  dropoff_lat DECIMAL,
  dropoff_lng DECIMAL,
  estimated_fare DECIMAL NOT NULL,
  final_fare DECIMAL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, arrived, in_progress, completed, cancelled
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  accepted_at TIMESTAMP WITH TIME ZONE,
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE
);
```

### Driver Locations Table
```sql
CREATE TABLE driver_locations (
  driver_id UUID PRIMARY KEY REFERENCES profiles(id),
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Payments Table
```sql
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id UUID REFERENCES ride_requests(id) NOT NULL,
  stripe_payment_intent_id TEXT UNIQUE,
  amount DECIMAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'usd',
  status TEXT NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed, refunded
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);
```

## Testing the APIs

### 1. Test Location Services
- Open the Book Ride page
- Try entering addresses in the pickup/dropoff fields
- Verify that fare estimation works

### 2. Test Payment Flow
- Complete a ride booking
- Test the payment process (using Stripe test cards)

### 3. Test Notifications
- Book a ride as a customer
- Check if drivers receive notifications
- Test ride status updates

## Security Considerations

1. **API Keys**: Never commit actual API keys to version control
2. **Stripe Secret Key**: Keep on server-side only
3. **Input Validation**: Validate all user inputs
4. **Rate Limiting**: Implement rate limiting for API calls
5. **Error Handling**: Handle API failures gracefully

## Troubleshooting

### Common Issues:

1. **Google Maps API not working**:
   - Check if API key is valid and restricted properly
   - Verify that required APIs are enabled
   - Check billing information

2. **Payments failing**:
   - Verify Stripe keys are correct
   - Check webhook configuration
   - Test with Stripe test cards

3. **Notifications not sending**:
   - Check Firebase configuration
   - Verify device token registration
   - Check Twilio credentials

## Next Steps

After setting up the APIs, you can enhance the system with:

1. **Real-time tracking** of driver locations
2. **Advanced fare calculation** with surge pricing
3. **Rating system** for drivers and customers
4. **Ride history** and analytics
5. **Multiple payment methods** support
6. **Promo codes and discounts**

For production deployment, consider implementing:
- Backend API server for secure operations
- Database backups and monitoring
- Performance optimization
- Security audits