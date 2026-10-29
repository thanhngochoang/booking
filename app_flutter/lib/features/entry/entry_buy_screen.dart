// S30.05 `/spots/:spotId/tickets`: entry tickets for one visit day. The spot
// card, the open days of the next 14 (sold-out ones dimmed), a counter per
// ticket type (1–10 in all), the total, the refund cutoff and "Thanh toán
// {tổng}" → `registerEntry` → S04.04. Without a phone: S04.05 first.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/entry/entry_buy_controller.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// `/spots/{id}/tickets`.
String entryBuyPath(String spotId) => '/spots/$spotId/tickets';

class EntryBuyScreen extends ConsumerStatefulWidget {
  const EntryBuyScreen({super.key, required this.spotId});

  final String spotId;

  @override
  ConsumerState<EntryBuyScreen> createState() => _EntryBuyScreenState();
}

class _EntryBuyScreenState extends ConsumerState<EntryBuyScreen> {
  /// A day picked with "Chọn ngày" beyond the chips.
  String? _pickedDay;

  EntryBuyController get _ctl =>
      ref.read(entryBuyControllerProvider(widget.spotId).notifier);

  bool _soldOut(EntryEvent e, String day) {
    final row = ref.watch(entryDayProvider((eventId: e.id, day: day))).value;
    if (row == null) return false;
    return row.closed || row.left(e.dailyCapacity) == 0;
  }

  Future<void> _pickDay(EntryEvent e, String today) async {
    final first = parseDayKey(today)!;
    final last = parseDayKey(e.endDay) ?? first;
    if (last.isBefore(first)) return;
    DateTime initial = first;
    while (!e.isOpenDay(dayKeyOf(initial)) && initial.isBefore(last)) {
      initial = initial.add(const Duration(days: 1));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (d) => e.isOpenDay(dayKeyOf(d)),
    );
    if (picked == null || !mounted) return;
    final key = dayKeyOf(picked);
    setState(() => _pickedDay = key);
    _ctl.selectDay(key);
  }

  Future<void> _pay(EntryEvent e, String day) async {
    // The contact may still be loading: wait for it before sending a
    // customer who has a phone to S04.05.
    String? phone;
    final hold = ref.listenManual(currentContactProvider, (_, _) {});
    try {
      phone = (await ref.read(currentContactProvider.future))?.phone;
    } catch (_) {
      phone = null;
    } finally {
      hold.close();
    }
    if (!mounted) return;
    if (phone == null || phone.isEmpty) {
      _toPhone();
      return;
    }
    final out = await _ctl.submit(e, day);
    if (!mounted || out == null) return;
    switch (out) {
      case EntryHeld(:final outcome):
        final subject = TicketPay(e.id, outcome.registrationId);
        final inst = outcome.instructions;
        if (inst != null) {
          await openPayment(context, ref, subject: subject, instructions: inst);
        } else {
          await context.push(payPathOf(subject));
        }
      case EntryRefused(:final refusal):
        switch (refusal) {
          case RegisterRefusal.phoneRequired:
            _toPhone();
          case RegisterRefusal.soldOutDay || RegisterRefusal.dayClosed:
            // The chips read their days again; the refused day is dropped.
            ref.invalidate(entryDayProvider((eventId: e.id, day: day)));
            if (_pickedDay == day) setState(() => _pickedDay = null);
            _ctl.dropDay();
          default:
            break;
        }
    }
  }

