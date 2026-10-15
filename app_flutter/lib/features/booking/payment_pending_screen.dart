// lib/features/booking/payment_pending_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/qr_checkout_view.dart';
import 'package:photobooking/features/booking/wallet_waiting_view.dart';
import 'package:photobooking/features/discovery/book_entry.dart';

/// S04.04: pay one draft booking. A bank transfer shows the VietQR
/// ([QrCheckoutView]); a wallet shows the waiting view ([WalletWaitingView]).
/// The screen never trusts a redirect: only `bookings.status` moves it on.
class PaymentPendingScreen extends ConsumerStatefulWidget {
  const PaymentPendingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<PaymentPendingScreen> createState() =>
      _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends ConsumerState<PaymentPendingScreen> {
  /// The last non-null booking seen on the stream, so "Đặt lại" still knows the
  /// photographer and package after the server deletes an expired draft.
  Booking? _lastKnown;

  bool _leaving = false;

  /// A draft saved before checkouts existed has none: one QR is created for it
  /// ([_creating] guards against a second call while the first is running).
  bool _creating = false;
  BookingCheckout? _created;
  String? _createFailure;

  /// Replaces S04.04 with S05.02 once the payment is confirmed.
  void _openDetail(String id) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/b/$id?paid=1');
    });
  }

  void _ensureCheckout(Booking booking) {
    if (_creating || _created != null || _createFailure != null) return;
    _creating = true;
    final l10n = context.l10n;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final checkout = await ref
            .read(bookingRepositoryProvider)
            .createPayment(bookingId: booking.id, method: PayMethod.bankQr);
        if (mounted) setState(() => _created = checkout);
      } catch (e) {
        if (mounted) {
          setState(
            () => _createFailure = switch (bookingErrorOf(e)) {
              BookingErrorCode.paymentAttemptsExceeded =>
                l10n.payAttemptsExceeded,
              BookingErrorCode.blocked => l10n.bookingErrBlocked,
              BookingErrorCode.network => l10n.bookNetworkError,
              _ => l10n.bookTryAgain,
            },
          );
        }
      } finally {
        _creating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bookingAsync = ref.watch(bookingProvider(widget.bookingId));
    final lastCheckout = bookingAsync.value?.checkout ?? _created;
    final isWallet =
        lastCheckout != null && lastCheckout.method != PayMethod.bankQr;

    return ScreenCode(
      ScreenCodes.awaitingPayment,
      child: Scaffold(
        appBar: AppBar(title: Text(isWallet ? l10n.payTitle : l10n.payQrTitle)),
        body: SafeArea(
          bottom: false,
          child: AsyncView<Booking?>(
            value: bookingAsync,
            loaderSize: LoaderSize.screen,
            onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
            data: (ctx, booking) {
              if (booking != null) {
                _lastKnown = booking;
              }

              if (booking == null) {
                // The draft was cleaned up (or never existed): expired.
                final last = _lastKnown;
                return EmptyState(
                  title: l10n.payExpiredTitle,
                  body: l10n.payExpiredBody,
                  actionLabel: last != null
                      ? l10n.payBookAgain
                      : l10n.payGoHome,
                  onAction: () => context.go(
                    last != null
                        ? bookingPath(
                            photographerId: last.photographerId,
                            serviceId: last.serviceId,
                          )
                        : '/home',
                  ),
                );
              }

              if (booking.status != BookingStatus.draft) {
                // Paid: S05.02 takes over and shows the paid toast once.
                _openDetail(booking.id);
                return const Center(child: SignatureLoader());
              }

              final checkout = booking.checkout ?? _created;
              if (checkout == null) {
                final failure = _createFailure;
                if (failure != null) {
                  return Center(
                    child: ErrorState(
                      message: failure,
                      onRetry: () => setState(() => _createFailure = null),
                    ),
                  );
                }
                _ensureCheckout(booking);
                return const Center(child: DotRingLoader());
              }

              return checkout.method == PayMethod.bankQr
                  ? QrCheckoutView(booking: booking, checkout: checkout)
                  : WalletWaitingView(booking: booking, checkout: checkout);
            },
          ),
        ),
      ),
    );
  }
}
