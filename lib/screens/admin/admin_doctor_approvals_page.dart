import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_widgets.dart';
import '../../utils/doctor_name_format.dart';
import '../../widgets/doctor_avatar.dart';

/// Admin page to review and approve or reject self-registered doctor accounts.
class AdminDoctorApprovalsPage extends StatefulWidget {
  const AdminDoctorApprovalsPage({super.key});

  static const Color _navy = OrthoqColors.slateNavy;

  @override
  State<AdminDoctorApprovalsPage> createState() =>
      _AdminDoctorApprovalsPageState();
}

class _AdminDoctorApprovalsPageState extends State<AdminDoctorApprovalsPage> {
  final DoctorService _doctorService = DoctorService();
  final Set<String> _processingIds = <String>{};
  bool _loadingDialogOpen = false;

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
          child: CircularProgressIndicator(color: AdminDoctorApprovalsPage._navy),
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

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _promptRejectionReason(DoctorModel doctor) async {
    final reasonController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              'Reject ${formatDoctorDisplayName(doctor.name)}',
              style: const TextStyle(color: AdminDoctorApprovalsPage._navy),
            ),
            content: SingleChildScrollView(
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Reason shown to the doctor if they sign in…',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                  rootNavigator: true,
                ).pop(reasonController.text.trim()),
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _approveDoctor(DoctorModel doctor) async {
    if (_processingIds.contains(doctor.id)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve doctor'),
        content: Text(
          'Approve registration for ${formatDoctorDisplayName(doctor.name)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processingIds.add(doctor.id));
    _showBlockingLoading();
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _doctorService.approveDoctor(
        doctorId: doctor.id,
        reviewedBy: adminUid,
      );
      _showSnackBar(
        '${formatDoctorDisplayName(doctor.name)} approved',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Could not approve doctor: $e', isError: true);
    } finally {
      _dismissBlockingLoading();
      if (mounted) {
        setState(() => _processingIds.remove(doctor.id));
      }
    }
  }

  Future<void> _rejectDoctor(DoctorModel doctor) async {
    if (_processingIds.contains(doctor.id)) return;

    final reason = await _promptRejectionReason(doctor);
    if (reason == null) return;

    setState(() => _processingIds.add(doctor.id));
    _showBlockingLoading();
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _doctorService.rejectDoctor(
        doctorId: doctor.id,
        reviewedBy: adminUid,
        rejectionReason: reason,
      );
      _showSnackBar(
        '${formatDoctorDisplayName(doctor.name)} rejected',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Could not reject doctor: $e', isError: true);
    } finally {
      _dismissBlockingLoading();
      if (mounted) {
        setState(() => _processingIds.remove(doctor.id));
      }
    }
  }

  String _formatSubmittedAt(DoctorModel doctor) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(doctor.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.adminPageBg,
      appBar: AppBar(
        title: const Text('Doctor Registrations'),
        backgroundColor: AdminDoctorApprovalsPage._navy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DoctorModel>>(
        stream: _doctorService.getPendingDoctors(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load pending registrations.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AdminDoctorApprovalsPage._navy,
              ),
            );
          }

          final pending = snapshot.data!;
          if (pending.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending registrations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'New doctor sign-ups will appear here for your review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: OrthoqSpacing.list,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  '${pending.length} pending registration${pending.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AdminDoctorApprovalsPage._navy,
                  ),
                ),
              ),
              ...pending.map((doctor) {
                final processing = _processingIds.contains(doctor.id);
                return OrthoqInteractiveCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DoctorAvatar(
                              imageUrl: doctor.imageUrl,
                              radius: 30,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatDoctorDisplayName(doctor.name),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AdminDoctorApprovalsPage._navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doctor.specialization,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (doctor.officialDoctorId != null &&
                            doctor.officialDoctorId!.isNotEmpty) ...[
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: doctor.officialDoctorId!,
                          ),
                          const SizedBox(height: 6),
                        ],
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: doctor.email.isNotEmpty
                              ? doctor.email
                              : 'No email',
                        ),
                        if (doctor.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            label: doctor.phoneNumber,
                          ),
                        ],
                        if (doctor.credentials != null &&
                            doctor.credentials!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.school_outlined,
                            label: doctor.credentials!,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.schedule,
                          label: 'Submitted ${_formatSubmittedAt(doctor)}',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _rejectDoctor(doctor),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _approveDoctor(doctor),
                                icon: processing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AdminDoctorApprovalsPage._navy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }
}