  void _toPhone() {
    final back = Uri.encodeComponent(entryBuyPath(widget.spotId));
    context.push('/profile/phone?returnTo=$back');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final spot = ref.watch(spotProvider(widget.spotId));
    final event = ref.watch(entryEventProvider(widget.spotId));
    return ScreenCode(
      ScreenCodes.entryTicketsBuy,
      child: Scaffold(
        appBar: AppBar(title: Text(l.s3005_title)),
        body: AsyncView<EntryEvent?>(
          value: event,
          onRetry: () => ref.invalidate(entryEventProvider(widget.spotId)),
          isEmpty: (e) => e == null || e.visibleTicketTypes.isEmpty,
          empty: (_) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s6),
              child: Text(l.s3005_noSale, textAlign: TextAlign.center),
            ),
          ),
          data: (context, e) => _body(context, e!, spot.value),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, EntryEvent e, Spot? spot) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final s = ref.watch(entryBuyControllerProvider(widget.spotId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctl.start(e);
    });
    final today = vnDateKey(ref.watch(clockProvider)());
    final days = [
      ...entryDaysFrom(e, today),
      if (_pickedDay != null && !entryDaysFrom(e, today).contains(_pickedDay))
        _pickedDay!,
    ];
    final sold = {for (final d in days) d: _soldOut(e, d)};
    final chosen = s.day != null && sold[s.day] != true
        ? s.day
        : days.where((d) => sold[d] != true).firstOrNull;
    final types = e.visibleTicketTypes;
    final total = s.total;
    final amount = s.amountFor(types);
    final dayLabel = chosen == null
        ? ''
        : (chosen == today ? l.spotDayToday : formatDay(parseDayKey(chosen)!));
    final refusal = switch (s.refusal) {
      null => null,
      RegisterRefusal.soldOutDay => l.s3005_soldOutError,
      RegisterRefusal.dayClosed => l.s3005_dayClosed,
      RegisterRefusal.limit => l.s3005_limit,
      RegisterRefusal.conflict => l.s3005_conflict,
      RegisterRefusal.network => l.s30_network,
      RegisterRefusal.phoneRequired => null,
      _ => l.s30_error,
    };
    final hours = '${e.openHours.start}–${e.openHours.end}';
    final org = e.organizerName;
    final note = [
      l.s3005_oneQr,
      if (chosen != null)
        l.s3005_refund(entryCutoffLabel(chosen, e.refundCutoffHours)),
    ].join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s3),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: spot?.cover?.url.isNotEmpty == true
                              ? NetworkPhoto(
                                  url: spot!.cover!.cardUrl,
                                  fit: BoxFit.cover,
                                  semanticLabel: spot.name,
                                )
                              : ColoredBox(
                                  color: dark
                                      ? AppColorsDark.surfaceMuted
                                      : AppColors.surfaceMuted,
                                  child: Center(
                                    child: AppIcon(
                                      AppIcons.ticket,
                                      color: secondary,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot?.name ?? e.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpace.s1),
                            Text(
                              org.isEmpty
                                  ? hours
                                  : l.s3005_spotMeta(hours, org),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              if (days.isEmpty)
                Text(l.s3005_noDays, style: theme.textTheme.bodyMedium)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final d in days) ...[
                        AppChip(
                          key: Key('entry-day-$d'),
                          label: _chipLabel(l, d, today, sold[d] == true),
                          selected: d == chosen,
                          enabled: sold[d] != true && !s.submitting,
                          onChanged: (_) => _ctl.selectDay(d),
                        ),
                        const SizedBox(width: AppSpace.s2),
                      ],
                      AppChip(
                        key: const Key('entry-day-pick'),
                        label: l.s3005_pickDay,
                        selected: false,
                        leading: const AppIcon(AppIcons.calendar, size: 14),
                        enabled: !s.submitting,
                        onChanged: (_) => _pickDay(e, today),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.s3),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                    vertical: AppSpace.s1,
                  ),
                  child: Column(
                    children: [
                      for (final t in types)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    formatMoney(t.price),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            QtyStepper(
                              keyPrefix: 'entry-${t.id}',
                              value: s.countOf(t.id),
                              min: 0,
                              max:
                                  entryTicketsPerOrder -
                                  (total - s.countOf(t.id)),
                              enabled: !s.submitting,
                              valueLabel: l.ticketCount(s.countOf(t.id)),
                              decrementLabel: l.s3005_less(t.name),
                              incrementLabel: l.s3005_more(t.name),
                              onChanged: (n) => _ctl.setCount(t.id, n),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (total >= entryTicketsPerOrder) ...[
                const SizedBox(height: AppSpace.s2),
                Text(
                  l.s3005_limit,
                  key: const Key('entry-limit'),
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
              const SizedBox(height: AppSpace.s3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chosen == null ? '' : l.s3005_total(total, dayLabel),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    formatMoney(amount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
              if (refusal != null) ...[
                const SizedBox(height: AppSpace.s3),
                Text(
                  refusal,
                  key: const Key('entry-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: dark ? AppColorsDark.destructive : AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l.s3005_pay(formatMoney(amount)),
              key: const Key('entry-pay'),
              loading: s.submitting,
              onPressed: total == 0 || chosen == null
                  ? null
                  : () => unawaited(_pay(e, chosen)),
            ),
          ),
        ),
      ],
    );
  }

  String _chipLabel(
    AppLocalizations l,
    String day,
    String today,
    bool soldOut,
  ) {
    final name = day == today ? l.spotDayToday : formatDay(parseDayKey(day)!);
    return soldOut ? l.s3005_dayChipSoldOut(name) : name;
  }
}
