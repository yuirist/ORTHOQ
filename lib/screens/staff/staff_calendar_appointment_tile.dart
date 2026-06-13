import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';
import '../../widgets/doctor_avatar.dart';
import 'staff_manual_appointment_sheet.dart';

/// Default follow-up tile background when visit type is unknown.
const Color kStaffCalendarDefaultTileBackground = Color(0xFFE3F2FD);

/// Display fields for one appointment block on the staff/doctor schedule calendar.
class StaffCalendarTileMeta {
  const StaffCalendarTileMeta({
    required this.appointmentDocId,
    required this.patientName,
    required this.time,
    required this.patientTypeLabel,
    required this.icNumber,
    this.status = 'Pending',
    this.paymentLabel = 'Self Pay',
    this.appointmentDate,
    this.patientEmail,
    this.patientId,
  });

  final String appointmentDocId;
  final String patientName;
  final String time;
  final String patientTypeLabel;
  final String icNumber;
  final String status;
  final String paymentLabel;
  final DateTime? appointmentDate;
  final String? patientEmail;
  final String? patientId;
}

/// Resolves new vs follow-up styling from label text only (never reads a bool field).
bool staffCalendarTileIsNewPatient(StaffCalendarTileMeta meta) {
  final label = meta.patientTypeLabel.toLowerCase().trim();
  if (label.contains('new')) return true;
  if (label.contains('follow')) return false;
  return false;
}

({Color background, Color text, Color border}) _staffTilePalette(bool isNewPatient) {
  if (isNewPatient) {
    return (
      background: const Color(0xFFF3E5F5),
      text: Colors.purple.shade900,
      border: Colors.purple.shade200,
    );
  }
  return (
    background: kStaffCalendarDefaultTileBackground,
    text: Colors.blue.shade900,
    border: Colors.blue.shade200,
  );
}

BoxDecoration _staffTileDecoration({bool isNewPatient = false}) {
  final palette = _staffTilePalette(isNewPatient);
  return BoxDecoration(
    color: palette.background,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: palette.border,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: palette.text.withValues(alpha: 0.12),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

/// Builds the custom appointment cell content (name, time, type, IC).
Widget buildStaffCalendarAppointmentTile({
  required StaffCalendarTileMeta meta,
}) {
  final isNewPatient = staffCalendarTileIsNewPatient(meta);
  final palette = _staffTilePalette(isNewPatient);
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
    decoration: _staffTileDecoration(isNewPatient: isNewPatient),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    alignment: Alignment.topLeft,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 42;
        final nameSize = compact ? 9.0 : 10.0;
        final timeSize = compact ? 8.0 : 9.0;

        Widget line(
          String text, {
          required double fontSize,
          FontWeight? weight,
        }) {
          return Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: fontSize,
                  fontWeight: weight ?? FontWeight.w500,
                  height: 1.05,
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(meta.patientName, fontSize: nameSize, weight: FontWeight.bold),
            line(meta.time, fontSize: timeSize),
            if (!compact) ...[
              line(meta.patientTypeLabel, fontSize: 8),
              line('IC: ${meta.icNumber}', fontSize: 8),
            ],
          ],
        );
      },
    ),
  );
}

Widget staffCalendarAppointmentBuilder(
  BuildContext context,
  CalendarAppointmentDetails details,
  Map<String, StaffCalendarTileMeta> metaByDocId,
) {
  final appt = details.appointments.first;
  final meta = metaByDocId[appt.notes ?? ''];
  if (meta == null) {
    final palette = _staffTilePalette(false);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      decoration: _staffTileDecoration(isNewPatient: false),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: Alignment.topLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    appt.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  return buildStaffCalendarAppointmentTile(meta: meta);
}

String staffCalendarVisitTypeDisplayLabel(StaffCalendarTileMeta meta) {
  final label = meta.patientTypeLabel.toLowerCase().trim();
  if (label.contains('new')) return 'New Patient';
  if (label.contains('follow')) return 'Follow Up';
  final raw = meta.patientTypeLabel.trim();
  return raw.isEmpty || raw == '—' ? 'Follow Up' : raw;
}

Color staffCalendarStatusColor(BuildContext context, String status) {
  switch (status.toLowerCase()) {
    case 'booked':
    case 'pending':
      return Theme.of(context).colorScheme.secondary;
    case 'confirmed':
      return OrthoqColors.slateNavy;
    case 'rescheduled':
      return Colors.orange;
    case 'cancelled':
    case 'rejected':
      return Colors.red;
    case 'completed':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Widget staffCalendarPaymentBadge(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    ),
  );
}

Widget staffCalendarVisitTypeBadge(StaffCalendarTileMeta meta) {
  final isNewPatient = staffCalendarTileIsNewPatient(meta);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isNewPatient ? const Color(0xFFF3E5F5) : const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      staffCalendarVisitTypeDisplayLabel(meta),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isNewPatient ? Colors.purple.shade900 : Colors.blue.shade900,
      ),
    ),
  );
}

