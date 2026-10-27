// lib/features/jobs/quotes_screen.dart
//
// Screen comparing quotes for a job (S15.03).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/features/jobs/invite_sheet.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({
    super.key,
    required this.jobId,
  });

  final String jobId;

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  bool _resetAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_resetAttempted && mounted) {
        _resetAttempted = true;
        ref.read(jobRepositoryProvider).markQuotesSeen(widget.jobId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final jobAsync = ref.watch(jobProvider(widget.jobId));
    final quotesAsync = ref.watch(jobQuotesProvider(widget.jobId));
    final sortedQuotes = ref.watch(sortedQuotesProvider(widget.jobId));
    final currentSort = ref.watch(quotesSortProvider(widget.jobId));
    final savedQuotes = ref.watch(savedQuotesProvider(widget.jobId));

    DateTime now;
    try {
      now = ref.watch(clockProvider)();
    } catch (_) {
      now = DateTime.now().toUtc();
    }

    final allQuotes = quotesAsync.value ?? const [];
    final submittedCount = allQuotes.where((q) => q.status == QuoteStatus.submitted).length;

    return ScreenCode(
      ScreenCodes.jobApplications,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.quotesTitle(submittedCount)),
        ),
        body: jobAsync.when(
          data: (job) {
            if (job == null) {
              return const Center(child: Text('Không tìm thấy công việc'));
            }
            return _buildBody(
              context,
              job: job,
              allQuotes: allQuotes,
              sortedQuotes: sortedQuotes,
              currentSort: currentSort,
              savedQuotes: savedQuotes,
              now: now,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Lỗi: $err')),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required Job job,
    required List<Quote> allQuotes,
    required List<Quote> sortedQuotes,
    required QuoteSort currentSort,
    required Set<String> savedQuotes,
    required DateTime now,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sort chips row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s2,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip(
                  label: l.quotesSortFit,
                  selected: currentSort == QuoteSort.fit,
                  onSelected: () => ref
                      .read(quotesSortProvider(widget.jobId).notifier)
                      .setSort(QuoteSort.fit),
                  accentOnSelected: true,
                  isDark: isDark,
                ),
                const SizedBox(width: AppSpace.s2),
                _buildSortChip(
                  label: l.quotesSortPrice,
                  selected: currentSort == QuoteSort.price,
                  onSelected: () => ref
                      .read(quotesSortProvider(widget.jobId).notifier)
                      .setSort(QuoteSort.price),
                  isDark: isDark,
                ),
                const SizedBox(width: AppSpace.s2),
                _buildSortChip(
                  label: l.quotesSortRating,
                  selected: currentSort == QuoteSort.rating,
                  onSelected: () => ref
                      .read(quotesSortProvider(widget.jobId).notifier)
                      .setSort(QuoteSort.rating),
                  isDark: isDark,
                ),
                const SizedBox(width: AppSpace.s2),
                _buildSortChip(
                  label: l.quotesSaved,
                  selected: currentSort == QuoteSort.saved,
                  onSelected: () => ref
                      .read(quotesSortProvider(widget.jobId).notifier)
                      .setSort(QuoteSort.saved),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildQuotesList(
            context,
            job: job,
            allQuotes: allQuotes,
            sortedQuotes: sortedQuotes,
            currentSort: currentSort,
            savedQuotes: savedQuotes,
            now: now,
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    bool accentOnSelected = false,
    required bool isDark,
  }) {
    Color? selectedColor;
    Color? labelColor;

    if (selected) {
      if (accentOnSelected) {
        selectedColor = isDark ? AppColorsDark.accent : AppColors.accent;
        labelColor = isDark ? AppColorsDark.accentForeground : AppColors.accentForeground;
      } else {
        selectedColor = isDark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
        labelColor = isDark ? AppColorsDark.foreground : AppColors.foreground;
      }
    }

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedColor: selectedColor,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildQuotesList(
    BuildContext context, {
    required Job job,
    required List<Quote> allQuotes,
    required List<Quote> sortedQuotes,
    required QuoteSort currentSort,
    required Set<String> savedQuotes,
    required DateTime now,
  }) {
    final l = context.l10n;
    if (allQuotes.isEmpty) {
      return EmptyState(
        title: l.quotesEmptyTitle,
        actionLabel: l.jobInvite,
        onAction: () async {
          final invited = await ref.read(jobRepositoryProvider).invitedIds(job.id);
          final quoted = allQuotes.map((q) => q.photographerId).toList();
          if (context.mounted) {
            showInviteSheet(
              context,
              job: job,
              alreadyInvitedIds: invited,
              quotedPhotographerIds: quoted,
            );
          }
        },
      );
    }

    if (currentSort == QuoteSort.saved && sortedQuotes.isEmpty) {
      return EmptyState(
        title: l.quotesSavedEmpty,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.s4),
      itemCount: sortedQuotes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
      itemBuilder: (context, index) {
        final quote = sortedQuotes[index];
        final isSaved = savedQuotes.contains(quote.id);
        final cardData = quoteCardOf(quote, job, saved: isSaved, now: now, l: l);

        return QuoteCard(
          data: cardData,
          onView: () {
            context.push('/jobs/${widget.jobId}/applications/${quote.photographerId}');
          },
          onToggleSave: () {
            ref.read(savedQuotesProvider(widget.jobId).notifier).toggle(quote.id);
          },
        );
      },
    );
  }
}
