import 'package:flutter/material.dart';
import 'package:albocarride/services/connectivity_service.dart';

class ErrorScreen extends StatefulWidget {
  final FlutterErrorDetails? errorDetails;
  final String? error;
  final bool isOfflineError;

  const ErrorScreen({
    super.key,
    this.errorDetails,
    this.error,
    this.isOfflineError = false,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);

    final isOnline = await ConnectivityService.instance.checkConnectivity();

    if (isOnline) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth_wrapper');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still offline. Please check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.isOfflineError ||
        widget.error?.toLowerCase().contains('network') == true ||
        widget.error?.toLowerCase().contains('connection') == true ||
        widget.error?.toLowerCase().contains('socket') == true;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isOffline ? 'No Connection' : 'Error'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? Icons.wifi_off : Icons.error_outline,
                color: isOffline ? Colors.orange : Colors.red,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                isOffline ? 'No Internet Connection' : 'Oops! Something went wrong.',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isOffline
                    ? 'Please check your internet connection and try again.'
                    : widget.errorDetails?.exceptionAsString() ??
                        widget.error ??
                        'An unknown error occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              if (isOffline) ...[
                // Offline-specific tips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Troubleshooting Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip('Check if Wi-Fi or mobile data is enabled'),
                      _buildTip('Try moving to an area with better signal'),
                      _buildTip('Restart your router or modem'),
                      _buildTip('Toggle airplane mode on and off'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRetrying ? null : _retry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isRetrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isOffline ? 'Try Again' : 'Go to Home'),
                ),
              ),
              if (!isOffline) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/support'),
                  child: const Text('Contact Support'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline page shown when there's no connectivity
class OfflinePage extends StatefulWidget {
  final VoidCallback? onRetry;

  const OfflinePage({super.key, this.onRetry});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  bool _isRetrying = false;

  Future<void> _checkConnection() async {
    setState(() => _isRetrying = true);

    final isOnline = await ConnectivityService.instance.checkConnectivity();

    if (isOnline) {
      widget.onRetry?.call();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still offline. Please check your connection.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 100,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please check your connection and try again.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _checkConnection,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isRetrying ? 'Checking...' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
