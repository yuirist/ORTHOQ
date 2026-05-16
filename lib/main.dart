import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'utils/auth_navigation.dart';

import 'firebase_options.dart';

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
        theme: ThemeData(
          primaryColor: const Color(0xFF1A365D),
          scaffoldBackgroundColor: const Color(0xFFF7FAFC),
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF1A365D),
            onPrimary: Color(0xFFFFFFFF),
            secondary: Color(0xFF2B6CB0),
            onSecondary: Color(0xFFFFFFFF),
            error: Color(0xFFB00020),
            onError: Color(0xFFFFFFFF),
            surface: Color(0xFFFFFFFF),
            onSurface: Color(0xFF1A202C),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A365D),
            foregroundColor: Color(0xFFFFFFFF),
            iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
            titleTextStyle: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A365D),
              foregroundColor: const Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Color(0xFF1A365D),
            unselectedItemColor: Color(0xFF4A5568),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(color: Color(0xFF1A202C)),
            headlineMedium: TextStyle(color: Color(0xFF1A202C)),
            headlineSmall: TextStyle(color: Color(0xFF1A202C)),
            bodyLarge: TextStyle(color: Color(0xFF4A5568)),
            bodyMedium: TextStyle(color: Color(0xFF4A5568)),
            bodySmall: TextStyle(color: Color(0xFF4A5568)),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4A5568)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2B6CB0), width: 2),
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFFFFFFFF),
            elevation: 2,
            shadowColor: const Color(0xFF1A365D).withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          useMaterial3: true,
        ),
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
