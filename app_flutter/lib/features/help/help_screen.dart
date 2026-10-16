import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/app_config.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/support/support_providers.dart';
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
    final topics = l != null ? faqTopics(l) : const <FaqTopic>[];
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
          appBar: AppBar(
            title: Text(l?.helpTitle ?? 'Trợ giúp'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s3,
            ),
            children: [
              // Slot for "Khiếu nại của bạn" (#142 fills this; empty in #204)

              // "Câu hỏi thường gặp" Section
              Text(
                l?.helpFaqTitle ?? 'Câu hỏi thường gặp',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                l?.helpContactSupport ?? 'Liên hệ hỗ trợ',
                key: const Key('help-contact-support'),
                icon: AppIcons.supportAgent,
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
                        l?.helpEmailLine(email) ?? 'Email hỗ trợ: $email',
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const AppIcon(
                        AppIcons.expandMore,
                        size: 20,
                      ),
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
