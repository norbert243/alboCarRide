import 'dart:io';

void main() async {
  print('Clearing session data...');

  // Clear SharedPreferences data
  await clearSharedPreferences();

  // Clear FlutterSecureStorage data
  await clearSecureStorage();

  print('Session data cleared successfully!');
  print('Please restart the app and log in again.');
}

Future<void> clearSharedPreferences() async {
  try {
    // For iOS simulator
    final iosPath =
        '${Platform.environment['HOME']}/Library/Developer/CoreSimulator/Devices';
    final iosProcess = await Process.run('find', [
      iosPath,
      '-name',
      '*.plist',
      '-exec',
      'plutil',
      '-convert',
      'xml1',
      '{}',
      ';',
      '-exec',
      'sed',
      '-i',
      '',
      's/access_token.*//g',
      '{}',
      ';',
    ], runInShell: true);

    // For Android emulator
    final androidPath = '${Platform.environment['HOME']}/.android/avd';
    final androidProcess = await Process.run('find', [
      androidPath,
      '-name',
      '*.xml',
      '-exec',
      'sed',
      '-i',
      '',
      's/access_token.*//g',
      '{}',
      ';',
    ], runInShell: true);

    print('SharedPreferences cleared');
  } catch (e) {
    print('Error clearing SharedPreferences: $e');
  }
}

Future<void> clearSecureStorage() async {
  try {
    // For iOS - clear keychain entries
    final iosProcess = await Process.run('security', [
      'delete-generic-password',
      '-a',
      'com.example.albocarride',
    ], runInShell: true);

    // For Android - clear encrypted storage
    final androidProcess = await Process.run('adb', [
      'shell',
      'pm',
      'clear',
      'com.example.albocarride',
    ], runInShell: true);

    print('SecureStorage cleared');
  } catch (e) {
    print('Error clearing SecureStorage: $e');
  }
}
