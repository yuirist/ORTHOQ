import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:orthoq_app/theme/orthoq_theme.dart';
import 'package:orthoq_app/theme/orthoq_widgets.dart';
import 'package:provider/provider.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/doctor_delay_notification_service.dart';
import '../../services/doctor_service.dart';
import '../../utils/staff_scope.dart';
import 'delay_notifications_page.dart';

class DoctorRequestsPage extends StatefulWidget {
  const DoctorRequestsPage({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<DoctorRequestsPage> createState() => _DoctorRequestsPageState();
}

class _DoctorRequestsPageState extends State<DoctorRequestsPage> {
  static const String _allDoctorsKey = '__all_doctors__';

  final DoctorService _doctorService = DoctorService();
  String? _selectedDoctorId;
  List<String> _assignedDoctorIds = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _assignedDoctorIds = widget.userProfile?.assignedDoctorIds ?? const [];
    _listenForAssignmentUpdates();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenForAssignmentUpdates() {
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

  List<String> _resolveAssignedDoctorIds(BuildContext context) {
    if (_assignedDoctorIds.isNotEmpty) return _assignedDoctorIds;
    final authProfile = context.read<AuthProvider>().currentUserData;
    return authProfile?.assignedDoctorIds ?? const [];
  }

  List<DoctorModel> _filterDoctors(
    List<DoctorModel> all,
    List<String> assignedDoctorIds,
  ) {
    if (assignedDoctorIds.isEmpty) return all;
    return all
        .where(
          (doctor) =>
              assignedDoctorIds.contains(doctor.id) ||
              (doctor.userId.isNotEmpty &&
                  assignedDoctorIds.contains(doctor.userId)),
        )
        .toList();
  }

  String? _effectiveDoctorId(
    List<DoctorModel> visibleDoctors,
    List<String> assignedDoctorIds,
  ) {
    if (_selectedDoctorId != null && _selectedDoctorId!.isNotEmpty) {
      return _selectedDoctorId;
    }
    if (assignedDoctorIds.isNotEmpty && visibleDoctors.isNotEmpty) {
      return _doctorFilterId(visibleDoctors.first);
    }
    return null;
  }

  void _ensureDefaultDoctorSelection(
    List<DoctorModel> visibleDoctors,
    List<String> assignedDoctorIds,
  ) {
    if (assignedDoctorIds.isEmpty || visibleDoctors.isEmpty) return;

    final targetId = _effectiveDoctorId(visibleDoctors, assignedDoctorIds);
    if (targetId == null || _selectedDoctorId == targetId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedDoctorId = targetId);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _delayAlertsStream({
    String? doctorId,
    List<String> assignedDoctorIds = const [],
  }) {
    if (doctorId != null && doctorId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection(DoctorDelayNotificationService.collection)
          .where('status', isEqualTo: DoctorDelayNotificationService.pendingStatus)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    if (assignedDoctorIds.isNotEmpty) {
      final ids = assignedDoctorIds.take(10).toList();
      return FirebaseFirestore.instance
          .collection(DoctorDelayNotificationService.collection)
          .where('status', isEqualTo: DoctorDelayNotificationService.pendingStatus)
          .where('doctorId', whereIn: ids)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    return DoctorDelayNotificationService.getPendingDoctorDelaysStream();
  }

  String _doctorFilterId(DoctorModel doctor) {
    if (doctor.userId.trim().isNotEmpty) return doctor.userId.trim();
    return doctor.id;
  }

  DoctorModel? _findDoctorForAlert(
    List<DoctorModel> doctors,
    Map<String, dynamic> data,
  ) {
    final delayDoctorId = data['doctorId']?.toString().trim() ?? '';
    if (delayDoctorId.isNotEmpty) {
      for (final doctor in doctors) {
        if (doctor.id == delayDoctorId || doctor.userId == delayDoctorId) {
          return doctor;
        }
      }
    }
    final name = (data['doctorName'] ?? data['sender'])?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final normalized = name.toLowerCase();
    for (final doctor in doctors) {
      if (doctor.name.trim().toLowerCase() == normalized) return doctor;
    }
    return null;
  }

  String _displayDoctorName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Unknown Doctor';
    return trimmed.toLowerCase().startsWith('dr') ? trimmed : 'Dr. $trimmed';
  }

  Future<void> _openBroadcastPageFromAlert(
    BuildContext context,
    String requestId,
    Map<String, dynamic> requestData,
    List<DoctorModel> doctors,
  ) async {
    final matchedDoctor = _findDoctorForAlert(doctors, requestData);
    final doctorName = matchedDoctor?.name ??
        requestData['sender']?.toString().trim() ??
        requestData['doctorName']?.toString().trim() ??
        '';
    final doctorId = matchedDoctor?.id ??
        requestData['doctorId']?.toString().trim();
    final message = requestData['message']?.toString().trim() ?? '';
    final dateValue = requestData['date'];

    DateTime? selectedDate;
    if (dateValue is Timestamp) {
      selectedDate = dateValue.toDate();
    } else if (dateValue is String) {
      selectedDate = DateTime.tryParse(dateValue);
    }

    if (doctorName.isEmpty || message.isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid delay request data.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DelayNotificationsPage(
          initialDoctor: _displayDoctorName(doctorName),
          initialDoctorId: doctorId,
          initialDate: selectedDate,
          initialMessage: message,
          delayRequestId: requestId,
          popOnSuccess: true,
        ),
      ),
    );
  }

  Widget _buildDoctorAvatar(DoctorModel? doctor) {
    const size = 56.0;
    final imageUrl = doctor?.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: OrthoqColors.navy,
            alignment: Alignment.center,
            child: const Icon(
              Icons.medical_services,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      );
    }
    return const CircleAvatar(
      radius: 28,
      backgroundColor: OrthoqColors.navy,
      child: Icon(Icons.medical_services, color: Colors.white, size: 28),
    );
  }

  Widget _buildDelayAlertCard(
    BuildContext context, {
    required String requestId,
    required Map<String, dynamic> data,
    required List<DoctorModel> doctors,
  }) {
    DateTime? delayDate;
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      delayDate = rawDate.toDate();
    } else if (rawDate is String) {
      delayDate = DateTime.tryParse(rawDate);
    }
    final matchedDoctor = _findDoctorForAlert(doctors, data);
    final sender = matchedDoctor?.name ??
        data['sender']?.toString() ??
        data['doctorName']?.toString() ??
        'Unknown Doctor';
    final displayName = _displayDoctorName(sender);
    final message = data['message']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending_staff_action';
    final dateLabel = delayDate != null
        ? DateFormat('EEE, MMM d, y').format(delayDate)
        : 'N/A';

    return OrthoqInteractiveCard(
      margin: const EdgeInsets.only(bottom: OrthoqSpacing.md),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDoctorAvatar(matchedDoctor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor Delay Alert',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: OrthoqColors.navy,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule,
                  size: 20,
                  color: OrthoqColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Affected Date: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: dateLabel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: OrthoqColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: OrthoqColors.lightSlate),
                    ),
                    child: Text(
                      message.isNotEmpty ? message : 'No message provided',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openBroadcastPageFromAlert(
                  context,
                  requestId,
                  data,
                  doctors,
                ),
                style: OrthoqTheme.primaryButton,
                icon: const Icon(Icons.campaign),
                label: const Text('Broadcast to Patients'),
              ),
            ),
          ],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Reschedule Requests'),
        backgroundColor: OrthoqColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: OrthoqColors.navy,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StreamBuilder<List<DoctorModel>>(
              stream: _doctorService.getActiveDoctors(),
              builder: (context, doctorsSnap) {
                final assignedDoctorIds = _resolveAssignedDoctorIds(context);
                final allDoctors = doctorsSnap.data ?? [];
                final doctors = _filterDoctors(allDoctors, assignedDoctorIds);
                final hasAssignedDoctors = assignedDoctorIds.isNotEmpty;
                _ensureDefaultDoctorSelection(doctors, assignedDoctorIds);

                final dropdownValue = hasAssignedDoctors
                    ? _effectiveDoctorId(doctors, assignedDoctorIds)
                    : (_selectedDoctorId ?? _allDoctorsKey);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: doctors.isEmpty ? null : dropdownValue,
                      isExpanded: true,
                      hint: Text(
                        doctors.isEmpty
                            ? 'No assigned doctors'
                            : 'Select doctor',
                      ),
                      items: [
                        if (!hasAssignedDoctors)
                          const DropdownMenuItem<String>(
                            value: _allDoctorsKey,
                            child: Text(
                              'All doctors',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ...doctors.map(
                          (doctor) => DropdownMenuItem<String>(
                            value: _doctorFilterId(doctor),
                            child: Text(
                              'Dr. ${doctor.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: doctorsSnap.connectionState ==
                              ConnectionState.waiting
                          ? null
                          : doctors.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    if (hasAssignedDoctors) {
                                      _selectedDoctorId = value;
                                    } else {
                                      _selectedDoctorId =
                                          value == null || value == _allDoctorsKey
                                              ? null
                                              : value;
                                    }
                                  });
                                },
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DoctorModel>>(
              stream: _doctorService.getActiveDoctors(),
              builder: (context, doctorsSnap) {
                final assignedDoctorIds = _resolveAssignedDoctorIds(context);
                final doctors = _filterDoctors(
                  doctorsSnap.data ?? const <DoctorModel>[],
                  assignedDoctorIds,
                );
                final hasAssignedDoctors = assignedDoctorIds.isNotEmpty;
                final activeDoctorId =
                    _effectiveDoctorId(doctors, assignedDoctorIds);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _delayAlertsStream(
                    doctorId: activeDoctorId,
                    assignedDoctorIds:
                        hasAssignedDoctors ? assignedDoctorIds : const [],
                  ),
                  builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: OrthoqColors.navy),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading delay alerts:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final requests = snapshot.data?.docs ?? [];
                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            hasAssignedDoctors
                                ? 'No active delay alerts for your assigned doctors.'
                                : activeDoctorId == null
                                    ? 'No active delay alerts from any doctor.'
                                    : 'No active delay alerts for this doctor.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildDelayAlertCard(
                      context,
                      requestId: request.id,
                      data: request.data(),
                      doctors: doctors,
                    );
                  },
                );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
