import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'delay_notifications_page.dart';

class DoctorRequestsPage extends StatefulWidget {
  const DoctorRequestsPage({super.key});

  @override
  State<DoctorRequestsPage> createState() => _DoctorRequestsPageState();
}

class _DoctorRequestsPageState extends State<DoctorRequestsPage> {
  static const List<String> _doctorValues = [
    'Jamal Bin Kassim',
    'Siti Maimunah Binti Ahmad',
    'Halim Bin Tongkol',
  ];

  String? _selectedDoctor;

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
          .collection('reschedule_requests')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Reschedule Requests'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: OrthoqColors.slateNavy,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDoctor,
                  isExpanded: true,
                  hint: const Text('Select doctor'),
                  items: _doctorValues
                      .map(
                        (doctor) => DropdownMenuItem<String>(
                          value: doctor,
                          child: Text('Dr. $doctor'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDoctor = value;
                    });
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _selectedDoctor == null
                ? Center(
                    child: Text(
                      'Select a doctor to view active alerts.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reschedule_requests')
                        .where('type', isEqualTo: 'doctor_delay')
                        .where('sender', isEqualTo: _selectedDoctor)
                        .where('status', isEqualTo: 'pending_staff_action')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
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
                              Text(
                                'No active delay alerts for this doctor.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
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
                          final data = request.data() as Map<String, dynamic>;
                          DateTime? delayDate;
                          final rawDate = data['date'];
                          if (rawDate is Timestamp) {
                            delayDate = rawDate.toDate();
                          } else if (rawDate is String) {
                            delayDate = DateTime.tryParse(rawDate);
                          }
                          final sender = data['sender']?.toString() ?? 'Unknown Doctor';
                          final message = data['message']?.toString() ?? '';
                          final status = data['status']?.toString() ?? 'pending_staff_action';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            color: const Color(0xFFE8F0FF),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.notification_important,
                                        color: OrthoqColors.slateNavy,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: const Text(
                                          'Doctor Delay Alert',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Doctor: Dr. $sender',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Date: ${delayDate != null ? DateFormat('EEE, MMM d, y').format(delayDate) : 'N/A'}',
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade100),
                                    ),
                                    child: Text(message.isNotEmpty ? message : 'No message provided'),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.center,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openBroadcastPageFromAlert(context, request.id, data),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: OrthoqColors.slateNavy,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                      icon: const Icon(Icons.campaign),
                                      label: const Text('Broadcast to Patients'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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



