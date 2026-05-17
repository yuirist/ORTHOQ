import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';
import 'delay_notifications_page.dart';

class DoctorRequestsPage extends StatefulWidget {
  const DoctorRequestsPage({super.key});

  @override
  State<DoctorRequestsPage> createState() => _DoctorRequestsPageState();
}

class _DoctorRequestsPageState extends State<DoctorRequestsPage> {
  static const String _allDoctorsKey = '__all_doctors__';

  final DoctorService _doctorService = DoctorService();
  String? _selectedDoctorId;

  String _doctorFilterId(DoctorModel doctor) {
    if (doctor.userId.trim().isNotEmpty) return doctor.userId.trim();
    return doctor.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _delayAlertsStream() {
    var query = FirebaseFirestore.instance
        .collection('doctor_delays')
        .where('status', isEqualTo: 'pending_staff_action');

    final doctorId = _selectedDoctorId;
    if (doctorId != null && doctorId.isNotEmpty) {
      query = query.where('doctorId', isEqualTo: doctorId);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _openBroadcastPageFromAlert(
    BuildContext context,
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    final doctorName =
        requestData['sender']?.toString().trim().isNotEmpty == true
            ? requestData['sender'].toString().trim()
            : requestData['doctorName']?.toString().trim() ?? '';
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

    try {
      await FirebaseFirestore.instance
          .collection('doctor_delays')
          .doc(requestId)
          .set({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DelayNotificationsPage(
            initialDoctor: doctorName,
            initialDate: selectedDate,
            initialMessage: message,
            popOnSuccess: true,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDelayAlertCard(
    BuildContext context, {
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    DateTime? delayDate;
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      delayDate = rawDate.toDate();
    } else if (rawDate is String) {
      delayDate = DateTime.tryParse(rawDate);
    }
    final sender = data['sender']?.toString() ??
        data['doctorName']?.toString() ??
        'Unknown Doctor';
    final message = data['message']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending_staff_action';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: const Color(0xFFE8F0FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notification_important,
                  color: OrthoqColors.navy,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Doctor Delay Alert',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: OrthoqColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Doctor:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OrthoqColors.navy,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Dr. $sender',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OrthoqColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Date: ${delayDate != null ? DateFormat('EEE, MMM d, y').format(delayDate) : 'N/A'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: OrthoqColors.lightSlate),
              ),
              child: Text(
                message.isNotEmpty ? message : 'No message provided',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _openBroadcastPageFromAlert(context, requestId, data),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrthoqColors.navy,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.campaign),
                label: const Text('Broadcast to Patients'),
              ),
            ),
          ],
        ),
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
                final doctors = doctorsSnap.data ?? [];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDoctorId ?? _allDoctorsKey,
                      isExpanded: true,
                      items: [
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
                          : (value) {
                              setState(() {
                                _selectedDoctorId =
                                    value == null || value == _allDoctorsKey
                                        ? null
                                        : value;
                              });
                            },
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _delayAlertsStream(),
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
                            _selectedDoctorId == null
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
