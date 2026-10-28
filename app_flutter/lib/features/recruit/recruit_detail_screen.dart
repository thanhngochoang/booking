import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_apply_sheet.dart';
import 'package:photobooking/features/recruit/recruit_area_label.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/studio/studio_common.dart';

/// One post (S27.02); read only by a provider account (R3).
final recruitPostProvider = FutureProvider.autoDispose
    .family<RecruitPost?, String>(
      (ref, postId) => ref.watch(recruitRepositoryProvider).get(postId),
      retry: (_, _) => null,
    );

/// The signed-in provider's application to a post, or null (one query
/// listener, Task 6 ledger 3).
final myRecruitApplicationProvider = StreamProvider.autoDispose
    .family<RecruitApplication?, String>((ref, postId) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value(null);
      return ref
          .watch(recruitRepositoryProvider)
          .watchMyApplication(postId, uid);
    });

/// S27.02 `/recruit/:postId`: kind tag (+ "Hợp với bạn"), title, the studio
/// row with its stats and "Xem studio", the four rows, "Yêu cầu", the stats
/// line, and one footer: "Ứng tuyển" (S27.03), "Xác minh để ứng tuyển"
/// (S27.02-unverified), or the state of the viewer's application or of the
/// post. No share action (R3).
class RecruitDetailScreen extends ConsumerWidget {
  const RecruitDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final facts = ref.watch(myProviderFactsProvider);
    return ScreenCode(
      ScreenCodes.recruitDetail,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: AsyncView<ProviderFacts?>(
          value: facts,
          onRetry: () => ref.invalidate(myProviderFactsProvider),
          data: (context, f) => f == null || !f.isProviderAccount
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: RecruitNote(l.recruitOnlyProvidersNote),
                )
              : _PostView(postId: postId, facts: f),
        ),
      ),
    );
  }
}

class _PostView extends ConsumerWidget {
  const _PostView({required this.postId, required this.facts});

