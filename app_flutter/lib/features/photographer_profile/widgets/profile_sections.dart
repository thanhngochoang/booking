// lib/features/photographer_profile/widgets/profile_sections.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/review/widgets/star_rating.dart';

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
      _ => SliverToBoxAdapter(child: AppSkeleton.box(height: 180)),
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
      _ => SliverToBoxAdapter(child: AppSkeleton.card(height: 72)),
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

/// S03.01 "Đánh giá": paginated list of reviews for the photographer.
class ReviewsSliver extends ConsumerStatefulWidget {
  const ReviewsSliver({super.key, required this.photographerId});
  final String photographerId;

  @override
  ConsumerState<ReviewsSliver> createState() => _ReviewsSliverState();
}

class _ReviewsSliverState extends ConsumerState<ReviewsSliver> {
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _scrollPosition) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = pos;
      _scrollPosition?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollPosition;
    if (pos == null || !pos.hasPixels) return;
    if (pos.pixels > 0 && pos.extentAfter < 200) {
      ref
          .read(photographerReviewsProvider(widget.photographerId).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(
      photographerReviewsProvider(widget.photographerId),
    );
    return SliverToBoxAdapter(
      child: AsyncView<List<Review>>(
        value: reviewsAsync,
        skeleton: (_) => Column(
          children: [for (var i = 0; i < 3; i++) ReviewTile.skeleton()],
        ),
        onRetry: () =>
            ref.invalidate(photographerReviewsProvider(widget.photographerId)),
        isEmpty: (l) => l.isEmpty,
        empty: (_) => const _EmptyReviews(),
        data: (context, reviews) => _ReviewsContent(
          photographerId: widget.photographerId,
          reviews: reviews,
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
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
    );
  }
}

class _ReviewsContent extends ConsumerWidget {
  const _ReviewsContent({required this.photographerId, required this.reviews});

  final String photographerId;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final profile = ref
        .watch(photographerProfileProvider(photographerId))
        .value;

    final notifier = ref.read(
      photographerReviewsProvider(photographerId).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile != null && profile.summary.hasRating)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s3),
            child: Text(
              l.reviewsHeader(
                formatRating(profile.summary.ratingAvg),
                profile.summary.reviewCount,
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        for (var i = 0; i < reviews.length; i++) ...[
          _ReviewRow(review: reviews[i]),
          if (i < reviews.length - 1) const Divider(height: 1),
        ],
        if (notifier.loadMoreFailed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Center(
              child: TextButton(
                onPressed: notifier.retryLoadMore,
                child: Text(l.retry),
              ),
            ),
          )
        else if (notifier.loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.s4),
            child: Center(child: SignatureLoader(size: LoaderSize.inline)),
          ),
      ],
    );
  }
}

class _ReviewRow extends ConsumerWidget {
  const _ReviewRow({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(partyProfileProvider(review.customerId));
    if (customerAsync.isLoading && !customerAsync.hasValue) {
      return ReviewTile.skeleton();
    }
    final customer = customerAsync.value;
    final thumbs = review.photoPostId != null
        ? ref
                  .watch(reviewPostProvider(review.photoPostId!))
                  .value
                  ?.images
                  .take(3)
                  .map((img) => img.url)
                  .toList() ??
              const <String>[]
        : const <String>[];

    return ReviewTile(
      review: review,
      name: customer?.displayName ?? context.l10n.reviewsAnonymousName,
      avatarUrl: customer?.avatarUrl,
      thumbs: thumbs,
    );
  }
}

/// A single review tile showing customer info, stars, date, review text,
/// and up to 3 thumbnails of shared photos.
class ReviewTile extends StatefulWidget {
  const ReviewTile({
    super.key,
    required this.review,
    required this.name,
    this.avatarUrl,
    this.thumbs = const [],
  });

  final Review review;
  final String name;
  final String? avatarUrl;
  final List<String> thumbs;

  static Widget skeleton() => const _ReviewTileSkeleton();

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  bool _expanded = false;

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppAvatar(
                  url: widget.avatarUrl,
                  name: widget.name,
                  size: AppAvatarSize.sm,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      StarRating(value: widget.review.rating, size: 14),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Text(
                  _formatDate(widget.review.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          LayoutBuilder(
            builder: (context, constraints) {
              final style =
                  theme.textTheme.bodyMedium ??
                  const TextStyle(fontSize: 14, height: 1.4);
              final textSpan = TextSpan(text: widget.review.text, style: style);
              final textPainter =
                  TextPainter(
                    text: textSpan,
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 4,
                  )..layout(
                    maxWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : double.infinity,
                  );

              final exceeded = textPainter.didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.review.text,
                    style: style,
                    maxLines: _expanded ? null : 4,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                  if (exceeded && !_expanded) ...[
                    const SizedBox(height: AppSpace.s1),
                    InkWell(
                      onTap: () => setState(() => _expanded = true),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppSpace.s12,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: 1,
                          child: Text(
                            context.l10n.reviewsMore,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          if (widget.thumbs.isNotEmpty &&
              widget.review.photoPostId != null) ...[
            const SizedBox(height: AppSpace.s2),
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  for (final thumb in widget.thumbs.take(3)) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s2),
                      child: Semantics(
                        button: true,
                        label: context.l10n.reviewThumbLabel,
                        child: InkWell(
                          key: Key('review-thumb-$thumb'),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () =>
                              context.push('/p/${widget.review.photoPostId}'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: NetworkPhoto(url: thumb),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTileSkeleton extends StatelessWidget {
  const _ReviewTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppAvatar.skeleton(size: AppAvatarSize.sm),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppSkeleton.line(width: 100, height: 12),
                      const SizedBox(height: 4),
                      AppSkeleton.line(width: 70, height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                AppSkeleton.line(width: 60, height: 10),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          SizedBox(
            height: 80.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton.line(widthFactor: 1.0, height: 12),
                AppSkeleton.line(widthFactor: 0.9, height: 12),
                AppSkeleton.line(widthFactor: 0.95, height: 12),
                AppSkeleton.line(widthFactor: 0.6, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
