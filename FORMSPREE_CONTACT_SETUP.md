# Formspree Contact/Support Form Setup Guide

## Overview

The Contact/Support feature has been implemented in the AlboCarRide mobile app using Formspree. This feature provides users with a reliable way to report issues, ask questions, and contact support even if other parts of the app experience problems.

## Features Implemented

### 1. **Comprehensive Contact Form**
- **Name Field**: Auto-populated from user profile
- **Email Field**: Auto-populated from user profile or auth data
- **Issue Type Dropdown**: 9 predefined categories including:
  - General Inquiry
  - App Crash/Technical Issue
  - Booking Problem
  - Payment Issue
  - Driver Issue
  - Account Problem
  - Feature Request
  - Safety Concern
  - Other

- **Message/Description Field**:
  - Multi-line text area (6 lines)
  - 1000 character limit
  - Minimum 20 characters required
  - Character counter included

### 2. **Robust Error Handling**
- Network error detection with retry functionality
- Timeout handling (15-second timeout)
- User-friendly error messages
- Automatic retry dialog for failed submissions
- Graceful fallbacks if user info can't be loaded

### 3. **User Feedback**
- Loading spinner during submission
- Success message with confirmation
- Detailed error dialogs
- Form validation with helpful error messages
- Response time expectation message

### 4. **Additional Contact Options**
- Quick contact cards for:
  - Phone support
  - Email support
  - Live chat (placeholder)
- FAQ section with common questions
- Emergency contact section

### 5. **Data Captured**
Each submission includes:
- User's name
- Email address
- Issue type
- Detailed message
- User ID (from database)
- Phone number (if available)
- Timestamp
- Platform identifier ("mobile_app")

## Setup Instructions

### Step 1: Create a Formspree Account

