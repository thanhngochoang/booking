import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Maps known error codes (FirebaseException, BookingException) and network
/// errors to localized user-facing messages.
String errorMessage(Object error, AppLocalizations l) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' || 'network-request-failed' => l.authErrorNetwork,
      _ => l.authErrorUnknown,
    };
  }
  if (error is SocketException || error is TimeoutException) {
    return l.authErrorNetwork;
  }
  final str = error.toString();
  final lower = str.toLowerCase();
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('timeout') ||
      lower.contains('offline') ||
      lower.contains('connection')) {
    return l.authErrorNetwork;
  }
  if (str.startsWith('BookingException(')) {
    final code = str.substring('BookingException('.length, str.length - 1);
    return switch (code) {
      'network' || 'unavailable' => l.authErrorNetwork,
      _ => l.authErrorUnknown,
    };
  }
  return l.authErrorUnknown;
}

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
