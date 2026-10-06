import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Huy chương Vàng" style title of [r], for chips and rows.
String awardResultTitle(AppLocalizations l, AwardResult r) => switch (r) {
  AwardResult.gold => l.awardResultGold,
  AwardResult.silver => l.awardResultSilver,
  AwardResult.bronze => l.awardResultBronze,
  AwardResult.honorable => l.awardResultHonorable,
  AwardResult.finalist => l.awardResultFinalist,
  AwardResult.exhibited => l.awardResultExhibited,
};

/// Short label of [r] for the picker ("Vàng / Nhất").
String awardResultShortLabel(AppLocalizations l, AwardResult r) => switch (r) {
  AwardResult.gold => l.awardShortGold,
  AwardResult.silver => l.awardShortSilver,
  AwardResult.bronze => l.awardShortBronze,
  AwardResult.honorable => l.awardShortHonorable,
  AwardResult.finalist => l.awardShortFinalist,
  AwardResult.exhibited => l.awardShortExhibited,
};

/// Review-state text of [s] ("Chờ duyệt"); status is always shown as text.
String awardStatusLabel(AppLocalizations l, AwardStatus s) => switch (s) {
  AwardStatus.pending => l.awardPending,
  AwardStatus.approved => l.awardApproved,
  AwardStatus.needsInfo => l.awardNeedsInfo,
  AwardStatus.rejected => l.awardRejected,
  AwardStatus.revoked => l.awardRevoked,
};

const _goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.goldGradStart, AppColors.goldGradEnd],
);

/// Round award disc: gold gradient with a dark medal icon, or grey (mute).
class AwardDisc extends StatelessWidget {
  const AwardDisc({super.key, this.gold = true, this.size = 30});

  final bool gold;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: ValueKey(gold ? 'award_disc_gold' : 'award_disc_mute'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gold ? _goldGradient : null,
        color: gold
            ? null
            : (dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.workspace_premium,
          size: 16,
          color: gold
              ? AppColors.goldInk
              : (dark
                    ? AppColorsDark.foregroundMuted
                    : AppColors.foregroundMuted),
        ),
      ),
    );
  }
}

/// Profile award chip (S03.01): 178dp, soft gold fill and line, gold disc,
/// bold result and one line "competition year · category".
class AwardChip extends StatelessWidget {
  const AwardChip({
    super.key,
    required this.resultLabel,
    required this.subtitle,
    this.onTap,
  }) : _skeleton = false;

  const AwardChip.skeleton({super.key})
    : resultLabel = '',
      subtitle = '',
      onTap = null,
      _skeleton = true;

  static const double width = 178;

  /// Height of the two text lines; the skeleton reserves the same.
  static const double _textHeight = 31;

  final String resultLabel;
  final String subtitle;
  final VoidCallback? onTap;
  final bool _skeleton;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(AppRadius.md);
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s2,
      ),
      child: Row(
        children: [
          _skeleton ? AppSkeleton.circle(size: 30) : const AwardDisc(),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: _skeleton
                ? SizedBox(
                    height: _textHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton.line(widthFactor: 0.8, height: 12),
                        const SizedBox(height: AppSpace.s1),
                        AppSkeleton.line(widthFactor: 0.6, height: 10),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resultLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.sm,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: fg,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppText.xs2, color: fgSec),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    final box = SizedBox(
      key: const ValueKey('award_chip_box'),
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.goldSoft : AppColors.goldSoft,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColorsDark.goldLine : AppColors.goldLine,
          ),
        ),
        child: _skeleton
            ? body
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: radius,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: onTap == null ? 0 : 48,
                    ),
                    child: body,
                  ),
                ),
              ),
      ),
    );
    if (_skeleton) {
      return box;
    }
    return Semantics(
      label: context.l10n.awardChipSemantics(resultLabel, subtitle),
      button: onTap != null,
      excludeSemantics: true,
      child: box,
    );
  }
}
