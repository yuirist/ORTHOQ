import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../utils/staff_scope.dart';
import '../../utils/validation_utils.dart';
import '../../widgets/doctor_avatar.dart';
import 'doctor_schedule_preview_card.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key, this.userProfile});

  final UserModel? userProfile;

  static const Color _navy = OrthoqColors.slateNavy;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final DoctorService _doctorService = DoctorService();
  final AppointmentService _appointmentService = AppointmentService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _activeSearchIc;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchIcChanged(String? ic) {
    if (_activeSearchIc == ic) return;
    setState(() => _activeSearchIc = ic);
  }

  void _submitSearch() {
    final normalized = ValidationUtils.normalizeICNumber(_searchController.text);
    if (normalized.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a full 12-digit IC number.'),
          backgroundColor: Colors.orange,
        ),
      );
      _searchFocusNode.requestFocus();
      return;
    }
    _onSearchIcChanged(normalized);
    _searchFocusNode.requestFocus();
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchIcChanged(null);
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        backgroundColor: primary,
        foregroundColor: onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/welcome', (route) => false);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _StaffDashboardBody(
        doctorService: _doctorService,
        appointmentService: _appointmentService,
        userProfile: widget.userProfile,
        searchInput: _StaffIcSearchInput(
          key: const ValueKey('staff_dashboard_ic_search'),
          controller: _searchController,
          focusNode: _searchFocusNode,
          onSearchIcChanged: _onSearchIcChanged,
          onSubmitted: _submitSearch,
          onClear: _clearSearch,
        ),
        activeSearchIc: _activeSearchIc,
      ),
    );
  }
}

class _StaffDashboardBody extends StatelessWidget {
  const _StaffDashboardBody({
    required this.doctorService,
    required this.appointmentService,
    this.userProfile,
    required this.searchInput,
    required this.activeSearchIc,
  });

  final DoctorService doctorService;
  final AppointmentService appointmentService;
  final UserModel? userProfile;
  final Widget searchInput;
  final String? activeSearchIc;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                userProfile != null && userProfile!.fullName.trim().isNotEmpty
                    ? 'Welcome, ${userProfile!.fullName.trim()}'
                    : 'Doctor Schedule Overview',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: StaffDashboardPage._navy,
                ),
              ),
              if (userProfile != null &&
                  userProfile!.fullName.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'Doctor Schedule Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: StaffDashboardPage._navy,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              searchInput,
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final assigned =
                  StaffScope.assignedDoctorIds(userSnap.data?.data());

              return StreamBuilder<List<DoctorModel>>(
                stream: doctorService.getActiveDoctors(),
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

                  final all = doctorSnap.data ?? [];
                  final doctors = assigned.isEmpty
                      ? <DoctorModel>[]
                      : all.where((d) => assigned.contains(d.id)).toList();
                  final previewDoctors = doctors.take(3).toList();
                  final isSearchActive = activeSearchIc != null;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: isSearchActive
                        ? _IcSearchResultsSection(
                            appointmentService: appointmentService,
                            searchIc: activeSearchIc!,
                            assignedDoctorIds: assigned,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                assigned.isEmpty
                                    ? 'An admin must assign exactly 3 doctors to your account before schedules appear here.'
                                    : 'Only your assigned doctors are shown. Tap a card for calendar view.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (doctors.isEmpty)
                                Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      assigned.isEmpty
                                          ? 'No assigned doctors yet. Ask an administrator to use Admin → Assign staff.'
                                          : 'No active doctors match your assignment.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0;
                                        i < previewDoctors.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(height: 18),
                                      DoctorSchedulePreviewCard(
                                        doctor: previewDoctors[i],
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Isolated search field so stream/list rebuilds do not steal TextField focus.
class _StaffIcSearchInput extends StatefulWidget {
  const _StaffIcSearchInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearchIcChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String?> onSearchIcChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  State<_StaffIcSearchInput> createState() => _StaffIcSearchInputState();
}

class _StaffIcSearchInputState extends State<_StaffIcSearchInput> {
  String? _lastNotifiedIc;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _StaffIcSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final normalized =
        ValidationUtils.normalizeICNumber(widget.controller.text);
    final ic = normalized.length == 12 ? normalized : null;

    if (_lastNotifiedIc != ic) {
      _lastNotifiedIc = ic;
      widget.onSearchIcChanged(ic);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => widget.onSubmitted(),
      decoration: InputDecoration(
        hintText: 'Search patient by IC Number...',
        prefixIcon: const Icon(
          Icons.search,
          color: StaffDashboardPage._navy,
        ),
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: widget.onClear,
                tooltip: 'Clear search',
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: StaffDashboardPage._navy,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _IcSearchResultsSection extends StatelessWidget {
  const _IcSearchResultsSection({
    required this.appointmentService,
    required this.searchIc,
    required this.assignedDoctorIds,
  });

  final AppointmentService appointmentService;
  final String searchIc;
  final List<String> assignedDoctorIds;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppointmentModel>>(
      stream: appointmentService.searchAppointmentsByIc(searchIc),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Could not search appointments.\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final allResults = snapshot.data ?? [];
        final results = assignedDoctorIds.isEmpty
            ? allResults
            : allResults
                .where((a) => assignedDoctorIds.contains(a.doctorId))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search results for IC $searchIc',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: StaffDashboardPage._navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${results.length} appointment(s) found',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            if (results.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No appointments found for this IC number.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < results.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    _StaffIcAppointmentCard(appointment: results[i]),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StaffIcAppointmentCard extends StatelessWidget {
  const _StaffIcAppointmentCard({required this.appointment});

  final AppointmentModel appointment;

  bool get _isNewPatientVisit {
    final patientType = appointment.patientType.toLowerCase();
    final appointmentType = appointment.appointmentType.toLowerCase();
    return patientType.contains('new') || appointmentType.contains('new');
  }

  String get _visitTypeLabel {
    if (_isNewPatientVisit) return 'New Patient';
    final patientType = appointment.patientType.toLowerCase();
    final appointmentType = appointment.appointmentType.toLowerCase();
    if (patientType.contains('follow') || appointmentType.contains('follow')) {
      return 'Follow Up';
    }
    final raw = appointment.patientType.trim();
    return raw.isEmpty ? 'Follow Up' : raw;
  }

  String get _paymentBadgeLabel {
    final raw = appointment.paymentType?.trim() ?? '';
    if (raw.isEmpty) return 'Self Pay';
    final lower = raw.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ');
    if (lower.contains('insurance')) return 'Insurance';
    return 'Self Pay';
  }

  Widget _paymentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _paymentBadgeLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _visitTypeBadge() {
    final isNewPatient = _isNewPatientVisit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isNewPatient ? const Color(0xFFF3E5F5) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _visitTypeLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isNewPatient ? Colors.purple.shade900 : Colors.blue.shade900,
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'booked':
      case 'pending':
        return Theme.of(context).colorScheme.secondary;
      case 'confirmed':
        return StaffDashboardPage._navy;
      case 'rescheduled':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName.trim().isNotEmpty
                            ? appointment.patientName
                            : 'Patient',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<DoctorModel?>(
                        future: DoctorService()
                            .getDoctorById(appointment.doctorId),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dr. ${appointment.doctorName}',
                                      style: const TextStyle(
                                        fontSize: 18,
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
                                        _paymentBadge(),
                                        _visitTypeBadge(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(context, appointment.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d, y')
                        .format(appointment.appointmentDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  appointment.appointmentTime.trim().isEmpty
                      ? '—'
                      : appointment.appointmentTime,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            if (appointment.icNumber != null &&
                appointment.icNumber!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    appointment.icNumber!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
