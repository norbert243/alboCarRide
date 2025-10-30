import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverDashboardV2 extends StatefulWidget {
  final String driverId;
  const DriverDashboardV2({super.key, required this.driverId});

  @override
  State<DriverDashboardV2> createState() => _DriverDashboardV2State();
}

class _DriverDashboardV2State extends State<DriverDashboardV2> {
  Map<String, dynamic>? dashboardData;
  Timer? refreshTimer;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchDashboard();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    setState(() => loading = true);
    try {
      final response = await Supabase.instance.client
          .rpc('get_driver_dashboard', params: {'p_driver_id': widget.driverId});
      setState(() => dashboardData = response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('⚠️ Dashboard fetch failed: $e');
      // Provide fallback data when RPC fails
      setState(() {
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
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = dashboardData;
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Dashboard v2')),
      body: loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _metric('Driver ID', d?['driver_id']),
                  _metric('Wallet Balance', 'R ${d?['wallet_balance'] ?? 0}'),
                  _metric('Rating', d?['rating']),
                  _metric('Completed Trips', d?['completed_trips']),
                  _metric('Today Earnings', 'R ${d?['today_earnings'] ?? 0}'),
                  _metric('Weekly Earnings', 'R ${d?['weekly_earnings'] ?? 0}'),
                  if (d != null && d['recent_trips'] != null && (d['recent_trips'] as List).isNotEmpty)
                    _metric('Recent Trips', '${(d['recent_trips'] as List).length}'),
                ],
              ),
            ),
    );
  }

  Widget _metric(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: SizedBox(
          width: 80,
          child: Text(
            value?.toString() ?? '-',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  }
}