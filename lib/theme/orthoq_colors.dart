import 'package:flutter/material.dart';

/// OrthoQ professional brand palette.
abstract final class OrthoqColors {
  /// Primary Navy Blue — headers, buttons, active icons.
  static const Color navy = Color(0xFF1B3C68);

  /// Alias used across portals and admin screens.
  static const Color slateNavy = navy;

  /// Primary actions (same as [navy] for consistent branding).
  static const Color techBlue = navy;

  static const Color lightSlate = Color(0xFFE2E8F0);
  static const Color white = Color(0xFFFFFFFF);

  /// Light gray for patient portals and general screens.
  static const Color scaffoldBg = Color(0xFFF8FAFC);

  /// Admin dashboard and staff list — pure white for contrast with navy cards.
  static const Color adminPageBg = white;
}
