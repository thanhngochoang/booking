// lib/features/explore/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/event_routes.dart';
import 'package:photobooking/features/explore/explore_links.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/nearby_events.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

enum ExploreCategoryTab { services, places, styles, photographers }

/// S13 (no location chosen) and S35 (location or area chosen): one screen,
/// two layouts.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with WidgetsBindingObserver {
  ExploreCategoryTab _tab = ExploreCategoryTab.services;

  /// Keeps the scroll position when the skeleton scope appears or goes.
  final _scrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the Settings app: pick up a permission change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only the active tab refreshes (the other branches stay mounted).
    if (state == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled) {
      ref.read(locationControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final resolution = ref.watch(exploreResolutionProvider);
    final nearby = resolution.mode == ExploreMode.nearby;
    final isCustomer =
        ref.watch(currentProfileProvider).value?.role == UserRole.customer;
    final controller = ref.read(locationControllerProvider.notifier);
    final resolving =
        resolution.mode == ExploreMode.loading ||
        resolution.mode == ExploreMode.locating;
    // No fetch (and no header flicker) while the location is still unknown.
    final eventsLoading =
        resolving ||
        (nearby
            ? ref.watch(nearbyEventsProvider).isLoading
            : ref.watch(upcomingEventsProvider).isLoading);

    final category = _CategorySection(
      tab: _tab,
      onTab: (t) => setState(() => _tab = t),
      tappable: isCustomer,
    );
    final events = _EventsSection(nearby: nearby, resolving: resolving);

    final scroll = CustomScrollView(
      key: _scrollKey,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            AppSpace.s6,
          ),
          sliver: SliverMainAxisGroup(
            slivers: nearby
                ? [
                    ..._locationSlivers(context, resolution),
                    events.build(context, ref),
                    category.build(context, ref),
                  ]
                : [
                    // S13: the four entry points first, then the location
                    // card or chip, then the events.
                    category.build(context, ref),
                    ..._locationSlivers(context, resolution),
                    events.build(context, ref),
                  ],
          ),
        ),
      ],
    );

    return ScreenCode(
      nearby ? ScreenCodes.exploreNearby : ScreenCodes.exploreNoLocation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          title: Text(l.tabExplore),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshLocation();
            ref.invalidate(nearbyEventsProvider);
            ref.invalidate(upcomingEventsProvider);
          },
          // One pulse for every skeleton on the screen.
          child: eventsLoading ? AppSkeletonScope(child: scroll) : scroll,
        ),
      ),
    );
  }

  List<Widget> _locationSlivers(
    BuildContext context,
    ExploreResolution resolution,
  ) {
    final l = context.l10n;
    final controller = ref.read(locationControllerProvider.notifier);
    switch (resolution.mode) {
      case ExploreMode.loading:
      case ExploreMode.locating:
        return const [
          SliverToBoxAdapter(child: AppSkeleton.box(height: 120)),
          _Gap(AppSpace.s5),
        ];
      case ExploreMode.ask:
      case ExploreMode.requesting:
      case ExploreMode.chooseArea:
        return [
          SliverToBoxAdapter(
            child: LocationPromptCard(
              state: switch (resolution.mode) {
                ExploreMode.ask => LocationPromptState.ask,
                ExploreMode.requesting => LocationPromptState.requesting,
                _ => LocationPromptState.denied,
              },
              onAllow: controller.allow,
              onLater: controller.later,
              onChooseArea: () => showAreaPicker(context),
            ),
          ),
          const _Gap(AppSpace.s5),
        ];
      case ExploreMode.nearby:
        final origin = resolution.origin!;
        final filters = ref.watch(nearbyFiltersProvider);
        final filterController = ref.read(nearbyFiltersProvider.notifier);
        return [
          SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  key: const Key('explore-pin'),
                  size: 15,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    origin.fromDevice
                        ? l.exploreAroundMe
                        : l.exploreAround(origin.areaName ?? ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const Key('explore-change'),
                  onPressed: () => showAreaPicker(context),
                  child: Text(l.exploreChange),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final km in kRadiusOptionsKm) ...[
                    AppChip(
                      key: Key('filter-radius-${km.round()}'),
                      label: l.exploreRadius(km.round()),
                      selected: filters.radiusKm == km,
                      onChanged: (_) => filterController.setRadius(km),
                    ),
                    const SizedBox(width: AppSpace.s2),
                  ],
                  AppChip(
                    key: const Key('filter-this-week'),
                    kind: AppChipKind.context,
                    label: l.exploreThisWeek,
                    selected: filters.thisWeek,
                    onChanged: (_) => filterController.toggleThisWeek(),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  AppChip(
                    key: const Key('filter-weekend'),
                    kind: AppChipKind.context,
                    label: l.exploreWeekend,
                    selected: filters.weekend,
                    onChanged: (_) => filterController.toggleWeekend(),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  AppChip(
                    key: const Key('filter-free'),
                    kind: AppChipKind.context,
                    label: l.freeTag,
                    selected: filters.freeOnly,
                    onChanged: (_) => filterController.toggleFree(),
                  ),
                ],
              ),
            ),
          ),
          const _Gap(AppSpace.s4),
        ];
    }
  }
}

