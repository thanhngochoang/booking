// lib/core/widgets/verdict_icon.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// The two sides of a review. Core cannot import `lib/data`, so features map
/// their own `Verdict` to this one.
enum VerdictKind { tomato, brick }

/// The token colour of [kind] on the current theme (tomato and brick are
/// exempt from the 60-30-10 split: icon, level track, badge and ratio bar).
Color verdictColor(BuildContext context, VerdictKind kind) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (kind) {
    VerdictKind.tomato => dark ? AppColorsDark.tomato : AppColors.tomato,
    VerdictKind.brick => dark ? AppColorsDark.brick : AppColors.brick,
  };
}

/// The tomato line icon (mock `#i-tomato`), tinted with the token colour
/// unless [color] is given, or the brick mascot (mock `#i-brick`), drawn in
/// its own colours with no background so it sits on the surface below it:
/// [color] does not apply to the brick, and [muted] fades it for an
/// unselected button. Decorative: callers put the spoken text on the
/// surrounding widget.
class VerdictIcon extends StatelessWidget {
  const VerdictIcon(
    this.kind, {
    super.key,
    this.size = 16,
    this.color,
    this.muted = false,
  });

  final VerdictKind kind;
  final double size;
  final Color? color;

  /// Brick only: draws the mascot faded (the tomato fades through [color]).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Widget picture = switch (kind) {
      VerdictKind.tomato => SvgPicture.asset(
        'assets/icons/tomato.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color ?? verdictColor(context, kind),
          BlendMode.srcIn,
        ),
      ),
      VerdictKind.brick => Opacity(
        opacity: muted ? 0.5 : 1,
        child: SvgPicture.asset(
          'assets/icons/brick.svg',
          width: size,
          height: size,
        ),
      ),
    };
    return ExcludeSemantics(child: picture);
  }
}
