import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/screens/home/add_saved_place_page.dart';
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
      if (userId != null) {
        // Load profile
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .single();

        print('Profile data loaded: $profileResponse');

        // Load saved places
        final placesResponse = await Supabase.instance.client
            .from('saved_places')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            // Try both full_name and name fields
            _userName = profileResponse['full_name'] ??
                       profileResponse['name'] ??
                       'User';
            _userEmail = profileResponse['phone'] ??
                        profileResponse['phone_number'];
            _userRating = (profileResponse['rating'] as num?)?.toDouble() ?? 0.0;
            _savedPlaces = List<Map<String, dynamic>>.from(placesResponse);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
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
        print('Error refreshing saved places: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 40), // Top spacing to bring profile down

                    // PROFILE HEADER (NON-TAPPABLE)
                    _buildProfileHeader(),

                    const SizedBox(height: 8),

                    // SECTION 1: SETTINGS (NO FAMILY PROFILE)
                  Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person_outline,
                          title: 'Personal info',
                          onTap: () {
                            // Navigate to personal info
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.shield_outlined,
                          title: 'Safety',
                          onTap: () {
                            // Navigate to safety
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
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // SECTION 3: SAVED PLACES
                  _buildSavedPlacesSection(),

                  const SizedBox(height: 8),

                  // SECTION 4: PREFERENCES
                  Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.language,
                          title: 'Language',
                          trailing: 'English-GB',
                          onTap: () {
                            // Navigate to language selection
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'Communication preferences',
                          onTap: () {
                            // Navigate to communication preferences
                          },
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // SECTION 5: ACCOUNT ACTIONS
                  Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
                                content: const Text('Are you sure you want to log out?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await Supabase.instance.client.auth.signOut();
                                      if (context.mounted) {
                                        Navigator.of(context).pushNamedAndRemoveUntil(
                                          '/auth_wrapper',
                                          (route) => false,
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Log out',
                                      style: TextStyle(color: Color(0xFFF44336)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 5: BECOME A DRIVER BANNER
                  if (_showDriverBanner) _buildDriverBanner(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Avatar (NON-TAPPABLE)
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFF5F5F5),
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 12),

          // Username
          Text(
            _userName ?? 'User',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF212121),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // Rating
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _userRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700, // Bold number
                    color: Color(0xFF212121),
                  ),
                ),
                const TextSpan(
                  text: ' Rating',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400, // Regular text
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
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
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 12),
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
                    builder: (context) => AddSavedPlacePage(
                      existingPlace: place,
                    ),
                  ),
                ).then((_) => _refreshSavedPlaces());
              },
            ),
            // Delete this place
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFF44336)),
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
      print('Error deleting place: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete place')),
        );
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconData,
              size: 24,
              color: const Color(0xFF757575),
            ),
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
        child: Icon(
          Icons.add,
          size: 24,
          color: Color(0xFF2196F3),
        ),
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
          MaterialPageRoute(
            builder: (context) => const AddSavedPlacePage(),
          ),
        );

        // Refresh saved places if a place was added
        if (result == true) {
          _refreshSavedPlaces();
        }
      },
    );
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(
            icon,
            size: 24,
            color: const Color(0xFF616161),
          ),
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

  Widget _buildDriverBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
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
              child: const Icon(
                Icons.close,
                size: 20,
                color: Color(0xFF757575),
              ),
            ),
          ),

          // Banner content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Become a driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Earn money on your schedule',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF616161),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
