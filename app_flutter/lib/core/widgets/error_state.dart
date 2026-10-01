import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';

/// A short Vietnamese message and, when there is something to retry, a
/// "Thử lại" button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
          const SizedBox(height: AppSpace.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              context.l10n.retry,
              key: const Key('error-retry'),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
