// lib/features/verification/verify_start_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';
import 'package:photobooking/features/verification/widgets/verify_step_tile.dart';
import 'package:photobooking/features/verification/widgets/verify_timeline.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S21.02's own path; the steps come back here when done.
const verifyStartPath = '/verify/start';

/// The screen that does [step], or null while it has none (the fee is #203).
String? verifyStepPath(VerifyStep step) => switch (step) {
  VerifyStep.phone => Uri(
    path: '/verify/phone',
    queryParameters: {'returnTo': verifyStartPath},
  ).toString(),
  VerifyStep.fee => null,
  VerifyStep.identity => '/verify/identity',
  VerifyStep.rules => '$verifyStartPath/rules',
};

/// "{n} / {total}" of the S21.02 flow: the position of the step being worked
/// on ([VerificationState.nextStep]) among the required steps, [total] once
/// all are done.
int verifyStepPosition(VerificationState s) {
  final next = s.nextStep;
  return next == null
      ? s.requiredSteps.length
      : s.requiredSteps.indexOf(next) + 1;
}

/// S21.02 "Bắt đầu nhận đơn": the required steps (mock `#S21.02`), then,
/// once sent, the decision states `#S21.02-pending`, `-rejected`,
/// `-approved` and `-revoked`. [supportAddress] is the build's support email
/// (null hides the support line).
class VerifyStartScreen extends ConsumerStatefulWidget {
  const VerifyStartScreen({super.key, this.supportAddress = supportEmail});

  final String? supportAddress;

  @override
  ConsumerState<VerifyStartScreen> createState() => _VerifyStartScreenState();
}

class _VerifyStartScreenState extends ConsumerState<VerifyStartScreen> {
  bool _busy = false;

