import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../models/doctor_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/doctor_service.dart';
import '../staff/doctor_calendar_view.dart';

/// Full vertical day calendar for the signed-in doctor (matches staff calendar layout).
class DoctorSchedulePage extends StatefulWidget {
  const DoctorSchedulePage({super.key});

  @override
  State<DoctorSchedulePage> createState() => _DoctorSchedulePageState();
}

class _DoctorSchedulePageState extends State<DoctorSchedulePage> {
  Future<DoctorModel?>? _doctorFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _doctorFuture ??= _resolveDoctor();
  }

  Future<DoctorModel?> _resolveDoctor() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final doctorService = DoctorService();
    final profileDoctorId = auth.currentUserData?.doctorId?.trim() ?? '';
    final uid = auth.currentUser?.uid;

    if (profileDoctorId.isNotEmpty) {
      final byId = await doctorService.getDoctorById(profileDoctorId);
      if (byId != null) return byId;
    }
    if (uid != null && uid.isNotEmpty) {
      return doctorService.getDoctorByUserId(uid);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DoctorModel?>(
      future: _doctorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Schedule'),
              backgroundColor: OrthoqColors.slateNavy,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Schedule'),
              backgroundColor: OrthoqColors.slateNavy,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? 'Could not load your doctor profile.\n${snapshot.error}'
                      : 'Doctor profile is not loaded. Please sign in again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final doctor = snapshot.data!;
        return DoctorCalendarView(
          doctorId: doctor.id,
          doctorName: doctor.name,
          initialCalendarView: CalendarView.day,
          showManualBookingFab: false,
        );
      },
    );
  }
}
