import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/email_verification_page.dart';
import '../screens/auth/doctor_approval_gate.dart';
import '../screens/auth/welcome_screen.dart';
import '../theme/orthoq_colors.dart';
import '../theme/orthoq_typography.dart';
import '../utils/auth_navigation.dart';

const Duration _profileFetchTimeout = Duration(seconds: 15);
const Duration _emailReloadTimeout = Duration(seconds: 10);

Widget _routeAuthenticatedUser({
  required User user,
  required UserModel profile,
  required String fallbackRole,
}) {
  if (isAdminBypassEmail(user.email)) {
    final resolved = ensureUserProfile(
      user: user,
      profile: profile,
      fallbackRole: 'admin',
    );
    return homeScreenForRole('admin', uid: user.uid, userData: resolved);
  }

  final normalizedRole = normalizeRole(profile.role);
  if (!isKnownClinicRole(normalizedRole)) {
    return const WelcomeScreen();
  }

  if (requiresEmailVerification(normalizedRole)) {
    return EmailVerifiedGate(user: user, profile: profile);
  }

  if (normalizedRole == 'doctor') {
    return DoctorApprovalGate(user: user, profile: profile);
  }

  final resolved = ensureUserProfile(
    user: user,
    profile: profile,
    fallbackRole: fallbackRole,
  );
  return homeScreenForRole(
    normalizedRole,
    uid: user.uid,
    userData: resolved,
  );
}

Widget _adminBypassHome({
  required User user,
  required AuthProvider auth,
  required bool fetchTriggered,
}) {
  if (auth.isProfileLoading || !fetchTriggered) {
    return const AuthLoadingScreen(
      message: 'Loading your profile…',
      showBackToLogin: true,
    );
  }

  final profile = auth.currentUserData ?? syntheticAdminProfile(user);
  return _routeAuthenticatedUser(
    user: user,
    profile: profile,
    fallbackRole: 'admin',
  );
}

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
          return const AuthLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }

        return _AuthenticatedHome(
          key: ValueKey(user.uid),
          user: user,
        );
      },
    );
  }
}

/// Named-route gate: resolves profile from [AuthProvider] without blocking loops.
class ProfileRouteGate extends StatefulWidget {
  const ProfileRouteGate({
    super.key,
    required this.fallbackRole,
  });

  final String fallbackRole;

  @override
  State<ProfileRouteGate> createState() => _ProfileRouteGateState();
}

class _ProfileRouteGateState extends State<ProfileRouteGate> {
  bool _fetchTriggered = false;

  void _scheduleProfileLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureProfileLoaded();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleProfileLoad();
  }

  @override
  void didUpdateWidget(covariant ProfileRouteGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fallbackRole != widget.fallbackRole) {
      _fetchTriggered = false;
      _scheduleProfileLoad();
    }
  }

  void _ensureProfileLoaded() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || auth.currentUserData != null || _fetchTriggered) {
      return;
    }
    _fetchTriggered = true;
    auth
        .applyLoginSession(firebaseUser: user)
        .timeout(_profileFetchTimeout, onTimeout: () => null)
        .then((profile) => _handleProfileLoadResult(profile));
  }

  void _handleProfileLoadResult(UserModel? profile) {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (profile != null || auth.profileLoadError != null) return;
    final user = auth.currentUser;
    if (user != null &&
        auth.currentUserData == null &&
        !isAdminBypassEmail(user.email)) {
      auth.signOut();
    }
  }

  Widget _buildRoleHome({
    required User user,
    required UserModel profile,
    required String fallbackRole,
  }) =>
      _routeAuthenticatedUser(
        user: user,
        profile: profile,
        fallbackRole: fallbackRole,
      );

  Widget _buildAdminBypassHome(User user, AuthProvider auth) =>
      _adminBypassHome(
        user: user,
        auth: auth,
        fetchTriggered: _fetchTriggered,
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null || auth.profileLoadError != null) {
      return const WelcomeScreen();
    }

    if (isAdminBypassEmail(user.email)) {
      return _buildAdminBypassHome(user, auth);
    }

    final profile = auth.currentUserData;

    if (profile == null &&
        (auth.isProfileLoading || !_fetchTriggered)) {
      return const AuthLoadingScreen(
        message: 'Loading your profile…',
        showBackToLogin: true,
      );
    }

    if (profile == null) {
      return const WelcomeScreen();
    }

    return _buildRoleHome(
      user: user,
      profile: profile,
      fallbackRole: widget.fallbackRole,
    );
  }
}

