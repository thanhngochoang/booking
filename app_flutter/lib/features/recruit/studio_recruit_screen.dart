import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/features/recruit/studio_recruit_controller.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart';

/// Shows [builder] only to a studio account (S27.04, S27.05); anyone else
/// is sent to `/recruit` once their facts load.
class StudioRecruitGate extends ConsumerStatefulWidget {
  const StudioRecruitGate({super.key, required this.builder});

  final Widget Function(BuildContext context, ProviderFacts facts) builder;

  @override
  ConsumerState<StudioRecruitGate> createState() => _StudioRecruitGateState();
}

class _StudioRecruitGateState extends ConsumerState<StudioRecruitGate> {
  bool _leaving = false;

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).replace('/recruit');
    });
  }

  @override
  Widget build(BuildContext context) => AsyncView<ProviderFacts?>(
    value: ref.watch(myProviderFactsProvider),
    onRetry: () => ref.invalidate(myProviderFactsProvider),
    data: (context, f) {
      if (f == null || !f.isProviderAccount || !f.isStudio) {
        _leave();
        return const SizedBox.shrink();
      }
      return widget.builder(context, f);
    },
  );
}

/// S27.05 `/studio/recruit` (query `post`): "{open}/3 tin mở · còn {n} lượt
/// đăng/đóng hôm nay", the studio's posts (kind tag, status badge,
/// applicants and days left, Sửa / Gia hạn 30 ngày / Đóng tin), the
/// applicants of the selected post with "Từ chối" and "Nhận", and one
/// primary: "Đăng tin mới", "Đã đủ 3 tin mở" (off), or "Xác minh để đăng
/// tin". A blocked studio sees the warning and no enabled primary.
class StudioRecruitScreen extends ConsumerWidget {
  const StudioRecruitScreen({super.key, this.postId});

  /// Preselected post (notifications `/studio/recruit?post=…`).
  final String? postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.studioRecruit,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.recruitStudioTitle)),
        body: StudioRecruitGate(
          builder: (context, facts) => _Body(postId: postId),
        ),
        bottomNavigationBar: const _Footer(),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.postId});

  final String? postId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late String? _selected = widget.postId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final now = ref.watch(clockProvider)();
    return AsyncView<RecruitCounters>(
      value: ref.watch(myRecruitCountersProvider),
      onRetry: () => ref.invalidate(myRecruitCountersProvider),
      skeleton: (_) => const _Skeleton(),
      data: (context, counters) => AsyncView<List<RecruitPost>>(
        value: ref.watch(studioRecruitPostsProvider),
        onRetry: () => ref.invalidate(studioRecruitPostsProvider),
        skeleton: (_) => const _Skeleton(),
        data: (context, posts) {
          final selected = selectedRecruitPost(posts, _selected, now);
          final blockedUntil = counters.isBlocked(now)
              ? counters.recruitBlockedUntil
              : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s1,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              Text(
                l.recruitStudioMeta(
                  counters.openPostCount,
                  counters.postActionsLeft(now),
                ),
                key: const Key('recruit-studio-meta'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (blockedUntil != null) ...[
                const SizedBox(height: AppSpace.s2),
                VerifyAlert(
                  l.recruitBlocked(recruitBlockedDate(blockedUntil)),
                  key: const Key('recruit-blocked'),
                ),
              ],
              const SizedBox(height: AppSpace.s2),
              if (posts.isEmpty)
                StudioNote(l.recruitNoPosts, icon: AppIcons.campaign)
              else
                for (final p in posts) ...[
                  _PostCard(
                    key: Key('recruit-post-${p.id}'),
                    post: p,
                    now: now,
                    selected: p.id == selected?.id,
                    closeAllowed: counters.postActionsLeft(now) > 0,
                    onTap: () => setState(() => _selected = p.id),
                  ),
                  const SizedBox(height: AppSpace.s2),
                ],
              if (selected != null)
                _Applicants(
                  post: selected,
                  canAnswer: counters.collabActionsLeft(now) > 0,
                  blockedUntil: blockedUntil,
                ),
            ],
          );
        },
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
      AppSkeleton.line(widthFactor: 0.6),
      const SizedBox(height: AppSpace.s3),
      for (var i = 0; i < 2; i++) ...[
        RecruitCard.skeleton(key: ValueKey('recruit-post-skeleton-$i')),
        const SizedBox(height: AppSpace.s2),
      ],
    ],
  );
}

