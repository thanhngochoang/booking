import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/features/collab/collab_accept_sheet.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/collab/collab_offer_sheet.dart';
import 'package:photobooking/features/studio/studio_common.dart';

/// S27.06 for an individual or artist (mock `#S27.06-me`): "Việc chờ nhận"
/// (each opens S27.07, "Còn {time}"), "Studio cộng tác {n} / tối đa 5",
/// "Lời mời" with "Từ chối" / "Xem & nhận" (the terms sheet) and "Thù lao"
/// with "Chưa nhận" / "Đã nhận" once the studio reports a pay. No gradient
/// button. [offerBookingId] (`/collab?offer=…`) opens that offer on load.
class CollabMemberView extends ConsumerWidget {
  const CollabMemberView({super.key, this.offerBookingId});

  final String? offerBookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncView<List<Collaboration>>(
        value: ref.watch(myCollaborationsProvider),
        onRetry: () => ref.invalidate(myCollaborationsProvider),
        skeleton: (_) => const _Skeleton(),
        data: (context, collabs) => AsyncView<List<CollabJob>>(
          value: ref.watch(myCollabJobsProvider),
          onRetry: () => ref.invalidate(myCollabJobsProvider),
          skeleton: (_) => const _Skeleton(),
          data: (context, jobs) => _Body(
            collabs: collabs,
            jobs: jobs,
            offerBookingId: offerBookingId,
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
      AppSkeleton.card(height: 64),
      const SizedBox(height: AppSpace.s3),
      for (var i = 0; i < 3; i++) MemberRow.skeleton(),
    ],
  );
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.collabs,
    required this.jobs,
    required this.offerBookingId,
  });

  final List<Collaboration> collabs;
  final List<CollabJob> jobs;
  final String? offerBookingId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// The deep-linked offer already opened.
  String? _opened;

  @override
  void initState() {
    super.initState();
    _openLinked();
  }

  @override
  void didUpdateWidget(_Body old) {
    super.didUpdateWidget(old);
    // A notification opened `?offer=…` while S27.06 was already showing.
    if (widget.offerBookingId != old.offerBookingId) _openLinked();
  }

  void _openLinked() {
    final id = widget.offerBookingId;
    if (id == null || id == _opened) return;
    _opened = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final job = widget.jobs.where((j) => j.bookingId == id).firstOrNull;
      if (job != null) {
        showCollabOfferSheet(context, job);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.collabOfferGone)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final jobs = widget.jobs;
    final offers = liveOffers(jobs, now);
    final studios = [
      for (final c in widget.collabs)
        if (c.status == CollabStatus.active) c,
    ];
    final invites = [
      for (final c in widget.collabs)
        if (c.status == CollabStatus.invited && now.isBefore(c.expiresAt)) c,
    ];
    final pays = payRecords(jobs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        if (offers.isNotEmpty) ...[
          StudioSectionHeader(
            title: l.collabOffersHeader,
            count: '${offers.length}',
          ),
          for (final j in offers) ...[
            _OfferCard(key: Key('collab-offer-${j.bookingId}'), job: j),
            const SizedBox(height: AppSpace.s2),
          ],
        ],
        StudioSectionHeader(
          title: l.collabStudiosHeader,
          count: l.collabStudiosCount(studios.length),
        ),
        if (studios.isEmpty)
          StudioNote(l.collabEmpty, icon: AppIcons.handshake)
        else
          for (final c in studios)
            _StudioRow(
              key: Key('collab-studio-${c.studioId}'),
              collaboration: c,
              openJobs: openCollabJobCount(
                jobs,
                now,
                (j) => j.studioId == c.studioId,
              ),
            ),
        if (invites.isNotEmpty) ...[
          StudioSectionHeader(
            title: l.collabInvitesHeader,
            count: '${invites.length}',
          ),
          for (final c in invites)
            _InvitationRow(
              key: Key('collab-invitation-${c.studioId}'),
              collaboration: c,
              now: now,
            ),
        ],
        if (pays.isNotEmpty) ...[
          StudioSectionHeader(title: l.collabPayHeader),
          StudioRowsCard(
            rows: [
              for (final j in pays)
                _MyPayRow(key: Key('collab-mypay-${j.id}'), job: j),
            ],
          ),
        ],
      ],
    );
  }
}

/// Mock `.card` of "Việc chờ nhận": studio and shoot, the fee and the
/// "Còn {time}" badge (live, injected clock). Opens S27.07.
class _OfferCard extends ConsumerWidget {
  const _OfferCard({super.key, required this.job});

