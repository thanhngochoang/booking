import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// One line of the read-only price table: [label] names the weekdays that
/// share [price].
typedef PriceTableRow = ({String label, int price});

/// The weekday prices of [p], consecutive days with one price on one row:
/// "Thứ 2 – Thứ 6", "Thứ 7, Chủ nhật", "Thứ 3".
List<PriceTableRow> priceTableRows(AppLocalizations l, PricedService p) {
  final prices = weekPrices(p);
  final rows = <PriceTableRow>[];
  var i = 0;
  while (i < Weekday.values.length) {
    var j = i;
    while (j + 1 < Weekday.values.length &&
        prices[Weekday.values[j + 1]] == prices[Weekday.values[i]]) {
      j++;
    }
    String name(Weekday w) => l.calendarWeekdayLong(w.name);
    final first = name(Weekday.values[i]);
    final last = name(Weekday.values[j]);
    rows.add((
      label: switch (j - i) {
        0 => first,
        1 => '$first, $last',
        _ => '$first – $last',
      },
      price: prices[Weekday.values[i]]!,
    ));
    i = j + 1;
  }
  return rows;
}

String _dm(DateTime d) => '${d.day}/${d.month}';

/// The next special days from [today] (`yyyy-MM-dd`), at most [limit], by
/// start date: "Tết 17/2 · Mùa cưới 14–22/11". Holidays on consecutive days
/// with one name read as one range. Null when there is none.
String? upcomingSpecialDays(
  String today,
  List<Holiday> holidays,
  List<SpecialDayRange> ranges, {
  int limit = 3,
}) {
  final spans = <({String from, String to, String name})>[];
  final sorted = [...holidays]..sort((a, b) => a.day.compareTo(b.day));
  for (final h in sorted) {
    final last = spans.isEmpty ? null : spans.last;
    final prev = last == null ? null : parseDayKey(last.to);
    final cur = parseDayKey(h.day);
    if (last != null &&
        last.name == h.name &&
        prev != null &&
        cur != null &&
        cur.difference(prev).inDays == 1) {
      spans[spans.length - 1] = (from: last.from, to: h.day, name: last.name);
    } else {
      spans.add((from: h.day, to: h.day, name: h.name));
    }
  }
  for (final r in ranges) {
    spans.add((from: r.from, to: r.to, name: r.name));
  }
  spans.sort((a, b) => a.from.compareTo(b.from));
  final parts = <String>[];
  for (final s in spans) {
    if (s.to.compareTo(today) < 0) {
      continue;
    }
    final from = parseDayKey(s.from);
    final to = parseDayKey(s.to);
    if (from == null || to == null) {
      continue;
    }
    final when = s.from == s.to
        ? _dm(from)
        : from.month == to.month
        ? '${from.day}–${_dm(to)}'
        : '${_dm(from)}–${_dm(to)}';
    parts.add('${s.name} $when');
    if (parts.length == limit) {
      break;
    }
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// S03.01 "Bảng giá · {gói}" (mock `#S03.01-prices`): the price of each
/// weekday group and of special days, read-only. "Đặt gói này" is the one
/// primary action; [onBook] is null when the photographer takes no orders.
Future<void> showPriceTableSheet(
  BuildContext context, {
  required String photographerId,
  required String name,
  required PricedService pricing,
  VoidCallback? onBook,
}) => showAppSheet<void>(
  context,
  builder: (_) => PriceTableSheet(
    photographerId: photographerId,
    name: name,
    pricing: pricing,
    onBook: onBook,
  ),
);

class PriceTableSheet extends ConsumerWidget {
  const PriceTableSheet({
    super.key,
    required this.photographerId,
    required this.name,
    required this.pricing,
    this.onBook,
  });

  final String photographerId;
  final String name;
  final PricedService pricing;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const figures = [FontFeature.tabularFigures()];
    final special = pricing.specialPrice;

    String? upcoming;
    if (special != null) {
      final today = ref.watch(calendarTodayProvider);
      final holidays = [
        for (final y in [today.year, today.year + 1])
          ...?ref.watch(holidaysProvider(y)).value,
      ];
      final ranges =
          ref.watch(specialDaysProvider(photographerId)).value ?? const [];
      upcoming = upcomingSpecialDays(dayKeyOf(today), holidays, ranges);
    }

    Widget row(Widget label, int price, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: label),
          const SizedBox(width: AppSpace.s3),
          Text(
            formatMoney(price),
            style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: figures),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.s0301_priceSheetTitle(name),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.bookClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          for (final r in priceTableRows(l, pricing))
            row(
              Text(
                r.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              r.price,
            ),
          if (special != null)
            row(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.s0301_specialRow,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (upcoming != null)
                    Text(
                      upcoming,
                      key: const Key('price-sheet-upcoming'),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
              special,
              key: const Key('price-sheet-special'),
            ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.s0301_priceSheetNote,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.photoBook,
            key: const Key('price-sheet-book'),
            onPressed: onBook == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    onBook!();
                  },
          ),
        ],
      ),
    );
  }
}
