import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

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

/// Builds the custom appointment cell content (name, time, type, IC).
Widget buildStaffCalendarAppointmentTile({
  required StaffCalendarTileMeta meta,
  required Color backgroundColor,
}) {
  return Container(
    color: backgroundColor,
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    alignment: Alignment.topLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          meta.patientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        Text(
          meta.time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            height: 1.15,
          ),
        ),
        Text(
          meta.patientTypeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            height: 1.1,
          ),
        ),
        Text(
          'IC: ${meta.icNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            height: 1.1,
          ),
        ),
      ],
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
      color: appt.color,
      padding: const EdgeInsets.all(2),
      alignment: Alignment.topLeft,
      child: Text(
        appt.subject,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  return buildStaffCalendarAppointmentTile(
    meta: meta,
    backgroundColor: appt.color,
  );
}
