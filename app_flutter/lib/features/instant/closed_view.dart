// `#S13.08-done`: every way a Chụp ngay request ends other than a completed
// shoot (Decision 4) — cancelled by the customer, expired before any invite
// (`abandoned`), or reported absent by the photographer. Money lines use what
// the server wrote on the request (`amountVnd − feeVnd`, `refundPercent`);
// an unpaid request (every #140 one) has no money to speak of.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Where a refund goes ("về MoMo"): the method the request was paid with.
String instantRefundToText(AppLocalizations l, PayMethod? method) =>
    switch (method) {
      PayMethod.momo => l.refundToMomo,
      PayMethod.zaloPay => l.refundToZaloPay,
      PayMethod.bankQr || null => l.refundToBankQr,
    };

class ClosedView extends StatelessWidget {
  const ClosedView({super.key, required this.request});

  final InstantRequest request;

  /// What the customer gets back, as the server recorded it; null when
  /// nothing was paid or nothing comes back.
  int? get _refundVnd {
    if (!request.paid) return null;
    final refund = request.amountVnd - (request.feeVnd ?? 0);
    return refund > 0 ? refund : null;
  }

  (String, String) _texts(AppLocalizations l) {
    final refund = _refundVnd;
    return switch (request.status) {
      InstantStatus.abandoned => (l.abandonedTitle, l.abandonedBody),
      InstantStatus.noShowCustomer => (
        l.noShowTitle,
        refund == null
            ? l.cancelledNoMoney
            : l.noShowBody(formatMoney(refund), request.refundPercent ?? 0),
      ),
      _ => (
        l.cancelledTitle,
        refund == null
            ? l.cancelledNoMoney
            : l.cancelledRefund(
                formatMoney(refund),
                instantRefundToText(l, request.payMethod),
              ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (title, body) = _texts(l);
    return ScreenCode(
      ScreenCodes.instantCancel,
      label: 'done',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(l.instantTitle),
          ),
          body: EmptyState(
            title: title,
            body: body,
            illustration: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.eventBusy,
                  size: 40,
                  color: dark
                      ? AppColorsDark.foregroundSecondary
                      : AppColors.foregroundSecondary,
                ),
              ),
            ),
          ),
          bottomNavigationBar: AppFooterBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton.primary(
                  l.closedNewRequest,
                  key: const Key('closed-new-request'),
                  onPressed: () => context.go('/instant'),
                ),
                const SizedBox(height: AppSpace.s1),
                AppButton.outline(
                  l.doneHome,
                  key: const Key('closed-home'),
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
