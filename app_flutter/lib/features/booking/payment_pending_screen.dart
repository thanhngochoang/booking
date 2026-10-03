// lib/features/booking/payment_pending_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/booking_summary.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/fake_payment_sheet.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/l10n/app_localizations.dart';

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
  bool _checking = false;
  bool _changing = false;

  bool _leaving = false;

  /// Replaces S04.04 with S05.02 once the deposit is confirmed.
  void _openDetail(String id) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/b/$id?paid=1');
    });
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Asks the server to query the gateway. Never creates a payment; the stream
  /// moves the screen on when the status leaves `draft`.
  Future<void> _checkAgain() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = context.l10n;
    try {
      final res = await ref
          .read(bookingRepositoryProvider)
          .checkDeposit(bookingId: widget.bookingId);
      if (!mounted) return;
      if (!res.paid) _showSnack(l10n.payNotYet);
    } catch (_) {
      if (mounted) _showSnack(l10n.bookNetworkError);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// "Đổi cổng thanh toán": pick the other gateway, create a deposit with it and
  /// run the same payment step as S04.03 (fake sheet or external page). The
  /// screen stays here; only the booking stream decides what comes next.
  Future<void> _changeProvider(Booking b) async {
    if (_changing) return;
    final l10n = context.l10n;
    final current =
        PaymentProviderCode.fromCode(b.depositProvider) ??
        PaymentProviderCode.momo;

    final picked = await showAppSheet<PaymentProviderCode>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.payChangeProvider,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            ProviderPicker(
              value: current,
              onChanged: (p) => Navigator.of(sheetContext).pop(p),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null || picked == current) return;

    setState(() => _changing = true);
    final repo = ref.read(bookingRepositoryProvider);
    try {
      final checkout = await repo.createDeposit(
        bookingId: b.id,
        provider: picked.code,
      );
      if (!mounted) return;
      if (ref.read(realPaymentsProvider)) {
        await ref
            .read(externalLauncherProvider)
            .open(Uri.parse(checkout.payUrl));
      } else {
        // The fake sheet confirms by itself; its result does not matter here.
        await showAppSheet<bool>(
          context,
          builder: (_) => FakePaymentSheet(
            paymentId: checkout.paymentId,
            amountVnd: b.deposit,
          ),
        );
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.bookNetworkError);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  String _providerName(String? code, AppLocalizations l10n) {
    if (!ref.read(realPaymentsProvider)) return l10n.payProviderFake;
    return switch (PaymentProviderCode.fromCode(code)) {
      PaymentProviderCode.momo => l10n.payProviderNamed('MoMo'),
      PaymentProviderCode.vnpay => l10n.payProviderNamed('VNPay'),
      null => l10n.payProviderGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bookingAsync = ref.watch(bookingProvider(widget.bookingId));

    return ScreenCode(
      ScreenCodes.awaitingPayment,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.payTitle)),
        body: SafeArea(
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

              // Draft status: show waiting UI
              final profileAsync = ref.watch(
                photographerProfileProvider(booking.photographerId),
              );
              final photographerName =
                  profileAsync.value?.summary.displayName ?? '';
              final thumbUrl = profileAsync.value?.summary.avatarUrl;

              final providerName = _providerName(booking.depositProvider, l10n);
              final summary = bookingSummaryOf(
                booking,
                photographerName: photographerName,
                thumbUrl: thumbUrl,
                statusLabel: l10n.payAwaitingDeposit,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: SignatureLoader(
                        size: LoaderSize.screen,
                        wave: LoaderWave.vibration,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s6),
                    Text(
                      l10n.payPendingTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      l10n.payPendingBody(providerName),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.s6),
                    BookingCard(data: summary, size: BookingCardSize.compact),
                    const SizedBox(height: AppSpace.s6),
                    AppButton.primary(
                      l10n.payCheckAgain,
                      loading: _checking,
                      onPressed: _changing ? null : _checkAgain,
                    ),
                    const SizedBox(height: AppSpace.s3),
                    AppButton.outline(
                      l10n.payChangeProvider,
                      size: AppButtonSize.small,
                      loading: _changing,
                      onPressed: _changing || _checking
                          ? null
                          : () => _changeProvider(booking),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
