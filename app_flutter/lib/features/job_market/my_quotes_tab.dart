// lib/features/job_market/my_quotes_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

class MyQuotesTab extends ConsumerWidget {
  const MyQuotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final quotesAsync = ref.watch(myQuotesProvider);

    return ScreenCode(
      ScreenCodes.openJobs,
      label: 'quotes',
      child: AsyncView<List<Quote>>(
        value: quotesAsync,
        data: (context, quotes) {
          if (quotes.isEmpty) {
            return EmptyState(
              title: l.myQuotesEmpty,
            );
          }

          final pending = quotes.where((q) => q.status == QuoteStatus.submitted).toList();
          final chosen = quotes.where((q) => q.status == QuoteStatus.accepted).toList();
          final notChosen = quotes.where((q) => q.status == QuoteStatus.notSelected || q.status == QuoteStatus.declined).toList();
          final withdrawn = quotes.where((q) => q.status == QuoteStatus.withdrawn).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionHeader(l.myQuotesPending, pending.length, theme),
                for (final q in pending) _buildQuoteCard(context, q, l, theme),
                const SizedBox(height: AppSpace.s3),
              ],
              if (chosen.isNotEmpty) ...[
                _buildSectionHeader(l.myQuotesChosen, chosen.length, theme),
                for (final q in chosen) _buildQuoteCard(context, q, l, theme),
                const SizedBox(height: AppSpace.s3),
              ],
              if (notChosen.isNotEmpty) ...[
                _buildSectionHeader(l.myQuotesNotChosen, notChosen.length, theme),
                for (final q in notChosen) _buildQuoteCard(context, q, l, theme, opacity: 0.6),
                const SizedBox(height: AppSpace.s3),
              ],
              if (withdrawn.isNotEmpty) ...[
                _buildSectionHeader(l.myQuotesWithdrawn, withdrawn.length, theme),
                for (final q in withdrawn) _buildQuoteCard(context, q, l, theme, opacity: 0.6),
                const SizedBox(height: AppSpace.s3),
              ],
            ],
          );
        },
        error: (_, err, _) => Center(child: Text(err.toString())),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            count.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(
    BuildContext context,
    Quote quote,
    dynamic l,
    ThemeData theme, {
    double opacity = 1.0,
  }) {
    final dark = theme.brightness == Brightness.dark;
    final isAccepted = quote.status == QuoteStatus.accepted;
    final isAuto = quote.autoWithdrawn;
    final isNotChosen = quote.status == QuoteStatus.notSelected || quote.status == QuoteStatus.declined;

    String subtitle = quote.proposal.day;
    if (isAuto) {
      subtitle = l.myQuotesAuto as String;
    } else if (isNotChosen) {
      subtitle = '${quote.proposal.day} · Khách đã chọn thợ khác';
    }

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s2),
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dark ? AppColorsDark.glass : AppColors.glass,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  specialtyLabel('ky_yeu'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dark ? AppColorsDark.foreground : AppColors.foreground,
                  ),
                ),
              ),
              if (isAccepted)
                const Text(
                  'Mở buổi chụp →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              else
                Text(
                  formatMoney(quote.terms.price, short: true),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            quote.jobTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isAuto ? AppColors.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final wrappedCard = opacity < 1.0
        ? Opacity(opacity: opacity, child: cardContent)
        : cardContent;

    return InkWell(
      key: Key('quote-item-${quote.id}'),
      onTap: () {
        if (isAccepted && quote.bookingId != null) {
          context.push('/b/${quote.bookingId}');
        } else {
          context.push('/jobs/${quote.jobId}');
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: wrappedCard,
    );
  }
}
