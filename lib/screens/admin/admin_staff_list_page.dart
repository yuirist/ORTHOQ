import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import 'admin_assign_staff_page.dart';
import 'admin_edit_staff_screen.dart';

class AdminStaffListPage extends StatelessWidget {
  const AdminStaffListPage({super.key});

  static const Color _navy = Color(0xFF0D1B2A);

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff List'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined),
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
            return const Center(child: CircularProgressIndicator());
          }

          final staff = snapshot.data!;
          if (staff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No staff accounts yet.\nRegister staff with role "staff" in Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: staff.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final member = staff[index];
              final initials = member.fullName.isNotEmpty
                  ? member.fullName[0].toUpperCase()
                  : '?';

              return ListTile(
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${member.email}\n'
                  '${member.phoneNumber.isNotEmpty ? member.phoneNumber : 'No phone'}'
                  '${member.staffId != null ? ' · ID: ${member.staffId}' : ''}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
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
              );
            },
          );
        },
      ),
    );
  }
}
