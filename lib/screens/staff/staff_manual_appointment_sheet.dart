import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

/// Quick-add form for staff to create a confirmed appointment on a doctor's calendar.
Future<void> showStaffManualAppointmentSheet({
  required BuildContext context,
  required String doctorId,
  required String doctorName,
  DateTime? initialDate,
}) async {
  final nameController = TextEditingController();
  final icController = TextEditingController();
  final emailController = TextEditingController();
  var selectedDate = initialDate ?? DateTime.now();
  String? selectedTime;
  var isSaving = false;

  final timeSlots = <String>[];
  for (var hour = 8; hour < 12; hour++) {
    for (var minute = 0; minute < 60; minute += 15) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      timeSlots.add(
        '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period',
      );
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> save() async {
            final patientName = nameController.text.trim();
            if (patientName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter the patient name.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (selectedTime == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an appointment time.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setSheetState(() => isSaving = true);
            try {
              final dateOnly = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
              );
              await FirebaseFirestore.instance.collection('appointments').add({
                'doctorId': doctorId,
                'doctorName': doctorName,
                'patientName': patientName,
                'icNumber': icController.text.trim(),
                'email': emailController.text.trim(),
                'patientType': 'Follow-up',
                'appointmentDate': Timestamp.fromDate(dateOnly),
                'appointmentTime': selectedTime,
                'status': 'confirmed',
                'referralVerified': true,
                'hasRescheduleRequest': false,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text('Appointment added for $patientName.'),
                    backgroundColor: OrthoqColors.navy,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not save: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (context.mounted) {
                setSheetState(() => isSaving = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add appointment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: OrthoqColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dr. $doctorName',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Patient name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: icController,
                    decoration: const InputDecoration(
                      labelText: 'IC number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                            }
                          },
                    icon: const Icon(Icons.calendar_today,
                        color: OrthoqColors.navy),
                    label: Text(
                      DateFormat('EEE, MMM d, y').format(selectedDate),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTime,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                    ),
                    items: timeSlots
                        .map(
                          (t) => DropdownMenuItem(value: t, child: Text(t)),
                        )
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (v) => setSheetState(() => selectedTime = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isSaving ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor: OrthoqColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save appointment'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  nameController.dispose();
  icController.dispose();
  emailController.dispose();
}
