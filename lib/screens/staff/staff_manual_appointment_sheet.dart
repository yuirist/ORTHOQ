import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../services/email_service.dart';

/// Quick-add or reschedule form for staff on a doctor's calendar.
/// Returns `true` when an appointment was saved successfully.
Future<bool> showStaffManualAppointmentSheet({
  required BuildContext context,
  required String doctorId,
  required String doctorName,
  DateTime? initialDate,
  String? initialPatientName,
  String? initialIcNumber,
  String? initialEmail,
  String? initialPatientId,
  String? appointmentId,
  DateTime? originalAppointmentDate,
  String? originalAppointmentTime,
}) async {
  final parentContext = context;
  final nameController = TextEditingController(text: initialPatientName ?? '');
  final icController = TextEditingController(text: initialIcNumber ?? '');
  final emailController = TextEditingController(text: initialEmail ?? '');
  final reasonController = TextEditingController();
  var selectedDate = initialDate ?? DateTime.now();
  String? selectedTime;
  var isSaving = false;
  var savedSuccessfully = false;

  final trimmedAppointmentId = appointmentId?.trim() ?? '';
  final isReschedule = trimmedAppointmentId.isNotEmpty;

  final originalDateLabel = originalAppointmentDate != null
      ? DateFormat('EEEE, MMMM d, y').format(originalAppointmentDate)
      : null;
  final originalTimeLabel = originalAppointmentTime?.trim();

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

  try {
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
              FocusScope.of(context).unfocus();

              // Capture all field values before any async work or navigation.
              final pName = nameController.text.trim();
              final pIc = icController.text.trim();
              final pEmail = emailController.text.trim();
              final rescheduleReason = reasonController.text.trim();
              final nTime = selectedTime?.trim();
              final nDate = selectedDate;
              final nDateLabel = DateFormat('EEEE, MMMM d, y').format(nDate);
              final successMessage = isReschedule
                  ? 'Appointment rescheduled for $pName.'
                  : 'Appointment added for $pName.';

              if (pName.isEmpty) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter the patient name.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              if (nTime == null || nTime.isEmpty) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please select an appointment time.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              if (isReschedule && rescheduleReason.isEmpty) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reason for the reschedule.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              if (!sheetContext.mounted) return;
              setSheetState(() => isSaving = true);

              try {
                final dateOnly = DateTime(nDate.year, nDate.month, nDate.day);
                var oldDateLabel = originalDateLabel;
                var oldTimeLabel = originalTimeLabel ?? '';

                if (isReschedule) {
                  final docRef = FirebaseFirestore.instance
                      .collection('appointments')
                      .doc(trimmedAppointmentId);
                  final existingSnap = await docRef.get();
                  if (!existingSnap.exists) {
                    throw StateError(
                      'Could not find the existing appointment to reschedule.',
                    );
                  }

                  final existingData =
                      existingSnap.data() ?? <String, dynamic>{};
                  if (oldDateLabel == null) {
                    final existingDay =
                        _parseAppointmentDate(existingData['appointmentDate']);
                    oldDateLabel = existingDay != null
                        ? DateFormat('EEEE, MMMM d, y').format(existingDay)
                        : '—';
                  }
                  if (oldTimeLabel.isEmpty) {
                    oldTimeLabel =
                        existingData['appointmentTime']?.toString().trim() ??
                            '—';
                  }

                  await docRef.update({
                    'appointmentDate': Timestamp.fromDate(dateOnly),
                    'appointmentTime': nTime,
                    'status': 'confirmed',
                    'rescheduleReason': rescheduleReason,
                    'hasRescheduleRequest': false,
                    'requestedDate': FieldValue.delete(),
                    'requestedTime': FieldValue.delete(),
                    'patientName': pName,
                    'icNumber': pIc,
                    'email': pEmail,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await FirebaseFirestore.instance
                      .collection('appointments')
                      .add({
                    'doctorId': doctorId,
                    'doctorName': doctorName,
                    if (initialPatientId != null &&
                        initialPatientId.trim().isNotEmpty)
                      'patientId': initialPatientId.trim(),
                    'patientName': pName,
                    'icNumber': pIc,
                    'email': pEmail,
                    'appointmentType': 'follow_up',
                    'patientType': 'Follow-up',
                    'paymentType': 'Self-pay',
                    'appointmentDate': Timestamp.fromDate(dateOnly),
                    'appointmentTime': nTime,
                    'status': 'confirmed',
                    'referralVerified': true,
                    'hasRescheduleRequest': false,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                if (isReschedule &&
                    pEmail.isNotEmpty &&
                    oldDateLabel != null &&
                    oldTimeLabel.isNotEmpty &&
                    oldTimeLabel != '—') {
                  await EmailService().sendRescheduleEmail(
                    pEmail,
                    pName,
                    oldDateLabel,
                    oldTimeLabel,
                    nDateLabel,
                    nTime,
                    doctorName,
                    rescheduleReason,
                    patientId: initialPatientId,
                  );
                }

                savedSuccessfully = true;

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);

                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(successMessage),
                      backgroundColor: OrthoqColors.navy,
                    ),
                  );
                }
              } catch (e) {
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text('Could not save: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                setSheetState(() => isSaving = false);
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
                    Text(
                      isReschedule ? 'Reschedule appointment' : 'Add appointment',
                      style: const TextStyle(
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
                    if (isReschedule &&
                        originalDateLabel != null &&
                        originalTimeLabel != null &&
                        originalTimeLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Previous: $originalDateLabel · $originalTimeLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Patient name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: icController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'IC number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      enabled: !isSaving,
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
                    if (isReschedule) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reasonController,
                        enabled: !isSaving,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Reason for reschedule',
                          hintText: 'e.g., Doctor has an urgent surgery...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
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
  } finally {
    nameController.dispose();
    icController.dispose();
    emailController.dispose();
    reasonController.dispose();
  }

  return savedSuccessfully;
}

DateTime? _parseAppointmentDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
