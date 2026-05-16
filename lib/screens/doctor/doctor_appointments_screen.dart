import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/appointment_service.dart';
import '../../models/appointment_model.dart';
import 'request_schedule_change_screen.dart';

class DoctorAppointmentsScreen extends StatelessWidget {
  final bool showTodayOnly;

  const DoctorAppointmentsScreen({super.key, this.showTodayOnly = false});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.currentUser?.uid ?? '';
    final appointmentService = AppointmentService();

    return Scaffold(
      appBar: AppBar(
        title: Text(showTodayOnly ? "Today's Appointments" : 'All Appointments'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: showTodayOnly
          ? StreamBuilder<List<AppointmentModel>>(
              stream: appointmentService.getDoctorAppointmentsByDate(
                userId,
                DateTime.now(),
              ),
              builder: (context, snapshot) => _buildAppointmentsList(context, snapshot),
            )
          : StreamBuilder<List<AppointmentModel>>(
              stream: appointmentService.getDoctorAppointments(userId),
              builder: (context, snapshot) => _buildAppointmentsList(context, snapshot),
            ),
    );
  }

  Widget _buildAppointmentsList(
    BuildContext context,
    AsyncSnapshot<List<AppointmentModel>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }

    final appointments = snapshot.data ?? [];

    if (appointments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No appointments found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        return _AppointmentCard(
          appointment: appointments[index],
        );
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'booked':
        return Theme.of(context).colorScheme.secondary;
      case 'rescheduled':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPast = appointment.appointmentDate.isBefore(DateTime.now());
    final canRequestChange = !isPast && 
                            appointment.status != 'cancelled' && 
                            appointment.status != 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appointment.patientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(context, appointment.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(appointment.appointmentDate),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  appointment.appointmentTime,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  appointment.appointmentType == 'new_patient'
                      ? 'New Patient'
                      : 'Follow-Up',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            if (appointment.hasDoctorScheduleChange && !appointment.scheduleChangeApproved)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pending, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Schedule change request pending',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            if (canRequestChange) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequestScheduleChangeScreen(
                          appointment: appointment,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Request Schedule Change'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


