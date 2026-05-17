import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DoctorRescheduleRequestsPage extends StatefulWidget {
  const DoctorRescheduleRequestsPage({super.key});

  @override
  State<DoctorRescheduleRequestsPage> createState() =>
      _DoctorRescheduleRequestsPageState();
}

class _DoctorRescheduleRequestsPageState
    extends State<DoctorRescheduleRequestsPage> {
  static const List<String> _doctorValues = [
    'Jamal Bin Kassim',
    'Siti Maimunah Binti Ahmad',
    'Halim Bin Tongkol',
  ];

  String? _selectedDoctor;

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
                  hint: const Text('Select doctor to view requests'),
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
                      'Please select a doctor to view requests.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reschedule_logs')
                        .where('initiatedBy', isEqualTo: 'doctor')
                        .where('doctorName', isEqualTo: _selectedDoctor)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        final errorText = snapshot.error.toString();
                        final linkMatch = RegExp(r'https://console\.firebase\.google\.com\S+')
                            .firstMatch(errorText);
                        final indexLink = linkMatch?.group(0);
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Error loading requests:\n$errorText',
                                  textAlign: TextAlign.center,
                                ),
                                if (indexLink != null) ...[
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    indexLink,
                                    style: const TextStyle(color: Colors.blue),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      final requests = snapshot.data?.docs ?? [];
                      requests.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTs = aData['createdAt'];
                        final bTs = bData['createdAt'];
                        final aDate =
                            aTs is Timestamp ? aTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                        final bDate =
                            bTs is Timestamp ? bTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                        return bDate.compareTo(aDate);
                      });

                      if (requests.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No reschedule requests for selected doctor',
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

                          // Parse dates
                          DateTime? originalDate;
                          DateTime? newDate;
                          String originalTime = data['originalTime']?.toString() ?? 'N/A';
                          String newTime = data['newTime']?.toString() ?? 'N/A';
                          String doctorName =
                              data['doctorName']?.toString() ?? 'Unknown Doctor';
                          String reason =
                              data['reason']?.toString() ?? 'No reason provided';

                          if (data['originalDate'] != null) {
                            if (data['originalDate'] is Timestamp) {
                              originalDate = (data['originalDate'] as Timestamp).toDate();
                            } else if (data['originalDate'] is String) {
                              originalDate = DateTime.parse(data['originalDate']);
                            }
                          }

                          if (data['newDate'] != null) {
                            if (data['newDate'] is Timestamp) {
                              newDate = (data['newDate'] as Timestamp).toDate();
                            } else if (data['newDate'] is String) {
                              newDate = DateTime.parse(data['newDate']);
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: Theme.of(context).colorScheme.secondary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          doctorName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.arrow_back,
                                                size: 16, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Original: ${originalDate != null ? DateFormat('MMM dd, yyyy').format(originalDate) : 'N/A'} at $originalTime',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.arrow_forward,
                                                size: 16, color: Colors.green),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'New: ${newDate != null ? DateFormat('MMM dd, yyyy').format(newDate) : 'N/A'} at $newTime',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (reason.isNotEmpty &&
                                      reason != 'No reason provided') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Reason:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            reason,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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











