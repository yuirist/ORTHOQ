import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'staff_calendar_appointment_tile.dart';

/// Default session length on staff calendars (matches clinic slot grid).
const int kStaffAppointmentSlotMinutes = 15;

/// Tile fill for Syncfusion month/agenda chips (custom builder uses same palette).
Color staffCalendarColorForStatus(String? status) {
  return kStaffCalendarTileBackground;
}

DateTime? parseAppointmentDateOnly(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Parses slots like `08:00 AM` / `12:30 PM` and combines with [day].
DateTime? combineDayWithTimeSlot(DateTime day, String? timeSlot) {
  final raw = timeSlot?.trim() ?? '';
  if (raw.isEmpty) return null;
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  var hour = int.tryParse(m.group(1)!) ?? 0;
  final minute = int.tryParse(m.group(2)!) ?? 0;
  final period = (m.group(3) ?? '').toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// Patient type label from Firestore `patientType` / `appointmentType`.
String staffCalendarPatientTypeLabel(Map<String, dynamic> data) {
  final patientType = data['patientType']?.toString().toLowerCase() ?? '';
  final appointmentType = data['appointmentType']?.toString().toLowerCase() ?? '';
  if (patientType.contains('new') || appointmentType.contains('new')) {
    return 'New Patient';
  }
  if (patientType.contains('follow') || appointmentType.contains('follow')) {
    return 'Follow-up';
  }
  final raw = data['patientType']?.toString().trim() ?? '';
  return raw.isEmpty ? '—' : raw;
}

class StaffCalendarMappingResult {
  const StaffCalendarMappingResult({
    required this.appointments,
    required this.metaByDocId,
  });

  final List<Appointment> appointments;
  final Map<String, StaffCalendarTileMeta> metaByDocId;
}

/// Maps Firestore `appointments` docs to Syncfusion [Appointment] entries.
StaffCalendarMappingResult mapFirestoreDocsToCalendarAppointments(
  List<QueryDocumentSnapshot<Object?>> docs,
) {
  final out = <Appointment>[];
  final metaByDocId = <String, StaffCalendarTileMeta>{};

  for (final doc in docs) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) continue;
    final data = raw;
    final patientName = data['patientName']?.toString().trim() ?? 'Patient';
    final timeStr = data['appointmentTime']?.toString().trim() ?? '';
    final displayTime =
        timeStr.isEmpty ? 'Awaiting staff confirmation' : timeStr;
    final patientTypeLabel = staffCalendarPatientTypeLabel(data);
    final icRaw = data['icNumber']?.toString().trim() ?? '';
    final icNumber = icRaw.isEmpty ? '—' : icRaw;
    final status = data['status']?.toString();
    final color = staffCalendarColorForStatus(status);

    metaByDocId[doc.id] = StaffCalendarTileMeta(
      patientName: patientName,
      time: displayTime,
      patientTypeLabel: patientTypeLabel,
      icNumber: icNumber,
    );

    final day = parseAppointmentDateOnly(data['appointmentDate']);
    if (day == null) continue;

    final dateOnly = DateTime(day.year, day.month, day.day);
    final start = combineDayWithTimeSlot(dateOnly, timeStr);
    final durationMinutes = _durationMinutesFromFirestore(data);

    if (start == null) {
      out.add(
        Appointment(
          startTime: dateOnly,
          endTime: dateOnly.add(const Duration(hours: 23, minutes: 59)),
          isAllDay: true,
          subject: patientName,
          color: color,
          notes: doc.id,
        ),
      );
      continue;
    }

    final end = start.add(Duration(minutes: durationMinutes));
    out.add(
      Appointment(
        startTime: start,
        endTime: end,
        isAllDay: false,
        subject: patientName,
        color: color,
        notes: doc.id,
      ),
    );
  }
  return StaffCalendarMappingResult(
    appointments: out,
    metaByDocId: metaByDocId,
  );
}

class StaffAppointmentCalendarDataSource extends CalendarDataSource {
  StaffAppointmentCalendarDataSource(List<Appointment> source) {
    appointments = source;
  }
}

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _durationMinutesFromFirestore(Map<String, dynamic> data) {
  final v = data['durationMinutes'];
  if (v is int) return v.clamp(5, 120);
  if (v is num) return v.round().clamp(5, 120).toInt();
  return kStaffAppointmentSlotMinutes;
}
