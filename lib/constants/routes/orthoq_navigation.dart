import 'package:flutter/material.dart';

/// Smooth slide + fade page transition for healthcare app navigation.
class OrthoqPageRoute<T> extends PageRouteBuilder<T> {
  OrthoqPageRoute({required Widget page, RouteSettings? settings})
      : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Push helper used across portals.
Future<T?> pushOrthoQPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(OrthoqPageRoute<T>(page: page));
}
