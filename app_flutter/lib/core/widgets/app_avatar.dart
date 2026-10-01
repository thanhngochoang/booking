import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

enum AppAvatarSize {
  xs(32),
  sm(40),
  md(48),
  lg(64),
  xl(96);

  const AppAvatarSize(this.dimension);
  final double dimension;
}

/// Upper-case first letter of the last word of [name] (the given name in
/// Vietnamese), or `?` when there is none.
String avatarInitial(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) {
    return '?';
  }
  return words.last.characters.first.toUpperCase();
}

/// A round profile picture. A failed or missing photo leaves the initial on a
/// soft gradient; the photo itself never shows a retry button here.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = AppAvatarSize.md,
    this.badge,
  });

  final String? url;
  final String name;
  final AppAvatarSize size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = size.dimension;
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: d,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.ctaStart.withValues(alpha: 0.35),
                              AppColors.ctaEnd.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            avatarInitial(name),
                            style: TextStyle(
                              fontSize: d * 0.4,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (url != null) NetworkPhoto(url: url!, retry: false),
                    ],
                  ),
                ),
              ),
            ),
            if (badge != null) Positioned(right: -2, bottom: -2, child: badge!),
          ],
        ),
      ),
    );
  }
}
