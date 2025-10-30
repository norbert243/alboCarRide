import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/eta_service.dart';

/// ETA display widget for rider-side trip tracking
class RiderEtaWidget extends StatefulWidget {
  final String tripId;
  final String driverId;
  final Duration refreshInterval;

  const RiderEtaWidget({
    Key? key,
    required this.tripId,
    required this.driverId,
    this.refreshInterval = const Duration(seconds: 15),
  }) : super(key: key);

  @override
  State<RiderEtaWidget> createState() => _RiderEtaWidgetState();
}

class _RiderEtaWidgetState extends State<RiderEtaWidget> {
  final EtaService _etaService = EtaService();
  final SupabaseClient _client = Supabase.instance.client;
  
  Map<String, dynamic>? _etaData;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  StreamSubscription<Map<String, dynamic>>? _driverLocationSubscription;
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 RiderEtaWidget: Initializing for trip ${widget.tripId}');
    _initializeEtaSystem();
  }

  void _initializeEtaSystem() {
    _startAutoRefresh();
    _subscribeToRealTimeUpdates();
    _fetchInitialEta();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      _fetchEta();
    });
  }

  void _subscribeToRealTimeUpdates() {
    // Subscribe to driver location changes
    _driverLocationSubscription = _etaService
        .subscribeToDriverLocation(widget.driverId)
        .listen((location) {
      debugPrint('📍 RiderEtaWidget: Driver location updated');
      _fetchEta(); // Recalculate ETA on location change
    });

    // Subscribe to trip status changes
    _tripSubscription = _etaService
        .subscribeToTrip(widget.tripId)
        .listen((tripUpdate) {
      debugPrint('🔄 RiderEtaWidget: Trip status updated - ${tripUpdate['status']}');
      _fetchEta(); // Recalculate ETA on status change
    });

    // Subscribe to notifications for this rider
    final userId = _client.auth.currentUser?.id ?? '';
    if (userId.isNotEmpty) {
      _notificationSubscription = _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .listen((notifications) {
        // Filter notifications for this user and ride_update type
        final relevantNotifications = notifications.where((notification) =>
            notification['user_id'] == userId &&
            notification['type'] == 'ride_update');
        
        if (relevantNotifications.isNotEmpty) {
          debugPrint('🔔 RiderEtaWidget: New notification received');
          // Refresh ETA when new notification arrives
          _fetchEta();
        }
      });
    }
  }

  Future<void> _fetchInitialEta() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _fetchEta();
  }

  Future<void> _fetchEta() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final etaData = await _etaService.calculateEta(widget.tripId);
      
      if (mounted) {
        setState(() {
          _etaData = etaData;
          _isLoading = false;
        });
        debugPrint('✅ RiderEtaWidget: ETA updated - ${etaData?['eta_minutes']} min');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
      debugPrint('❌ RiderEtaWidget: Failed to fetch ETA - $e');
    }
  }

  String _formatEta(int? minutes) {
    if (minutes == null) return '--';
    if (minutes < 1) return 'Arriving now';
    if (minutes == 1) return '1 minute';
    return '$minutes minutes';
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.round()} meters away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Widget _buildEtaContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_etaData?['status'] != 'ok') {
      return _buildNoDataState();
    }

    return _buildEtaDisplay();
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Calculating ETA...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tracking driver location',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 40),
          const SizedBox(height: 16),
          const Text(
            'ETA Unavailable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchEta,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule, color: Colors.orange[700], size: 40),
          const SizedBox(height: 16),
          const Text(
            'ETA Not Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Waiting for driver location data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEtaDisplay() {
    final etaMinutes = _etaData?['eta_minutes'] as int?;
    final distanceMeters = _etaData?['distance_m'] as double?;
    final driverLat = _etaData?['driver_lat'];
    final driverLng = _etaData?['driver_lng'];

    // Determine status color based on ETA
    Color statusColor;
    if (etaMinutes == null) {
      statusColor = Colors.grey;
    } else if (etaMinutes <= 5) {
      statusColor = Colors.green;
    } else if (etaMinutes <= 15) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with driver icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_car,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Driver ETA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Main ETA display
          Text(
            _formatEta(etaMinutes),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Distance information
          Text(
            _formatDistance(distanceMeters),
            style: TextStyle(
              fontSize: 16,
              color: statusColor.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Progress indicator
          LinearProgressIndicator(
            value: etaMinutes != null ? (1.0 - (etaMinutes / 60.0)).clamp(0.0, 1.0) : 0.0,
            backgroundColor: statusColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          
          const SizedBox(height: 12),
          
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              _getStatusText(etaMinutes),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Additional information
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.update, color: statusColor.withOpacity(0.7), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Updated: ${DateTime.now().toString().substring(11, 16)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              
              if (driverLat != null && driverLng != null)
                Row(
                  children: [
                    Icon(Icons.location_on, color: statusColor.withOpacity(0.7), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Driver location active',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Auto-refresh indicator
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.autorenew, color: statusColor.withOpacity(0.5), size: 12),
              const SizedBox(width: 4),
              Text(
                'Auto-refreshing every 15s',
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusText(int? etaMinutes) {
    if (etaMinutes == null) return 'Calculating...';
    if (etaMinutes <= 2) return 'Arriving soon!';
    if (etaMinutes <= 5) return 'Very close';
    if (etaMinutes <= 10) return 'On the way';
    if (etaMinutes <= 20) return 'En route';
    return 'Heading your way';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _buildEtaContent(),
    );
  }

  @override
  void dispose() {
    debugPrint('🧹 RiderEtaWidget: Disposing resources');
    _refreshTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _tripSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }
}