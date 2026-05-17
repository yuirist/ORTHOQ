import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment_model.dart';
import '../../widgets/slot_availability_checker.dart';

class RescheduleAppointmentScreen extends StatefulWidget {
  final AppointmentModel appointment;

  const RescheduleAppointmentScreen({super.key, required this.appointment});

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
        _selectedTime = null;
      });
    }
  }

  Future<void> _requestReschedule() async {
    // Validation: Check if date and time are selected
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validation: Check if appointment ID exists
    if (widget.appointment.id.isEmpty) {
      debugPrint('ERROR: Appointment ID is empty!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Appointment ID is missing. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    debugPrint('Rescheduling appointment ID: ${widget.appointment.id}');
    debugPrint('Selected Date: $_selectedDate');
    debugPrint('Selected Time: $_selectedTime');

    final timeString = _formatTimeOfDay(_selectedTime!);

    // Final check: Verify slot is still available (race condition prevention)
    bool isAvailable = true;
    try {
      isAvailable = await SlotAvailabilityChecker.isSlotAvailable(
        selectedDate: _selectedDate!,
        doctorId: widget.appointment.doctorId,
        timeString: timeString,
        excludeAppointmentId:
            widget.appointment.id, // Exclude current appointment
      );
    } catch (e) {
      debugPrint('Slot availability check error: $e');
      // Continue with save - the check is just a safety measure
    }

    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sorry, this slot was just booked by someone else. Please choose another time.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('reschedule_requests').add({
        'appointmentId': widget.appointment.id,
        'patientId': widget.appointment.patientId,
        'patientName': widget.appointment.patientName,
        'patientEmail': widget.appointment.email ?? '',
        'doctorId': widget.appointment.doctorId,
        'doctorName': widget.appointment.doctorName,
        'oldDate': Timestamp.fromDate(widget.appointment.appointmentDate),
        'newDate': Timestamp.fromDate(_selectedDate!),
        'requestedDate': Timestamp.fromDate(_selectedDate!),
        'oldTime': widget.appointment.appointmentTime,
        'newTime': timeString,
        'requestedTime': timeString,
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Reschedule request submitted successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reschedule request submitted for staff approval'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in _requestReschedule: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'Error submitting reschedule request';
      if (e.toString().contains('Permission denied') ||
          e.toString().contains('permission-denied')) {
        errorMessage =
            'Permission denied. You may not have permission to update this appointment.';
      } else if (e.toString().contains('not-found') ||
          e.toString().contains('Document not found')) {
        errorMessage =
            'Appointment not found. The appointment may have been deleted.';
      } else if (e.toString().contains('appointmentId') ||
          e.toString().contains('id')) {
        errorMessage = 'Invalid appointment ID. Please try again.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
        title: const Text('Reschedule Appointment'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Appointment Info
              Card(
                color: const Color(0xFFF7FAFC),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Appointment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Dr. ${widget.appointment.doctorName}'),
                      Text(
                        DateFormat(
                          'EEEE, MMMM d, y',
                        ).format(widget.appointment.appointmentDate),
                      ),
                      Text(widget.appointment.appointmentTime),
                      const SizedBox(height: 8),
                      Text(
                        'Appointment ID: ${widget.appointment.id.isEmpty ? "MISSING!" : widget.appointment.id}',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.appointment.id.isEmpty
                              ? Colors.red
                              : Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Select New Date
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select New Date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(
                          _selectedDate == null
                              ? 'Choose a date'
                              : DateFormat(
                                  'EEEE, MMMM d, y',
                                ).format(_selectedDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _selectDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Select New Time
              if (_selectedDate != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select New Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTimeSlotGrid(),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Reason (Optional)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reason (Optional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter reason for rescheduling...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_isLoading ||
                          _selectedDate == null ||
                          _selectedTime == null)
                      ? null
                      : _requestReschedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrthoqColors.slateNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                          'Submit Reschedule Request',
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

  Widget _buildTimeSlotGrid() {
    if (_selectedDate == null) {
      return const SizedBox.shrink();
    }

    final allTimeSlots = _generateTimeSlots();

    return StreamBuilder<List<String>>(
      stream: SlotAvailabilityChecker.getBookedSlots(
        selectedDate: _selectedDate!,
        doctorId: widget.appointment.doctorId,
        excludeAppointmentId: widget
            .appointment
            .id, // Exclude current appointment - prevents self-conflict
      ),
      builder: (context, snapshot) {
        final bookedSlots = snapshot.data ?? [];

        // Filter out booked slots - only show available slots (current appointment is already excluded)
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
            final isSelected =
                _selectedTime != null &&
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
                    ? OrthoqColors.slateNavy
                    : Colors.grey.shade100,
                foregroundColor: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected
                        ? OrthoqColors.slateNavy
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
