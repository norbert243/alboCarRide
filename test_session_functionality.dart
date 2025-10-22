import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:albocarride/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // Initialize Auth Service
  await AuthService.initialize();
  
  runApp(const SessionTestApp());
}

class SessionTestApp extends StatelessWidget {
  const SessionTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Session Test')),
        body: const SessionTestWidget(),
      ),
    );
  }
}

class SessionTestWidget extends StatefulWidget {
  const SessionTestWidget({super.key});

  @override
  State<SessionTestWidget> createState() => _SessionTestWidgetState();
}

class _SessionTestWidgetState extends State<SessionTestWidget> {
  String _status = 'Testing...';
  Map<String, dynamic>? _sessionData;

  @override
  void initState() {
    super.initState();
    _testSession();
  }

  Future<void> _testSession() async {
    try {
      // Test 1: Check if session exists
      final isLoggedIn = await SessionService.isLoggedIn();
      _updateStatus('Session exists: $isLoggedIn');

      // Test 2: Get session data
      _sessionData = await SessionService.getSessionData();
      _updateStatus('Session data: ${_sessionData != null ? "EXISTS" : "NULL"}');

      // Test 3: Get individual fields
      final userId = await SessionService.getUserId();
      final userPhone = await SessionService.getUserPhone();
      final userRole = await SessionService.getUserRole();
      
      _updateStatus('''
Session Details:
- User ID: ${userId ?? 'NULL'}
- User Phone: ${userPhone ?? 'NULL'}
- User Role: ${userRole ?? 'NULL'}
- Session Data: ${_sessionData ?? 'NULL'}
''');

      // Test 4: Test AuthService session
      final authSession = await AuthService.isLoggedIn();
      _updateStatus('AuthService session: $authSession');

    } catch (e) {
      _updateStatus('Error testing session: $e');
    }
  }

  void _updateStatus(String status) {
    if (mounted) {
      setState(() {
        _status = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Test Results:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _status,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _testSession,
            child: const Text('Test Session Again'),
          ),
        ],
      ),
    );
  }
}