/// Loads Firestore profile for a signed-in Firebase user, then opens the role dashboard.
class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({super.key, required this.user});

  final User user;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  bool _fetchTriggered = false;

  void _scheduleProfileLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureProfileLoaded();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleProfileLoad();
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _fetchTriggered = false;
      _scheduleProfileLoad();
    }
  }

  void _ensureProfileLoaded() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.currentUserData != null || _fetchTriggered) return;
    _fetchTriggered = true;
    auth
        .applyLoginSession(firebaseUser: widget.user)
        .timeout(_profileFetchTimeout, onTimeout: () => null)
        .then((profile) => _handleProfileLoadResult(profile));
  }

  void _handleProfileLoadResult(UserModel? profile) {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (profile != null || auth.profileLoadError != null) return;
    final user = auth.currentUser ?? widget.user;
    if (auth.currentUserData == null && !isAdminBypassEmail(user.email)) {
      auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.currentUserData;

    if (auth.currentUser == null || auth.profileLoadError != null) {
      return const WelcomeScreen();
    }

    if (isAdminBypassEmail(widget.user.email)) {
      return _adminBypassHome(
        user: widget.user,
        auth: auth,
        fetchTriggered: _fetchTriggered,
      );
    }

    if (profile == null &&
        (auth.isProfileLoading || !_fetchTriggered)) {
      return const AuthLoadingScreen(
        message: 'Loading your profile…',
        showBackToLogin: true,
      );
    }

    if (profile == null) {
      return const WelcomeScreen();
    }

    return _routeAuthenticatedUser(
      user: widget.user,
      profile: profile,
      fallbackRole: normalizeRole(profile.role),
    );
  }
}

/// Blocks dashboard access until email is verified (patient and staff).
class EmailVerifiedGate extends StatefulWidget {
  const EmailVerifiedGate({
    super.key,
    required this.user,
    required this.profile,
  });

  final User user;
  final UserModel profile;

  @override
  State<EmailVerifiedGate> createState() => _EmailVerifiedGateState();
}

class _EmailVerifiedGateState extends State<EmailVerifiedGate> {
  late bool _checking;
  late bool _verified;

  @override
  void initState() {
    super.initState();
    _verified = widget.user.emailVerified;
    _checking = !_verified;
    if (_checking) {
      _refreshVerificationStatus();
    }
  }

  Future<void> _refreshVerificationStatus() async {
    try {
      await widget.user.reload().timeout(_emailReloadTimeout);
      final refreshed = FirebaseAuth.instance.currentUser ?? widget.user;
      if (!mounted) return;
      setState(() {
        _verified = refreshed.emailVerified;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verified = widget.user.emailVerified;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isAdminBypassEmail(widget.user.email)) {
      final resolved = ensureUserProfile(
        user: widget.user,
        profile: widget.profile,
        fallbackRole: 'admin',
      );
      return homeScreenForRole('admin', uid: widget.user.uid, userData: resolved);
    }

    if (_checking) {
      return const AuthLoadingScreen(message: 'Checking account…');
    }

    if (!_verified) {
      final role = normalizeRole(widget.profile.role);
      final loginPortal = role == 'staff' ? 'staff' : 'patient';
      return EmailVerificationPage(
        email: widget.user.email ?? '',
        loginPortal: loginPortal,
      );
    }

    final resolved = ensureUserProfile(
      user: widget.user,
      profile: widget.profile,
      fallbackRole: normalizeRole(widget.profile.role),
    );

    return homeScreenForRole(
      normalizeRole(widget.profile.role),
      uid: widget.user.uid,
      userData: resolved,
    );
  }
}

/// Full-screen splash while Firebase auth or Firestore profile is resolving.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({
    super.key,
    this.message = 'Loading…',
    this.showBackToLogin = false,
  });

  final String message;
  final bool showBackToLogin;

  Future<void> _backToWelcome(BuildContext context) async {
    await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                textAlign: TextAlign.center,
              ),
              if (showBackToLogin) ...[
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => _backToWelcome(context),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      color: OrthoqColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
