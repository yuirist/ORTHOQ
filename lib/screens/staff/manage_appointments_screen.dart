import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/appointment_service.dart';
import '../../services/email_service.dart';
import '../../services/notification_service.dart';
import '../../models/appointment_model.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  final bool showPendingReschedules;
  final bool showPendingScheduleChanges;

  const ManageAppointmentsScreen({
    super.key,
    this.showPendingReschedules = false,
    this.showPendingScheduleChanges = false,
  });

  @override
  State<ManageAppointmentsScreen> createState() => _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final NotificationService _notificationService = NotificationService();

  Future<void> _approveReschedule(AppointmentModel appointment) async {
    try {
      await _appointmentService.approveReschedule(
        appointmentId: appointment.id,
      );

      await _notificationService.sendRescheduleNotification(
        userId: appointment.patientId,
        appointmentId: appointment.id,
        doctorName: appointment.doctorName,
        newDate: appointment.requestedDate ?? appointment.appointmentDate,
        newTime: appointment.requestedTime ?? appointment.appointmentTime,
      );

      final oldDateLabel =
          DateFormat.yMMMMd().format(appointment.appointmentDate);
      final newDateObj =
          appointment.requestedDate ?? appointment.appointmentDate;
      final newDateLabel = DateFormat.yMMMMd().format(newDateObj);
      final newTimeStr =
          appointment.requestedTime ?? appointment.appointmentTime;
      final patientEmail = appointment.email?.trim();
      if (patientEmail != null && patientEmail.isNotEmpty) {
        await EmailService().sendRescheduleEmail(
          patientEmail,
          appointment.patientName,
          oldDateLabel,
          newDateLabel,
          newTimeStr,
          appointment.doctorName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reschedule approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectReschedule(AppointmentModel appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Reschedule'),
        content: const Text('Are you sure you want to reject this reschedule request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _appointmentService.rejectReschedule(appointment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reschedule request rejected'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _approveScheduleChange(AppointmentModel appointment) async {
    try {
      await _appointmentService.approveDoctorScheduleChange(
        appointmentId: appointment.id,
      );

      await _notificationService.sendScheduleChangeNotification(
        userId: appointment.patientId,
        appointmentId: appointment.id,
        doctorName: appointment.doctorName,
        newDate: appointment.doctorRequestedDate ?? appointment.appointmentDate,
        newTime: appointment.doctorRequestedTime ?? appointment.appointmentTime,
      );

      final oldDateLabel =
          DateFormat.yMMMMd().format(appointment.appointmentDate);
      final newDateObj =
          appointment.doctorRequestedDate ?? appointment.appointmentDate;
      final newDateLabel = DateFormat.yMMMMd().format(newDateObj);
      final newTimeStr =
          appointment.doctorRequestedTime ?? appointment.appointmentTime;
      final patientEmail = appointment.email?.trim();
      if (patientEmail != null && patientEmail.isNotEmpty) {
        await EmailService().sendRescheduleEmail(
          patientEmail,
          appointment.patientName,
          oldDateLabel,
          newDateLabel,
          newTimeStr,
          appointment.doctorName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule change approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(AppointmentModel appointment, String status) async {
    try {
      await _appointmentService.updateAppointmentStatus(
        appointmentId: appointment.id,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<List<AppointmentModel>>(
        stream: _appointmentService.getAllAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          List<AppointmentModel> appointments = snapshot.data ?? [];

          if (widget.showPendingReschedules) {
            appointments = appointments
                .where((apt) => apt.hasRescheduleRequest)
                .toList();
          } else if (widget.showPendingScheduleChanges) {
            appointments = appointments
                .where((apt) => apt.hasDoctorScheduleChange && !apt.scheduleChangeApproved)
                .toList();
          }

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
                onApproveReschedule: _approveReschedule,
                onRejectReschedule: _rejectReschedule,
                onApproveScheduleChange: _approveScheduleChange,
                onUpdateStatus: _updateStatus,
              );
            },
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final Function(AppointmentModel) onApproveReschedule;
  final Function(AppointmentModel) onRejectReschedule;
  final Function(AppointmentModel) onApproveScheduleChange;
  final Function(AppointmentModel, String) onUpdateStatus;

  const _AppointmentCard({
    required this.appointment,
    required this.onApproveReschedule,
    required this.onRejectReschedule,
    required this.onApproveScheduleChange,
    required this.onUpdateStatus,
  });

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
    final isNewPatient = appointment.patientType.toLowerCase().contains('new');
    final patientTypeLabel = isNewPatient ? 'New Patient' : 'Follow-up';
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isNewPatient
                              ? const Color(0xFFDCEEFF)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          patientTypeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isNewPatient
                                ? const Color(0xFF1A365D)
                                : const Color(0xFF166534),
                          ),
                        ),
                      ),
                      Text(
                        'Dr. ${appointment.doctorName}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
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
            if (appointment.hasRescheduleRequest) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reschedule Request',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    if (appointment.requestedDate != null)
                      Text(
                        'New Date: ${DateFormat('EEEE, MMMM d, y').format(appointment.requestedDate!)}',
                      ),
                    if (appointment.requestedTime != null)
                      Text('New Time: ${appointment.requestedTime}'),
                    if (appointment.rescheduleReason != null)
                      Text('Reason: ${appointment.rescheduleReason}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onApproveReschedule(appointment),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onRejectReschedule(appointment),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (appointment.hasDoctorScheduleChange && !appointment.scheduleChangeApproved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.secondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor Schedule Change Request',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    if (appointment.doctorRequestedDate != null)
                      Text(
                        'New Date: ${DateFormat('EEEE, MMMM d, y').format(appointment.doctorRequestedDate!)}',
                      ),
                    if (appointment.doctorRequestedTime != null)
                      Text('New Time: ${appointment.doctorRequestedTime}'),
                    if (appointment.doctorChangeReason != null)
                      Text('Reason: ${appointment.doctorChangeReason}'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => onApproveScheduleChange(appointment),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                        ),
                        child: const Text('Approve Change'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Status Update Dropdown
            DropdownButtonFormField<String>(
              value: appointment.status,
              decoration: const InputDecoration(
                labelText: 'Update Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'booked', child: Text('Booked')),
                DropdownMenuItem(value: 'rescheduled', child: Text('Rescheduled')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onUpdateStatus(appointment, value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}


