import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/doctor_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_typography.dart';
import '../../utils/auth_navigation.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

/// Blocks doctor dashboard access until an administrator approves registration.
class DoctorApprovalGate extends StatefulWidget {
  const DoctorApprovalGate({
    super.key,
    required this.user,
    required this.profile,
  });

  final User user;
  final UserModel profile;

  @override
  State<DoctorApprovalGate> createState() => _DoctorApprovalGateState();
}

class _DoctorApprovalGateState extends State<DoctorApprovalGate> {
  final DoctorService _doctorService = DoctorService();
  DoctorModel? _doctor;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
  }

  Future<void> _loadDoctorProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final doctor = await _doctorService.getDoctorByUserId(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: OrthoqColors.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: OrthoqColors.navy),
        ),
      );
    }

    if (_loadError != null) {
      return _StatusScaffold(
        icon: Icons.error_outline,
        iconColor: Colors.red.shade700,
        title: 'Could not verify account',
        message: _loadError!,
        primaryActionLabel: 'Try again',
        onPrimaryAction: _loadDoctorProfile,
        secondaryActionLabel: 'Back to login',
        onSecondaryAction: _signOut,
      );
    }

    final doctor = _doctor;
    if (doctor == null) {
      return _StatusScaffold(
        icon: Icons.medical_services_outlined,
        iconColor: OrthoqColors.navy,
        title: 'Doctor profile not found',
        message:
            'Your account exists but no doctor profile was found. '
            'Please contact the clinic administrator.',
        primaryActionLabel: 'Back to login',
        onPrimaryAction: _signOut,
      );
    }

    if (doctor.canAccessPortal) {
      final resolved = ensureUserProfile(
        user: widget.user,
        profile: widget.profile,
        fallbackRole: 'doctor',
      );
      return doctorDashboard(uid: widget.user.uid, userData: resolved);
    }

    if (doctor.isApprovalRejected) {
      final reason = doctor.rejectionReason?.trim();
      return _StatusScaffold(
        icon: Icons.cancel_outlined,
        iconColor: Colors.red.shade700,
        title: 'Registration not approved',
        message: reason != null && reason.isNotEmpty
            ? reason
            : 'Your doctor registration was not approved. '
                'Please contact the clinic administrator for more information.',
        primaryActionLabel: 'Back to login',
        onPrimaryAction: _signOut,
      );
    }

    if (!doctor.isActive && doctor.approvalStatus == DoctorModel.approvalApproved) {
      return _StatusScaffold(
        icon: Icons.block,
        iconColor: Colors.orange.shade800,
        title: 'Account inactive',
        message:
            'Your doctor account is currently inactive. '
            'Please contact the clinic administrator.',
        primaryActionLabel: 'Back to login',
        onPrimaryAction: _signOut,
      );
    }

    return _StatusScaffold(
      icon: Icons.hourglass_top_outlined,
      iconColor: OrthoqColors.navy,
      title: 'Pending administrator approval',
      message:
          'Thank you for registering, Dr. ${doctor.name}. '
          'Your account is awaiting approval from the clinic administrator. '
          'You will be able to sign in once your registration has been reviewed.',
      primaryActionLabel: 'Refresh status',
      onPrimaryAction: _loadDoctorProfile,
      secondaryActionLabel: 'Back to login',
      onSecondaryAction: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(userType: 'doctor'),
          ),
          (route) => false,
        );
      },
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 72, color: iconColor),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: OrthoqTypography.sectionTitle(
                    color: OrthoqColors.navy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: OrthoqTypography.bodyMedium(
                    color: OrthoqColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPrimaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrthoqColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(primaryActionLabel),
                  ),
                ),
                if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onSecondaryAction,
                    child: Text(
                      secondaryActionLabel!,
                      style: const TextStyle(
                        color: OrthoqColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
