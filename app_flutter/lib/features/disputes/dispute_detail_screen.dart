// S18.02 (#142): one dispute for its customer and its provider — what is
// disputed, the money held, where the case stands, the description and the
// evidence, then the three-party thread with support (#204's
// SupportThreadView). Resolved: the outcome in money, the staff note, the
// thread read-only and "Liên hệ hỗ trợ" in the footer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/support/support_thread.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';
import 'package:photobooking/features/disputes/widgets/dispute_outcome_card.dart';
import 'package:photobooking/features/help/support_thread_view.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class DisputeDetailScreen extends ConsumerWidget {
  const DisputeDetailScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.disputeDetail,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.disputeTitle(disputeCode(disputeId)))),
          body: AsyncView<Dispute?>(
            value: ref.watch(disputeProvider(disputeId)),
            onRetry: () => ref.invalidate(disputeProvider(disputeId)),
            // The rules refuse a dispute the viewer is not a party of the
            // same way as a missing one: both read as "not found".
            isEmpty: (d) => d == null,
            empty: (_) => EmptyState(
              title: l.disputeNotFound,
              body: l.disputeNotFoundBody,
            ),
            data: (context, d) => _DisputeBody(dispute: d!),
          ),
        ),
      ),
    );
  }
}

class _DisputeBody extends ConsumerWidget {
  const _DisputeBody({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final d = dispute;
    final open = d.status == DisputeStatus.open;
    return Column(
      children: [
        Expanded(
          child: KeyedSubtree(
            key: const Key('dispute-detail-scroll'),
            child: SupportThreadView(
              threadId: d.threadId,
              enabled: open,
              hint: l.disputeThreadHint,
              scrollHeader: true,
              senderLabel: (m) => _senderLabel(l, d, m, uid),
              header: _DisputeDetails(
                dispute: d,
                viewerIsCustomer: d.isCustomer(uid),
              ),
            ),
          ),
        ),
        if (!open)
          AppFooterBar(
            child: AppButton.outline(
              l.helpContactSupport,
              key: const Key('dispute-contact-support'),
              icon: const AppIcon(AppIcons.supportAgent, size: 20),
              onPressed: () => context.push('/help/chat'),
            ),
          ),
      ],
    );
  }
}

/// "Hỗ trợ", "{name} · nhiếp ảnh gia" ("· chủ sự kiện" for a ticket),
/// "{name} · khách"; the viewer's own messages carry no label.
String _senderLabel(
  AppLocalizations l,
  Dispute d,
  SupportMessage m,
  String uid,
) {
  if (m.senderId != null && m.senderId == uid) {
    return '';
  }
  return switch (m.senderRole) {
    SupportSenderRole.staff => l.disputeSenderSupport,
    SupportSenderRole.provider =>
      d.subjectType == DisputeSubjectType.ticket
          ? l.disputeSenderHost(_nameOf(m, d.providerName))
          : l.disputeSenderProvider(_nameOf(m, d.providerName)),
    SupportSenderRole.customer => l.disputeSenderCustomer(_nameOf(m, null)),
    SupportSenderRole.user || SupportSenderRole.system => '',
  };
}

String _nameOf(SupportMessage m, String? fallback) =>
    m.senderName.isNotEmpty ? m.senderName : (fallback ?? '');

/// `10:12 14/10` in Vietnam time.
String _when(DateTime instant) {
  final vn = toVn(instant);
  return '${formatHm(vn)} ${formatDayMonth(vn)}';
}

/// Everything above "Trao đổi"'s messages, scrolling with them.
class _DisputeDetails extends StatelessWidget {
  const _DisputeDetails({
    required this.dispute,
    required this.viewerIsCustomer,
  });

