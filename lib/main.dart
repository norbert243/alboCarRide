import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:albocarride/screens/auth/auth_wrapper.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/auth/signup_page.dart';
import 'package:albocarride/screens/auth/vehicle_type_selection_page.dart';
import 'package:albocarride/screens/auth/vehicle_details_page.dart';
import 'package:albocarride/screens/driver/verification_page.dart';
import 'package:albocarride/screens/driver/waiting_for_review_page.dart';
import 'package:albocarride/screens/home/customer_home_page.dart';
import 'package:albocarride/screens/home/comprehensive_driver_dashboard.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await _setupFirebaseMessaging();
  await AuthService.initialize();
}

Future<void> _setupFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission();

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    final token = await messaging.getToken();
    if (token != null) _saveFcmToken(token);
    messaging.onTokenRefresh.listen(_saveFcmToken);
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
        '/role-selection': (context) => const RoleSelectionPage(),
        '/signup': (context) => SignupPage(role: ModalRoute.of(context)!.settings.arguments as String? ?? 'customer'),
        '/vehicle-type-selection': (context) => VehicleTypeSelectionPage(driverId: ModalRoute.of(context)!.settings.arguments as String? ?? ''),
        '/vehicle-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return VehicleDetailsPage(driverId: args?['driverId'] ?? '', vehicleType: args?['vehicleType'] ?? 'car');
        },
        '/verification': (context) => const VerificationPage(),
        '/waiting-review': (context) => const WaitingForReviewPage(),
        '/driver-dashboard': (context) => const ComprehensiveDriverDashboard(),
        '/payment-details': (context) => const PaymentDetailsPage(),
        '/customer-payment': (context) => CustomerPaymentPage(tripId: ModalRoute.of(context)!.settings.arguments as String),
        '/customer_home': (context) => const CustomerHomePage(),
        '/customer-ride-request': (context) => const CustomerRideRequestPage(),
        '/ride-history': (context) => const RideHistoryPage(),
        '/payments': (context) => const PaymentsPage(),
        '/support': (context) => const SupportPage(),
        '/driver-trip-management': (context) => DriverTripManagementPage(tripId: ModalRoute.of(context)!.settings.arguments as String),
        '/rider-trip-tracking': (context) => RiderTripTrackingPage(tripId: ModalRoute.of(context)!.settings.arguments as String),
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
        body: Center(
          child: Text('Failed to initialize app: $error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}