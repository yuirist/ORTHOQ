import 'package:flutter/material.dart';

import 'orthoq_colors.dart';

/// Shared Material theme for OrthoQ.
abstract final class OrthoqTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: OrthoqColors.scaffoldBg,
        primaryColor: OrthoqColors.navy,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: OrthoqColors.navy,
          onPrimary: OrthoqColors.white,
          secondary: OrthoqColors.navy,
          onSecondary: OrthoqColors.white,
          surface: OrthoqColors.white,
          onSurface: OrthoqColors.navy,
          error: Color(0xFFB00020),
          onError: OrthoqColors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: OrthoqColors.navy,
          foregroundColor: OrthoqColors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: OrthoqColors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: OrthoqColors.navy,
            foregroundColor: OrthoqColors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: OrthoqColors.white,
          selectedItemColor: OrthoqColors.navy,
          unselectedItemColor: Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        cardTheme: CardThemeData(
          color: OrthoqColors.white,
          elevation: 2,
          shadowColor: OrthoqColors.navy.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: OrthoqColors.navy,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: OrthoqColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: OrthoqColors.lightSlate),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: OrthoqColors.lightSlate),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: OrthoqColors.navy, width: 2),
          ),
        ),
      );

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: OrthoqColors.navy,
        foregroundColor: OrthoqColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  static ButtonStyle welcomePortalButton(Color navy) => ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: OrthoqColors.white,
        elevation: 2,
        shadowColor: Colors.black38,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