  final CollabJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final clock = ref.watch(clockProvider);
    final j = job;
    final radius = BorderRadius.circular(AppRadius.card);
    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCollabOfferSheet(context, j),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CollabTitleMeta(
                title: '${j.studioName} · ${j.serviceName}',
                meta: '${collabDayText(j)} · ${j.start}–${j.end}',
              ),
              const SizedBox(height: AppSpace.s1),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMoney(j.agreedFee),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  CountdownText(
                    deadline: j.offerExpiresAt,
                    now: clock,
                    builder: (context, left) => StatusBadge.custom(
                      label: l.collabOfferLeft(collabLeftText(left, l)),
                      color: AppColors.warningSubtle,
                      onColor: AppColors.foreground,
                    ),
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

/// A studio the photographer works with: "Từ {MM/yyyy} · {n} việc đang
/// giao" and "…" Nhắn tin / Kết thúc cộng tác.
class _StudioRow extends ConsumerWidget {
  const _StudioRow({
    super.key,
    required this.collaboration,
    required this.openJobs,
  });

  final Collaboration collaboration;
  final int openJobs;

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    String? chatId;
    final ok = await runCollabAction(
      context,
      () async => chatId = await ref
          .read(collabRepositoryProvider)
          .openChat(studioId: collaboration.studioId),
    );
    if (ok && chatId != null) router.push('/chat/$chatId');
  }

  Future<void> _end(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(collabRepositoryProvider);
    return showConfirmSheet(
      context,
      title: l.collabEndConfirmTitle(collaboration.studioName),
      body: l.collabEndConfirmBody,
      confirmLabel: l.collabMenuEnd,
      keepLabel: l.collabKeep,
      onConfirm: () async {
        try {
          await repo.end(studioId: collaboration.studioId);
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
    final since = c.activeAt;
    return MemberRow(
      avatarUrl: c.studioAvatarUrl,
      name: c.studioName,
      meta: [
        MetaPart.text(
          since == null
              ? l.collabRowMetaNoFee(openJobs)
              : l.collabStudioRowMeta(studioMonth(since), openJobs),
        ),
      ],
      onTap: () => context.push('/u/${c.studioId}'),
      trailing: PopupMenuButton<String>(
        key: Key('collab-studio-menu-${c.studioId}'),
        tooltip: l.collabRowOptions(c.studioName),
        icon: const AppIcon(AppIcons.more),
        onSelected: (v) =>
            v == 'message' ? _message(context, ref) : _end(context, ref),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'message', child: Text(l.collabMenuMessage)),
          PopupMenuItem(
            value: 'end',
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

/// An invite from a studio: "Mời cộng tác · hết hạn sau {n} ngày", outline
/// "Từ chối" (answers at once) and "Xem & nhận" (the terms sheet).
class _InvitationRow extends ConsumerWidget {
  const _InvitationRow({
    super.key,
    required this.collaboration,
    required this.now,
  });

  final Collaboration collaboration;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = collaboration;
    return MemberRow(
      avatarUrl: c.studioAvatarUrl,
      name: c.studioName,
      meta: [
        MetaPart.text(l.collabInviteRowMeta(studioDaysLeft(c.expiresAt, now))),
      ],
      trailing: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s1,
        children: [
          AppButton.outline(
            l.collabDeclineInvite,
            key: Key('collab-decline-${c.studioId}'),
            size: AppButtonSize.xsmall,
            onPressed: () => runCollabAction(
              context,
              () => ref
                  .read(collabRepositoryProvider)
                  .respondInvite(c.studioId, accept: false, acceptTerms: false),
              done: l.collabInviteDeclinedToast(c.studioName),
            ),
          ),
          AppButton.outline(
            l.collabAcceptInvite,
            key: Key('collab-accept-${c.studioId}'),
            size: AppButtonSize.xsmall,
            onPressed: () => showCollabAcceptSheet(context, c),
          ),
        ],
      ),
    );
  }
}

/// One pay record of the photographer: "{studio} · {shoot} · {fee}", and
/// once the studio reports it "Studio báo đã trả {date} ({method})" with
/// "Chưa nhận" (confirm sheet, red) and "Đã nhận"; otherwise its badge.
class _MyPayRow extends ConsumerWidget {
  const _MyPayRow({super.key, required this.job});

  final CollabJob job;

  Future<void> _notReceived(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(collabRepositoryProvider);
    return showConfirmSheet(
      context,
      title: l.collabNotReceivedConfirmTitle,
      body: l.collabNotReceivedConfirmBody,
      confirmLabel: l.collabReportNotReceived,
      keepLabel: l.collabKeep,
      onConfirm: () async {
        try {
          await repo.confirmPay(job.bookingId, received: false);
        } catch (e) {
          throw CollabFailure(collabErrorText(e, l));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final j = job;
    final reported = j.payStatus == PayStatus.paidReported;
    final paidOn = j.paidOn == null ? null : parseDayKey(j.paidOn!);
    final method = j.payMethod;
    final meta = [
      collabDayText(j),
      formatMoney(j.agreedFee),
      if (reported && paidOn != null && method != null)
        l.collabPayReportedMeta(
          formatDayMonth(paidOn),
          collabMethodLabel(method, l),
        ),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CollabTitleMeta(
                  title: '${j.studioName} · ${j.serviceName}',
                  meta: meta,
                ),
              ),
              if (!reported) ...[
                const SizedBox(width: AppSpace.s2),
                CollabPayBadge(j.payStatus),
              ],
            ],
          ),
          if (reported) ...[
            const SizedBox(height: AppSpace.s1),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                AppButton.outline(
                  l.collabReportNotReceived,
                  key: Key('collab-not-received-${j.id}'),
                  size: AppButtonSize.xsmall,
                  onPressed: () => _notReceived(context, ref),
                ),
                AppButton.outline(
                  l.collabConfirmReceived,
                  key: Key('collab-received-${j.id}'),
                  size: AppButtonSize.xsmall,
                  onPressed: () => runCollabAction(
                    context,
                    () => ref
                        .read(collabRepositoryProvider)
                        .confirmPay(j.bookingId, received: true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