Widget _staffCalendarDetailRow({
  required IconData icon,
  required String text,
}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: Colors.grey.shade600),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    ],
  );
}

/// Opens a bottom sheet with full appointment details for a calendar slot.
void showStaffCalendarAppointmentDetailSheet({
  required BuildContext context,
  required StaffCalendarTileMeta meta,
  required String doctorId,
  required String doctorName,
  VoidCallback? onAppointmentChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StaffCalendarAppointmentDetailSheet(
      meta: meta,
      doctorId: doctorId,
      doctorName: doctorName,
      onAppointmentChanged: onAppointmentChanged,
    ),
  );
}

class StaffCalendarAppointmentDetailSheet extends StatelessWidget {
  const StaffCalendarAppointmentDetailSheet({
    super.key,
    required this.meta,
    required this.doctorId,
    required this.doctorName,
    this.onAppointmentChanged,
  });

  final StaffCalendarTileMeta meta;
  final String doctorId;
  final String doctorName;
  final VoidCallback? onAppointmentChanged;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dateText = meta.appointmentDate != null
        ? DateFormat('EEEE, MMMM d, y').format(meta.appointmentDate!)
        : '—';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.patientName.trim().isNotEmpty
                              ? meta.patientName
                              : 'Patient',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FutureBuilder<DoctorModel?>(
                                future: DoctorService().getDoctorById(doctorId),
                                builder: (context, snapshot) {
                                  final doctor = snapshot.data;
                                  final specialization =
                                      doctor?.specialization.trim();
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DoctorAvatar(
                                        imageUrl: doctor?.imageUrl,
                                        radius: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doctorName
                                                      .trim()
                                                      .toLowerCase()
                                                      .startsWith('dr.')
                                                  ? doctorName.trim()
                                                  : 'Dr. $doctorName',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (specialization != null &&
                                                specialization.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                specialization,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                staffCalendarPaymentBadge(
                                                  meta.paymentLabel,
                                                ),
                                                staffCalendarVisitTypeBadge(
                                                  meta,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: staffCalendarStatusColor(
                                  context,
                                  meta.status,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                meta.status.toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _staffCalendarDetailRow(
                          icon: Icons.calendar_month,
                          text: dateText,
                        ),
                        const SizedBox(height: 8),
                        _staffCalendarDetailRow(
                          icon: Icons.access_time,
                          text: meta.time,
                        ),
                        if (meta.icNumber.trim().isNotEmpty &&
                            meta.icNumber != '—') ...[
                          const SizedBox(height: 8),
                          _staffCalendarDetailRow(
                            icon: Icons.badge_outlined,
                            text: meta.icNumber,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final saved = await showStaffManualAppointmentSheet(
                      context: context,
                      doctorId: doctorId,
                      doctorName: doctorName,
                      initialDate: meta.appointmentDate ?? DateTime.now(),
                      initialPatientName: meta.patientName,
                      initialIcNumber:
                          meta.icNumber == '—' ? '' : meta.icNumber,
                      initialEmail: meta.patientEmail,
                      initialPatientId: meta.patientId,
                      appointmentId: meta.appointmentDocId,
                      originalAppointmentDate: meta.appointmentDate,
                      originalAppointmentTime:
                          meta.time == 'Awaiting staff confirmation'
                              ? null
                              : meta.time,
                    );
                    if (saved) {
                      onAppointmentChanged?.call();
                    }
                  },
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Reschedule appointment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OrthoqColors.slateNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
