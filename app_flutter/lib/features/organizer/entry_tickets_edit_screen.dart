// lib/features/organizer/entry_tickets_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/organizer_routes.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';
import 'package:photobooking/features/organizer/widgets/ticket_type_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// T2…T7, CN as the domain's weekday codes (0 = Sunday).
const _weekdayCodes = [1, 2, 3, 4, 5, 6, 0];

/// A new sale range covers 30 days.
const _defaultDays = 30;

/// S30.04 "Vé vào cửa" (mock `#S30.04`): create (`/organizer/entry/new?spot=`,
/// "Mở bán" = `saveEventDraft` + `publishEvent` with `type: entry`) or edit
/// (`/organizer/entry/:eventId/edit`, "Lưu thay đổi" = `updateEvent`) the
/// spot's entry tickets. The rules of `validateEntryEvent` and the entry edit
/// (sold types only hide, a day's cap never under its tickets) are checked
/// here first; the server checks them again.
class EntryTicketsEditScreen extends ConsumerStatefulWidget {
  const EntryTicketsEditScreen({super.key, this.spotId, this.eventId});

  /// The managed spot of a new entry event.
  final String? spotId;

  /// The entry event being edited.
  final String? eventId;

  @override
  ConsumerState<EntryTicketsEditScreen> createState() =>
      _EntryTicketsEditScreenState();
}

