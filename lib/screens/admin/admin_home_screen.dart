import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/orthoq_colors.dart';
import '../auth/register_screen.dart';
import '../auth/welcome_screen.dart';
import 'admin_assign_staff_page.dart';
import 'admin_clinic_settings_page.dart';
import 'admin_doctor_list_page.dart';
import 'admin_edit_staff_screen.dart';
import 'admin_staff_list_page.dart';
/// Admin portal — Hospital Kajang OrthoQ administrator console.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.uid,
    this.userProfile,
  });

  final String uid;
  final UserModel? userProfile;

  static const Color navy = OrthoqColors.navy;

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
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AdminHomeScreen.navy,
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
        onAssignStaff: () {
          Navigator.pop(context);
          _openPage(const AdminAssignStaffPage());
        },
        onClinicSettings: () {
          Navigator.pop(context);
          _openPage(const AdminClinicSettingsPage());
        },
        onLogout: _logout,
      ),
      body: RefreshIndicator(
        color: AdminHomeScreen.navy,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading(title: 'Clinic overview'),
                    const SizedBox(height: 12),
                    StreamBuilder<AdminOverviewStats>(
                      stream: _adminService.watchOverviewStats(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'Statistics unavailable: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        }
                        return _StatsRow(
                          stats: snapshot.data ?? const AdminOverviewStats(),
                          loading: !snapshot.hasData,
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    const _SectionHeading(title: 'Staff management'),
                    const SizedBox(height: 12),
                    _StaffManagementCard(
                      adminService: _adminService,
                      onAddStaff: () => _openPage(
                        const RegisterScreen(userType: 'staff'),
                      ),
                      onViewAll: () => _openPage(const AdminStaffListPage()),
                      onEditStaff: (member) => _openPage(
                        AdminEditStaffScreen(staff: member),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top banner: Admin Dashboard + Hospital Kajang.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: AdminHomeScreen.navy,
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
              letterSpacing: 0.3,
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
          const SizedBox(height: 4),
          Text(
            'Orthopaedic Outpatient Clinic · OrthoQ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Signed in as $displayName',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AdminHomeScreen.navy,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.loading});

  final AdminOverviewStats stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _StatCard(
            label: 'Total Patients',
            value: loading ? '—' : '${stats.totalPatients}',
            icon: Icons.people_outline,
            loading: loading,
          ),
          _StatCard(
            label: 'Total Doctors',
            value: loading ? '—' : '${stats.totalDoctors}',
            icon: Icons.local_hospital_outlined,
            loading: loading,
          ),
          _StatCard(
            label: 'Total Staff',
            value: loading ? '—' : '${stats.totalStaff}',
            icon: Icons.badge_outlined,
            loading: loading,
          ),
        ];

        if (constraints.maxWidth >= 600) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AdminHomeScreen.navy, size: 30),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            if (loading)
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AdminHomeScreen.navy,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffManagementCard extends StatelessWidget {
  const _StaffManagementCard({
    required this.adminService,
    required this.onAddStaff,
    required this.onViewAll,
    required this.onEditStaff,
  });

  final AdminService adminService;
  final VoidCallback onAddStaff;
  final VoidCallback onViewAll;
  final void Function(UserModel member) onEditStaff;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.list, size: 20),
                    label: const Text('View All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminHomeScreen.navy,
                      side: const BorderSide(color: AdminHomeScreen.navy),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddStaff,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text('Add New Staff'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminHomeScreen.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            StreamBuilder<List<UserModel>>(
              stream: adminService.watchStaffMembers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Could not load staff: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final staff = snapshot.data!;
                if (staff.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No staff registered yet. Use Add New Staff to onboard team members.',
                      style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: staff.map((member) {
                    return _StaffListTile(
                      member: member,
                      onTap: () => onEditStaff(member),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffListTile extends StatelessWidget {
  const _StaffListTile({required this.member, required this.onTap});

  final UserModel member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = member.fullName.trim().isNotEmpty
        ? member.fullName.trim()[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AdminHomeScreen.navy.withValues(alpha: 0.1),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AdminHomeScreen.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AdminHomeScreen.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (member.phoneNumber.isNotEmpty)
                    Text(
                      member.phoneNumber,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AdminHomeScreen.navy),
          ],
        ),
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
    required this.onAssignStaff,
    required this.onClinicSettings,
    required this.onLogout,
  });

  final String displayName;
  final String email;
  final VoidCallback onDashboard;
  final VoidCallback onStaffList;
  final VoidCallback onDoctors;
  final VoidCallback onAssignStaff;
  final VoidCallback onClinicSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AdminHomeScreen.navy),
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
          _DrawerTile(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            onTap: onDashboard,
          ),
          _DrawerTile(icon: Icons.groups, label: 'Staff List', onTap: onStaffList),
          _DrawerTile(
            icon: Icons.medical_services_outlined,
            label: 'Doctors',
            onTap: onDoctors,
          ),
          _DrawerTile(
            icon: Icons.assignment_ind_outlined,
            label: 'Assign Staff',
            onTap: onAssignStaff,
          ),
          _DrawerTile(
            icon: Icons.settings_outlined,
            label: 'Clinic Settings',
            onTap: onClinicSettings,
          ),
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
      leading: Icon(icon, color: iconColor ?? AdminHomeScreen.navy),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? AdminHomeScreen.navy,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
