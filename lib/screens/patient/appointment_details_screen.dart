import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_model.dart';
import 'reschedule_appointment_screen.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  final AppointmentModel appointment;

  const AppointmentDetailsScreen({super.key, required this.appointment});

  String _displayTime(String rawTime) {
    if (rawTime.trim().isEmpty || rawTime.trim().toUpperCase() == 'TBD') {
      return 'Awaiting Staff Confirmation';
    }
    return rawTime;
  }

  String _displayStatus(String rawStatus) {
    if (rawStatus.toLowerCase() == 'pending') {
      return 'Pending Staff Approval';
    }
    return rawStatus.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isPast = appointment.appointmentDate.isBefore(DateTime.now());
    final canReschedule = !isPast &&
        appointment.status != 'cancelled' &&
        appointment.status != 'completed';
    final canCancel = !isPast &&
        appointment.status != 'cancelled' &&
        appointment.status != 'completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Info Card
            Card(
              color: const Color(0xFF1A365D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: const Icon(
                        Icons.person,
                        size: 35,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${appointment.doctorName}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appointment.appointmentType == 'new_patient'
                                ? 'New Patient Appointment'
                                : 'Follow-Up Appointment',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Appointment Details
            const Text(
              'Appointment Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: DateFormat('EEEE, MMMM d, y').format(appointment.appointmentDate),
            ),

            const SizedBox(height: 12),

            _DetailRow(
              icon: Icons.access_time,
              label: 'Time',
              value: _displayTime(appointment.appointmentTime),
            ),

            const SizedBox(height: 12),

            _DetailRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: _displayStatus(appointment.status),
              valueColor: _getStatusColor(context, appointment.status),
            ),

            const SizedBox(height: 12),

            _DetailRow(
              icon: Icons.category,
              label: 'Type',
              value: appointment.appointmentType == 'new_patient'
                  ? 'New Patient'
                  : 'Follow-Up',
            ),

            if (appointment.referralLetterUrl != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.description,
                label: 'Referral Letter',
                value: 'Uploaded',
                valueColor: Colors.green,
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (canReschedule || canCancel) ...[
              if (canReschedule)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RescheduleAppointmentScreen(
                            appointment: appointment,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('Reschedule Appointment'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF1A365D)),
                      foregroundColor: const Color(0xFF1A365D),
                    ),
                  ),
                ),
              if (canReschedule && canCancel) const SizedBox(height: 12),
              if (canCancel)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showCancelDialog(context);
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Appointment'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement cancel appointment
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appointment cancellation feature coming soon'),
                ),
              );
            },
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

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
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

















