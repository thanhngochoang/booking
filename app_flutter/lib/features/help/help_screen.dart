import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/features/disputes/widgets/dispute_outcome_card.dart';
import 'package:photobooking/features/help/help_faq.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _selectedTopicId = 'payments';
  final Set<String> _expandedQuestions = {};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final topics = faqTopics(l);
    final currentTopic = topics.firstWhere(
      (t) => t.id == _selectedTopicId,
      orElse: () => topics.isNotEmpty
          ? topics.first
          : const FaqTopic(id: '', label: '', items: []),
    );
    final email = ref.watch(supportEmailProvider);

    return ScreenCode(
      ScreenCodes.help,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.helpTitle)),
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s3,
            ),
            children: [
              // "Khiếu nại của bạn" (#142): only when the user has disputes.
              const _MyDisputes(),

              // "Câu hỏi thường gặp" Section
              Text(
                l.helpFaqTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpace.s2),

              // Topic chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final topic in topics) ...[
                      AppChip(
                        key: Key('topic-chip-${topic.id}'),
                        label: topic.label,
                        selected: topic.id == _selectedTopicId,
                        onChanged: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedTopicId = topic.id;
                              _expandedQuestions.clear();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: AppSpace.s2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s3),

              // FAQ Question rows
              for (final item in currentTopic.items) ...[
                _buildFaqRow(context, item),
                const SizedBox(height: AppSpace.s2),
              ],

              const SizedBox(height: AppSpace.s4),

              // Contact support primary CTA
              AppButton.primary(
                l.helpContactSupport,
                key: const Key('help-contact-support'),
                icon: const AppIcon(AppIcons.supportAgent, size: 20),
                onPressed: () => context.push('/help/chat'),
              ),

              // Email support line if email configured
              if (email != null && email.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s3),
                Center(
                  child: InkWell(
                    key: const Key('help-support-email'),
                    onTap: () {
                      final uri = supportEmailUri(email);
                      if (uri != null) {
                        ref.read(externalLauncherProvider).open(uri);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s2,
                        vertical: AppSpace.s1,
                      ),
                      child: Text(
                        l.helpEmailLine(email),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqRow(BuildContext context, FaqItem item) {
    final isExpanded = _expandedQuestions.contains(item.question);

    return GlassCard(
      child: Semantics(
        expanded: isExpanded,
        button: true,
        label: item.question,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedQuestions.remove(item.question);
              } else {
                _expandedQuestions.add(item.question);
              }
            });
          },
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.question,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const AppIcon(AppIcons.expandMore, size: 20),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: AppSpace.s3),
                  Text(
                    item.answer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S18.03 "Khiếu nại của bạn": my latest disputes, newest first (one `get`).
/// Shown only when there is at least one; while loading or when the read
/// fails the section stays out, so the FAQ and "Liên hệ hỗ trợ" always work.
class _MyDisputes extends ConsumerWidget {
  const _MyDisputes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authStateProvider).value?.uid;
    return AsyncView<List<Dispute>>(
      value: ref.watch(myDisputesProvider),
      skeleton: (_) => const SizedBox.shrink(),
      error: (_, _, _) => const SizedBox.shrink(),
      isEmpty: (list) => list.isEmpty,
      empty: (_) => const SizedBox.shrink(),
      data: (context, list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.helpMyDisputes,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpace.s2),
          for (final d in list) ...[
            // The provider reads the booking; everyone else the receiver.
            _DisputeRow(dispute: d, viewerIsProvider: d.providerId == uid),
            const SizedBox(height: AppSpace.s2),
          ],
          const SizedBox(height: AppSpace.s2),
        ],
      ),
    );
  }
}

/// "Khiếu nại #K7Q2 · Minh Trí" / "Đang xem xét · 14/10" → S18.02.
class _DisputeRow extends StatelessWidget {
  const _DisputeRow({required this.dispute, required this.viewerIsProvider});

  final Dispute dispute;
  final bool viewerIsProvider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final d = dispute;
    // The customer sees who receives the money; the provider the booking.
    final name = viewerIsProvider ? d.title : disputeReceiverName(l, d);
    final status = d.status == DisputeStatus.open
        ? l.disputeStatusOpen
        : l.disputeStatusResolved;
    const radius = BorderRadius.all(Radius.circular(28));
    return GlassCard(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('help-dispute-${d.id}'),
          borderRadius: radius,
          onTap: () => context.push('/disputes/${d.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2h,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColorsDark.surfaceMuted
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s2),
                    child: AppIcon(
                      AppIcons.flag,
                      size: 20,
                      color: dark
                          ? AppColorsDark.foregroundSecondary
                          : AppColors.foregroundSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.helpDisputeRow(disputeCode(d.id), name),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l.helpDisputeRowMeta(
                          status,
                          formatDayMonth(toVn(d.createdAt)),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const AppIcon(AppIcons.chevron, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
