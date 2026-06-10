import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/doctor_service.dart';
import '../theme/orthoq_colors.dart';

/// Circular doctor photo with CachedNetworkImage and a safe fallback icon.
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({
    super.key,
    this.imageUrl,
    this.radius = 28,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
    this.fallbackIcon = Icons.person_pin,
  });

  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;
  final IconData fallbackIcon;

  String get _normalizedUrl => DoctorService.normalizeDoctorImageUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final bg = backgroundColor ?? const Color(0xFFE6F2FF);
    final icColor = iconColor ?? OrthoqColors.navy;
    final icSize = iconSize ?? (radius * 1.15);

    if (_normalizedUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Icon(fallbackIcon, size: icSize, color: icColor),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: _normalizedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _LoadingPlaceholder(
            size: size,
            iconColor: icColor,
          ),
          errorWidget: (_, __, ___) => Icon(
            fallbackIcon,
            size: icSize,
            color: icColor,
          ),
        ),
      ),
    );
  }
}

/// Large rectangular doctor banner image for detail screens.
class DoctorHeaderImage extends StatelessWidget {
  const DoctorHeaderImage({
    super.key,
    this.imageUrl,
    this.height = 200,
    this.fallbackIcon = Icons.person_pin,
  });

  final String? imageUrl;
  final double height;
  final IconData fallbackIcon;

  String get _normalizedUrl => DoctorService.normalizeDoctorImageUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFE6F2FF);

    if (_normalizedUrl.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: bg,
        child: Icon(
          fallbackIcon,
          size: height * 0.45,
          color: OrthoqColors.navy,
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: _normalizedUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: bg,
          child: const Center(
            child: CircularProgressIndicator(
              color: OrthoqColors.navy,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: bg,
          child: Icon(
            fallbackIcon,
            size: height * 0.45,
            color: OrthoqColors.navy,
          ),
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({
    required this.size,
    required this.iconColor,
  });

  final double size;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: size * 0.35,
          height: size * 0.35,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
