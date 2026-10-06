// lib/features/earnings/widgets/reauth_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_error.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

/// Asks the user to sign in again before the payout account changes: the
/// password for email accounts, the provider flow for Google and Facebook.
/// True after a successful re-authentication; false when the sheet is closed
/// without one (the caller keeps what the user typed).
///
/// Dragging down is off because the sheet holds a text field; the barrier tap
/// and Back still close it (nothing is lost: only a password was typed).
Future<bool> showReauthSheet(BuildContext context) async {
  final done = await showAppSheet<bool>(
    context,
    enableDrag: false,
    builder: (_) => const _ReauthBody(),
  );
  return done ?? false;
}

class _ReauthBody extends ConsumerStatefulWidget {
  const _ReauthBody();

  @override
  ConsumerState<_ReauthBody> createState() => _ReauthBodyState();
}

class _ReauthBodyState extends ConsumerState<_ReauthBody> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _go(bool usesPassword) async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .reauthenticate(password: usesPassword ? _password.text : null);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final error = mapAuthException(e);
      setState(() {
        _busy = false;
        // Backing out of the provider's own screen is not an error.
        _error = switch (error) {
          AuthError.cancelled => null,
          AuthError.wrongPassword => l.payoutAccountReauthWrong,
          _ => errorMessage(e, l),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final usesPassword =
        ref.read(authRepositoryProvider).reauthMethod == ReauthMethod.password;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.payoutAccountReauthTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(l.payoutAccountReauthBody, style: theme.textTheme.bodyMedium),
          if (usesPassword) ...[
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('reauth-password'),
              controller: _password,
              obscureText: true,
              autofocus: true,
              enabled: !_busy,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _go(true),
              decoration: InputDecoration(
                labelText: l.payoutAccountReauthPassword,
                errorText: _error,
              ),
            ),
          ] else if (_error != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              _error!,
              key: const Key('reauth-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.payoutAccountReauthGo,
            key: const Key('reauth-go'),
            loading: _busy,
            onPressed: () => _go(usesPassword),
          ),
        ],
      ),
    );
  }
}
