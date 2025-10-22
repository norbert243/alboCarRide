import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LocationService {
  /// Get place suggestions for autocomplete
  static Future<List<Map<String, dynamic>>> getPlaceSuggestions(
    String query,
  ) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.placesAutocompleteEndpoint}?input=$query&key=${ApiConfig.googleMapsApiKey}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List?;

        if (predictions != null) {
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
      }
    } catch (e) {
      print('Error getting place suggestions: $e');
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
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.geocodingEndpoint}?address=${Uri.encodeComponent(address)}&key=${ApiConfig.googleMapsApiKey}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final result = results.first;
          final geometry = result['geometry'];
          final location = geometry?['location'];

          return {
            'address': result['formatted_address'],
            'latitude': location?['lat'],
            'longitude': location?['lng'],
          };
        }
      }
    } catch (e) {
      print('Error geocoding address: $e');
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
}
