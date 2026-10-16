// lib/features/events/register_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/events/register_controller.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

/// What the sheet closed with, besides a success.
enum _Exit { soldOut, needsPhone, changePhone }

/// S11.03: register for an event. Free: "Xác nhận đăng ký" makes the ticket at
/// once. Paid: the money table, escrow notice, policy and payment method, then
/// "Thanh toán {amount}" holds the seats for 10 minutes ("Giữ chỗ còn mm:ss")
/// and opens the payment step (fake sheet, or the gateway's pay URL); the
/// registration stream decides: `paid` closes the sheet, an expired hold says
/// "Chỗ giữ đã hết hạn" and the button starts again. Returns the outcome of a
/// valid ticket; then the app opens the tickets tab with it highlighted.
///
/// A full event closes the sheet with a SnackBar; a missing phone number goes
/// to S04.05 and comes back to `/e/{id}/join`, which reopens this sheet.
Future<RegisterOutcome?> showRegisterSheet(
  BuildContext context,
  WidgetRef ref, {
  required EventDetail event,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final result = await showAppSheet<Object>(
    context,
    enableDrag: false,
    builder: (_) => ScreenCode(
      ScreenCodes.eventRegister,
      child: RegisterSheet(event: event),
    ),
  );
  if (result is RegisterOutcome) {
    if (result.status == RegistrationStatus.held &&
        result.instructions != null) {
      if (context.mounted) {
        await openPayment(
          context,
          ref,
          subject: TicketPay(event.id, result.registrationId),
          instructions: result.instructions!,
        );
      }
      return result;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.registerDone),
          // A paid (or free) ticket opens the event's group chat.
          action: result.status == RegistrationStatus.paid
              ? SnackBarAction(
                  label: l.registerOpenChat,
                  onPressed: () => router.push('/e/${event.id}/chat'),
                )
              : null,
        ),
      );
    router.go('/bookings?tab=events&highlight=${result.registrationId}');
    return result;
  }
  switch (result) {
    case _Exit.soldOut:
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.registerSoldOut)));
    case _Exit.needsPhone || _Exit.changePhone:
      final back = Uri.encodeComponent('/e/${event.id}/join');
      router.push('/profile/phone?returnTo=$back');
    case _:
      break;
  }
  return null;
}

class RegisterSheet extends ConsumerStatefulWidget {
  const RegisterSheet({super.key, required this.event});

  final EventDetail event;

