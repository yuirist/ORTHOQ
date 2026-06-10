import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/email_verification_page.dart';
import '../screens/auth/welcome_screen.dart';
import '../theme/orthoq_colors.dart';
import '../theme/orthoq_typography.dart';
import '../utils/auth_navigation.dart';

/// App entry gate: restores Firebase sessions and routes by Firestore role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseReady = context.watch<AuthProvider>().isFirebaseInitialized;

    if (!firebaseReady) {
      return const WelcomeScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }

        return _AuthenticatedHome(user: user);
      },
    );
  }
}

/// Loads Firestore profile for a signed-in Firebase user, then opens the role dashboard.
class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({required this.user});

  final User user;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  Future<UserModel?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _profileFuture = auth.currentUserData != null
        ? Future.value(auth.currentUserData)
        : auth.applyLoginSession(firebaseUser: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen(message: 'Loading your profile…');
        }

        final profile =
            snapshot.data ?? context.read<AuthProvider>().currentUserData;

        if (profile == null) {
          return const WelcomeScreen();
        }

        final role = normalizeRole(profile.role);
        if (!isKnownClinicRole(role)) {
          return const WelcomeScreen();
        }

        if (role == 'patient') {
          return _PatientVerifiedGate(user: widget.user, profile: profile);
        }

        final resolved = ensureUserProfile(
          user: widget.user,
          profile: profile,
          fallbackRole: role,
        );

        return homeScreenForRole(
          role,
          uid: widget.user.uid,
          userData: resolved,
        );
      },
    );
  }
}

/// Blocks patient dashboard access until email is verified (same rule as login).
class _PatientVerifiedGate extends StatefulWidget {
  const _PatientVerifiedGate({
    required this.user,
    required this.profile,
  });

  final User user;
  final UserModel profile;

  @override
  State<_PatientVerifiedGate> createState() => _PatientVerifiedGateState();
}

class _PatientVerifiedGateState extends State<_PatientVerifiedGate> {
  bool _checking = true;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    try {
      await widget.user.reload();
      final refreshed = FirebaseAuth.instance.currentUser ?? widget.user;
      if (mounted) {
        setState(() {
          _verified = refreshed.emailVerified;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verified = widget.user.emailVerified;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const _AuthLoadingScreen(message: 'Checking account…');
    }

    if (!_verified) {
      return EmailVerificationPage(
        email: widget.user.email ?? '',
      );
    }

    final resolved = ensureUserProfile(
      user: widget.user,
      profile: widget.profile,
      fallbackRole: 'patient',
    );

    return homeScreenForRole(
      'patient',
      uid: widget.user.uid,
      userData: resolved,
    );
  }
}

/// Full-screen splash while Firebase auth or Firestore profile is resolving.
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen({this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: OrthoqColors.navy,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: OrthoqTypography.bodyMedium(
                color: OrthoqColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
