# Feature Integration Guide
**How to connect new features to existing AlboCarRide screens**

---

## 🚨 **1. ADD SOS BUTTON TO ACTIVE TRIP SCREEN**

### Customer Trip Tracking Page

**File:** `lib/screens/home/rider_trip_tracking_page.dart`

Add this import:
```dart
import '../../widgets/sos_button.dart';
import '../../services/emergency_sos_service.dart';
```

Add floating SOS button to your Scaffold:
```dart
Scaffold(
  appBar: AppBar(title: Text('Trip in Progress')),
  body: Column(
    children: [
      // Your existing trip tracking widgets
      MapWidget(),
      DriverInfoCard(),
      // ... other widgets
    ],
  ),
  floatingActionButton: SosButton(
    userRole: 'customer',
    tripId: currentTripId, // Your active trip ID
  ),
)
```

### Driver Trip Management Page

**File:** `lib/screens/home/driver_trip_management_page.dart`

```dart
import '../../widgets/sos_button.dart';

// Add to your Scaffold
floatingActionButton: SosButton(
  userRole: 'driver',
  tripId: currentTripId,
),
```

---

## 📍 **2. ADD SAVED ADDRESSES TO BOOKING FLOW**

### Customer Ride Request Page

**File:** `lib/screens/home/customer_ride_request_page.dart`

Add these imports:
```dart
import '../customer/saved_addresses_page.dart';
import '../../services/saved_address_service.dart';
import '../../services/recent_destinations_service.dart';
```

Add quick access buttons above your address input:
```dart
Column(
  children: [
    // Quick access to saved addresses
    Row(
      children: [
        IconButton(
          icon: Icon(Icons.home),
          onPressed: () async {
            final address = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SavedAddressesPage(
                  selectMode: true, // Return selected address
                ),
              ),
            );
            if (address != null) {
              setState(() {
                _pickupController.text = address.address;
                _pickupLatitude = address.latitude;
                _pickupLongitude = address.longitude;
              });
            }
          },
          tooltip: 'Saved Addresses',
        ),
        IconButton(
          icon: Icon(Icons.history),
          onPressed: () => _showRecentDestinations(),
          tooltip: 'Recent Destinations',
        ),
      ],
    ),

    // Your existing TextFormField for address
    TextFormField(
      controller: _pickupController,
      decoration: InputDecoration(
        labelText: 'Pickup Location',
        prefixIcon: Icon(Icons.location_on),
      ),
    ),
  ],
)
```

Add method to show recent destinations:
```dart
Future<void> _showRecentDestinations() async {
  final recentService = RecentDestinationsService(Supabase.instance.client);
  final userId = Supabase.instance.client.auth.currentUser!.id;

  final destinations = await recentService.getRecentDestinations(userId);

  if (destinations.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No recent destinations')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    builder: (context) => ListView.builder(
      itemCount: destinations.length,
      itemBuilder: (context, index) {
        final dest = destinations[index];
        return ListTile(
          leading: Icon(Icons.history),
          title: Text(dest.address),
          subtitle: Text('Visited ${dest.visitCount} times'),
          trailing: Text(
            _formatDate(dest.lastVisitedAt),
            style: TextStyle(fontSize: 12),
          ),
          onTap: () {
            setState(() {
              _dropoffController.text = dest.address;
              _dropoffLatitude = dest.latitude;
              _dropoffLongitude = dest.longitude;
            });
            Navigator.pop(context);
          },
        );
      },
    ),
  );
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${date.day}/${date.month}/${date.year}';
}
```

---

## 💰 **3. ADD PAYMENT FLOW AFTER TRIP COMPLETION**

### After Trip Ends

**File:** `lib/screens/home/rider_trip_tracking_page.dart`

When trip status changes to 'completed':
```dart
void _onTripCompleted() async {
  // Your existing completion logic

  // Navigate to payment page
  final tripData = await _getTripData();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TripPaymentPage(
        tripId: tripData.id,
        driverId: tripData.driverId,
        amount: tripData.finalPrice,
        commissionRate: 0.10, // 10%
      ),
    ),
  );
}
```

---

