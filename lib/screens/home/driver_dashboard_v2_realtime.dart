// lib/screens/home/driver_dashboard_v2_realtime.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _ConnState { unknown, connected, disconnected, reconnecting }

class DriverDashboardV2Realtime extends StatefulWidget {
  final String driverId;
  const DriverDashboardV2Realtime({super.key, required this.driverId});

  @override
  State<DriverDashboardV2Realtime> createState() => _DriverDashboardV2RealtimeState();
}

class _DriverDashboardV2RealtimeState extends State<DriverDashboardV2Realtime> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? dashboardData;
  bool loading = false;
  RealtimeChannel? _subscription;
  Timer? _debounceTimer;
  _ConnState _connState = _ConnState.unknown;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _subscribe();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _unsubscribe();
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    if (mounted) setState(() => loading = true);
    try {
      final response = await _sb.rpc('get_driver_dashboard', params: {'p_driver_id': widget.driverId});
      Map<String, dynamic>? parsed;
      if (response is Map<String, dynamic>) {
        parsed = response;
      } else if (response is List && response.isNotEmpty && response.first is Map<String, dynamic>) {
        parsed = Map<String, dynamic>.from(response.first);
      } else if (response != null) {
        parsed = Map<String, dynamic>.from(response);
      }
      if (mounted) setState(() => dashboardData = parsed);
    } catch (e, st) {
      debugPrint('Dashboard fetch failed: $e\n$st');
      // Provide fallback data when RPC fails
      if (mounted) setState(() {
        dashboardData = {
          'driver_id': widget.driverId,
          'wallet_balance': 0,
          'rating': 5.0,
          'completed_trips': 0,
          'today_earnings': 0,
          'weekly_earnings': 0,
          'recent_trips': [],
        };
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _scheduleRefreshDebounced([Duration delay = const Duration(milliseconds: 800)]) {
    // debounce rapid events
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (mounted) _fetchDashboard();
    });
  }

  void _subscribe() {
    try {
      final channelName = 'driver_state_events_${widget.driverId}';
      final channel = _sb.channel(channelName);

      // Remove existing same channel if any
      if (_subscription != null) {
        try {
          _sb.removeChannel(_subscription!);
        } catch (_) {}
      }

      // Listen for inserts and updates
      channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'driver_state_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: widget.driverId,
          ),
          callback: (payload) {
            debugPrint('Realtime insert: $payload');
            _scheduleRefreshDebounced();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_state_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: widget.driverId,
          ),
          callback: (payload) {
            debugPrint('Realtime update: $payload');
            _scheduleRefreshDebounced();
          },
        );

      _subscription = channel.subscribe();

      // optimistic set connected
      setState(() {
        _connState = _ConnState.connected;
        _reconnectAttempts = 0;
      });

      debugPrint('Subscribed to $channelName');
    } catch (e) {
      debugPrint('Subscribe failed: $e');
      setState(() {
        _connState = _ConnState.disconnected;
      });
      _attemptReconnect();
    }
  }

  void _unsubscribe() {
    if (_subscription != null) {
      try {
        _sb.removeChannel(_subscription!);
        debugPrint('Unsubscribed from channel');
      } catch (e) {
        debugPrint('Unsubscribe error: $e');
      }
      _subscription = null;
    }
  }

  void _attemptReconnect() {
    if (_reconnectAttempts > 5) return;
    _reconnectAttempts++;
    setState(() => _connState = _ConnState.reconnecting);
    Future.delayed(Duration(seconds: 2 * _reconnectAttempts), () {
      if (!mounted) return;
      try {
        _subscribe();
      } catch (e) {
        debugPrint('Re-subscribe attempt failed: $e');
        _attemptReconnect();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = dashboardData;
    final connLabel = {
      _ConnState.unknown: 'Unknown',
      _ConnState.connected: 'Connected',
      _ConnState.disconnected: 'Disconnected',
      _ConnState.reconnecting: 'Reconnecting'
    }[_connState];
    final connColor = {
      _ConnState.unknown: Colors.grey,
      _ConnState.connected: Colors.green,
      _ConnState.disconnected: Colors.red,
      _ConnState.reconnecting: Colors.orange
    }[_connState];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // connection chip
        Align(
          alignment: Alignment.topRight,
          child: Chip(
            backgroundColor: connColor!.withAlpha(30),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 14, color: connColor),
                const SizedBox(width: 6),
                Text(connLabel!, style: TextStyle(color: connColor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // existing metrics (use the keys you confirmed)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: const Text('Driver ID', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: SizedBox(
              width: 120,
              child: Text(
                d?['driver_id']?.toString() ?? widget.driverId,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: const Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: SizedBox(
              width: 80,
              child: Text(
                'R ${d?['wallet_balance'] ?? 0}',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: SizedBox(
              width: 40,
              child: Text(
                d?['rating']?.toString() ?? '-',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: const Text('Completed Trips', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: SizedBox(
              width: 40,
              child: Text(
                d?['completed_trips']?.toString() ?? '0',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: const Text('Today Earnings', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: SizedBox(
              width: 80,
              child: Text(
                'R ${d?['today_earnings'] ?? 0}',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: const Text('Weekly Earnings', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: SizedBox(
              width: 80,
              child: Text(
                'R ${d?['weekly_earnings'] ?? 0}',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
        if (d != null && d['recent_trips'] != null && (d['recent_trips'] as List).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: const Text('Recent Trips', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: SizedBox(
                width: 40,
                child: Text(
                  '${(d['recent_trips'] as List).length}',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            _scheduleRefreshDebounced(Duration(milliseconds: 0));
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Force refresh'),
        ),
        ],
      ),
    );
  }
}