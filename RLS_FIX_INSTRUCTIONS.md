# RLS Policy Fix Instructions for Ride Requests

## Problem
The application is encountering a PostgrestException when creating ride requests:
```
PostgrestException(message: new row violates row-level security policy for table "ride_requests", code: 42501, details: Unauthorized, hint: null)
```

## Root Cause
The Row-Level Security (RLS) policies for the `ride_requests` table are either missing or incorrectly configured, preventing authenticated users from creating ride requests.

## Solution Files Created

### 1. `fix_ride_requests_rls.sql`
- **Purpose**: Targeted fix specifically for the ride_requests table
- **Actions**:
  - Drops existing conflicting policies
  - Creates comprehensive INSERT, SELECT, UPDATE, and DELETE policies
  - Ensures customers can create and manage their own ride requests
  - Allows drivers to view pending requests
  - Grants service role full access

### 2. `comprehensive_rls_fix.sql`
- **Purpose**: Complete RLS policy overhaul for all major tables
- **Actions**:
  - Fixes policies for profiles, ride_requests, ride_offers, and trips tables
  - Ensures proper user isolation and access control
  - Maintains security while allowing necessary functionality

## How to Apply the Fix

### Option 1: Quick Fix (Recommended)
1. Open your Supabase dashboard
2. Go to the SQL Editor
3. Copy and paste the contents of `fix_ride_requests_rls.sql`
4. Execute the script

### Option 2: Comprehensive Fix
1. Open your Supabase dashboard
2. Go to the SQL Editor
3. Copy and paste the contents of `comprehensive_rls_fix.sql`
4. Execute the script

## Verification Steps

After applying the fix:

1. **Test Ride Request Creation**:
   - Try creating a new ride request in the app
   - Should no longer receive RLS policy violation errors

2. **Verify Policies** (Optional):
   - Run the verification queries at the end of `comprehensive_rls_fix.sql`
   - Check that all tables have RLS enabled
   - Confirm policies exist for all operations

## Key Policy Details

### Ride Requests Policies:
- **INSERT**: Customers can create requests where `customer_id = auth.uid()`
- **SELECT**: 
  - Customers can view their own requests
  - Drivers can view pending requests
- **UPDATE**: Customers can update their own requests
- **DELETE**: Customers can delete their own requests

### User Isolation:
- Users can only access their own data
- Drivers can see pending ride requests for matching
- Service role has full administrative access

## Expected Behavior After Fix

- ✅ Customers can create ride requests without errors
- ✅ Customers can view and manage their own requests
- ✅ Drivers can see pending requests for matching
- ✅ All operations respect user authentication and authorization
- ✅ No security compromises in data access

## Troubleshooting

If issues persist:

1. **Check Current Policies**:
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'ride_requests';
   ```

2. **Verify RLS is Enabled**:
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'ride_requests';
   ```

3. **Test Authentication**:
   - Ensure the user is properly authenticated
   - Verify the `auth.uid()` matches the `customer_id`

## Additional Notes

- The fix assumes the current schema uses `customer_id` column in `ride_requests`
- If your schema uses `rider_id` instead, modify the policies accordingly
- Always test in a development environment first
- Consider backing up your database before making changes