// lib/core/widgets/hashtag_chip.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// "#PhotoWalkPhoCo1020" as a pill, with "{n} bài" beside it (mock S11.05).
///
/// The pill is the event's hashtag: it reads as the active filter of the
/// timeline (accent text on the subtle accent fill, like a selected context
/// chip). Without [onTap] it is a label; with it, a button at least 48dp tall.
class HashtagChip extends StatelessWidget {
  const HashtagChip({super.key, required this.tag, this.count, this.onTap});

  /// The tag, with or without its `#`.
  final String tag;

  /// How many posts carry it; hidden when null.
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final text = tag.startsWith('#') ? tag : '#$tag';

    Widget pill = Material(
      color: subtle,
      shape: StadiumBorder(side: BorderSide(color: scheme.primary)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onTap != null) {
      pill = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(widthFactor: 1, heightFactor: 1, child: pill),
      );
    }

    final n = count;
    return Semantics(
      container: true,
      label: n == null ? text : '$text, ${context.l10n.timelineCount(n)}',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: pill),
          if (n != null) ...[
            const SizedBox(width: AppSpace.s2),
            Text(
              context.l10n.timelineCount(n),
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
