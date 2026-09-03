import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_navigation.dart';
import '../auth/welcome_screen.dart';
import 'admin_assign_staff_page.dart';
import 'appointment_report_screen.dart';
import 'admin_doctor_approvals_page.dart';
import 'admin_doctor_list_page.dart';
import 'admin_staff_list_page.dart';
import 'admin_patient_list_page.dart';

/// Admin portal — Hospital Kajang OrthoQ administrator console.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.uid,
    this.userProfile,
  });

  final String uid;
  final UserModel? userProfile;

  static const Color slateNavy = OrthoqColors.slateNavy;
  static const Color techBlue = OrthoqColors.techBlue;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminService _adminService = AdminService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _displayName {
    final name = widget.userProfile?.fullName.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Administrator';
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Sign out of the admin portal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _openPage(Widget page) {
    pushOrthoQPage(context, page);
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: OrthoqColors.adminPageBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AdminHomeScreen.slateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _AdminDrawer(
        displayName: _displayName,
        email: widget.userProfile?.email ?? '',
        onDashboard: () {
          Navigator.pop(context);
          _scrollToTop();
        },
        onStaffList: () {
          Navigator.pop(context);
          _openPage(const AdminStaffListPage());
        },
        onDoctors: () {
          Navigator.pop(context);
          _openPage(const AdminDoctorListPage());
        },
        onDoctorApprovals: () {
          Navigator.pop(context);
          _openPage(const AdminDoctorApprovalsPage());
        },
        onPatientList: () {
          Navigator.pop(context);
          _openPage(const AdminPatientListPage());
        },
        onAssignStaff: () {
          Navigator.pop(context);
          _openPage(const AdminAssignStaffPage());
        },
        onReports: () {
          Navigator.pop(context);
          _openPage(const AppointmentReportScreen());
        },
        onLogout: _logout,
      ),
      body: RefreshIndicator(
        color: AdminHomeScreen.slateNavy,
        onRefresh: () async {
          setState(() {});
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DashboardHeader(displayName: _displayName),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Clinic overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AdminHomeScreen.slateNavy,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<AdminOverviewStats>(
                stream: _adminService.watchOverviewStats(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Statistics unavailable: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return _ClinicOverviewRow(
                    stats: snapshot.data ?? const AdminOverviewStats(),
                    loading: !snapshot.hasData,
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: AdminHomeScreen.slateNavy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hospital Kajang',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Signed in as $displayName',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width horizontal row of navy metric cards.
class _ClinicOverviewRow extends StatelessWidget {
  const _ClinicOverviewRow({required this.stats, required this.loading});

  final AdminOverviewStats stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _NavyStatCard(
                label: 'Total Patients',
                value: loading ? '—' : '${stats.totalPatients}',
                icon: Icons.people_outline,
                loading: loading,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavyStatCard(
                label: 'Total Doctors',
                value: loading ? '—' : '${stats.totalDoctors}',
                icon: Icons.local_hospital_outlined,
                loading: loading,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavyStatCard(
                label: 'Total Staff',
                value: loading ? '—' : '${stats.totalStaff}',
                icon: Icons.badge_outlined,
                loading: loading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavyStatCard extends StatelessWidget {
  const _NavyStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.loading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AdminHomeScreen.slateNavy,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AdminHomeScreen.slateNavy.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.displayName,
    required this.email,
    required this.onDashboard,
    required this.onStaffList,
    required this.onDoctors,
    required this.onDoctorApprovals,
    required this.onPatientList,
    required this.onAssignStaff,
    required this.onReports,
    required this.onLogout,
  });

  final String displayName;
  final String email;
  final VoidCallback onDashboard;
  final VoidCallback onStaffList;
  final VoidCallback onDoctors;
  final VoidCallback onDoctorApprovals;
  final VoidCallback onPatientList;
  final VoidCallback onAssignStaff;
  final VoidCallback onReports;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AdminHomeScreen.slateNavy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          _DrawerTile(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: onDashboard),
          _DrawerTile(icon: Icons.groups, label: 'Staff List', onTap: onStaffList),
          _DrawerTile(icon: Icons.medical_services_outlined, label: 'Doctors List', onTap: onDoctors),
          _DrawerTile(icon: Icons.how_to_reg_outlined, label: 'Doctor Registrations', onTap: onDoctorApprovals),
          _DrawerTile(icon: Icons.people_outline, label: 'Patient List', onTap: onPatientList),
          _DrawerTile(icon: Icons.assignment_ind_outlined, label: 'Assign Staff', onTap: onAssignStaff),
          _DrawerTile(icon: Icons.bar_chart, label: 'Reports', onTap: onReports),
          const Spacer(),
          const Divider(height: 1),
          _DrawerTile(
            icon: Icons.logout,
            label: 'Log Out',
            onTap: onLogout,
            textColor: Colors.red,
            iconColor: Colors.red,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AdminHomeScreen.slateNavy),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? AdminHomeScreen.slateNavy,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
