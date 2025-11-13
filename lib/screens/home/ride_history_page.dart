import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/trip_service.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = true;
  String? _userId;
  String? _userRole;
  final TripService _tripService = TripService();

  @override
  void initState() {
    super.initState();
    _loadRideHistory();
  }

  Future<void> _loadRideHistory() async {
    setState(() => _isLoading = true);

    try {
      _userId = await SessionService.getUserIdStatic();
      _userRole = await SessionService.getUserRoleStatic();

      if (_userId != null) {
        // Query completed trips from the database
        final response = await Supabase.instance.client
            .from('trips')
            .select('''
              id,
              pickup_location,
              dropoff_location,
              final_price,
              status,
              start_time,
              end_time,
              driver_rating,
              driver_id,
              profiles!trips_driver_id_fkey(full_name)
            ''')
            .eq('customer_id', _userId!)
            .inFilter('status', ['completed', 'cancelled'])
            .order('end_time', ascending: false);

        final trips = response as List<dynamic>;

        setState(() {
          _rideHistory = trips.map((trip) {
            final driverProfile = trip['profiles'] as Map<String, dynamic>?;
            final driverName = driverProfile?['full_name'] ?? 'Unknown Driver';
            final fare = (trip['final_price'] as num?)?.toDouble() ?? 0.0;
            final rating = (trip['driver_rating'] as num?)?.toDouble() ?? 0.0;
            final endTime = trip['end_time'] != null
                ? DateTime.parse(trip['end_time'] as String)
                : DateTime.now();

            return {
              'id': trip['id'],
              'pickup_location': trip['pickup_location'] ?? 'Unknown pickup',
              'dropoff_location':
                  trip['dropoff_location'] ?? 'Unknown destination',
              'driver_name': driverName,
              'fare': fare,
              'status': trip['status'] ?? 'completed',
              'date': _formatDateTime(endTime),
              'rating': rating,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading ride history: $e');
      // Show empty state if there's an error
      setState(() {
        _rideHistory = [];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final status = ride['status'];
    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'cancelled'
        ? Colors.red
        : Colors.orange;

    final isCustomer = _userRole == 'customer' || _userRole == null;
    final otherPartyLabel = isCustomer ? 'Driver' : 'Customer';
    final otherPartyName = ride['other_party_name'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${ride['fare'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.location_on_outlined,
              'From: ${ride['pickup_location']}',
            ),
            _buildLocationRow(
              Icons.flag_outlined,
              'To: ${ride['dropoff_location']}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '$otherPartyLabel: $otherPartyName',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  ride['rating'] > 0 ? ride['rating'].toString() : 'No rating',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (isCustomer && ride['vehicle_info'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ride['vehicle_info'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  ride['date'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ride History',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rideHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Ride History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your completed rides will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRideHistory,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_rideHistory.length} ${_userRole == 'driver' ? 'Completed Trips' : 'Completed Rides'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._rideHistory.map(_buildRideCard),
                  ],
                ),
              ),
            ),
    );
  }
}
