import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_widgets.dart';
import 'admin_edit_staff_screen.dart';

class AdminStaffListPage extends StatelessWidget {
  const AdminStaffListPage({super.key});

  static const Color _navy = OrthoqColors.navy;

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Scaffold(
      backgroundColor: OrthoqColors.adminPageBg,
      appBar: AppBar(
        title: const Text('Staff List'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No staff accounts yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: OrthoqSpacing.list,
            children: [
              ...List.generate(staff.length, (index) {
                final member = staff[index];
                final initials = member.fullName.isNotEmpty
                    ? member.fullName[0].toUpperCase()
                    : '?';

                return OrthoqInteractiveCard(
                  padding: EdgeInsets.zero,
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: _navy.withValues(alpha: 0.12),
                      child: Text(
                        initials,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _navy,
                            ),
                      ),
                    ),
                    title: Text(
                      member.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${member.email}\n'
                      '${member.phoneNumber.isNotEmpty ? member.phoneNumber : 'No phone'}'
                      '${member.staffId != null ? ' · ID: ${member.staffId}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right, color: _navy),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
