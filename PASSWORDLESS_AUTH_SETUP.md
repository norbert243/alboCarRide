# WhatsApp-Style Passwordless Authentication Setup Guide

This guide will walk you through setting up the passwordless authentication system for AlboCarRide, similar to WhatsApp's phone number + OTP flow.

## Overview

The authentication flow consists of:
1. User enters phone number and full name
2. System sends OTP via Twilio SMS
3. User enters 6-digit OTP code
4. System verifies OTP and creates/logs in user
5. Session tokens are stored securely for persistent login

## Prerequisites

- Supabase project (already created)
- Twilio account with SMS capabilities (credentials in .env)
- Supabase CLI installed (for deploying Edge Functions)

## Step 1: Run the Database Migration

The OTP verification system requires a new table to store OTP codes securely on the backend.

### Using Supabase Dashboard (Recommended):

1. Go to your Supabase project dashboard: https://app.supabase.com
2. Navigate to **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy and paste the contents of `supabase/migrations/20250122_create_otp_verifications.sql`
5. Click **Run** to execute the migration

### Using Supabase CLI:

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref YOUR_PROJECT_REF

# Run the migration
supabase db push
```

## Step 2: Deploy Supabase Edge Functions

The passwordless auth system uses two Edge Functions:

### 2.1 Deploy send-otp Function

This function generates and sends OTP codes via Twilio.

```bash
# Navigate to project root
cd C:\Users\lubay\Documents\alboCarRide

# Deploy the send-otp function
supabase functions deploy send-otp --no-verify-jwt
```

### 2.2 Deploy verify-otp Function

This function verifies the OTP and creates/authenticates users.

```bash
# Deploy the verify-otp function
supabase functions deploy verify-otp --no-verify-jwt
```

### 2.3 Set Environment Variables for Edge Functions

Edge Functions need access to Twilio credentials and Supabase keys.

**Using Supabase Dashboard:**

1. Go to **Settings** → **Edge Functions**
2. Click **Add secret** and add the following:
   - `TWILIO_ACCOUNT_SID`: Your Twilio Account SID
   - `TWILIO_AUTH_TOKEN`: Your Twilio Auth Token
   - `TWILIO_PHONE_NUMBER`: Your Twilio phone number
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (found in Settings → API)

**Using Supabase CLI:**

```bash
supabase secrets set TWILIO_ACCOUNT_SID=your_account_sid
supabase secrets set TWILIO_AUTH_TOKEN=your_auth_token
supabase secrets set TWILIO_PHONE_NUMBER=your_twilio_number
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## Step 3: Verify Supabase Configuration

Make sure your `.env` file has the correct Supabase credentials:

```env
SUPABASE_URL=https://txulwrdevjuwumqvevjt.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Step 4: Test the Authentication Flow

### Testing from the App:

1. Run the app: `flutter run`
2. Navigate to the signup screen
3. Select your role (Customer or Driver)
4. Enter your full name and phone number (format: +27812345678)
5. Click **Continue**
6. You should receive an SMS with a 6-digit code
7. Enter the code on the OTP verification screen
8. You should be logged in successfully

### Testing the Edge Functions Directly:

**Test send-otp:**

```bash
curl -X POST \
  'https://txulwrdevjuwumqvevjt.supabase.co/functions/v1/send-otp' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber": "+27812345678"}'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "expiresIn": 600
}
```

**Test verify-otp:**

```bash
curl -X POST \
  'https://txulwrdevjuwumqvevjt.supabase.co/functions/v1/verify-otp' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "phoneNumber": "+27812345678",
    "otp": "123456",
    "fullName": "John Doe",
    "role": "customer"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "userId": "uuid-here",
  "isNewUser": true,
  "role": "customer",
  "message": "Phone number verified successfully"
}
```

## Architecture Overview

### Database Schema

**otp_verifications table:**
```sql
- id: UUID (Primary Key)
- phone_number: TEXT (Unique)
- otp_code: TEXT
- expires_at: TIMESTAMP (OTP valid for 10 minutes)
- verified: BOOLEAN (Prevents OTP reuse)
- attempts: INTEGER (Max 5 attempts)
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

### Edge Functions

**send-otp:**
- Generates random 6-digit OTP
- Stores OTP in database with 10-minute expiry
- Sends OTP via Twilio SMS
- Returns success status

**verify-otp:**
- Validates OTP against database record
- Checks expiry and attempt limits
- Creates/authenticates user in Supabase Auth
- Creates profile and role-specific records
- Returns user session details

### Flutter Implementation

**SignupPage (lib/screens/auth/signup_page.dart):**
- Collects phone number and full name
- Calls send-otp Edge Function
- Navigates to OTP verification screen

**OtpVerificationPage (lib/screens/auth/otp_verification_page.dart):**
- 6-digit OTP input with auto-focus
- Calls verify-otp Edge Function
- Stores session tokens securely
- Navigates based on user role and verification status

**AuthService (lib/services/auth_service.dart):**
- Manages session storage using flutter_secure_storage
- Handles auto-login on app restart
- Refreshes tokens when needed

## Security Features

1. **Backend OTP Storage:** OTPs are generated and stored on the backend, not client-side
2. **Expiry Management:** OTPs expire after 10 minutes
3. **Attempt Limiting:** Maximum 5 verification attempts per OTP
4. **OTP Reuse Prevention:** OTPs are marked as verified after successful use
5. **Secure Token Storage:** Access and refresh tokens stored in encrypted storage
6. **Row Level Security:** Database policies restrict access to OTP records

## Troubleshooting

### OTP not received:

1. Check Twilio account balance
2. Verify phone number format (+27... for South Africa)
3. Check Twilio console for delivery status
4. Ensure TWILIO_PHONE_NUMBER is correct in Edge Function secrets

### OTP verification fails:

1. Check database for OTP record: `SELECT * FROM otp_verifications WHERE phone_number = '+27...'`
2. Verify OTP hasn't expired (expires_at > NOW())
3. Check attempts count (< 5)
4. Ensure OTP hasn't been used (verified = false)

### Session not persisting:

1. Check flutter_secure_storage permissions
2. Verify AuthService.saveSession is being called
3. Check SharedPreferences for user data
4. Review auth state in SessionService

### Edge Functions not working:

1. Check function logs in Supabase dashboard
2. Verify environment variables are set
3. Ensure CORS headers are correct
4. Check Supabase project URL and anon key

## Next Steps

1. **Test thoroughly:** Try signup, login, and session persistence
2. **Handle edge cases:** Network errors, invalid phone numbers, etc.
3. **Add rate limiting:** Prevent OTP spam (future enhancement)
4. **Monitor usage:** Check Twilio and Supabase usage regularly
5. **Implement logout:** Ensure proper token cleanup on logout

## Support

For issues or questions:
- Check Supabase logs: Dashboard → Logs → Edge Functions
- Check Twilio logs: Twilio Console → Monitor → Logs → SMS
- Review app logs for error messages

## Summary

You've now implemented a secure, WhatsApp-style passwordless authentication system! Users can sign up and log in using just their phone number, receiving an OTP via SMS for verification. The system includes:

- Secure backend OTP generation and verification
- Persistent sessions with token refresh
- Role-based routing (Customer vs Driver)
- Comprehensive error handling
- Clean, intuitive UI similar to WhatsApp

The app will automatically log users in on subsequent launches using stored tokens, providing a seamless experience just like WhatsApp!