  final String postId;
  final ProviderFacts facts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView<RecruitPost?>(
      value: ref.watch(recruitPostProvider(postId)),
      onRetry: () => ref.invalidate(recruitPostProvider(postId)),
      isEmpty: (p) => p == null,
      empty: (_) => Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: RecruitNote(l.recruitClosedNote, icon: AppIcons.info),
      ),
      data: (context, p) => _Loaded(post: p!, facts: facts),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.post, required this.facts});

  final RecruitPost post;
  final ProviderFacts facts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final match = recruitMatchScore(post, facts.recruitMatchKeys) == 2;
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final open = recruitPostIsOpen(post, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s1,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              Row(
                children: [
                  Flexible(child: RecruitKindTag(post.kind)),
                  if (match) ...[
                    const SizedBox(width: AppSpace.s2),
                    const RecruitMatchTag(),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              Semantics(
                header: true,
                child: Text(
                  post.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              _StudioRow(post: post),
              const SizedBox(height: AppSpace.s3),
              _InfoRow(
                icon: AppIcons.camera,
                text: recruitSpecialtiesText(post.specialties),
                caption: l.recruitSpecialtiesLabel,
              ),
              _InfoRow(
                icon: AppIcons.place,
                text: recruitAreasText(post.areas),
                caption: l.recruitAreasLabel,
              ),
              _InfoRow(
                icon: AppIcons.calendarRepeat,
                text: recruitFrequencyLong(post.frequency, l),
                caption: l.recruitFrequencyLabel,
              ),
              _InfoRow(
                icon: AppIcons.payment,
                text: recruitFeeText(post.fee, l),
                caption: l.recruitFeeLabel,
              ),
              if (post.requirements.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s2),
                Semantics(
                  header: true,
                  child: Text(
                    l.recruitRequirements,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  post.requirements,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
              const SizedBox(height: AppSpace.s3),
              if (open)
                Text(
                  l.recruitStats(
                    post.applicationCount,
                    studioDaysLeft(post.expiresAt, now),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        _Footer(post: post, facts: facts, open: open),
      ],
    );
  }
}

/// Avatar, name + seal, "🍅 96% · 128 buổi chụp" (the studio's public
/// profile, #130) and the outline "Xem studio".
class _StudioRow extends ConsumerWidget {
  const _StudioRow({required this.post});

  final RecruitPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final mark = recruitStudioMark(post);
    return Row(
      children: [
        AppAvatar(
          url: post.studioAvatarUrl,
          name: post.studioName,
          size: AppAvatarSize.sm,
        ),
        const SizedBox(width: AppSpace.s2h),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProviderName(
                post.studioName,
                mark: mark,
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              AsyncView<PhotographerProfile?>(
                value: ref.watch(photographerProfileProvider(post.studioId)),
                skeleton: (_) => AppSkeleton.line(widthFactor: 0.4),
                error: (_, _, _) => const SizedBox.shrink(),
                data: (context, p) {
                  final s = p?.summary;
                  if (s == null) return const SizedBox.shrink();
                  return MetaLine([
                    if (s.hasTomatoPct) MetaPart.tomato(s.tomatoPct),
                    MetaPart.text(l.recruitStudioShoots(s.completedCount)),
                  ]);
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        AppButton.outline(
          l.recruitViewStudio,
          key: const Key('recruit-view-studio'),
          size: AppButtonSize.xsmall,
          onPressed: () => context.push('/u/${post.studioId}'),
        ),
      ],
    );
  }
}

/// Mock `.irow`: an icon tile, the value and its small caption.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.caption,
  });

  final IconData icon;
  final String text;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: SizedBox.square(
              dimension: AppSpace.s8,
              child: Center(
                child: ExcludeSemantics(
                  child: AppIcon(icon, size: AppIconSize.sm),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s2h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyMedium),
                Text(
                  caption,
                  style: TextStyle(fontSize: AppText.xs2, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one footer of S27.02: the first that applies of studio viewer,
/// member of this studio, the viewer's application, a closed post, not
/// verified, or "Ứng tuyển".
class _Footer extends ConsumerWidget {
  const _Footer({required this.post, required this.facts, required this.open});

  final RecruitPost post;
  final ProviderFacts facts;
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (facts.isStudio) {
      return _bar(RecruitNote(l.recruitStudioViewerNote, icon: AppIcons.info));
    }
    if (facts.studioId == post.studioId) {
      return _bar(
        RecruitNote(
          l.recruitAlreadyMember(post.studioName),
          icon: AppIcons.info,
        ),
      );
    }
    return AsyncView<RecruitApplication?>(
      value: ref.watch(myRecruitApplicationProvider(post.id)),
      loaderSize: LoaderSize.inline,
      skeleton: (_) => const SizedBox(height: AppSpace.s12),
      onRetry: () => ref.invalidate(myRecruitApplicationProvider(post.id)),
      data: (context, a) => _bar(_action(context, ref, a)),
    );
  }

  Widget _bar(Widget child) => AppFooterBar(child: child);

  Widget _action(BuildContext context, WidgetRef ref, RecruitApplication? a) {
    final l = context.l10n;
    switch (a?.status) {
      case ApplicationStatus.applied when open:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton.outline(
              l.recruitApplied,
              key: const Key('recruit-applied'),
              onPressed: null,
            ),
            const SizedBox(height: AppSpace.s1),
            AppButton.text(
              l.recruitWithdraw,
              key: const Key('recruit-withdraw'),
              onPressed: () => _withdraw(context, ref),
            ),
          ],
        );
      case ApplicationStatus.accepted:
        return _result(context, l.recruitResultAccepted);
      case ApplicationStatus.declined:
        return _result(context, l.recruitResultDeclined);
      case ApplicationStatus.withdrawn || ApplicationStatus.expired:
        return RecruitNote(l.recruitErrorDuplicate, icon: AppIcons.info);
      case ApplicationStatus.applied || null:
        break;
    }
    if (!open) return RecruitNote(l.recruitClosedNote, icon: AppIcons.info);
    if (!facts.acceptingOrders) {
      final canVerify = ref.watch(verifyStartReadyProvider);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecruitNote(l.recruitVerifyNote),
          if (canVerify) ...[
            const SizedBox(height: AppSpace.s2h),
            AppButton.primary(
              l.recruitVerifyToApply,
              key: const Key('recruit-verify'),
              onPressed: () => context.push('/verify/start'),
            ),
          ],
        ],
      );
    }
    return AppButton.primary(
      l.recruitApply,
      key: const Key('recruit-apply'),
      onPressed: () => showRecruitApplySheet(context, post),
    );
  }

  Widget _result(BuildContext context, String text) => Text(
    text,
    key: const Key('recruit-result'),
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600),
  );

  Future<void> _withdraw(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(recruitRepositoryProvider);
    return showConfirmSheet(
      context,
      title: l.recruitWithdrawConfirmTitle,
      body: l.recruitWithdrawConfirmBody,
      confirmLabel: l.recruitWithdraw,
      keepLabel: l.recruitWithdrawKeep,
      danger: true,
      onConfirm: () async {
        try {
          await repo.withdraw(post.id);
        } catch (e) {
          throw RecruitFailure(recruitApplyErrorText(e, l));
        }
      },
    );
  }
}
