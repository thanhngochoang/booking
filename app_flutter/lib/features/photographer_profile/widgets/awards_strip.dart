// lib/features/photographer_profile/widgets/awards_strip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// How many chips the strip shows before the rest sit behind a tap.
const int awardsStripVisible = 2;

/// Approved awards on S03.01: up to two [AwardChip]s, newest first, scrolling
/// sideways; a tap opens the read-only list of every approved award.
///
/// Draws nothing while loading (non-artists), on error or with no approved
/// awards. [reserveWhileLoading] shows chip skeletons instead; set for an
/// artist, who is known to have awards.
class AwardsStrip extends ConsumerWidget {
  const AwardsStrip({
    super.key,
    required this.photographerId,
    this.reserveWhileLoading = false,
  });

  final String photographerId;
  final bool reserveWhileLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const none = SizedBox.shrink();
    return AsyncView<List<Award>>(
      value: ref.watch(approvedAwardsProvider(photographerId)),
      isEmpty: (a) => a.isEmpty,
      empty: (_) => none,
      skeleton: (_) => reserveWhileLoading ? const _StripSkeleton() : none,
      error: (_, _, _) => none,
      data: (context, awards) => _Strip(awards: _newestFirst(awards)),
    );
  }
}

List<Award> _newestFirst(List<Award> awards) {
  final sorted = [...awards]
    ..sort((a, b) {
      final byYear = b.year.compareTo(a.year);
      return byYear != 0 ? byYear : b.createdAt.compareTo(a.createdAt);
    });
  return sorted;
}

String _subtitle(AppLocalizations l, Award a) {
  final category = a.category;
  return category == null || category.isEmpty
      ? l.profileAwardSub(a.competition, a.year)
      : l.profileAwardSubCategory(a.competition, a.year, category);
}

class _Strip extends StatelessWidget {
  const _Strip({required this.awards});

  final List<Award> awards;

  Future<void> _openAll(BuildContext context) =>
      showAppSheet<void>(context, builder: (_) => _AwardsSheet(awards: awards));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final more = awards.length - awardsStripVisible;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: SingleChildScrollView(
        key: const Key('profile-awards-strip'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final a in awards.take(awardsStripVisible)) ...[
              AwardChip(
                resultLabel: awardResultTitle(l, a.result),
                subtitle: _subtitle(l, a),
                onTap: () => _openAll(context),
              ),
              const SizedBox(width: AppSpace.s2),
            ],
            if (more > 0)
              TextButton(
                key: const Key('profile-awards-more'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(AppSpace.s12, AppSpace.s12),
                ),
                onPressed: () => _openAll(context),
                child: Text(l.profileAwardsMore(awards.length)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripSkeleton extends StatelessWidget {
  const _StripSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    key: Key('profile-awards-skeleton'),
    padding: EdgeInsets.only(top: AppSpace.s3),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          AwardChip.skeleton(),
          SizedBox(width: AppSpace.s2),
          AwardChip.skeleton(),
        ],
      ),
    ),
  );
}

/// Read-only sheet with every approved award: no status badge, no editing.
class _AwardsSheet extends StatelessWidget {
  const _AwardsSheet({required this.awards});

  final List<Award> awards;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s4,
      ),
      child: Column(
        key: const Key('profile-awards-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.s2501Title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: awards.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
              itemBuilder: (_, i) => AwardRow(
                title: awardResultTitle(l, awards[i].result),
                subtitle: _subtitle(l, awards[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