  Future<void> _send(Future<void> Function(VerificationRepository) call) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await call(ref.read(verificationRepositoryProvider));
    } on VerificationError {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.engagementError)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _open(VerifyStep? step) {
    final path = step == null ? null : verifyStepPath(step);
    if (path != null) {
      context.push(path);
    }
  }

  void _viewProfile() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      context.push('/u/$uid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(myVerificationProvider);
    final s = async.value;
    final steps =
        s == null ||
        s.status == VerificationStatus.notStarted ||
        s.status == VerificationStatus.inProgress;
    final label = switch (s?.status) {
      VerificationStatus.submitted => 'pending',
      VerificationStatus.rejected => 'rejected',
      VerificationStatus.approved => 'approved',
      VerificationStatus.revoked => 'revoked',
      _ => null,
    };
    return ScreenCode(
      ScreenCodes.verifyPhotographer,
      label: label,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.verifyStartTitle),
            actions: [
              if (s != null && steps)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        l.verifyStepCounter(
                          verifyStepPosition(s),
                          s.requiredSteps.length,
                        ),
                        key: const Key('verify-counter'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: AsyncView<VerificationState>(
              value: async,
              loadingLabel: l.loadingLabel,
              onRetry: () => ref.invalidate(myVerificationProvider),
              data: (context, s) => switch (s.status) {
                VerificationStatus.notStarted ||
                VerificationStatus.inProgress => _steps(context, s),
                VerificationStatus.submitted => _pending(context, s),
                VerificationStatus.rejected => _rejected(context, s),
                VerificationStatus.approved => _approved(context, s),
                VerificationStatus.revoked => _revoked(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  DateTime _now() => ref.read(clockProvider)();

  /// Title and subtitle of one required step's row; null for a row this
  /// build does not draw (the fee, #203).
  ({String title, String subtitle})? _texts(
    AppLocalizations l,
    VerificationState s,
    VerifyStep step,
  ) {
    final done = s.isDone(step);
    switch (step) {
      case VerifyStep.phone:
        final phone = ref.watch(currentContactProvider).value?.phone ?? '';
        return (
          title: l.verifyStepPhone,
          subtitle: !done
              ? l.verifyStepPhoneTodo
              : phone.length > 4
              ? l.verifyStepPhoneDone(phone.substring(phone.length - 4))
              : l.verifyPhoneDone,
        );
      case VerifyStep.fee:
        // #203 adds the fee row's texts; without the fee it is not drawn.
        return null;
      case VerifyStep.identity:
        return (
          title: l.verifyStepIdentity,
          subtitle: !done
              ? l.verifyStepIdentityTodo
              : s.identityMethod == IdentityMethod.nfc
              ? l.verifyStepIdentityDoneNfc
              : l.verifyStepIdentityDoneVneid,
        );
      case VerifyStep.rules:
        return (
          title: l.verifyStepRules,
          subtitle: done ? l.verifyStepRulesDone : l.verifyStepRulesTodo,
        );
    }
  }

  /// `#S21.02`: the step list with text states and "Tiếp tục" / "Gửi duyệt".
  Widget _steps(BuildContext context, VerificationState s) {
    final l = context.l10n;
    final total = s.requiredSteps.length;
    final next = s.nextStep;
    final tiles = <Widget>[];
    for (final (i, step) in s.requiredSteps.indexed) {
      final t = _texts(l, s, step);
      if (t == null) {
        continue;
      }
      final done = s.isDone(step);
      tiles.add(
        VerifyStepTile(
          key: Key('verify-step-${step.name}'),
          index: i + 1,
          title: t.title,
          subtitle: t.subtitle,
          state: done
              ? VerifyTileState.done
              : step == next
              ? VerifyTileState.now
              : VerifyTileState.todo,
          onTap: done || verifyStepPath(step) == null
              ? null
              : () => _open(step),
        ),
      );
    }
    return _Layout(
      progress: StepProgress(
        current: verifyStepPosition(s),
        total: total,
        showCount: false,
      ),
      action: next != null
          ? AppButton.primary(
              l.verifyContinue,
              key: const Key('verify-next'),
              onPressed: verifyStepPath(next) == null
                  ? null
                  : () => _open(next),
            )
          : AppButton.primary(
              l.verifySubmit,
              key: const Key('verify-submit'),
              loading: _busy,
              onPressed: () => _send((r) => r.submit()),
            ),
      children: [
        _Meta(l.verifyStartIntro),
        const SizedBox(height: AppSpace.s3),
        Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, t) in tiles.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpace.s2),
                t,
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        _InfoNote(l.verifyStartNote(total)),
      ],
    );
  }

  /// `#S21.02-pending`: sent, waiting for staff; no primary button.
  Widget _pending(BuildContext context, VerificationState s) {
    final l = context.l10n;
    final now = _now();
    final sent = s.submittedAt;
    return _Layout(
      action: AppButton.outline(
        l.verifyViewProfile,
        key: const Key('verify-view-profile'),
        onPressed: _viewProfile,
      ),
      children: [
        _Hero(
          heading: l.verifyPendingHeading,
          body: sent == null
              ? null
              : l.verifyPendingSent(
                  verifyAt(sent, now, l),
                  verifyAt(sent.add(const Duration(hours: 24)), now, l),
                ),
        ),
        const SizedBox(height: AppSpace.s4),
        VerifyTimeline(state: s, now: now),
        const SizedBox(height: AppSpace.s3),
        _InfoNote(l.verifyPendingNote),
      ],
    );
  }

  /// `#S21.02-rejected`: the reason, what reopens (Decision 13) and "Sửa và
  /// gửi lại"; a final reason shows the support line and no primary button.
  Widget _rejected(BuildContext context, VerificationState s) {
    final l = context.l10n;
    final reason = s.rejectReason;
    final reasonText = switch (reason) {
      RejectReason.fakeAvatar => l.verifyReject_fake_avatar,
      RejectReason.stolenPortfolio => l.verifyReject_stolen_portfolio,
      RejectReason.identityMismatch => l.verifyReject_identity_mismatch,
      RejectReason.duplicateAccount => l.verifyReject_duplicate_account,
      RejectReason.underage => l.verifyReject_underage,
      RejectReason.other || null => s.rejectText,
    };
    // Staff may add a note to a listed reason; `other` shows it as the reason.
    final staffNote = reason == null || reason == RejectReason.other
        ? null
        : s.rejectText;
    final warn = _WarnCard(
      key: const Key('verify-rejected'),
      icon: AppIcons.info,
      title: l.verifyRejectedTitle,
      body: [
        if (reasonText != null) l.verifyRejectedReason(reasonText),
        ?staffNote,
      ].join('\n'),
    );
    if (s.rejectionFinal) {
      return _Layout(
        children: [
          warn,
          const SizedBox(height: AppSpace.s3),
          _SupportLine(widget.supportAddress),
        ],
      );
    }

    final uid = ref.watch(authStateProvider).value?.uid;
    final rows = <Widget>[];
    void add(Widget Function(int index) row) => rows.add(row(rows.length + 1));
    if (reason == RejectReason.fakeAvatar) {
      add(
        (i) => VerifyStepTile(
          key: const Key('verify-fix-avatar'),
          index: i,
          icon: AppIcons.profile,
          title: l.verifyFixAvatar,
          subtitle: l.verifyFixAvatarBody,
          state: VerifyTileState.fix,
          onTap: () => context.push('/settings/profile'),
        ),
      );
    }
    if (reason == RejectReason.stolenPortfolio && uid != null) {
      add(
        (i) => VerifyStepTile(
          key: const Key('verify-fix-portfolio'),
          index: i,
          icon: AppIcons.album,
          title: l.verifyFixPortfolio,
          subtitle: l.verifyFixPortfolioBody,
          state: VerifyTileState.fix,
          onTap: () => context.push('/u/$uid'),
        ),
      );
    }
    // Mock order: identity, fee, rules; the phone only when a new number
    // reset it (Decision 3).
    for (final step in [
      VerifyStep.phone,
      VerifyStep.identity,
      VerifyStep.fee,
      VerifyStep.rules,
    ]) {
      if (!s.requiredSteps.contains(step)) {
        continue;
      }
      final done = s.isDone(step);
      if (step == VerifyStep.phone && done) {
        continue;
      }
      final t = _texts(l, s, step);
      if (t == null) {
        continue;
      }
      // Mock `#S21.02-rejected` names the rows "Danh tính" and "Quy định
      // nhận việc".
      final title = switch (step) {
        VerifyStep.identity => l.verifyFixIdentity,
        VerifyStep.rules => l.verifyRulesTitle,
        _ => t.title,
      };
      add(
        (i) => VerifyStepTile(
          key: Key('verify-step-${step.name}'),
          index: i,
          title: title,
          subtitle: t.subtitle,
          state: done ? VerifyTileState.done : VerifyTileState.fix,
          onTap: done || verifyStepPath(step) == null
              ? null
              : () => _open(step),
        ),
      );
    }

    final fixNext = s.nextStep;
    final decided = s.decidedAt;
    final left = s.freeResubmitsLeft;
    // Without the fee a resubmit is free whatever the count, so 0 says
    // nothing; #203 shows "Hết lượt gửi lại miễn phí" there.
    final showLeft = left > 0;
    final theme = Theme.of(context);
    return _Layout(
      action: AppButton.primary(
        l.verifyResubmit,
        key: const Key('verify-resubmit'),
        loading: _busy,
        // A step reopened by the rejection (or reset since) comes first.
        onPressed: s.resubmittable
            ? () => _send((r) => r.resubmit())
            : fixNext == null || verifyStepPath(fixNext) == null
            ? null
            : () => _open(fixNext),
      ),
      children: [
        warn,
        if (showLeft || decided != null) ...[
          const SizedBox(height: AppSpace.s3),
          Row(
            children: [
              Expanded(
                child: showLeft
                    ? Text(
                        l.verifyFreeResubmitsLeft(left),
                        key: const Key('verify-free-resubmits'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (decided != null) _Meta(verifyAt(decided, _now(), l)),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s3),
        Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpace.s2),
                r,
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        _Meta(l.verifyRejectedNote),
      ],
    );
  }

  /// `#S21.02-approved`.
  Widget _approved(BuildContext context, VerificationState s) {
    final l = context.l10n;
    final decided = s.decidedAt;
    return _Layout(
      action: AppButton.outline(
        l.verifyViewProfile,
        key: const Key('verify-view-profile'),
        onPressed: _viewProfile,
      ),
      children: [
        const SizedBox(height: AppSpace.s4),
        _Hero(
          heading: l.verifyApprovedHeading,
          body: decided == null
              ? null
              : l.verifyApprovedBody(verifyAt(decided, _now(), l)),
        ),
      ],
    );
  }

  /// `#S21.02-revoked`: terminal in the app (Decision 14).
  Widget _revoked(BuildContext context) {
    final l = context.l10n;
    return _Layout(
      children: [
        _WarnCard(
          key: const Key('verify-revoked'),
          icon: AppIcons.warning,
          title: l.verifyRevokedHeading,
          body: l.verifyRevokedBody,
        ),
        const SizedBox(height: AppSpace.s3),
        _SupportLine(widget.supportAddress),
      ],
    );
  }
}

/// Optional step bar, the scrolling content and the sticky footer action.
class _Layout extends StatelessWidget {
  const _Layout({this.progress, required this.children, this.action});

  final Widget? progress;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final bar = progress;
    final act = action;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bar != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
            child: bar,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        if (act != null) AppFooterBar(child: act),
      ],
    );
  }
}

Color _secondary(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColorsDark.foregroundSecondary
    : AppColors.foregroundSecondary;

/// Mock `.meta`: secondary small text.
class _Meta extends StatelessWidget {
  const _Meta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: _secondary(theme),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Mock `.vqr` with `.idill`: the verified-user circle, a heading and a line.
class _Hero extends StatelessWidget {
  const _Hero({required this.heading, this.body});

  final String heading;
  final String? body;

  /// Mock `.idill`.
  static const _size = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final text = body;
    return Column(
      children: [
        Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? AppColorsDark.accentSoft : AppColors.accentSoft,
          ),
          child: AppIcon(
            AppIcons.verifiedUser,
            size: AppText.xxl,
            color: dark ? AppColorsDark.accent : AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Semantics(
          header: true,
          child: Text(
            heading,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (text != null) ...[
          const SizedBox(height: AppSpace.s1),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _secondary(theme),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// Mock `.esc`: an info icon and a note on the field background.
class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s2h,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(AppIcons.info, size: AppText.md, color: _secondary(theme)),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mock `.warnc` (role alert): a red-outlined card with a title and body.
class _WarnCard extends StatelessWidget {
  const _WarnCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bad = dark ? AppColorsDark.error : AppColors.error;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bad.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: bad.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: AppText.md, color: bad),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _secondary(theme),
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

/// "Hỗ trợ: {email}", opening the mail app; hidden while the build has no
/// support address.
class _SupportLine extends ConsumerWidget {
  const _SupportLine(this.email);

  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = email;
    final mailto = supportEmailUri(address);
    if (address == null || mailto == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('verify-support'),
      onTap: () => ref.read(externalLauncherProvider).open(mailto),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            context.l10n.verifySupportLine(address),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _secondary(theme),
            ),
          ),
        ),
      ),
    );
  }
}
