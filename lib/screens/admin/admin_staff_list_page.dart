import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/orthoq_colors.dart';
import '../auth/register_screen.dart';
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AddStaffHeader(onPressed: () => _openAddStaff(context)),
                const SizedBox(height: 48),
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
                const SizedBox(height: 8),
                Text(
                  'Use Add New Staff above to register a team member.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _AddStaffHeader(onPressed: () => _openAddStaff(context)),
              const SizedBox(height: 12),
              ...List.generate(staff.length, (index) {
                final member = staff[index];
                final initials = member.fullName.isNotEmpty
                    ? member.fullName[0].toUpperCase()
                    : '?';

                return Padding(
                  padding: EdgeInsets.only(bottom: index < staff.length - 1 ? 8 : 0),
                  child: Card(
                    elevation: 0,
                    color: OrthoqColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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

class _AddStaffHeader extends StatelessWidget {
  const _AddStaffHeader({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: OrthoqColors.navy,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: OrthoqColors.navy.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Text(
                  'Add New Staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
