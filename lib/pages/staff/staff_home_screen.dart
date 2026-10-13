import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/doctor_delay_notification_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_widgets.dart';
import 'delay_notifications_page.dart';
import 'doctor_requests_page.dart';
import 'patient_verification_page.dart';
import 'staff_dashboard_page.dart';
import 'staff_patient_page.dart';

/// Staff portal shell — modern bottom navigation and tab content.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  static const int _rescheduleTabIndex = 2;
  static const Color _badgeRed = Color(0xFFE53935);

  int _currentIndex = 0;
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
            content: Text('Rejection email sent to $patientEmail.'),
            backgroundColor: OrthoqColors.navy,
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

  Widget _navIcon(IconData outlined, IconData filled, bool selected) {
    return Icon(selected ? filled : outlined);
  }

  Widget _rescheduleDestinationIcon({
    required bool selected,
    required int badgeCount,
  }) {
    final icon = _navIcon(
      Icons.event_repeat_outlined,
      Icons.event_repeat_rounded,
      selected,
    );
    if (badgeCount <= 0) return icon;
    final label = badgeCount > 99 ? '99+' : '$badgeCount';
    return Badge(
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: _badgeRed,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StaffDashboardPage(userProfile: widget.userProfile),
          PatientVerificationPage(onRejectionComplete: _onRejectionComplete),
          DoctorRequestsPage(userProfile: widget.userProfile),
          DelayNotificationsPage(userProfile: widget.userProfile),
          StaffPatientPage(userProfile: widget.userProfile),
        ],
      ),
      bottomNavigationBar: StreamBuilder(
        stream: DoctorDelayNotificationService.getPendingDoctorDelaysStream(),
        builder: (context, pendingSnap) {
          final pendingCount = pendingSnap.hasData
              ? DoctorDelayNotificationService.pendingCount(pendingSnap.data!)
              : 0;
          final badgeCount = _badgeCount(pendingCount);

          return OrthoqModernBottomNav(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => _onNavTap(index, pendingCount),
            destinations: [
              NavigationDestination(
                icon: _navIcon(Icons.dashboard_outlined, Icons.dashboard_rounded, false),
                selectedIcon: _navIcon(Icons.dashboard_outlined, Icons.dashboard_rounded, true),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: _navIcon(Icons.verified_user_outlined, Icons.verified_user_rounded, false),
                selectedIcon: _navIcon(Icons.verified_user_outlined, Icons.verified_user_rounded, true),
                label: 'Verify',
              ),
              NavigationDestination(
                icon: _rescheduleDestinationIcon(selected: false, badgeCount: badgeCount),
                selectedIcon: _rescheduleDestinationIcon(selected: true, badgeCount: badgeCount),
                label: 'Reschedule',
              ),
              NavigationDestination(
                icon: _navIcon(Icons.notifications_outlined, Icons.notifications_rounded, false),
                selectedIcon: _navIcon(Icons.notifications_outlined, Icons.notifications_rounded, true),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: _navIcon(Icons.people_outline, Icons.people_rounded, false),
                selectedIcon: _navIcon(Icons.people_outline, Icons.people_rounded, true),
                label: 'Patients',
              ),
            ],
          );
        },
      ),
    );
  }
}
