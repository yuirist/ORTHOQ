import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/doctor_delay_notification_service.dart';
import '../../theme/orthoq_colors.dart';
import 'delay_notifications_page.dart';
import 'doctor_management_page.dart';
import 'doctor_requests_page.dart';
import 'patient_verification_page.dart';
import 'staff_dashboard_page.dart';

/// Staff portal shell — bottom navigation and tab content.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.userProfile});

  /// Profile loaded at login (safe Timestamp parsing applied).
  final UserModel? userProfile;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  static const int _rescheduleTabIndex = 2;
  static const Color _badgeRed = Color(0xFFE53935);

  int _currentIndex = 0;

  /// Last pending count acknowledged when staff opens Reschedule Requests.
  int _acknowledgedPendingCount = 0;

  void _onRejectionComplete(String patientEmail) {
    if (!mounted) return;

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

  void _onNavTap(int index, int currentPendingCount) {
    setState(() {
      _currentIndex = index;
      if (index == _rescheduleTabIndex) {
        _acknowledgedPendingCount = currentPendingCount;
      }
    });
  }

  int _badgeCount(int pendingFromFirestore) {
    final unread = pendingFromFirestore - _acknowledgedPendingCount;
    return unread < 0 ? 0 : unread;
  }

  Widget _rescheduleNavIcon({
    required bool selected,
    required int badgeCount,
  }) {
    final iconColor =
        selected ? OrthoqColors.navy : const Color(0xFF64748B);
    final icon = Icon(Icons.schedule, color: iconColor);

    if (badgeCount <= 0) return icon;

    final label = badgeCount > 99 ? '99+' : '$badgeCount';

    return Badge(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
      backgroundColor: _badgeRed,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: icon,
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
      bottomNavigationBar: StreamBuilder(
        stream: DoctorDelayNotificationService.getPendingDoctorDelaysStream(),
        builder: (context, pendingSnap) {
          final pendingCount = pendingSnap.hasData
              ? DoctorDelayNotificationService.pendingCount(pendingSnap.data!)
              : 0;
          final badgeCount = _badgeCount(pendingCount);

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => _onNavTap(index, pendingCount),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context)
                .bottomNavigationBarTheme
                .selectedItemColor,
            unselectedItemColor: Theme.of(context)
                .bottomNavigationBarTheme
                .unselectedItemColor,
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
                icon: _rescheduleNavIcon(
                  selected: false,
                  badgeCount: badgeCount,
                ),
                activeIcon: _rescheduleNavIcon(
                  selected: true,
                  badgeCount: badgeCount,
                ),
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
          );
        },
      ),
    );
  }
}
