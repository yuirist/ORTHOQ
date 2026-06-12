import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:uuid/uuid.dart';

import '../../services/cloudinary_service.dart';
import '../../services/email_service.dart';
import '../../utils/patient_email_resolver.dart';
import 'success_page.dart';

class ReferralUploadPage extends StatefulWidget {
  const ReferralUploadPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.patientName,
    required this.phoneNumber,
    required this.email,
    required this.icNumber,
    this.paymentType,
    this.bookingFor,
    this.insuranceProvider,
    this.gender,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.appointmentType,
  });

  final String doctorId;
  final String doctorName;
  final String patientName;
  final String? phoneNumber;
  final String? email;
  final String? icNumber;
  final String? paymentType;
  final String? bookingFor;
  final String? insuranceProvider;
  final String? gender;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String appointmentType;

  @override
  State<ReferralUploadPage> createState() => _ReferralUploadPageState();
}

class _ReferralUploadPageState extends State<ReferralUploadPage> {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _uploadError;

  Future<void> _pickFile() async {
    try {
      final file = await _cloudinaryService.pickReferralFile();
      if (file == null) return;
      setState(() {
        _selectedFile = file;
        _uploadError = null;
      });
    } catch (e) {
      setState(() {
        _uploadError = 'Error picking file: $e';
      });
    }
  }

  Future<void> _uploadAndSave() async {
    if (_selectedFile == null) {
      setState(() => _uploadError = 'Please select a file to upload');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _uploadError = 'User not logged in');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final referralLetterUrl =
          await _cloudinaryService.uploadReferralLetter(_selectedFile!);

      final appointmentId = const Uuid().v4();
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId);

      final appointmentDateNormalized = DateTime(
        widget.appointmentDate.year,
        widget.appointmentDate.month,
        widget.appointmentDate.day,
      );

      await appointmentRef.set({
        'id': appointmentId,
        'referralLetterUrl': referralLetterUrl,
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'patientId': user.uid,
        'patientName': widget.patientName,
        'status': 'pending',
        'appointmentType': widget.appointmentType,
        'patientType': 'New',
        'appointmentDate': Timestamp.fromDate(appointmentDateNormalized),
        'appointmentTime': widget.appointmentTime,
        'durationMinutes': 15,
        'phoneNumber': widget.phoneNumber,
        'email': widget.email,
        'icNumber': widget.icNumber,
        'paymentType': widget.paymentType,
        'bookingFor': widget.bookingFor,
        if (widget.insuranceProvider != null)
          'insuranceProvider': widget.insuranceProvider,
        'gender': widget.gender,
        'createdAt': FieldValue.serverTimestamp(),
        'referralVerified': false,
        'hasRescheduleRequest': false,
        'hasDoctorScheduleChange': false,
      });

      final recipient = await PatientEmailResolver().resolve(
            data: {'email': widget.email},
            patientId: user.uid,
            fallbackEmail: widget.email,
          );
      if (recipient != null && recipient.isNotEmpty) {
        await EmailService().sendBookingPendingEmail(recipient, widget.patientName);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessPage(
            appointmentId: appointmentId,
            doctorName: widget.doctorName,
            appointmentDate: widget.appointmentDate,
            appointmentTime: widget.appointmentTime,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Error uploading file: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Upload Referral Letter'),
        backgroundColor: OrthoqColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/LOGO ORTHOQ.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Upload Referral Letter',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: OrthoqColors.navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please upload your referral letter (PDF or image)',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: _isUploading ? null : _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile == null
                              ? Icons.upload_file
                              : Icons.check_circle,
                          size: 64,
                          color: _selectedFile == null
                              ? Colors.grey
                              : Colors.green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFile == null
                              ? 'Tap to select file'
                              : _selectedFile!.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _selectedFile == null
                                ? Colors.grey
                                : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _isPdfSelected
                                ? 'PDF selected'
                                : 'Image selected',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_uploadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_uploadError != null) const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading || _selectedFile == null
                    ? null
                    : _uploadAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrthoqColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Upload & Book Appointment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OrthoqColors.lightSlate.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: OrthoqColors.navy,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Accepted formats: ${CloudinaryService.referralAllowedExtensionsHint}\n'
                        'Maximum file size: 10MB',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isPdfSelected {
    final name = _selectedFile?.name.toLowerCase() ?? '';
    return name.endsWith('.pdf');
  }
}
