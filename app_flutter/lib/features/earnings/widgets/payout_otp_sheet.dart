// lib/features/earnings/widgets/payout_otp_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/earnings/earnings.dart';

/// What checking a code gave: [saved] closes the sheet with true; [wrong],
/// [expired] and [tooMany] keep it open with their message; [failed] closes
/// it with false (the caller says why).
enum PayoutOtpSubmit { saved, wrong, expired, tooMany, failed }

/// S06.06-otp: the code sent to the phone in the profile, to confirm a change
/// of payout account. True once [onSubmit] answered
/// [PayoutOtpSubmit.saved]; false when closed or failed. Resend is offered
/// after [PayoutOtpTicket.resendInSeconds]; [onResend] answers the new
/// ticket, or null when refused (the daily limit).
///
/// Dragging down is off because the sheet holds a text field; the barrier
/// tap and Back close it, except while a code is being checked.
Future<bool> showPayoutOtpSheet(
  BuildContext context, {
  required PayoutOtpTicket ticket,
  required Future<PayoutOtpSubmit> Function(String code) onSubmit,
  required Future<PayoutOtpTicket?> Function() onResend,
}) async {
  final done = await showAppSheet<bool>(
    context,
    enableDrag: false,
    builder: (_) => ScreenCode(
      ScreenCodes.payoutAccount,
      label: 'otp',
      child: _OtpBody(ticket: ticket, onSubmit: onSubmit, onResend: onResend),
    ),
  );
  return done ?? false;
}

class _OtpBody extends ConsumerStatefulWidget {
  const _OtpBody({
    required this.ticket,
    required this.onSubmit,
    required this.onResend,
  });

  final PayoutOtpTicket ticket;
  final Future<PayoutOtpSubmit> Function(String code) onSubmit;
  final Future<PayoutOtpTicket?> Function() onResend;

  @override
  ConsumerState<_OtpBody> createState() => _OtpBodyState();
}

class _OtpBodyState extends ConsumerState<_OtpBody> {
  final _code = TextEditingController();
  late PayoutOtpTicket _ticket = widget.ticket;
  late DateTime _resendAt;
  bool _busy = false;
  bool _resending = false;
  String? _error;

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    _resendAt = _now().add(Duration(seconds: _ticket.resendInSeconds));
    _code.addListener(_clearError);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null && _code.text.isNotEmpty && !_busy) {
      setState(() => _error = null);
    }
  }

  Future<void> _submit() async {
    final code = _code.text;
    if (_busy || code.length != otpCodeLength) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.onSubmit(code);
    if (!mounted) return;
    switch (r) {
      case PayoutOtpSubmit.saved:
        Navigator.of(context).pop(true);
        return;
      case PayoutOtpSubmit.failed:
        Navigator.of(context).pop(false);
        return;
      case PayoutOtpSubmit.wrong ||
          PayoutOtpSubmit.expired ||
          PayoutOtpSubmit.tooMany:
        _code.clear();
        setState(() {
          _busy = false;
          _error = switch (r) {
            PayoutOtpSubmit.wrong => l.payoutOtpWrong,
            PayoutOtpSubmit.expired => l.payoutOtpExpired,
            _ => l.payoutOtpTooMany,
          };
        });
    }
  }

  Future<void> _resend() async {
    if (_resending || _busy) return;
    final l = context.l10n;
    setState(() => _resending = true);
    final t = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (t == null) {
        _error = l.payoutOtpLimit;
        return;
      }
      _ticket = t;
      _resendAt = _now().add(Duration(seconds: t.resendInSeconds));
      _error = null;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.payoutOtpTitle, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              l.payoutOtpBody(_ticket.phoneLast4),
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpace.s4),
            ListenableBuilder(
              listenable: _code,
              builder: (context, _) => OtpCodeField(
                key: const Key('payout-otp'),
                controller: _code,
                labelText: l.payoutOtpField,
                errorText: _error,
                enabled: !_busy,
                onCompleted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Center(
              child: CountdownText(
                key: ValueKey(_resendAt),
                deadline: _resendAt,
                now: _now,
                builder: (context, left) {
                  // The tick lands on whole seconds; round up the remainder.
                  final seconds = (left.inMilliseconds / 1000).ceil();
                  if (seconds > 0) {
                    return Text(
                      l.payoutOtpResendIn(seconds),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  }
                  return AppButton.text(
                    l.payoutOtpResend,
                    key: const Key('payout-otp-resend'),
                    loading: _resending,
                    onPressed: _busy ? null : _resend,
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            LockNote(text: l.payoutOtpNote),
            const SizedBox(height: AppSpace.s4),
            ListenableBuilder(
              listenable: _code,
              builder: (context, _) => AppButton.primary(
                l.payoutOtpConfirm,
                key: const Key('payout-otp-confirm'),
                loading: _busy,
                onPressed: _code.text.length == otpCodeLength && !_busy
                    ? _submit
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mock's `.lockn`: a lock icon and a muted note.
class LockNote extends StatelessWidget {
  const LockNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(AppIcons.lock, size: AppText.base, color: secondary),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}
