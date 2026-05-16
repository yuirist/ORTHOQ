import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/orthoq_colors.dart';
import '../auth/register_screen.dart';
import 'admin_assign_staff_page.dart';
import 'admin_edit_staff_screen.dart';

class AdminStaffListPage extends StatelessWidget {
  const AdminStaffListPage({super.key});

  static const Color _navy = OrthoqColors.navy;

  void _openAddStaff(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(userType: 'staff'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Staff List'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => _openAddStaff(context),
            icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
            label: const Text(
              'Add New Staff',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined, color: Colors.white),
            tooltip: 'Assign doctors',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAssignStaffPage(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddStaff(context),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add New Staff'),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: adminService.watchStaffMembers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load staff: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }

          final staff = snapshot.data!;
          if (staff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No staff accounts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap Add New Staff to register a team member.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: staff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = staff[index];
              final initials = member.fullName.isNotEmpty
                  ? member.fullName[0].toUpperCase()
                  : '?';

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _navy.withValues(alpha: 0.12),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    member.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  subtitle: Text(
                    '${member.email}\n'
                    '${member.phoneNumber.isNotEmpty ? member.phoneNumber : 'No phone'}'
                    '${member.staffId != null ? ' · ID: ${member.staffId}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right, color: _navy),
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminEditStaffScreen(staff: member),
                      ),
                    );
                    if (updated == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${member.fullName} updated'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
