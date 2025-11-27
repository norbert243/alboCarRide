import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/screens/home/add_saved_place_page.dart';
import 'package:albocarride/screens/home/safety_page.dart';
import 'package:albocarride/utils/place_icon_helper.dart';

/// Single unified Account screen (Bolt style)
/// Shows all account options in one scrollable view
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _userName;
  String? _userEmail;
  double _userRating = 0.0;
  List<Map<String, dynamic>> _savedPlaces = [];
  bool _showDriverBanner = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = await SessionService.getUserIdStatic();
      // User ID from SessionService: $userId

      if (userId != null) {
        // Load profile
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .single();

        // Profile data loaded successfully

        // Load saved places
        final placesResponse = await Supabase.instance.client
            .from('saved_places')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            // Try both full_name and name fields
            _userName =
                profileResponse['full_name'] ??
                profileResponse['name'] ??
                'User';
            _userEmail =
                profileResponse['phone'] ?? profileResponse['phone_number'];
            _userRating =
                (profileResponse['rating'] as num?)?.toDouble() ?? 0.0;
            _savedPlaces = List<Map<String, dynamic>>.from(placesResponse);
            _isLoading = false;
          });
        }
      } else {
        // User ID is null - setting default values
        if (mounted) {
          setState(() {
            _userName = 'User';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Error loading user data: $e
      if (mounted) {
        setState(() {
          _userName = 'User';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshSavedPlaces() async {
    final userId = await SessionService.getUserIdStatic();
    if (userId != null) {
      try {
        final placesResponse = await Supabase.instance.client
            .from('saved_places')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _savedPlaces = List<Map<String, dynamic>>.from(placesResponse);
          });
        }
      } catch (e) {
        // Error refreshing saved places: $e
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Simple test header to verify page loads
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: const Text(
                        'Profile Page Test',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // PROFILE HEADER (Uber Style)
                    _buildUberProfileHeader(),

                    const SizedBox(height: 16),

                    // SECTION 1: RIDE & PAYMENTS
                    _buildSection(
                      title: 'Ride & payments',
                      items: [
                        _buildMenuItem(
                          icon: Icons.payment_outlined,
                          title: 'Payment',
                          onTap: () {
                            // Navigate to payment
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.receipt_long_outlined,
                          title: 'Ride history',
                          onTap: () {
                            // Navigate to ride history
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.star_border_outlined,
                          title: 'Rate your trips',
                          onTap: () {
                            // Navigate to rate trips
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // SECTION 2: ROLE SWITCHING
                    _buildSection(
                      title: 'Role',
                      items: [_buildRoleSwitchItem()],
                    ),

                    const SizedBox(height: 16),

                    // SECTION 3: ACCOUNT
                    _buildSection(
                      title: 'Account',
                      items: [
                        _buildMenuItem(
                          icon: Icons.person_outline,
                          title: 'Personal info',
                          onTap: () {
                            // Navigate to personal info
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.lock_outline,
                          title: 'Login & security',
                          onTap: () {
                            // Navigate to login & security
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy',
                          onTap: () {
                            // Navigate to privacy
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // SECTION 3: SAVED PLACES
                    _buildSavedPlacesSection(),

                    const SizedBox(height: 16),

                    // SECTION 4: PREFERENCES
                    _buildSection(
                      title: 'Preferences',
                      items: [
                        _buildMenuItem(
                          icon: Icons.language,
                          title: 'Language',
                          trailing: 'English',
                          onTap: () {
                            // Navigate to language selection
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          onTap: () {
                            // Navigate to notifications
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.accessibility_outlined,
                          title: 'Accessibility',
                          onTap: () {
                            // Navigate to accessibility
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // SECTION 5: SAFETY
                    _buildSection(
                      title: 'Safety',
                      items: [
                        _buildMenuItem(
                          icon: Icons.shield_outlined,
                          title: 'Safety toolkit',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SafetyPage(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.emergency_outlined,
                          title: 'Emergency contacts',
                          onTap: () {
                            // Navigate to emergency contacts
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // SECTION 6: ABOUT
                    _buildSection(
                      title: 'About',
                      items: [
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Help',
                          onTap: () {
                            // Navigate to help
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.info_outline,
                          title: 'About',
                          onTap: () {
                            // Navigate to about
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.description_outlined,
                          title: 'Terms & privacy',
                          onTap: () {
                            // Navigate to terms & privacy
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // LOGOUT SECTION
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              leading: const Icon(
                                Icons.logout,
                                size: 24,
                                color: Color(0xFFF44336),
                              ),
                              title: const Text(
                                'Log out',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFF44336),
                                ),
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Log out'),
                                    content: const Text(
                                      'Are you sure you want to log out?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await Supabase.instance.client.auth
                                              .signOut();
                                          if (context.mounted) {
                                            Navigator.of(
                                              context,
                                            ).pushNamedAndRemoveUntil(
                                              '/role_selection',
                                              (route) => false,
                                            );
                                          }
                                        },
                                        child: const Text(
                                          'Log out',
                                          style: TextStyle(
                                            color: Color(0xFFF44336),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              leading: const Icon(
                                Icons.delete_outline,
                                size: 24,
                                color: Color(0xFFF44336),
                              ),
                              title: const Text(
                                'Delete account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFF44336),
                                ),
                              ),
                              onTap: () {
                                // Show delete confirmation
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // BECOME A DRIVER BANNER
                    if (_showDriverBanner) _buildUberDriverBanner(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUberProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade100,
            child: Icon(Icons.person, size: 32, color: Colors.grey.shade600),
          ),

          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                    const SizedBox(width: 4),
                    Text(
                      _userRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (_userEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _userEmail!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),

          // Edit button
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                // Navigate to edit profile
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Section items
          ...items,
        ],
      ),
    );
  }

  Widget _buildUberDriverBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Stack(
        children: [
          // Close button
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showDriverBanner = false;
                });
              },
              child: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
            ),
          ),

          // Banner content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drive with AlboCarRide',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Earn money on your schedule',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade600),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: () {
                      // Navigate to driver registration
                    },
                    child: const Text(
                      'Get started',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: 12,
          ),
          color: const Color(0xFFFAFAFA),
          child: const Text(
            'SAVED PLACES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF616161),
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Saved places list
        Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              // Display saved places
              ..._savedPlaces.map((place) => _buildSavedPlaceItem(place)),

              // Add a place button
              _buildAddPlaceButton(),
            ],
          ),
        ),
      ],
    );
  }

  void _showPlaceOptionsBottomSheet(Map<String, dynamic> place) {
    final name = place['name'] ?? 'Unnamed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Edit location
            ListTile(
              leading: const Icon(Icons.edit_location_outlined),
              title: const Text('Edit location'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddSavedPlacePage(existingPlace: place),
                  ),
                ).then((_) => _refreshSavedPlaces());
              },
            ),
            // Delete this place
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFF44336),
              ),
              title: const Text(
                'Delete this place',
                style: TextStyle(color: Color(0xFFF44336)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deleteSavedPlace(place['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSavedPlace(String placeId) async {
    try {
      await Supabase.instance.client
          .from('saved_places')
          .delete()
          .eq('id', placeId);

      await _refreshSavedPlaces();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Place deleted successfully')),
        );
      }
    } catch (e) {
      // Error deleting place: $e
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete place')));
      }
    }
  }

  Widget _buildSavedPlaceItem(Map<String, dynamic> place) {
    final iconName = place['icon'] ?? 'place';
    final iconData = PlaceIconHelper.getIcon(iconName);
    final name = place['name'] ?? 'Unnamed';
    final address = place['address'] ?? '';

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, size: 24, color: const Color(0xFF757575)),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF212121),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              address,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF757575),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
            color: Color(0xFFBDBDBD),
          ),
          onTap: () => _showPlaceOptionsBottomSheet(place),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        ),
      ],
    );
  }

  Widget _buildAddPlaceButton() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0xFFE3F2FD),
        child: Icon(Icons.add, size: 24, color: Color(0xFF2196F3)),
      ),
      title: const Text(
        'Add a place',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2196F3),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: Color(0xFF2196F3),
      ),
      onTap: () async {
        // Navigate to add saved place flow
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddSavedPlacePage()),
        );

        // Refresh saved places if a place was added
        if (result == true) {
          _refreshSavedPlaces();
        }
      },
    );
  }

  Widget _buildRoleSwitchItem() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.switch_account,
          size: 24,
          color: Colors.blue.shade600,
        ),
      ),
      title: const Text(
        'Switch Role',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      subtitle: const Text(
        'Switch between customer and driver',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Customer',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade800,
          ),
        ),
      ),
      onTap: () {
        _showRoleSwitchDialog();
      },
    );
  }

  void _showRoleSwitchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Role'),
        content: const Text('Choose the role you want to switch to:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _switchToDriverRole();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child: const Text(
              'Switch to Driver',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _switchToDriverRole() async {
    final currentContext = context;

    try {
      // Show loading
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Switching to driver role...'),
            ],
          ),
        ),
      );

      // In a real app, you would update the user's role in the database
      // For now, we'll just navigate to the driver home page
      await Future.delayed(const Duration(seconds: 1));

      if (!currentContext.mounted) return;
      Navigator.of(
        currentContext,
      ).pushNamedAndRemoveUntil('/driver_home', (route) => false);
    } catch (e) {
      if (currentContext.mounted) {
        Navigator.pop(currentContext); // Remove loading dialog
        ScaffoldMessenger.of(
          currentContext,
        ).showSnackBar(const SnackBar(content: Text('Failed to switch role')));
      }
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? trailing,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(icon, size: 24, color: const Color(0xFF616161)),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF212121),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    trailing,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFBDBDBD),
              ),
            ],
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
          ),
      ],
    );
  }
}
