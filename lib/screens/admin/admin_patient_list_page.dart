import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_widgets.dart';

class AdminPatientListPage extends StatelessWidget {
  const AdminPatientListPage({super.key});

  static const Color _navy = OrthoqColors.navy;

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Scaffold(
      backgroundColor: OrthoqColors.adminPageBg,
      appBar: AppBar(
        title: const Text('Patient List'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: adminService.watchPatientMembers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load patients: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }

          final patients = snapshot.data!;
          if (patients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No registered patients yet',
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
              ...List.generate(patients.length, (index) {
                final patient = patients[index];
                final initials = patient.fullName.isNotEmpty
                    ? patient.fullName[0].toUpperCase()
                    : '?';
                final icLabel = patient.icNumber?.trim().isNotEmpty == true
                    ? patient.icNumber!.trim()
                    : 'No IC';

                return OrthoqInteractiveCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        initials,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    title: Text(
                      patient.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${patient.email}\n'
                      '${patient.phoneNumber.isNotEmpty ? patient.phoneNumber : 'No phone'}'
                      ' · IC: $icLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    isThreeLine: true,
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
