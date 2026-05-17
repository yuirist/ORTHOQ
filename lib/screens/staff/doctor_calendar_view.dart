import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'staff_appointment_calendar_mapper.dart';
import 'staff_calendar_appointment_tile.dart';
import 'staff_calendar_slot_settings.dart';
import 'staff_manual_appointment_sheet.dart';

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

  static const _navy = OrthoqColors.navy;
  static const _currentTimeIndicatorColor = Color(0xFFFF5722);

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

  void _openManualAppointmentSheet() {
    showStaffManualAppointmentSheet(
      context: context,
      doctorId: widget.doctorId,
      doctorName: widget.doctorName,
      initialDate: _controller.displayDate,
    );
  }

  InputDecoration _navyToolbarFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFFCBD5E1),
        fontWeight: FontWeight.w500,
      ),
      isDense: true,
      filled: true,
      fillColor: _navy.withValues(alpha: 0.35),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF94A3B8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: OrthoqColors.scaffoldBg,
        appBar: AppBar(
          title: Text(
            'Dr. ${widget.doctorName}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openManualAppointmentSheet,
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          tooltip: 'Add appointment',
          child: const Icon(Icons.add),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: _navy,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final dropdown = DropdownButtonFormField<CalendarView>(
                      value: _view,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      iconEnabledColor: Colors.white,
                      decoration: _navyToolbarFieldDecoration('View'),
                      items: const [
                        DropdownMenuItem(
                          value: CalendarView.day,
                          child: Text(
                            'Day',
                            style: TextStyle(color: _navy),
                          ),
                        ),
                        DropdownMenuItem(
                          value: CalendarView.week,
                          child: Text(
                            'Week',
                            style: TextStyle(color: _navy),
                          ),
                        ),
                        DropdownMenuItem(
                          value: CalendarView.month,
                          child: Text(
                            'Month',
                            style: TextStyle(color: _navy),
                          ),
                        ),
                      ],
                      onChanged: _onViewChanged,
                    );
                    final todayBtn = OutlinedButton(
                      onPressed: _goToToday,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(88, 44),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      child: const Text('Today'),
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
                      showCurrentTimeIndicator: true,
                      todayHighlightColor: _currentTimeIndicatorColor,
                      backgroundColor: Colors.white,
                      cellBorderColor: OrthoqColors.lightSlate,
                      headerStyle: StaffCalendarSlotSettings.navyHeader,
                      viewHeaderStyle: ViewHeaderStyle(
                        backgroundColor: Colors.grey.shade50,
                        dayTextStyle: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        dateTextStyle: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      timeSlotViewSettings:
                          StaffCalendarSlotSettings.fullCalendar,
                      monthViewSettings: const MonthViewSettings(
                        appointmentDisplayMode:
                            MonthAppointmentDisplayMode.appointment,
                        showAgenda: true,
                      ),
                      appointmentTextStyle: const TextStyle(
                        color: OrthoqColors.navy,
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
      ),
    );
  }
}
