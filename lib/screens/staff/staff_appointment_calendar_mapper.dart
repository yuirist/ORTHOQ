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

/// Normalizes [date] to midnight for use as a map key.
DateTime normalizeCalendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Groups Firestore appointment docs by calendar day for month-view indicators.
Map<DateTime, List<Map<String, dynamic>>> groupDoctorAppointmentsByDate(
  List<QueryDocumentSnapshot<Object?>> docs,
) {
  final grouped = <DateTime, List<Map<String, dynamic>>>{};
  for (final doc in docs) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) continue;
    final date = parseAppointmentDateOnly(raw['appointmentDate']);
    if (date == null) continue;
    final key = normalizeCalendarDay(date);
    grouped.putIfAbsent(key, () => []).add(raw);
  }
  return grouped;
}

/// Month cell with red (busy) / green (available) status dot below the day number.
Widget buildStaffCalendarMonthCell({
  required MonthCellDetails details,
  required Map<DateTime, List<dynamic>> doctorAppointments,
}) {
  final normalizedDay = normalizeCalendarDay(details.date);
  final hasAppointments = doctorAppointments.containsKey(normalizedDay) &&
      doctorAppointments[normalizedDay]!.isNotEmpty;
  final isToday = isSameCalendarDay(details.date, DateTime.now());
  final midVisible = details.visibleDates.isNotEmpty
      ? details.visibleDates[details.visibleDates.length ~/ 2]
      : details.date;
  final isCurrentMonth =
      details.date.month == midVisible.month &&
      details.date.year == midVisible.year;

  final dayTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
    color: isCurrentMonth
        ? (isToday ? const Color(0xFF1B3C68) : Colors.black87)
        : Colors.grey.shade400,
  );

  return SizedBox(
    width: details.bounds.width,
    height: details.bounds.height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF1B3C68).withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Text(
              '${details.date.day}',
              textAlign: TextAlign.center,
              style: dayTextStyle,
            ),
          ),
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasAppointments ? Colors.red : Colors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

int _durationMinutesFromFirestore(Map<String, dynamic> data) {
  final v = data['durationMinutes'];
  if (v is int) return v.clamp(5, 120);
  if (v is num) return v.round().clamp(5, 120).toInt();
  return kStaffAppointmentSlotMinutes;
}
