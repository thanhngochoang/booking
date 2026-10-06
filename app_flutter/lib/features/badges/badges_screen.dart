// lib/features/badges/badges_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/badges/badges_analytics.dart';
import 'package:photobooking/features/badges/badges_view.dart';

/// S03.02 "Huy hiệu" at `/u/:uid/badges`: badges grouped by source. The own
/// view also shows locked badges with progress; other people's views show
/// earned badges only.
class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  /// Read once per visit so the "Mới" dots stay while the screen is open.
  DateTime? _seenAt;
  var _marked = false;
  var _opened = false;

  @override
  void initState() {
    super.initState();
    _seenAt = ref.read(badgesSeenStoreProvider).seenAt(widget.uid);
  }

  AsyncValue<BadgesView?> _view(bool own) {
    final catalog = ref.watch(badgeCatalogProvider);
    final earned = ref.watch(earnedBadgesProvider(widget.uid));
    final progress = own ? ref.watch(myBadgeProgressProvider) : null;
    final profile = own ? ref.watch(currentProfileProvider) : null;
    for (final v in [catalog, earned]) {
      if (v.hasError) {
        return AsyncError(v.error!, v.stackTrace!);
      }
    }
    final defs = catalog.value;
    final mine = earned.value;
    if (defs == null || mine == null || (own && profile?.value == null)) {
      return const AsyncLoading();
    }
    if (own && progress != null && !progress.hasValue && !progress.hasError) {
      return const AsyncLoading();
    }
    return AsyncData(
      buildBadgesView(
        catalog: defs,
        earned: mine,
        progress: own ? progress?.value : null,
        own: own,
        photographer: profile?.value?.role == UserRole.photographer,
        seenAt: _seenAt,
      ),
    );
  }

  void _afterData(bool own) {
    if (!_opened) {
      _opened = true;
      ref.read(badgesAnalyticsProvider)('badges_open', {'own': own});
    }
    if (own && !_marked) {
      _marked = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(badgesSeenStoreProvider)
            .markSeen(widget.uid, ref.read(clockProvider)());
      });
    }
  }

  Future<void> _detail(BadgeTileVm t) {
    ref.read(badgesAnalyticsProvider)('badge_detail', {
      'badgeId': t.badge.code,
    });
    final l = context.l10n;
    final at = t.awardedAt;
    final line = at != null
        ? l.badgesAwardedOn(_date(at.toLocal()))
        : t.progress != null
        ? l.badgesSheetProgress(t.progress!.current, t.progress!.total)
        : l.badgeNotEarned;
    return showAppSheet<void>(
      context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s5,
          ),
          child: Column(
            key: const Key('badge-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(t.badge.name, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(t.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpace.s3),
              Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (t.progress != null && at == null) ...[
                const SizedBox(height: AppSpace.s2),
                CapacityBar(
                  used: t.progress!.current,
                  total: t.progress!.total,
                  label: l.badgesSheetProgress(
                    t.progress!.current,
                    t.progress!.total,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = ref.watch(authStateProvider);
    final myUid = auth.value?.uid;
    final own = myUid != null && myUid == widget.uid;
    final value = auth.isLoading
        ? const AsyncLoading<BadgesView?>()
        : _view(own);
    final data = value.value;
    if (data != null) {
      _afterData(own);
    }
    void retry() {
      ref
        ..invalidate(badgeCatalogProvider)
        ..invalidate(earnedBadgesProvider(widget.uid));
    }

    return ScreenCode(
      ScreenCodes.badges,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const AppIcon(AppIcons.back),
                    onPressed: () =>
                        context.go(own ? '/profile' : '/u/${widget.uid}'),
                  ),
            title: Text(l.badgesTitle),
            actions: [
              if (own && data != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s4),
                  child: Center(
                    child: Text(
                      l.badgesFraction(data.earned, data.shown),
                      key: const Key('badges-meta'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
            ],
          ),
          body: AsyncView<BadgesView?>(
            value: value,
            onRetry: retry,
            skeleton: (_) => const _Skeleton(),
            error: (context, _, _) =>
                ErrorState(message: l.badgesLoadError, onRetry: retry),
            isEmpty: (v) => v == null || v.isEmpty,
            empty: (_) =>
                EmptyState(title: l.badgesEmptyTitle, body: l.badgesEmptyBody),
            data: (context, v) => _Body(view: v!, own: own, onTap: _detail),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.view, required this.own, required this.onTap});

  final BadgesView view;
  final bool own;
  final Future<void> Function(BadgeTileVm) onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final nearest = view.nearest;
    final tileHeight = MediaQuery.textScalerOf(context).scale(172);
    Widget grid(List<BadgeTileVm> tiles) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpace.s3,
          crossAxisSpacing: AppSpace.s3,
          mainAxisExtent: tileHeight,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final t = tiles[i];
          return BadgeTile(
            badge: t.badge,
            progress: t.progress,
            isNew: t.isNew,
            onTap: () => onTap(t),
          );
        }, childCount: tiles.length),
      ),
    );

    Widget header(String title, int earned, int shown) => SliverToBoxAdapter(
      child: Semantics(
        header: true,
        label: own ? l.badgesSectionSemantics(title, earned, shown) : title,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s4,
            AppSpace.s4,
            AppSpace.s2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (own)
                Text(
                  l.badgesFraction(earned, shown),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );

    return CustomScrollView(
      slivers: [
        if (nearest != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                highlight: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Text(
                    key: const Key('badges-nearest'),
                    l.badgesNearest(
                      nearest.badge.name,
                      nearest.progress!.current,
                      nearest.progress!.total,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
          ),
        if (view.fromReviews.isNotEmpty) ...[
          header(l.badgesFromReviews, view.reviewsEarned, view.reviewsShown),
          grid(view.fromReviews),
        ],
        if (view.fromSystem.isNotEmpty) ...[
          header(l.badgesFromSystem, view.systemEarned, view.systemShown),
          grid(view.fromSystem),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s6)),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget section(String title) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpace.s3,
            crossAxisSpacing: AppSpace.s3,
            mainAxisExtent: 110,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < 4; i++) BadgeTile.skeleton()],
        ),
      ],
    );
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        children: [section(l.badgesFromReviews), section(l.badgesFromSystem)],
      ),
    );
  }
}
