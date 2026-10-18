import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';

class OriginalsCard extends StatelessWidget {
  const OriginalsCard({
    super.key,
    required this.photoCount,
    required this.isApproved,
    required this.linkHost,
    this.rawLink,
    this.providerName,
    this.submittedDate,
    this.onOpenLink,
  });

  final int photoCount;
  final bool isApproved;
  final String linkHost;
  final String? rawLink;
  final String? providerName;
  final String? submittedDate;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cardBorder = dark ? AppColorsDark.border : AppColors.border;
    final cardBg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final textMuted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;
    final accent = dark ? AppColorsDark.primary : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(
                isApproved ? AppIcons.link : AppIcons.lock,
                size: 20,
                color: isApproved ? accent : textMuted,
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  l10n.deliveryOriginalsCardTitle(photoCount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          if (isApproved && providerName != null && submittedDate != null) ...[
            Text(
              l10n.deliveryOriginalsSubApproved(providerName!, submittedDate!),
              style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
          // Link chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.link,
                  size: 16,
                  color: isApproved ? accent : textMuted,
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    isApproved && rawLink != null && rawLink!.isNotEmpty
                        ? rawLink!
                        : '$linkHost/••••••••',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isApproved ? null : textMuted,
                      fontFamily: isApproved ? null : 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          if (!isApproved) ...[
            Text(
              l10n.deliveryOriginalsLocked,
              style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
            ),
          ] else ...[
            const SizedBox(height: AppSpace.s2),
            AppButton.outline(
              l10n.deliveryOriginalsOpen,
              size: AppButtonSize.small,
              onPressed: onOpenLink,
            ),
          ],
        ],
      ),
    );
  }
}
