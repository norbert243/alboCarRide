import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ride_matching_service.dart';
import '../services/session_service.dart';
import 'custom_toast.dart';

/// Widget that displays ride offers and allows drivers to manage them
class OfferBoard extends StatefulWidget {
  const OfferBoard({super.key});

  @override
  State<OfferBoard> createState() => _OfferBoardState();
}

class _OfferBoardState extends State<OfferBoard> {
  final RideMatchingService _matchingService = RideMatchingService();
  late Stream<List<Map<String, dynamic>>> _offersStream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    String? driverId;
    try {
      driverId = await SessionService.getUserIdStatic();
    } catch (e) {
      driverId = null;
    }

    if (driverId != null) {
      // Start the matching service to listen for offers
      await _matchingService.startMatchingService();

      // Subscribe to offers stream (this would need to be implemented in RideMatchingService)
      _offersStream = _watchPendingOffers(driverId);
    } else {
      _offersStream = Stream.value([]);
    }
  }

  /// Watch pending offers for a driver
  Stream<List<Map<String, dynamic>>> _watchPendingOffers(String driverId) {
    return _matchingService.supabaseClient
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .map(
          (events) => events
              .where(
                (offer) =>
                    offer['driver_id'] == driverId &&
                    offer['status'] == 'pending',
              )
              .toList(),
        );
  }

  Future<void> _handleAcceptOffer(Map<String, dynamic> offer) async {
    setState(() => _isLoading = true);
    try {
      await _matchingService.acceptOffer(offer['id'] as String);
      CustomToast.showSuccess(
        context: context,
        message: 'Offer accepted successfully! Trip created.',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to accept offer: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRejectOffer(Map<String, dynamic> offer) async {
    setState(() => _isLoading = true);
    try {
      await _matchingService.supabaseClient
          .from('ride_offers')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', offer['id']);
      CustomToast.showInfo(context: context, message: 'Offer rejected');
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to reject offer: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCounterOffer(
    Map<String, dynamic> offer,
    double counterPrice,
  ) async {
    if (counterPrice <= 0) {
      CustomToast.showError(
        context: context,
        message: 'Please enter a valid price',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _matchingService.supabaseClient
          .from('ride_offers')
          .update({
            'offer_price': counterPrice,
            'status': 'countered',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', offer['id']);
      CustomToast.showSuccess(context: context, message: 'Counter offer sent!');
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to send counter offer: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCounterDialog(Map<String, dynamic> offer) {
    final proposedPrice = (offer['offer_price'] as num).toDouble();
    final priceController = TextEditingController(
      text: (proposedPrice * 1.1).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Counter Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Original offer: \$${proposedPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your counter price',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null) {
                Navigator.pop(context);
                _handleCounterOffer(offer, price);
              } else {
                CustomToast.showError(
                  context: context,
                  message: 'Please enter a valid price',
                );
              }
            },
            child: const Text('Send Counter'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${(offer['offer_price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Chip(
                  label: Text(
                    (offer['status'] as String).toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.orange[100],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // These fields would need to be joined from ride_requests table
            _buildInfoRow(Icons.location_on, 'Pickup:', 'Loading...'),
            _buildInfoRow(Icons.flag, 'Destination:', 'Loading...'),
            _buildInfoRow(
              Icons.access_time,
              'Received:',
              _formatTimeAgo(DateTime.parse(offer['created_at'] as String)),
            ),
            const SizedBox(height: 16),
            if (!_isLoading) _buildActionButtons(offer),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> offer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton(
          onPressed: () => _handleAcceptOffer(offer),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Accept'),
        ),
        OutlinedButton(
          onPressed: () => _showCounterDialog(offer),
          child: const Text('Counter'),
        ),
        TextButton(
          onPressed: () => _handleRejectOffer(offer),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Reject'),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No ride offers yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Ride offers will appear here when customers request your service',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SessionService.getUserIdStatic(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final driverId = snapshot.data;
        if (driverId == null) {
          return const Center(child: Text('Please log in to view ride offers'));
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _offersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final offers = snapshot.data ?? [];

            if (offers.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Force refresh by re-initializing the stream
                setState(() {
                  _offersStream = _watchPendingOffers(driverId);
                });
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: offers.length,
                itemBuilder: (context, index) => _buildOfferCard(offers[index]),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _matchingService.dispose();
    super.dispose();
  }
}
