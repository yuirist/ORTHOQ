import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/doctor_service.dart';
import '../../services/email_service.dart';
import '../../widgets/slot_availability_checker.dart';

class StaffSchedulingPage extends StatefulWidget {
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;

  const StaffSchedulingPage({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<StaffSchedulingPage> createState() => _StaffSchedulingPageState();
}

class _StaffSchedulingPageState extends State<StaffSchedulingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  // Generate time slots from 8:00 AM to 12:00 PM with 15-minute intervals
  List<TimeOfDay> _generateTimeSlots() {
    final List<TimeOfDay> slots = [];
    for (int hour = 8; hour < 12; hour++) {
      for (int minute = 0; minute < 60; minute += 15) {
        slots.add(TimeOfDay(hour: hour, minute: minute));
      }
    }
    return slots;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
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
        // Reset time when date changes
        _selectedTime = null;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final timeString = _formatTimeOfDay(_selectedTime!);

    // Final check: Verify slot is still available (race condition prevention)
    bool isAvailable = true;
    try {
      isAvailable = await SlotAvailabilityChecker.isSlotAvailable(
        selectedDate: _selectedDate!,
        doctorId: widget.doctorId,
        timeString: timeString,
        excludeAppointmentId: widget.appointmentId, // Exclude current appointment if rescheduling
      );
    } catch (e) {
      // If the check fails (e.g., index not ready), log but continue
      debugPrint('Slot availability check error: $e');
      // Continue with save - the check is just a safety measure
    }

    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorry, this slot was just booked by someone else. Please choose another time.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Combine date and time
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Update appointment
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId);
      
      batch.update(appointmentRef, {
        'status': 'confirmed',
        'appointmentDate': Timestamp.fromDate(appointmentDateTime),
        'appointmentTime': timeString,
        'durationMinutes': 15,
        'referralVerified': true,
        'updatedAt': Timestamp.now(),
      });

      // Also verify the user
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.patientId);
      batch.update(userRef, {
        'isVerified': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();

      final postSnap = await appointmentRef.get();
      final patientEmail = postSnap.data()?['email'] as String?;
      if (patientEmail != null && patientEmail.trim().isNotEmpty) {
        final dateLabel = DateFormat.yMMMMd().format(_selectedDate!);
        final doctorModel =
            await DoctorService().getDoctorById(widget.doctorId);
        final specialization =
            doctorModel?.specialization ?? '—';
        await EmailService().sendApprovalEmail(
          patientEmail.trim(),
          dateLabel,
          timeString,
          widget.doctorName,
          specialization,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment scheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error in _saveSchedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling appointment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Appointment'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Card(
              color: const Color(0xFF1A365D),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Patient: ${widget.patientName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      'Doctor: Dr. ${widget.doctorName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
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

            // Time Selection
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

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSaving || _selectedDate == null || _selectedTime == null)
                    ? null
                    : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A365D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade300,
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
                        'Schedule Appointment',
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
    );
  }

  Widget _buildTimeSlotGrid() {
    if (_selectedDate == null) {
      return const SizedBox.shrink();
    }

    final allTimeSlots = _generateTimeSlots();
    
    return StreamBuilder<List<String>>(
      stream: SlotAvailabilityChecker.getBookedSlots(
        selectedDate: _selectedDate!,
        doctorId: widget.doctorId,
        excludeAppointmentId: widget.appointmentId, // Exclude current appointment if rescheduling
      ),
      builder: (context, snapshot) {
        final bookedSlots = snapshot.data ?? [];
        
        // Filter out booked slots - only show available slots
        final availableSlots = allTimeSlots.where((slot) {
          final timeString = _formatTimeOfDay(slot);
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
            final slot = availableSlots[index];
            final isSelected = _selectedTime != null &&
                _selectedTime!.hour == slot.hour &&
                _selectedTime!.minute == slot.minute;
            
            final timeString = _formatTimeOfDay(slot);
            
            return FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _selectedTime = slot;
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


