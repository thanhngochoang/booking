import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/meta_line.dart';
import 'package:photobooking/core/widgets/provider_mark.dart';

/// Who a studio sent to shoot, as [AssigneeCard] shows them.
@immutable
class AssigneeSummary {
  const AssigneeSummary({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.verified = false,
    this.tomatoPct,
    this.shoots = 0,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool verified;

  /// Their own tomato percent; null when they have too few reviews
  /// (`hasTomatoPct`), which leaves the percent out.
  final int? tomatoPct;

  /// Completed shoots ("112 buổi").
  final int shoots;
}

/// S05.02 "Thợ chụp cho bạn" (mock `#S05.02-studio`): the member a studio
/// assigned to a booking — avatar, name with the verified tick, "🍅 97% ·
/// 112 buổi · thợ của {studioName}", an outline xsmall "Xem hồ sơ" and,
/// under it, the outline "Xin đổi thợ (1 lần)" ([changeLabel]; disabled when
/// [onChange] is null, e.g. "Đã xin đổi · chờ studio"; left out when
/// [changeLabel] is null).
///
/// The person is read as one label (name, tick, percent, shoots, studio);
/// each button keeps its own name and a 48dp target. An empty [studioName]
/// leaves "thợ của …" out.
class AssigneeCard extends StatelessWidget {
  const AssigneeCard({
    super.key,
    required this.summary,
    required this.studioName,
    required this.onViewProfile,
    this.changeLabel,
    this.onChange,
  });

  final AssigneeSummary summary;
  final String studioName;
  final VoidCallback onViewProfile;
  final String? changeLabel;
  final VoidCallback? onChange;

  /// The card's shape while the member's profile loads.
  static Widget skeleton({Key? key}) => _Frame(
    key: key,
    child: Row(
      children: [
        AppAvatar.skeleton(size: AppAvatarSize.md),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.line(widthFactor: 0.4),
              const SizedBox(height: AppSpace.s1),
              AppSkeleton.line(widthFactor: 0.8),
            ],
          ),
        ),
      ],
    ),
  );

  List<MetaPart> _meta(BuildContext context) {
    final l = context.l10n;
    return [
      if (summary.tomatoPct case final pct?) MetaPart.tomato(pct),
      MetaPart.text(
        studioName.isEmpty
            ? l.photographerSessions(summary.shoots)
            : l.assigneeMeta(summary.shoots, studioName),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final meta = _meta(context);
    final person = Semantics(
      container: true,
      label: [
        summary.name,
        if (summary.verified) l.verifiedLabel,
        metaPartsSemantics(meta, l),
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          AppAvatar(
            url: summary.avatarUrl,
            name: summary.name,
            size: AppAvatarSize.md,
            decorative: true,
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        summary.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.base2,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                    if (summary.verified) ...[
                      const SizedBox(width: AppSpace.s1),
                      const ProviderMark(ProviderMarkKind.verified),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.s1),
                MetaLine(meta, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(child: person),
                const SizedBox(width: AppSpace.s2),
                // At most half the row, so the name always shows.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: AppButton.outline(
                    l.assigneeViewProfile,
                    key: const Key('assignee-view-profile'),
                    size: AppButtonSize.xsmall,
                    onPressed: onViewProfile,
                  ),
                ),
              ],
            ),
          ),
          if (changeLabel case final label?) ...[
            const SizedBox(height: AppSpace.s2),
            AppButton.outline(
              label,
              key: const Key('assignee-change'),
              size: AppButtonSize.small,
              onPressed: onChange,
            ),
          ],
        ],
      ),
    );
  }
}

/// Mock `.card` (column): glass fill, hairline, card radius.
class _Frame extends StatelessWidget {
  const _Frame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpace.s2h), child: child),
    );
  }
}
