// lib/features/photo/photo_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/photo/photo_detail_controller.dart';

/// Mock: the gallery is 3:4.
const double _galleryAspect = 3 / 4;
const double _dotSize = 6;
const double _dotGap = 3;
const double _dotIdleAlpha = 0.5;
const double _inactiveOpacity = 0.5;
const double _thumbSize = 56;
const double _iconSize = 16;
const int _moreSlots = 3;

/// At this text size (px for a 16px body) the two bottom buttons stack.
const double _stackBodyPx = 16;
const double _stackAbovePx = 18.4;

/// "Chân dung · Quận 3 · ★ 4,9 (58)": only the parts that exist (mock S02).
String _authorMeta(PhotographerSummary p) => [
  if (p.specialtyIds.isNotEmpty) specialtyLabel(p.specialtyIds.first),
  if (p.areaLabel != null && p.areaLabel!.isNotEmpty) p.areaLabel!,
  if (p.hasRating) '★ ${formatRating(p.ratingAvg)} (${p.reviewCount})',
].join(' · ');

/// S02: from one photo to the package it was shot with, and to booking it.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(postDetailProvider(widget.postId), (prev, next) {
      final d = next.value;
      if (d != null && prev?.value?.post.id != d.post.id) {
        // Not inside initState/build: a cached detail fires this at once.
        Future.microtask(() {
          if (!mounted) {
            return;
          }
          ref.read(engagementProvider.notifier).load(d.post);
          ref.read(followProvider.notifier).load(d.post.photographerId);
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _like(String postId) async {
    final ok = await ref.read(engagementProvider.notifier).toggleLike(postId);
    if (!ok && mounted) {
      _toast(context.l10n.engagementError);
    }
  }

  Future<void> _save(String postId) async {
    final ok = await ref.read(engagementProvider.notifier).toggleSave(postId);
    if (!ok && mounted) {
      _toast(context.l10n.engagementError);
    }
  }

  Future<void> _follow(String photographerId) async {
    final ok = await ref.read(followProvider.notifier).toggle(photographerId);
    if (!ok && mounted) {
      _toast(context.l10n.engagementError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detail = ref.watch(postDetailProvider(widget.postId));
    return ScreenCode(
      ScreenCodes.photoDetail,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: detail.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpace.s4),
                  child: AppSkeleton.card(height: 400),
                ),
                error: (_, _) => Center(
                  child: ErrorState(
                    message: l.photoLoadError,
                    onRetry: () =>
                        ref.invalidate(postDetailProvider(widget.postId)),
                  ),
                ),
                data: (d) => d == null
                    ? EmptyState(
                        title: l.photoRemovedTitle,
                        body: l.photoRemovedBody,
                        actionLabel: l.photoBackHome,
                        onAction: () => context.go(AppTab.home.path),
                      )
                    : _Content(
                        detail: d,
                        pages: _pages,
                        page: _page,
                        onPage: (i) => setState(() => _page = i),
                        onLike: () => _like(d.post.id),
                        onSave: () => _save(d.post.id),
                        onFollow: () => _follow(d.post.photographerId),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s2),
                  child: IconButton(
                    key: const Key('photo-back'),
                    tooltip: l.back,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.overlay,
                      foregroundColor: AppColors.foregroundInverse,
                    ),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppTab.home.path),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.detail,
    required this.pages,
    required this.page,
    required this.onPage,
    required this.onLike,
    required this.onSave,
    required this.onFollow,
  });

  final PostDetail detail;
  final PageController pages;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final post = detail.post;
    final author = detail.photographer;
    final service = detail.service;
    final view =
        ref.watch(engagementProvider.select((m) => m[post.id])) ??
        EngagementView(likeCount: post.likeCount, saveCount: post.saveCount);
    final following = ref.watch(
      followProvider.select((m) => m[post.photographerId] ?? false),
    );
    final active = service != null && service.active;
    final stack =
        MediaQuery.textScalerOf(context).scale(_stackBodyPx) > _stackAbovePx;

    final profileButton = AppButton.outline(
      l.photoViewProfile,
      key: const Key('photo-profile'),
      onPressed: () => context.push('/u/${post.photographerId}'),
    );
    final bookButton = AppButton.primary(
      active ? l.photoBook : l.photoOtherPackages,
      key: const Key('photo-book'),
      onPressed: () {
        final s = service;
        if (s != null && s.active) {
          startBooking(
            context,
            ref,
            photographerId: post.photographerId,
            serviceId: s.id,
          );
        } else {
          context.push('/u/${post.photographerId}?tab=services');
        }
      },
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Gallery(
                post: post,
                pages: pages,
                page: page,
                onPage: onPage,
                onDoubleTap: () {
                  if (!view.liked) {
                    onLike();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (author != null)
                      Row(
                        children: [
                          AppAvatar(
                            url: author.avatarUrl,
                            name: author.displayName,
                            decorative: true,
                          ),
                          const SizedBox(width: AppSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                author.verified
                                    ? VerifiedName(
                                        author.displayName,
                                        style: theme.textTheme.titleMedium,
                                      )
                                    : Text(
                                        author.displayName,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                Text(
                                  _authorMeta(author),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.s2),
                          AppButton.outline(
                            following ? l.photoFollowing : l.photoFollow,
                            key: const Key('follow'),
                            size: AppButtonSize.xsmall,
                            onPressed: onFollow,
                          ),
                        ],
                      ),
                    if (post.caption.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s3),
                      Text(post.caption),
                    ],
                    if (post.kind == PostKind.realShoot && author != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.photoRealShootBy(
                          author.displayName,
                          service?.name ?? '',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpace.s3),
                    Row(
                      children: [
                        _CountButton(
                          key: const Key('like'),
                          icon: view.liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          count: view.likeCount,
                          label: view.liked ? l.photoUnlike : l.photoLike,
                          color: view.liked ? theme.colorScheme.error : null,
                          onTap: onLike,
                        ),
                        _CountButton(
                          key: const Key('save'),
                          icon: view.saved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          count: view.saveCount,
                          label: view.saved ? l.photoUnsave : l.photoSave,
                          onTap: onSave,
                        ),
                        if (post.locationName != null)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: _iconSize,
                                ),
                                const SizedBox(width: AppSpace.s1),
                                Flexible(
                                  child: Text(
                                    post.locationName!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (service != null) ...[
                      const SizedBox(height: AppSpace.s3),
                      _ServiceCard(service: service),
                    ],
                    if (detail.more.isNotEmpty && author != null) ...[
                      const SizedBox(height: AppSpace.s5),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                l.photoMoreOf(author.displayName),
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push('/u/${post.photographerId}'),
                            child: Text(l.photoMoreProfile),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Row(
                        children: [
                          for (var i = 0; i < _moreSlots; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpace.s2),
                            Expanded(
                              child: i < detail.more.length
                                  ? PhotoCard(
                                      key: Key('more-${detail.more[i].id}'),
                                      imageUrl: detail.more[i].cover.url,
                                      aspect: 1,
                                      // No visible text: name the card by the
                                      // post's caption, else "Ảnh {i}".
                                      semanticLabel:
                                          detail.more[i].caption.isNotEmpty
                                          ? detail.more[i].caption
                                          : l.photoItemLabel(i + 1),
                                      onTap: () => context.push(
                                        '/p/${detail.more[i].id}',
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        AppFooterBar(
          child: stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    profileButton,
                    const SizedBox(height: AppSpace.s2),
                    bookButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 4, child: profileButton),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(flex: 6, child: bookButton),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.post,
    required this.pages,
    required this.page,
    required this.onPage,
    required this.onDoubleTap,
  });

  final PostSummary post;
  final PageController pages;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = post.images.length;
    return AspectRatio(
      aspectRatio: _galleryAspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('photo-gallery'),
            onDoubleTap: onDoubleTap,
            child: PageView.builder(
              controller: pages,
              itemCount: n,
              onPageChanged: onPage,
              itemBuilder: (context, i) => NetworkPhoto(
                url: post.images[i].url,
                semanticLabel: l.photoPageOf(i + 1, n),
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpace.s3,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < n; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _dotGap,
                        ),
                        child: DecoratedBox(
                          key: Key('page-dot-$i'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.foregroundInverse.withValues(
                              alpha: i == page ? 1 : _dotIdleAlpha,
                            ),
                          ),
                          child: const SizedBox.square(dimension: _dotSize),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpace.s12,
            minWidth: AppSpace.s12,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpace.s1),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photos = service.editedCount ?? service.photoCount;
    final details = [
      if (photos != null) l.servicePhotos(photos),
      if (service.deliveryDays != null)
        l.serviceDelivery(service.deliveryDays!),
      formatDuration(service.durationMinutes, l),
    ].join(' · ');
    final cover = service.coverUrl;
    return Opacity(
      opacity: service.active ? 1 : _inactiveOpacity,
      child: Material(
        key: const Key('service-card'),
        color: scheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: service.active ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox.square(
                  dimension: _thumbSize,
                  child: cover == null
                      ? ColoredBox(color: scheme.outlineVariant)
                      : NetworkPhoto(url: cover, retry: false),
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: theme.textTheme.titleMedium),
                    Text(details, style: theme.textTheme.bodySmall),
                    if (!service.active)
                      Text(
                        l.photoServiceInactive,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: AppText.sm,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                formatMoney(service.priceVnd),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
