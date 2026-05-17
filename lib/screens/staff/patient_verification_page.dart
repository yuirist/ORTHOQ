import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/email_service.dart';
import '../../utils/referral_url_utils.dart';
import '../../utils/staff_scope.dart';
import 'staff_scheduling_page.dart';

class PatientVerificationPage extends StatefulWidget {
  const PatientVerificationPage({
    super.key,
    this.onRejectionComplete,
  });

  /// Called after a successful rejection so the parent can navigate away and
  /// show feedback on a stable Scaffold (avoids TabBarView GlobalKey crashes).
  final void Function(String patientEmail)? onRejectionComplete;

  @override
  State<PatientVerificationPage> createState() =>
      _PatientVerificationPageState();
}

class _PatientVerificationPageState extends State<PatientVerificationPage> {
  final Set<String> _processingRescheduleRequestIds = <String>{};
  bool _loadingDialogOpen = false;

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

  Future<String?> _resolvePatientEmail({
    required Map<String, dynamic> appointmentData,
    required String patientId,
  }) async {
    final fromAppointment = appointmentData['email']?.toString().trim();
    if (fromAppointment != null && fromAppointment.isNotEmpty) {
      return fromAppointment;
    }

    if (patientId.isEmpty) return null;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();
      final fromUser = userDoc.data()?['email']?.toString().trim();
      if (fromUser != null && fromUser.isNotEmpty) {
        return fromUser;
      }
    } catch (e) {
      debugPrint('Could not load patient email from users/$patientId: $e');
    }
    return null;
  }

  void _showBlockingLoading() {
    if (!mounted || _loadingDialogOpen) return;
    _loadingDialogOpen = true;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: OrthoqColors.navy),
        ),
      ),
    );
  }

  void _dismissBlockingLoading() {
    if (!mounted || !_loadingDialogOpen) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
    _loadingDialogOpen = false;
  }

  void _showSnackBarOnPage(String message, {required bool isError}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: isError ? Colors.red : OrthoqColors.navy,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isError ? 5 : 4),
        ),
      );
    });
  }

  /// Returns rejection reason, or `null` if cancelled.
  Future<String?> _promptRejectionReason() async {
    final reasonController = TextEditingController();
    String? reason;

    try {
      final result = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Reject Appointment',
              style: TextStyle(color: OrthoqColors.navy),
            ),
            content: SingleChildScrollView(
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason for Rejection',
                  hintText: 'Enter the reason sent to the patient…',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: OrthoqColors.navy,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: OrthoqColors.navy,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final value = reasonController.text.trim();
                  if (value.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a reason for rejection'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.of(dialogContext, rootNavigator: true)
                      .pop(value);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrthoqColors.navy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Rejection'),
              ),
            ],
          );
        },
      );
      reason = result?.trim();
    } finally {
      reasonController.dispose();
    }

    if (reason != null && reason.isEmpty) return null;
    return reason;
  }

  Future<void> _rejectAppointment({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required Map<String, dynamic> appointmentData,
  }) async {
    if (!mounted) return;

    // Step 1: Rejection reason dialog (closes when user taps Send Rejection)
    final reason = await _promptRejectionReason();
    if (reason == null || reason.isEmpty) return;
    if (!mounted) return;

    // a) Loading indicator (root overlay — dismissed explicitly once)
    _showBlockingLoading();

    String? patientEmail;
    try {
      patientEmail = await _resolvePatientEmail(
        appointmentData: appointmentData,
        patientId: patientId,
      );

      if (patientEmail == null || patientEmail.isEmpty) {
        throw 'No email address found for this patient. Cannot send rejection notice.';
      }

      final appointmentDateLabel =
          _formatAppointmentDateLabel(appointmentData);
      final appointmentTimeLabel =
          _formatAppointmentTimeLabel(appointmentData);
      final doctorLabel = _formatDoctorLabel(
        appointmentData['doctorName']?.toString() ?? '',
      );

      // b) Send email
      final emailSent = await EmailService().sendAppointmentRejectionEmail(
        patientEmail: patientEmail,
        patientName: patientName,
        rejectionReason: reason,
        appointmentDate: appointmentDateLabel,
        appointmentTime: appointmentTimeLabel,
        doctorName: doctorLabel,
      );

      if (!emailSent) {
        throw 'Rejection email could not be sent. Check EmailService configuration.';
      }

      // c) Update Firestore
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'rejected',
            'rejectionReason': reason,
            'rejectedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'referralVerified': false,
          });

      if (!mounted) return;

      // d) Dismiss root loading dialog (single pop)
      _dismissBlockingLoading();

      if (!mounted) return;

      final emailForMessage = patientEmail;

      // e) Return to verification list via parent (IndexedStack tab)
      if (widget.onRejectionComplete != null) {
        widget.onRejectionComplete!(emailForMessage);
      } else {
        // f) SnackBar after navigation frame settles
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showSnackBarOnPage(
              'Successfully sent rejection email to $emailForMessage.',
              isError: false,
            );
          });
        });
      }
    } catch (e) {
      _dismissBlockingLoading();
      if (!mounted) return;
      _showSnackBarOnPage(
        'Could not reject appointment: $e',
        isError: true,
      );
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

  String _formatDoctorLabel(String doctorName) {
    final trimmed = doctorName.trim();
    if (trimmed.isEmpty) return 'Unknown Doctor';
    if (trimmed.toLowerCase().startsWith('dr')) return trimmed;
    return 'Dr. $trimmed';
  }

  String _formatAppointmentDateLabel(Map<String, dynamic> data) {
    final date = _parseDate(data['appointmentDate']);
    if (date == null) return 'Not yet scheduled';
    return DateFormat('EEEE, d MMMM y').format(date);
  }

  String _formatAppointmentTimeLabel(Map<String, dynamic> data) {
    final time = data['appointmentTime']?.toString().trim();
    if (time == null || time.isEmpty) return 'Not yet scheduled';
    return time;
  }

  static const TextStyle _fieldLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.75,
    color: Color(0xFF64748B),
  );

  static const TextStyle _fieldValueStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: OrthoqColors.navy,
    height: 1.35,
  );

  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: OrthoqColors.navy),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: _fieldLabelStyle),
              const SizedBox(height: 4),
              Text(
                value,
                style: _fieldValueStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const TextStyle _sectionHeaderStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: OrthoqColors.navy,
    letterSpacing: 0.2,
  );

  Widget _buildScheduleComparisonBox({
    required String label,
    required String dateText,
    required String timeText,
    required bool isRequested,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRequested ? Colors.white : OrthoqColors.scaffoldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRequested ? OrthoqColors.navy : OrthoqColors.lightSlate,
            width: isRequested ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: _fieldLabelStyle),
            const SizedBox(height: 8),
            Text(
              dateText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _fieldValueStyle,
            ),
            const SizedBox(height: 4),
            Text(
              timeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isRequested ? OrthoqColors.navy : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescheduleRequestCard({
    required BuildContext context,
    required String patientName,
    required String patientTypeLabel,
    required bool isNewPatient,
    required String icNumber,
    required String emailDisplay,
    required String doctorLabel,
    required DateTime? oldDate,
    required String oldTime,
    required DateTime? newDate,
    required String newTime,
    required bool isProcessing,
    required VoidCallback onApprove,
    required VoidCallback onDecline,
  }) {
    final oldDateLabel = oldDate != null
        ? DateFormat('EEE, MMM d, y').format(oldDate)
        : 'N/A';
    final newDateLabel = newDate != null
        ? DateFormat('EEE, MMM d, y').format(newDate)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              patientName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: OrthoqColors.navy,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusChip(
                  label: patientTypeLabel,
                  background: isNewPatient
                      ? const Color(0xFFDCEEFF)
                      : const Color(0xFFDCFCE7),
                  foreground: isNewPatient
                      ? OrthoqColors.navy
                      : const Color(0xFF166534),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEEFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: OrthoqColors.navy,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        icNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OrthoqColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoField(
              icon: Icons.email_outlined,
              label: 'Email',
              value: emailDisplay,
            ),
            const SizedBox(height: 16),
            const Text('Doctor & Appointment', style: _sectionHeaderStyle),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.local_hospital_outlined,
                  size: 18,
                  color: OrthoqColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ASSIGNED DOCTOR', style: _fieldLabelStyle),
                      const SizedBox(height: 4),
                      Text(
                        doctorLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _fieldValueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Schedule change', style: _sectionHeaderStyle),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildScheduleComparisonBox(
                    label: 'Current (Old)',
                    dateText: oldDateLabel,
                    timeText: oldTime,
                    isRequested: false,
                  ),
                  const SizedBox(width: 10),
                  _buildScheduleComparisonBox(
                    label: 'Requested (New)',
                    dateText: newDateLabel,
                    timeText: newTime,
                    isRequested: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onDecline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
  }

  Widget _buildStatusChip({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildVerificationCard(
    BuildContext context, {
    required String patientName,
    required String icNumber,
    required String emailDisplay,
    required bool isNewPatient,
    required String patientTypeLabel,
    required String doctorLabel,
    required String appointmentDateLabel,
    required String appointmentTimeLabel,
    required bool hasScheduledSlot,
    required DateTime? createdAt,
    required String? referralUrl,
    required VoidCallback onReject,
    required VoidCallback onApprove,
    required VoidCallback? onViewReferral,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                _buildStatusChip(
                  label: patientTypeLabel,
                  background: isNewPatient
                      ? const Color(0xFFDCEEFF)
                      : const Color(0xFFDCFCE7),
                  foreground: isNewPatient
                      ? OrthoqColors.navy
                      : const Color(0xFF166534),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(
                  label: 'Pending',
                  background: Colors.orange.shade100,
                  foreground: Colors.orange.shade900,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: OrthoqColors.navy,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoField(
                        icon: Icons.badge_outlined,
                        label: 'IC Number',
                        value: icNumber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoField(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: emailDisplay,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.local_hospital_outlined,
                            size: 18,
                            color: OrthoqColors.navy,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DOCTOR', style: _fieldLabelStyle),
                                const SizedBox(height: 4),
                                Text(
                                  doctorLabel,
                                  style: _fieldValueStyle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OrthoqColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OrthoqColors.lightSlate),
              ),
              child: hasScheduledSlot
                  ? Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: OrthoqColors.navy,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REQUESTED',
                                style: _fieldLabelStyle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$appointmentDateLabel · $appointmentTimeLabel',
                                style: _fieldValueStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _buildStatusChip(
                        label: 'Not yet scheduled',
                        background: const Color(0xFFDCEEFF),
                        foreground: OrthoqColors.navy,
                      ),
                    ),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted ${DateFormat('MMM dd, yyyy · HH:mm').format(createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                if (onViewReferral != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewReferral,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('View Referral'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OrthoqColors.navy,
                        side: const BorderSide(color: OrthoqColors.navy),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
            final patientEmail = data['email']?.toString().trim();
            final emailDisplay = (patientEmail != null && patientEmail.isNotEmpty)
                ? patientEmail
                : 'Not provided';
            final patientTypeRaw = data['patientType']?.toString() ?? '';
            final isNewPatient = patientTypeRaw.toLowerCase().contains('new');
            final patientTypeLabel = isNewPatient ? 'New Patient' : 'Follow-up';
            final referralUrl = data['referralLetterUrl']?.toString();
            final appointmentId = appointmentDoc.id;
            final patientId = data['patientId']?.toString() ?? '';
            final createdAt = _parseDate(data['createdAt']);
            final doctorLabel = _formatDoctorLabel(doctorName);
            final appointmentDateLabel = _formatAppointmentDateLabel(data);
            final appointmentTimeLabel = _formatAppointmentTimeLabel(data);
            final hasScheduledSlot = appointmentDateLabel != 'Not yet scheduled' ||
                appointmentTimeLabel != 'Not yet scheduled';

            return KeyedSubtree(
              key: ValueKey<String>('verification_$appointmentId'),
              child: _buildVerificationCard(
              context,
              patientName: patientName,
              icNumber: icNumber,
              emailDisplay: emailDisplay,
              isNewPatient: isNewPatient,
              patientTypeLabel: patientTypeLabel,
              doctorLabel: doctorLabel,
              appointmentDateLabel: appointmentDateLabel,
              appointmentTimeLabel: appointmentTimeLabel,
              hasScheduledSlot: hasScheduledSlot,
              createdAt: createdAt,
              referralUrl: referralUrl,
              onReject: () => _rejectAppointment(
                appointmentId: appointmentId,
                patientId: patientId,
                patientName: patientName,
                appointmentData: data,
              ),
              onApprove: () => _approveAppointment(
                context,
                appointmentId,
                patientId,
                patientName,
                data['doctorId']?.toString() ?? '',
                doctorName,
              ),
              onViewReferral: referralUrl != null && referralUrl.isNotEmpty
                  ? () => openReferralLetterUrl(context, referralUrl)
                  : null,
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
            final appointmentId = data['appointmentId']?.toString().trim() ?? '';
            final isProcessing = _processingRescheduleRequestIds.contains(
              doc.id,
            );

            Widget buildCard(Map<String, dynamic>? aptData) {
              return _buildRescheduleRequestCard(
                context: context,
                patientName: data['patientName']?.toString() ??
                    aptData?['patientName']?.toString() ??
                    'Unknown Patient',
                patientTypeLabel: () {
                  final raw = data['patientType']?.toString() ??
                      aptData?['patientType']?.toString() ??
                      '';
                  return raw.toLowerCase().contains('new')
                      ? 'New Patient'
                      : 'Follow-up';
                }(),
                isNewPatient: () {
                  final raw = data['patientType']?.toString() ??
                      aptData?['patientType']?.toString() ??
                      '';
                  return raw.toLowerCase().contains('new');
                }(),
                icNumber: data['icNumber']?.toString() ??
                    aptData?['icNumber']?.toString() ??
                    'N/A',
                emailDisplay: () {
                  final emailRaw = data['patientEmail']?.toString().trim() ??
                      data['email']?.toString().trim() ??
                      aptData?['email']?.toString().trim();
                  return (emailRaw != null && emailRaw.isNotEmpty)
                      ? emailRaw
                      : 'Not provided';
                }(),
                doctorLabel: _formatDoctorLabel(
                  data['doctorName']?.toString() ??
                      aptData?['doctorName']?.toString() ??
                      '',
                ),
                oldDate: _parseDate(data['oldDate']),
                oldTime: data['oldTime']?.toString() ?? 'N/A',
                newDate: _parseDate(data['requestedDate']),
                newTime: data['requestedTime']?.toString() ?? 'N/A',
                isProcessing: isProcessing,
                onApprove: () => _respondToRescheduleRequest(
                  context: context,
                  requestId: doc.id,
                  requestData: data,
                  isAccepted: true,
                ),
                onDecline: () => _respondToRescheduleRequest(
                  context: context,
                  requestId: doc.id,
                  requestData: data,
                  isAccepted: false,
                ),
              );
            }

            if (appointmentId.isEmpty) {
              return buildCard(null);
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .get(),
              builder: (context, aptSnap) {
                if (aptSnap.connectionState == ConnectionState.waiting) {
                  return const Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: OrthoqColors.navy,
                        ),
                      ),
                    ),
                  );
                }
                return buildCard(aptSnap.data?.data());
              },
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
    return SafeArea(
      bottom: false,
      child: DefaultTabController(
        key: const PageStorageKey<String>('patient_verification_tabs'),
        length: 2,
        child: Scaffold(
          backgroundColor: OrthoqColors.scaffoldBg,
          appBar: AppBar(
            title: const Text(
              'Patient Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: OrthoqColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: false,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF94A3B8),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: 'Pending Verification'),
                Tab(text: 'Reschedule Requests'),
              ],
            ),
          ),
          body: TabBarView(
            key: const ValueKey<String>('patient_verification_tab_view'),
            children: [
              _buildPendingAppointmentsTab(),
              _buildRescheduleRequestsTab(),
            ],
          ),
        ),
      ),
    );
  }
}
