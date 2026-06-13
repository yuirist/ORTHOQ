import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/doctor_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/doctor_service.dart';
import '../../services/staff_patient_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../utils/staff_scope.dart';
import 'staff_manual_appointment_sheet.dart';

/// Staff dashboard for browsing patients by doctor and quick actions.
class StaffPatientPage extends StatefulWidget {
  const StaffPatientPage({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<StaffPatientPage> createState() => _StaffPatientPageState();
}

class _StaffPatientPageState extends State<StaffPatientPage> {
  final DoctorService _doctorService = DoctorService();
  final StaffPatientService _patientService = StaffPatientService();

  String? _selectedDoctorId;
  DoctorModel? _selectedDoctor;

  List<DoctorModel> _filterDoctors(
    List<DoctorModel> all,
    List<String> assignedDoctorIds,
  ) {
    if (assignedDoctorIds.isEmpty) return all;
    return all.where((d) => assignedDoctorIds.contains(d.id)).toList();
  }

  void _onDoctorSelected(String? doctorId, List<DoctorModel> doctors) {
    if (doctorId == null) {
      setState(() {
        _selectedDoctorId = null;
        _selectedDoctor = null;
      });
      return;
    }
    DoctorModel? doctor;
    for (final d in doctors) {
      if (d.id == doctorId) {
        doctor = d;
        break;
      }
    }
    setState(() {
      _selectedDoctorId = doctorId;
      _selectedDoctor = doctor;
    });
  }

  Future<void> _showPatientHistoryDialog(StaffDoctorPatient patient) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('History · ${patient.fullName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: patient.patientId != null && patient.patientId!.isNotEmpty
                ? StreamBuilder<List<StaffPatientHistoryEntry>>(
                    stream: _patientService.watchPatientEmailHistory(
                      patient.patientId!,
                    ),
                    builder: (context, emailSnap) {
                      if (emailSnap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (emailSnap.hasError) {
                        return Text(
                          'Could not load email history.\n${emailSnap.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }

                      return StreamBuilder<List<NotificationModel>>(
                        stream: _patientService.watchInAppNotifications(
                          patient.patientId!,
                        ),
                        builder: (context, notifSnap) {
                          if (notifSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (notifSnap.hasError) {
                            return Text(
                              'Could not load notifications.\n${notifSnap.error}',
                              style: const TextStyle(color: Colors.red),
                            );
                          }

                          return _PatientHistoryList(
                            notifications: notifSnap.data ?? const [],
                            emailLogs: emailSnap.data ?? const [],
                          );
                        },
                      );
                    },
                  )
                : FutureBuilder<List<StaffPatientHistoryEntry>>(
                    future: _patientService.fetchEmailLogs(
                      patient.email?.trim() ?? '',
                    ),
                    builder: (context, emailSnap) {
                      if (emailSnap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _PatientHistoryList(
                        notifications: const [],
                        emailLogs: emailSnap.data ?? const [],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openQuickBook(StaffDoctorPatient patient) {
    final doctor = _selectedDoctor;
    if (doctor == null) return;

    showStaffManualAppointmentSheet(
      context: context,
      doctorId: doctor.id,
      doctorName: doctor.name,
      initialPatientName: patient.fullName,
      initialIcNumber: patient.icNumber == '—' ? '' : patient.icNumber,
      initialEmail: patient.email,
      initialPatientId: patient.patientId,
      appointmentId: patient.latestAppointmentId,
      originalAppointmentDate: patient.latestAppointmentDate,
      originalAppointmentTime: patient.latestAppointmentTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in.')),
      );
    }

    final assignedFromProfile = widget.userProfile?.assignedDoctorIds ?? const [];

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final assigned = assignedFromProfile.isNotEmpty
              ? assignedFromProfile
              : StaffScope.assignedDoctorIds(userSnap.data?.data());

          return StreamBuilder<List<DoctorModel>>(
            stream: _doctorService.getActiveDoctors(),
            builder: (context, doctorSnap) {
              if (doctorSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (doctorSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load doctors.\n${doctorSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final doctors = _filterDoctors(
                doctorSnap.data ?? const [],
                assigned,
              );

              if (_selectedDoctorId != null &&
                  !doctors.any((d) => d.id == _selectedDoctorId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _selectedDoctorId = null;
                    _selectedDoctor = null;
                  });
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedDoctorId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Select Doctor',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            hint: const Text('Choose a doctor'),
                            items: doctors
                                .map(
                                  (doctor) => DropdownMenuItem(
                                    value: doctor.id,
                                    child: Text(
                                      'Dr. ${doctor.name} · ${doctor.specialization}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: doctors.isEmpty
                                ? null
                                : (value) =>
                                    _onDoctorSelected(value, doctors),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (assigned.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Showing your assigned doctors only.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _selectedDoctorId == null
                        ? _EmptyPrompt(
                            icon: Icons.medical_services_outlined,
                            message: doctors.isEmpty
                                ? 'No doctors available. Ask an admin to assign doctors to your account.'
                                : 'Select a doctor to view their patients.',
                          )
                        : StreamBuilder<List<StaffDoctorPatient>>(
                            stream: _patientService.watchPatientsForDoctor(
                              _selectedDoctorId!,
                            ),
                            builder: (context, patientSnap) {
                              if (patientSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (patientSnap.hasError) {
                                return _EmptyPrompt(
                                  icon: Icons.error_outline,
                                  message:
                                      'Could not load patients.\n${patientSnap.error}',
                                );
                              }

                              final patients = patientSnap.data ?? const [];
                              if (patients.isEmpty) {
                                return _EmptyPrompt(
                                  icon: Icons.people_outline,
                                  message:
                                      'No patients found for this doctor yet.',
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: patients.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final patient = patients[index];
                                  return _PatientRowCard(
                                    patient: patient,
                                    onHistory: () =>
                                        _showPatientHistoryDialog(patient),
                                    onQuickBook: () => _openQuickBook(patient),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PatientRowCard extends StatelessWidget {
  const _PatientRowCard({
    required this.patient,
    required this.onHistory,
    required this.onQuickBook,
  });

  final StaffDoctorPatient patient;
  final VoidCallback onHistory;
  final VoidCallback onQuickBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _PatientAvatar(
              fullName: patient.fullName,
              profileImageUrl: patient.profileImageUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'IC: ${patient.icNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'History & notifications',
              onPressed: onHistory,
              icon: const Icon(Icons.mark_email_unread_outlined),
              color: OrthoqColors.slateNavy,
            ),
            IconButton(
              tooltip: 'Quick book appointment',
              onPressed: onQuickBook,
              icon: const Icon(Icons.event_available_outlined),
              color: OrthoqColors.slateNavy,
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({
    required this.fullName,
    required this.profileImageUrl,
  });

  final String fullName;
  final String? profileImageUrl;

  static const double _size = 44;

  String get _initial {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
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
                placeholder: (_, __) => Text(
                  _initial,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          : Icon(Icons.person, color: Colors.grey.shade600),
    );
  }
}

class _PatientHistoryList extends StatelessWidget {
  const _PatientHistoryList({
    required this.notifications,
    required this.emailLogs,
  });

  final List<NotificationModel> notifications;
  final List<StaffPatientHistoryEntry> emailLogs;

  @override
  Widget build(BuildContext context) {
    final items = <_HistoryItem>[
      ...notifications.map(
        (n) => _HistoryItem(
          title: n.title,
          body: n.message,
          createdAt: n.createdAt,
          source: 'In-app · ${n.type}',
        ),
      ),
      ...emailLogs.map(
        (e) => _HistoryItem(
          title: e.title,
          body: e.body,
          createdAt: e.createdAt,
          source: e.source,
        ),
      ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (items.isEmpty) {
      return const Text('No notification or email history found for this patient.');
    }

    return SizedBox(
      height: 320,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                item.body,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('MMM d, y · h:mm a').format(item.createdAt)} · ${item.source}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryItem {
  const _HistoryItem({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.source,
  });

  final String title;
  final String body;
  final DateTime createdAt;
  final String source;
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
