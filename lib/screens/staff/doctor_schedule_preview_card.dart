import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../models/doctor_model.dart';
import 'doctor_calendar_view.dart';
import 'staff_appointment_calendar_mapper.dart';
import 'staff_calendar_appointment_tile.dart';
import 'staff_calendar_slot_settings.dart';

/// Tappable preview: mini day view for today → opens [DoctorCalendarView].
class DoctorSchedulePreviewCard extends StatelessWidget {
  const DoctorSchedulePreviewCard({super.key, required this.doctor});

  final DoctorModel doctor;

  static const _navy = Color(0xFF1A365D);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Object?>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctor.id)
          .snapshots(),
      builder: (context, snapshot) {
        final today = DateTime.now();
        final mapping = mapFirestoreDocsToCalendarAppointments(
          snapshot.data?.docs ?? const [],
        );
        final todays = mapping.appointments
            .where((a) => isSameCalendarDay(a.startTime, today))
            .toList();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => DoctorCalendarView(
                    doctorId: doctor.id,
                    doctorName: doctor.name,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _navy.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.person,
                            color: _navy,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${doctor.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _navy,
                                ),
                              ),
                              Text(
                                'Today · ${todays.length} slot${todays.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 200,
                        child: AbsorbPointer(
                          child: SfCalendar(
                            view: CalendarView.day,
                            initialDisplayDate: today,
                            dataSource:
                                StaffAppointmentCalendarDataSource(todays),
                            specialRegions:
                                StaffCalendarSlotSettings
                                    .preClinicBufferRegions,
                            headerStyle: const CalendarHeaderStyle(
                              textStyle: TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            todayHighlightColor: _navy,
                            backgroundColor: const Color(0xFFF7FAFC),
                            headerHeight: 36,
                            showNavigationArrow: false,
                            allowViewNavigation: false,
                            timeSlotViewSettings:
                                StaffCalendarSlotSettings.preview,
                            appointmentTextStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            appointmentBuilder: (context, details) =>
                                staffCalendarAppointmentBuilder(
                              context,
                              details,
                              mapping.metaByDocId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
