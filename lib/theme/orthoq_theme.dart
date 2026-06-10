import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'orthoq_colors.dart';
import 'orthoq_typography.dart';

/// Shared Material 3 theme for OrthoQ healthcare portals.
abstract final class OrthoqTheme {
  static const double inputRadius = 12;
  static const double cardRadius = 16;

  static InputDecorationTheme get _inputTheme => InputDecorationTheme(
        filled: true,
        fillColor: OrthoqColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: OrthoqTypography.bodyMedium(color: OrthoqColors.textSecondary),
        labelStyle: OrthoqTypography.label(),
        floatingLabelStyle: GoogleFonts.inter(
          color: OrthoqColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: OrthoqColors.lightSlate.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: OrthoqColors.lightSlate.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: OrthoqColors.navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
      );

  static ThemeData get light {
    final base = ThemeData(
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
        error: Color(0xFFDC2626),
        onError: OrthoqColors.white,
      ),
    );

    final textTheme = OrthoqTypography.buildTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: OrthoqColors.navy,
        foregroundColor: OrthoqColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: OrthoqColors.white,
        ),
        iconTheme: const IconThemeData(color: OrthoqColors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OrthoqColors.navy,
          foregroundColor: OrthoqColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: OrthoqTypography.button(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OrthoqColors.navy,
          side: BorderSide(color: OrthoqColors.navy.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: OrthoqTypography.button(color: OrthoqColors.navy),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OrthoqColors.navy,
          textStyle: OrthoqTypography.button(color: OrthoqColors.navy),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: OrthoqColors.navy,
        foregroundColor: OrthoqColors.white,
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OrthoqColors.white,
        indicatorColor: OrthoqColors.navy.withValues(alpha: 0.12),
        elevation: 3,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? OrthoqColors.navy : OrthoqColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? OrthoqColors.navy : OrthoqColors.textSecondary,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: OrthoqColors.white,
        selectedItemColor: OrthoqColors.navy,
        unselectedItemColor: OrthoqColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: OrthoqColors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shadowColor: OrthoqColors.navy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: OrthoqColors.lightSlate.withValues(alpha: 0.75)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: OrthoqColors.lightSlate.withValues(alpha: 0.8),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: OrthoqTypography.bodyMedium(color: OrthoqColors.white),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: OrthoqTypography.sectionTitle(),
        contentTextStyle: OrthoqTypography.bodyMedium(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: OrthoqColors.navy,
      ),
      inputDecorationTheme: _inputTheme,
      splashColor: OrthoqColors.navy.withValues(alpha: 0.08),
      highlightColor: OrthoqColors.navy.withValues(alpha: 0.04),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Consistent field decoration — inherits global [inputDecorationTheme].
  static InputDecoration field({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: OrthoqColors.navy,
        foregroundColor: OrthoqColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: OrthoqTypography.button(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputRadius)),
      );

  static ButtonStyle welcomePortalButton(Color navy) => ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: OrthoqColors.white,
        elevation: 2,
        shadowColor: OrthoqColors.navy.withValues(alpha: 0.25),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        textStyle: OrthoqTypography.button(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputRadius)),
      );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: OrthoqColors.navy.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
}
