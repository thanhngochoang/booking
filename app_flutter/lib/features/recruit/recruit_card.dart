import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_area_label.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/l10n/app_localizations.dart';

// S27 pieces the list (S27.01), the detail (S27.02) and the apply sheet
// (S27.03) share: labels, the kind and "Hợp với bạn" tags, the `.lockn`
// note and the `jcard` of the list.

/// "Cộng tác theo việc" / "Vào studio".
String recruitKindLabel(RecruitKind k, AppLocalizations l) => switch (k) {
  RecruitKind.collaborator => l.recruitKindCollaborator,
  RecruitKind.member => l.recruitKindMember,
};

/// "800.000₫/buổi" or "Thoả thuận".
String recruitFeeText(FeeHint fee, AppLocalizations l) => switch (fee) {
  PerShootFee(:final amount) => l.recruitFeePerShoot(formatMoney(amount)),
  NegotiableFee() => l.recruitFeeNegotiable,
};

/// The card's short form: "Vài buổi/tháng", "Hằng tuần", "Theo mùa".
String recruitFrequencyShort(RecruitFrequency f, AppLocalizations l) =>
    switch (f) {
      RecruitFrequency.occasional => l.recruitFrequencyOccasional,
      RecruitFrequency.weekly => l.recruitFrequencyWeekly,
      RecruitFrequency.seasonal => l.recruitFrequencySeasonal,
    };

/// The detail's long form: "Theo mùa (cưới, Tết…)".
String recruitFrequencyLong(RecruitFrequency f, AppLocalizations l) =>
    switch (f) {
      RecruitFrequency.occasional => l.recruitFrequencyOccasionalLong,
      RecruitFrequency.weekly => l.recruitFrequencyWeeklyLong,
      RecruitFrequency.seasonal => l.recruitFrequencySeasonalLong,
    };

/// Age of a post on the Vietnam calendar: "{n} giờ trước" the same day,
/// "hôm qua", "{n} ngày trước" within a week, then "{n} tuần trước".
String recruitAgo(AppLocalizations l, DateTime at, DateTime now) {
  final days = vnDaysBetween(at, now);
  if (days <= 0) return studioAgo(l, at, now);
  if (days == 1) return l.recruitAgoYesterday;
  if (days < 7) return l.studioAgoDays(days);
  return l.recruitAgoWeeks(days ~/ 7);
}

/// Open and not past its expiry at [now]: the only posts one can apply to.
bool recruitPostIsOpen(RecruitPost p, DateTime now) =>
    p.status == RecruitPostStatus.open && now.isBefore(p.expiresAt);

/// The studio's mark next to its name: a posting studio is verified (R1),
/// the seal once its business is.
ProviderMarkKind? recruitStudioMark(RecruitPost p) => providerMarkOf(
  type: ProviderType.studio,
  verified: true,
  businessVerified: p.studioBusinessVerified,
);

Color _ink2(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColorsDark.foregroundSecondary
    : AppColors.foregroundSecondary;

Color _ink3(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColorsDark.foregroundMuted
    : AppColors.foregroundMuted;

/// Mock `.tag`: the post's kind.
class RecruitKindTag extends StatelessWidget {
  const RecruitKindTag(this.kind, {super.key});

  final RecruitKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          recruitKindLabel(kind, context.l10n),
          maxLines: 1,
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Mock `.fit`: "Hợp với bạn" on a post matching the viewer's area and
/// specialty (score 2, Decision 7).
class RecruitMatchTag extends StatelessWidget {
  const RecruitMatchTag({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondary,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s2,
        vertical: AppSpace.s1,
      ),
      child: Text(
        context.l10n.recruitMatch,
        maxLines: 1,
        style: TextStyle(
          fontSize: AppText.xs,
          fontWeight: FontWeight.w600,
          color: _ink2(context),
        ),
      ),
    ),
  );
}

/// Mock `.lockn`: a small icon and a tertiary line.
class RecruitNote extends StatelessWidget {
  const RecruitNote(this.text, {super.key, this.icon = AppIcons.lock});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = _ink3(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(
            child: AppIcon(icon, size: AppText.base2, color: muted),
          ),
        ),
        const SizedBox(width: AppSpace.s1 * 1.5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: AppText.xs2, height: 1.4, color: muted),
          ),
        ),
      ],
    );
  }
}

/// One post of S27.01 (mock `jcard`): kind tag (+ "Hợp với bạn"), title,
/// studio + seal · areas · specialties, fee and "{frequency} · {age}".
class RecruitCard extends StatelessWidget {
  const RecruitCard({
    super.key,
    required this.post,
    required this.match,
    required this.now,
    required this.onTap,
  });

  final RecruitPost post;

  /// Score 2: shows "Hợp với bạn".
  final bool match;
  final DateTime now;
  final VoidCallback onTap;

  static Widget skeleton({Key? key}) => _RecruitCardSkeleton(key: key);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink2 = _ink2(context);
    final mark = recruitStudioMark(post);
    final where = [
      if (post.areas.isNotEmpty) recruitAreasText(post.areas),
      if (post.specialties.isNotEmpty) recruitSpecialtiesText(post.specialties),
    ];
    final footer = l.recruitCardFooter(
      recruitFrequencyShort(post.frequency, l),
      recruitAgo(l, post.createdAt, now),
    );
    final fee = recruitFeeText(post.fee, l);
    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(child: RecruitKindTag(post.kind)),
                  if (match) ...[
                    const SizedBox(width: AppSpace.s2),
                    const Spacer(),
                    const RecruitMatchTag(),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: AppText.base2,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpace.s1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: post.studioName),
                    if (mark != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpace.s1),
                          child: ProviderMark(mark, size: AppText.base2),
                        ),
                      ),
                    for (final part in where) TextSpan(text: ' · $part'),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppText.sm, color: ink2),
              ),
              const SizedBox(height: AppSpace.s1),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s1,
                children: [
                  Text(
                    fee,
                    style: TextStyle(
                      fontSize: AppText.base2,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    footer,
                    style: TextStyle(
                      fontSize: AppText.xs2,
                      color: _ink3(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecruitCardSkeleton extends StatelessWidget {
  const _RecruitCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton.line(width: 110),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(width: 220),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(width: 180),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(width: 140),
          ],
        ),
      ),
    );
  }
}

/// What to say when applying (S27.03) or withdrawing (S27.02) is refused.
String recruitApplyErrorText(Object error, AppLocalizations l) {
  final e = recruitErrorOf(error);
  if (e.isContact) return l.recruitContactError;
  return switch (e.code) {
    RecruitErrorCode.rateLimited => l.recruitErrorRateLimited,
    RecruitErrorCode.limitExceeded => l.recruitErrorApplyLimit,
    RecruitErrorCode.deadlinePassed => l.recruitErrorClosed,
    RecruitErrorCode.conflict => l.recruitErrorDuplicate,
    RecruitErrorCode.notAcceptingOrders => l.recruitVerifyNote,
    RecruitErrorCode.network => l.authErrorNetwork,
    _ => l.recruitErrorGeneric,
  };
}

/// A refusal shown as its text (the confirm sheet's SnackBar prints the
/// error).
class RecruitFailure implements Exception {
  const RecruitFailure(this.text);
  final String text;

  @override
  String toString() => text;
}
