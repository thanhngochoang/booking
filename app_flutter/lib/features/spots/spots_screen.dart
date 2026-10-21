// lib/features/spots/spots_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/spots/spots_controller.dart';

/// S29.01: Trending spots directory list, filtered by area, in season, and weekend providers.
class SpotsScreen extends ConsumerStatefulWidget {
  const SpotsScreen({super.key, this.area});

  final String? area;

  @override
  ConsumerState<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends ConsumerState<SpotsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.area != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(spotsFilterProvider.notifier).initArea(widget.area);
      });
    }
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
      ref.read(spotsPageLimitProvider.notifier).loadMore();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.home.path);
    }
  }

  void _showAreaSheet(BuildContext context, List<SpotEntry> all) {
    final l = context.l10n;
    final currentArea = ref.read(spotsFilterProvider).area;

    final areaMap = <String, String>{};
    for (final s in all) {
      if (!areaMap.containsKey(s.areaCode)) {
        areaMap[s.areaCode] = s.city;
      }
    }

    showAppSheet<void>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s2,
                ),
                child: Text(
                  l.spotsFilterArea,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  title: Text(l.spotsFilterAllAreas),
                  selected: currentArea == null,
                  trailing: currentArea == null
                      ? const AppIcon(AppIcons.check, size: 18)
                      : null,
                  onTap: () {
                    ref.read(spotsFilterProvider.notifier).setArea(null);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
              const Divider(height: 1),
              for (final entry in areaMap.entries)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(entry.value),
                    selected: currentArea == entry.key,
                    trailing: currentArea == entry.key
                        ? const AppIcon(AppIcons.check, size: 18)
                        : null,
                    onTap: () {
                      ref.read(spotsFilterProvider.notifier).setArea(entry.key);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final filter = ref.watch(spotsFilterProvider);
    final pageLimit = ref.watch(spotsPageLimitProvider);
    final directoryAsync = ref.watch(spotDirectoryProvider);
    final spotsAsync = ref.watch(filteredSpotsProvider);

    return ScreenCode(
      ScreenCodes.spots,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          leading: IconButton(
            icon: const AppIcon(AppIcons.back),
            onPressed: _back,
          ),
          title: Text(l.spotsTitle),
        ),
        body: AsyncView<List<SpotEntry>>(
          value: spotsAsync,
          error: (context, err, _) => Center(
            child: ErrorState(
              message: l.spotsLoadError,
              onRetry: () {
                ref.invalidate(spotDirectoryProvider);
              },
            ),
          ),
          data: (context, spots) {
            final allSpots = directoryAsync.value ?? const [];
            final pagedSpots = spots.take(pageLimit).toList();

            return CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                      vertical: AppSpace.s2,
                    ),
                    child: Row(
                      children: [
                        AppChip(
                          key: const Key('filter-area'),
                          label: filter.area != null
                              ? (allSpots
                                      .where((s) => s.areaCode == filter.area)
                                      .firstOrNull
                                      ?.city ??
                                  filter.area!)
                              : l.spotsFilterArea,
                          selected: filter.area != null,
                          onChanged: (_) => _showAreaSheet(context, allSpots),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        AppChip(
                          key: const Key('filter-in-season'),
                          label: l.spotsFilterInSeason,
                          selected: filter.inSeason,
                          onChanged: (_) => ref
                              .read(spotsFilterProvider.notifier)
                              .toggleInSeason(),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        AppChip(
                          key: const Key('filter-weekend'),
                          label: l.spotsFilterWeekend,
                          selected: filter.weekendOnly,
                          onChanged: (_) => ref
                              .read(spotsFilterProvider.notifier)
                              .toggleWeekendOnly(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (spots.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4,
                        AppSpace.s2,
                        AppSpace.s4,
                        AppSpace.s3,
                      ),
                      child: Text(
                        filter.inSeason
                            ? l.spotsInSeasonCount(spots.length)
                            : '${spots.length} điểm chụp',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? AppColorsDark.foregroundMuted
                              : AppColors.foregroundMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (spots.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s6),
                        child: Text(
                          l.spotsEmpty,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? AppColorsDark.foregroundMuted
                                : AppColors.foregroundMuted,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final spot = pagedSpots[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.s3),
                            child: SpotCard(
                              key: Key('spot-card-${spot.spotId}'),
                              entry: spot,
                              variant: SpotCardVariant.large,
                              onTap: () => context.push('/spots/${spot.spotId}'),
                            ),
                          );
                        },
                        childCount: pagedSpots.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpace.s6),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
