// lib/features/jobs/quote_detail_screen.dart
//
// Screen for viewing a quote's details (S15.04) with swipe navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/jobs/decline_quote_sheet.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({
    super.key,
    required this.jobId,
    required this.initialPhotographerId,
  });

  final String jobId;
  final String initialPhotographerId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _initializedPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final jobAsync = ref.watch(jobProvider(widget.jobId));
    final sortedQuotes = ref.watch(sortedQuotesProvider(widget.jobId));

    if (!_initializedPage && sortedQuotes.isNotEmpty) {
      final index = sortedQuotes.indexWhere(
        (q) => q.photographerId == widget.initialPhotographerId || q.id == widget.initialPhotographerId,
      );
      if (index >= 0) {
        _currentIndex = index;
        _pageController = PageController(initialPage: index);
      }
      _initializedPage = true;
    }

    return ScreenCode(
      ScreenCodes.applicationDetail,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            sortedQuotes.isNotEmpty
                ? l.quoteCounter(_currentIndex + 1, sortedQuotes.length)
                : '',
          ),
          actions: [
            if (sortedQuotes.isNotEmpty && _currentIndex < sortedQuotes.length)
              PopupMenuButton<String>(
                icon: const AppIcon(AppIcons.more),
                onSelected: (val) async {
                  if (val == 'decline') {
                    final quote = sortedQuotes[_currentIndex];
                    final confirmed = await showDeclineQuoteSheet(
                      context,
                      jobId: widget.jobId,
                      photographerId: quote.photographerId,
                    );
                    if (confirmed && context.mounted) {
                      context.pop();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'decline',
                    child: Text(
                      l.quoteDecline,
                      style: const TextStyle(color: AppColors.destructive),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: jobAsync.when(
          data: (job) {
            if (job == null) {
              return const Center(child: Text('Không tìm thấy công việc'));
            }
            if (sortedQuotes.isEmpty) {
              return Center(child: Text(l.quotesEmptyTitle));
            }

            return PageView.builder(
              controller: _pageController,
              itemCount: sortedQuotes.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, idx) {
                final quote = sortedQuotes[idx];
                return _buildQuoteView(context, job: job, quote: quote);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Lỗi: $err')),
        ),
      ),
    );
  }

  Widget _buildQuoteView(
    BuildContext context, {
    required Job job,
    required Quote quote,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = isDark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;

    final p = quote.photographer;
    final markKind = providerMarkOf(
      type: p.providerType,
      verified: p.verified,
      businessVerified: p.providerType == ProviderType.studio,
    );

    // Price & budget
    final price = quote.terms.price;
    final fitResult = budgetFit(price, job.budget);
    String budgetNoteText = '';
    Color? budgetColor;
    if (fitResult.fit == BudgetFit.inBudget) {
      budgetNoteText = l.quoteInBudget;
      budgetColor = isDark ? AppColorsDark.freeInk : AppColors.freeInk;
    } else if (fitResult.fit == BudgetFit.over) {
      final overAmount = fitResult.over >= 1000000
          ? formatMoney(fitResult.over, short: true)
          : '${(fitResult.over / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
      budgetNoteText = l.quoteOverBudget(overAmount);
      budgetColor = isDark ? AppColorsDark.warning : AppColors.warning;
    }

    // Milestones
    final milestones = milestoneAmountsOf(price);
    final milestoneLines = [
      MilestoneLine(
        title: l.quoteM1,
        subtitle: l.quoteM1Sub,
        amountVnd: milestones.shoot,
      ),
      MilestoneLine(
        title: l.quoteM2,
        subtitle: l.quoteM2Sub(3),
        amountVnd: milestones.delivery,
      ),
    ];

    // Deliverables grid (4 tiles: ảnh chỉnh, ảnh gốc, ngày giao, lần sửa)
    final deliverableItems = [
      DeliverableItem(
        label: l.quoteTileEdited,
        value: quote.terms.editedCount > 0 ? '${quote.terms.editedCount}' : '—',
      ),
      DeliverableItem(
        label: l.quoteTileRaw,
        value: quote.terms.photoCount != null && quote.terms.photoCount! > 0
            ? '${quote.terms.photoCount}'
            : '—',
      ),
      DeliverableItem(
        label: l.quoteTileDays,
        value: quote.terms.deliveryDays > 0 ? '${quote.terms.deliveryDays}' : '—',
      ),
      DeliverableItem(
        label: l.quoteTileRevisions,
        value: quote.terms.revisions > 0 ? '${quote.terms.revisions}' : '—',
      ),
    ];

    // Status check for action
    final isWithdrawn = quote.status == QuoteStatus.withdrawn;
    final isJobClosed = job.status != JobStatus.open;
    final isDisabled = isWithdrawn || isJobClosed;
    String? disabledReason;
    if (isWithdrawn) {
      disabledReason = l.quoteUnavailableWithdrawn;
    } else if (isJobClosed) {
      disabledReason = l.quoteUnavailableClosed;
    }

    final formattedPrice = formatMoney(price);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provider row
            Row(
              children: [
                AppAvatar(
                  url: p.avatarUrl,
                  name: p.name,
                  size: AppAvatarSize.md,
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
                              p.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (markKind != null) ...[
                            const SizedBox(width: 4),
                            ProviderMark(markKind),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '🍅 ${(p.score * 100).round()}% · ${p.reviewCount} đánh giá',
                        style: TextStyle(
                          fontSize: 12,
                          color: fgSec,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton.outline(
                  l.quoteProfile,
                  onPressed: () => context.push('/u/${quote.photographerId}'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),

            // Price card
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpace.s2,
                      children: [
                        Text(
                          formattedPrice,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        if (budgetNoteText.isNotEmpty)
                          Text(
                            budgetNoteText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: budgetColor ?? fgSec,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s3),
                    MilestoneTable(lines: milestoneLines),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),

            // Deliverables grid
            DeliverableChips(items: deliverableItems, grid: true),
            const SizedBox(height: AppSpace.s4),

            // Message bubble
            if (quote.message.isNotEmpty) ...[
              ChatBubble(
                content: TextContent(quote.message),
                mine: false,
              ),
              const SizedBox(height: AppSpace.s4),
            ],

            // Attached album row
            if (quote.album != null && quote.albumId != null) ...[
              InkWell(
                onTap: () {
                  context.push('/u/${quote.photographerId}/albums/${quote.albumId!}');
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.s3),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.image, size: 20),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.quoteAlbum(quote.album!.title),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              l.quoteAlbumSub(quote.album!.postCount),
                              style: TextStyle(fontSize: 12, color: fgSec),
                            ),
                          ],
                        ),
                      ),
                      const AppIcon(AppIcons.forward, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s4),
            ],

            // Escrow info note
            Text(
              l.quoteEscrow(formattedPrice),
              style: TextStyle(
                fontSize: 12,
                color: fgSec,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpace.s6),
          ],
        ),
      ),
      bottomNavigationBar: AppFooterBar(
        child: Row(
          children: [
            IconButton(
              icon: const AppIcon(AppIcons.chat),
              tooltip: l.quoteAsk,
              onPressed: () async {
                try {
                  final chatId = await ref
                      .read(jobRepositoryProvider)
                      .openInquiry(widget.jobId, photographerId: quote.photographerId);
                  if (context.mounted) {
                    context.push('/chat/$chatId');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: isDisabled
                  ? AppButton.outline(
                      disabledReason ?? '',
                      onPressed: null,
                    )
                  : AppButton.primary(
                      l.quoteChoose(formattedPrice),
                      onPressed: () async {
                        // Check phone first
                        final contactHold = ref.listenManual(currentContactProvider, (_, _) {});
                        Object? contact;
                        try {
                          contact = await ref.read(currentContactProvider.future);
                        } catch (_) {
                          contact = null;
                        } finally {
                          contactHold.close();
                        }

                        if (!context.mounted) return;

                        final checkoutPath = '/jobs/${widget.jobId}/applications/${quote.photographerId}/pay';
                        if (contact == null) {
                          context.push('/profile/phone?returnTo=${Uri.encodeComponent(checkoutPath)}');
                          return;
                        }

                        context.push(checkoutPath);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
