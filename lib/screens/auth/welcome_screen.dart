import 'package:flutter/material.dart';

import '../../theme/orthoq_theme.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _navy = Color(0xFF1B3C68);
  static const double _backgroundImageOpacity = 0.55;
  static const double _overlayOpacity = 0.52;

  void _openLogin(BuildContext context, String userType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(userType: userType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: _backgroundImageOpacity,
            child: Image.asset(
              'assets/images/hospitalkajang.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Container(color: _navy.withValues(alpha: _overlayOpacity)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 175,
                        child: Image.asset(
                          'assets/images/LOGO ORTHOQ.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Orthopaedic Outpatient Clinic,\nHospital Kajang',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 48),
                      _WelcomeLoginButton(
                        label: 'Patient',
                        onPressed: () => _openLogin(context, 'patient'),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeLoginButton(
                        label: 'Doctor',
                        onPressed: () => _openLogin(context, 'doctor'),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeLoginButton(
                        label: 'Staff',
                        onPressed: () => _openLogin(context, 'staff'),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeLoginButton(
                        label: 'Admin',
                        onPressed: () => _openLogin(context, 'admin'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeLoginButton extends StatelessWidget {
  const _WelcomeLoginButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: OrthoqTheme.welcomePortalButton(WelcomeScreen._navy),
        child: Text(label),
      ),
    );
  }
}
