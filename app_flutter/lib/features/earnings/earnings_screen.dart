// lib/features/earnings/earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_providers.dart';
import 'package:photobooking/features/earnings/earnings_analytics.dart';
import 'package:photobooking/features/earnings/earnings_controller.dart';
import 'package:photobooking/features/earnings/widgets/account_inputs.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const _accountRoute = '/work/earnings/account';

/// S06.05 "Thu nhập" at `/work/earnings`: where the photographer's money is
/// (Đang giữ, Chờ chi trả, Đã nhận), the payout account card (or the
/// add-account card) and one row per payment with its state. There is no
/// primary button: the screen only reads.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  /// Last rows shown, kept while a bigger page loads so the list never blinks.
  List<EarningItem>? _shown;

  /// Ids of the rows that are open; each row toggles on its own.
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    ref.read(earningsAnalyticsProvider)('earnings_open', const {});
  }

  void _openAccount() => context.push(_accountRoute);

  /// A tap opens or closes the breakdown of that row (the row no longer links
  /// to the booking: the mock has no link).
  void _toggle(EarningItem item) {
    final opening = !_expanded.contains(item.id);
    setState(() {
      if (opening) {
        _expanded.add(item.id);
      } else {
        _expanded.remove(item.id);
      }
    });
    if (opening) {
      ref.read(earningsAnalyticsProvider)('earnings_item_open', {
        'state': item.state.code,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final summary = ref.watch(earningsSummaryProvider);
    final limit = ref.watch(earningsLimitProvider);
    var items = ref.watch(earningItemsProvider(limit));
    if (items.hasValue) {
      _shown = items.requireValue;
    } else if (_shown != null && items.isLoading) {
      items = AsyncData(_shown!);
    }
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.s4);
    final error = ErrorState(
      message: l.earningsLoadError,
      onRetry: () {
        ref.invalidate(earningsSummaryProvider);
        ref.invalidate(earningItemsProvider);
      },
    );
    return ScreenCode(
      ScreenCodes.earnings,
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
                    onPressed: () => context.go('/bookings'),
                  ),
            title: Text(l.earningsTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.s6),
            children: [
              if (summary.value?.fromCache == true) const OfflineBanner(),
              Padding(
                padding: gutter.copyWith(top: AppSpace.s2),
                child: EscrowNotice(text: l.earningsNotice),
              ),
              const SizedBox(height: AppSpace.s3),
              Padding(
                padding: gutter,
                child: AsyncView<EarningsSummary>(
                  value: summary,
                  skeleton: (_) => IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpace.s2),
                          Expanded(child: StatTile.skeleton()),
                        ],
                      ],
                    ),
                  ),
                  error: (_, _, _) => error,
                  data: (_, s) => _Totals(
                    summary: s,
                    accountUpdatedAt: ref
                        .watch(payoutAccountProvider)
                        .value
                        ?.updatedAt,
                    onOpenAccount: _openAccount,
                  ),
                ),
              ),
              AsyncView<PayoutAccountView?>(
                value: ref.watch(payoutAccountProvider),
                skeleton: (_) => const SizedBox.shrink(),
                error: (_, _, _) => const SizedBox.shrink(),
                // The mock's account row: the active account, or the
                // reminder to add one. Both open S06.06.
                data: (_, account) => Padding(
                  padding: gutter.copyWith(top: AppSpace.s3),
                  child: account == null
                      ? _AddAccountCard(onTap: _openAccount)
                      : _AccountCard(account: account, onTap: _openAccount),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              AsyncView<List<EarningItem>>(
                value: items,
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
                  title: l.earningsEmptyTitle,
                  body: l.earningsEmptyBody,
                ),
                data: (_, list) => _Rows(
                  items: list,
                  limit: limit,
                  expanded: _expanded,
                  onToggle: _toggle,
                  onMore: () => ref.read(earningsLimitProvider.notifier).more(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.summary,
    required this.accountUpdatedAt,
    required this.onOpenAccount,
  });

  final EarningsSummary summary;

  /// `updatedAt` of the active account: an account saved after the failed
  /// payout means the payee already fixed it, so the banner goes away.
  final DateTime? accountUpdatedAt;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTileRow(
          tiles: [
            StatTile(
              value: formatMoney(summary.heldVnd, short: true, decimals: 2),
              semanticsValue: formatMoney(summary.heldVnd),
              label: l.earningsHeld,
            ),
            StatTile(
              value: formatMoney(summary.soonVnd, short: true, decimals: 2),
              semanticsValue: formatMoney(summary.soonVnd),
              label: l.earningsSoon,
            ),
            StatTile(
              value: formatMoney(summary.receivedVnd, short: true, decimals: 2),
              semanticsValue: formatMoney(summary.receivedVnd),
              label: l.earningsReceived,
            ),
          ],
        ),
        if (summary.lastPayoutFailed &&
            !(accountUpdatedAt != null &&
                summary.lastPayoutAt != null &&
                accountUpdatedAt!.isAfter(summary.lastPayoutAt!))) ...[
          const SizedBox(height: AppSpace.s3),
          _LinkCard(
            key: const Key('earnings-payout-failed'),
            leading: const AppIcon(AppIcons.warning),
            title: l.earningsPayoutFailed,
            onTap: onOpenAccount,
          ),
        ],
      ],
    );
  }
}