  @override
  ConsumerState<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends ConsumerState<RegisterSheet> {
  late final RegisterArgs _args;
  late final TextEditingController _name;
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider).value;
    final prefill = (profile?.displayName ?? '').trim();
    _args = RegisterArgs(
      eventId: widget.event.id,
      seatsLeft: widget.event.summary.seatsLeft,
      priceVnd: widget.event.summary.isFree ? 0 : widget.event.summary.priceVnd,
      initialName: prefill.length > registerNameMaxLength
          ? prefill.substring(0, registerNameMaxLength)
          : prefill,
    );
    _name = TextEditingController(text: _args.initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _listen(RegisterState? prev, RegisterState next) {
    final outcome = next.outcome;
    if (outcome != null && prev?.outcome == null) {
      Navigator.of(context).pop(outcome);
      return;
    }
    final code = next.errorCode;
    if (code == null || code == prev?.errorCode) {
      return;
    }
    if (code == 'sold_out') {
      Navigator.of(context).pop(_Exit.soldOut);
    } else if (code == 'phone_required') {
      Navigator.of(context).pop(_Exit.needsPhone);
    }
  }

  String? _errorText(String? code) => switch (code) {
    null || 'sold_out' || 'phone_required' => null,
    'deadline_passed' => context.l10n.eventClosed,
    _ => context.l10n.registerError,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    ref.listen(registerControllerProvider(_args), _listen);
    // The profile may still be loading when the sheet opens: fill the name
    // once it arrives, unless the person already typed one.
    ref.listen(currentProfileProvider, (_, next) {
      final prefill = (next.value?.displayName ?? '').trim();
      if (!_edited && _name.text.isEmpty && prefill.isNotEmpty) {
        final capped = prefill.length > registerNameMaxLength
            ? prefill.substring(0, registerNameMaxLength)
            : prefill;
        _name.text = capped;
        ref.read(registerControllerProvider(_args).notifier).setName(capped);
      }
    });
    final state = ref.watch(registerControllerProvider(_args));
    final controller = ref.read(registerControllerProvider(_args).notifier);
    final phone = ref.watch(currentContactProvider).value?.phone;
    final digits = phone == null ? null : nationalDigits(phone);
    final error = _errorText(state.errorCode);
    final seatsLeft = widget.event.summary.seatsLeft;
    final secondary = theme.textTheme.bodySmall;

    return PopScope(
      canPop: !state.submitting,
      child: SingleChildScrollView(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    l.eventRegisterTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Flexible(
                  child: Text(
                    widget.event.summary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.registerTickets,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(l.registerTicketsHint(seatsLeft), style: secondary),
                    ],
                  ),
                ),
                _Stepper(
                  value: state.quantity,
                  canDecrement: !controller.locked && state.quantity > 1,
                  canIncrement:
                      !controller.locked &&
                      state.quantity < controller.maxQuantity,
                  onDecrement: controller.decrement,
                  onIncrement: controller.increment,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('register-name'),
              controller: _name,
              enabled: !state.submitting,
              maxLength: registerNameMaxLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.registerName,
                errorText: state.nameValid ? null : l.registerNameError,
              ),
              onChanged: (v) {
                _edited = true;
                controller.setName(v);
              },
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.registerPhone, style: secondary),
                      Text(
                        digits == null || digits.isEmpty
                            ? '—'
                            : '0${formatNational(digits)}',
                        key: const Key('register-phone'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton.text(
                  l.registerChangePhone,
                  key: const Key('register-change-phone'),
                  size: AppButtonSize.xsmall,
                  onPressed: state.submitting
                      ? null
                      : () => Navigator.of(context).pop(_Exit.changePhone),
                ),
              ],
            ),
            if (_args.paid) ..._paidSection(context, state, controller),
            if (error != null) ...[
              const SizedBox(height: AppSpace.s2),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('register-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              _args.paid
                  ? l.registerPay(formatMoney(controller.totalVnd))
                  : l.registerFree,
              key: const Key('register-submit'),
              loading: state.submitting,
              onPressed: state.nameValid && !state.submitting
                  ? controller.submit
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Mock S11.03 (paid): "{n} vé × {price}", "Tổng thanh toán", the escrow
  /// notice (Decision 29), the policy line, the payment method, and the hold.
  List<Widget> _paidSection(
    BuildContext context,
    RegisterState state,
    RegisterController controller,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final total = controller.totalVnd;
    return [
      const SizedBox(height: AppSpace.s3),
      MoneyBreakdown(
        key: const Key('register-money'),
        lines: [
          MoneyLine(
            label: l.registerLine(state.quantity, formatMoney(_args.priceVnd)),
            vnd: total,
          ),
          MoneyLine(
            label: l.registerTotal,
            vnd: total,
            style: MoneyLineStyle.strong,
          ),
        ],
      ),
      const SizedBox(height: AppSpace.s3),
      EscrowNotice(text: l.escrowNoticeTicket),
      const SizedBox(height: AppSpace.s2),
      Text(
        l.registerPolicy,
        key: const Key('register-policy'),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpace.s3),
      PayMethodPicker(
        value: state.method,
        enabled: !state.submitting,
        onChanged: controller.setMethod,
      ),
    ];
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('register-minus'),
          tooltip: l.registerLess,
          icon: const AppIcon(AppIcons.remove),
          onPressed: canDecrement ? onDecrement : null,
        ),
        Semantics(
          liveRegion: true,
          label: l.ticketCount(value),
          child: ExcludeSemantics(
            child: SizedBox(
              width: 32,
              child: Text(
                '$value',
                key: const Key('register-quantity'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('register-plus'),
          tooltip: l.registerMore,
          icon: const AppIcon(AppIcons.add),
          onPressed: canIncrement ? onIncrement : null,
        ),
      ],
    );
  }
}
