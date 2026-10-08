// lib/features/earnings/widgets/name_lookup_card.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/features/earnings/payout_account_controller.dart';

/// The mock's `.lkp`: what the bank answered for the typed account. Matched
/// shows the name with a check; mismatch the bank's name with a cross and,
/// under it, the `.warnc` alert with the verified name; review an info line
/// (save allowed, staff compares). Nothing while idle. A failed lookup other
/// than the daily limit retries on tap ([onRetry]).
class NameLookupCard extends StatelessWidget {
  const NameLookupCard({super.key, required this.view, this.onRetry});

  final PayoutLookupView view;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = view;
    return switch (v) {
      LookupIdle() => const SizedBox.shrink(),
      LookupLoading() => _Line(
        mark: const SizedBox.square(
          dimension: AppSpace.s5,
          child: DotRingLoader(dimension: AppSpace.s5),
        ),
        title: l.payoutLookupLoading,
        strongTitle: false,
      ),
      LookupFailed(code: 'limit_exceeded') => _Line(
        mark: const _Mark(_Tone.bad, AppIcons.close),
        title: l.payoutLookupLimit,
        strongTitle: false,
      ),
      LookupFailed() => Semantics(
        button: onRetry != null,
        child: InkWell(
          key: const Key('payout-lookup-retry'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onRetry,
          child: _Line(
            mark: const _Mark(_Tone.neutral, AppIcons.info),
            title: l.payoutLookupError,
            strongTitle: false,
          ),
        ),
      ),
      LookupDone(:final result) => _done(context, result),
    };
  }

  Widget _done(BuildContext context, PayoutNameLookup r) {
    final l = context.l10n;
    switch (r.decision) {
      case PayoutNameDecision.matched:
        return _Line(
          mark: const _Mark(_Tone.ok, AppIcons.check),
          title: r.holderName ?? r.verifiedName ?? '',
          sub: l.payoutLookupMatched,
          subTone: _Tone.ok,
        );
      case PayoutNameDecision.mismatch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The server's own check may refuse without a name.
            _Line(
              mark: const _Mark(_Tone.bad, AppIcons.close),
              title: r.holderName ?? l.payoutLookupMismatch,
              sub: r.holderName == null ? null : l.payoutLookupMismatch,
            ),
            const SizedBox(height: AppSpace.s3),
            _MismatchAlert(verifiedName: r.verifiedName ?? ''),
          ],
        );
      case PayoutNameDecision.review:
        return _Line(
          mark: const _Mark(_Tone.neutral, AppIcons.info),
          title: l.payoutLookupReview,
          sub: l.payoutLookupReviewSub,
        );
      case PayoutNameDecision.notFound:
        return _Line(
          mark: const _Mark(_Tone.bad, AppIcons.close),
          title: l.payoutLookupNotFound,
          strongTitle: false,
        );
      case PayoutNameDecision.unverifiable:
        return _Line(
          mark: const _Mark(_Tone.neutral, AppIcons.info),
          title: l.payoutLookupUnverifiable,
          strongTitle: false,
        );
    }
  }
}

enum _Tone { ok, bad, neutral }

/// The round mark at the start of the line.
class _Mark extends StatelessWidget {
  const _Mark(this.tone, this.icon);

  final _Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (tone) {
      _Tone.ok => (AppColors.success, AppColors.foregroundInverse),
      _Tone.bad => (AppColors.error, AppColors.foregroundInverse),
      _Tone.neutral => (
        dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary,
      ),
    };
    return ExcludeSemantics(
      child: Container(
        width: AppSpace.s6,
        height: AppSpace.s6,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(icon, size: AppText.base, color: fg),
      ),
    );
  }
}

/// One `.lkp` row; a status region so the answer is announced.
class _Line extends StatelessWidget {
  const _Line({
    required this.mark,
    required this.title,
    this.sub,
    this.subTone,
    this.strongTitle = true,
  });

  final Widget mark;
  final String title;
  final String? sub;
  final _Tone? subTone;
  final bool strongTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Semantics(
      liveRegion: true,
      container: true,
      child: GlassCard(
        highlight: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            children: [
              mark,
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: strongTitle
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.bodyMedium,
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subTone == _Tone.ok
                              ? AppColors.success
                              : secondary,
                        ),
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

/// The mock's `.warnc`: the verified name and why the account is refused.
class _MismatchAlert extends StatelessWidget {
  const _MismatchAlert({required this.verifiedName});

  final String verifiedName;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.errorSubtle.withValues(alpha: dark ? 0.12 : 1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon(
                AppIcons.info,
                size: AppText.md,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (verifiedName.isNotEmpty) ...[
                      Text(
                        l.payoutLookupMismatchTitle(verifiedName),
                        style: theme.textTheme.titleSmall?.copyWith(color: fg),
                      ),
                      const SizedBox(height: AppSpace.s1),
                    ],
                    Text(
                      l.payoutLookupMismatchBody,
                      style: theme.textTheme.bodySmall?.copyWith(color: fg),
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
