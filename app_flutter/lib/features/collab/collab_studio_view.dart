import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_csv.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/collab/collab_fee_sheet.dart';
import 'package:photobooking/features/collab/collab_paid_sheet.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart'
    show VerifyAlert;

/// S27.06 for a studio (mock `#S27.06`): "{a}/{max} cộng tác viên · còn {k}
/// thao tác hôm nay", the active collaborators (% · jobs · suggested fee,
/// "…" Nhắn tin / Sửa thù lao gợi ý / Kết thúc cộng tác), "Thù lao cần trả"
/// with each record's badge and "Đã trả", "Đang chờ" invites with "Huỷ",
/// the tax note (Decision 25) and "Sao chép bảng kê tháng {m} (CSV)"
/// (Decision 19). The screen's primary "Mời cộng tác viên" is
/// [CollabScreen]'s footer.
class CollabStudioView extends ConsumerWidget {
  const CollabStudioView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncView<RecruitCounters>(
        value: ref.watch(myRecruitCountersProvider),
        onRetry: () => ref.invalidate(myRecruitCountersProvider),
        skeleton: (_) => const _Skeleton(),
        data: (context, counters) => AsyncView<List<Collaboration>>(
          value: ref.watch(studioCollaborationsProvider),
          onRetry: () => ref.invalidate(studioCollaborationsProvider),
          skeleton: (_) => const _Skeleton(),
          data: (context, collabs) => AsyncView<List<CollabJob>>(
            value: ref.watch(studioCollabJobsProvider),
            onRetry: () => ref.invalidate(studioCollabJobsProvider),
            skeleton: (_) => const _Skeleton(),
            data: (context, jobs) =>
                _Body(counters: counters, collabs: collabs, jobs: jobs),
          ),
        ),
      );
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
      for (var i = 0; i < 3; i++) MemberRow.skeleton(),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.counters,
    required this.collabs,
    required this.jobs,
  });

  final RecruitCounters counters;
  final List<Collaboration> collabs;
  final List<CollabJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final now = ref.watch(clockProvider)();
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final businessVerified =
        ref.watch(myProviderFactsProvider).value?.businessVerified ?? false;
    final active = [
      for (final c in collabs)
        if (c.status == CollabStatus.active) c,
    ];
    final invites = [
      for (final c in collabs)
        if (c.status == CollabStatus.invited && now.isBefore(c.expiresAt)) c,
    ];
    final pays = payRecords(jobs);
    final owed = pays.where(studioOwesPay).length;
    final actionsLeft = counters.collabActionsLeft(now);
    final blockedUntil = counters.isBlocked(now)
        ? counters.recruitBlockedUntil
        : null;
    final taxSeen = ref.watch(collabTaxNoticeSeenProvider(uid));
    final month = toVn(now).month;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s1,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        Text(
          l.collabStudioMeta(
            active.length,
            collaboratorLimit(businessVerified: businessVerified),
            actionsLeft,
          ),
          key: const Key('collab-studio-meta'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (blockedUntil != null) ...[
          const SizedBox(height: AppSpace.s2),
          VerifyAlert(
            l.recruitBlocked(formatDayMonth(toVn(blockedUntil))),
            key: const Key('collab-blocked'),
          ),
        ],
        const SizedBox(height: AppSpace.s2),
        if (active.isEmpty && invites.isEmpty)
          StudioNote(l.collabStudioEmpty, icon: AppIcons.handshake)
        else
          for (final c in active)
            _CollaboratorRow(
              key: Key('collab-row-${c.collaboratorId}'),
              collaboration: c,
              openJobs: openCollabJobCount(
                jobs,
                now,
                (j) => j.collaboratorId == c.collaboratorId,
              ),
              canAct: actionsLeft > 0,
            ),
        if (pays.isNotEmpty) ...[
          StudioSectionHeader(
            title: l.collabPayDueHeader,
            count: owed > 0 ? '$owed' : null,
          ),
          StudioRowsCard(
            rows: [
              for (final j in pays)
                _PayRow(key: Key('collab-pay-${j.id}'), job: j),
            ],
          ),
        ],
        if (invites.isNotEmpty) ...[
          StudioSectionHeader(
            title: l.collabPendingHeader,
            count: '${invites.length}',
          ),
          for (final c in invites)
            _InviteRow(
              key: Key('collab-invite-${c.collaboratorId}'),
              collaboration: c,
              now: now,
              canAct: actionsLeft > 0,
            ),
        ],
        const SizedBox(height: AppSpace.s3),
        if (needsTaxNotice(jobs) && !taxSeen)
          _TaxNote(
            onDismiss: () =>
                ref.read(collabTaxNoticeSeenProvider(uid).notifier).dismiss(),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            l.collabExportCsv(month),
            key: const Key('collab-export'),
            size: AppButtonSize.small,
            onPressed: () => _export(context, ref, uid, now),
          ),
        ),
      ],
    );
  }

  /// Decision 19: the month's records as CSV on the clipboard.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    String uid,
    DateTime now,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final vn = toVn(now);
    String text;
    try {
      final due = await ref
          .read(collabRepositoryProvider)
          .jobsDueInMonth(uid, vn.year, vn.month);
      if (due.isEmpty) {
        text = l.collabExportEmpty(vn.month);
      } else {
        await Clipboard.setData(ClipboardData(text: collabCsv(due, l)));
        text = l.collabExportDone(vn.month);
      }
    } catch (e) {
      text = collabErrorText(e, l);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

/// One active collaborator: % (their own reviews), "{n} việc đang giao ·
/// gợi ý {fee}/buổi" and the "…" menu.
class _CollaboratorRow extends ConsumerWidget {
  const _CollaboratorRow({
    super.key,
    required this.collaboration,
    required this.openJobs,
    required this.canAct,
  });

  final Collaboration collaboration;
  final int openJobs;

  /// Ending spends one of the studio's daily collaboration actions.
  final bool canAct;

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    String? chatId;
    final ok = await runCollabAction(
      context,
      () async => chatId = await ref
          .read(collabRepositoryProvider)
          .openChat(collaboratorId: collaboration.collaboratorId),
    );
    if (ok && chatId != null) router.push('/chat/$chatId');
  }

  Future<void> _end(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(collabRepositoryProvider);
    return showConfirmSheet(
      context,
      title: l.collabEndConfirmTitle(collaboration.collaboratorName),
      body: l.collabEndConfirmBody,
      confirmLabel: l.collabMenuEnd,
      keepLabel: l.collabKeep,
      onConfirm: () async {
        try {
          await repo.end(collaboratorId: collaboration.collaboratorId);
        } catch (e) {
          throw CollabFailure(collabErrorText(e, l));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = collaboration;
    final summary = ref
        .watch(photographerProfileProvider(c.collaboratorId))
        .value
        ?.summary;
    final fee = c.defaultFee;
    return MemberRow(
      avatarUrl: c.collaboratorAvatarUrl ?? summary?.avatarUrl,
      name: c.collaboratorName,
      meta: [
        if (summary != null && summary.hasTomatoPct)
          MetaPart.tomato(summary.tomatoPct),
        MetaPart.text(
          fee == null
              ? l.collabRowMetaNoFee(openJobs)
              : l.collabRowMeta(openJobs, formatMoney(fee)),
        ),
      ],
      onTap: () => context.push('/u/${c.collaboratorId}'),
      trailing: PopupMenuButton<String>(
        key: Key('collab-menu-${c.collaboratorId}'),
        tooltip: l.collabRowOptions(c.collaboratorName),
        icon: const AppIcon(AppIcons.more),
        onSelected: (v) => switch (v) {
          'message' => _message(context, ref),
          'fee' => showCollabFeeSheet(context, c),
          _ => _end(context, ref),
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'message', child: Text(l.collabMenuMessage)),
          PopupMenuItem(value: 'fee', child: Text(l.collabMenuFee)),
          PopupMenuItem(
            value: 'end',
            enabled: canAct,
            child: Text(
              l.collabMenuEnd,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// "{name} · {shoot} · {fee}", the record's badge and, while the studio
/// owes it, "Đã trả" (S27.06 paid sheet).
class _PayRow extends StatelessWidget {
  const _PayRow({super.key, required this.job});

  final CollabJob job;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final j = job;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CollabTitleMeta(
                  title: '${j.collaboratorName} · ${j.serviceName}',
                  meta: '${collabDayText(j)} · ${formatMoney(j.agreedFee)}',
                ),
                const SizedBox(height: AppSpace.s1),
                CollabPayBadge(j.payStatus),
              ],
            ),
          ),
          if (studioOwesPay(j)) ...[
            const SizedBox(width: AppSpace.s2),
            AppButton.outline(
              l.collabMarkPaid,
              key: Key('collab-paid-${j.id}'),
              size: AppButtonSize.xsmall,
              onPressed: () => showCollabPaidSheet(context, j),
            ),
          ],
        ],
      ),
    );
  }
}

/// A pending invite: "Lời mời đã gửi · hết hạn sau {n} ngày" and "Huỷ".
class _InviteRow extends ConsumerWidget {
  const _InviteRow({
    super.key,
    required this.collaboration,
    required this.now,
    required this.canAct,
  });

  final Collaboration collaboration;
  final DateTime now;

  /// Cancelling spends one of the studio's daily collaboration actions.
  final bool canAct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = collaboration;
    return MemberRow(
      avatarUrl: c.collaboratorAvatarUrl,
      name: c.collaboratorName,
      meta: [
        MetaPart.text(l.collabInviteSent(studioDaysLeft(c.expiresAt, now))),
      ],
      trailing: AppButton.outline(
        l.collabCancelInvite,
        key: Key('collab-cancel-${c.collaboratorId}'),
        size: AppButtonSize.xsmall,
        onPressed: canAct
            ? () => runCollabAction(
                context,
                () => ref
                    .read(collabRepositoryProvider)
                    .cancelInvite(c.collaboratorId),
              )
            : null,
      ),
    );
  }
}

/// Decision 25: the info line above the export link, closable.
class _TaxNote extends StatelessWidget {
  const _TaxNote({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      key: const Key('collab-tax-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: StudioNote(l.collabTaxNote)),
        IconButton(
          key: const Key('collab-tax-dismiss'),
          tooltip: l.collabTaxDismiss,
          icon: const AppIcon(AppIcons.close, size: AppIconSize.sm),
          onPressed: onDismiss,
        ),
      ],
    );
  }
}
