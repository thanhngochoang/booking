import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/meta_line.dart';
import 'package:photobooking/core/widgets/provider_mark.dart';

/// One person in a studio list (mock `.irow2`, S26.01–S26.03): avatar, bold
/// name with an optional [mark], a [MetaLine] under it and [trailing]
/// actions (an outline "Mời", "Huỷ", a "…" menu).
///
/// A row that cannot be acted on ([enabled] false: in another studio, in the
/// cooldown) is dimmed, does not react to taps and is announced as disabled;
/// its meta line says why.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    this.avatarUrl,
    required this.name,
    this.mark,
    this.meta = const [],
    this.trailing,
    this.enabled = true,
    this.onTap,
  });

  final String? avatarUrl;
  final String name;

  /// The verified tick or studio seal after the name; null draws none.
  final ProviderMarkKind? mark;

  /// The line under the name; empty leaves it out.
  final List<MetaPart> meta;

  /// Buttons at the end, kept out of the row's own label so each keeps its
  /// name and action; at most half the row wide (pass several as a [Wrap]
  /// aligned to the end so they stack on a narrow screen).
  final Widget? trailing;
  final bool enabled;
  final VoidCallback? onTap;

  static const double _dimmed = 0.5;

  /// A grey row of the same height while a list loads.
  static Widget skeleton({Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
    child: Row(
      children: [
        AppAvatar.skeleton(size: AppAvatarSize.sm),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.line(widthFactor: 0.5),
              const SizedBox(height: AppSpace.s1),
              AppSkeleton.line(widthFactor: 0.7),
            ],
          ),
        ),
      ],
    ),
  );

  String? _markLabel(BuildContext context) {
    final l = context.l10n;
    return switch (mark) {
      null => null,
      ProviderMarkKind.verified => l.verifiedLabel,
      ProviderMarkKind.artist => l.providerArtistMark,
      ProviderMarkKind.studio => l.providerStudioMark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final tap = enabled ? onTap : null;
    final info = Semantics(
      button: onTap != null,
      // Announced only where it matters: a tappable row, or a dimmed one.
      enabled: onTap != null || !enabled ? enabled : null,
      label: [
        name,
        ?_markLabel(context),
        if (meta.isNotEmpty) metaPartsSemantics(meta, context.l10n),
      ].join(', '),
      // The InkWell's own action is excluded with its children.
      onTap: tap,
      excludeSemantics: true,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.s12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Row(
              children: [
                AppAvatar(
                  url: avatarUrl,
                  name: name,
                  size: AppAvatarSize.sm,
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
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppText.base2,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                          ),
                          if (mark case final kind?) ...[
                            const SizedBox(width: AppSpace.s1),
                            ProviderMark(kind),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.s1),
                        MetaLine(meta, maxLines: 2),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The trailing actions take at most half the row, so the name always
    // shows; several buttons come as a [Wrap] and stack when narrow.
    final row = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(child: info),
          if (trailing case final t?) ...[
            const SizedBox(width: AppSpace.s2),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: t,
            ),
          ],
        ],
      ),
    );
    return enabled ? row : Opacity(opacity: _dimmed, child: row);
  }
}
