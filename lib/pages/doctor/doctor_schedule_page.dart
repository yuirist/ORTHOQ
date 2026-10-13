import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/doctor_service.dart';
import '../../utils/doctor_name_format.dart';
import 'doctor_appointment_schedule_view.dart';

class _ResolvedDoctorSchedule {
  const _ResolvedDoctorSchedule({
    required this.doctorId,
    required this.doctorName,
  });

  final String doctorId;
  final String doctorName;
}

/// Doctor daily schedule with week strip, summary card, and timeline feed.
class DoctorSchedulePage extends StatefulWidget {
  const DoctorSchedulePage({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<DoctorSchedulePage> createState() => _DoctorSchedulePageState();
}

class _DoctorSchedulePageState extends State<DoctorSchedulePage> {
  final DoctorService _doctorService = DoctorService();

  Scaffold _shell(BuildContext context, {required Widget body}) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: body,
    );
  }

  Future<_ResolvedDoctorSchedule?> _resolveDoctorSchedule(
    AuthProvider auth,
  ) async {
    final profile = auth.currentUserData ?? widget.userProfile;
    final uid = auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) return null;

    final profileDoctorId = profile?.doctorId?.trim() ?? '';

    if (profileDoctorId.isNotEmpty) {
      final byProfileId = await _doctorService.getDoctorById(profileDoctorId);
      if (byProfileId != null) {
        return _ResolvedDoctorSchedule(
          doctorId: byProfileId.id,
          doctorName: byProfileId.name,
        );
      }
    }

    final byUserId = await _doctorService.getDoctorByUserId(uid);
    if (byUserId != null) {
      return _ResolvedDoctorSchedule(
        doctorId: byUserId.id,
        doctorName: byUserId.name,
      );
    }

    final byUidDoc = await _doctorService.getDoctorById(uid);
    if (byUidDoc != null) {
      return _ResolvedDoctorSchedule(
        doctorId: byUidDoc.id,
        doctorName: byUidDoc.name,
      );
    }

    if (profile != null) {
      final rawName = profile.fullName.trim();
      final doctorName = rawName.isNotEmpty ? rawName : 'Doctor';
      return _ResolvedDoctorSchedule(
        doctorId: profileDoctorId.isNotEmpty ? profileDoctorId : uid,
        doctorName: doctorName,
      );
    }

    final displayName = auth.currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return _ResolvedDoctorSchedule(
        doctorId: uid,
        doctorName: displayName,
      );
    }

    return _ResolvedDoctorSchedule(doctorId: uid, doctorName: 'Doctor');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final profile = auth.currentUserData ?? widget.userProfile;
        final uid = auth.currentUser?.uid;

        if (auth.isProfileLoading && profile == null) {
          return _shell(
            context,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (uid == null || uid.isEmpty) {
          return _shell(
            context,
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Please sign in again to view your schedule.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return FutureBuilder<_ResolvedDoctorSchedule?>(
          key: ValueKey('doctor-schedule-$uid-${profile?.id ?? ''}'),
          future: _resolveDoctorSchedule(auth),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _shell(
                context,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _shell(
                context,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load your doctor profile.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final resolved = snapshot.data;
            if (resolved == null || resolved.doctorId.isEmpty) {
              return _shell(
                context,
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Doctor profile is not loaded. Please sign in again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return _shell(
              context,
              body: DoctorAppointmentScheduleView(
                doctorId: resolved.doctorId,
                doctorName: stripDoctorPrefix(resolved.doctorName),
              ),
            );
          },
        );
      },
    );
  }
}
