import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';

/// The studio's public summary, for its mark on the card.
final _studioSummaryProvider = FutureProvider.autoDispose
    .family<PhotographerSummary?, String>((ref, studioId) async {
      final map = await ref.watch(photographerRepositoryProvider).summaries([
        studioId,
      ]);
      return map[studioId];
    });

/// Shoots studios assigned to the signed-in photographer. Unlike #134's
/// `assignedBookingsProvider` (which reads a failure as "no work" so S06.01
/// never breaks), a failure stays an error here: leaving must wait until the
/// open shoots are known.
final _assignedJobsProvider = StreamProvider.autoDispose<List<Booking>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).watchAssignedBookings(uid);
});

/// The package of a studio booking, for its cover as the job's thumbnail.
final _packageCoverProvider = FutureProvider.autoDispose
    .family<String?, (String, String)>((ref, key) async {
      final service = await ref
          .watch(serviceRepositoryProvider)
          .byId(key.$1, key.$2);
      return service?.coverUrl;
    });

/// S26.03 "Studio của tôi" at `/me/studio` (individual or NAG photographer):
/// the studio they are in, the shoots it gave them, leaving, and invites.
/// One studio at a time, so other invites are dimmed while in one. No
/// gradient button.
class MyStudioScreen extends ConsumerWidget {
  const MyStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final relations = ref.watch(myMemberRelationsProvider);
    return ScreenCode(
      ScreenCodes.myStudio,
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
                    onPressed: () => context.go('/settings'),
                  ),
            title: Text(l.myStudioTitle),
          ),
          body: AsyncView<List<StudioRelation>>(
            value: relations,
            onRetry: () => ref.invalidate(myMemberRelationsProvider),
            skeleton: (_) => ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.s4),
              children: [
                StudioRowsCard(rows: [MemberRow.skeleton()]),
                const SizedBox(height: AppSpace.s3),
                StudioRowsCard(
                  rows: [for (var i = 0; i < 2; i++) MemberRow.skeleton()],
                ),
              ],
            ),
            data: (context, list) => _Body(relations: list),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.relations});

  final List<StudioRelation> relations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final quotaOut = ref.watch(studioQuotaProvider(false)).value?.exhausted;
    final active = relations
        .where((r) => r.status == RelationStatus.active)
        .firstOrNull;
    final requests = [
      for (final r in relations)
        if (r.status == RelationStatus.requested) r,
    ];
    final invites = [
      for (final r in relations)
        if (r.status == RelationStatus.invited) r,
    ];
    // This studio's open shoots; the count is unknown until they load.
    final jobs = active == null
        ? null
        : ref
              .watch(_assignedJobsProvider)
              .whenData(
                (list) => [
                  for (final b in list)
                    if (b.photographerId == active.studioId &&
                        isOpenStudioJob(b))
                      b,
                ],
              );
    final openJobs = jobs != null && jobs.hasValue
        ? jobs.requireValue.length
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s1,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        if (active != null) ...[
          _StudioCard(relation: active, jobs: openJobs),
          AsyncView<List<Booking>>(
            value: jobs!,
            loaderSize: LoaderSize.inline,
            skeleton: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.s4),
                for (var i = 0; i < 2; i++) ...[
                  _JobCard.skeleton(),
                  const SizedBox(height: AppSpace.s2),
                ],
              ],
            ),
            onRetry: () => ref.invalidate(_assignedJobsProvider),
            data: (context, list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isNotEmpty) ...[
                  StudioSectionHeader(
                    title: l.myStudioJobs,
                    count: '${list.length}',
                  ),
                  for (final b in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s2),
                      child: _JobCard(booking: b),
                    ),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.text(
              l.myStudioLeave,
              key: const Key('my-studio-leave'),
              size: AppButtonSize.small,
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.error,
                ),
              ),
              // Waits for the open shoots: a busy member cannot leave.
              onPressed: quotaOut == true || openJobs == null
                  ? null
                  : () => _leave(context, ref, active, openJobs),
            ),
          ),
        ] else ...[
          StudioEmptyCard(
            icon: AppIcons.work,
            title: l.myStudioNone,
            body: l.myStudioNoneBody,
          ),
          for (final r in requests) ...[
            const SizedBox(height: AppSpace.s3),
            StudioRowsCard(
              rows: [_RequestLine(relation: r, now: now, quotaOut: quotaOut)],
            ),
          ],
        ],
        if (quotaOut == true)
          StudioNote(l.studioQuotaOut, icon: AppIcons.schedule),
        if (invites.isNotEmpty) ...[
          StudioSectionHeader(
            title: l.myStudioInvites,
            count: '${invites.length}',
          ),
          for (final r in invites)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: StudioRowsCard(
                rows: [
                  _InviteLine(
                    key: ValueKey('my-studio-invite-${r.id}'),
                    relation: r,
                    now: now,
                    currentStudio: active?.studioName,
                  ),
                ],
              ),
            ),
        ],
        StudioNote(l.myStudioCooldownNote),
      ],
    );
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    StudioRelation active,
    int openJobs,
  ) async {
    final l = context.l10n;
    if (openJobs > 0) {
      await showStudioBlockedSheet(
        context,
        title: l.studioBusyTitle(openJobs),
        body: l.myStudioLeaveBusyBody,
      );
      return;
    }
    final repo = ref.read(studioRepositoryProvider);
    await showConfirmSheet(
      context,
      title: l.myStudioLeaveTitle(active.studioName),
      body: l.myStudioLeaveBody(active.studioName),
      confirmLabel: l.myStudioLeave,
      keepLabel: l.myStudioLeaveKeep,
      onConfirm: () async {
        try {
          await repo.leave();
        } catch (e) {
          if (!context.mounted) rethrow;
          throw StudioFailure(studioFailureText(context, e));
        }
      },
    );
  }
}

