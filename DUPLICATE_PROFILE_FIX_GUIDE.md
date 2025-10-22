# Duplicate Profile Creation Fix Guide

## Problem
You're getting a "duplicate key value violates unique constraint" error when creating a driver profile with ID `a9582d72-c26e-406d-99a8-15f1503f2760`.

## Root Cause
The profile with this ID already exists in the database, but the app is trying to create it again. This happens due to:
1. Race conditions in profile creation logic
2. Session state issues
3. Multiple registration attempts

## Immediate Solution

### Option 1: Update the Existing Profile (Recommended)

Run this SQL in your Supabase SQL editor:

```sql
-- Check current profile data
SELECT id, full_name, phone, role, created_at, updated_at 
FROM profiles 
WHERE id = 'a9582d72-c26e-406d-99a8-15f1503f2760';

-- Update with your current registration data
UPDATE profiles 
SET 
  full_name = 'Your Full Name',  -- Replace with actual name
  phone = '+27XXXXXXXXX',        -- Replace with actual phone number
  role = 'driver',
  updated_at = NOW()
WHERE id = 'a9582d72-c26e-406d-99a8-15f1503f2760';

-- Create driver record if it doesn't exist
INSERT INTO drivers (id, is_approved, is_online, rating, total_rides, created_at, updated_at)
VALUES ('a9582d72-c26e-406d-99a8-15f1503f2760', false, false, 0.0, 0, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET updated_at = NOW();
```

### Option 2: Delete and Start Fresh

```sql
-- Delete existing records
DELETE FROM drivers WHERE id = 'a9582d72-c26e-406d-99a8-15f1503f2760';
DELETE FROM profiles WHERE id = 'a9582d72-c26e-406d-99a8-15f1503f2760';
```

## Code Fix

The profile creation logic in `lib/screens/auth/signup_page.dart` needs to be more robust. Here's the improved approach:

```dart
Future<Map<String, dynamic>> _createOrUpdateProfile({
  required String userId,
  required String phone,
  required String fullName,
  required String role,
}) async {
  final supabase = Supabase.instance.client;

  final payload = {
    'id': userId,
    'full_name': fullName,
    'phone': phone,
    'role': role,
    'updated_at': DateTime.now().toIso8601String(),
  };

  // Strategy: Try update first, then insert if needed
  try {
    // First try to update (if profile exists)
    final updateResponse = await supabase
        .from('profiles')
        .update(payload)
        .eq('id', userId)
        .select();

    if (updateResponse.isNotEmpty) {
      return updateResponse.first;
    }
  } catch (updateError) {
    // Continue to insert
  }

  // If update failed or returned no rows, try insert
  try {
    final insertResponse = await supabase
        .from('profiles')
        .insert(payload)
        .select();

    if (insertResponse.isEmpty) {
      throw Exception('Failed to create profile: No data returned');
    }

    return insertResponse.first;
  } catch (insertError) {
    // If insert fails with duplicate key, try update again
    if (insertError.toString().contains('duplicate key') ||
        insertError.toString().contains('23505')) {
      final retryUpdateResponse = await supabase
          .from('profiles')
          .update(payload)
          .eq('id', userId)
          .select();

      if (retryUpdateResponse.isEmpty) {
        throw Exception('Failed to update profile after duplicate key error');
      }

      return retryUpdateResponse.first;
    }
    throw Exception('Failed to create profile: $insertError');
  }
}
```

## Testing Steps

1. **Run the SQL fix** in Supabase SQL editor
2. **Clear app data** on your device/emulator
3. **Restart the app** and try registration again
4. **Verify navigation** to vehicle type selection page

## Expected Flow After Fix

1. User enters phone number and receives OTP
2. User verifies OTP successfully
3. Profile is created/updated without duplicate key errors
4. Driver is navigated to vehicle type selection page
5. Driver selects vehicle type and continues to verification

## Prevention

- Use robust UPSERT patterns in database operations
- Add proper error handling for duplicate key scenarios
- Implement session state validation
- Add comprehensive logging for debugging

## Next Steps

1. Apply the SQL fix immediately
2. Test the registration flow
3. If issues persist, check the enhanced profile creation logic
4. Monitor logs for any remaining race conditions