import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/appointment_model.dart';
import 'reschedule_appointment_screen.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../services/notification_service.dart';

class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Appointments'),
          backgroundColor: OrthoqColors.slateNavy,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: const Center(
          child: Text('Please log in to view your appointments'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: user.uid)
            .orderBy('appointmentDate')
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(OrthoqColors.slateNavy),
              ),
            );
          }

          // Error state - Display error message clearly
          if (snapshot.hasError) {
            final error = snapshot.error;
            final errorMessage = error.toString();
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading Appointments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error Details:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (errorMessage.contains('failed-precondition') ||
                              errorMessage.contains('index'))
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Index Building in Progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'The composite index for this query is currently being built. Please wait a few minutes and try again.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Trigger rebuild to retry
                        (context as Element).markNeedsBuild();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrthoqColors.slateNavy,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Success state
          final appointments = snapshot.data?.docs ?? [];

          if (appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_note,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Appointments Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You don\'t have any appointments yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          // Display appointments in ListView.builder
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final doc = appointments[index];
              final appointment = AppointmentModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
              return _AppointmentCard(
                appointment: appointment,
                appointmentService: AppointmentService(),
                notificationService: NotificationService(),
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
  final AppointmentService appointmentService;
  final NotificationService notificationService;

  const _AppointmentCard({
    required this.appointment,
    required this.appointmentService,
    required this.notificationService,
  });

  Future<void> _viewReferral(BuildContext context) async {
    if (appointment.referralLetterUrl == null ||
        appointment.referralLetterUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No referral letter available for this appointment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final url = Uri.parse(appointment.referralLetterUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open referral letter link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelAppointment(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await appointmentService.cancelAppointment(appointment.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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

  Color _getStatusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'booked':
      case 'pending':
        return Theme.of(context).colorScheme.secondary;
      case 'confirmed':
        return OrthoqColors.slateNavy;
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

  bool get _isPending =>
      appointment.status.toLowerCase() == 'pending';

  String get _pendingStatusMessage {
    final bookedOn = DateFormat('d MMMM y').format(appointment.createdAt);
    return 'Appointment booked on $bookedOn still pending and waiting for staff to approve referral letter';
  }

  @override
  Widget build(BuildContext context) {
    final isPast = appointment.appointmentDate.isBefore(DateTime.now());
    final canReschedule = !isPast &&
        appointment.status.toLowerCase() != 'cancelled' &&
        appointment.status.toLowerCase() != 'completed';
    final canCancel = !isPast &&
        appointment.status.toLowerCase() != 'cancelled' &&
        appointment.status.toLowerCase() != 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor name, specialization, and status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${appointment.doctorName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder(
                        future: DoctorService()
                            .getDoctorById(appointment.doctorId),
                        builder: (context, snapshot) {
                          final specialization =
                              snapshot.data?.specialization.trim();
                          if (specialization == null ||
                              specialization.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            specialization,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                            softWrap: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

            // Date/time or pending status
            if (_isPending)
              Text(
                _pendingStatusMessage,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                  height: 1.45,
                ),
                softWrap: true,
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMMM d, y')
                          .format(appointment.appointmentDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    appointment.appointmentTime.trim().isEmpty
                        ? '—'
                        : appointment.appointmentTime,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            
            // View Referral Button (if referral exists)
            if (appointment.referralLetterUrl != null &&
                appointment.referralLetterUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _viewReferral(context),
                  icon: const Icon(Icons.description),
                  label: const Text('View Referral'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OrthoqColors.slateNavy,
                    side: const BorderSide(color: OrthoqColors.slateNavy),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            
            // Reschedule and Cancel buttons
            if (canReschedule || canCancel) ...[
              if (appointment.referralLetterUrl != null &&
                  appointment.referralLetterUrl!.isNotEmpty)
                const SizedBox(height: 12),
              Row(
                children: [
                  if (canReschedule)
                    Expanded(
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
                        label: const Text('Reschedule'),
                      ),
                    ),
                  if (canReschedule && canCancel) const SizedBox(width: 8),
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelAppointment(context),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            
            // Reschedule request indicator
            if (appointment.hasRescheduleRequest)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
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
                        'Reschedule request pending',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

