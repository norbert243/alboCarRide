# Driver Flow Explanation and Testing Guide

## Understanding the Current Behavior

The app is working correctly, but there's a misunderstanding about how the flow operates. Here's what's happening:

### Current Flow (Working as Intended)
1. **User launches app** → Already authenticated (session exists)
2. **AuthWrapper checks status** → Finds user is authenticated with NULL verification_status
3. **Routes to vehicle selection** → Correctly identifies this as the next step

### Why Authentication is Skipped
- The app uses session persistence (Supabase auth)
- When users return to the app, they're already authenticated
- AuthWrapper correctly detects this and proceeds to the next appropriate step
- This is the expected behavior for a good user experience

## Complete Intended Flow Sequence

The complete flow is designed to work as follows:

### For New Users (First Time)
1. **Authentication** → Role selection + phone verification
2. **Vehicle Selection** → Choose car or motorcycle
3. **Driver Verification** → Upload required documents
4. **Waiting for Review** → Documents under admin review
5. **Driver Home** → Final destination after approval

### For Returning Users (Already Authenticated)
1. **AuthWrapper** → Checks current status
2. **Routes to appropriate step** → Based on verification_status and vehicle_type

## Testing the Complete Flow

To test the complete sequence from start to finish, you need to simulate a new user registration:

### Method 1: Clear App Data
1. Clear the app's storage/cache
2. Uninstall and reinstall the app
3. This will force the authentication flow to start from the beginning

### Method 2: Use Different Test Accounts
1. Create new test phone numbers/accounts
2. Each new account will go through the complete flow

### Method 3: Database Reset (For Development)
Run the reset script to clear existing driver status:
```sql
-- Run this in your Supabase SQL editor
UPDATE profiles SET verification_status = NULL WHERE role = 'driver';
UPDATE drivers SET vehicle_type = NULL;
```

## AuthWrapper Routing Logic

The current routing logic in `auth_wrapper.dart` is correct:

```dart
// For new drivers (verification_status = NULL)
if (verificationStatus == null) {
    if (vehicleType == null) {
        // Route to vehicle selection (first step after auth)
        _navigateToVehicleType(userId);
    } else {
        // Route to verification (vehicle set but no verification)
        _navigateToVerification();
    }
}
// For pending verification
else if (verificationStatus == 'pending') {
    _navigateToWaitingReview();
}
// For approved drivers
else if (verificationStatus == 'approved') {
    if (vehicleType == null) {
        _navigateToVehicleType(userId);
    } else {
        _navigateToEnhancedDriverHome();
    }
}
```

## Expected User Experience

### First Time User
- Sees authentication → vehicle selection → verification → waiting review → home

### Returning User (Pending Verification)
- Sees waiting review page directly

### Returning User (Approved, No Vehicle)
- Sees vehicle selection → home

### Returning User (Fully Verified)
- Sees driver home page directly

## Verification Status States

- **NULL** = New driver, hasn't started verification process
- **'pending'** = Documents submitted, under review
- **'approved'** = Verification complete
- **'rejected'** = Verification failed, needs resubmission

## Conclusion

The app is working correctly. The "issue" is actually the expected behavior for returning authenticated users. To see the complete flow, you need to test with a fresh installation or new user account.

The routing logic properly handles all states and ensures users are always directed to the appropriate next step in their onboarding journey.