import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';

class AdminEditDoctorScreen extends StatefulWidget {
  final DoctorModel doctor;

  const AdminEditDoctorScreen({super.key, required this.doctor});

  @override
  State<AdminEditDoctorScreen> createState() => _AdminEditDoctorScreenState();
}

class _AdminEditDoctorScreenState extends State<AdminEditDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specializationController;
  late final TextEditingController _credentialsController;
  late final String _imageUrl;
  late final String _hospital;
  late bool _isActive;

  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  final DoctorService _doctorService = DoctorService();
  bool _saving = false;
  String _loadingMessage = 'Saving changes…';

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _nameController = TextEditingController(text: d.name);
    _specializationController = TextEditingController(text: d.specialization);
    _credentialsController = TextEditingController(text: d.credentials ?? '');
    _imageUrl = d.imageUrl ?? '';
    _hospital = d.hospital?.trim().isNotEmpty == true
        ? d.hospital!.trim()
        : 'Hospital Kajang';
    _isActive = d.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _credentialsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_saving) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _uploadDoctorImage(File imageFile) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef =
        FirebaseStorage.instance.ref().child('doctors').child(fileName);

    final snapshot = await storageRef.putFile(imageFile);
    return snapshot.ref.getDownloadURL();
  }

  static bool _looksLikeHttpUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    final u = Uri.tryParse(s);
    if (u == null || !u.hasScheme || u.host.isEmpty) return false;
    return u.isScheme('https') || u.isScheme('http');
  }

  Widget _previewPlaceholder() {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: ColoredBox(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              'Tap to select photo',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_selectedImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _selectedImageFile!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _previewPlaceholder(),
        ),
      );
    }

    final url = DoctorService.normalizeDoctorImageUrl(_imageUrl);
    if (!_looksLikeHttpUrl(url)) {
      return _previewPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: 160,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(
          height: 160,
          child: ColoredBox(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    setState(() {
      _saving = true;
      _loadingMessage = _selectedImageFile != null
          ? 'Uploading photo…'
          : 'Saving changes…';
    });

    try {
      var imageUrlToSave = _imageUrl;

      if (_selectedImageFile != null) {
        imageUrlToSave = await _uploadDoctorImage(_selectedImageFile!);
        if (mounted) {
          setState(() => _loadingMessage = 'Saving changes…');
        }
      }

      await _doctorService.updateDoctorFromAdmin(
        doctorId: widget.doctor.id,
        name: _nameController.text,
        specialization: _specializationController.text,
        credentials: _credentialsController.text,
        imageUrl: imageUrlToSave,
        hospital: _hospital,
        isActive: _isActive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor updated'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _loadingMessage = 'Saving changes…';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Doctor'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specializationController,
                      decoration: const InputDecoration(
                        labelText: 'Specialization',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _credentialsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Credentials',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Preview',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _saving ? null : _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: _preview(),
                      ),
                    ),
                    if (_selectedImageFile != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _selectedImageFile = null),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove new photo'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active (visible to patients)'),
                      value: _isActive,
                      onChanged: _saving ? null : (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrthoqColors.slateNavy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Save changes',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_saving)
            const ModalBarrier(dismissible: false, color: Colors.black26),
          if (_saving)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
