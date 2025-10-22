# AlboCarRide Architecture and Workflow Documentation

## Current Architecture Overview

### Core Components

#### 1. Authentication & Session Management
- **AuthService**: Singleton service handling Supabase authentication
- **SessionService**: Local session storage using SharedPreferences
- **AuthWrapper**: Main authentication routing component

#### 2. Document Upload System
- **DocumentUploadService**: Handles file uploads with compression and validation
- **Storage Bucket**: Supabase storage bucket 'driver-documents'
- **Document Types**: Driver license, vehicle registration, profile photo, vehicle photo, deposit proof

#### 3. Database Schema
- **profiles**: User profiles with role information
- **drivers**: Driver-specific information and vehicle details
- **driver_documents**: Document metadata and storage references
- **driver_wallets**: Driver financial information

## Workflow Issues Fixed

### Issue 1: Session Management Synchronization

**Problem**: AuthService and AuthWrapper were not properly synchronized, causing inconsistent authentication states.

**Solution**: Enhanced `attemptAutoLogin()` method to:
- Double-check Supabase auth state
- Clear local state if no valid Supabase session exists
- Proper error handling and logging

```dart
static Future<bool> attemptAutoLogin() async {
  try {
    await _instance.initializeSession();
    
    // Double-check with Supabase auth state
    final supabase = Supabase.instance.client;
    final currentSession = supabase.auth.currentSession;
    final currentUser = supabase.auth.currentUser;
    
    if (currentSession != null && currentUser != null) {
      // Update local state and fetch user role
      return true;
    } else {
      // Clear local state if no Supabase session
      return false;
    }
  } catch (e) {
    // Error handling
    return false;
  }
}
```

### Issue 2: Document Upload Authentication

**Problem**: Document uploads were attempted without proper authentication checks, causing RLS policy violations.

**Solution**: Added comprehensive authentication checks in DocumentUploadService:

```dart
// Check if user is authenticated
final currentSession = _supabase.auth.currentSession;
if (currentSession == null) {
  throw Exception('User not authenticated. Please sign in first.');
}

// Verify the userId matches the authenticated user
final currentUser = _supabase.auth.currentUser;
if (currentUser?.id != userId) {
  throw Exception('User ID mismatch. Cannot upload documents for another user.');
}

// Check if user exists in profiles table
final profileResponse = await _supabase
    .from('profiles')
    .select('id')
    .eq('id', userId)
    .maybeSingle();

if (profileResponse == null) {
  throw Exception('User profile not found. Please complete registration first.');
}
```

### Issue 3: User Existence Verification

**Problem**: Documents were being uploaded for users that don't exist in the database.

**Solution**: Added database verification before upload attempts:
- Check profiles table for user existence
- Provide clear error messages for missing profiles
- Prevent orphaned document uploads

## Current Workflow

### 1. User Registration Flow
```
Role Selection → Signup (Phone OTP) → Vehicle Type Selection → Vehicle Details → Document Upload
```

### 2. Session Management Flow
```
App Start → AuthWrapper → Auto-login Attempt → Session Validation → Role-based Routing
```

### 3. Document Upload Flow
```
Document Selection → Authentication Check → User Verification → File Validation → Upload → URL Storage
```

## Security Implementation

### Row Level Security (RLS) Policies
- **Storage Policies**: Users can only upload to their own document folders
- **Database Policies**: Users can only access their own records
- **Authentication Required**: All operations require valid Supabase session

### Data Validation
- **File Size**: 5MB maximum limit
- **File Types**: Images (JPG, PNG, etc.) and documents (PDF, DOC, DOCX)
- **User Verification**: User must exist in profiles table
- **Session Validation**: Active Supabase session required

## Error Handling

### Authentication Errors
- Clear error messages for unauthenticated users
- Automatic session cleanup on errors
- Graceful fallback to login screens

### Document Upload Errors
- File size validation with user-friendly messages
- Authentication state verification
- Network error handling with retry mechanisms

## Testing Status

✅ **Session Management**: Fixed synchronization between AuthService and AuthWrapper  
✅ **Document Upload**: Added comprehensive authentication checks  
✅ **User Verification**: Database existence checks before upload  
🔄 **Mobile Testing**: Currently testing on Android device  
🔜 **Complete Flow**: Verify end-to-end driver registration with document upload

## Next Steps

1. **Complete mobile testing** of session persistence and document upload
2. **Verify end-to-end driver registration flow** with all document types
3. **Performance optimization** for large file uploads
4. **Error recovery mechanisms** for failed uploads

## Technical Dependencies

- **Flutter**: Mobile app framework
- **Supabase**: Backend-as-a-Service (Auth + Database + Storage)
- **Firebase**: Push notifications
- **Image Picker**: Camera and gallery access
- **Image Compression**: File size optimization