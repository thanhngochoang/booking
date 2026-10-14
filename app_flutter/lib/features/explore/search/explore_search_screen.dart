// lib/features/explore/search/explore_search_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/features/explore/explore_links.dart';
import 'package:photobooking/features/explore/search/explore_search.dart';
import 'package:photobooking/features/explore/search/explore_search_controller.dart';

class ExploreSearchScreen extends ConsumerStatefulWidget {
  const ExploreSearchScreen({super.key});

  @override
  ConsumerState<ExploreSearchScreen> createState() =>
      _ExploreSearchScreenState();
}

class _ExploreSearchScreenState extends ConsumerState<ExploreSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(exploreSearchQueryProvider);
    _controller.text = initial;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(exploreSearchQueryProvider.notifier).setQuery(value);
      }
    });
    setState(() {}); // to update clear button visibility
  }

  void _onClear() {
    _debounceTimer?.cancel();
    _controller.clear();
    ref.read(exploreSearchQueryProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final searchAsync = ref.watch(exploreSearchProvider);
    final query = ref.watch(exploreSearchQueryProvider).trim();

    return ScreenCode(
      ScreenCodes.exploreSearch,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const AppIcon(AppIcons.back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.pop(),
          ),
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.exploreSearchHint,
              border: InputBorder.none,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const AppIcon(AppIcons.close),
                      tooltip: l.exploreSearchClear,
                      onPressed: _onClear,
                    )
                  : null,
            ),
            onChanged: _onChanged,
          ),
        ),
        body: _buildBody(context, query, searchAsync),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String query,
    AsyncValue<ExploreSearchResults> searchAsync,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);

    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Text(
            l.exploreSearchIdle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      );
    }

    return AsyncView<ExploreSearchResults>(
      value: searchAsync,
      isEmpty: (res) => res.isEmpty,
      empty: (_) => _buildEmptyState(context, query),
      error: (_, _, _) => _buildEmptyState(context, query),
      data: (context, results) => ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
        children: [
          if (results.services.isNotEmpty) ...[
            _SectionHeader(title: l.exploreTabServices),
            for (final s in results.services)
              _ServiceTile(
                hit: s,
                onTap: () => context.push(
                  findPhotographersPath(specialty: s.id),
                ),
              ),
          ],
          if (results.styles.isNotEmpty) ...[
            _SectionHeader(title: l.exploreTabStyles),
            for (final st in results.styles)
              _StyleTile(
                hit: st,
                onTap: () => context.push(
                  findPhotographersPath(style: st.id),
                ),
              ),
          ],
          if (results.places.isNotEmpty) ...[
            _SectionHeader(title: l.exploreTabPlaces),
            for (final p in results.places)
              _PlaceTile(
                hit: p,
                onTap: () => context.push(
                  findPhotographersPath(area: p.id),
                ),
              ),
          ],
          if (results.photographers.isNotEmpty) ...[
            _SectionHeader(title: l.exploreTabPhotographers),
            for (final ph in results.photographers)
              _PhotographerTile(
                photographer: ph.photographer!,
                onTap: () => context.push('/u/${ph.id}'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.search,
              size: 48,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: AppSpace.s3),
            Text(
              l.exploreSearchEmptyTitle(query),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              l.exploreSearchEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              l.exploreSearchSeeAll,
              onPressed: () => context.push('/action'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s3,
        AppSpace.s4,
        AppSpace.s1,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.hit, required this.onTap});
  final ExploreHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final count = hit.serviceCount;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const AppIcon(AppIcons.camera, size: 20),
      ),
      title: Text(
        hit.label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: count != null && count > 0
          ? Text(
              l.exploreCategoryPackages(count),
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: const AppIcon(AppIcons.chevron, size: 20),
      onTap: onTap,
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.hit, required this.onTap});
  final ExploreHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const AppIcon(AppIcons.gradient, size: 20),
      ),
      title: Text(
        hit.label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: const AppIcon(AppIcons.chevron, size: 20),
      onTap: onTap,
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.hit, required this.onTap});
  final ExploreHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const AppIcon(AppIcons.place, size: 20),
      ),
      title: Text(
        hit.label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: const AppIcon(AppIcons.chevron, size: 20),
      onTap: onTap,
    );
  }
}

class _PhotographerTile extends StatelessWidget {
  const _PhotographerTile({
    required this.photographer,
    required this.onTap,
  });

  final PhotographerSummary photographer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = photographer;
    final mark = providerMarkOf(type: p.providerType, verified: p.verified);
    final meta = areaRatingMeta(p, l);

    return ListTile(
      leading: AppAvatar(
        url: p.avatarUrl,
        size: AppAvatarSize.sm,
        name: p.displayName,
      ),
      title: ProviderName(
        p.displayName,
        mark: mark,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: meta.isNotEmpty
          ? MetaLine(
              meta,
              style: theme.textTheme.bodySmall,
            )
          : null,
      onTap: onTap,
    );
  }
}
