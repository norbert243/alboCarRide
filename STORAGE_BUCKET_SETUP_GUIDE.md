# Supabase Storage Bucket Setup Guide

## Problem Identified
**Error**: `Storage upload failed: Bucket not found`
**Location**: Document upload functionality in driver verification process

## Root Cause
The application is trying to upload documents to a Supabase storage bucket named `driver-documents`, but this bucket doesn't exist in your Supabase project.

## Solution

### Step 1: Create the Storage Bucket

Execute the following SQL script in your Supabase SQL Editor:

```sql
-- Copy and paste the entire content from supabase_storage_setup.sql
-- Or execute the script directly in Supabase dashboard
```

**Instructions for execution:**
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the entire content from [`supabase_storage_setup.sql`](supabase_storage_setup.sql)
4. Click **Run** to execute the script
5. Verify the bucket was created successfully

### Step 2: Verify Bucket Creation

After executing the script, check that:
1. The bucket `driver-documents` exists in **Storage** section
2. RLS policies are enabled for the bucket
3. File size limit is set to 5MB
4. Supported MIME types are configured

### Step 3: Test the Setup

**Manual Testing Steps:**
1. Run the application
2. Go through driver registration process
3. Reach the verification page
4. Try uploading a document (driver license, etc.)
5. Verify upload succeeds without errors

## Technical Details

### Storage Bucket Configuration
- **Bucket ID**: `driver-documents`
- **Visibility**: Private (authenticated users only)
- **File Size Limit**: 5MB
- **Supported Formats**: Images (JPEG, PNG, GIF, BMP, WebP) and Documents (PDF, DOC, DOCX)

### Security Policies
- **Upload Policy**: Users can only upload to their own user folder
- **View Policy**: Users can only view their own uploaded files
- **Update Policy**: Users can only update their own files
- **Delete Policy**: Users can only delete their own files

### Folder Structure
```
driver-documents/
├── driver_license/
│   └── {user_id}/
│       └── driver_license_1234567890.jpg
├── vehicle_registration/
│   └── {user_id}/
│       └── registration_1234567890.pdf
├── profile_photo/
│   └── {user_id}/
│       └── profile_1234567890.jpg
└── vehicle_photo/
    └── {user_id}/
        └── vehicle_1234567890.jpg
```

## Code Changes Made

### Enhanced Error Handling
The [`document_upload_service.dart`](lib/services/document_upload_service.dart) has been updated with better error messages:

```dart
// Before: Generic error message
throw Exception('Storage upload failed: ${e.message}');

// After: Specific bucket not found error
if (e.message?.contains('bucket') ?? false) {
  throw Exception('Storage bucket not found. Please ensure the "driver-documents" bucket is created in Supabase Storage.');
}
```

## Testing Instructions

### Test Scenario 1: Bucket Setup Verification
1. **Action**: Execute the SQL setup script
2. **Expected**: Bucket created with proper policies
3. **Verification**: Check Supabase Storage dashboard

### Test Scenario 2: Document Upload Test
1. **Action**: Upload a driver license image
2. **Expected**: Upload succeeds without errors
3. **Verification**: File appears in storage bucket

### Test Scenario 3: Error Handling Test
1. **Action**: Try upload before bucket setup
2. **Expected**: Clear error message about missing bucket
3. **Verification**: User receives informative error

## Troubleshooting

### Common Issues and Solutions

**Issue 1**: "Bucket not found" error persists
- **Solution**: Verify the bucket ID matches exactly `driver-documents`

**Issue 2**: Permission denied errors
- **Solution**: Check RLS policies are properly configured

**Issue 3**: File size too large
- **Solution**: Ensure uploaded files are under 5MB limit

**Issue 4**: Unsupported file type
- **Solution**: Check file extension against supported formats

### Debugging Steps
1. Check Supabase Storage logs for upload attempts
2. Verify user authentication status
3. Confirm bucket exists in Supabase dashboard
4. Test with different file types and sizes

## Security Considerations

- **Private Bucket**: Files are only accessible to authenticated users
- **User Isolation**: Each user can only access their own files
- **File Validation**: Server-side validation of file types and sizes
- **Secure URLs**: Public URLs are generated with proper access controls

## Performance Optimization

- **Image Compression**: Automatic compression for large images
- **File Size Limits**: Prevents storage abuse
- **Efficient Queries**: Optimized storage operations
- **Caching**: Appropriate caching strategies for frequently accessed files

## Next Steps

After setting up the storage bucket:

1. **Test Complete Flow**: Verify document upload works end-to-end
2. **Monitor Usage**: Watch storage usage and performance
3. **Scale if Needed**: Adjust file size limits or storage capacity
4. **Backup Strategy**: Implement regular backups of important documents

The storage bucket setup is essential for the driver verification process to function correctly. Once configured, users will be able to upload their verification documents seamlessly.