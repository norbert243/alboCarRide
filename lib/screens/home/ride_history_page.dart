import 'package:flutter/material.dart';
import 'package:albocarride/services/session_service.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = true;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _loadRideHistory();
  }

  Future<void> _loadRideHistory() async {
    setState(() => _isLoading = true);

    try {
      _customerId = await SessionService.getUserId();

      if (_customerId != null) {
        // In a real implementation, this would query the ride_requests table
        // For demo purposes, we'll use sample data
        await Future.delayed(const Duration(seconds: 1)); // Simulate loading

        setState(() {
          _rideHistory = [
            {
              'id': '1',
              'pickup_location': '123 Main Street',
              'dropoff_location': 'Downtown Mall',
              'driver_name': 'John Smith',
              'fare': 15.50,
              'status': 'completed',
              'date': '2024-01-15 14:30',
              'rating': 4.5,
            },
            {
              'id': '2',
              'pickup_location': 'Airport Terminal A',
              'dropoff_location': 'City Center Hotel',
              'driver_name': 'Sarah Johnson',
              'fare': 32.75,
              'status': 'completed',
              'date': '2024-01-12 09:15',
              'rating': 5.0,
            },
            {
              'id': '3',
              'pickup_location': 'University Campus',
              'dropoff_location': 'Train Station',
              'driver_name': 'Mike Davis',
              'fare': 12.25,
              'status': 'completed',
              'date': '2024-01-10 16:45',
              'rating': 4.0,
            },
            {
              'id': '4',
              'pickup_location': 'Shopping Mall',
              'dropoff_location': 'Home Address',
              'driver_name': 'Lisa Brown',
              'fare': 18.90,
              'status': 'completed',
              'date': '2024-01-08 19:20',
              'rating': 4.8,
            },
          ];
        });
      }
    } catch (e) {
      print('Error loading ride history: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final status = ride['status'];
    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'cancelled'
        ? Colors.red
        : Colors.orange;

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
                  'Driver: ${ride['driver_name']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  ride['rating'].toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_rideHistory.length} Completed Rides',
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
    );
  }
}
