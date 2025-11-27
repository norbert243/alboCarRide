import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'package:albocarride/screens/auth/auth_wrapper.dart';
import 'package:albocarride/screens/auth/role_selection_page.dart';
import 'package:albocarride/screens/auth/signup_page.dart';
import 'package:albocarride/screens/auth/vehicle_type_selection_page.dart';
import 'package:albocarride/screens/driver/verification_page.dart';
import 'package:albocarride/screens/driver/waiting_for_review_page.dart';
import 'package:albocarride/screens/home/customer_main_navigation.dart';
import 'package:albocarride/screens/home/comprehensive_driver_dashboard.dart';
import 'package:albocarride/screens/home/driver_home_page.dart';
import 'package:albocarride/screens/home/indrive_book_ride_complete.dart';
import 'package:albocarride/screens/home/ride_history_page.dart';
import 'package:albocarride/screens/home/payments_page.dart';
import 'package:albocarride/screens/home/support_page.dart';
import 'package:albocarride/screens/home/my_ride_requests_page.dart';
import 'package:albocarride/services/auth_service.dart';
import 'package:albocarride/screens/debug/session_debug_page.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/ride_matching_service.dart';
import 'package:albocarride/services/location_permission_service.dart';

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

  // Set up Firebase Messaging
  await _setupFirebaseMessaging();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Auth Service for session management
  print('main: Initializing AuthService...');
  await AuthService.initialize();
  print('main: AuthService initialization completed');

  // Initialize session service
  SessionService().initialize();

  // Start ride matching service to handle ride requests globally
  print('main: Starting RideMatchingService...');
  try {
    await RideMatchingService().startMatchingService();
    print('main: RideMatchingService started successfully');
  } catch (e) {
    print('main: Error starting RideMatchingService: $e');
  }

  // Request location permissions on app startup (especially important for iOS)
  await _requestLocationPermissions();

  runApp(const MyApp());
}

Future<void> _requestLocationPermissions() async {
  try {
    print('Requesting location permissions on app startup...');

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled on startup');
      return;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    print('Current location permission status: $permission');

    // If permission is denied or not determined, request it
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      print('Requesting location permission...');
      permission = await Geolocator.requestPermission();
      print('Location permission request result: $permission');

      if (permission == LocationPermission.denied) {
        print('Location permission denied by user');
      } else if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
      } else {
        print('Location permission granted: $permission');
      }
    } else {
      print('Location permission already granted: $permission');
    }
  } catch (e) {
    print('Error requesting location permissions: $e');
  }
}

Future<void> _setupFirebaseMessaging() async {
  try {
    // Request notification permissions
    final messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Get the device token
    String? token = await messaging.getToken();
    print('Firebase Messaging Token: $token');

    // For iOS/macOS, also get APNS token with error handling
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        String? apnsToken = await messaging.getAPNSToken();
        print('APNS Token: $apnsToken');
      } catch (e) {
        print('APNS token error (this is normal during development): $e');
      }
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
      }
    });

    // Handle when the app is in the background and opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via notification: ${message.data}');
    });
  } catch (e) {
    print('Error setting up Firebase Messaging: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlboCarRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
      ),
      home: const AuthWrapper(), // Production: Phone authentication with Twilio
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
        '/verification': (context) => const VerificationPage(),
        '/waiting-review': (context) => const WaitingForReviewPage(),
        '/enhanced-driver-home': (context) =>
            const ComprehensiveDriverDashboard(),
        '/driver_home': (context) => const ComprehensiveDriverDashboard(),
        '/customer_home': (context) => const CustomerMainNavigation(),
        '/book-ride': (context) => const InDriverBookRideComplete(),
        '/my-ride-requests': (context) => const MyRideRequestsPage(),
        '/ride-history': (context) => const RideHistoryPage(),
        '/payments': (context) => const PaymentsPage(),
        '/support': (context) => const SupportPage(),
        '/session-debug': (context) => const SessionDebugPage(),
      },
    );
  }
}
