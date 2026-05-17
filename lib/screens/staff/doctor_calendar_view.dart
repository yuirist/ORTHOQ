import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'staff_appointment_calendar_mapper.dart';
import 'staff_calendar_appointment_tile.dart';
import 'staff_calendar_slot_settings.dart';

/// Full-screen staff calendar for one doctor (day / week / month).
class DoctorCalendarView extends StatefulWidget {
  const DoctorCalendarView({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  final String doctorId;
  final String doctorName;

  @override
  State<DoctorCalendarView> createState() => _DoctorCalendarViewState();
}

class _DoctorCalendarViewState extends State<DoctorCalendarView> {
  late final CalendarController _controller;
  CalendarView _view = CalendarView.week;

  static const _navy = OrthoqColors.slateNavy;
  static const _onNavy = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _controller = CalendarController()
      ..displayDate = DateTime.now()
      ..view = CalendarView.week;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToToday() {
    final now = DateTime.now();
    _controller.displayDate = now;
    _controller.selectedDate = now;
    setState(() {});
  }

  void _onViewChanged(CalendarView? v) {
    if (v == null) return;
    setState(() {
      _view = v;
      _controller.view = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(
          'Dr. ${widget.doctorName}',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _navy,
        foregroundColor: _onNavy,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final dropdown = DropdownButtonFormField<CalendarView>(
                      value: _view,
                      decoration: InputDecoration(
                        labelText: 'View',
                        labelStyle: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w600,
                        ),
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: CalendarView.day,
                          child: Text('Day'),
                        ),
                        DropdownMenuItem(
                          value: CalendarView.week,
                          child: Text('Week'),
                        ),
                        DropdownMenuItem(
                          value: CalendarView.month,
                          child: Text('Month'),
                        ),
                      ],
                      onChanged: _onViewChanged,
                    );
                    final todayBtn = Align(
                      alignment:
                          narrow ? Alignment.center : Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: _goToToday,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          foregroundColor: _navy,
                        ),
                        child: const Text('Today'),
                      ),
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dropdown,
                          const SizedBox(height: 10),
                          todayBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: dropdown),
                        const SizedBox(width: 12),
                        todayBtn,
                      ],
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: StreamBuilder<QuerySnapshot<Object?>>(
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
                  final docs = snapshot.data?.docs ?? const [];
                  final mapped =
                      mapFirestoreDocsToCalendarAppointments(docs);
                  final dataSource = StaffAppointmentCalendarDataSource(
                    mapped.appointments,
                  );

                  return SfCalendar(
                    controller: _controller,
                    view: _view,
                    dataSource: dataSource,
                    specialRegions:
                        StaffCalendarSlotSettings.preClinicBufferRegions,
                    todayHighlightColor: _navy,
                    backgroundColor: Colors.white,
                    cellBorderColor: Colors.grey.shade300,
                    headerStyle: const CalendarHeaderStyle(
                      textStyle: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    viewHeaderStyle: ViewHeaderStyle(
                      backgroundColor: Colors.grey.shade100,
                      dayTextStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                      dateTextStyle: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    timeSlotViewSettings: StaffCalendarSlotSettings.fullCalendar,
                    monthViewSettings: const MonthViewSettings(
                      appointmentDisplayMode:
                          MonthAppointmentDisplayMode.appointment,
                      showAgenda: true,
                    ),
                    appointmentTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    appointmentBuilder: (context, details) =>
                        staffCalendarAppointmentBuilder(
                      context,
                      details,
                      mapped.metaByDocId,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
