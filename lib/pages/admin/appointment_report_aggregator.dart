import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/firestore_date_utils.dart';

enum AppointmentReportPeriod { daily, monthly }

/// Dropdown value for combined appointments across all doctors.
const String kAllDoctorsFilterKey = '__all_doctors__';

class AppointmentReportBucket {
  const AppointmentReportBucket({
    required this.label,
    required this.count,
    required this.start,
    required this.end,
  });

  final String label;
  final int count;
  final DateTime start;
  final DateTime end;
}

class AppointmentReportData {
  const AppointmentReportData({
    required this.dailyWeekMonSun,
    required this.monthlyYearJanDec,
  });

  final List<AppointmentReportBucket> dailyWeekMonSun;
  final List<AppointmentReportBucket> monthlyYearJanDec;

  List<AppointmentReportBucket> bucketsFor(AppointmentReportPeriod period) {
    switch (period) {
      case AppointmentReportPeriod.daily:
        return dailyWeekMonSun;
      case AppointmentReportPeriod.monthly:
        return monthlyYearJanDec;
    }
  }

  static int maxCountFor(List<AppointmentReportBucket> buckets) {
    if (buckets.isEmpty) return 0;
    return buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _mondayOfWeekContaining(DateTime date) {
  final day = _dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

const List<String> _weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Keeps only appointments for [doctorId]; null = all doctors.
List<QueryDocumentSnapshot<Object?>> filterAppointmentsByDoctor(
  List<QueryDocumentSnapshot<Object?>> docs,
  String? doctorId,
) {
  if (doctorId == null || doctorId.isEmpty) return docs;
  return docs.where((doc) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) return false;
    return raw['doctorId']?.toString().trim() == doctorId;
  }).toList();
}

/// Aggregates appointments for admin reports (optionally one doctor).
AppointmentReportData buildAppointmentReportData(
  List<QueryDocumentSnapshot<Object?>> docs, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  final year = now.year;

  final appointmentDates = <DateTime>[];
  final createdDates = <DateTime>[];

  for (final doc in docs) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) continue;

    final appointmentDay =
        parseFirestoreDateTimeNullable(raw['appointmentDate']);
    if (appointmentDay != null) {
      appointmentDates.add(_dateOnly(appointmentDay));
    }

    final createdDay = parseFirestoreDateTimeNullable(raw['createdAt']);
    if (createdDay != null) {
      createdDates.add(_dateOnly(createdDay));
    }
  }

  final weekStart = _mondayOfWeekContaining(now);
  final dailyWeekMonSun = List.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    final count = appointmentDates.where((d) => d == day).length;
    return AppointmentReportBucket(
      label: _weekdayLabels[i],
      count: count,
      start: day,
      end: day,
    );
  });

  final monthlyYearJanDec = List.generate(12, (i) {
    final month = i + 1;
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    final count = createdDates
        .where((d) => d.year == year && d.month == month)
        .length;
    return AppointmentReportBucket(
      label: _monthLabels[i],
      count: count,
      start: monthStart,
      end: monthEnd,
    );
  });

  return AppointmentReportData(
    dailyWeekMonSun: dailyWeekMonSun,
    monthlyYearJanDec: monthlyYearJanDec,
  );
}

String periodSubtitle(
  AppointmentReportPeriod period,
  DateTime now, {
  required String doctorScopeLabel,
}) {
  final weekStart = _mondayOfWeekContaining(now);
  final weekEnd = weekStart.add(const Duration(days: 6));
  switch (period) {
    case AppointmentReportPeriod.daily:
      return 'This week (Mon–Sun) · ${_formatShort(weekStart)} – '
          '${_formatShort(weekEnd)} · $doctorScopeLabel';
    case AppointmentReportPeriod.monthly:
      return 'Calendar year ${now.year} (Jan–Dec) · $doctorScopeLabel';
  }
}

String _formatShort(DateTime d) => '${d.day}/${d.month}/${d.year}';
