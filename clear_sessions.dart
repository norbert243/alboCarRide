import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('🧹 Clearing all stored sessions...');

  // Clear FlutterSecureStorage
  final secureStorage = FlutterSecureStorage();
  await secureStorage.deleteAll();
  print('✅ Cleared FlutterSecureStorage tokens');

  // Clear SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  print('✅ Cleared SharedPreferences sessions');

  print('🎉 All sessions cleared successfully!');
  print('Restart the app to test fresh authentication flow.');
}
