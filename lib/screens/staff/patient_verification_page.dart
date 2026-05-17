import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/email_service.dart';
import '../../utils/staff_scope.dart';
import 'staff_scheduling_page.dart';

class PatientVerificationPage extends StatefulWidget {
  const PatientVerificationPage({super.key});

  @override
  State<PatientVerificationPage> createState() =>
      _PatientVerificationPageState();
}

class _PatientVerificationPageState extends State<PatientVerificationPage> {
  final Set<String> _processingRescheduleRequestIds = <String>{};

  Future<void> _approveAppointment(
    BuildContext context,
    String appointmentId,
    String patientId,
    String patientName,
    String doctorId,
    String doctorName,
  ) async {
    // Navigate to scheduling page instead of directly approving
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffSchedulingPage(
          appointmentId: appointmentId,
          patientId: patientId,
          patientName: patientName,
          doctorId: doctorId,
          doctorName: doctorName,
        ),
      ),
    );

    // If scheduling was successful, show success message
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment scheduled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectAppointment(
    BuildContext context,
    String appointmentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: const Text(
          'Are you sure you want to reject this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
              'status': 'cancelled',
              'updatedAt': DateTime.now().toIso8601String(),
            });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _viewReferral(BuildContext context, String referralUrl) async {
    try {
      final uri = Uri.parse(referralUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open referral link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening referral: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  Future<void> _respondToRescheduleRequest({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> requestData,
    required bool isAccepted,
  }) async {
    if (_processingRescheduleRequestIds.contains(requestId)) {
      return;
    }
    setState(() {
      _processingRescheduleRequestIds.add(requestId);
    });

    final firestore = FirebaseFirestore.instance;
    final requestRef = firestore
        .collection('reschedule_requests')
        .doc(requestId);
    final appointmentId = requestData['appointmentId']?.toString().trim() ?? '';
    if (appointmentId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing appointmentId in reschedule request'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final appointmentRef = firestore
        .collection('appointments')
        .doc(appointmentId);
    final requestedDate = _parseDate(requestData['requestedDate']);
    final requestedTime = requestData['requestedTime']?.toString();
    final oldDate = _parseDate(requestData['oldDate']);
    final oldTime = requestData['oldTime']?.toString() ?? 'N/A';
    final fallbackPatientEmail =
        requestData['patientEmail']?.toString().trim() ?? '';
    final fallbackPatientName =
        requestData['patientName']?.toString() ?? 'Patient';
    final requestDoctorName =
        requestData['doctorName']?.toString().trim() ?? '';

    if (isAccepted && (requestedDate == null || requestedTime == null)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requested date/time is missing for this request'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final requestUpdateData = <String, dynamic>{
      'status': isAccepted ? 'approved' : 'declined',
      'respondedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    final appointmentUpdateData = <String, dynamic>{
      'hasRescheduleRequest': false,
      'rescheduleRequestStatus': isAccepted ? 'Accepted' : 'Declined',
      'rescheduleRespondedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    if (isAccepted) {
      final normalizedDate = DateTime(
        requestedDate!.year,
        requestedDate.month,
        requestedDate.day,
      );
      appointmentUpdateData['appointmentDate'] = Timestamp.fromDate(
        normalizedDate,
      );
      appointmentUpdateData['appointmentTime'] = requestedTime!;
      appointmentUpdateData['status'] = 'confirmed';
    }

    appointmentUpdateData['requestedDate'] = null;
    appointmentUpdateData['requestedTime'] = null;
    appointmentUpdateData['rescheduleReason'] = null;

    try {
      // Step 1: Mark request status in reschedule_requests.
      await requestRef.update(requestUpdateData);

      // Step 2: Update the original appointments document using appointmentId.
      final appointmentSnapshot = await appointmentRef.get();
      if (!appointmentSnapshot.exists) {
        throw 'Appointment not found for ID: $appointmentId';
      }

      final appointmentData =
          appointmentSnapshot.data() as Map<String, dynamic>;
      await appointmentRef.update(appointmentUpdateData);
      debugPrint('Appointment updated successfully!');

      // Doctor name alignment: keep exact DB value, do not overwrite doctorName.
      final patientEmail =
          appointmentData['email']?.toString().trim().isNotEmpty == true
          ? appointmentData['email']?.toString().trim() ?? ''
          : fallbackPatientEmail;
      final patientName =
          appointmentData['patientName']?.toString().isNotEmpty == true
          ? appointmentData['patientName']?.toString() ?? fallbackPatientName
          : fallbackPatientName;
      final appointmentCurrentTime =
          appointmentData['appointmentTime']?.toString() ?? oldTime;
      final appointmentCurrentDate =
          _parseDate(appointmentData['appointmentDate']) ?? oldDate;
      final appointmentDoctorName =
          appointmentData['doctorName']?.toString().trim() ?? '';
      final resolvedDoctorName = requestDoctorName.isNotEmpty
          ? requestDoctorName
          : (appointmentDoctorName.isNotEmpty
                ? appointmentDoctorName
                : 'Unknown Doctor');

      if (patientEmail.isNotEmpty) {
        if (isAccepted) {
          final approvedDateLabel = requestedDate != null
              ? DateFormat('yyyy-MM-dd').format(requestedDate)
              : (appointmentCurrentDate != null
                    ? DateFormat('yyyy-MM-dd').format(appointmentCurrentDate)
                    : 'N/A');
          final approvedTimeLabel =
              requestedTime ??
              (appointmentCurrentTime.isNotEmpty
                  ? appointmentCurrentTime
                  : 'N/A');
          await EmailService().sendRescheduleConfirmationEmail(
            patientEmail,
            patientName,
            true,
            approvedDateLabel,
            approvedTimeLabel,
            resolvedDoctorName,
          );
        } else {
          final declinedDateLabel = appointmentCurrentDate != null
              ? DateFormat('EEEE, MMMM d, y').format(appointmentCurrentDate)
              : 'N/A';
          final declinedTimeLabel = appointmentCurrentTime.isNotEmpty
              ? appointmentCurrentTime
              : 'N/A';
          await EmailService().sendRescheduleResponseEmail(
            patientEmail,
            patientName,
            false,
            declinedDateLabel,
            declinedTimeLabel,
          );
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAccepted
                  ? 'Request Approved! Confirmation email has been sent to the patient.'
                  : 'Request Declined. Notification email has been sent to the patient.',
            ),
            backgroundColor: isAccepted ? Colors.green : Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRescheduleRequestIds.remove(requestId);
        });
      }
    }
  }

  Widget _buildPendingAppointmentsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in.'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final assigned = StaffScope.assignedDoctorIds(userSnap.data?.data());
        return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Handle index not ready error
          if (snapshot.error.toString().contains('failed-precondition')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.build, size: 64, color: Colors.orange.shade700),
                    const SizedBox(height: 16),
                    const Text(
                      'Index Building',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Firestore is building the required index.\nThis may take a few minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading appointments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var appointments = snapshot.data!.docs;

        if (assigned.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No doctors are assigned to your account yet. Ask an admin to assign 3 doctors (Admin → Assign staff).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ),
          );
        }

        appointments = appointments.where((doc) {
          final m = doc.data() as Map<String, dynamic>;
          return StaffScope.appointmentDoctorAllowed(m, assigned);
        }).toList();

        if (appointments.isEmpty) {
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
                  'No pending appointments for your assigned doctors',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointmentDoc = appointments[index];
            final data = appointmentDoc.data() as Map<String, dynamic>;

            final patientName = data['patientName']?.toString() ?? 'Unknown';
            final doctorName =
                data['doctorName']?.toString() ?? 'Unknown Doctor';
            final icNumber = data['icNumber']?.toString() ?? 'N/A';
            final patientTypeRaw = data['patientType']?.toString() ?? '';
            final isNewPatient = patientTypeRaw.toLowerCase().contains('new');
            final patientTypeLabel = isNewPatient ? 'New Patient' : 'Follow-up';
            final referralUrl = data['referralLetterUrl']?.toString();
            final appointmentId = appointmentDoc.id;
            final patientId = data['patientId']?.toString() ?? '';
            final createdAt = _parseDate(data['createdAt']);

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
                        CircleAvatar(
                          backgroundColor: OrthoqColors.slateNavy,
                          child: Text(
                            patientName.isNotEmpty
                                ? patientName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patientName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isNewPatient
                                      ? const Color(0xFFDCEEFF)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  patientTypeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isNewPatient
                                        ? OrthoqColors.slateNavy
                                        : const Color(0xFF166534),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'IC Number: $icNumber',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dr. $doctorName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    if (createdAt != null)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (referralUrl != null && referralUrl.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _viewReferral(context, referralUrl),
                              icon: const Icon(Icons.description, size: 18),
                              label: const Text('View Referral'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                            ),
                          ),
                        if (referralUrl != null && referralUrl.isNotEmpty)
                          const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _rejectAppointment(context, appointmentId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveAppointment(
                              context,
                              appointmentId,
                              patientId,
                              patientName,
                              data['doctorId']?.toString() ?? '',
                              doctorName,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
      },
    );
  }

  Widget _buildRescheduleRequestsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in.'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final assigned = StaffScope.assignedDoctorIds(userSnap.data?.data());
        return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reschedule_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading requests: ${snapshot.error}'),
          );
        }

        var requests = snapshot.data?.docs ?? [];

        if (assigned.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No doctors are assigned to your account yet. Ask an admin to assign 3 doctors (Admin → Assign staff).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ),
          );
        }

        requests = requests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return StaffScope.rescheduleDoctorAllowed(data, assigned);
        }).toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No reschedule requests for your assigned doctors',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final patientName =
                data['patientName']?.toString() ?? 'Unknown Patient';
            final oldDate = _parseDate(data['oldDate']);
            final oldTime = data['oldTime']?.toString() ?? 'N/A';
            final newDate = _parseDate(data['requestedDate']);
            final newTime = data['requestedTime']?.toString() ?? 'N/A';
            final isProcessing = _processingRescheduleRequestIds.contains(
              doc.id,
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                          Text(
                            'Current (Old): ${oldDate != null ? DateFormat('EEE, MMM d, y').format(oldDate) : 'N/A'} at $oldTime',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Requested (New): ${newDate != null ? DateFormat('EEE, MMM d, y').format(newDate) : 'N/A'} at $newTime',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isProcessing
                                ? null
                                : () => _respondToRescheduleRequest(
                                    context: context,
                                    requestId: doc.id,
                                    requestData: data,
                                    isAccepted: true,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                            child: isProcessing
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isProcessing
                                ? null
                                : () => _respondToRescheduleRequest(
                                    context: context,
                                    requestId: doc.id,
                                    requestData: data,
                                    isAccepted: false,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                            child: isProcessing
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Patient Verification'),
          backgroundColor: OrthoqColors.slateNavy,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending Verification'),
              Tab(text: 'Reschedule Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingAppointmentsTab(),
            _buildRescheduleRequestsTab(),
          ],
        ),
      ),
    );
  }
}
