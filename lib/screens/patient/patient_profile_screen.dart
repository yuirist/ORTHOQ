import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validation_utils.dart';
import 'ai_assistant_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.currentUserData;
    if (userData != null) {
      _fullNameController.text = userData.fullName;
      _phoneNumberController.text = userData.phoneNumber;
      _emailController.text = userData.email;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Opens gallery, uploads to Firebase Storage, and saves URL to Firestore.
  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingPhoto) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to update your profile photo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);

      final userId = currentUser.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$userId.jpg');

      final uploadTask = ref.putFile(File(pickedFile.path));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await context.read<AuthProvider>().applyLoginSession(
              firebaseUser: currentUser,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final normalizedPhone =
          ValidationUtils.normalizePhoneNumber(_phoneNumberController.text);

      await authProvider.updateProfile(
        fullName: _fullNameController.text.trim(),
        phoneNumber: normalizedPhone,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userData = authProvider.currentUserData;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: OrthoqColors.slateNavy,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                )
              else
                TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _ProfileAvatar(
                    fullName: userData?.fullName ?? '',
                    profileImageUrl: userData?.profileImageUrl,
                    isUploading: _isUploadingPhoto,
                    onTap: _pickAndUploadProfilePhoto,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap photo to change',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OrthoqColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _fullNameController,
                    enabled: _isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneNumberController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: ValidationUtils.validateMalaysianPhone,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => openAiAssistant(context),
                      icon: const Icon(Icons.smart_toy_rounded),
                      label: const Text('AI Assistant'),
                      style: FilledButton.styleFrom(
                        backgroundColor: OrthoqColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tappable profile avatar with network image, initial fallback, and upload overlay.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.fullName,
    required this.profileImageUrl,
    required this.isUploading,
    required this.onTap,
  });

  final String fullName;
  final String? profileImageUrl;
  final bool isUploading;
  final VoidCallback onTap;

  static const double _radius = 50;

  String get _initial {
    if (fullName.trim().isEmpty) return 'U';
    return fullName.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = profileImageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: _radius,
            backgroundColor: OrthoqColors.slateNavy,
            backgroundImage: hasImage ? NetworkImage(url) : null,
            child: hasImage
                ? null
                : Text(
                    _initial,
                    style: TextStyle(
                      fontSize: 48,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (isUploading)
            Container(
              width: _radius * 2,
              height: _radius * 2,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: OrthoqColors.navy,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
