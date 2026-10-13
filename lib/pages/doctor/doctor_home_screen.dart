import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:orthoq_app/theme/orthoq_navigation.dart';
import 'package:orthoq_app/theme/orthoq_typography.dart';
import 'package:orthoq_app/theme/orthoq_widgets.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/appointment_service.dart';
import '../../models/appointment_model.dart';
import 'doctor_schedule_page.dart';
import 'notify_staff_delay_page.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/welcome',
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: OrthoqSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, _) {
                return OrthoqInteractiveCard(
                  margin: EdgeInsets.zero,
                  color: OrthoqColors.slateNavy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${authProvider.currentUserData?.fullName ?? ''}',
                        style: OrthoqTypography.headingMedium(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Today\'s clinic schedule',
                        style: OrthoqTypography.bodyMedium(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: OrthoqSpacing.lg),
            const OrthoqSectionHeader(title: 'Quick actions'),
            const SizedBox(height: OrthoqSpacing.sm),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickActionCard(
                    icon: Icons.today_rounded,
                    label: "Today's\nSchedule",
                    onTap: () {
                      pushOrthoQPage(
                        context,
                        DoctorSchedulePage(userProfile: widget.userProfile),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.campaign_outlined,
                    label: 'Notify Staff\nof Delay',
                    onTap: () {
                      pushOrthoQPage(context, const NotifyStaffDelayPage());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrthoqSpacing.lg),
            const OrthoqSectionHeader(title: "Today's appointments"),
            const SizedBox(height: OrthoqSpacing.sm),
            Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, _) {
                final userId = authProvider.currentUser?.uid ?? '';
                // Get doctor ID from user data
                // For now, using userId as doctorId (should be linked properly in real implementation)
                
                return StreamBuilder<List<AppointmentModel>>(
                  stream: _appointmentService.getDoctorAppointmentsByDate(
                    userId,
                    DateTime.now(),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const OrthoqSkeletonAppointmentCard();
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Unable to load appointments',
                        style: OrthoqTypography.bodyMedium(color: Colors.red),
                      );
                    }

                    final appointments = snapshot.data ?? [];

                    if (appointments.isEmpty) {
                      return const OrthoqEmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'No appointments today',
                        subtitle: 'Your schedule is clear for now',
                      );
                    }

                    return Column(
                      children: appointments.map((appointment) {
                        return _AppointmentCard(
                          appointment: appointment,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: OrthoqInteractiveCard(
        margin: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: OrthoqColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: OrthoqColors.slateNavy),
            ),
            const SizedBox(height: OrthoqSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: OrthoqTypography.bodySmall(color: OrthoqColors.navy),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return OrthoqInteractiveCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appointment.patientName,
                    style: OrthoqTypography.titleMedium(),
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


