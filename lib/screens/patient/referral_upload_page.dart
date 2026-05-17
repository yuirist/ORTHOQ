import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../services/email_service.dart';
import 'success_page.dart';

class ReferralUploadPage extends StatefulWidget {
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

  @override
  State<ReferralUploadPage> createState() => _ReferralUploadPageState();
}

class _ReferralUploadPageState extends State<ReferralUploadPage> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _uploadError;

  final cloudinary = CloudinaryPublic(
    'dfz9svj5s',
    'orthoq_app',
    cache: false,
  );

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single;
          _uploadError = null;
        });
      }
    } catch (e) {
      setState(() {
        _uploadError = 'Error picking file: $e';
      });
    }
  }

  Future<void> _uploadAndSave() async {
    if (_selectedFile == null || _selectedFile!.path == null) {
      setState(() {
        _uploadError = 'Please select a file to upload';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _uploadError = 'User not logged in';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      // Upload to Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _selectedFile!.path!,
          resourceType: CloudinaryResourceType.Auto,
        ),
      );

      if (response.secureUrl.isEmpty) {
        throw 'Failed to get secure URL from Cloudinary';
      }

      final referralLetterUrl = response.secureUrl;

      // Save booking to Firestore
      final appointmentId = const Uuid().v4();
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId);

      // Normalize appointmentDate to start of day for exact date matching
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

      final recipient = widget.email?.trim();
      if (recipient != null && recipient.isNotEmpty) {
        await EmailService().sendBookingPendingEmail(recipient, widget.patientName);
      }

      if (mounted) {
        // Navigate to Success Page
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
      }
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
      appBar: AppBar(
        title: const Text('Upload Referral Letter'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/LOGO ORTHOQ.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Upload Referral Letter',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please upload your referral letter (PDF or Image)',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // File Selection Card
              Card(
                elevation: 2,
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
                            'File selected',
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

              // Error Message
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

              // Upload Button
              ElevatedButton(
                onPressed: _isUploading || _selectedFile == null
                    ? null
                    : _uploadAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrthoqColors.slateNavy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Upload & Book Appointment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Info Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: OrthoqColors.slateNavy,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Accepted formats: PDF, JPG, JPEG, PNG\nMaximum file size: 10MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
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
}