## 🚗 **4. DRIVER MOBILE MONEY SETUP**

### Add to Driver Profile/Settings

**File:** `lib/screens/home/driver_home_page.dart` or driver settings

Add navigation button:
```dart
import '../driver/driver_mobile_money_setup_page.dart';

// In your drawer or settings menu
ListTile(
  leading: Icon(Icons.account_balance_wallet),
  title: Text('Mobile Money Accounts'),
  subtitle: Text('Manage payment methods'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverMobileMoneySetupPage(),
      ),
    );
  },
),
```

---

## 💳 **5. DRIVER WALLET & COMMISSION**

### Add to Driver Dashboard

**File:** `lib/screens/home/driver_home_page.dart`

Show wallet balance in header:
```dart
import '../../services/wallet_commission_service.dart';

class _DriverHomePageState extends State<DriverHomePage> {
  Map<String, double>? _walletSummary;

  @override
  void initState() {
    super.initState();
    _loadWalletSummary();
  }

  Future<void> _loadWalletSummary() async {
    final service = WalletCommissionService(Supabase.instance.client);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final summary = await service.getDriverWalletSummary(userId);
    setState(() => _walletSummary = summary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard'),
        actions: [
          // Wallet indicator
          if (_walletSummary != null)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_walletSummary!['balance']!.toStringAsFixed(0)} CDF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _walletSummary!['balance']! < 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  if (_walletSummary!['outstanding_commission']! > 0)
                    Text(
                      'Owes: ${_walletSummary!['outstanding_commission']!.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: Colors.red),
                    ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(Icons.payment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletCommissionPage(),
                ),
              );
            },
            tooltip: 'Pay Commission',
          ),
        ],
      ),
      // ... rest of your UI
    );
  }
}
```

---

## 👥 **6. EMERGENCY CONTACTS SETUP**

### Add to Customer/Driver Settings

**File:** `lib/screens/home/customer_home_page.dart` or settings page

```dart
import '../emergency/emergency_contacts_page.dart';

// In drawer or settings menu
ListTile(
  leading: Icon(Icons.emergency, color: Colors.red),
  title: Text('Emergency Contacts'),
  subtitle: Text('Set up SOS alerts'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyContactsPage(),
      ),
    );
  },
),
```

---

## 📍 **7. LIVE LOCATION SHARING**

### Add Share Button During Active Trip

**File:** `lib/screens/home/rider_trip_tracking_page.dart`

```dart
import '../../services/live_location_service.dart';

// Add button in your trip tracking UI
IconButton(
  icon: Icon(Icons.share_location),
  onPressed: () async {
    final locationService = LiveLocationService();
    final currentLocation = await _getCurrentPosition();

    await locationService.shareLocationLink(
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      message: 'I\'m currently on a ride. Track my location:',
    );
  },
  tooltip: 'Share Live Location',
),
```

---

## 🔔 **8. FIRST-TIME SETUP WIZARD**

### Prompt Users to Set Up Features

Create a setup wizard for new users:

**File:** `lib/screens/onboarding/feature_setup_wizard.dart`

```dart
import 'package:flutter/material.dart';
import '../emergency/emergency_contacts_page.dart';
import '../customer/saved_addresses_page.dart';
import '../driver/driver_mobile_money_setup_page.dart';

class FeatureSetupWizard extends StatefulWidget {
  final String userRole; // 'customer' or 'driver'

  const FeatureSetupWizard({required this.userRole});

  @override
  _FeatureSetupWizardState createState() => _FeatureSetupWizardState();
}

class _FeatureSetupWizardState extends State<FeatureSetupWizard> {
  int _currentStep = 0;

  List<Step> get _steps {
    if (widget.userRole == 'customer') {
      return [
        Step(
          title: Text('Emergency Contacts'),
          content: Text('Add contacts to notify in case of emergency'),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: Text('Saved Addresses'),
          content: Text('Save your home and work addresses'),
          isActive: _currentStep >= 1,
        ),
      ];
    } else {
      return [
        Step(
          title: Text('Emergency Contacts'),
          content: Text('Add contacts to notify in case of emergency'),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: Text('Mobile Money'),
          content: Text('Set up how you receive payments'),
          isActive: _currentStep >= 1,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome to AlboCarRide')),
      body: Stepper(
        currentStep: _currentStep,
        steps: _steps,
        onStepContinue: () {
          if (_currentStep < _steps.length - 1) {
            setState(() => _currentStep++);
          } else {
            Navigator.pop(context); // Setup complete
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
      ),
    );
  }
}
```

