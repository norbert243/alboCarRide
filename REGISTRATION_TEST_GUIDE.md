# AlboCarRide - Registration Test Guide

## Prerequisites

1. **Supabase Setup**:
   - Ensure your Supabase project is active at: https://txulwrdevjuwumqvevjt.supabase.co
   - Run the updated database schema from `database_schema.sql` in your Supabase SQL editor
   - Configure proper Row Level Security (RLS) policies for the `profiles` table

2. **Database Schema**:
   - The schema has been updated to work directly with Supabase's `auth.users` table
   - No more separate `users` table - profiles reference `auth.users.id` directly

## Testing Registration

### Step 1: Run the Application
```bash
flutter run
```

### Step 2: Test Registration Flow
1. Select a role (Customer or Driver)
2. Enter a phone number (e.g., +1234567890)
3. Enter your full name
4. Click "Send Verification Code"
5. Enter the 6-digit OTP shown in the console/logs
6. Complete registration

### Expected Behavior
- User should be created in Supabase Auth
- Profile should be created in the `profiles` table
- **For drivers**: Driver record should be created in the `drivers` table
- **For customers**: Customer record should be created in the `customers` table
- Session should be saved to local storage
- User should be redirected to the appropriate home page based on role

## Troubleshooting

### Common Issues

1. **Database Connection Errors**:
   - Ensure the database schema has been applied
   - Check RLS policies allow inserts into the `profiles` table

2. **Authentication Errors**:
   - Verify Supabase URL and anon key in `.env` file
   - Check if email confirmation is required in Supabase settings

3. **Profile Creation Errors**:
   - Ensure the `profiles` table exists with correct schema
   - Check that RLS allows inserts for authenticated users

### RLS Policy Example
```sql
-- Allow users to insert their own profile
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Allow users to read their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);
```

## Verification

1. **Check Supabase Auth**:
   - Go to your Supabase project → Authentication → Users
   - Verify new users are being created

2. **Check Database**:
   - Go to your Supabase project → Table Editor → profiles
   - Verify profiles are being created with correct data
   - **For drivers**: Check Table Editor → drivers for driver records
   - **For customers**: Check Table Editor → customers for customer records

3. **Check Logs**:
   - Monitor Flutter console for any error messages
   - Look for successful registration messages

## Next Steps

After successful registration test:
1. Implement proper phone authentication (instead of dummy email)
2. Add email verification if required
3. Implement proper password reset flow
4. Add social login options