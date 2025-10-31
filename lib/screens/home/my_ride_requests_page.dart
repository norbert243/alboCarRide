import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'dart:async';

/// Page showing customer's active ride requests with driver offers (inDrive-style)
class MyRideRequestsPage extends StatefulWidget {
  const MyRideRequestsPage({super.key});

  @override
  State<MyRideRequestsPage> createState() => _MyRideRequestsPageState();
}

class _MyRideRequestsPageState extends State<MyRideRequestsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rideRequests = [];
  bool _isLoading = false;
  String? _customerId;
  StreamSubscription? _offersSubscription;

  @override
  void initState() {
    super.initState();
    _loadRideRequests();
    _subscribeToOfferUpdates();
  }

  @override
  void dispose() {
    if (_offersSubscription != null) {
      _supabase.removeChannel(_offersSubscription as RealtimeChannel);
    }
    super.dispose();
  }

  Future<void> _loadRideRequests() async {
    setState(() => _isLoading = true);

    try {
      _customerId = await SessionService.getUserIdStatic();

      if (_customerId != null) {
        // Get all active ride requests
        final requestsResponse = await _supabase
            .from('ride_requests')
            .select('*')
            .eq('customer_id', _customerId!)
            .inFilter('status', ['pending', 'offered'])
            .order('created_at', ascending: false);

        final requests = requestsResponse as List<dynamic>;

        // For each request, get any offers from drivers
        List<Map<String, dynamic>> requestsWithOffers = [];
        for (var request in requests) {
          final offersResponse = await _supabase
              .from('ride_offers')
              .select('''
                id,
                driver_id,
                offer_price,
                status,
                created_at,
                profiles!ride_offers_driver_id_fkey(full_name, rating)
              ''')
              .eq('ride_request_id', request['id'])
              .inFilter('status', ['pending', 'countered'])
              .order('created_at', ascending: false);

          final offers = offersResponse as List<dynamic>;

          requestsWithOffers.add({
            'request': request,
            'offers': offers,
          });
        }

        setState(() {
          _rideRequests = requestsWithOffers;
        });
      }
    } catch (e) {
      print('Error loading ride requests: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to load ride requests',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToOfferUpdates() async {
    _customerId = await SessionService.getUserIdStatic();
    if (_customerId == null) return;

    // Subscribe to ride_offers changes for real-time updates
    final channel = _supabase.channel('ride_offers_updates');
    _offersSubscription = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_offers',
          callback: (payload) {
            _loadRideRequests();
          },
        ).subscribe() as StreamSubscription?;
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer, Map<String, dynamic> request) async {
    setState(() => _isLoading = true);

    try {
      // Create trip from the accepted offer
      final tripResponse = await _supabase.from('trips').insert({
        'customer_id': _customerId,
        'driver_id': offer['driver_id'],
        'pickup_location': request['pickup_location'],
        'dropoff_location': request['dropoff_location'],
        'final_price': offer['offer_price'],
        'status': 'accepted',
        'start_time': DateTime.now().toIso8601String(),
      }).select();

      if (tripResponse.isNotEmpty) {
        // Update offer status
        await _supabase
            .from('ride_offers')
            .update({'status': 'accepted'})
            .eq('id', offer['id']);

        // Update ride request status
        await _supabase
            .from('ride_requests')
            .update({'status': 'accepted'})
            .eq('id', request['id']);

        CustomToast.showSuccess(
          context: context,
          message: 'Offer accepted! Your driver is on the way.',
        );

        // Reload requests
        await _loadRideRequests();
      }
    } catch (e) {
      print('Error accepting offer: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to accept offer: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectOffer(Map<String, dynamic> offer) async {
    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('ride_offers')
          .update({'status': 'rejected'})
          .eq('id', offer['id']);

      CustomToast.showInfo(
        context: context,
        message: 'Offer rejected',
      );

      await _loadRideRequests();
    } catch (e) {
      print('Error rejecting offer: $e');
      CustomToast.showError(
        context: context,
        message: 'Failed to reject offer',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride Request'),
        content: const Text('Are you sure you want to cancel this ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        await _supabase
            .from('ride_requests')
            .update({'status': 'cancelled'})
            .eq('id', request['id']);

        CustomToast.showInfo(
          context: context,
          message: 'Ride request cancelled',
        );

        await _loadRideRequests();
      } catch (e) {
        print('Error cancelling request: $e');
        CustomToast.showError(
          context: context,
          message: 'Failed to cancel request',
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _formatTimeAgo(String createdAt) {
    final now = DateTime.now();
    final dateTime = DateTime.parse(createdAt);
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, Map<String, dynamic> request) {
    final driverProfile = offer['profiles'] as Map<String, dynamic>?;
    final driverName = driverProfile?['full_name'] ?? 'Unknown Driver';
    final driverRating = (driverProfile?['rating'] as num?)?.toDouble() ?? 0.0;
    final offerPrice = (offer['offer_price'] as num).toDouble();
    final yourPrice = (request['suggested_price'] as num?)?.toDouble() ??
        (request['estimated_fare'] as num?)?.toDouble() ??
        0.0;

    final priceDifference = offerPrice - yourPrice;
    final isCounterOffer = offer['status'] == 'countered';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCounterOffer ? Colors.orange : Colors.green,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              driverRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${offerPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isCounterOffer ? Colors.orange : Colors.green,
                        ),
                      ),
                      if (priceDifference != 0)
                        Text(
                          '${priceDifference > 0 ? '+' : ''}\$${priceDifference.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: priceDifference > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isCounterOffer)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.swap_horiz,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Counter-offer from driver (Your price: \$${yourPrice.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Received ${_formatTimeAgo(offer['created_at'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _acceptOffer(offer, request),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _rejectOffer(offer),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data) {
    final request = data['request'] as Map<String, dynamic>;
    final offers = data['offers'] as List<dynamic>;

    final yourPrice = (request['suggested_price'] as num?)?.toDouble() ??
        (request['estimated_fare'] as num?)?.toDouble() ??
        0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Ride Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your price: \$${yourPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    offers.isEmpty ? 'Waiting' : '${offers.length} Offer${offers.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.location_on_outlined,
              'From',
              request['pickup_location'],
            ),
            _buildLocationRow(
              Icons.flag_outlined,
              'To',
              request['dropoff_location'],
            ),
            if (request['notes'] != null && (request['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request['notes'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Requested ${_formatTimeAgo(request['created_at'])}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (offers.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_empty,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Waiting for drivers to respond...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (offers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Driver Offers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...offers.map((offer) => _buildOfferCard(offer, request)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _cancelRequest(request),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String location) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: location),
                ],
              ),
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
          'My Ride Requests',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading && _rideRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _rideRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Active Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Book a ride to see requests here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Book a Ride'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRideRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rideRequests.length,
                    itemBuilder: (context, index) =>
                        _buildRequestCard(_rideRequests[index]),
                  ),
                ),
    );
  }
}
