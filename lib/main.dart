import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/welcome_screen.dart';
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
        // Profile-aware route gates (replaces legacy _homeFromProvider).
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/patient-home': (context) =>
              const ProfileRouteGate(fallbackRole: 'patient'),
          '/doctor-home': (context) =>
              const ProfileRouteGate(fallbackRole: 'doctor'),
          '/staff-home': (context) =>
              const ProfileRouteGate(fallbackRole: 'staff'),
          '/admin-home': (context) =>
              const ProfileRouteGate(fallbackRole: 'admin'), // admin bypass in AuthGate
        },
      ),
    );
  }
}
