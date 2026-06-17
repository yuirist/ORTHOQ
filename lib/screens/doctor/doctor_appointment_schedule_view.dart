import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../staff/staff_appointment_calendar_mapper.dart';
import '../staff/staff_calendar_appointment_tile.dart';

/// Doctor-facing daily schedule: week strip, summary card, and time-slot timeline.
class DoctorAppointmentScheduleView extends StatefulWidget {
  const DoctorAppointmentScheduleView({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  final String doctorId;
  final String doctorName;

  @override
  State<DoctorAppointmentScheduleView> createState() =>
      _DoctorAppointmentScheduleViewState();
}

class _DoctorAppointmentScheduleViewState
    extends State<DoctorAppointmentScheduleView> {
  static const _navy = OrthoqColors.navy;
  static const _summaryBlue = Color(0xFFE3F2FD);
  static const _slotHeight = 56.0;
  static const _timeColumnWidth = 72.0;
  static const _statusRed = Color(0xFFEF4444);
  static const _statusGreen = Color(0xFF22C55E);

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStripStart =>
      _selectedDate.subtract(const Duration(days: 3));

  List<DateTime> get _weekStripDays => List.generate(
        7,
        (i) => _weekStripStart.add(Duration(days: i)),
      );

  List<String> get _clinicTimeSlots {
    final slots = <String>[];
    for (var hour = 8; hour < 12; hour++) {
      for (var minute = 0; minute < 60; minute += 15) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        slots.add(
          '${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $period',
        );
      }
    }
    return slots;
  }

  int _slotIndexForTime(String? timeSlot) {
    final slots = _clinicTimeSlots;
    final normalized = timeSlot?.trim().toUpperCase() ?? '';
    final idx = slots.indexWhere((s) => s.toUpperCase() == normalized);
    if (idx >= 0) return idx;

    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final parsed = combineDayWithTimeSlot(day, timeSlot);
    if (parsed == null) return 0;

    final minutesFromEight =
        (parsed.hour * 60 + parsed.minute) - (8 * 60);
    return (minutesFromEight / 15).round().clamp(0, slots.length - 1);
  }

  Set<DateTime> _daysWithAppointments(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final days = <DateTime>{};
    for (final doc in docs) {
      final raw = doc.data();
      if (raw is! Map<String, dynamic>) continue;
      final day = parseAppointmentDateOnly(raw['appointmentDate']);
      if (day != null) {
        days.add(DateTime(day.year, day.month, day.day));
      }
    }
    return days;
  }

  List<QueryDocumentSnapshot<Object?>> _docsForSelectedDay(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) {
    return docs.where((doc) {
      final raw = doc.data();
      if (raw is! Map<String, dynamic>) return false;
      final day = parseAppointmentDateOnly(raw['appointmentDate']);
      if (day == null) return false;
      return isSameCalendarDay(day, _selectedDate);
    }).toList();
  }

  ({int total, int newCount, int followUpCount}) _summarizeDay(
    List<QueryDocumentSnapshot<Object?>> dayDocs,
  ) {
    var newCount = 0;
    var followUpCount = 0;
    for (final doc in dayDocs) {
      final raw = doc.data();
      if (raw is! Map<String, dynamic>) continue;
      if (staffCalendarIsNewPatient(raw)) {
        newCount++;
      } else {
        followUpCount++;
      }
    }
    return (total: dayDocs.length, newCount: newCount, followUpCount: followUpCount);
  }

  bool _dayHasAppointment(
    DateTime checkDate,
    Set<DateTime> daysWithAppts,
  ) {
    return daysWithAppts.any((day) => isSameCalendarDay(day, checkDate));
  }

  Widget _buildDayStatusDot(
    bool hasAppointments, {
    bool onSelectedBackground = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasAppointments ? _statusRed : _statusGreen,
          border: onSelectedBackground
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1,
                )
              : null,
        ),
      ),
    );
  }

  List<DateTime?> _monthGridCells(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmpty = firstOfMonth.weekday % 7;

    final cells = <DateTime?>[
      for (var i = 0; i < leadingEmpty; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];

    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  Future<DateTime?> _showAppointmentDatePicker(
    Set<DateTime> daysWithAppts,
  ) async {
    var focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    var pickedDay = _selectedDate;
    final today = DateTime.now();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final monthLabel = DateFormat('MMMM yyyy').format(focusedMonth);
            final headerDate = DateFormat('EEE, MMM d').format(pickedDay);
            final cells = _monthGridCells(focusedMonth);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select date',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headerDate,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              focusedMonth = DateTime(
                                focusedMonth.year,
                                focusedMonth.month - 1,
                                1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _navy,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              focusedMonth = DateTime(
                                focusedMonth.year,
                                focusedMonth.month + 1,
                                1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        _WeekdayLabel('S'),
                        _WeekdayLabel('M'),
                        _WeekdayLabel('T'),
                        _WeekdayLabel('W'),
                        _WeekdayLabel('T'),
                        _WeekdayLabel('F'),
                        _WeekdayLabel('S'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisExtent: 48,
                      ),
                      itemCount: cells.length,
                      itemBuilder: (context, index) {
                        final cellDate = cells[index];
                        if (cellDate == null) {
                          return const SizedBox.shrink();
                        }

                        final isSelected = isSameCalendarDay(
                          cellDate,
                          pickedDay,
                        );
                        final isToday = isSameCalendarDay(cellDate, today);
                        final hasAppointments = _dayHasAppointment(
                          cellDate,
                          daysWithAppts,
                        );

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              pickedDay = DateTime(
                                cellDate.year,
                                cellDate.month,
                                cellDate.day,
                              );
                            });
                          },
                          customBorder: const CircleBorder(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? _navy : null,
                                  border: isToday && !isSelected
                                      ? Border.all(color: _navy, width: 1.5)
                                      : null,
                                ),
                                child: Text(
                                  '${cellDate.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected ? Colors.white : _navy,
                                  ),
                                ),
                              ),
                              _buildDayStatusDot(
                                hasAppointments,
                                onSelectedBackground: isSelected,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, pickedDay),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate(Set<DateTime> daysWithAppts) async {
    final picked = await _showAppointmentDatePicker(daysWithAppts);
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = DateTime(day.year, day.month, day.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Object?>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load appointments.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? const [];
        final dayDocs = _docsForSelectedDay(allDocs);
        final summary = _summarizeDay(dayDocs);
        final mapping = mapFirestoreDocsToCalendarAppointments(dayDocs);
        final daysWithAppts = _daysWithAppointments(allDocs);
        final selectedLabel = DateFormat('EEEE, MMM d, yyyy').format(_selectedDate);
        final monthYearLabel = DateFormat('MMMM yyyy').format(_selectedDate);
        final dayAbbr = DateFormat('EEE').format(_selectedDate).toUpperCase();
        final dayNumber = DateFormat('d').format(_selectedDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doctor Appointment View',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _navy,
                                fontSize: 20,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _pickDate(daysWithAppts),
                    tooltip: 'Pick a date',
                    style: IconButton.styleFrom(
                      backgroundColor: _summaryBlue,
                      foregroundColor: _navy,
                    ),
                    icon: const Icon(Icons.calendar_month_outlined, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _weekStripDays.length,
                itemBuilder: (context, index) {
                  final day = _weekStripDays[index];
                  final isSelected = isSameCalendarDay(day, _selectedDate);
                  final hasAppointments = _dayHasAppointment(day, daysWithAppts);
                  final dayName = DateFormat('EEE').format(day);
                  final dayNum = DateFormat('d').format(day);

                  return Padding(
                    padding: EdgeInsets.only(right: index < 6 ? 10 : 0),
                    child: InkWell(
                      onTap: () => _selectDay(day),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: isSelected ? 62 : 56,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? _navy : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _navy
                                : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _navy.withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dayName,
                              style: TextStyle(
                                fontSize: isSelected ? 12 : 11,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : Colors.grey.shade600,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dayNum,
                              style: TextStyle(
                                fontSize: isSelected ? 19 : 16,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : _navy,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildDayStatusDot(
                              hasAppointments,
                              onSelectedBackground: isSelected,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _summaryBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Appointments: ${summary.total}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.newCount} New, ${summary.followUpCount} Follow-up',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    monthYearLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dayAbbr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dayNumber,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _buildTimeline(mapping),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeline(StaffCalendarMappingResult mapping) {
    final slots = _clinicTimeSlots;
    final totalHeight = slots.length * _slotHeight;

    final blocks = <Widget>[];
    for (final doc in mapping.metaByDocId.entries) {
      final meta = doc.value;
      final rawDoc = mapping.appointments
          .where((a) => a.notes == doc.key)
          .toList();
      if (rawDoc.isEmpty) continue;

      final appt = rawDoc.first;
      if (appt.isAllDay) continue;

      final slotIndex = _slotIndexForTime(meta.time);
      final durationSlots = ((appt.endTime.difference(appt.startTime).inMinutes) /
              15)
          .ceil()
          .clamp(1, slots.length - slotIndex);

      final isNew = staffCalendarTileIsNewPatient(meta);
      final palette = isNew
          ? (
              bg: const Color(0xFFF3E5F5),
              border: Colors.purple.shade200,
              text: Colors.purple.shade900,
            )
          : (
              bg: _summaryBlue,
              border: Colors.blue.shade200,
              text: Colors.blue.shade900,
            );

      blocks.add(
        Positioned(
          top: slotIndex * _slotHeight + 2,
          left: 4,
          right: 4,
          height: durationSlots * _slotHeight - 4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                showStaffCalendarAppointmentDetailSheet(
                  context: context,
                  meta: meta,
                  doctorId: widget.doctorId,
                  doctorName: widget.doctorName,
                  onAppointmentChanged: () {
                    if (mounted) setState(() {});
                  },
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: palette.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      meta.patientTypeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColumnWidth,
            height: totalHeight,
            child: Column(
              children: [
                for (final slot in slots)
                  SizedBox(
                    height: _slotHeight,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          slot,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    for (var i = 0; i < slots.length; i++)
                      Container(
                        height: _slotHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: i == slots.length - 1 ? 0 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                ...blocks,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
