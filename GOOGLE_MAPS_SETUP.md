# Google Maps Setup Guide for AlboCarRide

This guide will help you configure Google Maps for both Android and iOS platforms.

## Prerequisites

1. Google Cloud Console account
2. Billing enabled on your Google Cloud project
3. Google Maps API key with the following APIs enabled:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Directions API
   - Geocoding API
   - Distance Matrix API

## Step 1: Get Your Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable billing for the project
4. Go to **APIs & Services** > **Library**
5. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Directions API
   - Geocoding API
   - Distance Matrix API
6. Go to **APIs & Services** > **Credentials**
7. Click **Create Credentials** > **API Key**
8. Copy your API key
9. (Recommended) Click **Edit API key** to restrict it:
   - For Android: Add your app's package name and SHA-1 fingerprint
   - For iOS: Add your app's bundle ID
   - For API restrictions: Select "Restrict key" and choose the APIs you enabled

## Step 2: Add API Key to .env File

Add your Google Maps API key to the `.env` file in the project root:

```
GOOGLE_MAPS_API_KEY=YOUR_API_KEY_HERE
```

## Step 3: Configure Android

### 3.1. Update AndroidManifest.xml

Open `android/app/src/main/AndroidManifest.xml` and add the following inside the `<application>` tag:

```xml
<application>
    <!-- ... other configurations ... -->

    <!-- Google Maps API Key -->
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY_HERE"/>

</application>
```

### 3.2. Add Permissions

Ensure these permissions are in your `AndroidManifest.xml` (should already be there):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 3.3. Update build.gradle

Open `android/app/build.gradle` and ensure `minSdkVersion` is at least 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // or higher
    }
}
```

## Step 4: Configure iOS

### 4.1. Update AppDelegate.swift

Open `ios/Runner/AppDelegate.swift` and add the Google Maps initialization:

```swift
import UIKit
import Flutter
import GoogleMaps  // Add this import

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add this line with your API key
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 4.2. Update Info.plist

Open `ios/Runner/Info.plist` and add location permissions:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to show nearby drivers and calculate fares.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to your location to track rides and provide accurate ETAs.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to your location to track rides and provide accurate ETAs.</string>
```

### 4.3. Update Podfile

Open `ios/Podfile` and ensure the platform is iOS 12 or higher:

```ruby
platform :ios, '12.0'
```

Then run:

```bash
cd ios
pod install
cd ..
```

## Step 5: Testing

### Test on Android

```bash
flutter run
```

### Test on iOS

```bash
flutter run
```

## Troubleshooting

### Map shows blank or gray

1. **Check API key**: Verify your API key is correct in both `.env` file and platform-specific files
2. **Enable APIs**: Make sure all required APIs are enabled in Google Cloud Console
3. **Check billing**: Ensure billing is enabled on your Google Cloud project
4. **Check restrictions**: If you've restricted your API key, make sure the restrictions allow your app

### "API key not found" error on Android

1. Verify the API key in `AndroidManifest.xml` matches your Google Cloud Console key
2. Make sure you've enabled "Maps SDK for Android" in Google Cloud Console
3. Clean and rebuild: `flutter clean && flutter pub get && flutter run`

### Map not showing on iOS

1. Verify `GMSServices.provideAPIKey()` is called in `AppDelegate.swift`
2. Make sure you've enabled "Maps SDK for iOS" in Google Cloud Console
3. Check that location permissions are properly set in `Info.plist`
4. Run `pod install` again in the `ios` directory

### Build errors

1. Run `flutter clean`
2. Delete `build` folders
3. Run `flutter pub get`
4. For iOS, delete `Podfile.lock` and `Pods` folder, then run `pod install`
5. Rebuild the app

## Security Best Practices

1. **Never commit API keys to version control**
   - Keep `.env` file in `.gitignore`
   - Use environment variables for production

2. **Restrict your API key**
   - Add application restrictions (package name for Android, bundle ID for iOS)
   - Add API restrictions to only the APIs you need
   - Monitor usage in Google Cloud Console

3. **Set up budget alerts**
   - Go to Google Cloud Console > Billing > Budgets & alerts
   - Set up alerts to avoid unexpected charges

## API Usage Costs

Google Maps APIs have a free tier, but charges may apply:
- **First $200/month is free**
- Maps SDK: $7 per 1,000 loads
- Places API: $17 per 1,000 requests (basic)
- Directions API: $5 per 1,000 requests
- Geocoding API: $5 per 1,000 requests

Monitor your usage at: https://console.cloud.google.com/google/maps-apis/metrics

## Additional Resources

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [google_maps_flutter package](https://pub.dev/packages/google_maps_flutter)
- [Restrict API Keys](https://developers.google.com/maps/api-security-best-practices)
