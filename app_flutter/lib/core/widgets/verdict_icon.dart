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

/// The tomato or brick line icon (mock `.tm svg`, `#i-tomato`, `#i-brick`),
/// tinted with the token colour unless [color] is given. Decorative: callers
/// put the spoken text on the surrounding widget.
class VerdictIcon extends StatelessWidget {
  const VerdictIcon(this.kind, {super.key, this.size = 16, this.color});

  final VerdictKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final asset = switch (kind) {
      VerdictKind.tomato => 'assets/icons/tomato.svg',
      VerdictKind.brick => 'assets/icons/brick.svg',
    };
    return ExcludeSemantics(
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color ?? verdictColor(context, kind),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
