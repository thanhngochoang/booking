import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/features/account/restore_account_controller.dart';

class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key});

  @override
  ConsumerState<RestoreAccountScreen> createState() => _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  bool _busy = false;

  Future<void> _handleRestore() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(restoreAccountControllerProvider.notifier).restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.restoreAccountDone)),
      );
      context.go('/');
    } on AccountException catch (e) {
      if (!mounted) return;
      if (e.code == 'deadline_passed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.restoreAccountExpired)),
        );
        await ref.read(authRepositoryProvider).signOut();
        if (mounted) context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.restoreAccountFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.restoreAccountFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _handleDownload(String path) async {
    try {
      final uri = await ref.read(accountRepositoryProvider).exportDownloadUrl(path);
      await ref.read(externalLauncherProvider).open(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được liên kết tải xuống.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    final lock = ref.watch(accountLockProvider).value;
    final dateStr = lock?.restoreUntil != null ? formatDayMonth(lock!.restoreUntil) : '';

    final export = ref.watch(dataExportProvider).value;
    final hasUsableExport = export != null && export.expiresAt.isAfter(DateTime.now());

    return ScreenCode(
      ScreenCodes.restoreAccount,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s6, vertical: AppSpace.s4),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          // Large AppIcons.restore in a circle
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                            ),
                            child: Center(
                              child: Icon(
                                AppIcons.restore,
                                size: 40,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s6),
                          Text(
                            l.restoreAccountTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpace.s3),
                          Text(
                            l.restoreAccountBody(dateStr),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (hasUsableExport) ...[
                            const SizedBox(height: AppSpace.s4),
                            GlassCard(
                              highlight: false,
                              child: ListTile(
                                leading: const AppIcon(AppIcons.download),
                                title: Text(l.restoreAccountExport),
                                trailing: const AppIcon(AppIcons.chevron),
                                onTap: () => _handleDownload(export.path),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Primary button: Khôi phục tài khoản
                          AppButton.primary(
                            l.restoreAccountAction,
                            key: const Key('restore-account-button'),
                            loading: _busy,
                            onPressed: _busy ? null : _handleRestore,
                          ),
                          const SizedBox(height: AppSpace.s2),
                          // Text button: Tiếp tục xoá
                          TextButton(
                            key: const Key('restore-continue-delete-button'),
                            onPressed: _busy ? null : _handleSignOut,
                            child: Text(
                              l.restoreAccountContinue,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s1),
                          Text(
                            l.restoreAccountContinueNote(dateStr),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpace.s4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
