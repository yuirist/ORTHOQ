import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'utils/auth_navigation.dart';
import 'widgets/auth_gate.dart';

import 'firebase_options.dart';
import 'theme/orthoq_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Optional — use --dart-define=GEMINI_API_KEY=... in production builds.
  }

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
        home: const AuthGate(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
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
