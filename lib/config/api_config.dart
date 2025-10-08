import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration for AlboCarRide
///
/// Essential APIs needed for a complete ride-hailing system:
///
/// 1. Google Maps Platform (Recommended)
///    - Places API: Address autocomplete and geocoding
///    - Directions API: Route calculation
///    - Distance Matrix API: Travel time and distance
///    - Geocoding API: Address to coordinates conversion
///
/// 2. Mapbox (Alternative to Google Maps)
///    - Search API: Address autocomplete
///    - Directions API: Route calculation
///    - Matrix API: Travel time calculation
///
/// 3. Stripe (Payment Processing)
///    - Payment Intents API: Secure payment processing
///    - Customers API: Customer management
///
/// 4. Firebase Cloud Messaging (Push Notifications)
///    - Real-time notifications to drivers and customers
///
/// 5. Twilio (SMS/Communication) - Already implemented
///    - SMS API: OTP verification and notifications

class ApiConfig {
  // Google Maps Platform Configuration
  static String get googleMapsApiKey => _getEnv('GOOGLE_MAPS_API_KEY');
  static const String googlePlacesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String googleDirectionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions';
  static const String googleGeocodingBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode';

  // Mapbox Configuration (Alternative)
  static String get mapboxAccessToken => _getEnv('MAPBOX_ACCESS_TOKEN');
  static const String mapboxBaseUrl = 'https://api.mapbox.com';

  // Stripe Configuration
  static String get stripePublishableKey => _getEnv('STRIPE_PUBLISHABLE_KEY');
  static const String stripeSecretKey =
      'YOUR_STRIPE_SECRET_KEY'; // Server-side only
  static const String stripeBaseUrl = 'https://api.stripe.com/v1';

  // Firebase Configuration
  static String get firebaseProjectId => _getEnv('FIREBASE_PROJECT_ID');
  static String get firebaseMessagingSenderId =>
      _getEnv('FIREBASE_MESSAGING_SENDER_ID');

  // Base fare calculation (in cents)
  static const int baseFare = 500; // $5.00
  static const double perMileRate = 150; // $1.50 per mile
  static const double perMinuteRate = 25; // $0.25 per minute
  static const double serviceFee = 99; // $0.99 service fee

  // API Endpoints
  static const String placesAutocompleteEndpoint =
      '$googlePlacesBaseUrl/autocomplete/json';
  static const String placesDetailsEndpoint =
      '$googlePlacesBaseUrl/details/json';
  static const String directionsEndpoint = '$googleDirectionsBaseUrl/json';
  static const String geocodingEndpoint = '$googleGeocodingBaseUrl/json';

  // Mapbox Endpoints
  static const String mapboxGeocodingEndpoint =
      '$mapboxBaseUrl/geocoding/v5/mapbox.places';
  static const String mapboxDirectionsEndpoint =
      '$mapboxBaseUrl/directions/v5/mapbox/driving';

  // Helper method to get environment variables
  static String _getEnv(String key) {
    try {
      final value = dotenv.env[key] ?? '';
      print(
        '🔍 ApiConfig: Reading $key = ${value.isNotEmpty ? "✓ SET" : "✗ EMPTY"}',
      );
      return value;
    } catch (e) {
      print('❌ Error reading environment variable $key: $e');
      return '';
    }
  }

  // Required API Keys Setup Instructions:
  //
  // 1. Google Maps Platform:
  //    - Go to https://console.cloud.google.com/
  //    - Enable: Places API, Directions API, Distance Matrix API, Geocoding API
  //    - Restrict API key to your app's domain
  //
  // 2. Mapbox (Alternative):
  //    - Sign up at https://www.mapbox.com/
  //    - Get access token from account dashboard
  //
  // 3. Stripe:
  //    - Sign up at https://stripe.com/
  //    - Get publishable and secret keys from dashboard
  //    - Implement webhooks for payment confirmation
  //
  // 4. Firebase:
  //    - Create project at https://console.firebase.google.com/
  //    - Enable Cloud Messaging
  //    - Download google-services.json for Android
  //    - Download GoogleService-Info.plist for iOS
}

/// Ride fare calculation service
class FareCalculator {
  /// Calculate estimated fare based on distance and time
  static double calculateFare(double distanceMiles, int durationMinutes) {
    final distanceFare = distanceMiles * ApiConfig.perMileRate;
    final timeFare = durationMinutes * ApiConfig.perMinuteRate;
    final total =
        ApiConfig.baseFare + distanceFare + timeFare + ApiConfig.serviceFee;
    return total / 100; // Convert cents to dollars
  }

  /// Calculate distance between two coordinates using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distanceKm = earthRadius * c;

    return distanceKm * 0.621371; // Convert to miles
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
