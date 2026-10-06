// lib/features/awards/my_awards_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/features/awards/edit_award_sheet.dart';
import 'package:photobooking/features/awards/my_awards_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S25.01 "Giải thưởng của tôi" at `/me/awards`: list the awards claimed,
/// follow their review and see how many more approved awards it takes to
/// reach the Nhiếp ảnh gia (NAG) tier. The tier card follows the server live.
class MyAwardsScreen extends ConsumerWidget {
  const MyAwardsScreen({super.key});

  Future<void> _add(BuildContext context) => showEditAwardSheet(context);

  Future<void> _edit(BuildContext context, Award a) async {
    final l = context.l10n;
    if (a.status == AwardStatus.approved) {
      final go = await showConfirmSheet(
        context,
        title: l.s2501EditApprovedTitle,
        body: l.s2501EditApprovedBody,
        confirmLabel: l.s2501EditApprovedGo,
        keepLabel: l.actionCancel,
        danger: false,
      );
      if (!go || !context.mounted) {
        return;
      }
    }
    await showEditAwardSheet(context, awardId: a.id);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Award a) async {
    final l = context.l10n;
    await showConfirmSheet(
      context,
      title: l.s2501DeleteTitle,
      body: l.s2501DeleteBody,
      confirmLabel: l.s2501Delete,
      keepLabel: l.actionCancel,
      onConfirm: () async {
        try {
          await deleteMyAward(ref, a.id);
        } catch (_) {
          throw Exception(l.s2501DeleteError);
        }
      },
    );
  }

  Future<void> _info(BuildContext context) {
    final l = context.l10n;
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.s2501Tier,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  l.s2501InfoBody,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              l.s2501InfoClose,
              key: const Key('awards-info-close'),
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final awards = ref.watch(myAwardsProvider);
    final empty = awards.hasValue && awards.requireValue.isEmpty;
    return ScreenCode(
      ScreenCodes.myAwards,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/profile'),
                  ),
            title: Text(l.s2501Title),
            actions: [
              IconButton(
                key: const Key('awards-info'),
                tooltip: l.s2501Info,
                constraints: const BoxConstraints.tightFor(
                  width: AppSpace.s12,
                  height: AppSpace.s12,
                ),
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => _info(context),
              ),
            ],
          ),
          body: AsyncView<List<Award>>(
            value: awards,
            onRetry: () => ref.invalidate(myAwardsProvider),
            skeleton: (_) => const _Skeleton(),
            error: (context, _, _) => ErrorState(
              message: l.s2501LoadError,
              onRetry: () => ref.invalidate(myAwardsProvider),
            ),
            isEmpty: (list) => list.isEmpty,
            empty: (_) => EmptyState(
              title: l.s2501EmptyTitle,
              body: l.s2501EmptyBody,
              actionLabel: l.s2501Add,
              onAction: () => _add(context),
            ),
            data: (context, list) => _Body(
              awards: list,
              onEdit: (a) => _edit(context, a),
              onDelete: (a) => _delete(context, ref, a),
            ),
          ),
          bottomNavigationBar: empty || !awards.hasValue
              ? null
              : AppFooterBar(
                  child: AppButton.primary(
                    l.s2501Add,
                    key: const Key('awards-add'),
                    onPressed: () => _add(context),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      AppSkeleton.box(height: AppSpace.s16 + AppSpace.s6),
      const SizedBox(height: AppSpace.s4),
      AppSkeleton.line(widthFactor: 0.4),
      const SizedBox(height: AppSpace.s2),
      for (var i = 0; i < 3; i++) ...[
        AppSkeleton.box(height: AppSpace.s12 + AppSpace.s2),
        const SizedBox(height: AppSpace.s2),
      ],
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.awards,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Award> awards;
  final void Function(Award) onEdit;
  final void Function(Award) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final approved = awards.where((a) => a.status == AwardStatus.approved);
    final tier = ref.watch(myTierProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s1,
        AppSpace.s4,
        AppSpace.s4,
      ),
      children: [
        AsyncView<AwardTier?>(
          value: tier,
          loaderSize: LoaderSize.inline,
          skeleton: (_) => AppSkeleton.box(height: AppSpace.s16 + AppSpace.s6),
          error: (_, _, _) => const SizedBox.shrink(),
          data: (context, t) =>
              _TierCard(tier: t ?? AwardTier(approvedCount: approved.length)),
        ),
        const SizedBox(height: AppSpace.s2),
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Text(
              l.s2501Listed(awards.length),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        for (final a in awards)
          Padding(
            key: ValueKey('award-${a.id}'),
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: l.s2501Delete): () => onDelete(a),
              },
              child: AwardRow(
                title: l.s2501RowTitle(
                  awardResultTitle(l, a.result),
                  a.competition,
                  a.year,
                ),
                subtitle: _subtitle(l, a),
                status: a.status,
                onTap: () => onEdit(a),
                onLongPress: () => onDelete(a),
              ),
            ),
          ),
      ],
    );
  }

  /// The staff's note for awards that need action, else the category, else
  /// the day it was sent.
  String _subtitle(AppLocalizations l, Award a) {
    final note = a.reviewNote;
    final returned =
        a.status == AwardStatus.needsInfo ||
        a.status == AwardStatus.rejected ||
        a.status == AwardStatus.revoked;
    if (returned && note != null && note.isNotEmpty) {
      return note;
    }
    return a.category ?? l.s2501Sent(awardDayMonth(a.createdAt));
  }
}

/// The tier card: progress to NAG, or "Bạn là Nhiếp ảnh gia"; none for a
/// studio (it declares awards but has no tier).
class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});
  final AwardTier tier;

  @override
  Widget build(BuildContext context) {
    if (tier.providerType == ProviderType.studio) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final theme = Theme.of(context);
    final artist = tier.providerType == ProviderType.artist;
    final since = tier.artistSince;
    final n = tier.approvedCount;
    final left = (kAwardTierThreshold - n).clamp(0, kAwardTierThreshold);
    final sub = artist
        ? (since == null
              ? l.s2501IsArtistNoDate
              : l.s2501IsArtist(awardDate(since)))
        : l.s2501Remaining(left);
    return GlassCard(
      key: const Key('awards-tier-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ExcludeSemantics(
                  child: AwardDisc(size: AppSpace.s8 + AppSpace.s2),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.s2501Tier,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        sub,
                        key: const Key('awards-tier-sub'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!artist)
                  ExcludeSemantics(
                    child: Text(
                      '$n / $kAwardTierThreshold',
                      key: const Key('awards-tier-count'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: AppFonts.display,
                      ),
                    ),
                  ),
              ],
            ),
            if (!artist) ...[
              const SizedBox(height: AppSpace.s3),
              CapacityBar(
                used: n,
                total: kAwardTierThreshold,
                label: l.s2501Progress(n, kAwardTierThreshold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
