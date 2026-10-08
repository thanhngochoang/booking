// lib/core/widgets/tomato_ratio_bar.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/verdict_icon.dart';

/// Tomato : brick split of a provider's reviews (mock `.vratio`): an 8 dp
/// pill, tomato first, a 2 dp gap, widths proportional to the counts. No
/// reviews draws an empty track.
class TomatoRatioBar extends StatelessWidget {
  const TomatoRatioBar({
    super.key,
    required this.tomatoCount,
    required this.brickCount,
  });

  final int tomatoCount;
  final int brickCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = tomatoCount < 0 ? 0 : tomatoCount;
    final b = brickCount < 0 ? 0 : brickCount;
    Widget segment(Key key, VerdictKind kind, int flex) => Expanded(
      flex: flex,
      child: DecoratedBox(
        key: key,
        decoration: BoxDecoration(color: verdictColor(context, kind)),
        child: const SizedBox.expand(),
      ),
    );
    return Semantics(
      label: context.l10n.reviewsRatioSemantics(t, b),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            height: 8,
            child: t + b == 0
                ? DecoratedBox(
                    key: const Key('ratio-empty'),
                    decoration: BoxDecoration(
                      color: dark ? AppColorsDark.border : AppColors.border,
                    ),
                    child: const SizedBox.expand(),
                  )
                : Row(
                    children: [
                      if (t > 0)
                        segment(
                          const Key('ratio-tomato'),
                          VerdictKind.tomato,
                          t,
                        ),
                      if (t > 0 && b > 0) const SizedBox(width: 2),
                      if (b > 0)
                        segment(const Key('ratio-brick'), VerdictKind.brick, b),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