1. Go to [https://formspree.io/](https://formspree.io/)
2. Sign up for a free account (or use an existing account)
3. Free tier includes:
   - 50 submissions per month
   - Email notifications
   - Basic form features
   - Spam filtering

4. For higher volume, consider upgrading to:
   - **Gold Plan** ($10/month): 1,000 submissions
   - **Platinum Plan** ($40/month): 10,000 submissions

### Step 2: Create a New Form

1. After logging in, click **"+ New Form"**
2. Name your form: `AlboCarRide Support`
3. Copy the form endpoint URL, which will look like:
   ```
   https://formspree.io/f/YOUR_FORM_ID
   ```
   Where `YOUR_FORM_ID` is a unique identifier like `xyzabc123`

### Step 3: Configure Form Settings

In your Formspree dashboard:

1. **Email Settings**:
   - Set notification email to: `support@albocarride.com` (or your preferred email)
   - Enable email notifications for new submissions

2. **Spam Protection** (Recommended):
   - Enable reCAPTCHA (optional, but recommended)
   - Enable honeypot spam filtering
   - Set up custom spam filters if needed

3. **Autoresponder** (Optional):
   - Enable to send automatic confirmation emails to users
   - Customize the message:
     ```
     Thank you for contacting AlboCarRide Support!

     We've received your message and will get back to you within 24 hours.

     Your ticket details:
     Issue Type: {{issueType}}
     Submitted: {{timestamp}}

     Best regards,
     AlboCarRide Support Team
     ```

4. **Submission Archive**:
   - All submissions are automatically stored in Formspree
   - Access them anytime from your dashboard
   - Export to CSV if needed

### Step 4: Update the App Code

1. Open the file: `lib/screens/home/support_page.dart`

2. Find line 29 where the endpoint is defined:
   ```dart
   static const String _formspreeEndpoint = 'https://formspree.io/f/YOUR_FORM_ID';
   ```

3. Replace `YOUR_FORM_ID` with your actual Formspree form ID:
   ```dart
   static const String _formspreeEndpoint = 'https://formspree.io/f/xyzabc123';
   ```

4. Save the file

### Step 5: Test the Implementation

1. **Build the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk  # For Android
   # or
   flutter build ios  # For iOS
   ```

2. **Run the app** on a test device or emulator:
   ```bash
   flutter run
   ```

3. **Navigate to the Support page**:
   - From the main menu, tap on "Support" or "Help"
   - The support page should load with the contact form

4. **Test submission**:
   - Fill in all fields with test data
   - Ensure name and email are populated
   - Select an issue type
   - Write a test message (at least 20 characters)
   - Submit the form

5. **Verify success**:
   - You should see a green success message
   - Check your Formspree dashboard for the submission
   - Check the notification email inbox

## Troubleshooting

### Issue: "Network Error" when submitting

**Possible Causes:**
- No internet connection
- Formspree endpoint URL is incorrect
- Firewall blocking the request

**Solutions:**
1. Check device internet connection
2. Verify the Formspree endpoint URL in the code
3. Try on a different network
4. Check Formspree dashboard for API status

### Issue: Form fields not auto-populating

**Possible Causes:**
- User profile data not in database
- Database query failing
- Auth session expired

**Solutions:**
- This is not a critical issue - users can still manually enter their info
- Check database for user profile data
- Verify Supabase connection

### Issue: Submissions not appearing in Formspree

**Possible Causes:**
- Wrong form ID
- Formspree account issue
- Submissions being filtered as spam

**Solutions:**
1. Verify form ID matches the code
2. Check Formspree dashboard spam folder
3. Review Formspree account status

### Issue: "Request timed out"

**Possible Causes:**
- Slow internet connection
- Formspree API issues

**Solutions:**
1. Try again with better connection
2. User can use the retry button
3. Check Formspree status page

## Monitoring and Maintenance

### Regular Tasks

1. **Check Submissions Daily**:
   - Log into Formspree dashboard
   - Review new support requests
   - Respond to urgent issues

2. **Monitor Usage**:
   - Track monthly submission count
   - Upgrade plan if approaching limit
   - Review spam submissions

3. **Update Contact Info**:
   - Keep phone numbers and emails current
   - Test contact methods regularly

### Monthly Review

1. Review common issues from submissions
2. Update FAQ section based on frequent questions
3. Analyze response times
4. Check spam filter effectiveness

## File Locations

- **Support Page**: `lib/screens/home/support_page.dart`
- **Main App**: `lib/main.dart` (route: `/support`)
- **Documentation**: `FORMSPREE_CONTACT_SETUP.md`

## API Reference

### Formspree Endpoint

```
POST https://formspree.io/f/{YOUR_FORM_ID}
Content-Type: application/json
Accept: application/json
```

### Request Body

```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "issueType": "App Crash/Technical Issue",
  "message": "The app crashes when I try to book a ride...",
  "userId": "uuid-here",
  "phone": "+1234567890",
  "timestamp": "2025-10-27T12:34:56.789Z",
  "platform": "mobile_app"
}
```

### Response Codes

- **200/201**: Success - Form submitted
- **400**: Bad Request - Invalid data
- **403**: Forbidden - Spam detected or rate limited
- **404**: Not Found - Invalid form ID
- **500**: Server Error - Formspree issue

## Security Considerations

1. **No sensitive data exposure**: Form ID is public but can only be used to submit forms
2. **Spam protection**: Formspree includes built-in spam filtering
3. **Rate limiting**: Formspree enforces rate limits to prevent abuse
4. **HTTPS**: All communication is encrypted
5. **Data privacy**: Formspree is GDPR compliant

## Alternative Configuration (Environment Variables)

For better security and easier management across environments, you can store the Formspree endpoint in the `.env` file:

1. **Edit `.env` file**:
   ```env
   FORMSPREE_ENDPOINT=https://formspree.io/f/YOUR_FORM_ID
   ```

2. **Update `support_page.dart`**:
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';

   // Replace the static constant with:
   static String get _formspreeEndpoint =>
       dotenv.env['FORMSPREE_ENDPOINT'] ?? 'https://formspree.io/f/YOUR_FORM_ID';
   ```

3. **Benefits**:
   - Different endpoints for dev/staging/production
   - No hardcoded values in source code
   - Easy updates without code changes

## Support Escalation Flow

When users submit support requests:

1. **Formspree receives submission** → Stores in dashboard
2. **Email notification sent** → To support@albocarride.com
3. **Support team responds** → Via email
4. **Optional**: Set up integrations with:
   - Slack (for instant notifications)
   - Zapier (for advanced workflows)
   - Email management systems

## Future Enhancements

Potential improvements to consider:

1. **Attachment Support**: Allow users to upload screenshots
2. **Live Chat Integration**: Replace placeholder with actual chat
3. **Ticket Tracking**: Show submission history in-app
4. **Push Notifications**: Notify users when support responds
5. **Multi-language Support**: Translate form and messages
6. **Analytics**: Track common issues and response times

## Contact for Help

If you need assistance with this implementation:

- **Formspree Support**: https://help.formspree.io/
- **Formspree Status**: https://status.formspree.io/
- **Developer Documentation**: https://help.formspree.io/hc/en-us/categories/360002111314-Formspree

## License

This implementation is part of the AlboCarRide application.

---

**Last Updated**: October 27, 2025
**Version**: 1.0
**Author**: Claude Code Assistant
