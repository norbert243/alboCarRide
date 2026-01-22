import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/services/session_service.dart';
import 'package:path/path.dart' as path;

class ProfilePicturePage extends StatefulWidget {
  const ProfilePicturePage({super.key});

  @override
  State<ProfilePicturePage> createState() => _ProfilePicturePageState();
}

class _ProfilePicturePageState extends State<ProfilePicturePage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _currentProfileUrl;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfilePicture();
  }

  Future<void> _loadCurrentProfilePicture() async {
    setState(() => _isLoading = true);
    try {
      _userId = await SessionService.getUserId();
      if (_userId != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('profile_picture_url')
            .eq('id', _userId!)
            .single();

        _currentProfileUrl = response['profile_picture_url'];
      }
    } catch (e) {
      debugPrint('Error loading profile picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // Validate file size (max 5MB)
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image is too large. Maximum size is 5MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_currentProfileUrl != null || _selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadProfilePicture() async {
    if (_selectedImage == null || _userId == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final fileExt = path.extension(_selectedImage!.path).replaceAll('.', '');
      final fileName = 'profile_$_userId.$fileExt';
      final filePath = 'profile-pictures/$fileName';

      // Upload to Supabase Storage
      await supabase.storage.from('user-uploads').upload(
        filePath,
        _selectedImage!,
        fileOptions: FileOptions(
          contentType: 'image/$fileExt',
          upsert: true,
        ),
      );

      // Get public URL
      final publicUrl = supabase.storage.from('user-uploads').getPublicUrl(filePath);

      // Update profile with new URL
      await supabase.from('profiles').update({
        'profile_picture_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userId!);

      setState(() {
        _currentProfileUrl = publicUrl;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    if (_userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUploading = true);

    try {
      // Update profile to remove URL
      await Supabase.instance.client.from('profiles').update({
        'profile_picture_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userId!);

      setState(() {
        _currentProfileUrl = null;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile Picture'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Current/Selected Profile Picture
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              border: Border.all(
                                color: Colors.blue,
                                width: 3,
                              ),
                              image: _selectedImage != null
                                  ? DecorationImage(
                                      image: FileImage(_selectedImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : _currentProfileUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_currentProfileUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: (_selectedImage == null && _currentProfileUrl == null)
                                ? Icon(
                                    Icons.person,
                                    size: 100,
                                    color: Colors.grey[400],
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions
                  Text(
                    'Tap the camera icon to change your profile picture',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Requirements
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Photo Guidelines',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildGuideline('Use a clear, recent photo of yourself'),
                        _buildGuideline('Make sure your face is clearly visible'),
                        _buildGuideline('Avoid sunglasses or hats'),
                        _buildGuideline('Maximum file size: 5MB'),
                        _buildGuideline('Supported formats: JPG, PNG'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  if (_selectedImage != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadProfilePicture,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Save Profile Picture'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isUploading
                            ? null
                            : () => setState(() => _selectedImage = null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_currentProfileUrl != null
                            ? 'Change Profile Picture'
                            : 'Add Profile Picture'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildGuideline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
