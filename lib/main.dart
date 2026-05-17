import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'utils/auth_navigation.dart';

import 'firebase_options.dart';
import 'theme/orthoq_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    firebaseInitialized = false;
  }

  runApp(OrthoQApp(firebaseInitialized: firebaseInitialized));
}

class OrthoQApp extends StatelessWidget {
  final bool firebaseInitialized;

  const OrthoQApp({super.key, this.firebaseInitialized = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(firebaseInitialized: firebaseInitialized),
        ),
      ],
      child: MaterialApp(
        title: 'OrthoQ',
        debugShowCheckedModeBanner: false,
        theme: OrthoqTheme.light,
        initialRoute: '/welcome',
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/app-home': (context) => const AuthWrapper(),
          '/patient-home': (context) => _homeFromProvider(context, 'patient'),
          '/doctor-home': (context) => _homeFromProvider(context, 'doctor'),
          '/staff-home': (context) => _homeFromProvider(context, 'staff'),
          '/admin-home': (context) => _homeFromProvider(context, 'admin'),
        },
      ),
    );
  }
}

Widget _homeFromProvider(BuildContext context, String role) {
  final auth = context.read<AuthProvider>();
  final user = auth.currentUser;
  final profile = auth.currentUserData;
  if (user == null || profile == null) {
    return const WelcomeScreen();
  }
  final resolved =
      ensureUserProfile(user: user, profile: profile, fallbackRole: role);
  return homeScreenForRole(role, uid: user.uid, userData: resolved);
}

/// Restores session on cold start when a user is already signed in.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isFirebaseInitialized) {
          return const WelcomeScreen();
        }

        if (authProvider.currentUser == null) {
          return const WelcomeScreen();
        }

        if (authProvider.currentUserData == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authProvider.currentUser!;
        final profile = authProvider.currentUserData!;
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
    );
  }
}
