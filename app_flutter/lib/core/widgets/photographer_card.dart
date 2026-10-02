import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/network_photo.dart';
import 'package:photobooking/core/widgets/photo_card.dart';
import 'package:photobooking/core/widgets/reason_chips.dart';
import 'package:photobooking/core/widgets/verified_mark.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// A photographer to compare (S01 "Rảnh tuần này" long form, S04): hero photo,
/// name with the verified tick, meta, price from, why recommended, and two
/// actions. No blur: a list of these must stay cheap.
class PhotographerCard extends StatelessWidget {
  const PhotographerCard({
    super.key,
    required this.data,
    this.reasons = const [],
    this.distanceKm,
    this.availabilityLabel,
    required this.onProfile,
    this.onBook,
    this.bookLabel,
  });

  final PhotographerSummary data;
  final List<Reason> reasons;
  final double? distanceKm;

  /// Text of the green pill on the hero, for example "Rảnh 12/10".
  final String? availabilityLabel;
  final VoidCallback onProfile;
  final VoidCallback? onBook;

  /// Label of the second button; defaults to "Đặt lịch".
  final String? bookLabel;

  String _meta(BuildContext context) {
    final l = context.l10n;
    return [
      if (data.specialtyIds.isNotEmpty) specialtyLabel(data.specialtyIds.first),
      if (distanceKm != null) formatDistance(distanceKm!),
      if (data.hasRating) '★ ${formatRating(data.ratingAvg)}',
      if (data.completedCount > 0) l.photographerSessions(data.completedCount),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final stack = MediaQuery.textScalerOf(context).scale(16) > 18.4;
    final hero = data.heroUrl;
    final meta = _meta(context);
    final priceLabel = priceFromLabel(data.startingPriceVnd, l);
    final price = priceLabel == null
        ? '—'
        : formatMoney(data.startingPriceVnd!, short: true);
    final header = [
      data.displayName,
      if (data.verified) l.verifiedLabel,
      meta,
      priceLabel,
      availabilityLabel,
    ].whereType<String>().where((e) => e.isNotEmpty).join(', ');

    final profileButton = AppButton.outline(
      l.photographerCardProfile,
      key: Key('card-profile-${data.id}'),
      onPressed: onProfile,
      size: AppButtonSize.small,
      tapAlignment: Alignment.topCenter,
    );
    final bookButton = onBook == null
        ? null
        : AppButton.primary(
            bookLabel ?? l.photographerCardBook,
            key: Key('card-book-${data.id}'),
            onPressed: onBook,
            size: AppButtonSize.small,
            tapAlignment: Alignment.topCenter,
          );

    return Material(
      color: scheme.secondary,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            onTap: onProfile,
            label: header,
            child: InkWell(
              onTap: onProfile,
              excludeFromSemantics: true,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hero != null)
                            NetworkPhoto(url: hero, retry: false)
                          else
                            ColoredBox(color: scheme.secondary),
                          if (availabilityLabel != null)
                            Positioned(
                              left: AppSpace.s2h,
                              top: AppSpace.s2h,
                              child: PhotoPill(
                                label: availabilityLabel!,
                                dot: PhotoPillDot.ok,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s2h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            url: data.avatarUrl,
                            name: data.displayName,
                            size: AppAvatarSize.sm,
                            decorative: true,
                          ),
                          const SizedBox(width: AppSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                data.verified
                                    ? VerifiedName(
                                        data.displayName,
                                        style: theme.textTheme.titleMedium,
                                      )
                                    : Text(
                                        data.displayName,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                if (meta.isNotEmpty)
                                  Text(meta, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.s2),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                price,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (priceLabel != null)
                                Text(
                                  l.priceFrom,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: secondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s3,
                0,
                AppSpace.s3,
                AppSpace.s3,
              ),
              child: ReasonChips(reasons: reasons),
            ),
          Padding(
            // No bottom padding: the buttons' 48dp tap boxes (visual on top)
            // supply the mock's 10dp below the row.
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2h),
            child: stack || bookButton == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      profileButton,
                      if (bookButton != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        bookButton,
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: profileButton),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(child: bookButton),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
