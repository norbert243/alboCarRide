# Google Maps Setup Guide for AlboCarRide

## Overview
This guide will help you set up Google Maps for the customer home page to display the user's current location.

## Prerequisites
- Google Cloud Platform account
- Billing account set up on Google Cloud Platform

## Step 1: Enable Google Maps APIs

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** 
   - **Places API**
   - **Directions API**
   - **Geocoding API**

## Step 2: Create API Keys

### For Android:
1. Go to **Credentials** in the Google Cloud Console
2. Click **Create Credentials** → **API Key**
3. Restrict the API key to:
   - **Application restrictions**: Android apps
   - **API restrictions**: Restrict to the APIs listed above
4. Add your app's package name and SHA-1 certificate fingerprint

### For iOS:
1. Create another API key for iOS
2. Restrict the API key to:
   - **Application restrictions**: iOS apps
   - **API restrictions**: Restrict to the APIs listed above
3. Add your app's bundle identifier

## Step 3: Configure API Keys

### Android Configuration
Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `android/app/src/main/AndroidManifest.xml` with your Android API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ANDROID_API_KEY_HERE" />
```

### iOS Configuration
Add the following to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Step 4: Environment Variables (Optional)

You can also set the API keys as environment variables in your `.env` file:

```
GOOGLE_MAPS_ANDROID_API_KEY=your_android_api_key_here
GOOGLE_MAPS_IOS_API_KEY=your_ios_api_key_here
```

## Step 5: Testing

1. Run the app on a physical device (maps don't work well on emulators)
2. Grant location permissions when prompted
3. The map should display with your current location marked

## Troubleshooting

### Common Issues:

1. **Map not loading**: Check API key restrictions and ensure all required APIs are enabled
2. **Location not showing**: Verify location permissions are granted
3. **Blank screen**: Check internet connection and API key validity
4. **Android buffer warnings**: "Unable to acquire a buffer item" warnings are normal Android system messages during development and don't affect map functionality

### Error Messages:

- **"This IP, site or mobile application is not authorized to use this API key"**: Check API key restrictions
- **"API key not valid"**: Verify the API key is correct and not expired
- **"The provided API key is expired"**: Create a new API key

## Security Notes

- Never commit API keys to version control
- Use environment variables or secure storage
- Restrict API keys to specific apps and APIs
- Monitor usage in Google Cloud Console

## Support

If you encounter issues:
1. Check the Google Maps Flutter documentation
2. Verify all setup steps were completed
3. Check the Google Cloud Console for API usage and errors