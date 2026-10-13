import 'package:cached_network_image/cached_network_image.dart';
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
                    leading: _PatientListAvatar(
                      fullName: patient.fullName,
                      profileImageUrl: patient.profileImageUrl,
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

/// List tile avatar — network photo when available, otherwise name initial.
class _PatientListAvatar extends StatelessWidget {
  const _PatientListAvatar({
    required this.fullName,
    required this.profileImageUrl,
  });

  final String fullName;
  final String? profileImageUrl;

  static const double _size = 40;

  String get _initial {
    if (fullName.trim().isEmpty) return '?';
    return fullName.trim()[0].toUpperCase();
  }

  TextStyle _initialStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.bold,
        );
  }

  @override
  Widget build(BuildContext context) {
    final url = profileImageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return CircleAvatar(
      radius: _size / 2,
      backgroundColor: Colors.grey.shade200,
      child: hasImage
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _InitialFallback(
                  initial: _initial,
                  style: _initialStyle(context),
                ),
                errorWidget: (_, __, ___) => _InitialFallback(
                  initial: _initial,
                  style: _initialStyle(context),
                ),
              ),
            )
          : _InitialFallback(
              initial: _initial,
              style: _initialStyle(context),
            ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  const _InitialFallback({
    required this.initial,
    required this.style,
  });

  final String initial;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PatientListAvatar._size,
      height: _PatientListAvatar._size,
      child: Center(child: Text(initial, style: style)),
    );
  }
}
