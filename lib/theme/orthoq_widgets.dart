import 'package:flutter/material.dart';

import 'orthoq_colors.dart';
import 'orthoq_theme.dart';
import 'orthoq_typography.dart';

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

/// Section header with optional trailing action.
class OrthoqSectionHeader extends StatelessWidget {
  const OrthoqSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrthoqSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: OrthoqTypography.sectionTitle()),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Tappable card with soft shadow, rounded corners, and ink splash feedback.
class OrthoqInteractiveCard extends StatelessWidget {
  const OrthoqInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.borderRadius = 16,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: OrthoqSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: color ?? OrthoqColors.white,
          border: Border.all(
            color: OrthoqColors.lightSlate.withValues(alpha: 0.7),
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

/// Empty state with healthcare iconography.
class OrthoqEmptyState extends StatelessWidget {
  const OrthoqEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: OrthoqSpacing.form,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: OrthoqColors.navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: OrthoqColors.navy),
          ),
          const SizedBox(height: OrthoqSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: OrthoqTypography.sectionTitle(),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: OrthoqSpacing.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: OrthoqTypography.bodyMedium(color: OrthoqColors.textSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: OrthoqSpacing.lg),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Pulsing skeleton placeholder for loading states.
class OrthoqSkeletonBox extends StatefulWidget {
  const OrthoqSkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 12,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<OrthoqSkeletonBox> createState() => _OrthoqSkeletonBoxState();
}

class _OrthoqSkeletonBoxState extends State<OrthoqSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(
              OrthoqColors.lightSlate,
              OrthoqColors.inputFill,
              _controller.value,
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton layout for appointment / list cards.
class OrthoqSkeletonAppointmentCard extends StatelessWidget {
  const OrthoqSkeletonAppointmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrthoqInteractiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrthoqSkeletonBox(height: 48, width: 48, borderRadius: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OrthoqSkeletonBox(height: 14, width: 140),
                    SizedBox(height: 8),
                    OrthoqSkeletonBox(height: 12, width: 100),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OrthoqSkeletonBox(height: 56)),
              SizedBox(width: 12),
              Expanded(child: OrthoqSkeletonBox(height: 56)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated success check for booking confirmations.
class OrthoqSuccessAnimation extends StatefulWidget {
  const OrthoqSuccessAnimation({super.key, this.size = 100});

  final double size;

  @override
  State<OrthoqSuccessAnimation> createState() => _OrthoqSuccessAnimationState();
}

class _OrthoqSuccessAnimationState extends State<OrthoqSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Color(0xFF16A34A),
          size: 56,
        ),
      ),
    );
  }
}

/// Material 3 bottom navigation shell shared by patient & staff portals.
class OrthoqModernBottomNav extends StatelessWidget {
  const OrthoqModernBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: OrthoqColors.white,
      indicatorColor: OrthoqColors.navy.withValues(alpha: 0.12),
      elevation: 3,
      shadowColor: OrthoqColors.navy.withValues(alpha: 0.1),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: destinations,
    );
  }
}

/// Navy FAB for quick patient booking.
class OrthoqBookingFab extends StatelessWidget {
  const OrthoqBookingFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: OrthoqColors.navy,
      foregroundColor: OrthoqColors.white,
      elevation: 4,
      highlightElevation: 6,
      icon: const Icon(Icons.add_rounded),
      label: Text('Book', style: OrthoqTypography.button()),
    );
  }
}
