import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  /// Check and request location permissions with user-friendly dialogs
  static Future<bool> checkAndRequestLocationPermission(
    BuildContext context, {
    bool showDialog = true,
  }) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showDialog) {
          await _showLocationServicesDialog(context);
        }
        return false;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.denied:
          // Request permission
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (showDialog) {
              await _showPermissionDeniedDialog(context);
            }
            return false;
          }
          return true;

        case LocationPermission.deniedForever:
          if (showDialog) {
            await _showPermissionPermanentlyDeniedDialog(context);
          }
          return false;

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return true;

        case LocationPermission.unableToDetermine:
          // Request permission to determine status
          permission = await Geolocator.requestPermission();
          return permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever;
      }
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  /// Show dialog when location services are disabled
  static Future<void> _showLocationServicesDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are disabled. Please enable location services to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openLocationSettings();
              },
              child: const Text('Enable Location'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when permission is denied
  static Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs location permission to show nearby drivers and calculate accurate fares. '
            'Please grant location permission to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when permission is permanently denied
  static Future<void> _showPermissionPermanentlyDeniedDialog(
    BuildContext context,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission has been permanently denied. '
            'Please enable location permission in app settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Get current location with permission handling
  static Future<Position?> getCurrentLocationWithPermission(
    BuildContext context,
  ) async {
    final hasPermission = await checkAndRequestLocationPermission(context);

    if (!hasPermission) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current permission status
  static Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Open location settings
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings for permission management
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
