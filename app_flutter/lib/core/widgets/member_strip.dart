import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/meta_line.dart';

/// One person on a [MemberStrip].
@immutable
class MemberStripItem {
  const MemberStripItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.tomatoPct,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  /// The member's own tomato percent; null when they have too few reviews
  /// (`hasTomatoPct`), which leaves the percent out.
  final int? tomatoPct;
}

/// A studio's members on S03.01 (mock `.mems`): up to four people, each an
/// avatar over the name and the tomato percent, then a "+n" circle for the
/// rest of [total]. Read as a list named [label] ("Thành viên Studio Mây");
/// the "+n" item says "và {n} thành viên khác". Tapping a person calls
/// [onTap] with their id.
class MemberStrip extends StatelessWidget {
  const MemberStrip({
    super.key,
    required this.members,
    required this.total,
    required this.label,
    this.onTap,
  });

  final List<MemberStripItem> members;

  /// Every member of the studio (its `memberCount`); the strip shows
  /// "+{total − shown}" when it is larger than what is drawn.
  final int total;
  final String label;
  final ValueChanged<String>? onTap;

  /// People drawn before the "+n" circle.
  static const maxShown = 4;

  /// Mock `.mems > div`: 54px wide cells, 6px apart.
  static const double _cell = 54;
  static const double _gap = 6;

  /// Mock `.mems b` and `.mems .tm`: 10.5px, the closest token is 11.
  static const double _text = AppText.xs2;

  /// Four grey cells while the members load.
  static Widget skeleton({Key? key}) => Row(
    key: key,
    children: [
      for (var i = 0; i < maxShown; i++) ...[
        if (i > 0) const SizedBox(width: _gap),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _cell),
            child: Column(
              children: [
                AppAvatar.skeleton(size: AppAvatarSize.sm),
                const SizedBox(height: AppSpace.s1),
                AppSkeleton.line(widthFactor: 0.8),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final shown = members.take(maxShown).toList();
    final more = total - shown.length;
    final cells = <Widget>[
      for (final m in shown) _Person(item: m, onTap: onTap),
      if (more > 0) _More(count: more, label: l.profileMoreMembersA11y(more)),
    ];
    return Semantics(
      role: SemanticsRole.list,
      label: label,
      explicitChildNodes: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _cell),
                child: cells[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.item, required this.onTap});

  final MemberStripItem item;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final pct = item.tomatoPct;
    final tap = onTap == null ? null : () => onTap!(item.id);
    return Semantics(
      role: SemanticsRole.listItem,
      button: tap != null,
      label: [
        item.name,
        if (pct != null) metaPartsSemantics([MetaPart.tomato(pct)], l),
      ].join(', '),
      onTap: tap,
      excludeSemantics: true,
      child: InkWell(
        key: Key('member-strip-${item.id}'),
        onTap: tap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                url: item.avatarUrl,
                name: item.name,
                size: AppAvatarSize.sm,
                decorative: true,
              ),
              const SizedBox(height: AppSpace.s1 / 2),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: MemberStrip._text,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (pct != null)
                MetaLine([
                  MetaPart.tomato(pct),
                ], style: const TextStyle(fontSize: MemberStrip._text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mock `.mems .more`: a field-coloured circle with "+n".
class _More extends StatelessWidget {
  const _More({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      role: SemanticsRole.listItem,
      label: label,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          key: const Key('member-strip-more'),
          width: AppAvatarSize.sm.dimension,
          height: AppAvatarSize.sm.dimension,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
          ),
          child: Text(
            '+$count',
            style: TextStyle(
              fontSize: AppText.xs2,
              fontWeight: FontWeight.w600,
              color: dark
                  ? AppColorsDark.foregroundSecondary
                  : AppColors.foregroundSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
