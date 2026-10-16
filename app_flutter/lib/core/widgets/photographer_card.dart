import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/review_meta.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/meta_line.dart';
import 'package:photobooking/core/widgets/network_photo.dart';
import 'package:photobooking/core/widgets/photo_card.dart';
import 'package:photobooking/core/widgets/provider_mark.dart';
import 'package:photobooking/core/widgets/reason_chips.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// A photographer to compare (S02.01 "Rảnh tuần này" long form, S02.06): hero photo,
/// name with the verified tick, meta, price from, why recommended, and two
/// actions. No blur: a list of these must stay cheap.
class PhotographerCard extends StatelessWidget {
  static Widget skeleton({Key? key}) => _PhotographerCardSkeleton(key: key);

  const PhotographerCard({
    super.key,
    required this.data,
    this.reasons = const [],
    this.distanceKm,
    this.availabilityLabel,
    required this.onProfile,
    this.onBook,
    this.bookLabel,
    this.saved,
    this.onToggleSave,
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

  /// Whether the photographer is saved by the viewer (S19).
  final bool? saved;

  /// Callback to toggle the saved state. When non-null, a bookmark overlay is shown.
  final VoidCallback? onToggleSave;

  /// "Chân dung · 1,2 km · 🍅 97% · 112 buổi" (mock S02.06); "Mới · 3 đánh giá"
  /// under five reviews and no review part without any.
  List<MetaPart> _meta(BuildContext context) {
    final l = context.l10n;
    final review = reviewMetaPart(data, l);
    return [
      if (data.specialtyIds.isNotEmpty)
        MetaPart.text(specialtyLabel(data.specialtyIds.first)),
      if (distanceKm != null) MetaPart.text(formatDistance(distanceKm!)),
      ?review,
      if (data.completedCount > 0)
        MetaPart.text(l.photographerSessions(data.completedCount)),
    ];
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
    final metaText = metaPartsSemantics(meta, l);
    final priceLabel = priceFromLabel(data.startingPriceVnd, l);
    final price = priceLabel == null
        ? '—'
        : formatMoney(data.startingPriceVnd!, short: true);
    final mark = providerMarkOf(
      type: data.providerType,
      verified: data.verified,
      businessVerified: data.businessVerified,
    );
    final awards = data.providerType == ProviderType.artist
        ? data.approvedAwardCount
        : 0;
    final studio = data.providerType == ProviderType.studio;
    final district = data.studioDistrict ?? '';
    final header = [
      data.displayName,
      switch (mark) {
        ProviderMarkKind.verified => l.verifiedLabel,
        ProviderMarkKind.artist => l.providerArtistMark,
        ProviderMarkKind.studio => l.providerStudioMark,
        null => null,
      },
      if (awards > 0) l.providerAwardsCount(awards),
      // The studio seal already says Studio; without it (unverified, or only
      // the blue tick) the tag text (Studio, or Studio · district) is read.
      if (studio && mark == ProviderMarkKind.studio && district.isNotEmpty)
        district,
      if (studio && mark != ProviderMarkKind.studio)
        district.isEmpty
            ? l.providerStudio
            : l.providerStudioDistrict(district),
      metaText,
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

    final glass = Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.glass
        : AppColors.glass;
    return Material(
      color: glass,
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
                          if (onToggleSave != null)
                            Positioned(
                              right: AppSpace.s2,
                              top: AppSpace.s2,
                              child: Semantics(
                                button: true,
                                label: (saved ?? false)
                                    ? l.savedToggleOff(data.displayName)
                                    : l.savedToggleOn(data.displayName),
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: AppColors.overlay,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    key: Key('card-save-${data.id}'),
                                    tooltip: (saved ?? false)
                                        ? l.savedToggleOff(data.displayName)
                                        : l.savedToggleOn(data.displayName),
                                    icon: AppIcon(
                                      AppIcons.save,
                                      selected: saved ?? false,
                                      color: Colors.white,
                                    ),
                                    onPressed: onToggleSave,
                                  ),
                                ),
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
                                ProviderName(
                                  data.displayName,
                                  mark: mark,
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (data.providerType !=
                                    ProviderType.individual)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: ProviderTag(
                                        type: data.providerType,
                                        awards: data.approvedAwardCount,
                                        district: data.studioDistrict,
                                      ),
                                    ),
                                  ),
                                if (meta.isNotEmpty)
                                  MetaLine(
                                    meta,
                                    style: theme.textTheme.bodySmall,
                                  ),
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
                      // The 48dp tap boxes (visual on top) already leave the
                      // mock's gap between the two visuals.
                      profileButton,
                      ?bookButton,
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

class _PhotographerCardSkeleton extends StatelessWidget {
  const _PhotographerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.glass
        : AppColors.glass;
    return Material(
      color: glass,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AppSkeleton.box(
              width: double.infinity,
              height: double.infinity,
              radius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s2h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar.skeleton(size: AppAvatarSize.sm),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppSkeleton.line(height: 16, width: 140),
                        AppSkeleton.line(height: 12, width: 100),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                SizedBox(
                  height: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppSkeleton.line(height: 16, width: 48),
                      AppSkeleton.line(height: 10, width: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2h),
            child: SizedBox(
              height: AppSpace.s12,
              child: Align(
                alignment: Alignment.topCenter,
                child: AppSkeleton.box(height: 38, radius: AppRadius.control),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