/// Mock `.badge`: "Đang mở" (ok), "Đã đóng", "Hết hạn".
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.open, required this.status});

  final bool open;
  final RecruitPostStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (open) {
      return StatusBadge.custom(
        label: l.recruitStatusOpen,
        color: dark ? AppColorsDark.successSubtle : AppColors.successSubtle,
        onColor: dark ? AppColorsDark.success : AppColors.success,
      );
    }
    return StatusBadge.custom(
      label: status == RecruitPostStatus.closed
          ? l.recruitStatusClosed
          : l.recruitStatusExpired,
      color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
      onColor: dark
          ? AppColorsDark.foregroundSecondary
          : AppColors.foregroundSecondary,
    );
  }
}

/// One post (mock `jcard`): kind tag and status, title, "{n} ứng viên ·
/// còn {d} ngày", and while open the text actions. Tapping selects it.
class _PostCard extends ConsumerWidget {
  const _PostCard({
    super.key,
    required this.post,
    required this.now,
    required this.selected,
    required this.closeAllowed,
    required this.onTap,
  });

  final RecruitPost post;
  final DateTime now;
  final bool selected;

  /// Closing spends one of the day's post actions.
  final bool closeAllowed;
  final VoidCallback onTap;

  Future<void> _renew(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    String text;
    try {
      final until = await ref.read(recruitRepositoryProvider).renew(post.id);
      text = l.recruitRenewedToast(formatDayMonth(toVn(until)));
    } catch (e) {
      text = recruitPostActionErrorText(e, l);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _close(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(recruitRepositoryProvider);
    return showConfirmSheet(
      context,
      title: l.recruitCloseConfirmTitle,
      body: l.recruitCloseConfirmBody,
      confirmLabel: l.recruitClose,
      keepLabel: l.recruitCloseKeep,
      onConfirm: () async {
        try {
          await repo.close(post.id);
        } catch (e) {
          throw RecruitFailure(recruitPostActionErrorText(e, l));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final open = recruitPostIsOpen(post, now);
    final quiet = TextButton.styleFrom(foregroundColor: secondary);
    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s3,
              AppSpace.s2h,
              AppSpace.s3,
              AppSpace.s1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(child: RecruitKindTag(post.kind)),
                    const SizedBox(width: AppSpace.s2),
                    const Spacer(),
                    _StatusBadge(open: open, status: post.status),
                  ],
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: AppText.base2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  open
                      ? l.recruitPostMeta(
                          post.applicationCount,
                          studioDaysLeft(post.expiresAt, now),
                        )
                      : l.recruitPostMetaEnded(post.applicationCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (open)
                  Wrap(
                    children: [
                      AppButton.text(
                        l.recruitEdit,
                        key: Key('recruit-edit-${post.id}'),
                        size: AppButtonSize.xsmall,
                        style: quiet,
                        onPressed: () =>
                            context.push('/studio/recruit/${post.id}/edit'),
                      ),
                      if (!post.renewed)
                        AppButton.text(
                          l.recruitRenew,
                          key: Key('recruit-renew-${post.id}'),
                          size: AppButtonSize.xsmall,
                          style: quiet,
                          onPressed: () => _renew(context, ref),
                        ),
                      AppButton.text(
                        l.recruitClose,
                        key: Key('recruit-close-${post.id}'),
                        size: AppButtonSize.xsmall,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        onPressed: closeAllowed
                            ? () => _close(context, ref)
                            : null,
                      ),
                    ],
                  )
                else
                  const SizedBox(height: AppSpace.s2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ứng viên · {title}" with "{n} chờ trả lời", then one card per applicant
/// (or "Chưa có ai ứng tuyển.").
class _Applicants extends ConsumerWidget {
  const _Applicants({
    required this.post,
    required this.canAnswer,
    required this.blockedUntil,
  });

  final RecruitPost post;

  /// Accepting and declining spend the day's collaboration actions.
  final bool canAnswer;
  final DateTime? blockedUntil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final applicants = ref.watch(studioRecruitApplicantsProvider(post.id));
    final count = applicants.value?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioSectionHeader(
          title: l.recruitApplicantsHeader(post.title),
          count: count == null ? null : l.recruitApplicantsPending(count),
        ),
        AsyncView<List<RecruitApplication>>(
          value: applicants,
          onRetry: () =>
              ref.invalidate(studioRecruitApplicantsProvider(post.id)),
          loaderSize: LoaderSize.inline,
          skeleton: (_) => Column(
            children: [
              for (var i = 0; i < 2; i++) ...[
                MemberRow.skeleton(),
                const SizedBox(height: AppSpace.s2),
              ],
            ],
          ),
          isEmpty: (list) => list.isEmpty,
          empty: (_) => StudioNote(l.recruitNoApplicants),
          data: (context, list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in list) ...[
                _ApplicantCard(
                  key: Key('recruit-applicant-${a.applicantId}'),
                  application: a,
                  // A recruit-blocked studio cannot take collaborators on
                  // running posts (Task 3 ruling).
                  canAccept:
                      canAnswer &&
                      (blockedUntil == null ||
                          post.kind != RecruitKind.collaborator),
                  canDecline: canAnswer,
                  blockedUntil: blockedUntil,
                ),
                const SizedBox(height: AppSpace.s2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Mock applicant card: avatar, name + mark, "🍅 95% · 42 buổi chụp", the
/// message, three sample thumbnails, outline "Từ chối" and "Nhận".
class _ApplicantCard extends ConsumerStatefulWidget {
  const _ApplicantCard({
    super.key,
    required this.application,
    required this.canAccept,
    required this.canDecline,
    required this.blockedUntil,
  });

  final RecruitApplication application;
  final bool canAccept;
  final bool canDecline;
  final DateTime? blockedUntil;

  @override
  ConsumerState<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends ConsumerState<_ApplicantCard> {
  bool _busy = false;

  RecruitApplication get _a => widget.application;

  String _errorText(Object e) => recruitRespondErrorText(
    e,
    context.l10n,
    name: _a.applicantName,
    blockedUntil: widget.blockedUntil,
  );

  void _refresh() => ref.invalidate(studioRecruitApplicantsProvider(_a.postId));

  Future<void> _accept() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(recruitRepositoryProvider);
    setState(() => _busy = true);
    String text;
    var ok = false;
    try {
      await repo.respond(_a.postId, _a.applicantId, accept: true);
      ok = true;
      text = l.recruitAcceptedToast(_a.applicantName);
    } catch (e) {
      text = mounted ? _errorText(e) : l.recruitErrorGeneric;
    }
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    if (ok && mounted) _refresh();
  }

  Future<void> _decline() async {
    final l = context.l10n;
    final repo = ref.read(recruitRepositoryProvider);
    final name = _a.applicantName;
    final declined = await showConfirmSheet(
      context,
      title: l.recruitDeclineConfirmTitle(name),
      body: l.recruitDeclineConfirmBody(name),
      confirmLabel: l.recruitDecline,
      keepLabel: l.recruitDeclineKeep,
      onConfirm: () async {
        try {
          await repo.respond(_a.postId, _a.applicantId, accept: false);
        } catch (e) {
          throw RecruitFailure(
            recruitRespondErrorText(
              e,
              l,
              name: name,
              blockedUntil: widget.blockedUntil,
            ),
          );
        }
      },
    );
    if (declined && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final profile = ref.watch(photographerProfileProvider(_a.applicantId));
    final summary = profile.value?.summary;
    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/u/${_a.applicantId}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppAvatar(
                    url: _a.applicantAvatarUrl ?? summary?.avatarUrl,
                    name: _a.applicantName,
                    size: AppAvatarSize.sm,
                  ),
                  const SizedBox(width: AppSpace.s2h),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProviderName(
                          _a.applicantName,
                          mark: summary == null
                              ? null
                              : providerMarkOf(
                                  type: summary.providerType,
                                  verified: summary.verified,
                                  businessVerified: summary.businessVerified,
                                ),
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AsyncView<PhotographerProfile?>(
                          value: profile,
                          skeleton: (_) => AppSkeleton.line(width: 120),
                          error: (_, _, _) => const SizedBox.shrink(),
                          data: (context, p) {
                            final s = p?.summary;
                            if (s == null) return const SizedBox.shrink();
                            return MetaLine([
                              if (s.hasTomatoPct) MetaPart.tomato(s.tomatoPct),
                              MetaPart.text(
                                l.recruitStudioShoots(s.completedCount),
                              ),
                            ]);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_a.message.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s2),
                Text(
                  '“${_a.message}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s2),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: AppSpace.s2,
                children: [
                  _Samples(ids: _a.samplePostIds),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton.outline(
                        l.recruitDecline,
                        key: Key('recruit-decline-${_a.applicantId}'),
                        size: AppButtonSize.xsmall,
                        onPressed: _busy || !widget.canDecline
                            ? null
                            : _decline,
                      ),
                      const SizedBox(width: AppSpace.s1),
                      AppButton.outline(
                        l.recruitAccept,
                        key: Key('recruit-accept-${_a.applicantId}'),
                        size: AppButtonSize.xsmall,
                        loading: _busy,
                        onPressed: !widget.canAccept ? null : _accept,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to three small thumbnails of the applicant's chosen posts.
class _Samples extends ConsumerWidget {
  const _Samples({required this.ids});

  final List<String> ids;

  static const _tile = AppSpace.s10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ids.isEmpty) return const SizedBox.shrink();
    final key = ids.join(',');
    Widget row(List<Widget> tiles) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s1),
          tiles[i],
        ],
      ],
    );
    return AsyncView<List<PostSummary>>(
      value: ref.watch(recruitSamplesProvider(key)),
      loaderSize: LoaderSize.inline,
      skeleton: (_) => row([
        for (final _ in ids) AppSkeleton.box(width: _tile, height: _tile),
      ]),
      error: (_, _, _) => const SizedBox.shrink(),
      data: (context, posts) => row([
        for (final p in posts)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox.square(
              dimension: _tile,
              child: NetworkPhoto(url: p.cover.url, retry: false),
            ),
          ),
      ]),
    );
  }
}

/// The one primary of S27.05.
class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final facts = ref.watch(myProviderFactsProvider).value;
    if (facts == null || !facts.isProviderAccount || !facts.isStudio) {
      return const SizedBox.shrink();
    }
    if (!facts.acceptingOrders) {
      if (!ref.watch(verifyStartReadyProvider)) {
        return const SizedBox.shrink();
      }
      return AppFooterBar(
        child: AppButton.primary(
          l.recruitVerifyToPost,
          key: const Key('recruit-verify-to-post'),
          onPressed: () => context.push('/verify/start'),
        ),
      );
    }
    // Off while the counters load, when blocked, at 3 open posts or with
    // no post actions left today.
    final counters = ref.watch(myRecruitCountersProvider).value;
    final now = ref.watch(clockProvider)();
    final full =
        counters != null && counters.openPostCount >= kRecruitMaxOpenPosts;
    final can =
        counters != null &&
        !full &&
        !counters.isBlocked(now) &&
        counters.postActionsLeft(now) > 0;
    return AppFooterBar(
      child: AppButton.primary(
        full ? l.recruitFull : l.recruitNewPost,
        key: const Key('recruit-new-post'),
        onPressed: can ? () => context.push('/studio/recruit/new') : null,
      ),
    );
  }
}