class _EntryTicketsEditScreenState
    extends ConsumerState<EntryTicketsEditScreen> {
  final _name = TextEditingController();
  final _open = TextEditingController(text: '06:00');
  final _close = TextEditingController(text: '22:00');
  final _capacity = TextEditingController();
  late String _startDay;
  late String _endDay;
  final Set<int> _weekdays = {};
  final List<String> _closedDays = [];
  final List<EntryTicketType> _types = [];
  int _refundCutoffHours = 48;
  String? _spotId;
  bool _ready = false;
  bool _busy = false;
  Map<EntryField, String> _errors = const {};

  /// The entry draft a "Mở bán" already saved whose publish failed: a retry
  /// saves over it and publishes it, never a second draft.
  String? _savedDraftId;

  bool get _editing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    _spotId = widget.spotId;
    _startDay = _today();
    _endDay = addDays(_startDay, _defaultDays - 1);
  }

  @override
  void dispose() {
    _name.dispose();
    _open.dispose();
    _close.dispose();
    _capacity.dispose();
    super.dispose();
  }

  String _today() => vnDateKey(ref.read(clockProvider)());

  void _fromSpot(Spot s) {
    if (_ready) return;
    _ready = true;
    _name.text = s.name;
    if (s.openHours case final h?) {
      _open.text = h.start;
      _close.text = h.end;
    }
  }

  void _fromEvent(EntryEvent e) {
    if (_ready) return;
    _ready = true;
    _spotId = e.spotId;
    _name.text = e.title;
    _startDay = e.startDay;
    _endDay = e.endDay;
    _open.text = e.openHours.start;
    _close.text = e.openHours.end;
    _capacity.text = e.dailyCapacity?.toString() ?? '';
    _weekdays.addAll(e.closedWeekdays);
    _closedDays.addAll(e.closedDays);
    _types.addAll(e.ticketTypes);
    _refundCutoffHours = e.refundCutoffHours;
  }

  Future<void> _pickDay({required bool start}) async {
    final today = parseDayKey(_today())!;
    final from = parseDayKey(_startDay)!;
    final DateTime first;
    final DateTime last;
    if (start) {
      first = _editing && from.isBefore(today) ? from : today;
      last = today.add(const Duration(days: 365));
    } else {
      first = from;
      last = from.add(const Duration(days: entryRangeMaxDays - 1));
    }
    final current = parseDayKey(start ? _startDay : _endDay)!;
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
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDay = dayKeyOf(picked);
        if (_endDay.compareTo(_startDay) < 0) _endDay = _startDay;
      } else {
        _endDay = dayKeyOf(picked);
      }
    });
  }

  Future<void> _addClosedDay() async {
    final l = context.l10n;
    if (_closedDays.length >= entryClosedDaysMax) {
      orgSay(context, l.s3004_closedDaysMax);
      return;
    }
    final first = parseDayKey(_startDay)!;
    final last = parseDayKey(_endDay)!;
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last.isBefore(first) ? first : last,
    );
    if (picked == null || !mounted) return;
    final day = dayKeyOf(picked);
    if (!_closedDays.contains(day)) {
      setState(
        () => _closedDays
          ..add(day)
          ..sort(),
      );
    }
  }

  Future<void> _editType(int? index, Set<String> soldIds) async {
    final existing = index == null ? null : _types[index];
    final r = await showTicketTypeSheet(
      context,
      existing: existing,
      sold: existing != null && soldIds.contains(existing.id),
    );
    if (r == null || !mounted) return;
    setState(() {
      switch (r) {
        case TicketTypeSaved(:final type):
          if (index == null) {
            _types.add(type);
          } else {
            _types[index] = type;
          }
        case TicketTypeDeleted():
          if (index != null) _types.removeAt(index);
      }
    });
  }

  String _ruleText(
    AppLocalizations l,
    EntryRule rule,
    Map<String, int> soldPerDay,
  ) => switch (rule) {
    EntryRule.rangeTooLong => l.s3004_rangeTooLong,
    EntryRule.startPast => l.s3004_startPast,
    EntryRule.endBeforeStart => l.s3004_endBeforeStart,
    EntryRule.timeFormat => l.s3004_timeFormat,
    EntryRule.hoursInvalid => l.s3004_hoursInvalid,
    EntryRule.capacityInvalid => l.s3004_capacityInvalid,
    EntryRule.capacityBelowSold => () {
      final over = firstDayOverCapacity(
        soldPerDay,
        capacityOf(_capacity.text).value ?? 0,
      );
      return over == null
          ? l.s3004_capacityInvalid
          : l.s3004_capacityBelowSold(dayLabel(over.day), over.sold);
    }(),
    EntryRule.typesEmpty => l.s3004_typesEmpty,
    EntryRule.typesMax => l.s3004_typesMax,
    EntryRule.closedDaysMax => l.s3004_closedDaysMax,
  };

  Future<void> _submit(Map<String, int> soldPerDay) async {
    final l = context.l10n;
    final spotId = _spotId;
    if (spotId == null) return;
    final form = EntryForm(
      name: _name.text,
      startDay: _startDay,
      endDay: _endDay,
      open: _open.text.trim(),
      close: _close.text.trim(),
      capacity: _capacity.text,
      types: _types,
      closedDays: _closedDays,
    );
    final rules = entryFormErrors(
      form,
      today: _today(),
      editing: _editing,
      soldPerDay: soldPerDay,
    );
    setState(
      () => _errors = {
        for (final MapEntry(:key, :value) in rules.entries)
          key: _ruleText(l, value, soldPerDay),
      },
    );
    if (rules.isNotEmpty) return;
    final title = _name.text.trim();
    final draft = EntryEventDraft(
      eventId: widget.eventId ?? _savedDraftId,
      spotId: spotId,
      title: title.isEmpty ? null : title,
      startDay: _startDay,
      endDay: _endDay,
      closedWeekdays: [
        for (final c in _weekdayCodes)
          if (_weekdays.contains(c)) c,
      ]..sort(),
      closedDays: List.of(_closedDays),
      openHours: OpenHours(start: form.open, end: form.close),
      ticketTypes: List.of(_types),
      dailyCapacity: capacityOf(_capacity.text).value,
      refundCutoffHours: _refundCutoffHours,
    );
    setState(() => _busy = true);
    final repo = ref.read(eventRepositoryProvider);
    try {
      if (_editing) {
        await repo.updateEntryEvent(widget.eventId!, draft);
      } else {
        final id = await repo.saveEntryDraft(draft);
        _savedDraftId = id;
        await repo.publish(id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final code = eventErrorCodeOf(e);
      final field = eventErrorFieldOf(e);
      if (code == 'invalid_argument' && field == 'dailyCapacity') {
        setState(
          () => _errors = {
            EntryField.capacity: _ruleText(
              l,
              EntryRule.capacityBelowSold,
              soldPerDay,
            ),
          },
        );
        return;
      }
      orgSay(context, switch (code) {
        'business_required' => l.s3004_businessRequired,
        'not_spot_manager' => l.s3004_notManager,
        _ => organizerErrorText(l, code),
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    orgSay(context, _editing ? l.s3004_saved : l.s3004_published);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(managedSpotPath(spotId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final Widget body;
    var soldPerDay = const <String, int>{};
    var soldIds = const <String>{};
    if (_editing) {
      final id = widget.eventId!;
      final event = ref.watch(eventProvider(id));
      final regs = ref.watch(eventRegistrationsProvider(id)).value ?? const [];
      soldPerDay = entrySoldPerDay(regs, _today());
      soldIds = entrySoldTypeIds(regs);
      final sold = soldIds;
      if (event.value?.entry case final entry?) _fromEvent(entry);
      body = AsyncView<EventDetail?>(
        value: event,
        onRetry: () => ref.invalidate(eventProvider(id)),
        isEmpty: (e) => e?.entry == null,
        empty: (_) => EmptyState(title: l.s3004_notManager, body: ''),
        data: (context, _) => _form(context, sold),
      );
    } else if (widget.spotId == null) {
      body = EmptyState(title: l.s3004_notManager, body: '');
    } else {
      final spot = ref.watch(spotProvider(widget.spotId!));
      if (spot.value case final s?) _fromSpot(s);
      body = AsyncView<Spot?>(
        value: spot,
        onRetry: () => ref.invalidate(spotProvider(widget.spotId!)),
        isEmpty: (s) => s == null,
        empty: (_) => EmptyState(title: l.s3004_notManager, body: ''),
        data: (context, _) => _form(context, const {}),
      );
    }
    final sold = soldPerDay;
    return ScreenCode(
      ScreenCodes.entryTicketsEdit,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.s3004_title)),
          body: body,
          bottomNavigationBar: AppFooterBar(
            child: AppButton.primary(
              _editing ? l.s3004_saveChanges : l.s3004_submit,
              key: const Key('entry-submit'),
              loading: _busy,
              onPressed: !_ready || _busy ? null : () => _submit(sold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(EntryField f) {
    final e = _errors[f];
    if (e == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Text(
        e,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _form(BuildContext context, Set<String> soldIds) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.mutedForeground,
    );
    final full = _types.length >= ticketTypesMax;
    Widget dayTile(Key key, String label, String day, bool start) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: muted),
      subtitle: Text(dayChipLabel(day), style: theme.textTheme.bodyLarge),
      onTap: _busy ? null : () => _pickDay(start: start),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        TextField(
          key: const Key('entry-name'),
          controller: _name,
          enabled: !_busy,
          maxLength: 80,
          decoration: InputDecoration(labelText: l.s3004_name),
        ),
        Row(
          children: [
            Expanded(
              child: dayTile(
                const Key('entry-from'),
                l.s3004_from,
                _startDay,
                true,
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: dayTile(const Key('entry-to'), l.s3004_to, _endDay, false),
            ),
          ],
        ),
        _error(EntryField.range),
        const SizedBox(height: AppSpace.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('entry-open'),
                controller: _open,
                enabled: !_busy,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(labelText: l.s3004_open),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: TextField(
                key: const Key('entry-close'),
                controller: _close,
                enabled: !_busy,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(labelText: l.s3004_close),
              ),
            ),
          ],
        ),
        _error(EntryField.hours),
        const SizedBox(height: AppSpace.s2),
        TextField(
          key: const Key('entry-capacity'),
          controller: _capacity,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l.s3004_capacity,
            helperText: l.s3004_capacityHint,
          ),
        ),
        _error(EntryField.capacity),
        OrgSection(l.s3004_closedWeekdays),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final c in _weekdayCodes)
              AppChip(
                key: Key('entry-weekday-$c'),
                label: weekdayLabel(c == 0 ? DateTime.sunday : c),
                selected: _weekdays.contains(c),
                kind: AppChipKind.context,
                enabled: !_busy,
                onChanged: (on) =>
                    setState(() => on ? _weekdays.add(c) : _weekdays.remove(c)),
              ),
          ],
        ),
        OrgSection(l.s3004_closedDays),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final d in _closedDays)
              AppChip(
                key: Key('entry-closed-$d'),
                label: dayChipLabel(d),
                selected: true,
                kind: AppChipKind.context,
                trailing: const AppIcon(AppIcons.close, size: 16),
                enabled: !_busy,
                onChanged: (_) => setState(() => _closedDays.remove(d)),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            l.s3004_addClosedDay,
            key: const Key('entry-add-closed-day'),
            onPressed: _busy ? null : _addClosedDay,
          ),
        ),
        _error(EntryField.closedDays),
        OrgSection(
          l.s3004_types(_types.length),
          trailing: AppButton.text(
            l.s3004_addType,
            key: const Key('entry-add-type'),
            onPressed: full || _busy ? null : () => _editType(null, soldIds),
          ),
        ),
        if (full) Text(l.s3004_typesMax, style: muted),
        if (_types.isNotEmpty)
          GlassCard(
            highlight: false,
            child: Column(
              children: [
                for (final (i, t) in _types.indexed)
                  ListTile(
                    key: Key('entry-type-$i'),
                    title: Text(t.name),
                    subtitle: t.hidden ? Text(l.s3004_hidden) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMoney(t.price),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const AppIcon(AppIcons.chevron),
                      ],
                    ),
                    onTap: _busy ? null : () => _editType(i, soldIds),
                  ),
              ],
            ),
          ),
        _error(EntryField.types),
        const SizedBox(height: AppSpace.s3),
        Text(l.s3004_note, style: muted),
        const SizedBox(height: AppSpace.s1),
        Text(l.s3004_refundNote, style: muted),
      ],
    );
  }
}
