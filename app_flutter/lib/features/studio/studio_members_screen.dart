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
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/studio/invite_member_sheet.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';

/// Public summaries of the studio's members (tomato %), up to the cap.
final _memberSummariesProvider = FutureProvider.autoDispose
    .family<Map<String, PhotographerSummary>, String>((ref, studioId) async {
      final list = await ref
          .watch(photographerRepositoryProvider)
          .membersOf(studioId, limit: kStudioMaxMembersVerified);
      return {for (final p in list) p.id: p};
    });

/// S26.01 "Thành viên" at `/studio/members` (studio owner): members with
/// their % and open shoots, pending invites and join requests, the daily
/// quota and the cap; the one primary action invites (S26.02).
class StudioMembersScreen extends ConsumerWidget {
  const StudioMembersScreen({super.key});

  Future<void> _rules(BuildContext context) {
    final l = context.l10n;
    final rules = [
      l.studioRule1,
      l.studioRule2,
      l.studioRule3,
      l.studioRule4,
      l.studioRule5,
    ];
    return showAppSheet<void>(
      context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s4,
          ),
          child: Column(
            key: const Key('studio-rules-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.studioRulesTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final rule in rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(
                                child: Text(
                                  '•',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: AppSpace.s2),
                              Expanded(
                                child: Text(
                                  rule,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              AppButton.outline(
                l.studioSheetClose,
                key: const Key('studio-rules-close'),
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final relations = ref.watch(myStudioRelationsProvider);
    final quota = ref.watch(studioQuotaProvider(true)).value;
    final quotaOut = quota?.exhausted ?? false;
    return ScreenCode(
      ScreenCodes.studioMembers,
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
            title: Text(l.studioMembersTitle),
            actions: [
              IconButton(
                key: const Key('studio-rules'),
                tooltip: l.studioMembersRulesA11y,
                constraints: const BoxConstraints.tightFor(
                  width: AppSpace.s12,
                  height: AppSpace.s12,
                ),
                icon: const AppIcon(AppIcons.info),
                onPressed: () => _rules(context),
              ),
            ],
          ),
          body: AsyncView<List<StudioRelation>>(
            value: relations,
            onRetry: () => ref.invalidate(myStudioRelationsProvider),
            skeleton: (_) => const _Skeleton(),
            data: (context, list) => _Body(relations: list, quota: quota),
          ),
          bottomNavigationBar: AppFooterBar(
            child: AppButton.primary(
              l.studioInviteAction,
              key: const Key('studio-invite'),
              onPressed: quotaOut ? null : () => showInviteMemberSheet(context),
            ),
          ),
        ),
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
      StudioRowsCard(rows: [for (var i = 0; i < 3; i++) MemberRow.skeleton()]),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.relations, required this.quota});

  final List<StudioRelation> relations;
  final StudioQuota? quota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final uid = ref.watch(authStateProvider).value?.uid;
    final intro = ref.watch(myIntroProvider).value;
    final businessVerified = intro?.businessVerified ?? false;
    final max = studioMaxMembers(businessVerified: businessVerified);
    final summaries = uid == null
        ? const <String, PhotographerSummary>{}
        : ref.watch(_memberSummariesProvider(uid)).value ??
              const <String, PhotographerSummary>{};
    // The studio's own bookings (S06.01's stream) give each member's open
    // shoots; until they load (or when they fail) the count is unknown, so
    // the line leaves it out and removing waits.
    final bookings = uid == null
        ? const AsyncValue<List<Booking>>.loading()
        : ref.watch(photographerBookingsStreamProvider(uid));
    final jobs = bookings.hasValue
        ? openJobsByAssignee(bookings.requireValue)
        : null;
    final now = ref.watch(clockProvider)();
    final quotaLeft = quota?.left ?? kStudioDailyActions;
    final quotaOut = quota?.exhausted ?? false;

    final members =
        relations.where((r) => r.status == RelationStatus.active).toList()
          ..sort(
            (a, b) => (a.joinedAt ?? a.createdAt).compareTo(
              b.joinedAt ?? b.createdAt,
            ),
          );
    final pending = [
      for (final r in relations)
        if (r.status == RelationStatus.invited ||
            r.status == RelationStatus.requested)
          r,
    ];
    // The cap counts members and open invites (Decision 3).
    final atCap = relations.atCap(max);
    final showCapBanner = atCap && !businessVerified;
    final canVerify =
        ref.watch(verifyStartReadyProvider) && (intro?.verified ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s1,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        Text(
          l.studioMembersQuota(members.length, max, quotaLeft),
          key: const Key('studio-quota'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (quotaOut) StudioNote(l.studioQuotaOut, icon: AppIcons.schedule),
        if (showCapBanner) ...[
          const SizedBox(height: AppSpace.s2),
          _CapBanner(canVerify: canVerify),
        ],
        // Shows only a failure of the bookings, with "Thử lại".
        if (uid != null)
          AsyncView<List<Booking>>(
            value: bookings,
            loaderSize: LoaderSize.inline,
            skeleton: (_) => const SizedBox.shrink(),
            onRetry: () =>
                ref.invalidate(photographerBookingsStreamProvider(uid)),
            data: (_, _) => const SizedBox.shrink(),
          ),
        const SizedBox(height: AppSpace.s3),
        if (members.isEmpty)
          StudioEmptyCard(
            icon: AppIcons.people,
            title: l.studioMembersEmpty,
            body: l.studioMembersEmptyBody,
          )
        else
          StudioRowsCard(
            rows: [
              for (final m in members)
                _MemberLine(
                  key: ValueKey('studio-member-${m.memberId}'),
                  relation: m,
                  summary: summaries[m.memberId],
                  openJobs: jobs == null ? null : jobs[m.memberId] ?? 0,
                  quotaOut: quotaOut,
                ),
            ],
          ),
        if (pending.isNotEmpty) ...[
          StudioSectionHeader(
            title: l.studioPendingTitle,
            count: l.studioPendingCount(pending.length),
          ),
          StudioRowsCard(
            rows: [
              for (final r in pending)
                r.status == RelationStatus.invited
                    ? _InviteLine(
                        key: ValueKey('studio-pending-${r.id}'),
                        relation: r,
                        now: now,
                        quotaOut: quotaOut,
                      )
                    : _RequestLine(
                        key: ValueKey('studio-pending-${r.id}'),
                        relation: r,
                        now: now,
                        quotaOut: quotaOut,
                        atCap: atCap,
                      ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Đã đủ 3 thợ…" with the S21.04 link when that route exists.
class _CapBanner extends StatelessWidget {
  const _CapBanner({required this.canVerify});

  final bool canVerify;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return GlassCard(
      key: const Key('studio-cap-banner'),
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: AppIcon(AppIcons.businessVerify, size: AppIconSize.sm),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    l.studioFullUnverified,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (canVerify)
              AppButton.text(
                l.studioFullVerifyAction,
                key: const Key('studio-verify-business'),
                size: AppButtonSize.xsmall,
                onPressed: () => context.push('/verify/business'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberLine extends ConsumerWidget {
  const _MemberLine({
    super.key,
    required this.relation,
    required this.summary,
    required this.openJobs,
    required this.quotaOut,
  });

  final StudioRelation relation;
  final PhotographerSummary? summary;

  /// Open studio shoots assigned to the member; null while the studio's
  /// bookings have not loaded.
  final int? openJobs;
  final bool quotaOut;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final name = relation.memberName;
    final jobs = openJobs;
    if (jobs == null) return;
    if (jobs > 0) {
      await showStudioBlockedSheet(
        context,
        title: l.studioBusyTitle(jobs),
        body: l.studioRemoveBusyBody,
      );
      return;
    }
    final repo = ref.read(studioRepositoryProvider);
    await showConfirmSheet(
      context,
      title: l.studioRemoveTitle(name),
      body: l.studioRemoveBody(name),
      confirmLabel: l.studioRemoveMember,
      keepLabel: l.studioRemoveKeep,
      onConfirm: () async {
        try {
          await repo.remove(relation.memberId);
        } catch (e) {
          if (!context.mounted) rethrow;
          throw StudioFailure(studioFailureText(context, e));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = summary;
    final name = relation.memberName;
    final jobs = openJobs;
    return MemberRow(
      avatarUrl: relation.memberAvatarUrl ?? s?.avatarUrl,
      name: name,
      meta: [
        if (s != null && s.hasTomatoPct) MetaPart.tomato(s.tomatoPct),
        if (jobs != null)
          MetaPart.text(
            jobs > 0 ? l.studioMemberAssigned(jobs) : l.studioMemberNoWork,
          ),
      ],
      onTap: () => context.push('/u/${relation.memberId}'),
      trailing: PopupMenuButton<String>(
        key: Key('studio-member-menu-${relation.memberId}'),
        tooltip: l.studioMemberOptions(name),
        icon: const AppIcon(AppIcons.more),
        onSelected: (_) => _remove(context, ref),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'remove',
            // Waits for the bookings (a busy member cannot be removed).
            // Removing spends a daily action; a busy member's sheet explains
            // itself whatever the quota.
            enabled: jobs != null && (!quotaOut || jobs > 0),
            child: Text(
              l.studioRemoveMember,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteLine extends ConsumerWidget {
  const _InviteLine({
    super.key,
    required this.relation,
    required this.now,
    required this.quotaOut,
  });

  final StudioRelation relation;
  final DateTime now;
  final bool quotaOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final days = studioDaysLeft(relation.expiresAt, now);
    return MemberRow(
      avatarUrl: relation.memberAvatarUrl,
      name: relation.memberName,
      meta: [
        MetaPart.text(
          days == 0 ? l.studioInviteSentToday : l.studioInviteSentDays(days),
        ),
      ],
      trailing: AppButton.text(
        l.studioCancelInvite,
        key: Key('studio-cancel-${relation.id}'),
        size: AppButtonSize.xsmall,
        onPressed: quotaOut
            ? null
            : () => runStudioAction(
                context,
                () => ref
                    .read(studioRepositoryProvider)
                    .cancelInvite(relation.id),
              ),
      ),
    );
  }
}

class _RequestLine extends ConsumerWidget {
  const _RequestLine({
    super.key,
    required this.relation,
    required this.now,
    required this.quotaOut,
    required this.atCap,
  });

  final StudioRelation relation;
  final DateTime now;
  final bool quotaOut;

  /// Members plus open invites already fill the studio: approving would be
  /// refused (`studio_full`), as "Mời" is in S26.02.
  final bool atCap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    void respond(bool accept) => runStudioAction(
      context,
      () => ref
          .read(studioRepositoryProvider)
          .respondJoinRequest(relation.id, accept: accept),
    );
    return MemberRow(
      avatarUrl: relation.memberAvatarUrl,
      name: relation.memberName,
      meta: [
        MetaPart.text(
          l.studioJoinRequestedAgo(studioAgo(l, relation.createdAt, now)),
        ),
      ],
      onTap: () => context.push('/u/${relation.memberId}'),
      trailing: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Declining a request is free (Decision 4).
          AppButton.outline(
            l.studioDecline,
            key: Key('studio-decline-${relation.id}'),
            size: AppButtonSize.xsmall,
            onPressed: () => respond(false),
          ),
          AppButton.outline(
            l.studioApprove,
            key: Key('studio-approve-${relation.id}'),
            size: AppButtonSize.xsmall,
            onPressed: quotaOut || atCap ? null : () => respond(true),
          ),
        ],
      ),
    );
  }
}