  final Dispute dispute;
  final bool viewerIsCustomer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final d = dispute;
    final open = d.status == DisputeStatus.open;
    final outcome = d.outcome;
    const gap = SizedBox(height: AppSpace.s3);
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!open && outcome != null) ...[
          InlineToast(l.disputeResolvedToast(_when(outcome.decidedAt))),
          gap,
        ],
        _SubjectCard(dispute: d),
        gap,
        if (open) ...[
          KeyValueBox(
            key: const Key('dispute-held'),
            rows: [
              KeyValueRow(
                label: l.disputeHeld,
                value: formatMoney(d.amountHeld),
                note: l.disputeHeldNote,
              ),
              KeyValueRow(label: l.disputeOpenedAt, value: _when(d.createdAt)),
            ],
          ),
          gap,
          StatusTimeline(
            steps: [
              TimelineStep(
                title: l.disputeStepSent,
                subtitle: l.disputeStepSentBody(d.evidencePaths.length),
                state: TimelineStepState.done,
              ),
              TimelineStep(
                title: l.disputeStepReview,
                subtitle: l.disputeStepReviewBody,
                state: TimelineStepState.current,
              ),
              TimelineStep(
                title: l.disputeStepOutcome,
                subtitle: l.disputeStepOutcomeBody,
                state: TimelineStepState.upcoming,
              ),
            ],
          ),
          gap,
          Text(l.disputeDetailsTitle, style: sectionStyle),
          const SizedBox(height: AppSpace.s2),
          Text(d.description, style: theme.textTheme.bodyMedium),
          if (d.evidencePaths.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s2),
            _EvidenceGrid(paths: d.evidencePaths),
          ],
          gap,
        ] else if (outcome != null) ...[
          DisputeOutcomeCard(
            dispute: d,
            outcome: outcome,
            viewerIsCustomer: viewerIsCustomer,
          ),
          gap,
        ],
        Text(l.disputeThreadTitle, style: sectionStyle),
        if (!open) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            l.disputeThreadClosed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s1),
      ],
    );
  }
}

/// The disputed booking or ticket: thumbnail, status badge, title, and the
/// subtitle with the reason (mock `.card`).
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final d = dispute;
    final open = d.status == DisputeStatus.open;
    final reason = disputeReasonLabel(l, d.reason);
    final thumb = d.thumbUrl;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox.square(
                dimension: 48,
                child: thumb != null
                    ? NetworkPhoto(url: thumb)
                    : ColoredBox(
                        color: dark
                            ? AppColorsDark.surfaceMuted
                            : AppColors.surfaceMuted,
                        child: Center(
                          child: AppIcon(
                            d.subjectType == DisputeSubjectType.ticket
                                ? AppIcons.ticket
                                : AppIcons.camera,
                            size: 20,
                            color: dark
                                ? AppColorsDark.foregroundMuted
                                : AppColors.foregroundMuted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge.custom(
                    key: const Key('dispute-status'),
                    label: open ? l.disputeStatusOpen : l.disputeStatusResolved,
                    color: open
                        ? AppColors.bookingWaiting
                        : AppColors.bookingClosed,
                    onColor: AppColors.foregroundInverse,
                  ),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    d.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    d.subtitle.isEmpty ? reason : '${d.subtitle} · $reason',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Evidence photos in three square columns; a tap opens them full screen.
class _EvidenceGrid extends StatelessWidget {
  const _EvidenceGrid({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpace.s2;
    return LayoutBuilder(
      builder: (context, c) {
        final side = (c.maxWidth - 2 * gap) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < paths.length; i++)
              SizedBox.square(
                dimension: side,
                child: _EvidenceTile(
                  key: Key('dispute-evidence-$i'),
                  path: paths[i],
                  index: i,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) =>
                          _EvidenceViewer(paths: paths, initialIndex: i),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EvidenceTile extends ConsumerWidget {
  const _EvidenceTile({
    super.key,
    required this.path,
    required this.index,
    required this.onTap,
  });

  final String path;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      image: true,
      label: context.l10n.disputeEvidencePhoto(index + 1),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: AsyncView<String>(
              value: ref.watch(evidenceUrlProvider(path)),
              skeleton: (_) => AppSkeleton.box(
                width: double.infinity,
                height: double.infinity,
                radius: AppRadius.md,
              ),
              error: (_, _, _) =>
                  const Center(child: AppIcon(AppIcons.brokenImage, size: 24)),
              data: (_, url) => NetworkPhoto(url: url),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen evidence, swipe between photos, pinch to zoom.
class _EvidenceViewer extends StatefulWidget {
  const _EvidenceViewer({required this.paths, required this.initialIndex});

  final List<String> paths;
  final int initialIndex;

  @override
  State<_EvidenceViewer> createState() => _EvidenceViewerState();
}

class _EvidenceViewerState extends State<_EvidenceViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('dispute-evidence-viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.disputeEvidencePhoto(_index + 1)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Consumer(
              builder: (context, ref, _) => AsyncView<String>(
                value: ref.watch(evidenceUrlProvider(widget.paths[i])),
                error: (_, _, _) => const AppIcon(
                  AppIcons.brokenImage,
                  size: 48,
                  color: Colors.white54,
                ),
                data: (_, url) => NetworkPhoto(url: url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
