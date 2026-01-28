import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:albocarride/screens/auth/auth_wrapper.dart';
import 'package:albocarride/screens/auth/phone_entry_page.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/auth/signup_page.dart';
import 'package:albocarride/screens/auth/otp_verification_page.dart';
import 'package:albocarride/screens/auth/vehicle_type_selection_page.dart';
import 'package:albocarride/screens/auth/vehicle_details_page.dart';
import 'package:albocarride/screens/driver/verification_page.dart';
import 'package:albocarride/screens/driver/waiting_for_review_page.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/comprehensive_driver_dashboard.dart';
import 'package:albocarride/screens/home/enhanced_driver_home_page.dart';
import 'package:albocarride/screens/home/customer_ride_request_page.dart';
import 'package:albocarride/screens/home/ride_history_page.dart';
import 'package:albocarride/screens/home/payments_page.dart';
import 'package:albocarride/screens/home/support_page.dart';
import 'package:albocarride/screens/home/driver_trip_management_page.dart';
import 'package:albocarride/screens/home/rider_trip_tracking_page.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/utils/app_theme.dart';
import 'package:albocarride/screens/driver/payment_details_page.dart';
import 'package:albocarride/screens/customer_payment_page.dart';
import 'package:albocarride/screens/trips/trip_concern_page.dart';
import 'package:albocarride/screens/account/account_settings_page.dart';
import 'package:albocarride/screens/account/profile_picture_page.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await _initializeServices();
    runApp(const MyApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

Future<void> _initializeServices() async {
  await dotenv.load();

  // Initialize Firebase (optional - app works without it)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _setupFirebaseMessaging();
  } catch (e) {
    debugPrint('Firebase initialization failed (app will continue without push notifications): $e');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await AuthService.instance.initialize();
}

Future<void> _setupFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      if (token != null) _saveFcmToken(token);
      messaging.onTokenRefresh.listen(_saveFcmToken);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase Messaging setup failed: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle background message
}

void _saveFcmToken(String token) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null) {
    try {
      await Supabase.instance.client.from('profiles').update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      // Handle error
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlboCarRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthWrapper(),
      routes: {
        '/auth_wrapper': (context) => const AuthWrapper(),
        '/phone-entry': (context) => const PhoneEntryPage(),
        '/role-selection': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return RoleSelectionPage(phone: args?['phone'] as String?);
        },
        '/signup': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return SignupPage(
              role: args['role'] as String? ?? 'customer',
              phone: args['phone'] as String?,
            );
          }
          return SignupPage(role: args as String? ?? 'customer');
        },
        '/otp-verify': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return OtpVerificationPage(
            phone: args['phone'] as String,
            isLogin: args['isLogin'] as bool? ?? false,
            fullName: args['fullName'] as String?,
            role: args['role'] as String?,
          );
        },
        '/vehicle-type-selection': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return VehicleTypeSelectionPage(
            driverId: args?['driverId'] ?? '',
            fullName: args?['fullName'] ?? '',
            phone: args?['phone'] ?? '',
          );
        },
        '/vehicle-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return VehicleDetailsPage(
            driverId: args?['driverId'] ?? '',
            vehicleType: args?['vehicleType'] ?? 'car',
            fullName: args?['fullName'] ?? '',
            phone: args?['phone'] ?? '',
          );
        },
        '/verification': (context) => const VerificationPage(),
        '/waiting-review': (context) => const WaitingForReviewPage(),
        '/driver-dashboard': (context) => const ComprehensiveDriverDashboard(),
        '/enhanced-driver-home': (context) => const EnhancedDriverHomePage(),
        '/payment-details': (context) => const PaymentDetailsPage(),
        '/customer-payment': (context) => CustomerPaymentPage(tripId: ModalRoute.of(context)!.settings.arguments as String),
        '/customer_home': (context) => const CustomerHomePage(),
        '/customer-ride-request': (context) => const CustomerRideRequestPage(),
        '/ride-history': (context) => const RideHistoryPage(),
        '/payments': (context) => const PaymentsPage(),
        '/support': (context) => const SupportPage(),
        '/driver-trip-management': (context) => DriverTripManagementPage(tripId: ModalRoute.of(context)!.settings.arguments as String),
        '/rider-trip-tracking': (context) => RiderTripTrackingPage(tripId: ModalRoute.of(context)!.settings.arguments as String),
        '/trip-concern': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TripConcernPage(
            tripId: args['tripId'] as String,
            tripDetails: args['tripDetails'] as String?,
          );
        },
        '/account-settings': (context) => const AccountSettingsPage(),
        '/profile-picture': (context) => const ProfilePicturePage(),
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}