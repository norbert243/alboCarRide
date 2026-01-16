import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
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
import 'package:albocarride/screens/home/book_ride_page.dart';
import 'package:albocarride/screens/home/ride_history_page.dart';
import 'package:albocarride/screens/home/payments_page.dart';
import 'package:albocarride/screens/home/support_page.dart';
import 'package:albocarride/screens/home/driver_trip_management_page.dart';
import 'package:albocarride/screens/home/rider_trip_tracking_page.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/utils/app_theme.dart';

// Background message handler (must be a top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure to call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("Handling a background message: ${message.messageId}");
  print("Message data: ${message.data}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from assets
  await dotenv.load();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Set up Firebase Messaging after Supabase is initialized
  await _setupFirebaseMessaging();

  // Initialize Auth Service for session management
  print('main: Initializing AuthService...');
  await AuthService.initialize();
  print('main: AuthService initialization completed');

  runApp(const MyApp());
}

Future<void> _setupFirebaseMessaging() async {
  try {
    // Request notification permissions
    final messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the device token
      String? token = await messaging.getToken();
      print('Firebase Messaging Token: $token');
      if (token != null) {
        _saveFcmToken(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen(_saveFcmToken);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when the app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print('App opened from terminated state with message: ${message.data}');
        // You can navigate to a specific screen here based on the message data
      }
    });

    // Handle when the app is in the background and opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via notification: ${message.data}');
      // You can navigate to a specific screen here based on the message data
    });
  } catch (e) {
    print('Error setting up Firebase Messaging: $e');
  }
}

void _saveFcmToken(String token) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null) {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      print('FCM token saved for user $userId');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
}

import 'package:albocarride/screens/driver/payment_details_page.dart';

// ... other code

import 'package:albocarride/screens/customer_payment_page.dart';

// ... other code

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
        '/signup': (context) {
          final role =
              ModalRoute.of(context)!.settings.arguments as String? ??
              'customer';
          return SignupPage(role: role);
        },
        '/vehicle-type-selection': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String?;
          return VehicleTypeSelectionPage(driverId: args ?? '');
        },
        '/vehicle-details': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return VehicleDetailsPage(
            driverId: args?['driverId'] ?? '',
            vehicleType: args?['vehicleType'] ?? 'car',
          );
        },
        '/verification': (context) => const VerificationPage(),
        '/waiting-review': (context) => const WaitingForReviewPage(),
        '/driver-dashboard': (context) => const ComprehensiveDriverDashboard(),
        '/payment-details': (context) => const PaymentDetailsPage(),
        '/customer-payment': (context) {
          final tripId = ModalRoute.of(context)!.settings.arguments as String;
          return CustomerPaymentPage(tripId: tripId);
        },
        '/customer_home': (context) => const CustomerHomePage(),
        '/book-ride': (context) => const BookRidePage(),
        '/ride-history': (context) => const RideHistoryPage(),
        '/payments': (context) => const PaymentsPage(),
        '/support': (context) => const SupportPage(),
        '/driver-trip-management': (context) {
          final tripId = ModalRoute.of(context)!.settings.arguments as String;
          return DriverTripManagementPage(tripId: tripId);
        },
        '/rider-trip-tracking': (context) {
          final tripId = ModalRoute.of(context)!.settings.arguments as String;
          return RiderTripTrackingPage(tripId: tripId);
        },
      },
    );
  }
}
