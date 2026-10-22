// S13.08 (photographer side): cancel an accepted Chụp ngay job. The server's
// dry run comes first, so the outcome is known before the red button; the
// customer always gets everything back and the photographer's reliability
// drops (Decision 9). #140 moves no money: the copy is the end-state copy
// (Task 1 ruling), the recorded amounts are zero.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';

/// `cancelInstantRequest(dryRun: true)` for the photographer.
final providerCancelQuoteProvider = FutureProvider.autoDispose
    .family<InstantCancelQuote, String>(
      (ref, id) =>
          ref.watch(instantRepositoryProvider).cancel(id, dryRun: true),
    );

/// Opens S13.08 over S14.03; true once the job was cancelled ("Huỷ việc"),
/// false when kept ("Giữ việc", back, tap outside). While the cancel runs the
/// sheet cannot be dismissed. [ref] is the caller's (the plan's signature);
/// the sheet reads the repository through its own.
Future<bool> showProviderCancelSheet(
  BuildContext context,
  WidgetRef ref, {
  required String requestId,
}) async {
  final done = await showAppSheet<bool>(
    context,
    builder: (_) => _ProviderCancelBody(requestId: requestId),
  );
  return done ?? false;
}

class _ProviderCancelBody extends ConsumerStatefulWidget {
  const _ProviderCancelBody({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_ProviderCancelBody> createState() =>
      _ProviderCancelBodyState();
}

class _ProviderCancelBodyState extends ConsumerState<_ProviderCancelBody> {
  bool _running = false;
  String? _error;

  Future<void> _confirm() async {
    if (_running) return;
    final l = context.l10n;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await ref
          .read(instantRepositoryProvider)
          .cancel(widget.requestId, dryRun: false);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      // The sheet stays: the job is still the photographer's.
      setState(() {
        _running = false;
        _error = instantErrorText(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final quote = ref.watch(providerCancelQuoteProvider(widget.requestId));
    final error = _error;
    return ScreenCode(
      ScreenCodes.instantCancel,
      label: 'provider',
      child: PopScope(
        canPop: !_running,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            0,
            AppSpace.s4,
            AppSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.providerCancelTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              AsyncView<InstantCancelQuote>(
                value: quote,
                loaderSize: LoaderSize.inline,
                onRetry: () => ref.invalidate(
                  providerCancelQuoteProvider(widget.requestId),
                ),
                data: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.providerCancelBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondary,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        error,
                        key: const Key('provider-cancel-error'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dark
                              ? AppColorsDark.destructive
                              : AppColors.destructive,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s4),
                    AppButton.danger(
                      l.providerCancelConfirm,
                      key: const Key('provider-cancel-confirm'),
                      loading: _running,
                      onPressed: _running ? null : _confirm,
                    ),
                    const SizedBox(height: AppSpace.s1),
                    AppButton.text(
                      l.providerCancelKeep,
                      key: const Key('provider-cancel-keep'),
                      onPressed: _running
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
