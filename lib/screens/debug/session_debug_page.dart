import 'package:flutter/material.dart';
import 'package:albocarride/services/session_debug_service.dart';
import 'package:albocarride/services/session_service.dart';

class SessionDebugPage extends StatefulWidget {
  const SessionDebugPage({super.key});

  @override
  State<SessionDebugPage> createState() => _SessionDebugPageState();
}

class _SessionDebugPageState extends State<SessionDebugPage> {
  String _debugReport = 'Loading...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDebugReport();
  }

  Future<void> _loadDebugReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await SessionDebugService.getDebugReport();
      setState(() => _debugReport = report);
    } catch (e) {
      setState(() => _debugReport = 'Error loading debug report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceSessionSync() async {
    setState(() => _isLoading = true);
    try {
      await SessionDebugService.forceSessionSync();
      await _loadDebugReport();
      _showSnackBar('Session synchronization completed');
    } catch (e) {
      _showSnackBar('Error synchronizing sessions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllSessions() async {
    setState(() => _isLoading = true);
    try {
      await SessionDebugService.clearAllSessions();
      await _loadDebugReport();
      _showSnackBar('All sessions cleared');
    } catch (e) {
      _showSnackBar('Error clearing sessions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkSessionValidity() async {
    setState(() => _isLoading = true);
    try {
      final isValid = await SessionService.hasValidSession();
      _showSnackBar('Session validity: $isValid');
      await _loadDebugReport();
    } catch (e) {
      _showSnackBar('Error checking session validity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Debug'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Buttons
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _forceSessionSync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Force Sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkSessionValidity,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Check Validity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _clearAllSessions,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Debug Report
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: SelectableText(
                            _debugReport,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Quick Status
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: SessionDebugService.debugSessionStatus(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    final data = snapshot.data!;
                    final validity =
                        data['session_validity'] as Map<String, dynamic>;

                    return Row(
                      children: [
                        Icon(
                          validity['sessions_synced'] as bool
                              ? Icons.check_circle
                              : Icons.error,
                          color: validity['sessions_synced'] as bool
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                validity['sessions_synced'] as bool
                                    ? 'Sessions Synced'
                                    : 'Sessions Not Synced',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Local: ${validity['local_session_valid'] ? "Valid" : "Invalid"} | '
                                'Supabase: ${validity['supabase_session_valid'] ? "Valid" : "Invalid"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
