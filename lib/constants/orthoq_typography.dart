import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'orthoq_colors.dart';

/// Dual-font hierarchy: Poppins (headings/buttons) + Inter (body/forms).
abstract final class OrthoqTypography {
  static TextStyle headingLarge({Color? color}) => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color ?? OrthoqColors.navy,
        height: 1.25,
        letterSpacing: -0.3,
      );

  static TextStyle headingMedium({Color? color}) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color ?? OrthoqColors.navy,
        height: 1.3,
      );

  static TextStyle sectionTitle({Color? color}) => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: color ?? OrthoqColors.navy,
        height: 1.35,
      );

  static TextStyle titleMedium({Color? color}) => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color ?? OrthoqColors.navy,
      );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color ?? OrthoqColors.textPrimary,
        height: 1.5,
      );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? OrthoqColors.textPrimary,
        height: 1.45,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? OrthoqColors.textSecondary,
        height: 1.4,
      );

  static TextStyle button({Color? color}) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color ?? OrthoqColors.white,
        letterSpacing: 0.2,
      );

  static TextStyle label({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? OrthoqColors.textSecondary,
      );

  static TextTheme buildTextTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: headingLarge(),
      headlineMedium: headingMedium(),
      headlineSmall: sectionTitle(),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: OrthoqColors.navy,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: OrthoqColors.navy,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: OrthoqColors.textPrimary,
      ),
      bodyLarge: bodyLarge(),
      bodyMedium: bodyMedium(),
      bodySmall: bodySmall(),
      labelLarge: button(color: OrthoqColors.navy),
    );
  }
}