class _Gap extends StatelessWidget {
  const _Gap(this.height);
  final double height;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: SizedBox(height: height));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mock `.sec`: serif 17 title, accent 12px link, baseline aligned.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
            ),
          ),
        ),
        if (onSeeAll != null)
          _SeeAllLink(key: const Key('explore-see-all'), onTap: onSeeAll!),
      ],
    );
  }
}

/// Accent "Xem tất cả" text link with a 48dp touch target.
class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
      ),
      child: Text(
        context.l10n.exploreSeeAll,
        style: TextStyle(
          fontSize: AppText.sm,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _EventsSection {
  const _EventsSection({required this.nearby, required this.resolving});
  final bool nearby;
  final bool resolving;

  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final routesReady = ref.watch(eventRoutesReadyProvider);

    VoidCallback? tapFor(EventSummary e) =>
        routesReady ? () => context.push(eventPath(e.id)) : null;

    Widget tile(EventSummary e, [double? km]) => NearbyEventTile(
      key: Key('event-tile-${e.id}'),
      event: e,
      distanceLabel: km == null ? null : formatDistance(km),
      onTap: tapFor(e),
    );

    final title = nearby ? l.exploreNearbyTitle : l.exploreEventsTitle;
    final header = SliverToBoxAdapter(
      child: _SectionTitle(
        title,
        onSeeAll: routesReady ? () => context.push(eventListPath()) : null,
      ),
    );
    const gap = _Gap(AppSpace.s3);
    const tail = _Gap(AppSpace.s5);

    Widget errorSliver(VoidCallback retry) => SliverToBoxAdapter(
      child: ErrorState(message: l.exploreLoadError, onRetry: retry),
    );

    Widget loadingSliver() => const SliverToBoxAdapter(
      child: Column(
        children: [
          AppSkeleton.card(height: 88),
          SizedBox(height: AppSpace.s3),
          AppSkeleton.card(height: 88),
        ],
      ),
    );

    if (resolving) {
      return SliverMainAxisGroup(slivers: [header, gap, loadingSliver(), tail]);
    }
    if (nearby) {
      final async = ref.watch(nearbyEventsProvider);
      return SliverMainAxisGroup(
        slivers: [
          header,
          gap,
          ...async.when(
            loading: () => [loadingSliver()],
            error: (_, _) => [
              errorSliver(() => ref.invalidate(nearbyEventsProvider)),
            ],
            data: (items) {
              if (items.isEmpty) {
                return [
                  _EmptyNearby(
                    onWiden: () =>
                        ref.read(nearbyFiltersProvider.notifier).widen(),
                  ),
                ];
              }
              return [
                SliverAdaptiveRows(
                  itemCount: items.length,
                  itemBuilder: (_, i) =>
                      tile(items[i].event, items[i].distanceKm),
                ),
              ];
            },
          ),
          tail,
        ],
      );
    }

    final async = ref.watch(upcomingEventsProvider);
    return async.when(
      loading: () =>
          SliverMainAxisGroup(slivers: [header, gap, loadingSliver(), tail]),
      error: (_, _) => SliverMainAxisGroup(
        slivers: [
          header,
          gap,
          errorSliver(() => ref.invalidate(upcomingEventsProvider)),
          tail,
        ],
      ),
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final shown = items.take(5).toList();
        return SliverMainAxisGroup(
          slivers: [
            header,
            gap,
            SliverAdaptiveRows(
              itemCount: shown.length,
              itemBuilder: (_, i) => tile(shown[i]),
            ),
            tail,
          ],
        );
      },
    );
  }
}

