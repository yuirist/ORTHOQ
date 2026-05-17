import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/doctor_service.dart';
import '../../utils/validation_utils.dart';
import 'package:uuid/uuid.dart';
import 'book_appointment_screen.dart';

class PatientInformationScreen extends StatefulWidget {
  final String doctorId;
  final String appointmentType;

  const PatientInformationScreen({
    super.key,
    required this.doctorId,
    required this.appointmentType,
  });

  @override
  State<PatientInformationScreen> createState() => _PatientInformationScreenState();
}

class _PatientInformationScreenState extends State<PatientInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _icNumberController = TextEditingController();
  
  String _selectedPackage = 'self_pay'; // 'self_pay' or 'insurance'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with logged-in user's data if available
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.currentUserData;
    if (userData != null) {
      _fullNameController.text = userData.fullName;
      _emailController.text = userData.email;
      _whatsappNumberController.text = userData.phoneNumber;
      _icNumberController.text = userData.icNumber ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _whatsappNumberController.dispose();
    _emailController.dispose();
    _icNumberController.dispose();
    super.dispose();
  }

  Future<void> _savePatientInformation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid ?? '';

      // Verify doctor exists
      final doctorService = DoctorService();
      final doctor = await doctorService.getDoctorById(widget.doctorId);
      if (doctor == null) {
        throw 'Doctor not found';
      }

      // Normalize phone and IC numbers before saving (strip hyphens)
      final normalizedPhone = ValidationUtils.normalizePhoneNumber(_whatsappNumberController.text);
      final normalizedIC = ValidationUtils.normalizeICNumber(_icNumberController.text);
      final gender = ValidationUtils.extractGenderFromIC(_icNumberController.text);

      // Update patient information in Firestore
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(userId)
          .set({
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': normalizedPhone,
        'whatsappNumber': normalizedPhone,
        'email': _emailController.text.trim(),
        'icNumber': normalizedIC,
        'gender': gender,
        'packageType': _selectedPackage,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'icNumber': normalizedIC,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Store patient information in a separate collection for appointment details
      final patientInfoId = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('patient_appointment_info')
          .doc(patientInfoId)
          .set({
        'patientId': userId,
        'appointmentType': widget.appointmentType,
        'doctorId': widget.doctorId,
        'fullName': _fullNameController.text.trim(),
        'whatsappNumber': normalizedPhone,
        'email': _emailController.text.trim(),
        'icNumber': normalizedIC,
        'gender': gender,
        'packageType': _selectedPackage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Navigate to book appointment screen
        // The new booking flow will collect all information in its own steps
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const BookAppointmentScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving information: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Center(
                child: Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Image.asset(
                    'assets/images/LOGO ORTHOQ.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Full Name Field
              const Text(
                'Full Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // WhatsApp Number Field
              const Text(
                'WhatsApp Number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _whatsappNumberController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter your WhatsApp number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                ),
                validator: ValidationUtils.validateMalaysianPhone,
              ),

              const SizedBox(height: 20),

              // Email Field
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(Icons.email, color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // IC No. / Passport No. Field
              const Text(
                'IC No. / Passport No.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _icNumberController,
                decoration: InputDecoration(
                  hintText: 'Enter your IC or Passport number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(Icons.badge, color: Colors.grey),
                ),
                validator: ValidationUtils.validateMalaysianIC,
              ),

              const SizedBox(height: 32),

              // Package Section
              const Text(
                'Package',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Package Radio Buttons
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPackage = 'self_pay';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPackage == 'self_pay'
                                ? OrthoqColors.slateNavy
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'self_pay',
                              groupValue: _selectedPackage,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPackage = value!;
                                });
                              },
                              activeColor: OrthoqColors.slateNavy,
                            ),
                            const Text(
                              'Self Pay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPackage = 'insurance';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPackage == 'insurance'
                                ? OrthoqColors.slateNavy
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'insurance',
                              groupValue: _selectedPackage,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPackage = value!;
                                });
                              },
                              activeColor: OrthoqColors.slateNavy,
                            ),
                            const Text(
                              'Insurance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Next Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePatientInformation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrthoqColors.slateNavy,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


