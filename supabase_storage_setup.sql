-- Supabase Storage Bucket Setup for AlboCarRide
-- This script creates the required storage bucket and policies for document uploads

-- 1. Create the storage bucket for driver documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents',
  'Driver Documents',
  false, -- Private bucket (only authenticated users can access)
  5242880, -- 5MB file size limit
  ARRAY[
    'image/jpeg',
    'image/png', 
    'image/gif',
    'image/bmp',
    'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Create Row Level Security (RLS) policies for the bucket

-- Policy: Users can upload files to their own folder
-- Path structure: {user_id}/{document_type}/{filename}
CREATE POLICY "Users can upload their own documents" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'driver-documents' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can view their own uploaded files
CREATE POLICY "Users can view their own documents" ON storage.objects
FOR SELECT USING (
  bucket_id = 'driver-documents' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own files
CREATE POLICY "Users can update their own documents" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'driver-documents' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own files
CREATE POLICY "Users can delete their own documents" ON storage.objects
FOR DELETE USING (
  bucket_id = 'driver-documents' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. Enable RLS on storage.objects table (if not already enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 4. Create a function to check if user owns the file
CREATE OR REPLACE FUNCTION storage.user_owns_file(file_path text, user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN (storage.foldername(file_path))[1] = user_id::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_id_name ON storage.objects(bucket_id, name);
CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_id_owner ON storage.objects(bucket_id, owner);

-- 6. Verify the setup
SELECT 
  'Storage bucket created successfully' as status,
  id as bucket_id,
  name as bucket_name,
  public as is_public,
  file_size_limit
FROM storage.buckets 
WHERE id = 'driver-documents';

-- 7. Show the created policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'objects' 
  AND schemaname = 'storage'
ORDER BY policyname;

-- Instructions for execution:
-- 1. Copy this SQL script
-- 2. Go to your Supabase project dashboard
-- 3. Navigate to the SQL Editor
-- 4. Paste and execute this script
-- 5. The storage bucket will be created with proper security policies

-- Note: Make sure you have the necessary permissions to create storage buckets and policies.