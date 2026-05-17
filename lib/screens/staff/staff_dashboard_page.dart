import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../services/doctor_service.dart';
import '../../utils/staff_scope.dart';
import 'doctor_schedule_preview_card.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key, this.userProfile});

  final UserModel? userProfile;

  static const Color _navy = OrthoqColors.slateNavy;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final DoctorService _doctorService = DoctorService();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        backgroundColor: primary,
        foregroundColor: onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/welcome', (route) => false);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _StaffDashboardBody(
        doctorService: _doctorService,
        userProfile: widget.userProfile,
      ),
    );
  }
}

class _StaffDashboardBody extends StatelessWidget {
  const _StaffDashboardBody({
    required this.doctorService,
    this.userProfile,
  });

  final DoctorService doctorService;
  final UserModel? userProfile;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in.'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final assigned = StaffScope.assignedDoctorIds(userSnap.data?.data());

        return StreamBuilder<List<DoctorModel>>(
          stream: doctorService.getActiveDoctors(),
          builder: (context, doctorSnap) {
            if (doctorSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (doctorSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load doctors.\n${doctorSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final all = doctorSnap.data ?? [];
            final doctors = assigned.isEmpty
                ? <DoctorModel>[]
                : all.where((d) => assigned.contains(d.id)).toList();
            final previewDoctors = doctors.take(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    userProfile != null &&
                            userProfile!.fullName.trim().isNotEmpty
                        ? 'Welcome, ${userProfile!.fullName.trim()}'
                        : 'Doctor Schedule Overview',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: StaffDashboardPage._navy,
                    ),
                  ),
                  if (userProfile != null &&
                      userProfile!.fullName.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Doctor Schedule Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: StaffDashboardPage._navy,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    assigned.isEmpty
                        ? 'An admin must assign exactly 3 doctors to your account before schedules appear here.'
                        : 'Only your assigned doctors are shown. Tap a card for calendar view.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (doctors.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          assigned.isEmpty
                              ? 'No assigned doctors yet. Ask an administrator to use Admin → Assign staff.'
                              : 'No active doctors match your assignment.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < previewDoctors.length; i++) ...[
                          if (i > 0) const SizedBox(height: 18),
                          DoctorSchedulePreviewCard(doctor: previewDoctors[i]),
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
