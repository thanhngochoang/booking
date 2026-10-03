import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Block showing the day and month of an event in Vietnam time (UTC instant converted via [toVn]).
class DateBlock extends StatelessWidget {
  const DateBlock({
    super.key,
    required this.day,
    this.size = 46,
  });

  /// UTC instant; displayed in Vietnam time via [toVn].
  final DateTime day;
  final double size;

  static Widget skeleton({Key? key, double size = 46}) =>
      _DateBlockSkeleton(key: key, size: size);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final vn = toVn(day);

    return SizedBox(
      width: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: subtle,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s2,
          ),
          child: Semantics(
            label: l.eventDateSpoken(
              vn.weekday.toString(),
              vn.day,
              vn.month,
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vn.day.toString().padLeft(2, '0'),
                    key: const Key('event-day'),
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  Text(
                    l.eventMonthShort(vn.month),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBlockSkeleton extends StatelessWidget {
  const _DateBlockSkeleton({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Natural height of AppSpace.s2 * 2 + 20pt day + 9.5pt month is 57.0dp.
    const height = 57.0;
    return AppSkeleton.box(
      width: size,
      height: height,
      radius: AppRadius.lg,
    );
  }
}
