import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
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

/// Upper-case first letter of the last word of [name] that starts with a
/// letter (the given name in Vietnamese; emoji and symbol words are skipped),
/// or `?` when there is none.
String avatarInitial(String name) {
  final letter = RegExp(r'^\p{L}', unicode: true);
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && letter.hasMatch(w));
  if (words.isEmpty) {
    return '?';
  }
  return words.last.characters.first.toUpperCase();
}

/// A round profile picture. A failed or missing photo leaves the initial on a
/// soft gradient; the photo itself never shows a retry button here.
///
/// The name is announced to screen readers unless [decorative] is set (use it
/// next to a visible name). A [badge] keeps its own semantics.
class AppAvatar extends StatelessWidget {
  static Widget skeleton({
    Key? key,
    AppAvatarSize size = AppAvatarSize.md,
  }) => AppSkeleton.circle(
    key: key,
    size: size.dimension,
  );

  const AppAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = AppAvatarSize.md,
    this.badge,
    this.decorative = false,
  });

  final String? url;
  final String name;
  final AppAvatarSize size;
  final Widget? badge;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = size.dimension;
    final circle = DecoratedBox(
      key: const Key('avatar-ring'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
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
    );
    return SizedBox.square(
      dimension: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: decorative
                ? ExcludeSemantics(child: circle)
                : Semantics(
                    label: name,
                    image: true,
                    excludeSemantics: true,
                    child: circle,
                  ),
          ),
          if (badge != null) Positioned(right: -2, bottom: -2, child: badge!),
        ],
      ),
    );
  }
}
