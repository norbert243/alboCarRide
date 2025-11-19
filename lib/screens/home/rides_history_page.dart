import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:intl/intl.dart';

/// Rides History screen with Past and Upcoming tabs (Bolt style)
class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pastRides = [];
  List<Map<String, dynamic>> _upcomingRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);

    try {
      final userId = await SessionService.getUserIdStatic();
      if (userId != null) {
        // Load past rides (completed trips)
        final pastResponse = await Supabase.instance.client
            .from('trips')
            .select()
            .eq('customer_id', userId)
            .eq('status', 'completed')
            .order('created_at', ascending: false)
            .limit(50);

        // Load upcoming rides (scheduled for future - if you implement scheduling)
        // For now, we'll just show empty
        final upcomingResponse = <Map<String, dynamic>>[];

        if (mounted) {
          setState(() {
            _pastRides = List<Map<String, dynamic>>.from(pastResponse);
            _upcomingRides = upcomingResponse;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading rides: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRideDate(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      return DateFormat('d MMM · HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }

  String _getMonthYear(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupRidesByMonth(
      List<Map<String, dynamic>> rides) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var ride in rides) {
      final monthYear = _getMonthYear(ride['created_at'] ?? '');
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(ride);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Rides',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              size: 24,
              color: Color(0xFF757575),
            ),
            onPressed: () {
              // Show info dialog
            },
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2196F3),
                indicatorWeight: 3,
                labelColor: const Color(0xFF2196F3),
                unselectedLabelColor: const Color(0xFF757575),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Past'),
                  Tab(text: 'Upcoming'),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPastRidesTab(),
                _buildUpcomingRidesTab(),
              ],
            ),
    );
  }

  Widget _buildPastRidesTab() {
    if (_pastRides.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No rides yet',
        subtitle: 'Your ride history will appear here',
      );
    }

    final groupedRides = _groupRidesByMonth(_pastRides);

    return RefreshIndicator(
      onRefresh: _loadRides,
      color: const Color(0xFF2196F3),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groupedRides.length,
        itemBuilder: (context, index) {
          final monthYear = groupedRides.keys.elementAt(index);
          final rides = groupedRides[monthYear]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 20,
                  bottom: 12,
                ),
                color: const Color(0xFFFAFAFA),
                child: Text(
                  monthYear,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
              ),

              // Rides in this month
              ...rides.map((ride) => _buildRideCard(ride)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUpcomingRidesTab() {
    if (_upcomingRides.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_outlined,
        title: 'No upcoming rides',
        subtitle: 'Schedule a ride for later from the home screen',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcomingRides.length,
      itemBuilder: (context, index) => _buildRideCard(_upcomingRides[index]),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final destination = ride['dropoff_location'] ?? 'Unknown destination';
    final price = ride['final_price'] ?? ride['proposed_price'] ?? 0.0;
    final dateTime = _formatRideDate(ride['created_at'] ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          // Car icon
          Icon(
            Icons.directions_car,
            size: 32,
            color: Colors.grey[600],
          ),

          const SizedBox(width: 16),

          // Ride details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time
                Text(
                  dateTime,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF616161),
                  ),
                ),

                const SizedBox(height: 4),

                // Destination
                Text(
                  destination,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF212121),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Price
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),

          // Repeat button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh,
                size: 20,
                color: Color(0xFF757575),
              ),
              onPressed: () {
                // Rebook this ride
                // Navigate to home and pre-fill destination
              },
              tooltip: 'Book again',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 120,
              color: const Color(0xFFBDBDBD),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