class _EmptyNearby extends ConsumerWidget {
  const _EmptyNearby({required this.onWiden});
  final bool Function() onWiden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canWiden =
        ref.watch(nearbyFiltersProvider).radiusKm < kRadiusOptionsKm.last;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.exploreNoneNearby,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (canWiden) ...[
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              l.exploreWiden,
              key: const Key('explore-widen'),
              onPressed: onWiden,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategorySection {
  const _CategorySection({
    required this.tab,
    required this.onTab,
    required this.tappable,
  });

  final ExploreCategoryTab tab;
  final ValueChanged<ExploreCategoryTab> onTab;
  final bool tappable;

  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tiles = _tiles(context, ref);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SegmentedTabs<ExploreCategoryTab>(
            options: [
              SegmentOption(
                value: ExploreCategoryTab.services,
                label: l.exploreTabServices,
              ),
              SegmentOption(
                value: ExploreCategoryTab.places,
                label: l.exploreTabPlaces,
              ),
              SegmentOption(
                value: ExploreCategoryTab.styles,
                label: l.exploreTabStyles,
              ),
              SegmentOption(
                value: ExploreCategoryTab.photographers,
                label: l.exploreTabPhotographers,
              ),
            ],
            value: tab,
            onChanged: onTab,
          ),
        ),
        const _Gap(AppSpace.s3),
        SliverToBoxAdapter(
          child: _CategoryGrid(key: ValueKey(tab), tiles: tiles),
        ),
        const _Gap(AppSpace.s5),
      ],
    );
  }

  List<_CategoryTile> _tiles(BuildContext context, WidgetRef ref) {
    _CategoryTile tile(String id, String title, String path) => _CategoryTile(
      key: Key('category-${tab.name}-$id'),
      title: title,
      onTap: tappable ? () => context.go(path) : null,
    );
    switch (tab) {
      case ExploreCategoryTab.services:
        return [
          for (final o in kSpecialties)
            tile(o.id, o.labelVi, findPhotographersPath(specialty: o.id)),
        ];
      case ExploreCategoryTab.places:
        final areas = ref.watch(areasProvider).value ?? const <AreaOption>[];
        return [
          for (final a in areas)
            tile(a.id, a.name, findPhotographersPath(area: a.id)),
        ];
      case ExploreCategoryTab.styles:
        return [
          for (final o in kStyles)
            tile(o.id, o.labelVi, findPhotographersPath(style: o.id)),
        ];
      case ExploreCategoryTab.photographers:
        return [
          tile(
            'all',
            context.l10n.explorePhotographersAll,
            findPhotographersPath(),
          ),
        ];
    }
  }
}

/// Mock S13 `.grid2`: the first four entries of the tab as short 21:9
/// tiles, two per row on a phone and four from 600dp. "Xem tất cả" opens
/// the rest of the tab in place.
class _CategoryGrid extends StatefulWidget {
  const _CategoryGrid({super.key, required this.tiles});
  final List<_CategoryTile> tiles;

  static const shown = 4;

  @override
  State<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<_CategoryGrid> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final tiles = widget.tiles;
    final more = !_all && tiles.length > _CategoryGrid.shown;
    final visible = more ? tiles.take(_CategoryGrid.shown).toList() : tiles;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AppSpace.s2;
        final columns = box.maxWidth >= SliverAdaptiveRows.wideBreakpoint
            ? 4
            : 2;
        final cell = (box.maxWidth - gap * (columns - 1)) / columns;
        final rows = <Widget>[
          for (var r = 0; r * columns < visible.length; r++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < columns; k++) ...[
                    if (k > 0) const SizedBox(width: gap),
                    Expanded(
                      child: r * columns + k < visible.length
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: cell * 9 / 21,
                              ),
                              child: visible[r * columns + k],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: gap),
              rows[i],
            ],
            if (more)
              Align(
                alignment: Alignment.centerRight,
                child: _SeeAllLink(
                  key: const Key('category-see-all'),
                  onTap: () => setState(() => _all = true),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({super.key, required this.title, this.onTap});
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    return Semantics(
      button: onTap != null,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: subtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
