# Session Management Debugging Guide

## Overview

The AlboCarRide app uses a dual-session management system:
1. **Supabase Auth Session** - Handles authentication with the backend
2. **Local Session Storage** - Persists session data locally using SharedPreferences

## Issues Identified and Fixed

### 1. **AuthWrapper Session Checking**
**Problem**: The AuthWrapper was only checking Supabase auth session but not local session storage.

**Fix**: Enhanced `_checkAndRoute()` method to check both sessions and synchronize them properly.

### 2. **Session Saving Error Handling**
**Problem**: Session saving in SignupPage had no error handling.

**Fix**: Added try-catch blocks and session verification after saving.

### 3. **Session Synchronization**
**Problem**: Sessions could become out of sync between Supabase and local storage.

**Fix**: Implemented session synchronization logic in AuthWrapper.

## How to Test Session Functionality

### Method 1: Using the Debug Screen

1. **Access the Debug Screen**:
   - Navigate to `/session-debug` in the app
   - Or add a debug button in your app to navigate there

2. **Check Current Session Status**:
   - The debug screen shows detailed information about both sessions
   - Look for "Sessions Synced" status
   - Check if both local and Supabase sessions are valid

3. **Use Debug Actions**:
   - **Force Sync**: Synchronizes sessions if they're out of sync
   - **Check Validity**: Verifies session validity
   - **Clear All**: Clears all sessions (useful for testing)

### Method 2: Manual Testing

1. **Test Registration Flow**:
   - Register a new user
   - Check console logs for session saving messages
   - Restart the app - user should remain logged in

2. **Test Session Persistence**:
   - Log in successfully
   - Close and reopen the app
   - User should be automatically logged in

3. **Test Session Expiry**:
   - Wait for session to expire (default: 30 days)
   - User should be redirected to login screen

## Debug Console Logs

Look for these log messages in the console:

### During Registration:
```
Session saved to local storage successfully
Session verification successful:
  User ID: [user-id]
  Phone: [phone-number]
  Role: [role]
```

### During App Startup:
```
Session check:
  Supabase session: [Exists/Null]
  Local session: [Valid/Invalid/Expired]
  Local session data: [session-data]
```

## Common Session Issues and Solutions

### Issue 1: "No valid session found" after app restart
**Cause**: Local session not saved properly during registration
**Solution**: 
- Check if `SessionService.saveSession()` is called after successful registration
- Verify SharedPreferences permissions in Android/iOS

### Issue 2: Sessions out of sync
**Cause**: Supabase session exists but local session is missing or expired
**Solution**:
- Use "Force Sync" button in debug screen
- Or manually call `SessionDebugService.forceSessionSync()`

### Issue 3: User redirected to login despite valid session
**Cause**: Session expiry check failing
**Solution**:
- Check session expiry dates in debug screen
- Verify timezone settings on device

## Session Service Methods

### Core Session Methods:
- `SessionService.saveSession()` - Save session to local storage
- `SessionService.clearSession()` - Clear local session
- `SessionService.isLoggedIn()` - Check if user is logged in
- `SessionService.hasValidSession()` - Check session validity

### Debug Methods:
- `SessionDebugService.debugSessionStatus()` - Get detailed session info
- `SessionDebugService.getDebugReport()` - Generate debug report
- `SessionDebugService.forceSessionSync()` - Synchronize sessions
- `SessionDebugService.clearAllSessions()` - Clear all sessions

## Testing Checklist

- [ ] New user registration saves session correctly
- [ ] Existing user login saves session correctly
- [ ] Session persists after app restart
- [ ] User redirected to appropriate screen based on role
- [ ] Session expiry works correctly
- [ ] Session clearing works on logout
- [ ] Sessions synchronize properly between Supabase and local storage

## Troubleshooting

### If sessions aren't saving:
1. Check SharedPreferences permissions
2. Verify `shared_preferences` package is properly installed
3. Check for exceptions during session saving

### If sessions aren't loading:
1. Check session expiry dates
2. Verify session data format in SharedPreferences
3. Check for corrupted session data

### If sessions are out of sync:
1. Use "Force Sync" functionality
2. Check if Supabase auth tokens are valid
3. Verify user metadata matches session data

## Session Data Structure

Local session stores:
- `is_logged_in` (bool) - Whether user is logged in
- `user_id` (string) - User ID from Supabase
- `user_phone` (string) - User's phone number
- `user_role` (string) - User's role (driver/customer)
- `session_expiry` (string) - Session expiry date (ISO format)

## Security Considerations

- Session data is stored locally using SharedPreferences
- No sensitive authentication tokens are stored locally
- Session expiry prevents indefinite access
- Clear sessions on logout for security

## Performance Notes

- Session checks are performed asynchronously
- Session data is cached for quick access
- Expiry checks are lightweight and efficient
- Session synchronization happens only when needed