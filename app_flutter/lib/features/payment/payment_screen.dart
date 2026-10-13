// lib/features/payment/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_controller.dart';
import 'package:photobooking/features/payment/payment_snack.dart';
import 'package:photobooking/features/payment/qr_checkout_view.dart';
import 'package:photobooking/features/payment/wallet_waiting_view.dart';

/// S04.04: pay one payment subject (booking, event registration, etc.).
/// A bank transfer shows the VietQR ([QrCheckoutView]); a wallet shows
/// the waiting view ([WalletWaitingView]).
/// The screen never trusts a redirect: only the subject's status moves it on.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.subject,
    this.initial,
  });

  final PaySubject subject;
  final PaymentInstructions? initial;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _leaving = false;
  bool _renewing = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(paymentControllerProvider(widget.subject).notifier).seed(widget.initial);
      });
    }
  }

  void _navigate(String path) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.subject is TicketPay) {
          final l10n = context.l10n;
          final messenger = ScaffoldMessenger.of(context);
          final eventId = (widget.subject as TicketPay).eventId;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.registerDone),
                action: SnackBarAction(
                  label: l10n.registerOpenChat,
                  onPressed: () => context.push('/e/$eventId/chat'),
                ),
              ),
            );
        }
        context.go(path);
      }
    });
  }

  PaymentInstructions? _created;

  bool _shows(PaymentInstructions created, PaymentInstructions current) =>
      current.paymentId == created.paymentId ||
      ((current.attempt != null && created.attempt != null) &&
          current.attempt! >= created.attempt!);

  Future<void> _renew() async {
    if (_renewing) return;
    setState(() => _renewing = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref
          .read(paymentControllerProvider(widget.subject).notifier)
          .renew();
      if (!mounted) return;
      final current = ref.read(paymentControllerProvider(widget.subject));
      if (created != null &&
          current is PayOpen &&
          _shows(created, current.instructions)) {
        setState(() {
          _renewing = false;
          _created = null;
        });
      } else {
        setState(() => _created = created);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _renewing = false;
          _created = null;
        });
      }
      final text = switch (bookingErrorOf(e)) {
        BookingErrorCode.paymentAttemptsExceeded => l10n.payAttemptsExceeded,
        BookingErrorCode.blocked => l10n.bookingErrBlocked,
        _ => l10n.bookTryAgain,
      };
      showPaymentSnack(messenger, text);
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final paid = await ref
          .read(paymentControllerProvider(widget.subject).notifier)
          .check();
      if (!paid) showPaymentSnack(messenger, l10n.payNotYet);
    } catch (_) {
      showPaymentSnack(messenger, l10n.bookNetworkError);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(paymentControllerProvider(widget.subject));

    if (_created != null &&
        state is PayOpen &&
        _shows(_created!, state.instructions)) {
      _created = null;
      _renewing = false;
    }

    final isTicket = widget.subject is TicketPay;
    final isWallet = state is PayOpen && state.instructions.method != PayMethod.bankQr;

    return ScreenCode(
      ScreenCodes.awaitingPayment,
      label: isTicket ? 'ticket' : null,
      child: Scaffold(
        appBar: AppBar(title: Text(isWallet ? l10n.payTitle : l10n.payQrTitle)),
        body: SafeArea(
          bottom: false,
          child: switch (state) {
            PayLoading() => const Center(child: DotRingLoader()),
            PayDone(:final path) => Builder(
                builder: (context) {
                  _navigate(path);
                  return const Center(child: SignatureLoader());
                },
              ),
            PayGone(:final kind, :final actionPath) => EmptyState(
                title: switch (kind) {
                  PayGoneKind.booking => l10n.payExpiredTitle,
                  PayGoneKind.ticket => l10n.registerHoldExpired,
                },
                body: switch (kind) {
                  PayGoneKind.booking => l10n.payExpiredBody,
                  PayGoneKind.ticket => l10n.payTicketExpiredBody,
                },
                actionLabel: switch (kind) {
                  PayGoneKind.booking =>
                    actionPath == '/home' ? l10n.payGoHome : l10n.payBookAgain,
                  PayGoneKind.ticket => l10n.payBackToEvent,
                },
                onAction: () => context.go(actionPath),
              ),
            PayFailed(:final code) => Center(
                child: ErrorState(
                  message: switch (code) {
                    BookingErrorCode.paymentAttemptsExceeded =>
                      l10n.payAttemptsExceeded,
                    BookingErrorCode.blocked => l10n.bookingErrBlocked,
                    BookingErrorCode.network => l10n.bookNetworkError,
                    _ => l10n.bookTryAgain,
                  },
                  onRetry: () => ref
                      .read(paymentControllerProvider(widget.subject).notifier)
                      .retry(),
                ),
              ),
            PayOpen(:final instructions, :final who, :final canRenew) =>
              instructions.method == PayMethod.bankQr
                  ? QrCheckoutView(
                      instructions: instructions,
                      who: who,
                      canRenew: canRenew,
                      renewing: _renewing,
                      onRenew: _renew,
                      onBack: () => context.go(
                        isTicket
                            ? '/e/${(widget.subject as TicketPay).eventId}'
                            : '/home',
                      ),
                    )
                  : WalletWaitingView(
                      instructions: instructions,
                      who: who,
                      checking: _checking,
                      onCheck: _check,
                    ),
          },
        ),
      ),
    );
  }
}