/// The studio the photographer is in: mark, since-line and "Xem studio".
class _StudioCard extends ConsumerWidget {
  const _StudioCard({required this.relation, required this.jobs});

  final StudioRelation relation;

  /// Open shoots from this studio; null until they load.
  final int? jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(_studioSummaryProvider(relation.studioId)).value;
    final since = studioMonth(relation.joinedAt ?? relation.createdAt);
    final mark = s == null
        ? null
        : providerMarkOf(
            type: ProviderType.studio,
            verified: s.verified,
            businessVerified: s.businessVerified,
          );
    return StudioRowsCard(
      rows: [
        MemberRow(
          key: const Key('my-studio-card'),
          avatarUrl: relation.studioAvatarUrl ?? s?.avatarUrl,
          name: relation.studioName,
          mark: mark,
          meta: [
            MetaPart.text(
              jobs == null
                  ? l.myStudioSinceOnly(since)
                  : l.myStudioSince(since, jobs!),
            ),
          ],
          trailing: AppButton.outline(
            l.myStudioView,
            key: const Key('my-studio-view'),
            size: AppButtonSize.xsmall,
            onPressed: () => context.push('/u/${relation.studioId}'),
          ),
        ),
      ],
    );
  }
}

/// A shoot the studio gave the photographer (mock: the package's cover,
/// package, day and time, "Đã giao").
///
/// Not core `BookingCard`: its compact size shows the place instead of the
/// day and time, its title is always "{photographer} · {package}", and its
/// `statusLabel` badge is the waiting yellow, while the mock's "Đã giao" is
/// the accepted green.
class _JobCard extends ConsumerWidget {
  const _JobCard({required this.booking});

  final Booking booking;

  static const double _thumb = AppSpace.s12;

