import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_widgets.dart';
import 'login_screen.dart';

/// Email verification gate after registration or blocked login.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.loginPortal = 'patient',
  });

  final String email;
  final String loginPortal;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final AuthService _authService = AuthService();
  bool _isResending = false;

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        _showMessage('Verification email sent. Please check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _backToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(userType: widget.loginPortal),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: OrthoqColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: OrthoqSpacing.form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: OrthoqColors.navy.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: OrthoqSpacing.md),
              Text(
                'A verification email has been sent to your registered email address. '
                'Please verify your account before logging in.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (widget.email.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OrthoqColors.navy,
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: _isResending ? null : _resendEmail,
                child: _isResending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: OrthoqColors.navy,
                        ),
                      )
                    : const Text('Resend Email'),
              ),
              const SizedBox(height: OrthoqSpacing.md),
              TextButton(
                onPressed: _backToLogin,
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: OrthoqSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
