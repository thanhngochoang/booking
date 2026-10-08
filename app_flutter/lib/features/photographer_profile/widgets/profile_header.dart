// lib/features/photographer_profile/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/features/photographer_profile/widgets/awards_strip.dart';

/// Top of S03.01: photo, avatar over it, name + check, genres · area, follow,
/// the four stats, bio, skill tags, equipment, and the owner's meter. A
/// visitor of a provider not accepting orders (S03.01-new) also sees the
/// dashed "Chưa nhận đơn" tag under the name and a note after the stats.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.profile, required this.owner});

  final PhotographerProfile profile;
  final bool owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = profile.summary;
    final skills =
        ref.watch(photographerSkillsProvider(s.id)).value ??
        PhotographerSkills.empty;
    final skillsScore = ref
        .watch(photographerSkillsSnapshotProvider(s.id))
        .value
        ?.server
        .completeness;
    final catalog = ref.watch(skillCatalogProvider);
    final genres = skills.specialtyIds.isNotEmpty
        ? skills.specialtyIds
        : s.specialtyIds;
    final studio = s.providerType == ProviderType.studio;
    final artist = s.providerType == ProviderType.artist;
    final closed = !owner && !s.acceptingOrders;
    final meta = [
      for (final id in genres.take(2)) catalog.label(SkillGroup.specialty, id),
      ?(studio ? (s.studioDistrict ?? s.areaLabel) : s.areaLabel),
    ].join(' · ');
    final mark = providerMarkOf(type: s.providerType, verified: s.verified);
    final nameStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
    );
    final cover = s.heroUrl;
    final years = skills.yearsExperience;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final coverHeight = box.maxWidth * 3 / 4;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: coverHeight,
                  child: cover == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: ctaGradientFor(theme.brightness),
                          ),
                        )
                      : NetworkPhoto(url: cover),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: coverHeight - 28,
                    left: AppSpace.s4,
                    right: AppSpace.s4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppAvatar(
                        url: s.avatarUrl,
                        name: s.displayName,
                        size: AppAvatarSize.lg,
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: ProviderName(
                                  s.displayName,
                                  mark: mark,
                                  style: nameStyle,
                                ),
                              ),
                              if (s.providerType != ProviderType.individual)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpace.s1,
                                  ),
                                  child: ProviderTag(
                                    key: const Key('profile-provider-tag'),
                                    type: s.providerType,
                                    showAwards: false,
                                  ),
                                ),
                              if (closed)
                                const Padding(
                                  padding: EdgeInsets.only(top: AppSpace.s1),
                                  child: OrdersClosedTag(
                                    key: Key('profile-orders-closed-tag'),
                                  ),
                                ),
                              if (meta.isNotEmpty)
                                Text(meta, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      if (!owner)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s1),
                          child: _FollowButton(photographerId: s.id),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.s4),
              StatTileRow(
                tiles: [
                  // Mock S03.01: "97%" with the tomato icon; under five reviews
                  // "Mới" (S03.01-new), always with the review count.
                  StatTile(
                    key: const Key('profile-stat-reviews'),
                    value: s.hasTomatoPct
                        ? formatTomatoPct(s.tomatoPct)
                        : l.profileStatNew,
                    valueLeading: s.hasTomatoPct
                        ? const VerdictIcon(VerdictKind.tomato, size: 18)
                        : null,
                    semanticsValue: s.hasTomatoPct
                        ? l.tomatoPctA11y(s.tomatoPct)
                        : null,
                    label: l.profileStatReviews(s.reviewCount),
                  ),
                  if (artist)
                    StatTile(
                      value: '${s.approvedAwardCount}',
                      label: l.profileStatAwards,
                    ),
                  StatTile(
                    value: '${s.completedCount}',
                    label: l.profileStatShoots,
                  ),
                  if (!artist)
                    StatTile(
                      value: s.responseMinutes == null
                          ? '—'
                          : responseLabel(s.responseMinutes!, l),
                      label: l.profileStatResponse,
                    ),
                  StatTile(
                    value: years == null ? '—' : l.profileYearsValue(years),
                    label: l.profileStatYears,
                  ),
                ],
              ),
              if (closed) _OrdersClosedNote(name: s.displayName),
              if (artist)
                AwardsStrip(photographerId: s.id, reserveWhileLoading: true),
              if (profile.intro.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s4),
                Text(profile.intro.bio, style: theme.textTheme.bodyMedium),
              ],
              _BadgesRow(uid: s.id),
              if (!artist) AwardsStrip(photographerId: s.id),
              if (skills.specialties.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s3),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    for (final sk in skills.specialties)
                      _Tag(
                        '${catalog.label(SkillGroup.specialty, sk.id)} · ${skillLevelLabel(sk.level, l)}',
                      ),
                  ],
                ),
              ],
              if (profile.intro.equipment.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s2),
                Text(
                  l.profileEquipment(profile.intro.equipment.join(', ')),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (owner) ...[
                const SizedBox(height: AppSpace.s4),
                CompletenessMeter(percent: skillsScore),
              ],
              const SizedBox(height: AppSpace.s4),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mock `.lockn`: an info icon and why booking is closed, in tertiary ink.
class _OrdersClosedNote extends StatelessWidget {
  const _OrdersClosedNote({required this.name});

  final String name;

  /// Mock `.lockn` text size, as [StatTile]'s label.
  static const _textSize = 10.5;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: Row(
        key: const Key('profile-orders-closed-note'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.info, size: AppText.base2, color: muted),
          const SizedBox(width: AppSpace.s1 * 1.5),
          Expanded(
            child: Text(
              context.l10n.profileOrdersClosedNote(name),
              style: TextStyle(fontSize: _textSize, height: 1.4, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to three earned badges after the bio; hidden while loading, on error
/// and when none are earned. "Tất cả" opens S03.02.
class _BadgesRow extends ConsumerWidget {
  const _BadgesRow({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeChipsProvider(uid)).value;
    if (badges == null || badges.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: BadgeRow(
        key: const Key('profile-badges'),
        badges: badges,
        max: 3,
        alwaysShowSeeAll: true,
        onSeeAll: () => context.push('/u/$uid/badges'),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s1,
        ),
        child: Text(text, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.photographerId});
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final following = ref.watch(followProvider)[photographerId] ?? false;
    return AppButton.outline(
      following ? l.profileFollowing : l.profileFollow,
      key: const Key('profile-follow'),
      size: AppButtonSize.xsmall,
      onPressed: () async {
        final ok = await ref
            .read(followProvider.notifier)
            .toggle(photographerId);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l.engagementError)));
        }
      },
    );
  }
}
