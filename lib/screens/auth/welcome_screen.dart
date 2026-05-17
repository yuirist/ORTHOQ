import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/orthoq_theme.dart';
import '../../utils/auth_navigation.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const Color _navy = Color(0xFF1B3C68);
  static const double _backgroundImageOpacity = 0.55;
  static const double _overlayOpacity = 0.52;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSessionIfNeeded());
  }

  Future<void> _restoreSessionIfNeeded() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final profile = auth.currentUserData;
    if (user == null || profile == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) {
          final resolved = ensureUserProfile(
            user: user,
            profile: profile,
            fallbackRole: profile.role,
          );
          return homeScreenForRole(
            profile.role,
            uid: user.uid,
            userData: resolved,
          );
        },
      ),
    );
  }

  void _openLogin(String userType) {
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
      backgroundColor: WelcomeScreen._navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: WelcomeScreen._backgroundImageOpacity,
            child: Image.asset(
              'assets/images/hospitalkajang.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Container(color: WelcomeScreen._navy.withValues(alpha: WelcomeScreen._overlayOpacity)),
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
                      const Text(
                        'Orthopaedic Outpatient Clinic,\nHospital Kajang',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.35,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 48),
                      _WelcomeLoginButton(
                        label: 'Patient',
                        onPressed: () => _openLogin('patient'),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeLoginButton(
                        label: 'Doctor',
                        onPressed: () => _openLogin('doctor'),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeLoginButton(
                        label: 'Staff',
                        onPressed: () => _openLogin('staff'),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeLoginButton(
                        label: 'Admin',
                        onPressed: () => _openLogin('admin'),
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
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
