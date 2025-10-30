import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/eta_service.dart';

/// Real-time ETA display widget for driver-side trip tracking
class DriverEtaWidget extends StatefulWidget {
  final String tripId;
  final String driverId;
  final bool showNotifications;
  final Duration refreshInterval;

  const DriverEtaWidget({
    Key? key,
    required this.tripId,
    required this.driverId,
    this.showNotifications = true,
    this.refreshInterval = const Duration(seconds: 15),
  }) : super(key: key);

  @override
  State<DriverEtaWidget> createState() => _DriverEtaWidgetState();
}

class _DriverEtaWidgetState extends State<DriverEtaWidget> {
  final EtaService _etaService = EtaService();
  final SupabaseClient _client = Supabase.instance.client;
  
  Map<String, dynamic>? _etaData;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  StreamSubscription<Map<String, dynamic>>? _driverLocationSubscription;
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 DriverEtaWidget: Initializing for trip ${widget.tripId}');
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
      debugPrint('📍 DriverEtaWidget: Driver location updated');
      _fetchEta(); // Recalculate ETA on location change
    });

    // Subscribe to trip status changes
    _tripSubscription = _etaService
        .subscribeToTrip(widget.tripId)
        .listen((tripUpdate) {
      debugPrint('🔄 DriverEtaWidget: Trip status updated - ${tripUpdate['status']}');
      _fetchEta(); // Recalculate ETA on status change
    });
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

        // Send notification to rider if ETA is available
        if (widget.showNotifications && 
            etaData?['status'] == 'ok' && 
            etaData?['eta_minutes'] != null) {
          final etaMinutes = etaData?['eta_minutes'] as int;
          await _etaService.notifyRiderEta(widget.tripId, etaMinutes);
        }

        debugPrint('✅ DriverEtaWidget: ETA updated - ${etaData?['eta_minutes']} min');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
      debugPrint('❌ DriverEtaWidget: Failed to fetch ETA - $e');
    }
  }

  String _formatEta(int? minutes) {
    if (minutes == null) return '--';
    if (minutes < 1) return '< 1 min';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Calculating ETA...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'ETA Unavailable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.red,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _fetchEta,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'ETA Not Available',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Location data required for ETA calculation',
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Estimated Arrival',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _fetchEta,
                icon: const Icon(Icons.refresh, size: 18),
                color: Colors.green[700],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // ETA and Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatEta(etaMinutes),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ETA',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDistance(distanceMeters),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Distance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress indicator
          LinearProgressIndicator(
            value: etaMinutes != null ? (1.0 - (etaMinutes / 60.0)).clamp(0.0, 1.0) : 0.0,
            backgroundColor: Colors.green[100],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          
          const SizedBox(height: 8),
          
          // Last updated and location info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Updated: ${DateTime.now().toString().substring(11, 16)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              if (driverLat != null && driverLng != null)
                Text(
                  '📍 ${driverLat.toStringAsFixed(4)}, ${driverLng.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          
          // Notification status
          if (widget.showNotifications && etaMinutes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.notifications_active, 
                    color: Colors.green[700], size: 14),
                const SizedBox(width: 4),
                Text(
                  'Rider notified: $etaMinutes min',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildEtaContent(),
    );
  }

  @override
  void dispose() {
    debugPrint('🧹 DriverEtaWidget: Disposing resources');
    _refreshTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _tripSubscription?.cancel();
    super.dispose();
  }
}