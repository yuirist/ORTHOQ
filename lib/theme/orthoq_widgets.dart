import 'package:flutter/material.dart';

import 'orthoq_colors.dart';
import 'orthoq_theme.dart';

/// Consistent spacing scale for layouts.
abstract final class OrthoqSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const EdgeInsets form = EdgeInsets.all(24);
  static const EdgeInsets list = EdgeInsets.fromLTRB(16, 12, 16, 24);
}

/// Tappable card with soft shadow, rounded corners, and ink splash feedback.
class OrthoqInteractiveCard extends StatelessWidget {
  const OrthoqInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.borderRadius = 14,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: OrthoqSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: OrthoqColors.white,
          border: Border.all(
            color: OrthoqColors.lightSlate.withValues(alpha: 0.75),
          ),
          boxShadow: OrthoqTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: OrthoqColors.navy.withValues(alpha: 0.08),
            highlightColor: OrthoqColors.navy.withValues(alpha: 0.04),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(OrthoqSpacing.md),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
