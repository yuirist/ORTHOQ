import 'package:flutter/material.dart';

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
  late final TextEditingController _imageUrlController;
  late bool _isActive;

  final DoctorService _doctorService = DoctorService();
  bool _saving = false;

  void _onUrlChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _nameController = TextEditingController(text: d.name);
    _specializationController = TextEditingController(text: d.specialization);
    _credentialsController = TextEditingController(text: d.credentials ?? '');
    _imageUrlController = TextEditingController(text: d.imageUrl ?? '');
    _isActive = d.isActive;
    _imageUrlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _imageUrlController.removeListener(_onUrlChanged);
    _nameController.dispose();
    _specializationController.dispose();
    _credentialsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  static bool _looksLikeHttpUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    final u = Uri.tryParse(s);
    if (u == null || !u.hasScheme || u.host.isEmpty) return false;
    return u.isScheme('https') || u.isScheme('http');
  }

  Widget _preview() {
    final url = DoctorService.normalizeDoctorImageUrl(_imageUrlController.text);
    if (!_looksLikeHttpUrl(url)) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: ColoredBox(
          color: Colors.grey.shade200,
          child: Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade500),
        ),
      );
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
            child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade500),
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

    setState(() => _saving = true);
    try {
      await _doctorService.updateDoctorFromAdmin(
        doctorId: widget.doctor.id,
        name: _nameController.text,
        specialization: _specializationController.text,
        credentials: _credentialsController.text,
        imageUrl: _imageUrlController.text,
        isActive: _isActive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor updated'), backgroundColor: Colors.green),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Doctor'),
        backgroundColor: const Color(0xFF1A365D),
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
                    Text(
                      'Hospital: Hospital Kajang',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
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
                    TextFormField(
                      controller: _imageUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Doctor Image URL (Cloudinary Link)',
                        hintText: 'https://res.cloudinary.com/...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Preview', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _preview(),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active (visible to patients)'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A365D),
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
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