/// The mock's `.card` row: bank badge, "Tài khoản nhận tiền" and
/// "{bankCode} •••• {last4}", chevron to S06.06.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onTap});

  final PayoutAccountView account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkCard(
      key: const Key('earnings-account'),
      leading: BankBadge(code: account.bankCode),
      title: l.payoutAccountTitle,
      sub: '${account.bankCode} ${l.payoutAccountMasked(account.accountLast4)}',
      tabularSub: true,
      onTap: onTap,
    );
  }
}

class _AddAccountCard extends StatelessWidget {
  const _AddAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkCard(
      key: const Key('earnings-add-account'),
      leading: const AppIcon(AppIcons.payment),
      title: l.earningsAddAccount,
      sub: l.earningsAddAccountSub,
      onTap: onTap,
    );
  }
}

/// A glass card with an icon or badge, text and a chevron that opens S06.06.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    super.key,
    required this.leading,
    required this.title,
    this.sub,
    this.tabularSub = false,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? sub;

  /// Digits of [sub] in tabular figures (the masked account number).
  final bool tabularSub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      highlight: false,
      child: Semantics(
        button: true,
        label: sub == null ? title : '$title. $sub',
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (sub != null)
                          Text(
                            sub!,
                            style: tabularSub
                                ? theme.textTheme.bodySmall?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  )
                                : theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const AppIcon(AppIcons.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rows extends ConsumerWidget {
  const _Rows({
    required this.items,
    required this.limit,
    required this.expanded,
    required this.onToggle,
    required this.onMore,
  });

  final List<EarningItem> items;
  final int limit;
  final Set<String> expanded;
  final void Function(EarningItem) onToggle;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final year = toVn(ref.watch(clockProvider)()).year;
    final groups = groupByMonth(items);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var g = 0; g < groups.length; g++) ...[
            // The mock puts the first month beside "Các khoản"; later ones
            // are small upper-case section labels.
            if (g == 0)
              MonthHeader.first(
                title: l.earningsItems,
                trailing: monthLabel(l, groups[g].monthKey, year),
              )
            else
              MonthHeader.month(month: monthLabel(l, groups[g].monthKey, year)),
            for (final item in groups[g].items) ...[
              _row(context, l, item),
              const SizedBox(height: AppSpace.s2),
            ],
          ],
          if (items.length >= limit)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: AppButton.outline(
                l.earningsMore,
                key: const Key('earnings-more'),
                onPressed: onMore,
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l, EarningItem item) {
    final name = item.counterpartName.isEmpty
        ? l.earningsCustomerFallback
        : item.counterpartName;
    final title = item.subjectLabel.isEmpty
        ? name
        : '$name · ${item.subjectLabel}';
    final day = parseDayKey(item.day);
    final reason = _holdLabel(l, item);
    return EarningRow(
      key: ValueKey(item.id),
      title: title,
      meta: _meta(l, item, day),
      // Millions truncate to two decimals (never rounded up); below 1M the
      // plain K form (`450K`) is exact for whole-thousand amounts.
      amount: formatMoney(
        item.amountVnd,
        short: true,
        decimals: item.amountVnd >= 1000000 ? 2 : 1,
      ),
      amountLabel: formatMoney(item.amountVnd),
      badge: _badge(l, item),
      note: reason == null ? null : l.earningsHoldReason(reason),
      noteIcon: reason == null ? null : AppIcons.warning,
      breakdown: _breakdown(l, item),
      expanded: expanded.contains(item.id),
      // Every row expands to its breakdown, a Chụp ngay job (#202) too (mock
      // S06.05 wins over the plan's "opens /work/instant").
      onTap: () => onToggle(item),
    );
  }
}

/// "T3 01/10 · đủ 2 mốc": the day, then the milestones when the booking has
/// them; a refunded milestone appends " · mốc {n} đã hoàn cho khách" (#207).
String _meta(AppLocalizations l, EarningItem item, DateTime? day) {
  final date = day == null ? item.day : formatDay(day);
  final total = item.milestonesTotal;
  if (total == null || total <= 0) return date;
  final done = item.milestonesDone ?? 0;
  final refunded = item.milestonesRefunded;
  final milestones = done >= total && refunded.isEmpty
      ? l.earningsMilestonesAll(total)
      : l.earningsMilestones(done, total);
  final suffix = [
    for (final k in refunded)
      l.earningsMilestoneRefundedSuffix(k == 'shoot' ? 1 : 2),
  ].join();
  return '$date · $milestones$suffix';
}

/// `700` is "7%", `750` is "7,5%".
String _percent(int bp) => bp % 100 == 0
    ? '${bp ~/ 100}%'
    : '${(bp / 100).toStringAsFixed(1).replaceAll('.', ',')}%';

/// The lines under an open row, in the mock's order. A paid row shows the
/// payout item's own numbers, after the transfer day (the pill only says "Đã
/// chuyển"); every other row shows the estimate. The tax line is absent for a
/// studio (rate 0), the commission line while it is 0.
List<EarningBreakdownLine> _breakdown(AppLocalizations l, EarningItem item) {
  final paid = item.state == EarningState.paidOut;
  final paidOutAt = item.paidOutAt;
  return [
    if (paid && paidOutAt != null)
      EarningBreakdownLine(
        label: l.earningsBreakdownPaidOn,
        value: formatDayMonth(toVn(paidOutAt)),
      ),
    EarningBreakdownLine(
      label: paid ? l.earningsBreakdownReleased : l.earningsBreakdownAmount,
      value: formatMoney(item.amountVnd),
    ),
    if (item.feeVnd > 0)
      EarningBreakdownLine(
        label: l.earningsBreakdownFee(_percent(item.feeRateBp)),
        value: formatMoney(item.feeVnd),
      ),
    if (item.taxVnd > 0 || item.taxRateBp > 0)
      EarningBreakdownLine(
        label: l.earningsBreakdownTax(_percent(item.taxRateBp)),
        value: formatMoney(item.taxVnd),
      ),
    EarningBreakdownLine(
      label: paid ? l.earningsBreakdownNet : l.earningsBreakdownNetEstimated,
      value: formatMoney(item.netVnd),
      strong: true,
    ),
  ];
}

/// The fixed label of a hold reason code; free text never reaches the screen.
String? _holdLabel(AppLocalizations l, EarningItem item) {
  final code =
      item.holdReason ??
      (item.state == EarningState.disputed ? holdReasonDispute : null);
  return switch (code) {
    holdReasonDispute => l.earningsHoldDispute,
    holdReasonPayoutOnHold => l.earningsHoldPayoutOnHold,
    _ => null,
  };
}

/// Badge colours follow the mock (.b-pen / .b-warn / .b-ok) and the booking
/// badges; the warning yellow needs dark ink.
Widget _badge(AppLocalizations l, EarningItem item) {
  final (label, bg, on) = switch (item.state) {
    EarningState.held => (
      l.earningsStateHeld,
      AppColors.bookingWaiting,
      AppColors.foregroundInverse,
    ),
    EarningState.released => (
      l.earningsStateReleased,
      AppColors.warning,
      AppColors.foreground,
    ),
    EarningState.paidOut => (
      l.earningsStatePaid,
      AppColors.success,
      AppColors.foregroundInverse,
    ),
    EarningState.disputed => (
      l.earningsStateDispute,
      AppColors.bookingDenied,
      AppColors.foregroundInverse,
    ),
  };
  return StatusBadge.custom(label: label, color: bg, onColor: on);
}
