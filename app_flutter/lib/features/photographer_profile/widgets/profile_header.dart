// lib/features/photographer_profile/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

/// Top of S03: photo, avatar over it, name + check, genres · area, follow,
/// the four stats, bio, skill tags, equipment, and the owner's meter.
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
    final meta = [
      for (final id in genres.take(2)) catalog.label(SkillGroup.specialty, id),
      ?s.areaLabel,
    ].join(' · ');
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
                                child: s.verified
                                    ? VerifiedName(
                                        s.displayName,
                                        style: nameStyle,
                                      )
                                    : Text(s.displayName, style: nameStyle),
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
                  StatTile(
                    value: s.hasRating ? formatRating(s.ratingAvg) : '—',
                    label: s.reviewCount > 0
                        ? l.profileStatReviews(s.reviewCount)
                        : l.profileStatNoReviews,
                  ),
                  StatTile(
                    value: '${s.completedCount}',
                    label: l.profileStatShoots,
                  ),
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
              if (profile.intro.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s4),
                Text(profile.intro.bio, style: theme.textTheme.bodyMedium),
              ],
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
