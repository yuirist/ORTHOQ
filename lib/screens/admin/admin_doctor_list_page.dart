import 'package:flutter/material.dart';

import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_widgets.dart';
import '../../widgets/doctor_avatar.dart';
import '../../utils/doctor_name_format.dart';
import '../staff/doctor_calendar_view.dart';
import 'add_doctor_screen.dart';
import 'admin_edit_doctor_screen.dart';

class AdminDoctorListPage extends StatelessWidget {
  const AdminDoctorListPage({super.key});

  static const Color _navy = OrthoqColors.slateNavy;

  void _openAddDoctor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDoctorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorService = DoctorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Management'),
        backgroundColor: _navy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<List<DoctorModel>>(
        stream: doctorService.getAllDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Could not load doctors.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final doctors = snapshot.data ?? [];

          return ListView(
            padding: OrthoqSpacing.list,
            children: [
              _AddDoctorHeader(onPressed: () => _openAddDoctor(context)),
              const SizedBox(height: 12),
              if (doctors.isEmpty) ...[
                const SizedBox(height: 48),
                Icon(Icons.medical_services_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No doctors in Firestore yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use Add Doctor above to register a new specialist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ] else
                ...List.generate(doctors.length, (index) {
                  final d = doctors[index];
                  return OrthoqInteractiveCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            DoctorAvatar(
                              imageUrl: d.imageUrl,
                              radius: 26,
                              backgroundColor: Colors.grey.shade200,
                              iconColor: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatDoctorDisplayName(d.name),
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    d.specialization,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (!d.isActive)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 36,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DoctorCalendarView(
                                            doctorId: d.id,
                                            doctorName: stripDoctorPrefix(d.name),
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.calendar_month, size: 18),
                                    label: const Text('Calendar'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _navy,
                                      side: const BorderSide(color: _navy),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 36,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminEditDoctorScreen(doctor: d),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _navy,
                                      side: const BorderSide(color: _navy),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    child: const Text('Edit'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 36,
                                  child: OutlinedButton(
                                    onPressed: () => _confirmDelete(
                                      context,
                                      d,
                                      doctorService,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DoctorModel doctor,
    DoctorService doctorService,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete doctor?'),
        content: Text(
          'Remove "${doctor.name}" from Firestore permanently? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await doctorService.permanentlyDeleteDoctor(doctor.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _AddDoctorHeader extends StatelessWidget {
  const _AddDoctorHeader({required this.onPressed});

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
                  'Add Doctor',
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
