// lib/core/widgets/verified_mark.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Verified photographer: a small blue disc with a white check, no text.
/// Not used for badges (those are purple); see spec 3d.1.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.verifiedLabel;
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.ctaStart,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: size * 0.72,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A name followed by [VerifiedMark], raised about 3dp above the baseline so
/// it reads as a superscript to the name rather than sitting mid-line.
class VerifiedName extends StatelessWidget {
  const VerifiedName(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: name,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.aboveBaseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Transform.translate(
                offset: const Offset(0, -3),
                child: const VerifiedMark(),
              ),
            ),
          ),
        ],
      ),
      style: style,
    );
  }
}
