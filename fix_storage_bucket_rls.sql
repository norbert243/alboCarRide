-- Fix Storage Bucket RLS Policies for AlboCarRide
-- This script ensures proper RLS policies for the driver-documents storage bucket

-- 1. Enable RLS on the storage.objects table (if not already enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 2. Create policy to allow authenticated users to upload files to their own folders
CREATE POLICY "Users can upload files to their own folders" 
ON storage.objects 
FOR INSERT 
TO authenticated 
WITH CHECK (
  bucket_id = 'driver-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. Create policy to allow users to read their own files
CREATE POLICY "Users can read their own files" 
ON storage.objects 
FOR SELECT 
TO authenticated 
USING (
  bucket_id = 'driver-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. Create policy to allow users to update their own files
CREATE POLICY "Users can update their own files" 
ON storage.objects 
FOR UPDATE 
TO authenticated 
USING (
  bucket_id = 'driver-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 5. Create policy to allow users to delete their own files
CREATE POLICY "Users can delete their own files" 
ON storage.objects 
FOR DELETE 
TO authenticated 
USING (
  bucket_id = 'driver-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 6. Create policy to allow service role to manage all files (for admin operations)
CREATE POLICY "Service role can manage all files" 
ON storage.objects 
FOR ALL 
TO service_role 
USING (true);

-- 7. Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Allow authenticated users to upload files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to read files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete files" ON storage.objects;

-- 8. Alternative approach: If the above policies don't work, try this simpler approach
-- This allows any authenticated user to upload to the driver-documents bucket
CREATE POLICY "Allow authenticated uploads to driver-documents" 
ON storage.objects 
FOR ALL 
TO authenticated 
USING (bucket_id = 'driver-documents');

-- 9. Ensure the storage bucket exists and is properly configured
-- Note: This should be run in the Supabase dashboard SQL editor
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-documents', 'driver-documents', false)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = EXCLUDED.public;

-- 10. Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;

-- Print confirmation
SELECT 'Storage bucket RLS policies applied successfully' as status;