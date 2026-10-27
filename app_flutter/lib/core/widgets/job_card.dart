// lib/core/widgets/job_card.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/fit_pill.dart';
import 'package:photobooking/core/widgets/status_badge.dart';

enum JobCardVariant { customer, photographer }

enum JobCardStatusTone { waiting, accepted, denied, neutral }

@immutable
class JobCardData {
  const JobCardData({
    required this.specialtyLabel,
    required this.title,
    required this.metaLine,
    this.statusLabel,
    this.statusTone,
    this.budgetLabel,
    this.footLeft,
    this.footRight,
    this.avatarUrls = const [],
    this.invited = false,
    this.fitPercent,
    this.locked = false,
    this.lockLabel,
    this.dimmed = false,
    this.linkLabel,
    this.onLinkTap,
  });

  final String specialtyLabel;
  final String title;
  final String metaLine;
  final String? statusLabel;
  final JobCardStatusTone? statusTone;
  final String? budgetLabel;
  final String? footLeft;
  final String? footRight;
  final List<String> avatarUrls;
  final bool invited;
  final int? fitPercent;
  final bool locked;
  final String? lockLabel;
  final bool dimmed;
  final String? linkLabel;
  final VoidCallback? onLinkTap;
}

/// Card showing a job post overview (spec S15.02 customer, S16.02 photographer).
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.data,
    this.onTap,
    this.variant = JobCardVariant.customer,
  });

  final JobCardData data;
  final VoidCallback? onTap;
  final JobCardVariant variant;

  static Widget skeleton({JobCardVariant variant = JobCardVariant.customer}) =>
      _JobCardSkeleton(variant: variant);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 5),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          if (data.locked && data.lockLabel != null && variant == JobCardVariant.photographer)
            _buildLockRow(context)
          else ...[
            Text(
              data.metaLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fgSec,
              ),
            ),
            if (data.footLeft != null ||
                data.footRight != null ||
                data.budgetLabel != null ||
                data.linkLabel != null ||
                data.avatarUrls.isNotEmpty) ...[
              const SizedBox(height: 5),
              _buildFooter(context),
            ],
          ],
        ],
      ),
    );

    final card = Container(
      decoration: BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: content,
        ),
      ),
    );

    if (data.dimmed || data.locked) {
      return Opacity(
        opacity: data.locked ? 0.7 : 0.75,
        child: card,
      );
    }

    return card;
  }

  Widget _buildHeader(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tagBg = dark ? AppColorsDark.glass : AppColors.glass;
    final tagBorder = Theme.of(context).colorScheme.outlineVariant;
    final tagFg = dark ? AppColorsDark.foreground : AppColors.foreground;

    final specialtyTag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: tagBorder),
      ),
      child: Text(
        data.specialtyLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: tagFg,
        ),
      ),
    );

    if (variant == JobCardVariant.customer) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: specialtyTag),
          if (data.statusLabel != null) ...[
            const SizedBox(width: 8),
            _buildStatusBadge(context),
          ],
        ],
      );
    }

    // Photographer variant
    final invitedTag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: tagBorder),
      ),
      child: Text(
        'Bạn được mời',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: dark
              ? AppColorsDark.foregroundSecondary
              : AppColors.foregroundSecondary,
        ),
      ),
    );

    Widget? rightItem;
    if (data.locked) {
      final gold = dark ? AppColorsDark.gold : AppColors.gold;
      final border = dark ? AppColorsDark.goldLine : AppColors.goldLine;
      final bg = dark ? AppColorsDark.goldSoft : AppColors.goldSoft;
      rightItem = DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s1 * 1.5,
            AppSpace.s1 / 2,
            AppSpace.s2,
            AppSpace.s1 / 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.award,
                size: AppText.xs2,
                color: gold,
              ),
              const SizedBox(width: AppSpace.s1),
              Text(
                Theme.of(context).brightness == Brightness.dark
                    ? 'Chỉ Nhiếp ảnh gia'
                    : 'Chỉ Nhiếp ảnh gia',
                style: TextStyle(
                  fontSize: AppText.xs,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: gold,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (data.fitPercent != null) {
      rightItem = FitPill(percent: data.fitPercent!);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            specialtyTag,
            if (data.invited) ...[
              const SizedBox(width: 6),
              invitedTag,
            ],
          ],
        ),
        ?rightItem,
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final (bg, on) = switch (data.statusTone ?? JobCardStatusTone.neutral) {
      JobCardStatusTone.waiting => (
        AppColors.bookingWaiting,
        AppColors.foregroundInverse,
      ),
      JobCardStatusTone.accepted => (
        AppColors.bookingAccepted,
        AppColors.foregroundInverse,
      ),
      JobCardStatusTone.denied => (
        AppColors.bookingDenied,
        AppColors.foregroundInverse,
      ),
      JobCardStatusTone.neutral => (
        AppColors.bookingClosed,
        AppColors.foregroundInverse,
      ),
    };

    return StatusBadge.custom(
      label: data.statusLabel!,
      color: bg,
      onColor: on,
    );
  }

  Widget _buildLockRow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fgMuted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(AppIcons.lock, size: 13, color: fgMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            data.lockLabel!,
            style: TextStyle(
              fontSize: 10.5,
              color: fgMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;

    // Customer awarded or expired link
    if (variant == JobCardVariant.customer && data.linkLabel != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: data.onLinkTap,
            child: Text(
              data.linkLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ],
      );
    }

    if (variant == JobCardVariant.customer) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.avatarUrls.isNotEmpty)
                  _buildAvatarStack(),
                if (data.footLeft != null) ...[
                  if (data.avatarUrls.isNotEmpty) const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      data.footLeft!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (data.footRight != null) ...[
            const SizedBox(width: 8),
            Text(
              data.footRight!,
              style: TextStyle(
                fontSize: 12,
                color: fgSec,
              ),
            ),
          ],
        ],
      );
    }

    // Photographer variant footer: budget left in tabular bold, footRight right
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (data.budgetLabel != null)
          Flexible(
            child: Text(
              data.budgetLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        if (data.footRight != null) ...[
          const SizedBox(width: 8),
          Text(
            data.footRight!,
            style: TextStyle(
              fontSize: 12,
              color: fgSec,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < data.avatarUrls.length; i++)
            Align(
              widthFactor: i == 0 ? 1.0 : 0.75,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: AppAvatar(
                  size: AppAvatarSize.xs,
                  url: data.avatarUrls[i],
                  name: '',
                  decorative: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JobCardSkeleton extends StatelessWidget {
  const _JobCardSkeleton({required this.variant})
      : super(key: const ValueKey('job_card_skeleton'));

  final JobCardVariant variant;

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton.box(width: 50, height: 18, radius: AppRadius.full),
                AppSkeleton.box(width: 70, height: 18, radius: AppRadius.sm),
              ],
            ),
            const SizedBox(height: 8),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.85,
              child: AppSkeleton.line(height: 14),
            ),
            const SizedBox(height: 6),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.6,
              child: AppSkeleton.line(height: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton.box(width: 80, height: 12, radius: AppRadius.sm),
                AppSkeleton.box(width: 60, height: 12, radius: AppRadius.sm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
