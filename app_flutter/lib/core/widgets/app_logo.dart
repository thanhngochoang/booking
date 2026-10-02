import 'package:flutter/material.dart';

/// The aperture app icon as an in-app mark, with the launcher's squircle
/// corners so it reads as the same logo the user tapped on the home screen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88, this.shadows = _drop});

  final double size;

  /// Defaults to a soft drop shadow; pass coloured shadows for a glow.
  final List<BoxShadow> shadows;

  static const _drop = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 20,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    return Semantics(
      image: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            'assets/brand/logo.png',
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
