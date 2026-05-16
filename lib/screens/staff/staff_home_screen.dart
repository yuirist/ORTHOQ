import 'package:flutter/material.dart';

import '../../models/user_model.dart';
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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      StaffDashboardPage(userProfile: widget.userProfile),
      const PatientVerificationPage(),
      const DoctorRequestsPage(),
      const DelayNotificationsPage(),
      DoctorManagementPage(userProfile: widget.userProfile),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(
          context,
        ).bottomNavigationBarTheme.unselectedItemColor,
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Verification',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Reschedule Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Delay Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
