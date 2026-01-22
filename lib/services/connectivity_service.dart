import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    _isOnline = await checkConnectivity();
    // Periodically check connectivity
    Timer.periodic(const Duration(seconds: 30), (_) async {
      final wasOnline = _isOnline;
      _isOnline = await checkConnectivity();
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
      }
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _connectivityController.close();
  }
}

/// A widget that shows an offline banner when there's no connectivity
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOnline = true;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;
    _subscription = ConnectivityService.instance.connectivityStream.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          MaterialBanner(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No internet connection. Some features may be unavailable.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            actions: [
              TextButton(
                onPressed: () async {
                  final online = await ConnectivityService.instance.checkConnectivity();
                  if (mounted) {
                    setState(() => _isOnline = online);
                    if (online) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connected!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Helper class for input validation
class InputValidators {
  /// Validate phone number (basic validation)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove spaces and dashes
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it contains only digits and optional + at start
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned)) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate name (not empty, reasonable length)
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (value.length > 100) {
      return 'Name is too long';
    }

    // Check for invalid characters (letters, spaces, hyphens, apostrophes, periods)
    if (!RegExp(r"^[a-zA-Z\s\-'.]+$").hasMatch(value)) {
      return 'Name contains invalid characters';
    }

    return null;
  }

  /// Validate OTP code
  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP code is required';
    }

    if (!RegExp(r'^[0-9]{4,6}$').hasMatch(value)) {
      return 'Please enter a valid OTP code';
    }

    return null;
  }

  /// Validate price/amount
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid number';
    }

    if (price <= 0) {
      return 'Price must be greater than 0';
    }

    if (price > 100000) {
      return 'Price seems too high';
    }

    return null;
  }

  /// Validate address
  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Address is required';
    }

    if (value.length < 5) {
      return 'Please enter a valid address';
    }

    return null;
  }

  /// Validate message/description
  static String? validateMessage(String? value, {int minLength = 10}) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }

    if (value.length < minLength) {
      return 'Please enter at least $minLength characters';
    }

    return null;
  }

  /// Validate vehicle registration number
  static String? validateVehicleRegistration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Registration number is required';
    }

    if (value.length < 3 || value.length > 15) {
      return 'Please enter a valid registration number';
    }

    return null;
  }
}
