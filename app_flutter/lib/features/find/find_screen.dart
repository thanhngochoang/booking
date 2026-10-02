import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/find/find_controller.dart';
import 'package:photobooking/features/find/find_sheets.dart';

/// Items load when fewer than this many dp remain below the viewport.
const _loadMoreExtent = 600.0;

const _skeletonHeight = 280.0;
const _noteIconSize = 14.0;

/// S02.06: compare photographers by area, day, service, price and rating.
class FindPhotographerScreen extends ConsumerStatefulWidget {
  const FindPhotographerScreen({
    super.key,
    this.initialSpecialty,
    this.initialStyle,
    this.initialArea,
  });

  final String? initialSpecialty;
  final String? initialStyle;
  final String? initialArea;

  @override
  ConsumerState<FindPhotographerScreen> createState() =>
      _FindPhotographerScreenState();
}

class _FindPhotographerScreenState
    extends ConsumerState<FindPhotographerScreen> {
  final _scroll = ScrollController();
  String? _applied;

  /// The cursor the viewport fill already asked for, so a failing page is not
  /// retried in a loop.
  String? _filledFor;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < _loadMoreExtent) {
        ref.read(findResultsProvider.notifier).loadMore();
      }
    });
    _applyInitial();
  }

  @override
  void didUpdateWidget(FindPhotographerScreen old) {
    super.didUpdateWidget(old);
    _applyInitial();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Applies the filters that came with the link, once per distinct link.
  void _applyInitial() {
    final key =
        '${widget.initialSpecialty}|${widget.initialStyle}|${widget.initialArea}';
    if (key == '$_applied' || key == 'null|null|null') {
      _applied = key;
      return;
    }
    _applied = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final filters = ref.read(findFiltersProvider.notifier);
      if (widget.initialSpecialty != null) {
        filters.setSpecialty(widget.initialSpecialty);
      }
      if (widget.initialStyle != null) {
        filters.setStyle(widget.initialStyle);
      }
      final areaId = widget.initialArea;
      if (areaId != null) {
        final areas = await ref.read(areasProvider.future);
        final match = areas.where((a) => a.id == areaId);
        if (match.isNotEmpty && mounted) {
          await ref
              .read(locationControllerProvider.notifier)
              .chooseArea(match.first);
        }
      }
    });
  }

  /// A page the rating filter shrank can leave the list shorter than the
  /// viewport: nothing scrolls, so ask for the next page once per cursor
  /// until the list fills or the pages run out.
  void _fillViewport() {
    if (!mounted || !_scroll.hasClients) {
      return;
    }
    final results = ref.read(findResultsProvider);
    if (results.isLoading) {
      return;
    }
    final data = results.value;
    final cursor = data?.cursor;
    if (data == null ||
        cursor == null ||
        data.loadingMore ||
        cursor == _filledFor ||
        _scroll.position.extentAfter >= _loadMoreExtent) {
      return;
    }
    _filledFor = cursor;
    ref.read(findResultsProvider.notifier).loadMore();
  }

  DateTime _today() {
    final vn = toVn(ref.read(clockProvider)());
    return DateTime(vn.year, vn.month, vn.day);
  }

  Future<void> _pickDate(FindFilters filters) async {
    final r = await pickDate(context, current: filters.date, today: _today());
    if (r != null) {
      ref.read(findFiltersProvider.notifier).setDate(r.value);
    }
  }

  Widget _chipRow(List<Widget> chips) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
    child: Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s2),
          chips[i],
        ],
      ],
    ),
  );

  List<Widget> _resultSlivers(
    BuildContext context,
    AsyncValue<FindResults> results,
    FindFilters filters,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    if (results.isLoading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpace.s4),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                AppSkeleton.card(height: _skeletonHeight),
                const SizedBox(height: AppSpace.s3),
                AppSkeleton.card(height: _skeletonHeight),
              ],
            ),
          ),
        ),
      ];
    }
    if (!results.hasValue) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(
            message: l.findLoadError,
            onRetry: () => ref.invalidate(findResultsProvider),
          ),
        ),
      ];
    }
    final data = results.requireValue;
    if (data.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmptyState(
                title: l.findNoResult,
                body: l.findNoResultBody,
                actionLabel: filters.hasAny ? l.findClear : null,
                onAction: filters.hasAny
                    ? ref.read(findFiltersProvider.notifier).clear
                    : null,
              ),
            ],
          ),
        ),
      ];
    }
    final count = '${data.items.length}${data.cursor != null ? '+' : ''}';
    final countText = filters.date == null
        ? l.findCount(count)
        : l.findCountOnDay(count, formatDay(filters.date!));
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s2,
          AppSpace.s4,
          AppSpace.s2,
        ),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(countText, style: theme.textTheme.bodySmall),
              if (data.usedFallback)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s1),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: _noteIconSize),
                      const SizedBox(width: AppSpace.s1),
                      Expanded(
                        child: Text(
                          l.findFallbackNote,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        sliver: SliverAdaptiveRows(
          itemCount: data.items.length,
          itemBuilder: (context, i) {
            final item = data.items[i];
            final p = item.photographer;
            final day = filters.date;
            return PhotographerCard(
              key: Key('find-card-${p.id}'),
              data: p,
              reasons: item.reasons,
              distanceKm: item.distanceKm,
              availabilityLabel: day != null
                  ? l.reasonFreeOnDate(formatDayMonth(day))
                  : freeThisWeekLabel(p, now, l),
              bookLabel: day == null
                  ? null
                  : l.findBookDay(weekdayLabel(day.weekday)),
              onProfile: () {
                ref.read(findResultsProvider.notifier).sendClick(item);
                context.push('/u/${p.id}');
              },
              onBook: () =>
                  startBooking(context, ref, photographerId: p.id, date: day),
            );
          },
        ),
      ),
      if (data.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.s4),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s8)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filters = ref.watch(findFiltersProvider);
    final filterCtl = ref.read(findFiltersProvider.notifier);
    final results = ref.watch(findResultsProvider);
    final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());

    return ScreenCode(
      ScreenCodes.findPhotographer,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          title: Text(l.tabFind),
          actions: [
            IconButton(
              key: const Key('find-area'),
              tooltip: l.locationChooseArea,
              icon: const Icon(Icons.place_outlined),
              onPressed: () => showAreaPicker(context),
            ),
          ],
        ),
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: _chipRow([
                AppChip(
                  key: const Key('find-area-chip'),
                  label: origin == null
                      ? l.locationChooseArea
                      : (origin.areaName ?? l.findNearMe),
                  selected: origin != null,
                  onChanged: (_) => showAreaPicker(context),
                ),
                AppChip(
                  key: const Key('find-date'),
                  label: filters.date == null
                      ? l.findDate
                      : formatDay(filters.date!),
                  selected: filters.date != null,
                  onChanged: (_) => _pickDate(filters),
                ),
                AppChip(
                  key: const Key('find-service'),
                  label: filters.specialtyId == null
                      ? l.findService
                      : specialtyLabel(filters.specialtyId!),
                  selected: filters.specialtyId != null,
                  onChanged: (_) async {
                    final r = await pickSpecialty(
                      context,
                      current: filters.specialtyId,
                    );
                    if (r != null) {
                      filterCtl.setSpecialty(r.value);
                    }
                  },
                ),
                if (filters.styleId != null)
                  AppChip(
                    key: const Key('find-style'),
                    label: styleLabel(filters.styleId!),
                    selected: true,
                    onChanged: (_) => filterCtl.setStyle(null),
                  ),
                AppChip(
                  key: const Key('find-price'),
                  label: filters.budgetMax == null
                      ? l.findPrice
                      : l.findPriceUnder(
                          formatMoney(filters.budgetMax!, short: true),
                        ),
                  selected: filters.budgetMax != null,
                  onChanged: (_) async {
                    final r = await pickBudget(
                      context,
                      current: filters.budgetMax,
                    );
                    if (r != null) {
                      filterCtl.setBudget(r.value);
                    }
                  },
                ),
                AppChip(
                  key: const Key('find-rating'),
                  label: filters.minRating == null
                      ? l.findRating
                      : l.findRatingMin(formatRating(filters.minRating!)),
                  selected: filters.minRating != null,
                  onChanged: (_) async {
                    final r = await pickMinRating(
                      context,
                      current: filters.minRating,
                    );
                    if (r != null) {
                      filterCtl.setMinRating(r.value);
                    }
                  },
                ),
              ]),
            ),
            SliverToBoxAdapter(
              child: _chipRow([
                for (final (key, sort, label) in [
                  ('find-sort-best', RecommendationSort.best, l.findSortBest),
                  ('find-sort-near', RecommendationSort.near, l.findSortNear),
                  (
                    'find-sort-price',
                    RecommendationSort.price,
                    l.findSortPrice,
                  ),
                  (
                    'find-sort-rating',
                    RecommendationSort.rating,
                    l.findSortRating,
                  ),
                ])
                  AppChip(
                    key: Key(key),
                    kind: AppChipKind.context,
                    label: label,
                    selected: filters.sort == sort,
                    onChanged: (_) => filterCtl.setSort(sort),
                  ),
              ]),
            ),
            ..._resultSlivers(context, results, filters),
          ],
        ),
      ),
    );
  }
}
