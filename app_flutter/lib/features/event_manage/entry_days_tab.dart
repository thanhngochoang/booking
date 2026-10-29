// lib/features/event_manage/entry_days_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/organizer_routes.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// Day chips after "Hôm nay" (open days only).
const _nextDays = 6;

/// The paid tickets of one visit day: count and amount per ticket type, in
/// the event's type order (types no longer listed go last).
({
  int tickets,
  int amount,
  List<({String id, String name, int qty, int amount})> rows,
})
entryDaySales(EntryEvent event, Iterable<EventRegistration> regs, String day) {
  final qty = <String, int>{};
  final amount = <String, int>{};
  final names = <String, String>{};
  var tickets = 0;
  var total = 0;
  for (final r in regs) {
    if (r.status != RegistrationStatus.paid || r.visitDay != day) continue;
    for (final i in r.items) {
      qty[i.ticketTypeId] = (qty[i.ticketTypeId] ?? 0) + i.qty;
      amount[i.ticketTypeId] = (amount[i.ticketTypeId] ?? 0) + i.amount;
      names[i.ticketTypeId] = i.name;
      tickets += i.qty;
      total += i.amount;
    }
  }
  final order = [
    for (final t in event.ticketTypes)
      if (qty.containsKey(t.id)) t.id,
    for (final id in qty.keys)
      if (!event.ticketTypes.any((t) => t.id == id)) id,
  ];
  return (
    tickets: tickets,
    amount: total,
    rows: [
      for (final id in order)
        (
          id: id,
          name:
              event.ticketTypes.where((t) => t.id == id).firstOrNull?.name ??
              names[id] ??
              '',
          qty: qty[id]!,
          amount: amount[id]!,
        ),
    ],
  );
}

/// S12.03-entry (mock `#S12.03-entry`): an entry event is managed per visit
/// day: chips (today and the next open days, or any day of the range), the
/// day's KPI line, the paid tickets per type, and "Đóng ngày này" (red text
/// → red confirm → `closeEntryDay`, 100% refunds). Primary "Quét mã"
/// (S30.07), secondary "Sửa" (S30.04). No attendee names (spec).
class EntryDaysTab extends ConsumerStatefulWidget {
  const EntryDaysTab({super.key, required this.event});

  final EntryEvent event;

  @override
  ConsumerState<EntryDaysTab> createState() => _EntryDaysTabState();
}

class _EntryDaysTabState extends ConsumerState<EntryDaysTab> {
  String? _day;
  bool _closing = false;

  Future<void> _pickDay(String today) async {
    final e = widget.event;
    final first = parseDayKey(e.startDay)!;
    final last = parseDayKey(e.endDay)!;
    final current = parseDayKey(_day ?? today)!;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first)
          ? first
          : current.isAfter(last)
          ? last
          : current,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _day = dayKeyOf(picked));
  }

  Future<void> _close(String day, int tickets, int amount) async {
    final l = context.l10n;
    final actions = ref.read(organizerActionsProvider);
    String? failed;
    final yes = await showConfirmSheet(
      context,
      title: l.s1203_closeDayTitle(dayLabel(day)),
      body: l.s1203_closeDayBody(tickets, formatMoney(amount)),
      confirmLabel: l.s1203_closeDayConfirm,
      keepLabel: l.s30_keep,
      onConfirm: () async {
        setState(() => _closing = true);
        failed = await actions.run(
          (r) => r.closeEntryDay(widget.event.id, day),
        );
      },
    );
    if (!mounted) return;
    setState(() => _closing = false);
    if (!yes) return;
    orgSay(
      context,
      failed == null
          ? l.s1203_closeDone(dayLabel(day))
          : organizerErrorText(l, failed!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final e = widget.event;
    final today = vnDateKey(ref.watch(clockProvider)());
    final day = _day ?? today;
    final chips = <String>{
      today,
      ...e.openDays(addDays(today, 1), _nextDays),
      ?_day,
    }.toList()..sort();
    final entryDay = ref
        .watch(entryDayProvider((eventId: e.id, day: day)))
        .value;
    // One visit day only, never the whole season (final fix A-I4).
    final regs =
        ref
            .watch(entryDayRegistrationsProvider((eventId: e.id, day: day)))
            .value ??
        const [];
    final sales = entryDaySales(e, regs, day);
    final cap = e.dailyCapacity;
    final sold = entryDay?.sold ?? 0;
    final entered = entryDay?.checkedIn ?? 0;
    final revenue = formatMoney(sales.amount);
    final closed = entryDay?.closed ?? e.closedDays.contains(day);
    final canClose = !closed && day.compareTo(today) >= 0 && e.isOpenDay(day);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.mutedForeground,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              GlassCard(
                highlight: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l.s1203_range(
                                dayLabel(e.startDay),
                                dayLabel(e.endDay),
                                e.visibleTicketTypes.length,
                              ),
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      OrgBadge(l.s3003_onSale),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final d in chips)
                    AppChip(
                      key: Key('entry-day-$d'),
                      label: d == today ? l.s1203_today : dayChipLabel(d),
                      selected: d == day,
                      onChanged: (_) => setState(() => _day = d),
                    ),
                  AppChip(
                    key: const Key('entry-day-pick'),
                    label: l.s1203_pickDay,
                    semanticsLabel: l.s1203_pickDay,
                    selected: false,
                    leading: const AppIcon(AppIcons.calendar, size: 16),
                    onChanged: (_) => _pickDay(today),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                cap == null
                    ? l.s1203_dayKpiNoCap(sold, entered, revenue)
                    : l.s1203_dayKpi(sold, cap, entered, revenue),
                key: const Key('entry-kpi'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (closed) ...[
                const SizedBox(height: AppSpace.s3),
                OrgBand(
                  key: const Key('entry-day-closed'),
                  text: l.s1203_closed,
                  icon: AppIcons.eventBusy,
                  tone: OrgBandTone.warning,
                ),
              ],
              OrgSection(l.s1203_byType),
              if (sales.rows.isEmpty)
                Text(l.s1203_noSales, style: muted)
              else
                GlassCard(
                  highlight: false,
                  child: Column(
                    children: [
                      for (final r in sales.rows)
                        ListTile(
                          key: Key('entry-type-row-${r.id}'),
                          dense: true,
                          title: Text(r.name),
                          trailing: Text(
                            l.s1203_typeRow(r.qty, formatMoney(r.amount)),
                            style: muted?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (canClose) ...[
                const SizedBox(height: AppSpace.s3),
                OrgDangerText(
                  l.s1203_closeDay,
                  key: const Key('entry-close-day'),
                  onPressed: _closing
                      ? null
                      : () => _close(day, sales.tickets, sales.amount),
                ),
              ],
            ],
          ),
        ),
        AppFooterBar(
          child: SizedBox(
            height: controlHeight,
            child: Row(
              children: [
                Expanded(
                  flex: 40,
                  child: AppButton.outline(
                    l.s1203_edit,
                    key: const Key('entry-edit'),
                    onPressed: () => context.push(entryEditPath(e.id)),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  flex: 60,
                  child: AppButton.primary(
                    l.s1203_scan,
                    key: const Key('entry-scan'),
                    onPressed: () => context.push(scanPath),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