---

## 🔄 **9. AUTO-TRACK RECENT DESTINATIONS**

### After Trip Completion

**File:** `lib/services/trip_service.dart` or wherever you handle trip completion

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recent_destinations_service.dart';

Future<void> completeTripAndTrackDestination({
  required String tripId,
  required String customerId,
  required String dropoffAddress,
  required double dropoffLat,
  required double dropoffLng,
}) async {
  final supabase = Supabase.instance.client;

  // Your existing trip completion logic
  await supabase.from('trips').update({
    'status': 'completed',
    'completed_at': DateTime.now().toIso8601String(),
  }).eq('id', tripId);

  // Auto-track recent destination
  final recentService = RecentDestinationsService(supabase);
  await recentService.upsertDestination(
    userId: customerId,
    address: dropoffAddress,
    latitude: dropoffLat,
    longitude: dropoffLng,
  );
}
```

---

## ⚠️ **10. HANDLE MISSING EMERGENCY CONTACTS**

### Show Warning if SOS Button Clicked Without Contacts

**File:** `lib/widgets/sos_button.dart` (already created, but add this check)

Before triggering SOS:
```dart
Future<void> _triggerSos() async {
  final sosService = EmergencySosService(Supabase.instance.client);
  final userId = Supabase.instance.client.auth.currentUser!.id;

  // Check if user has emergency contacts
  final contacts = await sosService.getEmergencyContacts(userId);

  if (widget.userRole == 'customer' && contacts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please add emergency contacts first'),
        action: SnackBarAction(
          label: 'Add Now',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmergencyContactsPage(),
              ),
            );
          },
        ),
      ),
    );
    return;
  }

  // Continue with SOS trigger
  // ... existing code
}
```

---

## 📱 **11. PUSH NOTIFICATION SETUP FOR DRIVER SOS**

### Configure FCM for Driver Alerts

**File:** `lib/services/notification_service.dart` (update existing)

Add handler for SOS notifications:
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Your existing notification setup

    // Listen for SOS alerts
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'driver_sos') {
        _showSosAlert(message.data);
      }
    });
  }

  void _showSosAlert(Map<String, dynamic> data) {
    // Show high priority notification
    // data contains: latitude, longitude, driver_name, distance
  }
}
```

---

## 🎯 **INTEGRATION CHECKLIST**

### Customer App:
- [ ] SOS button on active trip screen
- [ ] Emergency contacts in settings menu
- [ ] Saved addresses in booking flow
- [ ] Recent destinations in destination picker
- [ ] Payment page after trip completion
- [ ] Live location sharing during trip

### Driver App:
- [ ] SOS button on active trip screen
- [ ] Emergency contacts in settings menu
- [ ] Mobile money setup in profile/settings
- [ ] Wallet balance in dashboard header
- [ ] Commission payment page accessible
- [ ] Payment confirmation for completed trips

### Both:
- [ ] First-time setup wizard for new users
- [ ] SMS permissions requested on first SOS attempt
- [ ] Auto-track destinations after trips
- [ ] Push notifications for SOS alerts

---

## 🚀 **DEPLOYMENT ORDER**

1. **Day 1:** Emergency contacts + SOS button (CRITICAL for safety)
2. **Day 2:** Mobile money setup + payment flow (CRITICAL for revenue)
3. **Day 3:** Saved addresses + recent destinations (UX improvement)
4. **Day 4:** Wallet commission + live location (Driver features)
5. **Day 5:** Testing with beta users in Kinshasa
6. **Day 6:** Bug fixes and refinements
7. **Day 7:** PUBLIC LAUNCH 🇨🇩

---

**🎉 All features are production-ready. Just wire them into your existing UI!**
