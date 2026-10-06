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
import 'package:photobooking/l10n/app_localizations.dart';

const _accountRoute = '/work/earnings/account';

/// S06.05 "Thu nhập" at `/work/earnings`: where the photographer's money is
/// (Đang giữ, Sắp nhận, Đã nhận) and one row per payment with its state. There
/// is no primary button: the screen only reads.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  /// Last rows shown, kept while a bigger page loads so the list never blinks.
  List<EarningItem>? _shown;

  @override
  void initState() {
    super.initState();
    ref.read(earningsAnalyticsProvider)('earnings_open', const {});
  }

  void _openAccount() => context.push(_accountRoute);

  void _openItem(EarningItem item) {
    ref.read(earningsAnalyticsProvider)('earnings_item_open', {
      'state': item.state.code,
    });
    context.push('/b/${item.subjectId}');
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
            actions: [
              IconButton(
                key: const Key('earnings-account'),
                tooltip: l.payoutAccountTitle,
                constraints: const BoxConstraints.tightFor(
                  width: AppSpace.s12,
                  height: AppSpace.s12,
                ),
                icon: const AppIcon(AppIcons.settings),
                onPressed: _openAccount,
              ),
            ],
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
                  data: (_, s) =>
                      _Totals(summary: s, onOpenAccount: _openAccount),
                ),
              ),
              AsyncView<PayoutAccountView?>(
                value: ref.watch(payoutAccountProvider),
                skeleton: (_) => const SizedBox.shrink(),
                error: (_, _, _) => const SizedBox.shrink(),
                data: (_, account) => account != null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: gutter.copyWith(top: AppSpace.s3),
                        child: _AddAccountCard(onTap: _openAccount),
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
                  onOpen: _openItem,
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
  const _Totals({required this.summary, required this.onOpenAccount});

  final EarningsSummary summary;
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
              value: formatMoney(summary.heldVnd, short: true),
              label: l.earningsHeld,
            ),
            StatTile(
              value: formatMoney(summary.soonVnd, short: true),
              label: l.earningsSoon,
            ),
            StatTile(
              value: formatMoney(summary.receivedVnd, short: true),
              label: l.earningsReceived,
            ),
          ],
        ),
        if (summary.lastPayoutFailed) ...[
          const SizedBox(height: AppSpace.s3),
          _LinkCard(
            key: const Key('earnings-payout-failed'),
            icon: AppIcons.warning,
            title: l.earningsPayoutFailed,
            onTap: onOpenAccount,
          ),
        ],
      ],
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
      icon: AppIcons.payment,
      title: l.earningsAddAccount,
      sub: l.earningsAddAccountSub,
      onTap: onTap,
    );
  }
}

/// A glass card with an icon, text and a chevron that opens S06.06.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    super.key,
    required this.icon,
    required this.title,
    this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? sub;
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
                  AppIcon(icon),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (sub != null)
                          Text(sub!, style: theme.textTheme.bodySmall),
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
    required this.onOpen,
    required this.onMore,
  });

  final List<EarningItem> items;
  final int limit;
  final void Function(EarningItem) onOpen;
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
            _MonthHeader(
              // The mock puts the first month beside "Các khoản".
              title: g == 0
                  ? l.earningsItems
                  : _monthLabel(l, groups[g].monthKey, year),
              trailing: g == 0
                  ? _monthLabel(l, groups[g].monthKey, year)
                  : null,
            ),
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
      meta: day == null ? item.day : formatDay(day),
      amount: formatMoney(item.amountVnd, short: true),
      amountLabel: formatMoney(item.amountVnd),
      badge: _badge(l, item),
      note: reason == null ? null : l.earningsHoldReason(reason),
      noteIcon: reason == null ? null : AppIcons.warning,
      onTap: item.subjectType == 'booking' ? () => onOpen(item) : null,
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
      item.paidOutAt == null
          ? l.earningsReceived
          : l.earningsStatePaid(formatDayMonth(toVn(item.paidOutAt!))),
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
