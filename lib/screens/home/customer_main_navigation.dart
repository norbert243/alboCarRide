import 'package:flutter/material.dart';
import 'package:albocarride/screens/home/indrive_book_ride_complete.dart';
import 'package:albocarride/screens/home/rides_history_page.dart';
import 'package:albocarride/screens/home/account_page.dart';

/// Main navigation wrapper with 3-tab bottom navigation (Bolt style)
/// Tabs: Home, Rides, Account
class CustomerMainNavigation extends StatefulWidget {
  const CustomerMainNavigation({super.key});

  @override
  State<CustomerMainNavigation> createState() => _CustomerMainNavigationState();
}

class _CustomerMainNavigationState extends State<CustomerMainNavigation> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      InDriverBookRideComplete(
        onNavigateToAccount: () => _navigateToTab(2),
      ), // Home tab - inDriver booking screen
      const RideHistoryPage(), // Rides tab - ride history
      const AccountPage(), // Account tab - profile & settings
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF2196F3), // Bolt blue
              unselectedItemColor: const Color(0xFF9E9E9E),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
              elevation: 0, // We handle shadow with container
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, size: 24),
                  activeIcon: Icon(Icons.home, size: 24),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined, size: 24),
                  activeIcon: Icon(Icons.calendar_today, size: 24),
                  label: 'Rides',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline, size: 24),
                  activeIcon: Icon(Icons.person, size: 24),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
