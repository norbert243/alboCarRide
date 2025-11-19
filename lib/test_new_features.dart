import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/saved_address_service.dart';
import 'services/mobile_money_service.dart';
import 'services/emergency_sos_service.dart';
import 'screens/emergency/emergency_contacts_page.dart';
import 'screens/customer/saved_addresses_page.dart';
import 'screens/driver/driver_mobile_money_setup_page.dart';
import 'screens/driver/wallet_commission_page.dart';
import 'widgets/sos_button.dart';

/// Temporary testing page to access new features
/// Add this to your app temporarily to test new features
class TestNewFeaturesPage extends StatelessWidget {
  const TestNewFeaturesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Test New Features'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '🚨 EMERGENCY & SAFETY',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),

          // Emergency Contacts
          Card(
            child: ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: const Text('Emergency Contacts'),
              subtitle: const Text('Add up to 3 emergency contacts'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmergencyContactsPage(),
                  ),
                );
              },
            ),
          ),

          // SOS Button Demo
          Card(
            child: ListTile(
              leading: const Icon(Icons.sos, color: Colors.red),
              title: const Text('SOS Button Demo'),
              subtitle: const Text('Test emergency alert (hold 3s)'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('SOS Test')),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Hold button for 3 seconds',
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 30),
                            SosButton(
                              userRole: 'customer',
                              tripId: null,
                              size: 80,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          const Text(
            '📍 ADDRESSES & DESTINATIONS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 10),

          // Saved Addresses
          Card(
            child: ListTile(
              leading: const Icon(Icons.home, color: Colors.blue),
              title: const Text('Saved Addresses'),
              subtitle: const Text('Home, work, favorites'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SavedAddressesPage(),
                  ),
                );
              },
            ),
          ),

          // Recent Destinations Test
          Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.blue),
              title: const Text('Recent Destinations'),
              subtitle: const Text('Test auto-tracking'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => _testRecentDestinations(context),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          const Text(
            '💰 PAYMENTS (DRIVER)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),

          // Mobile Money Setup
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: const Text('Mobile Money Accounts'),
              subtitle: const Text('M-Pesa, Orange, Airtel'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverMobileMoneySetupPage(),
                  ),
                );
              },
            ),
          ),

          // Wallet Commission
          Card(
            child: ListTile(
              leading: const Icon(Icons.payment, color: Colors.green),
              title: const Text('Wallet & Commission'),
              subtitle: const Text('Pay commission, view balance'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WalletCommissionPage(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          const Text(
            '🧪 DATABASE TESTS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 10),

          // Test Database
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage, color: Colors.purple),
              title: const Text('Test Database Connection'),
              subtitle: const Text('Verify all tables exist'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _testDatabase(context),
            ),
          ),

          // Test Services
          Card(
            child: ListTile(
              leading: const Icon(Icons.code, color: Colors.purple),
              title: const Text('Test Services'),
              subtitle: const Text('Run backend service tests'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _testServices(context),
            ),
          ),

          const SizedBox(height: 30),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '📋 TESTING INSTRUCTIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Emergency Contacts: Add 3 contacts first\n'
                  '2. SOS Button: Test with your own phone number\n'
                  '3. Saved Addresses: Add home and work\n'
                  '4. Mobile Money: Add M-Pesa account\n'
                  '5. Database Test: Verify all tables created\n\n'
                  '⚠️ These features are NOT yet integrated into\n'
                  'your main app. Use this test page for now.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testRecentDestinations(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        _showMessage(context, 'Please login first', isError: true);
        return;
      }

      // Query recent destinations
      final response = await supabase
          .from('recent_destinations')
          .select()
          .eq('user_id', userId)
          .order('last_visited_at', ascending: false);

      if (response.isEmpty) {
        _showMessage(
          context,
          '✅ Table exists but no destinations yet.\nComplete a ride to auto-track.',
        );
      } else {
        _showMessage(
          context,
          '✅ Found ${response.length} recent destinations!',
        );
      }
    } catch (e) {
      _showMessage(context, '❌ Error: $e', isError: true);
    }
  }

  Future<void> _testDatabase(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        _showMessage(context, 'Please login first', isError: true);
        return;
      }

      final results = <String>[];

      // Test each table
      final tables = [
        'saved_addresses',
        'recent_destinations',
        'driver_mobile_money',
        'emergency_contacts',
        'sos_incidents',
        'wallet_commission_payments',
        'trip_payments',
      ];

      for (final table in tables) {
        try {
          await supabase.from(table).select('id').limit(1);
          results.add('✅ $table');
        } catch (e) {
          results.add('❌ $table: ${e.toString().substring(0, 50)}');
        }
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database Test Results'),
          content: SingleChildScrollView(
            child: Text(results.join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage(context, '❌ Database error: $e', isError: true);
    }
  }

  Future<void> _testServices(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        _showMessage(context, 'Please login first', isError: true);
        return;
      }

      final results = <String>[];

      // Test SavedAddressService
      try {
        final savedAddrService = SavedAddressService(supabase);
        await savedAddrService.getSavedAddresses(userId);
        results.add('✅ SavedAddressService');
      } catch (e) {
        results.add('❌ SavedAddressService: $e');
      }

      // Test MobileMoneyService
      try {
        final mobileMoneyService = MobileMoneyService(supabase);
        await mobileMoneyService.getDriverMobileMoneyAccounts(userId);
        results.add('✅ MobileMoneyService');
      } catch (e) {
        results.add('❌ MobileMoneyService: $e');
      }

      // Test EmergencySosService
      try {
        final sosService = EmergencySosService(supabase);
        await sosService.getEmergencyContacts(userId);
        results.add('✅ EmergencySosService');
      } catch (e) {
        results.add('❌ EmergencySosService: $e');
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Service Test Results'),
          content: SingleChildScrollView(
            child: Text(results.join('\n\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage(context, '❌ Service test error: $e', isError: true);
    }
  }

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
