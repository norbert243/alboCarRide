# Driver Online Status Permissions Fix

## Issue
When a driver tries to toggle their online status in the enhanced driver dashboard, they receive the error:
```
permission denied for table profiles
```

## Root Cause
The Row Level Security (RLS) policy for the `profiles` table expects a `user_id` column, but the actual table structure may use a different column name (likely `id`).

### Current RLS Policy (from `migration_v10_rls_policies.sql`):
```sql
CREATE POLICY profiles_update_policy ON profiles
FOR UPDATE TO authenticated
USING (auth.uid() = user_id);
```

This policy compares `auth.uid()` with the `user_id` column. If the `profiles` table doesn't have a `user_id` column, the policy condition fails for all rows, resulting in "permission denied".

## Temporary Workaround (Implemented)
The frontend has been updated to:
1. Catch the permission error gracefully
2. Show a user-friendly error message
3. Prevent the app from crashing

The driver can still use other dashboard features, but cannot toggle online/offline status until the database is fixed.

## Permanent Fix
Run the following SQL to update the RLS policy to use the correct column name:

### Option 1: If the column is named `id` (most common in Supabase):
```sql
-- Drop the existing policy
DROP POLICY IF EXISTS profiles_update_policy ON profiles;

-- Create new policy using 'id' column
CREATE POLICY profiles_update_policy ON profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id);
```

### Option 2: If the column is named `user_id` but doesn't exist, add it:
```sql
-- Add user_id column if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Update existing rows to match auth.uid()
UPDATE profiles SET user_id = id WHERE user_id IS NULL;

-- Make the column NOT NULL after population
ALTER TABLE profiles ALTER COLUMN user_id SET NOT NULL;
```

### Option 3: Run the complete RLS migration fix:
```sql
-- Fix all profile policies
DROP POLICY IF EXISTS profiles_select_policy ON profiles;
DROP POLICY IF EXISTS profiles_insert_policy ON profiles;
DROP POLICY IF EXISTS profiles_update_policy ON profiles;

-- Recreate with correct column name (assuming 'id')
CREATE POLICY profiles_select_policy ON profiles
FOR SELECT TO authenticated
USING (auth.uid() = id);

CREATE POLICY profiles_insert_policy ON profiles
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY profiles_update_policy ON profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id);
```

## Verification
After applying the fix:
1. Restart the application
2. Navigate to the driver dashboard
3. Click the "Go Online" button
4. Verify that the online status toggles without errors
5. Check the database to confirm the `is_online` field updates correctly

## Additional Notes
- The enhanced driver dashboard now shows rider contact information (name, phone number)
- Real-time ride requests are displayed with improved UI
- All layout overflow errors have been fixed
- Database column errors have fallback handling
- User feedback is provided via snackbar notifications

## Files Modified
- `lib/screens/home/enhanced_driver_home_page.dart` - Added better error handling
- `lib/screens/home/driver_dashboard_v2_realtime.dart` - Fixed database column fallback
- `lib/widgets/offer_board.dart` - Enhanced to show rider details

## Next Steps
1. Apply the SQL fix to the production database
2. Test the online/offline functionality
3. Verify all enhanced features work end-to-end
4. Deploy the updated application