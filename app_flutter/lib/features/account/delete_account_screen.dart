import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/account/delete_account_controller.dart';
import 'package:photobooking/features/account/widgets/reauth_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;

  Future<void> _handleDelete() async {
    final l = context.l10n;
    final confirmed = await showConfirmSheet(
      context,
      title: l.deleteConfirmTitle,
      body: l.deleteConfirmBody,
      confirmLabel: l.deleteAction,
      keepLabel: l.deleteConfirmKeep,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    final ctrl = ref.read(deleteAccountControllerProvider.notifier);

    DateTime? restoreUntil;
    try {
      restoreUntil = await ctrl.requestDeletion();
    } on AccountException catch (e) {
      if (e.code == 'reauth_required') {
        if (!mounted) return;
        final reauthed = await showReauthSheet(context);
        if (reauthed && mounted) {
          try {
            restoreUntil = await ctrl.requestDeletion();
          } on AccountException catch (e2) {
            if (!mounted) return;
            if (e2.code == 'conflict') {
              await ctrl.reload();
            } else {
              messenger.showSnackBar(
                SnackBar(content: Text(l.deleteAccountFailed)),
              );
            }
          }
        }
      } else if (e.code == 'conflict') {
        await ctrl.reload();
      } else {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.deleteAccountFailed)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.deleteAccountFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (restoreUntil != null && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      final dateStr = formatDayMonth(restoreUntil);
      messenger.showSnackBar(
        SnackBar(content: Text(l.deleteAccountDone(dateStr))),
      );
      router.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final blockersAsync = ref.watch(deleteAccountControllerProvider);

    return ScreenCode(
      ScreenCodes.deleteAccount,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(l.deleteAccountTitle),
          ),
          body: blockersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.deleteAccountFailed),
                  const SizedBox(height: AppSpace.s2),
                  AppButton.outline(
                    'Thử lại',
                    onPressed: () =>
                        ref.read(deleteAccountControllerProvider.notifier).reload(),
                  ),
                ],
              ),
            ),
            data: (blockers) {
              final hasBlockers = blockers.isNotEmpty;
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(deleteAccountControllerProvider.notifier).reload(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  children: [
                    if (hasBlockers) ...[
                      // Warning card (red-tinted)
                      Container(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: theme.colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  AppIcons.warning,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: AppSpace.s2),
                                Expanded(
                                  child: Text(
                                    l.deleteBlockedTitle,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.s1),
                            Text(
                              l.deleteBlockedBody,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      // GlassCard list of blocker rows
                      GlassCard(
                        highlight: false,
                        child: Column(
                          children: [
                            for (var i = 0; i < blockers.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _BlockerTile(blocker: blockers[i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s6),
                    ],

                    // Section "Khi xoá tài khoản"
                    Text(
                      l.deleteConsequencesTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    _ConsequenceItem(number: '1', text: l.deleteConsequence1),
                    _ConsequenceItem(number: '2', text: l.deleteConsequence2),
                    _ConsequenceItem(number: '3', text: l.deleteConsequence3),
                    _ConsequenceItem(number: '4', text: l.deleteConsequence4),
                    _ConsequenceItem(number: '5', text: l.deleteConsequence5),

                    if (!hasBlockers) ...[
                      const SizedBox(height: AppSpace.s6),
                      // Export hint
                      Center(
                        child: Column(
                          children: [
                            Text(
                              l.deleteExportHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpace.s1),
                            GestureDetector(
                              onTap: () => context.push('/settings/privacy'),
                              child: Text(
                                l.deleteExportHintLink,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpace.s8),
                    // Action button: outline disabled if hasBlockers, enabled if none
                    AppButton.outline(
                      l.deleteAction,
                      key: const Key('delete-account-button'),
                      loading: _busy,
                      onPressed: hasBlockers ? null : _handleDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                          color: hasBlockers
                              ? theme.disabledColor
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConsequenceItem extends StatelessWidget {
  const _ConsequenceItem({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockerTile extends StatelessWidget {
  const _BlockerTile({required this.blocker});
  final DeletionBlocker blocker;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, title, subtitle, path) = _resolve(l);

    return ListTile(
      leading: AppIcon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const AppIcon(AppIcons.chevron),
      onTap: path != null ? () => context.push(path) : null,
    );
  }

  (IconData icon, String title, String? subtitle, String? path) _resolve(AppLocalizations l) {
    final first = blocker.first;
    final amountFormatted = blocker.amount != null ? formatMoney(blocker.amount!) : '';

    return switch (blocker.kind) {
      BlockerKind.openBooking => (
          AppIcons.calendar,
          l.deleteBlockBooking(blocker.count),
          first != null
              ? '${first.title}${first.day != null ? ' · ${first.day}' : ''}'
              : null,
          first != null ? '/b/${first.id}' : null,
        ),
      BlockerKind.openJob => (
          AppIcons.calendar,
          l.deleteBlockJob(blocker.count),
          first != null
              ? '${first.title}${first.day != null ? ' · ${first.day}' : ''}'
              : null,
          first != null ? '/b/${first.id}' : null,
        ),
      BlockerKind.openJobPost => (
          AppIcons.work,
          l.deleteBlockJobPost(blocker.count),
          first != null ? first.title : l.deleteBlockJobPostBody,
          first != null ? '/jobs/${first.id}' : null,
        ),
      BlockerKind.openQuote => (
          AppIcons.work,
          l.deleteBlockQuote(blocker.count),
          first != null ? first.title : l.deleteBlockQuoteBody,
          first != null ? '/jobs/${first.id}' : null,
        ),
      BlockerKind.activeInstant => (
          AppIcons.instant,
          l.deleteBlockInstant(blocker.count),
          first?.title,
          first != null ? '/instant/${first.id}' : null,
        ),
      BlockerKind.studioMembership => (
          AppIcons.people,
          l.deleteBlockStudio(blocker.count),
          first != null ? first.title : l.deleteBlockStudioBody,
          '/studio/members',
        ),
      BlockerKind.openCollab => (
          AppIcons.people,
          l.deleteBlockCollab(blocker.count),
          first != null ? first.title : l.deleteBlockCollabBody,
          '/collab',
        ),
      BlockerKind.liveTicket => (
          AppIcons.ticket,
          l.deleteBlockTicket(blocker.count),
          first != null
              ? '${first.title}${first.day != null ? ' · ${first.day}' : ''}'
              : null,
          '/events',
        ),
      BlockerKind.hostedEvent => (
          AppIcons.celebration,
          l.deleteBlockEvent(blocker.count),
          first != null
              ? '${first.title}${first.day != null ? ' · ${first.day}' : ''}'
              : null,
          first != null ? '/events/${first.id}/manage' : null,
        ),
      BlockerKind.openDispute => (
          AppIcons.warning,
          l.deleteBlockDispute(blocker.count),
          first?.title,
          null,
        ),
      BlockerKind.heldPayment => (
          AppIcons.receipt,
          l.deleteBlockHeld(amountFormatted),
          l.deleteBlockHeldBody,
          '/me/payments',
        ),
      BlockerKind.refundInProgress => (
          AppIcons.receipt,
          l.deleteBlockRefund(amountFormatted),
          l.deleteBlockRefundBody,
          '/me/payments',
        ),
      BlockerKind.unpaidEarnings => (
          AppIcons.receipt,
          l.deleteBlockEarnings(amountFormatted),
          l.deleteBlockEarningsBody,
          '/work/earnings',
        ),
    };
  }
}
