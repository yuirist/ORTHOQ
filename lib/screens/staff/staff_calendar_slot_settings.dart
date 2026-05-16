import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

/// OrthoQ staff calendars: **clinic window 8:00 AM–12:00 PM** with **15-minute** slots.
///
/// Syncfusion day/week rulers print the first label at **one [timeInterval] after
/// [startHour]**. With `startHour: 8` and 15-minute intervals the first label would be
/// **8:15 AM**, not 8:00. Using **`startHour: 7.75`** (7:45) aligns labels to **8:00,
/// 8:15, … 12:00 PM** while [endHour] remains **12**. [preClinicBufferRegions] shades
/// **7:45–8:00** so that quarter-hour is visually separate from clinic time.
abstract final class StaffCalendarSlotSettings {
  /// Tighter rows for embedded preview cards on phones.
  static const TimeSlotViewSettings preview = TimeSlotViewSettings(
    startHour: 7.75,
    endHour: 12,
    nonWorkingDays: <int>[DateTime.saturday, DateTime.sunday],
    timeInterval: Duration(minutes: 15),
    timeIntervalHeight: 64,
    timeFormat: 'h:mm a',
    minimumAppointmentDuration: Duration(minutes: 15),
  );

  /// Taller rows on the full-screen calendar for readability (Note 9+).
  static const TimeSlotViewSettings fullCalendar = TimeSlotViewSettings(
    startHour: 7.75,
    endHour: 12,
    nonWorkingDays: <int>[DateTime.saturday, DateTime.sunday],
    timeInterval: Duration(minutes: 15),
    timeIntervalHeight: 78,
    timeFormat: 'h:mm a',
    minimumAppointmentDuration: Duration(minutes: 15),
  );

  /// Shaded 7:45–8:00 daily (see class doc). Bookings use times from Firestore as-is.
  static final List<TimeRegion> preClinicBufferRegions = <TimeRegion>[
    TimeRegion(
      startTime: DateTime(2020, 1, 1, 7, 45),
      endTime: DateTime(2020, 1, 1, 8, 0),
      recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
      enablePointerInteraction: false,
      color: const Color(0xFFE2E8F0),
    ),
  ];
}
