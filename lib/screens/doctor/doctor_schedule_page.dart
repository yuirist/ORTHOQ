import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../providers/auth_provider.dart';
import '../staff/staff_appointment_calendar_mapper.dart';
import '../staff/staff_calendar_appointment_tile.dart';
import '../staff/staff_calendar_slot_settings.dart';

class DoctorSchedulePage extends StatefulWidget {
  const DoctorSchedulePage({super.key});

  @override
  State<DoctorSchedulePage> createState() => _DoctorSchedulePageState();
}

class _DoctorSchedulePageState extends State<DoctorSchedulePage> {
  DateTime _selectedDate = DateTime.now();

  DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime _endOfDay(DateTime date) => _startOfDay(date).add(const Duration(days: 1));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Calendar-day keys (`yyyy-MM-dd`) that have at least one appointment in the loaded range.
  static Set<String> _busyDayKeysFromSnapshot(QuerySnapshot snapshot) {
    final keys = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final raw = data['appointmentDate'];
      if (raw is! Timestamp) continue;
      final d = raw.toDate();
      keys.add(DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day)));
    }
    return keys;
  }

  Widget _buildHorizontalDatePicker(Set<String> daysWithAppointments) {
    final start = _selectedDate.subtract(const Duration(days: 3));
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = start.add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final dayKey = DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));
          final hasAppointments = daysWithAppointments.contains(dayKey);
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              width: 72,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A365D) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1A365D) : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF1A365D),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasAppointments ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Week strip (7 days) with red/green dots; listens to the same appointments collection as the list below.
  Widget _buildDateStripWithStatusIndicators(String doctorName) {
    if (doctorName.isEmpty) {
      return _buildHorizontalDatePicker({});
    }
    final firstVisible = _selectedDate.subtract(const Duration(days: 3));
    final lastVisible = firstVisible.add(const Duration(days: 6));
    final rangeStart = _startOfDay(firstVisible);
    final rangeEnd = _endOfDay(lastVisible);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorName', isEqualTo: doctorName)
          .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .where('appointmentDate', isLessThan: Timestamp.fromDate(rangeEnd))
          .orderBy('appointmentDate')
          .snapshots(),
      builder: (context, snapshot) {
        final busyKeys =
            snapshot.hasData ? _busyDayKeysFromSnapshot(snapshot.data!) : <String>{};
        return _buildHorizontalDatePicker(busyKeys);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final doctorName = authProvider.currentUserData?.fullName.trim() ?? '';
    final start = _startOfDay(_selectedDate);
    final end = _endOfDay(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Doctor Appointment View',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month, color: Color(0xFF1A365D)),
                ),
              ],
            ),
            Text(
              DateFormat('EEEE, MMM d, y').format(_selectedDate),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            _buildDateStripWithStatusIndicators(doctorName),
            const SizedBox(height: 16),
            if (doctorName.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Doctor profile is not loaded. Please sign in again.'),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('doctorName', isEqualTo: doctorName)
                      .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                      .where('appointmentDate', isLessThan: Timestamp.fromDate(end))
                      .orderBy('appointmentDate')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final errorText = snapshot.error.toString().toLowerCase();
                      // During composite index creation, treat as empty state.
                      if (errorText.contains('failed-precondition') ||
                          errorText.contains('requires an index') ||
                          errorText.contains('index')) {
                        return const Center(
                          child: Text('No appointments for this date'),
                        );
                      }
                      return const Center(
                        child: Text('No appointments for this date'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No appointments for this date.'),
                      );
                    }

                    final newCount = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final patientType = data['patientType']?.toString().toLowerCase() ?? '';
                      return patientType.contains('new');
                    }).length;
                    final followUpCount = docs.length - newCount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1A365D).withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Appointments: ${docs.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A365D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$newCount New, $followUpCount Follow-up',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final mapping =
                                  mapFirestoreDocsToCalendarAppointments(docs);
                              return SfCalendar(
                                view: CalendarView.day,
                                initialDisplayDate: _selectedDate,
                                dataSource: StaffAppointmentCalendarDataSource(
                                  mapping.appointments,
                                ),
                                specialRegions:
                                    StaffCalendarSlotSettings.preClinicBufferRegions,
                                todayHighlightColor: const Color(0xFF1A365D),
                                backgroundColor: Colors.white,
                                cellBorderColor: Colors.grey.shade300,
                                headerStyle: const CalendarHeaderStyle(
                                  textStyle: TextStyle(
                                    color: Color(0xFF1A365D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                timeSlotViewSettings:
                                    StaffCalendarSlotSettings.fullCalendar,
                                appointmentBuilder: (context, details) =>
                                    staffCalendarAppointmentBuilder(
                                  context,
                                  details,
                                  mapping.metaByDocId,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

}
