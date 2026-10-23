// lib/core/widgets/quote_card.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/deliverable_chips.dart';
import 'package:photobooking/core/widgets/fit_pill.dart';
import 'package:photobooking/core/widgets/meta_line.dart';
import 'package:photobooking/core/widgets/provider_mark.dart';

@immutable
class QuoteCardData {
  const QuoteCardData({
    required this.name,
    this.avatarUrl,
    this.mark,
    this.invited = false,
    this.trustParts = const [],
    required this.priceLabel,
    this.budgetNote,
    this.budgetOver = false,
    this.deliverables = const [],
    this.messageFirstLine,
    this.fitPercent,
    this.saved = false,
    this.withdrawn = false,
  });

  final String name;
  final String? avatarUrl;
  final ProviderMarkKind? mark;
  final bool invited;
  final List<MetaPart> trustParts;
  final String priceLabel;
  final String? budgetNote;
  final bool budgetOver;
  final List<DeliverableItem> deliverables;
  final String? messageFirstLine;
  final int? fitPercent;
  final bool saved;
  final bool withdrawn;
}

/// Card showing a quote in S15.03 (#S15.03 .qcard).
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.data,
    this.onView,
    this.onToggleSave,
  });

  final QuoteCardData data;
  final VoidCallback? onView;
  final VoidCallback? onToggleSave;

  static Widget skeleton() => const _QuoteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;
        final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopRow(context),
          if (data.deliverables.isNotEmpty) ...[
            const SizedBox(height: 7),
            DeliverableChips(items: data.deliverables),
          ],
          if (data.messageFirstLine != null && data.messageFirstLine!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${data.messageFirstLine!}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fgSec,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          _buildBottomRow(context),
        ],
      ),
    );

    final card = Container(
      decoration: BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: outline),
      ),
      child: content,
    );

    if (data.withdrawn) {
      return Opacity(
        opacity: 0.6,
        child: card,
      );
    }

    return card;
  }

  Widget _buildTopRow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final l = context.l10n;

    final okColor = dark ? AppColorsDark.freeInk : AppColors.freeInk;
    final warnColor = dark ? AppColorsDark.warning : AppColors.warning;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          url: data.avatarUrl,
          name: data.name,
          size: AppAvatarSize.sm,
          decorative: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Semantics(
                      label: data.name,
                      child: ProviderName(
                        data.name,
                      mark: data.mark,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  if (data.invited) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        l.quoteInvited,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: dark
                              ? AppColorsDark.foregroundSecondary
                              : AppColors.foregroundSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (data.trustParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                MetaLine(data.trustParts),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.priceLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (data.budgetNote != null)
              Text(
                data.budgetNote!,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: data.budgetOver ? warnColor : okColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    if (data.withdrawn) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              l.quoteWithdrawnTag,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: fgSec,
              ),
            ),
          ),
          if (data.fitPercent != null) FitPill(percent: data.fitPercent!),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (data.fitPercent != null)
          FitPill(percent: data.fitPercent!)
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: data.saved ? l.quoteUnbookmark : l.quoteBookmark,
              child: IconButton(
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: AppIcon(
                  AppIcons.save,
                  selected: data.saved,
                  color: fgSec,
                ),
                tooltip: data.saved ? l.quoteUnbookmark : l.quoteBookmark,
                onPressed: onToggleSave,
              ),
            ),
            const SizedBox(width: 4),
            AppButton.outline(
              l.quoteView,
              size: AppButtonSize.xsmall,
              onPressed: onView ?? () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _QuoteCardSkeleton extends StatelessWidget {
  const _QuoteCardSkeleton() : super(key: const ValueKey('quote_card_skeleton'));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton.circle(size: 40),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSkeleton.line(height: 14),
                      const SizedBox(height: 4),
                      AppSkeleton.line(height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppSkeleton.box(width: 50, height: 16, radius: AppRadius.sm),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AppSkeleton.box(width: 60, height: 18, radius: AppRadius.full),
                const SizedBox(width: 4),
                AppSkeleton.box(width: 60, height: 18, radius: AppRadius.full),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton.box(width: 50, height: 18, radius: AppRadius.full),
                AppSkeleton.box(width: 45, height: 24, radius: AppRadius.sm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
