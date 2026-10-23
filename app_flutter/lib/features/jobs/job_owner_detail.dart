// lib/features/jobs/job_owner_detail.dart
//
// S15.02 Customer Job Detail Screen:
// - Header with status, Fraunces 21 title, posted meta
// - Three KPI StatTiles: Báo giá, Lượt xem, Đã mời
// - SectionHeader "Báo giá mới" + "Xem tất cả"
// - Two latest quotes
// - Outline button: "Mời thợ ảnh báo giá"
// - Footer primary: "So sánh {n} báo giá" (disabled with "Chưa có báo giá" at 0)
// - Popup menu: Sửa (only if 0 quotes), Gia hạn 7 ngày, Đóng việc
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/jobs/invite_sheet.dart';
import 'package:photobooking/features/jobs/job_entry.dart';

class JobOwnerDetail extends ConsumerStatefulWidget {
  const JobOwnerDetail({
    super.key,
    required this.job,
  });

  final Job job;

  @override
  ConsumerState<JobOwnerDetail> createState() => _JobOwnerDetailState();
}

class _JobOwnerDetailState extends ConsumerState<JobOwnerDetail> {
  @override
  void initState() {
    super.initState();
    // Reset newQuoteCount on open
    if (widget.job.newQuoteCount > 0) {
      Future.microtask(() {
        ref.read(jobRepositoryProvider).markQuotesSeen(widget.job.id);
      });
    }
  }

  Future<void> _extendJob() async {
    final l = context.l10n;
    final repo = ref.read(jobRepositoryProvider);
    try {
      final newDeadline = await repo.extendJob(widget.job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.jobExtendedToast(formatDay(newDeadline)))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.jobExtendNotEligible)),
        );
      }
    }
  }

  Future<void> _closeJob() async {
    final l = context.l10n;
    final repo = ref.read(jobRepositoryProvider);

    // If job has active checkout
    final now = ref.read(clockProvider)();
    if (widget.job.checkout != null && widget.job.checkout!.expiresAt.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.jobInCheckout)),
      );
      return;
    }

    final confirmed = await showConfirmSheet(
      context,
      title: l.jobCloseTitle,
      body: l.jobCloseBody(widget.job.quoteCount),
      confirmLabel: l.jobClose,
      keepLabel: l.actionCancel,
      danger: true,
      onConfirm: () async {
        await repo.closeJob(widget.job.id);
      },
    );

    if (confirmed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.jobClosedToast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final job = widget.job;
    final quotesAsync = ref.watch(jobQuotesProvider(job.id));
    final specialty = specialtyLabel(job.specialtyId);
    final isOpen = job.status == JobStatus.open;
    final isClosedOrExpired = job.status == JobStatus.closed || job.status == JobStatus.expired;

    final quotes = quotesAsync.value ?? const [];
    final submittedQuotes = quotes.where((q) => q.status == QuoteStatus.submitted).toList();

    return ScreenCode(
      ScreenCodes.myJobs,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const AppIcon(AppIcons.back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (isOpen)
              PopupMenuButton<String>(
                icon: const AppIcon(AppIcons.more),
                onSelected: (val) {
                  if (val == 'edit') {
                    context.push('/jobs/new?edit=${job.id}');
                  } else if (val == 'extend') {
                    _extendJob();
                  } else if (val == 'close') {
                    _closeJob();
                  }
                },
                itemBuilder: (ctx) => [
                  if (job.quoteCount == 0)
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l.jobMenuEdit),
                    ),
                  if (!job.extended)
                    PopupMenuItem(
                      value: 'extend',
                      child: Text(l.jobExtend),
                    ),
                  PopupMenuItem(
                    value: 'close',
                    child: Text(
                      l.jobClose,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            specialty,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        StatusBadge(
                          job.status == JobStatus.open
                              ? BookingStatus.requested
                              : (job.status == JobStatus.awarded
                                  ? BookingStatus.accepted
                                  : BookingStatus.cancelled),
                          label: job.status == JobStatus.open
                              ? l.jobStatusOpen
                              : (job.status == JobStatus.awarded
                                  ? l.jobStatusAwarded
                                  : l.jobStatusClosed),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      l.jobPostedOn(
                        formatDay(job.createdAt),
                        job.quoteDeadline.difference(job.createdAt).inDays,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.foregroundSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    StatTileRow(
                      tiles: [
                        StatTile(
                          value: job.quoteCount.toString(),
                          label: l.jobStatQuotes,
                        ),
                        StatTile(
                          value: job.viewCount.toString(),
                          label: l.jobViews,
                        ),
                        StatTile(
                          value: job.inviteCount.toString(),
                          label: l.jobInvitedCount,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.jobLatest,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (submittedQuotes.length > 2)
                          TextButton(
                            onPressed: () => context.push('/jobs/${job.id}/applications'),
                            child: Text(l.jobSeeAll),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s2),
                    if (submittedQuotes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
                        child: Text(
                          l.jobCompareNone,
                          style: const TextStyle(color: AppColors.foregroundSecondary),
                        ),
                      )
                    else
                      ...submittedQuotes.take(2).map((q) => _buildQuoteRow(q)),
                    const SizedBox(height: AppSpace.s4),
                    if (isOpen)
                      Center(
                        child: AppButton.outline(
                          l.jobInvite,
                          onPressed: () async {
                            final invited = await ref.read(jobRepositoryProvider).invitedIds(job.id);
                            final quoted = quotes.map((q) => q.photographerId).toList();
                            if (context.mounted) {
                              showInviteSheet(
                                context,
                                job: job,
                                alreadyInvitedIds: invited,
                                quotedPhotographerIds: quoted,
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: isClosedOrExpired
                    ? AppButton.primary(
                        l.jobRepost,
                        onPressed: () => startJobPost(context, ref, fromJobId: job.id),
                      )
                    : AppButton.primary(
                        submittedQuotes.isNotEmpty
                            ? l.jobCompare(submittedQuotes.length)
                            : l.jobCompareNone,
                        onPressed: submittedQuotes.isNotEmpty
                            ? () => context.push('/jobs/${job.id}/applications')
                            : null,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteRow(Quote quote) {
    final markKind = providerMarkOf(
      type: quote.photographer.providerType,
      verified: quote.photographer.verified,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s2),
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          AppAvatar(
            url: quote.photographer.avatarUrl,
            name: quote.photographer.name,
            size: AppAvatarSize.sm,
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        quote.photographer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (markKind != null) ...[
                      const SizedBox(width: AppSpace.s1),
                      ProviderMark(markKind),
                    ],
                  ],
                ),
                Text(
                  '${quote.terms.editedCount} ảnh chỉnh · giao ${quote.terms.deliveryDays} ngày',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.foregroundSecondary,
                      ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(quote.terms.price, short: true),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
