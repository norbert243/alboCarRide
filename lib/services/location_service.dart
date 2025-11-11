import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart';

class LocationService {
  /// Get place suggestions for autocomplete
  static Future<List<Map<String, dynamic>>> getPlaceSuggestions(
    String query,
  ) async {
    if (query.isEmpty) return [];

    try {
      final apiKey = ApiConfig.googleMapsApiKey;
      final url =
          '${ApiConfig.placesAutocompleteEndpoint}?input=$query&key=$apiKey';

      print('🔍 LocationService: Making Places API request');
      print('🔍 URL: $url');
      print('🔍 API Key length: ${apiKey.length}');

      final response = await http.get(Uri.parse(url));

      print('🔍 Places API Response Status: ${response.statusCode}');
      print('🔍 Places API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List?;

        if (predictions != null) {
          print('🔍 Found ${predictions.length} place suggestions');
          return predictions.map((prediction) {
            return {
              'placeId': prediction['place_id'],
              'description': prediction['description'],
              'mainText':
                  prediction['structured_formatting']?['main_text'] ??
                  prediction['description'],
              'secondaryText':
                  prediction['structured_formatting']?['secondary_text'] ?? '',
            };
          }).toList();
        }
      } else {
        print('❌ Places API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting place suggestions: $e');
    }

    return [];
  }

  /// Get place details by place ID
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.placesDetailsEndpoint}?place_id=$placeId&key=${ApiConfig.googleMapsApiKey}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];

        if (result != null) {
          final geometry = result['geometry'];
          final location = geometry?['location'];

          return {
            'address': result['formatted_address'],
            'latitude': location?['lat'],
            'longitude': location?['lng'],
            'name': result['name'],
          };
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    }

    return null;
  }

  /// Calculate distance and duration between two points
  static Future<Map<String, dynamic>?> calculateRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.directionsEndpoint}?'
          'origin=$originLat,$originLng&'
          'destination=$destLat,$destLng&'
          'key=${ApiConfig.googleMapsApiKey}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes.first;
          final legs = route['legs'] as List?;

          if (legs != null && legs.isNotEmpty) {
            final leg = legs.first;
            final distance = leg['distance']?['value']; // in meters
            final duration = leg['duration']?['value']; // in seconds

            return {
              'distanceMeters': distance,
              'distanceMiles': (distance ?? 0) / 1609.34, // convert to miles
              'durationSeconds': duration,
              'durationMinutes': (duration ?? 0) / 60, // convert to minutes
            };
          }
        }
      }
    } catch (e) {
      print('Error calculating route: $e');
    }

    return null;
  }

  /// Geocode an address to get coordinates
  static Future<Map<String, dynamic>?> geocodeAddress(String address) async {
    try {
      final apiKey = ApiConfig.googleMapsApiKey;
      final url =
          '${ApiConfig.geocodingEndpoint}?address=${Uri.encodeComponent(address)}&key=$apiKey';

      print('🔍 LocationService: Making Geocoding API request');
      print('🔍 URL: $url');

      final response = await http.get(Uri.parse(url));

      print('🔍 Geocoding API Response Status: ${response.statusCode}');
      print('🔍 Geocoding API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final result = results.first;
          final geometry = result['geometry'];
          final location = geometry?['location'];

          print('🔍 Geocoding successful: ${result['formatted_address']}');
          return {
            'address': result['formatted_address'],
            'latitude': location?['lat'],
            'longitude': location?['lng'],
          };
        } else {
          print('❌ No geocoding results found');
        }
      } else {
        print(
          '❌ Geocoding API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error geocoding address: $e');
    }

    return null;
  }

  /// Estimate fare based on distance and time
  static Future<double?> estimateFare(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final routeInfo = await calculateRoute(
      originLat,
      originLng,
      destLat,
      destLng,
    );

    if (routeInfo != null) {
      final distanceMiles = routeInfo['distanceMiles'] ?? 0;
      final durationMinutes = routeInfo['durationMinutes'] ?? 0;

      return FareCalculator.calculateFare(
        distanceMiles,
        durationMinutes.toInt(),
      );
    }

    return null;
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    // Convert to miles
    return distance * 0.621371;
  }

  /// Get route polyline between two points
  static Future<List<LatLng>> getRoutePolyline(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.directionsEndpoint}?'
          'origin=$originLat,$originLng&'
          'destination=$destLat,$destLng&'
          'key=${ApiConfig.googleMapsApiKey}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes.first;
          final overviewPolyline = route['overview_polyline'];
          final points = overviewPolyline?['points'] as String?;

          if (points != null) {
            return _decodePolyline(points);
          }
        }
      }
    } catch (e) {
      print('Error getting route polyline: $e');
    }

    return [];
  }

  /// Decode Google Maps polyline string to list of LatLng points
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}

class FareCalculator {
  /// Calculate fare based on distance and time
  static double calculateFare(double distanceMiles, int durationMinutes) {
    // Base fare
    double baseFare = 2.50;

    // Distance rate (per mile)
    double distanceRate = 1.75;

    // Time rate (per minute)
    double timeRate = 0.25;

    // Calculate total fare
    double distanceFare = distanceMiles * distanceRate;
    double timeFare = durationMinutes * timeRate;

    return baseFare + distanceFare + timeFare;
  }
}