  /// The card's shape while the shoots load.
  static Widget skeleton() => GlassCard(
    highlight: false,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s3),
      child: Row(
        children: [
          AppSkeleton.box(width: _thumb, height: _thumb, radius: AppRadius.lg),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton.line(widthFactor: 0.5),
                const SizedBox(height: AppSpace.s1),
                AppSkeleton.line(widthFactor: 0.7),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cover = ref
        .watch(
          _packageCoverProvider((booking.photographerId, booking.serviceId)),
        )
        .value;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final day = parseDayKey(booking.day);
    final when =
        '${day == null ? booking.day : formatDay(day)} · '
        '${booking.start}–${booking.end}';
    return GlassCard(
      highlight: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('my-studio-job-${booking.id}'),
          onTap: () => context.push('/b/${booking.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: SizedBox.square(
                      dimension: _thumb,
                      child: ColoredBox(
                        color: dark
                            ? AppColorsDark.surfaceMuted
                            : AppColors.surfaceMuted,
                        child: cover == null
                            ? AppIcon(AppIcons.camera, color: secondary)
                            : NetworkPhoto(url: cover, retry: false),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceSnapshot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        when,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                StatusBadge.custom(
                  label: l.myStudioAssignedBadge,
                  color: AppColors.bookingAccepted,
                  onColor: AppColors.foregroundInverse,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photographer's own join request, with "Huỷ" (a daily action).
class _RequestLine extends ConsumerWidget {
  const _RequestLine({
    required this.relation,
    required this.now,
    required this.quotaOut,
  });

  final StudioRelation relation;
  final DateTime now;
  final bool? quotaOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final days = studioDaysLeft(relation.expiresAt, now);
    final ago = studioAgo(l, relation.createdAt, now);
    return MemberRow(
      avatarUrl: relation.studioAvatarUrl,
      name: l.myStudioRequestPending(relation.studioName),
      meta: [
        MetaPart.text(
          days == 0
              ? l.myStudioRequestSentToday(ago)
              : l.myStudioRequestSent(ago, days),
        ),
      ],
      trailing: AppButton.text(
        l.myStudioRequestCancel,
        key: Key('my-studio-cancel-${relation.id}'),
        size: AppButtonSize.xsmall,
        onPressed: quotaOut == true
            ? null
            : () => runStudioAction(
                context,
                () => ref
                    .read(studioRepositoryProvider)
                    .cancelJoinRequest(relation.id),
              ),
      ),
    );
  }
}

/// A studio's invite: "Nhận" (outline) and "Từ chối" (red text); dimmed
/// with the reason while in [currentStudio]. Answering is free.
class _InviteLine extends ConsumerWidget {
  const _InviteLine({
    super.key,
    required this.relation,
    required this.now,
    required this.currentStudio,
  });

  final StudioRelation relation;
  final DateTime now;
  final String? currentStudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final blockedBy = currentStudio;
    final days = studioDaysLeft(relation.expiresAt, now);
    void respond(bool accept) => runStudioAction(
      context,
      () => ref
          .read(studioRepositoryProvider)
          .respondInvite(relation.id, accept: accept),
    );
    return MemberRow(
      avatarUrl: relation.studioAvatarUrl,
      name: relation.studioName,
      enabled: blockedBy == null,
      meta: [
        MetaPart.text(
          blockedBy != null
              ? l.myStudioInviteBlocked(blockedBy)
              : days == 0
              ? l.myStudioInviteExpiresToday
              : l.myStudioInviteExpires(days),
        ),
      ],
      onTap: () => context.push('/u/${relation.studioId}'),
      trailing: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppButton.outline(
            l.myStudioAccept,
            key: Key('my-studio-accept-${relation.id}'),
            size: AppButtonSize.xsmall,
            onPressed: blockedBy != null ? null : () => respond(true),
          ),
          AppButton.text(
            l.myStudioDecline,
            key: Key('my-studio-decline-${relation.id}'),
            size: AppButtonSize.xsmall,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
            ),
            onPressed: blockedBy != null ? null : () => respond(false),
          ),
        ],
      ),
    );
  }
}
