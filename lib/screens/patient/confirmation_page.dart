import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/email_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/slot_availability_checker.dart';
import 'patient_home_screen.dart';

class ConfirmationPage extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String patientType; // 'New' or 'Follow-up'
  final String patientName;
  final String? phoneNumber;
  final String? email;
  final String? icNumber;
  final String? paymentType;
  final String? bookingFor;
  final String? insuranceProvider;
  final String? gender;

  const ConfirmationPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.patientType,
    required this.patientName,
    this.phoneNumber,
    this.email,
    this.icNumber,
    this.paymentType,
    this.bookingFor,
    this.insuranceProvider,
    this.gender,
  });

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  final AppointmentService _appointmentService = AppointmentService();
  bool _isSaving = false;
  bool _isSaved = false;

  Future<void> _confirmBooking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Final validation: Verify slot is still available (race condition prevention)
      bool isAvailable = false;
      try {
        isAvailable = await SlotAvailabilityChecker.isSlotAvailable(
          selectedDate: widget.appointmentDate,
          doctorId: widget.doctorId,
          timeString: widget.appointmentTime,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error checking slot availability: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This slot was just booked! Please choose another.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Normalize appointmentDate to start of day for exact date matching
      final normalizedDate = DateTime(
        widget.appointmentDate.year,
        widget.appointmentDate.month,
        widget.appointmentDate.day,
      );

      // Create appointment for follow-up patient with exactly these fields for 4-field index:
      // - appointmentTime: String (e.g., '08:00 AM') - required for index
      // - doctorId: String - required for index
      // - status: 'confirmed' - required for index
      // - appointmentDate: Timestamp - required for index
      // Note: referralUrl is NOT required for follow-up patients
      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        patientId: userId,
        patientName: widget.patientName,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        appointmentType: widget.patientType == 'New' ? 'new_patient' : 'follow_up',
        patientType: widget.patientType,
        appointmentDate: normalizedDate,
        appointmentTime: widget.appointmentTime,
        durationMinutes: 15,
        status: 'confirmed',
        createdAt: DateTime.now(),
        phoneNumber: widget.phoneNumber,
        email: widget.email,
        icNumber: widget.icNumber,
        paymentType: widget.paymentType,
        bookingFor: widget.bookingFor,
        insuranceProvider: widget.insuranceProvider,
        gender: widget.gender,
        // referralLetterUrl is null for follow-up patients (not required)
      );

      // Save to Firestore - appointmentDate will be saved as Timestamp, appointmentTime as String
      await _appointmentService.createAppointment(appointment);

      var emailSent = false;
      if (widget.patientType == 'Follow-up') {
        final recipient = widget.email?.trim();
        if (recipient != null && recipient.isNotEmpty) {
          final dateLabel =
              DateFormat('EEEE, d MMMM y').format(widget.appointmentDate);
          emailSent = await EmailService().sendFollowUpConfirmationEmail(
            patientEmail: recipient,
            patientName: widget.patientName,
            doctorName: widget.doctorName,
            appointmentDate: dateLabel,
            appointmentTime: widget.appointmentTime,
          );
        }
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        if (emailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Confirmation email sent'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving appointment: $e'),
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
        title: Text(_isSaved ? 'Booking Confirmed' : 'Confirm Booking'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        automaticallyImplyLeading: !_isSaved,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon - changes based on state
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isSaved
                      ? Colors.green.shade50
                      : Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSaved ? Icons.check_circle : Icons.calendar_today,
                  size: 60,
                  color: _isSaved
                      ? Colors.green
                      : Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Message - changes based on state
              Text(
                _isSaved ? 'Appointment Booked Successfully!' : 'Review Your Booking',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A365D),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isSaved
                    ? 'Your appointment has been confirmed'
                    : 'Please review the details below and confirm',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Booking Summary Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSummaryRow(
                        'Patient Type',
                        widget.patientType,
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Doctor',
                        'Dr. ${widget.doctorName}',
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Patient Name',
                        widget.patientName,
                      ),
                      if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) ...[
                        const Divider(),
                        _buildSummaryRow(
                          'Phone Number',
                          widget.phoneNumber!,
                        ),
                      ],
                      if (widget.email != null && widget.email!.isNotEmpty) ...[
                        const Divider(),
                        _buildSummaryRow(
                          'Email',
                          widget.email!,
                        ),
                      ],
                      if (widget.icNumber != null && widget.icNumber!.isNotEmpty) ...[
                        const Divider(),
                        _buildSummaryRow(
                          'IC Number',
                          widget.icNumber!,
                        ),
                      ],
                      if (widget.paymentType != null && widget.paymentType!.isNotEmpty) ...[
                        const Divider(),
                        _buildSummaryRow(
                          'Payment Type',
                          widget.paymentType!,
                        ),
                      ],
                      const Divider(),
                      _buildSummaryRow(
                        'Date',
                        DateFormat('EEEE, MMMM d, y').format(widget.appointmentDate),
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Time',
                        widget.appointmentTime,
                      ),
                      if (_isSaved) ...[
                        const Divider(),
                        _buildSummaryRow(
                          'Status',
                          'Confirmed',
                          valueColor: const Color(0xFF1A365D),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Confirm Booking or Back to Home Button
              SizedBox(
                width: double.infinity,
                child: _isSaved
                    ? ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PatientHomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A365D),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Back to Home',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _isSaving ? null : _confirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A365D),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
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
                                'Confirm Booking',
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

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


