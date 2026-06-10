import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_theme.dart';
import '../../theme/orthoq_widgets.dart';
import '../../utils/auth_navigation.dart';
import 'login_screen.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.userType,
    required this.email,
  });

  final String userType;
  final String email;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);
    try {
      final verified = await _authService.reloadAndCheckEmailVerified();
      if (!mounted) return;

      if (verified) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _showMessage('Session expired. Please sign in again.', isError: true);
          return;
        }

        final profile = await context.read<AuthProvider>().applyLoginSession(
              firebaseUser: user,
            );

        if (profile == null) {
          await FirebaseAuth.instance.signOut();
          _showMessage(
            'Profile not found. Please contact support.',
            isError: true,
          );
          return;
        }

        if (!mounted) return;
        await navigateAfterLogin(
          context: context,
          user: user,
          profile: profile,
          loginPortal: widget.userType,
        );
        return;
      }

      _showMessage(
        'Email not verified yet. Please check your inbox and click the link.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

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
        builder: (context) => LoginScreen(userType: widget.userType),
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
                'A verification email has been sent to your email address. '
                'Please check your inbox and verify your account before logging in.',
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
              ElevatedButton(
                onPressed: _isChecking ? null : _checkVerificationStatus,
                style: OrthoqTheme.primaryButton,
                child: _isChecking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Check Verification Status'),
              ),
              const SizedBox(height: OrthoqSpacing.sm),
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
              const SizedBox(height: OrthoqSpacing.sm),
              TextButton(
                onPressed: _backToLogin,
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
