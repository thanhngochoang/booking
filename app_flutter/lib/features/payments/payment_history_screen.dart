// lib/features/payments/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/features/payments/payment_history_controller.dart';
import 'package:photobooking/features/payments/refund_account_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S22.01 "Lịch sử thanh toán" at `/me/payments`: what the customer paid and
/// where that money is now (held, refunding, refunded, released), one row per
/// payment, newest first, grouped by month. Every figure comes from the
/// server's rows and totals; the screen does no money arithmetic. There is no
/// primary button: the screen only reads (Decision 15).
class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  /// Last rows shown, kept while a bigger page loads so the list never blinks.
  List<PayerPaymentRow>? _shown;

  /// Ids of the rows that are open; each row toggles on its own.
  final Set<String> _expanded = {};

  void _toggle(PayerPaymentRow row) => setState(() {
    if (!_expanded.remove(row.paymentId)) _expanded.add(row.paymentId);
  });

  /// S22.04 for a row waiting for the refund account; the row's stream
  /// updates it once the choice lands.
  void _chooseAccount(RefundSubject subject) =>
      showRefundAccountSheet(context, ref, subject);

  void _open(PayerPaymentRow row) {
    final id = row.subjectId;
    switch (row.subjectType) {
      case PayerSubjectType.booking:
        context.push('/b/$id');
      case PayerSubjectType.eventRegistration:
        context.go(
          Uri(
            path: '/bookings',
            queryParameters: {'tab': 'events', 'highlight': id},
          ).toString(),
        );
      case PayerSubjectType.instantRequest:
        context.push('/instant/$id');
      case PayerSubjectType.verificationFee || PayerSubjectType.unknown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totals = ref.watch(paymentTotalsProvider);
    final limit = ref.watch(paymentsLimitProvider);
    var rows = ref.watch(paymentHistoryProvider(limit));
    if (rows.hasValue) {
      _shown = rows.requireValue;
    } else if (_shown != null && rows.isLoading) {
      rows = AsyncData(_shown!);
    }
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.s4);
    final error = ErrorState(
      message: l.paymentsLoadError,
      onRetry: () {
        ref.invalidate(paymentTotalsProvider);
        ref.invalidate(paymentHistoryProvider);
      },
    );
    return ScreenCode(
      ScreenCodes.paymentHistory,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const AppIcon(AppIcons.back),
                    onPressed: () => context.go('/settings'),
                  ),
            title: Text(l.paymentsTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.s6),
            children: [
              Padding(
                padding: gutter.copyWith(top: AppSpace.s2),
                child: AsyncView<PaymentTotals>(
                  value: totals,
                  skeleton: (_) => IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: StatTile.skeleton()),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(child: StatTile.skeleton()),
                      ],
                    ),
                  ),
                  error: (_, _, _) => error,
                  data: (_, t) => StatTileRow(
                    tiles: [
                      StatTile(
                        value: formatMoney(t.held, short: true, decimals: 2),
                        semanticsValue: formatMoney(t.held),
                        label: l.paymentsHeld,
                      ),
                      StatTile(
                        value: formatMoney(
                          t.refunding,
                          short: true,
                          decimals: 2,
                        ),
                        semanticsValue: formatMoney(t.refunding),
                        label: l.paymentsRefunding,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: gutter.copyWith(top: AppSpace.s3),
                child: Text(
                  l.paymentsHeldNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              AsyncView<List<PayerPaymentRow>>(
                value: rows,
                skeleton: (_) => Padding(
                  padding: gutter,
                  child: Column(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        EarningRow.skeleton(),
                        const SizedBox(height: AppSpace.s2),
                      ],
                    ],
                  ),
                ),
                error: (_, _, _) => error,
                isEmpty: (list) => list.isEmpty,
                empty: (_) => EmptyState(
                  title: l.paymentsEmptyTitle,
                  body: l.paymentsEmptyBody,
                ),
                data: (_, list) => _Rows(
                  rows: list,
                  limit: limit,
                  expanded: _expanded,
                  onToggle: _toggle,
                  onOpen: _open,
                  onChooseAccount: _chooseAccount,
                  onMore: () => ref.read(paymentsLimitProvider.notifier).more(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rows extends ConsumerWidget {
  const _Rows({
    required this.rows,
    required this.limit,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onChooseAccount,
    required this.onMore,
  });

  final List<PayerPaymentRow> rows;
  final int limit;
  final Set<String> expanded;
  final void Function(PayerPaymentRow) onToggle;
  final void Function(PayerPaymentRow) onOpen;
  final void Function(RefundSubject) onChooseAccount;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final year = toVn(now).year;
    final groups = groupPaymentsByMonth(rows);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var g = 0; g < groups.length; g++) ...[
            _MonthHeader(
              // The mock puts the first month beside "Các khoản".
              title: g == 0
                  ? l.paymentsItems
                  : _monthLabel(l, groups[g].monthKey, year),
              trailing: g == 0
                  ? _monthLabel(l, groups[g].monthKey, year)
                  : null,
            ),
            for (final row in groups[g].rows) ...[
              _row(l, row, now),
              const SizedBox(height: AppSpace.s2),
            ],
          ],
          if (rows.length >= limit)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: AppButton.outline(
                l.paymentsMore,
                key: const Key('payments-more'),
                size: AppButtonSize.small,
                onPressed: onMore,
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(AppLocalizations l, PayerPaymentRow row, DateTime now) {
    final (label, tone) = _status(l, row);
    final subject = refundSubjectOf(row);
    final link = _linkLabel(l, row);
    return EarningRow(
      key: ValueKey('pay-row-${row.paymentId}'),
      title: _title(l, row),
      meta: _meta(l, row, now),
      // Millions truncate to two decimals (never rounded up); below 1M the
      // plain K form (`500K`) is exact for whole-thousand amounts.
      amount: formatMoney(
        row.amount,
        short: true,
        decimals: row.amount >= 1000000 ? 2 : 1,
      ),
      amountLabel: formatMoney(row.amount),
      badge: _StatePill(label: label, tone: tone),
      statusLabel: label,
      breakdown: _breakdown(l, row),
      expanded: expanded.contains(row.paymentId),
      onTap: () => onToggle(row),
      action: subject == null
          ? null
          : AppButton.outline(
              l.payChooseRefundAccount,
              size: AppButtonSize.xsmall,
              tapAlignment: Alignment.centerLeft,
              onPressed: () => onChooseAccount(subject),
            ),
      footer: link == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppButton.text(
                  link,
                  size: AppButtonSize.xsmall,
                  tapAlignment: Alignment.centerLeft,
                  onPressed: () => onOpen(row),
                ),
              ),
            ),
    );
  }
}

/// The row's title from the server's parts (the server writes no display
/// text): "Minh Trí · Chân dung 2 giờ", "Photo walk phố cổ · 2 vé",
/// "Chụp ngay · Quận 1", "Phí xác minh"; "Thanh toán" when the parts are
/// missing or the subject is unknown.
String _title(AppLocalizations l, PayerPaymentRow row) {
  switch (row.subjectType) {
    case PayerSubjectType.booking:
      final who = row.photographerName;
      final what = row.serviceName;
      if (who != null && what != null) return l.payTitleBooking(who, what);
      return who ?? what ?? l.payTitle;
    case PayerSubjectType.eventRegistration:
      final title = row.eventTitle;
      final n = row.quantity;
      if (title == null) return l.payTitle;
      return n == null ? title : l.payTitleTicket(title, n);
    case PayerSubjectType.instantRequest:
      final area = row.areaLabel;
      return area == null ? l.instantTitle : l.payTitleInstant(area);
    case PayerSubjectType.verificationFee:
      return l.verifyFeeTitle;
    case PayerSubjectType.unknown:
      return l.payTitle;
  }
}

String? _methodLabel(AppLocalizations l, PayMethod? method) => switch (method) {
  PayMethod.bankQr => l.payMethodBankQr,
  PayMethod.momo => l.payMethodMomo,
  PayMethod.zaloPay => l.payMethodZaloPay,
  null => null,
};

/// "T7 12/10 · Chuyển khoản QR[ · đang tìm thợ| · đã huỷ]": the shoot or
/// event day, else the day paid ("Hôm nay 09:12" for today), then the method.
String _meta(AppLocalizations l, PayerPaymentRow row, DateTime now) {
  final day = row.day == null ? null : parseDayKey(row.day!);
  final String date;
  if (day != null) {
    date = formatDay(day);
  } else if (vnDateKey(row.createdAt) == vnDateKey(now)) {
    date = l.payMetaToday(formatHm(toVn(row.createdAt)));
  } else {
    date = formatDay(toVn(row.createdAt));
  }
  return [
    date,
    ?_methodLabel(l, row.method),
    if (row.searching) l.payMetaSearching,
    if (row.cancelled) l.payMetaCancelled,
  ].join(' · ');
}

enum _Tone { neutral, live, ok, wait, dispute }

/// The badge text by status and subject, and its mock `.st` tone. A status
/// this app does not know yet reads from `open` only.
(String, _Tone) _status(AppLocalizations l, PayerPaymentRow row) =>
    switch (row.status) {
      PayerRowStatus.held => (l.payStatusHeld, _Tone.live),
      PayerRowStatus.disputed => (l.payStatusDisputed, _Tone.dispute),
      PayerRowStatus.released => (_releasedLabel(l, row), _Tone.ok),
      PayerRowStatus.refundAccountNeeded => (
        l.payStatusNeedsAccount,
        _Tone.wait,
      ),
      PayerRowStatus.refunding => (l.payStatusRefunding, _Tone.wait),
      PayerRowStatus.refunded => (l.payStatusRefunded, _Tone.ok),
      PayerRowStatus.partiallyRefunded => (l.payStatusPartlyRefunded, _Tone.ok),
      PayerRowStatus.unknown => (
        row.open ? l.payStatusHeld : l.payStatusReleasedPlatform,
        _Tone.neutral,
      ),
    };

/// Money passed on: to the photographer, to the event's organiser, or paid to
/// the platform (S21 fee, platform events).
String _releasedLabel(AppLocalizations l, PayerPaymentRow row) {
  if (row.toPlatform) return l.payStatusReleasedPlatform;
  return switch (row.subjectType) {
    PayerSubjectType.booking ||
    PayerSubjectType.instantRequest => l.payStatusReleasedBooking,
    PayerSubjectType.eventRegistration => l.payStatusReleasedTicket,
    PayerSubjectType.verificationFee ||
    PayerSubjectType.unknown => l.payStatusReleasedPlatform,
  };
}

/// "Đã trả", one line per refund ("Hoàn về ví ZaloPay · đang xử lý",
/// "Hoàn về Vietcombank •••• 6789 · đã về") and, while money is on its way
/// back, the bold "Sẽ nhận lại" with the server's refunding amount.
List<EarningBreakdownLine> _breakdown(AppLocalizations l, PayerPaymentRow row) {
  String destination(PayerRefundView r) {
    final label = r.destinationLabel;
    if (label != null) return l.payDetailRefundTo(label);
    final wallet = switch (row.method) {
      PayMethod.momo || PayMethod.zaloPay => _methodLabel(l, row.method),
      _ => null,
    };
    if (r.wallet && wallet != null) {
      return l.payDetailRefundTo(l.payDetailWallet(wallet));
    }
    // A bank refund waiting for the customer's account has no place yet.
    return l.payDetailRefund;
  }

  return [
    EarningBreakdownLine(
      label: l.payDetailPaid,
      value: formatMoney(row.amount),
    ),
    for (final r in row.refunds)
      EarningBreakdownLine(
        label:
            '${destination(r)} · '
            '${r.done ? l.payDetailRefundDone : l.payDetailRefundPending}',
        value: formatMoney(r.amount),
      ),
    if (row.refundingAmount > 0)
      EarningBreakdownLine(
        label: l.payDetailWillGetBack,
        value: formatMoney(row.refundingAmount),
        strong: true,
      ),
  ];
}

/// The way to the paid thing, shown under the open breakdown; none for the
/// S21 fee, a subject this app does not know, or a row without its id.
String? _linkLabel(AppLocalizations l, PayerPaymentRow row) {
  if (row.subjectId.isEmpty) return null;
  return switch (row.subjectType) {
    PayerSubjectType.booking => l.payDetailOpenBooking,
    PayerSubjectType.eventRegistration => l.payDetailOpenTicket,
    PayerSubjectType.instantRequest => l.payDetailOpenInstant,
    PayerSubjectType.verificationFee || PayerSubjectType.unknown => null,
  };
}

/// The mock's `.st` pill: plain text (no capitals), wraps inside 40% of the
/// screen so a long state ("Đã chuyển cho chủ sự kiện") never squeezes the
/// title at large text.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? AppColorsDark.foreground : AppColors.foreground;
    final field = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final (bg, fg) = switch (tone) {
      _Tone.neutral => (
        field,
        dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary,
      ),
      _Tone.live => (field, ink),
      _Tone.ok => (
        dark ? AppColorsDark.freeBg : AppColors.freeBg,
        dark ? AppColorsDark.freeInk : AppColors.freeInk,
      ),
      _Tone.wait => (AppColors.warning.withValues(alpha: 0.24), ink),
      _Tone.dispute => (
        AppColors.error.withValues(alpha: 0.18),
        dark ? AppColorsDark.error : AppColors.error,
      ),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s2,
            vertical: AppSpace.s1,
          ),
          child: Text(
            label,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: AppText.xs,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// "Tháng 10", or "Tháng 10/2025" for another year than [thisYear].
String _monthLabel(AppLocalizations l, String monthKey, int thisYear) {
  final parts = monthKey.split('-');
  final y = int.tryParse(parts.first) ?? thisYear;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
  return y == thisYear ? l.earningsMonth(m) : l.earningsMonthYear(m, y);
}
