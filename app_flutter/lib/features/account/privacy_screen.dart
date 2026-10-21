import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/account/privacy_controller.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _exportLoading = false;
  bool? _localHidden;

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatTime(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  Future<void> _handleToggleHide(bool value) async {
    final prev = _localHidden;
    setState(() => _localHidden = value);
    try {
      await ref.read(privacyControllerProvider.notifier).setHidden(value);
    } catch (_) {
      if (mounted) {
        setState(() => _localHidden = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa lưu được, thử lại sau.')),
        );
      }
    }
  }

  Future<void> _handleCreateExport() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exportLoading = true);
    try {
      await ref.read(privacyControllerProvider.notifier).requestExport();
    } on AccountException catch (e) {
      if (!mounted) return;
      if (e.code == 'limit_exceeded') {
        messenger.showSnackBar(
          SnackBar(content: Text(l.privacyExportLimit)),
        );
      } else if (e.code == 'not_eligible') {
        messenger.showSnackBar(
          SnackBar(content: Text(l.privacyExportPending)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l.privacyExportFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.privacyExportFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportLoading = false);
      }
    }
  }

  Future<void> _handleDownload(String path) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = await ref.read(privacyControllerProvider.notifier).downloadUrl(path);
      await ref.read(externalLauncherProvider).open(uri);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không mở được liên kết tải xuống.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final isPhotographer = profile?.role == UserRole.photographer;
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;

    final exportAsync = ref.watch(dataExportProvider);
    final export = exportAsync.value;

    return ScreenCode(
      ScreenCodes.privacy,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(l.privacyTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              if (isPhotographer && uid != null) ...[
                // Section "Hồ sơ"
                Text(
                  l.privacyProfile,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                FutureBuilder<Map<String, PhotographerSummary>>(
                  future: ref.read(photographerRepositoryProvider).summaries([uid]),
                  builder: (context, snapshot) {
                    final summary = snapshot.data?[uid];
                    final serverHidden = summary?.hiddenFromDiscovery ?? false;
                    final isHidden = _localHidden ?? serverHidden;
                    return GlassCard(
                      highlight: false,
                      child: SwitchListTile(
                        key: const Key('privacy-hide-switch'),
                        title: Text(l.privacyHide),
                        subtitle: Text(l.privacyHideBody),
                        value: isHidden,
                        onChanged: _handleToggleHide,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpace.s6),
              ],

              // Section "Dữ liệu của bạn"
              Text(
                l.privacyData,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              GlassCard(
                highlight: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.privacyExport,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        l.privacyExportBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s3),
                      _buildExportStatus(context, export),
                      const SizedBox(height: AppSpace.s4),
                      _buildExportAction(context, export),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.privacyExportCooldown,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpace.s8),
              // Red text button "Xoá tài khoản"
              Center(
                child: TextButton(
                  key: const Key('privacy-delete-account-button'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () => context.push('/settings/delete-account'),
                  child: Text(
                    l.privacyDelete,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportStatus(BuildContext context, DataExport? export) {
    if (export == null) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isUsable = export.expiresAt.isAfter(now);
    if (!isUsable) return const SizedBox.shrink();

    final time = _formatTime(export.createdAt);
    final date = formatDayMonth(export.expiresAt);
    return Text(
      l.privacyExportReady(time, date),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildExportAction(BuildContext context, DataExport? export) {
    final l = context.l10n;
    final now = DateTime.now();
    final isUsable = export != null && export.expiresAt.isAfter(now);

    if (isUsable) {
      return AppButton.outline(
        l.privacyExportDownload,
        key: const Key('privacy-export-download-button'),
        icon: const AppIcon(AppIcons.download),
        size: AppButtonSize.small,
        onPressed: () => _handleDownload(export.path),
      );
    }

    return AppButton.outline(
      _exportLoading ? l.privacyExportCreating : l.privacyExportCreate,
      key: const Key('privacy-export-create-button'),
      loading: _exportLoading,
      size: AppButtonSize.small,
      onPressed: _exportLoading ? null : _handleCreateExport,
    );
  }
}
