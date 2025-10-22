-- Fix for driver-documents storage bucket RLS policies
-- Run this in your Supabase SQL editor

-- 1. Create the storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-documents', 'driver-documents', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Create RLS policies for the storage bucket
-- Allow authenticated users to upload files to their own folder
CREATE POLICY "Users can upload their own documents"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'driver-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read their own documents
CREATE POLICY "Users can view their own documents"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'driver-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to update their own documents
CREATE POLICY "Users can update their own documents"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'driver-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete their own documents
CREATE POLICY "Users can delete their own documents"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'driver-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow public access to read documents (if needed for verification)
CREATE POLICY "Public can view documents"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'driver-documents');