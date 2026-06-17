import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/validation_utils.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'email_verification_page.dart';
import 'forgot_password_page.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_theme.dart';
import '../../theme/orthoq_widgets.dart';
import '../../utils/auth_navigation.dart';

class LoginScreen extends StatefulWidget {
  final String userType; // 'patient', 'doctor', 'staff', 'admin'

  const LoginScreen({super.key, required this.userType});

  static const Color navy = OrthoqColors.navy;

  bool get _isAdminPortal => userType.toLowerCase() == 'admin';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _patientIcController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.clear();
    _passwordController.clear();
    _patientIcController.clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _patientIcController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _completeLogin(User user) async {
    try {
      print(
        '[Role Check] Portal=${widget.userType} uid=${user.uid} — '
        'loading Firestore profile',
      );

      final profile = await context.read<AuthProvider>().applyLoginSession(
            firebaseUser: user,
          );

      if (profile == null) {
        print('[Role Check] No profile document found');
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          final isAdminPortal = widget.userType.toLowerCase() == 'admin';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isAdminPortal
                    ? 'No administrator profile found. '
                        'Ensure users/${user.uid} exists in Firestore with role: admin.'
                    : 'No profile found in the database. Please register first.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      final role = normalizeRole(profile.role);
      print(
        '[Role Check] Firestore role=$role → '
        '${roleDashboardName(role)} dashboard',
      );

      if (widget.userType.toLowerCase() == 'admin' && role != 'admin') {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Access denied. This account does not have administrator '
                'privileges (Firestore role must be admin).',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      await navigateAfterLogin(
        context: context,
        user: user,
        profile: profile,
        loginPortal: widget.userType,
      );
    } catch (e, stackTrace) {
      print('[Role Check] FAILED: $e');
      print('[Role Check] Stack trace:\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firebase is not initialized. Please run: flutterfire configure',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String authEmail;
      if (widget.userType == 'patient') {
        final normalizedIc =
            ValidationUtils.normalizeICNumber(_patientIcController.text);
        final patientSnap = await FirebaseFirestore.instance
            .collection('patients')
            .where('icNumber', isEqualTo: normalizedIc)
            .limit(1)
            .get();

        if (patientSnap.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('IC Number not registered.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final emailRaw = patientSnap.docs.first.data()['email']?.toString().trim();
        if (emailRaw == null || emailRaw.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account data is incomplete. Please contact support.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        authEmail = emailRaw;
      } else {
        authEmail = _emailController.text.trim();
      }

      final passwordSent = _passwordController.text;
      if (widget.userType.toLowerCase() == 'admin') {
        print(
          '[Admin Auth Debug] Attempting Firebase sign-in — '
          'email="$authEmail" password="$passwordSent" '
          '(length=${passwordSent.length}, codeUnits=${passwordSent.codeUnits})',
        );
      }

      final authService = AuthService();
      final userCredential = await authService.signInWithEmailAndPassword(
        email: authEmail,
        password: passwordSent,
      );

      final user = userCredential?.user;
      if (mounted && user != null) {
        final portal = widget.userType.toLowerCase();
        final needsEmailVerification = requiresEmailVerificationPortal(
          portal,
          email: user.email,
        );

        if (needsEmailVerification) {
          await user.reload();
          final refreshedUser = FirebaseAuth.instance.currentUser ?? user;

          if (!refreshedUser.emailVerified) {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Email Not Verified'),
                content: const Text(
                  'Please verify your email address before logging in.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationPage(
                  email: refreshedUser.email ?? authEmail,
                  loginPortal: widget.userType,
                ),
              ),
            );
            return;
          }

          await _completeLogin(refreshedUser);
        } else {
          await _completeLogin(user);
        }
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'LoginScreen FirebaseException: code=${e.code}, message=${e.message}',
      );
      if (mounted) {
        final isPatientLookup = widget.userType == 'patient' &&
            (e.code == 'permission-denied' || e.code == 'unavailable');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPatientLookup
                  ? '[${e.code}] Unable to verify IC number. Check your connection.'
                  : '[${e.code}] ${e.message ?? "Unknown error"}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      debugPrint('LoginScreen error: $e');
      if (widget.userType.toLowerCase() == 'admin' &&
          AuthService.matchesAdminBypassCredentials(
            _emailController.text.trim(),
            _passwordController.text,
          )) {
        print(
          '[Admin Auth Debug] Login failed after Firestore bypass attempt: $e',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is String ? e : '[error] ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _loginTitle {
    switch (widget.userType.toLowerCase()) {
      case 'staff':
        return 'STAFF LOGIN';
      case 'admin':
        return 'ADMIN LOGIN';
      default:
        return '${widget.userType.toUpperCase()} LOGIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: Text(_loginTitle),
        backgroundColor: LoginScreen.navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: OrthoqSpacing.form,
            child: SizedBox(
              width: 400,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 40),
                // Logo at the top
                Container(
                  height: 130,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/LOGO ORTHOQ.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: OrthoqSpacing.lg),

                if (widget.userType == 'patient') ...[
                  TextFormField(
                    controller: _patientIcController,
                    keyboardType: TextInputType.number,
                    decoration: OrthoqTheme.field(
                      labelText: 'IC Number',
                      hintText: 'e.g., 990101-14-5678',
                      prefixIcon: const Icon(Icons.credit_card),
                    ),
                    validator: ValidationUtils.validateMalaysianIC,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: OrthoqTheme.field(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: OrthoqSpacing.md),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: OrthoqTheme.field(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: OrthoqSpacing.md),
                
                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: OrthoqTheme.primaryButton,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
                if (!widget._isAdminPortal) ...[
                  const SizedBox(height: OrthoqSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RegisterScreen(userType: widget.userType),
                            ),
                          );
                        },
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


