import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

/// Light blue tile fill for staff schedule appointments.
const Color kStaffCalendarTileBackground = Color(0xFFDBEAFE);

/// Display fields for one appointment block on the staff/doctor schedule calendar.
class StaffCalendarTileMeta {
  const StaffCalendarTileMeta({
    required this.patientName,
    required this.time,
    required this.patientTypeLabel,
    required this.icNumber,
  });

  final String patientName;
  final String time;
  final String patientTypeLabel;
  final String icNumber;
}

BoxDecoration _staffTileDecoration() {
  return BoxDecoration(
    color: kStaffCalendarTileBackground,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: OrthoqColors.navy.withValues(alpha: 0.15),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: OrthoqColors.navy.withValues(alpha: 0.1),
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
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
    decoration: _staffTileDecoration(),
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
                  color: OrthoqColors.navy,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      decoration: _staffTileDecoration(),
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
                    style: const TextStyle(
                      color: OrthoqColors.navy,
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
