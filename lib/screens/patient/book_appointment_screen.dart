import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/doctor_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/doctor_model.dart';
import '../../widgets/slot_availability_checker.dart';
import '../../utils/validation_utils.dart';
import 'referral_upload_page.dart';
import 'confirmation_page.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  /// Insurance options when payment type is Insurance (exact labels).
  static const List<String> kInsuranceProviders = [
    'PUBLIC BANK BERHAD',
    'SME CORPORATION MALAYSIA',
    'UKM HOLDINGS SDN BHD',
  ];

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final PageController _pageController = PageController();
  final DoctorService _doctorService = DoctorService();
  
  int _currentStep = 0;
  
  // Step 0: Patient Type
  String? _patientType; // 'New' or 'Follow-up'
  
  // Step 1: Doctor Selection
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  
  // Step 2: Patient Information
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _icNumberController = TextEditingController();
  String? _paymentType; // 'Self-pay' or 'Insurance'
  String? _insuranceProvider;

  /// Who the appointment is for: logged-in profile (`Self`) vs manual entry (`Others`).
  String _bookingFor = 'Self';
  bool _patientInfoReadOnly = true;

  // Step 3: Date & Time Selection
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  bool _isLoading = false;
  bool _isCheckingSlot = false; // For pre-confirmation slot check
  bool _isCheckingEligibility = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfileIntoPatientFields();
      if (mounted) {
        setState(() {
          _bookingFor = 'Self';
          _patientInfoReadOnly = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _icNumberController.dispose();
    super.dispose();
  }

  void _clearPatientInformationFields() {
    _fullNameController.clear();
    _phoneNumberController.clear();
    _emailController.clear();
    _icNumberController.clear();
  }

  Future<void> _loadProfileIntoPatientFields() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.currentUserData;
    final userId = authProvider.currentUser?.uid;

    if (userData != null) {
      _fullNameController.text = userData.fullName;
      _phoneNumberController.text = userData.phoneNumber;
      _emailController.text = userData.email;
      _icNumberController.text = userData.icNumber ?? '';
    }

    if (userId != null) {
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (profileDoc.exists) {
        final profileData = profileDoc.data() ?? <String, dynamic>{};
        if (_fullNameController.text.trim().isEmpty) {
          _fullNameController.text = profileData['fullName']?.toString() ?? '';
        }
        if (_phoneNumberController.text.trim().isEmpty) {
          _phoneNumberController.text =
              profileData['phoneNumber']?.toString() ?? '';
        }
        if (_emailController.text.trim().isEmpty) {
          _emailController.text = profileData['email']?.toString() ?? '';
        }
        if (_icNumberController.text.trim().isEmpty) {
          _icNumberController.text = profileData['icNumber']?.toString() ?? '';
        }
      }

      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(userId)
          .get();
      if (patientDoc.exists) {
        final p = patientDoc.data() ?? <String, dynamic>{};
        if (_fullNameController.text.trim().isEmpty) {
          _fullNameController.text = p['fullName']?.toString() ?? '';
        }
        if (_phoneNumberController.text.trim().isEmpty) {
          _phoneNumberController.text = p['phoneNumber']?.toString() ?? '';
        }
        if (_emailController.text.trim().isEmpty) {
          _emailController.text = p['email']?.toString() ?? '';
        }
        if (_icNumberController.text.trim().isEmpty) {
          _icNumberController.text = p['icNumber']?.toString() ?? '';
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _applyBookingRecipientPrefill() async {
    if (_bookingFor != 'Self') return;
    await _loadProfileIntoPatientFields();
    if (mounted) {
      setState(() {
        _patientInfoReadOnly = true;
      });
    }
  }

  Future<void> _onBookingForChanged(String? value) async {
    if (value == null) return;
    if (value == 'Others') {
      setState(() {
        _bookingFor = 'Others';
        _clearPatientInformationFields();
        _patientInfoReadOnly = false;
      });
    } else {
      setState(() {
        _bookingFor = 'Self';
        _patientInfoReadOnly = true;
      });
      await _loadProfileIntoPatientFields();
      if (mounted) setState(() {});
    }
  }

  void _nextStep() {
    if (_currentStep == 2) {
      // Validate form before proceeding
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    
    // Calculate max step based on patient type
    final maxStep = _patientType == 'New' ? 2 : 3; // New: 0,1,2 | Follow-up: 0,1,2,3
    
    if (_currentStep < maxStep) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == maxStep) {
      // This is the final step, save booking
      _saveBooking();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Patient Type Selection
        return _patientType != null;
      case 1: // Doctor Selection
        return _selectedDoctorId != null;
      case 2: // Information Page
        final formValid = _formKey.currentState?.validate() ?? false;
        if (!formValid || _paymentType == null) return false;
        if (_paymentType == 'Insurance') {
          final p = _insuranceProvider;
          return p != null &&
              p.isNotEmpty &&
              BookAppointmentScreen.kInsuranceProviders.contains(p);
        }
        return true;
      case 3: // Date & Time Selection (only for Follow-up)
        return _selectedDate != null && _selectedTime != null;
      default:
        return false;
    }
  }

  Future<void> _saveBooking() async {
    if (!_canProceedToNextStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_patientType == 'Follow-up') {
      setState(() {
        _isCheckingEligibility = true;
      });
      final isEligible = await _isEligibleForFollowUp();
      if (mounted) {
        setState(() {
          _isCheckingEligibility = false;
        });
      }
      if (!isEligible) {
        if (mounted) {
          _showFollowUpRestrictedSheet();
        }
        return;
      }
    }

    // Validate and normalize phone and IC numbers before passing to next page
    // Validation already passed in form, but ensure data is clean
    final phoneValidationError = ValidationUtils.validateMalaysianPhone(_phoneNumberController.text);
    final icValidationError = ValidationUtils.validateMalaysianIC(_icNumberController.text);
    
    if (phoneValidationError != null || icValidationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(phoneValidationError ?? icValidationError ?? 'Invalid input'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Normalize phone and IC numbers (strip hyphens)
    final normalizedPhone = ValidationUtils.normalizePhoneNumber(_phoneNumberController.text);
    final normalizedIC = ValidationUtils.normalizeICNumber(_icNumberController.text);
    
    // Extract gender from IC number (must be done before normalization, but extractGenderFromIC handles it)
    final gender = ValidationUtils.extractGenderFromIC(_icNumberController.text);

    // For new patients, navigate to ReferralUploadPage (no date/time needed)
    if (_patientType == 'New') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReferralUploadPage(
              doctorId: _selectedDoctorId!,
              doctorName: _selectedDoctorName!,
              patientName: _fullNameController.text.trim(),
              phoneNumber: normalizedPhone,
              email: _emailController.text.trim(),
              icNumber: normalizedIC,
              gender: gender,
              paymentType: _paymentType,
              bookingFor: _bookingFor,
              insuranceProvider:
                  _paymentType == 'Insurance' ? _insuranceProvider : null,
              appointmentDate: DateTime.now(), // Placeholder date for new patients
              appointmentTime: '', // Awaiting staff confirmation for new patients
              appointmentType: 'new_patient',
            ),
          ),
        );
      }
    } else {
      // For follow-up patients: Pre-confirmation slot check before navigating
      final timeString = _formatTimeOfDay(_selectedTime!);
      
      // Normalize appointmentDate to start of day for exact date matching
      final normalizedDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );

      // Set loading state for slot check
      setState(() {
        _isCheckingSlot = true;
      });

      try {
        // Pre-confirmation slot check using 4-field index query:
        // appointmentTime, doctorId, status, appointmentDate
        final startOfDay = normalizedDate;
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final query = FirebaseFirestore.instance
            .collection('appointments')
            .where('appointmentTime', isEqualTo: timeString)
            .where('doctorId', isEqualTo: _selectedDoctorId!)
            .where('status', isEqualTo: 'confirmed')
            .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
            .orderBy('appointmentDate');

        final snapshot = await query.get();

        // Conflict handling: If query returns any documents, slot is taken
        if (snapshot.docs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _isCheckingSlot = false;
              // Clear selected time to remove it from the grid
              _selectedTime = null;
            });

            // Show conflict message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This slot was just booked. Please choose another.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return; // Do NOT navigate
        }

        // Successful check: No conflicts found, proceed with navigation
        if (mounted) {
          setState(() {
            _isCheckingSlot = false;
          });

          // Navigate to ConfirmationPage with all necessary data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmationPage(
                doctorId: _selectedDoctorId!,
                doctorName: _selectedDoctorName!,
                appointmentDate: normalizedDate,
                appointmentTime: timeString,
                patientType: 'Follow-up',
                patientName: _fullNameController.text.trim(),
                phoneNumber: normalizedPhone,
                email: _emailController.text.trim(),
                icNumber: normalizedIC,
                gender: gender,
                paymentType: _paymentType,
                bookingFor: _bookingFor,
                insuranceProvider:
                    _paymentType == 'Insurance' ? _insuranceProvider : null,
              ),
            ),
          );
        }
      } catch (e) {
        // Error during slot check
        if (mounted) {
          setState(() {
            _isCheckingSlot = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error checking slot availability: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<bool> _isEligibleForFollowUp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = (authProvider.currentUserData?.email ?? _emailController.text).trim();
    if (email.isEmpty) {
      return false;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('email', isEqualTo: email)
          .where('referralVerified', isEqualTo: true)
          .get();

      final hasApprovedNewPatient = snapshot.docs.any((doc) {
        final data = doc.data();
        final patientType = (data['patientType']?.toString() ?? '').toLowerCase();
        return patientType == 'new' || patientType == 'new patient';
      });

      return hasApprovedNewPatient;
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().toLowerCase();
        if (errorText.contains('failed-precondition') || errorText.contains('index')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Eligibility check is preparing. Please try again in a moment.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to validate follow-up eligibility: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return false;
    }
  }

  void _showFollowUpRestrictedSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Follow-up Booking Restricted',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A365D),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Our records indicate you have not yet completed a New Patient registration with an approved referral letter.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _patientType = 'New';
                      _currentStep = 0;
                    });
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    _applyBookingRecipientPrefill();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A365D),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Book as New Patient',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          // Progress Indicator - dynamic based on patient type
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFFF7FAFC),
            child: Row(
              children: List.generate(
                _patientType == 'New' ? 3 : 4, // 3 steps for New, 4 for Follow-up
                (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? const Color(0xFF1A365D)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of ${_patientType == 'New' ? 3 : 4}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A365D),
            ),
          ),
          const SizedBox(height: 8),

          // Page View - always include all steps, but skip step 3 for new patients
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep0PatientType(),
                _buildStep1DoctorSelection(),
                _buildStep2InformationPage(),
                _buildStep3DateTimeSelection(), // Always include, but navigation skips for new patients
              ],
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF1A365D)),
                      ),
                      child: const Text(
                        'Previous',
                        style: TextStyle(color: Color(0xFF1A365D)),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isCheckingSlot || _isCheckingEligibility)
                        ? null
                        : (_canProceedToNextStep() ? _nextStep : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A365D),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: (_isLoading || _isCheckingSlot || _isCheckingEligibility)
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
                            (_patientType == 'New' && _currentStep == 2) || 
                            (_patientType == 'Follow-up' && _currentStep == 3)
                                ? 'Confirm Booking'
                                : 'Next',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 0: Patient Type Selection
  Widget _buildStep0PatientType() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Patient Type',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Are you a new patient or returning for a follow-up?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          
          // New Patient Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _patientType == 'New'
                    ? const Color(0xFF1A365D)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _patientType = 'New';
                });
                _applyBookingRecipientPrefill();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'New',
                      groupValue: _patientType,
                      onChanged: (value) {
                        setState(() {
                          _patientType = value;
                        });
                        _applyBookingRecipientPrefill();
                      },
                      activeColor: const Color(0xFF1A365D),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Patient',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'First-time visit to the clinic',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Follow-up Patient Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _patientType == 'Follow-up'
                    ? const Color(0xFF1A365D)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _patientType = 'Follow-up';
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'Follow-up',
                      groupValue: _patientType,
                      onChanged: (value) {
                        setState(() {
                          _patientType = value;
                        });
                      },
                      activeColor: const Color(0xFF1A365D),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Follow-up Patient',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Returning patient for follow-up visit',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Requires a previously approved new patient appointment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A365D),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Doctor Selection
  Widget _buildStep1DoctorSelection() {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger a refresh by rebuilding the StreamBuilder
        setState(() {});
        // Wait a moment for the stream to refresh
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: const Color(0xFF1A365D),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Doctor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your preferred orthopaedic specialist',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            
            // Doctor List with StreamBuilder
            StreamBuilder<List<DoctorModel>>(
              stream: _doctorService.getActiveDoctors(),
              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A365D)),
                      ),
                    ),
                  );
                }

                // Error state
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final errorMessage = error.toString();
                  
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Connection Error',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unable to load doctors. Please check your internet connection and try again.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Error Details:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  errorMessage,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                    fontFamily: 'monospace',
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                // Trigger rebuild to retry
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A365D),
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final doctors = snapshot.data ?? [];

                // Empty state
                if (doctors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_hospital_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Doctors Available',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No doctors currently available at Hospital Kajang',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please check back later or contact the hospital for assistance.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Success state - Display doctors list using ListView.builder
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: doctors.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      final isSelected = _selectedDoctorId == doctor.id;
                      return _DoctorCard(
                        doctor: doctor,
                        isSelected: isSelected,
                        onTap: () {
                          // Safely get doctor name and ID
                          final doctorId = doctor.id.isNotEmpty ? doctor.id : '';
                          final doctorName = doctor.name.isNotEmpty ? doctor.name : 'Unknown Doctor';
                          
                          if (doctorId.isNotEmpty) {
                            setState(() {
                              _selectedDoctorId = doctorId;
                              _selectedDoctorName = doctorName;
                            });
                            // Navigate to next step
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted && _canProceedToNextStep()) {
                                _nextStep();
                              }
                            });
                          } else {
                            // Show error if doctor ID is invalid
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unable to select doctor. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Information Page
  Widget _buildStep2InformationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please provide your details',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Who is this appointment for?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Myself'),
                    value: 'Self',
                    groupValue: _bookingFor,
                    onChanged: _onBookingForChanged,
                    activeColor: const Color(0xFF1A365D),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Others (e.g., Child/Family)',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'Others',
                    groupValue: _bookingFor,
                    onChanged: _onBookingForChanged,
                    activeColor: const Color(0xFF1A365D),
                  ),
                ),
              ],
            ),
            // Show message for new patients about referral verification
            if (_patientType == 'New') ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Staff will review your referral letter before you can pick a slot.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Full Name
            TextFormField(
              controller: _fullNameController,
              readOnly: _patientInfoReadOnly,
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
            const SizedBox(height: 20),

            // Phone Number
            TextFormField(
              controller: _phoneNumberController,
              readOnly: _patientInfoReadOnly,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                hintText: 'e.g., 012-3456789 or 0123456789',
              ),
              validator: ValidationUtils.validateMalaysianPhone,
            ),
            const SizedBox(height: 20),

            // Email
            TextFormField(
              controller: _emailController,
              readOnly: _patientInfoReadOnly,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
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

            // IC Number
            TextFormField(
              controller: _icNumberController,
              readOnly: _patientInfoReadOnly,
              decoration: const InputDecoration(
                labelText: 'IC Number',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
                hintText: 'e.g., 990101-14-5678',
              ),
              validator: ValidationUtils.validateMalaysianIC,
            ),
            const SizedBox(height: 32),

            // Payment Type
            const Text(
              'Payment Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Self-pay'),
                    value: 'Self-pay',
                    groupValue: _paymentType,
                    onChanged: (value) {
                      setState(() {
                        _paymentType = value;
                        if (value != 'Insurance') {
                          _insuranceProvider = null;
                        }
                      });
                    },
                    activeColor: const Color(0xFF1A365D),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Insurance'),
                    value: 'Insurance',
                    groupValue: _paymentType,
                    onChanged: (value) {
                      setState(() {
                        _paymentType = value;
                        if (value != 'Insurance') {
                          _insuranceProvider = null;
                        }
                      });
                    },
                    activeColor: const Color(0xFF1A365D),
                  ),
                ),
              ],
            ),
            if (_paymentType == 'Insurance') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _insuranceProvider,
                decoration: const InputDecoration(
                  labelText: 'Select Insurance Provider',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
                items: BookAppointmentScreen.kInsuranceProviders
                    .map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _insuranceProvider = v);
                },
                validator: (value) {
                  if (_paymentType != 'Insurance') return null;
                  if (value == null || value.isEmpty) {
                    return 'Please select an insurance provider';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Step 3: Date & Time Selection (Only for Follow-up patients)
  Widget _buildStep3DateTimeSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Date & Time',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your preferred appointment date and time',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Date Selection
          const Text(
            'Select Date',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 32,
                      color: _selectedDate != null
                          ? const Color(0xFF1A365D)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'Tap to select date'
                            : DateFormat('EEEE, MMMM d, y').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _selectedDate != null
                              ? const Color(0xFF1A365D)
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Time Selection with Grid
          const Text(
            'Select Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedDate == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Please select a date first',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            _buildTimeSlotGrid(),
        ],
      ),
    );
  }

  // Generate time slots from 8:00 AM to 12:00 PM with 15-minute intervals
  List<String> _generateAllTimeSlots() {
    final List<String> slots = [];
    // Morning slots: 8:00 AM to 11:45 AM
    for (int hour = 8; hour < 12; hour++) {
      for (int minute = 0; minute < 60; minute += 15) {
        slots.add('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} AM');
      }
    }
    // Add 12:00 PM slot
    slots.add('12:00 PM');
    return slots;
  }

  Widget _buildTimeSlotGrid() {
    if (_selectedDate == null || _selectedDoctorId == null) {
      return const SizedBox.shrink();
    }

    // Master list of all available time slots (8:00 AM to 12:00 PM)
    final allTimeSlots = _generateAllTimeSlots();
    
    return StreamBuilder<List<String>>(
      stream: SlotAvailabilityChecker.getBookedSlots(
        selectedDate: _selectedDate!,
        doctorId: _selectedDoctorId!,
      ),
      builder: (context, snapshot) {
        final bookedSlots = snapshot.data ?? [];
        
        // Filter out booked slots - only show available slots from master list
        final availableSlots = allTimeSlots.where((timeString) {
          return !bookedSlots.contains(timeString);
        }).toList();
        
        if (availableSlots.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No available time slots for this date',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: availableSlots.length,
          itemBuilder: (context, index) {
            final timeString = availableSlots[index];
            final isSelected = _selectedTime != null &&
                _formatTimeOfDay(_selectedTime!) == timeString;
            
            return FilledButton.tonal(
              onPressed: () {
                // Parse timeString back to TimeOfDay
                final parts = timeString.split(' ');
                final timeParts = parts[0].split(':');
                final hour = int.parse(timeParts[0]);
                final minute = int.parse(timeParts[1]);
                final period = parts[1];
                
                int hour24 = hour;
                if (period == 'PM' && hour != 12) {
                  hour24 = hour + 12;
                } else if (period == 'AM' && hour == 12) {
                  hour24 = 0;
                }
                
                setState(() {
                  _selectedTime = TimeOfDay(hour: hour24, minute: minute);
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: isSelected
                    ? const Color(0xFF1A365D)
                    : Colors.grey.shade100,
                foregroundColor: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF1A365D)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
              child: Text(
                timeString,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Professional Doctor Card Widget
class _DoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final bool isSelected;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doctor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF1A365D)
              : Colors.grey.shade200,
          width: isSelected ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Circular Profile Image with network image or default icon
              Hero(
                tag: 'doctor_${doctor.id}',
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: isSelected
                      ? const Color(0xFF1A365D).withOpacity(0.2)
                      : Colors.grey.shade200,
                  child: doctor.imageUrl != null && doctor.imageUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            doctor.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                color: Color(0xFF1A365D),
                                size: 40,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 60,
                                height: 60,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A365D)),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Color(0xFF1A365D),
                          size: 40,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Doctor Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Name (null-safe)
                    Text(
                      'Dr. ${doctor.name.isNotEmpty ? doctor.name : 'Unknown Doctor'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Specialization (null-safe)
                    Text(
                      doctor.specialization.isNotEmpty ? doctor.specialization : 'General Practitioner',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A5568),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Select Button
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? const Color(0xFF1A365D)
                      : const Color(0xFF1A365D).withOpacity(0.8),
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: isSelected ? 4 : 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 4),
                    ],
                    const Text(
                      'Select',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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

