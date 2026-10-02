// lib/features/photographer_profile/widgets/profile_sections.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

/// S03.01 "Portfolio": a lazy two-column grid (only visible tiles are built,
/// each photo decoded at tile size by `NetworkPhoto`), "Xem thêm ảnh", then
/// "Thợ ảnh tương tự".
class PortfolioSliver extends ConsumerWidget {
  const PortfolioSliver({super.key, required this.photographerId});
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(portfolioProvider(photographerId));
    final evidence =
        ref
            .watch(photographerSkillsProvider(photographerId))
            .value
            ?.evidencePostIds ??
        const <String>{};
    return switch (state) {
      AsyncData(:final value) when value.posts.isEmpty => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: _Quiet(l.profileNoPortfolio)),
          SliverToBoxAdapter(child: _Similar(photographerId: photographerId)),
        ],
      ),
      AsyncData(:final value) => SliverMainAxisGroup(
        slivers: [
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpace.s2,
              crossAxisSpacing: AppSpace.s2,
            ),
            itemCount: value.posts.length,
            itemBuilder: (context, i) => _PortfolioTile(
              post: value.posts[i],
              evidence: evidence.contains(value.posts[i].id),
            ),
          ),
          if (value.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s3),
                child: AppButton.outline(
                  l.profileMorePhotos,
                  key: const Key('portfolio-more'),
                  loading: value.loadingMore,
                  onPressed: () => ref
                      .read(portfolioProvider(photographerId).notifier)
                      .loadMore(),
                ),
              ),
            ),
          SliverToBoxAdapter(child: _Similar(photographerId: photographerId)),
        ],
      ),
      AsyncError() => SliverToBoxAdapter(
        child: ErrorState(
          message: l.profileLoadError,
          onRetry: () => ref.invalidate(portfolioProvider(photographerId)),
        ),
      ),
      _ => const SliverToBoxAdapter(child: AppSkeleton.box(height: 180)),
    };
  }
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({required this.post, required this.evidence});
  final PostSummary post;
  final bool evidence;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      label: [
        post.caption.isEmpty ? l.profilePhoto : post.caption,
        if (evidence) l.profileEvidenceBadge,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('portfolio-${post.id}'),
        borderRadius: radius,
        onTap: () => context.push('/p/${post.id}'),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkPhoto(url: post.cover.url),
              if (evidence)
                const Positioned(
                  top: AppSpace.s1,
                  right: AppSpace.s1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.overlay,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.s1),
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Similar extends ConsumerWidget {
  const _Similar({required this.photographerId});
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final list =
        ref.watch(similarPhotographersProvider(photographerId)).value ??
        const [];
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s5),
        Semantics(
          header: true,
          child: Text(l.profileSimilar, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpace.s2),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s3),
            itemBuilder: (context, i) {
              final p = list[i];
              return InkWell(
                key: Key('similar-${p.id}'),
                onTap: () => context.push('/u/${p.id}'),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      AppAvatar(
                        url: p.avatarUrl,
                        name: p.displayName,
                        size: AppAvatarSize.lg,
                      ),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// S03.01 "Gói": a visitor taps a package to book it (phone gate included);
/// the owner taps to edit packages.
class ServicesSliver extends ConsumerWidget {
  const ServicesSliver({
    super.key,
    required this.photographerId,
    required this.owner,
  });
  final String photographerId;
  final bool owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final packages = ref.watch(profilePackagesProvider(photographerId));
    return switch (packages) {
      AsyncData(:final value) when value.isEmpty => SliverToBoxAdapter(
        child: _Quiet(l.profileNoServices),
      ),
      AsyncData(:final value) => SliverList.separated(
        itemCount: value.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
        itemBuilder: (context, i) => _ServiceTile(
          service: value[i],
          onTap: owner
              ? () => context.push('/setup/2')
              : () => startBooking(
                  context,
                  ref,
                  photographerId: photographerId,
                  serviceId: value[i].id,
                ),
        ),
      ),
      AsyncError() => SliverToBoxAdapter(
        child: ErrorState(
          message: l.profileLoadError,
          onRetry: () =>
              ref.invalidate(profilePackagesProvider(photographerId)),
        ),
      ),
      _ => const SliverToBoxAdapter(child: AppSkeleton.card(height: 72)),
    };
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});
  final ServiceSummary service;
  final VoidCallback onTap;

  /// List cards use the card radius; no blur on list rows.
  static const _radius = BorderRadius.all(Radius.circular(AppRadius.card));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = service;
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      borderRadius: _radius,
      child: InkWell(
        key: Key('service-${s.id}'),
        borderRadius: _radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: theme.textTheme.titleSmall),
                    Text(
                      packageMeta(
                        l,
                        durationMinutes: s.durationMinutes,
                        editedCount: s.editedCount,
                        deliveryDays: s.deliveryDays,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Text(
                formatMoney(s.priceVnd),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S03.01 "Lịch": the same `AvailabilityCalendar` as S06.04, read-only. Switching
/// months rebuilds only this sliver; its month listener closes when the
/// tab is left.
class CalendarSliver extends ConsumerStatefulWidget {
  const CalendarSliver({super.key, required this.photographerId});
  final String photographerId;

  @override
  ConsumerState<CalendarSliver> createState() => _CalendarSliverState();
}

class _CalendarSliverState extends ConsumerState<CalendarSliver> {
  late DateTime _month = monthOf(ref.read(calendarTodayProvider));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(calendarTodayProvider);
    final days = ref.watch(
      availabilityMonthProvider((uid: widget.photographerId, month: _month)),
    );
    final known = days.value ?? const {};
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvailabilityCalendar(
            month: _month,
            states: {for (final e in known.entries) e.key: e.value.state},
            today: today,
            minDate: today,
            maxDate: lastDayOfMonth(addMonths(monthOf(today), 12)),
            eventDays: {
              for (final e in known.entries)
                if (e.value.eventId != null) e.key,
            },
            onMonthChanged: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: AppSpace.s3),
          const AvailabilityLegend(),
          if (days.hasError) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              l.calendarLoadError,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// S03.01 "Đánh giá": reviews arrive with step 6; until then a clear empty state.
class ReviewsSliver extends StatelessWidget {
  const ReviewsSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
        child: Column(
          children: [
            Text(
              l.profileNoReviewsTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              l.profileNoReviewsBody,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
