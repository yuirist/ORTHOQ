import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../theme/orthoq_colors.dart';
import 'delay_notifications_page.dart';
import 'doctor_management_page.dart';
import 'doctor_requests_page.dart';
import 'patient_verification_page.dart';
import 'staff_dashboard_page.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.userProfile});

  /// Profile loaded at login (safe Timestamp parsing applied).
  final UserModel? userProfile;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _currentIndex = 0;

  void _onRejectionComplete(String patientEmail) {
    if (!mounted) return;

    // Stay on / return to the verification list tab.
    setState(() => _currentIndex = 1);

    final messenger = ScaffoldMessenger.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Successfully sent rejection email to $patientEmail.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: OrthoqColors.navy,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    });
  }

  Widget _rescheduleNavIcon({required bool selected}) {
    final iconColor =
        selected ? OrthoqColors.navy : const Color(0xFF64748B);
    final icon = Icon(Icons.schedule, color: iconColor);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('doctor_delays')
          .where('status', isEqualTo: 'pending_staff_action')
          .snapshots(),
      builder: (context, snapshot) {
        final hasPending = (snapshot.data?.docs.length ?? 0) > 0;
        if (!hasPending) return icon;

        return Badge(
          isLabelVisible: false,
          backgroundColor: const Color(0xFFE53935),
          smallSize: 9,
          child: icon,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StaffDashboardPage(userProfile: widget.userProfile),
          PatientVerificationPage(
            onRejectionComplete: _onRejectionComplete,
          ),
          const DoctorRequestsPage(),
          const DelayNotificationsPage(),
          DoctorManagementPage(userProfile: widget.userProfile),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor:
            Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(
          context,
        ).bottomNavigationBarTheme.unselectedItemColor,
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Verification',
          ),
          BottomNavigationBarItem(
            icon: _rescheduleNavIcon(selected: false),
            activeIcon: _rescheduleNavIcon(selected: true),
            label: 'Reschedule Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Delay Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
