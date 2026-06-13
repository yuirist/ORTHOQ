import 'dart:async';

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
import '../../utils/validation_utils.dart';
import '../../widgets/doctor_avatar.dart';
import 'staff_calendar_appointment_tile.dart';
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
  final TextEditingController _searchIcController = TextEditingController();
  final FocusNode _searchIcFocusNode = FocusNode();

  StreamSubscription<List<DoctorModel>>? _doctorsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  List<DoctorModel> _allActiveDoctors = [];
  List<String> _assignedDoctorIds = [];
  bool _doctorsLoading = true;
  String? _doctorsError;

  String? _selectedDoctorId;
  DoctorModel? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  String _searchIcQuery = '';

  String get _selectedDateLabel =>
      DateFormat('EEE, MMM d').format(_dateOnly(_selectedDate));

  List<DoctorModel> get _visibleDoctors =>
      _filterDoctors(_allActiveDoctors, _assignedDoctorIds);

  static const Color _datePickerPrimary = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _assignedDoctorIds = widget.userProfile?.assignedDoctorIds ?? const [];
    _listenForDoctorsAndScope();
  }

  void _listenForDoctorsAndScope() {
    _doctorsSubscription = _doctorService.getActiveDoctors().listen(
      (doctors) {
        if (!mounted) return;
        setState(() {
          _allActiveDoctors = doctors;
          _doctorsLoading = false;
          _doctorsError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _doctorsError = error.toString();
          _doctorsLoading = false;
        });
      },
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final profileIds = widget.userProfile?.assignedDoctorIds ?? const [];
      final assigned = profileIds.isNotEmpty
          ? profileIds
          : StaffScope.assignedDoctorIds(snap.data());
      setState(() => _assignedDoctorIds = assigned);
    });
  }

  @override
  void dispose() {
    _doctorsSubscription?.cancel();
    _userSubscription?.cancel();
    _searchIcController.dispose();
    _searchIcFocusNode.dispose();
    super.dispose();
  }

  void _onSearchIcChanged(String value) {
    setState(() {
      _searchIcQuery = ValidationUtils.normalizeICNumber(value);
    });
  }

  void _clearIcSearch() {
    _searchIcController.clear();
    setState(() => _searchIcQuery = '');
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _pickAppointmentDate() async {
    if (_searchIcQuery.isNotEmpty) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateOnly(_selectedDate),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _datePickerPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;
    setState(() => _selectedDate = _dateOnly(pickedDate));
  }

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

  void _showAppointmentDetailSheet(StaffDoctorPatient patient) {
    final doctor = _selectedDoctor;
    if (doctor == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _StaffPatientAppointmentDetailSheet(
        patient: patient,
        doctorId: doctor.id,
        doctorName: doctor.name,
        onReschedule: () {
          Navigator.pop(sheetContext);
          _openQuickBook(patient);
        },
        onHistory: () {
          Navigator.pop(sheetContext);
          _showPatientHistoryDialog(patient);
        },
      ),
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

    final doctors = _visibleDoctors;

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

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _doctorsLoading
                ? const Center(child: CircularProgressIndicator())
                : _doctorsError != null
                    ? Text(
                        'Could not load doctors.\n$_doctorsError',
                        style: const TextStyle(color: Colors.red),
                      )
                    : Row(
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
          if (_assignedDoctorIds.isNotEmpty)
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: IgnorePointer(
              ignoring: _selectedDoctorId == null,
              child: Opacity(
                opacity: _selectedDoctorId == null ? 0.45 : 1,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap:
                        _searchIcQuery.isEmpty ? _pickAppointmentDate : null,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedOpacity(
                      opacity: _searchIcQuery.isEmpty ? 1 : 0.45,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: OrthoqColors.navy,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedDateLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: OrthoqColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: IgnorePointer(
              ignoring: _selectedDoctorId == null,
              child: Opacity(
                opacity: _selectedDoctorId == null ? 0.45 : 1,
                child: ListenableBuilder(
                  listenable: _searchIcController,
                  builder: (context, _) {
                    return TextField(
                      key: const ValueKey('patient_ic_search_field_unique'),
                      controller: _searchIcController,
                      focusNode: _searchIcFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchIcChanged,
                      decoration: InputDecoration(
                        hintText: 'Search patient by IC number...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: OrthoqColors.navy,
                        ),
                        suffixIcon: _searchIcController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearIcSearch,
                                tooltip: 'Clear search',
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: OrthoqColors.navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                : _PatientListSection(
                    patientService: _patientService,
                    doctorId: _selectedDoctorId!,
                    selectedDate: _selectedDate,
                    searchIcQuery: _searchIcQuery,
                    onPatientTap: _showAppointmentDetailSheet,
                    onHistory: _showPatientHistoryDialog,
                    onQuickBook: _openQuickBook,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientListSection extends StatelessWidget {
  const _PatientListSection({
    required this.patientService,
    required this.doctorId,
    required this.selectedDate,
    required this.searchIcQuery,
    required this.onPatientTap,
    required this.onHistory,
    required this.onQuickBook,
  });

  final StaffPatientService patientService;
  final String doctorId;
  final DateTime selectedDate;
  final String searchIcQuery;
  final ValueChanged<StaffDoctorPatient> onPatientTap;
  final Future<void> Function(StaffDoctorPatient) onHistory;
  final void Function(StaffDoctorPatient) onQuickBook;

  Stream<List<StaffDoctorPatient>> _stream() {
    if (searchIcQuery.isNotEmpty) {
      return patientService.watchAppointmentsForDoctorByIc(
        doctorId,
        searchIcQuery,
      );
    }
    return patientService.watchAppointmentsForDoctorOnDate(
      doctorId,
      selectedDate,
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffDoctorPatient>>(
      key: ValueKey(
        '${doctorId}_${_dateOnly(selectedDate).toIso8601String()}',
      ),
      stream: _stream(),
      builder: (context, patientSnap) {
        if (patientSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (patientSnap.hasError) {
          return _EmptyPrompt(
            icon: Icons.error_outline,
            message: 'Could not load patients.\n${patientSnap.error}',
          );
        }

        final patients = patientSnap.data ?? const [];
        if (patients.isEmpty) {
          return _EmptyPrompt(
            icon: Icons.people_outline,
            message: searchIcQuery.isNotEmpty
                ? 'No patients found matching IC $searchIcQuery.'
                : 'No appointments scheduled for '
                    '${DateFormat('EEEE, MMM d').format(selectedDate)}.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: patients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final patient = patients[index];
            return _PatientRowCard(
              patient: patient,
              onTap: () => onPatientTap(patient),
              onHistory: () => onHistory(patient),
              onQuickBook: () => onQuickBook(patient),
            );
          },
        );
      },
    );
  }
}

class _PatientRowCard extends StatelessWidget {
  const _PatientRowCard({
    required this.patient,
    required this.onTap,
    required this.onHistory,
    required this.onQuickBook,
  });

  final StaffDoctorPatient patient;
  final VoidCallback onTap;
  final VoidCallback onHistory;
  final VoidCallback onQuickBook;

  String _patientSubtitle(StaffDoctorPatient patient) {
    final ic = patient.icNumber;
    final time = patient.latestAppointmentTime?.trim();
    if (time != null && time.isNotEmpty) {
      return 'IC: $ic | $time';
    }
    return 'IC: $ic';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 1,
          margin: EdgeInsets.zero,
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
                        _patientSubtitle(patient),
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
        ),
      ),
    );
  }
}

class _StaffPatientAppointmentDetailSheet extends StatelessWidget {
  const _StaffPatientAppointmentDetailSheet({
    required this.patient,
    required this.doctorId,
    required this.doctorName,
    required this.onReschedule,
    required this.onHistory,
  });

  final StaffDoctorPatient patient;
  final String doctorId;
  final String doctorName;
  final VoidCallback onReschedule;
  final VoidCallback onHistory;

  StaffCalendarTileMeta get _tileMeta => StaffCalendarTileMeta(
        appointmentDocId: patient.latestAppointmentId ?? patient.key,
        patientName: patient.fullName,
        time: patient.latestAppointmentTime?.trim().isNotEmpty == true
            ? patient.latestAppointmentTime!.trim()
            : '—',
        patientTypeLabel: patient.patientTypeLabel,
        icNumber: patient.icNumber,
        status: patient.status,
        paymentLabel: patient.paymentLabel,
        appointmentDate: patient.latestAppointmentDate,
        patientEmail: patient.email,
        patientId: patient.patientId,
      );

  Widget _detailRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _tileMeta;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dateText = patient.latestAppointmentDate != null
        ? DateFormat('EEEE, MMMM d, y').format(patient.latestAppointmentDate!)
        : '—';
    final timeText = meta.time;
    final icText = patient.icNumber.trim().isNotEmpty && patient.icNumber != '—'
        ? patient.icNumber
        : null;
    final formattedDoctorName = doctorName.trim().toLowerCase().startsWith('dr.')
        ? doctorName.trim()
        : 'Dr. $doctorName';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
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
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (icText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'ID: $icText',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FutureBuilder<DoctorModel?>(
                                future: DoctorService().getDoctorById(doctorId),
                                builder: (context, snapshot) {
                                  final doctor = snapshot.data;
                                  final specialization =
                                      doctor?.specialization.trim();
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      DoctorAvatar(
                                        imageUrl: doctor?.imageUrl,
                                        radius: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              formattedDoctorName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (specialization != null &&
                                                specialization.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                specialization,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                staffCalendarPaymentBadge(
                                                  meta.paymentLabel,
                                                ),
                                                staffCalendarVisitTypeBadge(meta),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: staffCalendarStatusColor(
                                  context,
                                  meta.status,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                meta.status.toUpperCase(),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _detailRow(
                          icon: Icons.calendar_today,
                          text: dateText,
                        ),
                        const SizedBox(height: 8),
                        _detailRow(
                          icon: Icons.access_time,
                          text: timeText,
                        ),
                        if (icText != null) ...[
                          const SizedBox(height: 8),
                          _detailRow(
                            icon: Icons.badge_outlined,
                            text: icText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onHistory,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: const Text('History'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onReschedule,
                        icon: const Icon(Icons.event_repeat),
                        label: const Text('Reschedule'),
                        style: FilledButton.styleFrom(
                          backgroundColor: OrthoqColors.slateNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
      },
    );
  }
}
