# Document Upload Service Debugging Guide

## Problem Identified
Documents cannot be uploaded to Supabase storage. The main issues are:

1. **Storage bucket not created** - The `driver-documents` bucket doesn't exist
2. **Path structure mismatch** - Incorrect folder structure for RLS policies
3. **Missing debugging information** - Hard to identify the exact error

## Solutions Implemented

### 1. Fixed Path Structure
**Before**: `document_type/user_id/filename`
**After**: `user_id/document_type/filename`

This matches the RLS policies that expect the user ID to be the first folder level.

### 2. Enhanced Error Handling
- Added detailed debug logging for upload attempts
- Better error categorization (bucket not found, permissions, file size)
- Clear error messages for users

### 3. Updated RLS Policies
The storage setup script now correctly handles the path structure.

## Steps to Fix Document Upload

### Step 1: Create the Storage Bucket
Execute the SQL script in your Supabase dashboard:

```sql
-- Copy and paste the content from supabase_storage_setup.sql
-- Go to Supabase Dashboard → SQL Editor → Run the script
```

### Step 2: Verify Bucket Creation
1. Go to Supabase Dashboard → Storage
2. Check if `driver-documents` bucket exists
3. Verify RLS policies are enabled

### Step 3: Test the Upload
1. Run the app
2. Go through driver registration
3. Try uploading a document
4. Check console logs for debug information

## Debugging Steps

### Check Console Logs
Look for these debug messages:
```
Attempting to upload document to: {user_id}/{document_type}/{filename}
File size: {bytes} bytes
MIME type: {mime_type}
Upload response: {response}
Document upload error: {error_details}
```

### Common Error Scenarios

#### Error 1: "Bucket not found"
**Cause**: Storage bucket doesn't exist
**Solution**: Execute the storage setup SQL script

#### Error 2: "Permission denied"
**Cause**: User not authenticated or RLS policies incorrect
**Solution**: 
- Ensure user is logged in
- Check RLS policies match path structure

#### Error 3: "File size exceeds limit"
**Cause**: File larger than 5MB
**Solution**: Compress image or use smaller file

## Testing the Fix

### Test 1: Basic Upload
```dart
final uploadService = DocumentUploadService();
try {
  final url = await uploadService.pickAndUploadDocument(
    source: ImageSource.gallery,
    userId: 'test-user-id',
    documentType: DocumentType.driverLicense,
  );
  print('Upload successful: $url');
} catch (e) {
  print('Upload failed: $e');
}
```

### Test 2: Error Handling
```dart
// Test with invalid bucket name to verify error messages
```

## Expected Behavior After Fix

1. **Successful Upload**: Documents upload to correct path
2. **Proper Error Messages**: Clear explanations for failures
3. **Debug Information**: Detailed logs for troubleshooting
4. **Security**: Proper user isolation via RLS policies

## Folder Structure
```
driver-documents/
├── {user_id}/
│   ├── driver_license/
│   │   └── driver_license_1234567890.jpg
│   ├── vehicle_registration/
│   │   └── registration_1234567890.pdf
│   ├── profile_photo/
│   │   └── profile_1234567890.jpg
│   └── vehicle_photo/
│       └── vehicle_1234567890.jpg
```

## Next Steps

1. **Execute the SQL script** to create the storage bucket
2. **Test the upload functionality** with a real document
3. **Monitor console logs** for any remaining issues
4. **Verify file appears** in Supabase storage dashboard

The fixes should resolve the document upload issues and provide better debugging capabilities.