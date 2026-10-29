// lib/features/spots/spot_schedule_edit_screen.dart
// S29.04 "Thêm / sửa lịch tại điểm": spot, member (studio), days ("Lặp lại"
// or "Chọn ngày"), window, packages and a preview where the days the holder
// cannot take are red with the reason.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
import 'package:photobooking/features/spots/slot_offer_sheet.dart';
import 'package:photobooking/features/spots/spot_format.dart';
import 'package:photobooking/features/spots/spot_schedule_edit_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The schedule being edited, read once.
final spotScheduleForEditProvider = FutureProvider.autoDispose
    .family<SpotSchedule?, String>(
      (ref, id) => ref.watch(spotRepositoryProvider).schedule(id),
    );

/// What the form needs before it can start: the provider type, the schedule
/// when editing, and the open-schedule count of "{n} / 8".
@immutable
class _EditContext {
  const _EditContext({
    required this.studio,
    required this.existing,
    required this.openCount,
  });

  final bool studio;
  final SpotSchedule? existing;
  final int openCount;
}

final _editContextProvider = Provider.autoDispose
    .family<AsyncValue<_EditContext>, String?>((ref, scheduleId) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const AsyncLoading();
      final intro = ref.watch(myIntroProvider);
      final mine = ref.watch(mySpotSchedulesProvider(uid));
      final existing = scheduleId == null
          ? const AsyncData<SpotSchedule?>(null)
          : ref.watch(spotScheduleForEditProvider(scheduleId));
      for (final v in <AsyncValue<Object?>>[intro, mine, existing]) {
        if (v.hasError && !v.hasValue) {
          return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
        }
      }
      if (!intro.hasValue || !mine.hasValue || !existing.hasValue) {
        return const AsyncLoading();
      }
      final s = existing.requireValue;
      if (scheduleId != null && (s == null || !s.open || s.providerId != uid)) {
        return AsyncError(StateError('schedule $scheduleId'), StackTrace.empty);
      }
      return AsyncData(
        _EditContext(
          studio: intro.requireValue?.providerType == ProviderType.studio,
          existing: s,
          openCount: openScheduleCount(
            mine.requireValue,
            vnDateKey(ref.watch(clockProvider)()),
          ),
        ),
      );
    });

/// `/me/spot-schedules/new?spotId=` and `/me/spot-schedules/:scheduleId`.
class SpotScheduleEditScreen extends ConsumerWidget {
  const SpotScheduleEditScreen({super.key, this.scheduleId, this.spotId});

  final String? scheduleId;
  final String? spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctx = ref.watch(_editContextProvider(scheduleId));
    final editing = scheduleId != null;
    return ScreenCode(
      ScreenCodes.spotScheduleEdit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            editing ? l.spotScheduleEditTitle : l.spotScheduleNewTitle,
          ),
          actions: [
            if (ctx.value case final c? when !editing)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
                child: Center(
                  child: Text(
                    l.spotScheduleLimitCount(c.openCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: AsyncView<_EditContext>(
          value: ctx,
          onRetry: () {
            ref.invalidate(myIntroProvider);
            if (scheduleId case final id?) {
              ref.invalidate(spotScheduleForEditProvider(id));
            }
          },
          data: (context, c) => _Form(
            args: SpotScheduleEditArgs(
              existing: c.existing,
              spotId: spotId,
              studio: c.studio,
            ),
            openCount: c.openCount,
          ),
        ),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.args, required this.openCount});

  final SpotScheduleEditArgs args;
  final int openCount;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  /// The month the "Chọn ngày" calendar shows.
  DateTime? _month;

  SpotScheduleEditController get _ctl =>
      ref.read(spotScheduleEditControllerProvider(widget.args).notifier);

  Future<void> _submit() async {
    final l = context.l10n;
    final editing = widget.args.existing != null;
    final messenger = ScaffoldMessenger.of(context);
    // The sheet opened from the SnackBar outlives this screen: it is shown on
    // the navigator, over S29.03.
    final nav = Navigator.of(context);
    final ctl = _ctl;
    final ok = await ctl.submit();
    if (!ok || !mounted) return;
    final saved = ctl.saved;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(editing ? l.spotScheduleUpdated : l.spotScheduleSaved),
          action: editing || saved == null
              ? null
              : SnackBarAction(
                  key: const Key('spot-schedule-add-offer'),
                  label: l.spotScheduleAddOffer,
                  onPressed: () =>
                      showSlotOfferSheet(nav.context, schedule: saved),
                ),
        ),
      );
    // Opened from a spot page (S29.02): back to S29.03, not to the spot.
    if (!editing && widget.args.spotId != null) {
      context.pushReplacement('/me/spot-schedules');
    } else if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/me/spot-schedules');
    }
  }

  Future<void> _pickSpot(SpotScheduleEditState s) async {
    final picked = await showAppSheet<String>(
      context,
      builder: (_) => _SpotPicker(selected: s.spotId),
    );
    if (picked != null && mounted) _ctl.pickSpot(picked);
  }

  Future<void> _pickDate(SpotScheduleEditState s, {required bool from}) async {
    final today = parseDayKey(s.today)!;
    final last = today.add(const Duration(days: kSpotScheduleDaysAhead));
    final current = parseDayKey(from ? s.from : s.to) ?? today;
    final initial = current.isBefore(today)
        ? today
        : (current.isAfter(last) ? last : current);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(last.year, last.month, last.day),
    );
    if (picked == null || !mounted) return;
    final key = dayKeyOf(picked);
    from ? _ctl.setRange(from: key) : _ctl.setRange(to: key);
  }

  Future<void> _pickTime(SpotScheduleEditState s, {required bool start}) async {
    final picked = await showAppSheet<String>(
      context,
      builder: (_) => _TimePicker(
        title: start
            ? context.l10n.spotScheduleStart
            : context.l10n.spotScheduleEnd,
        selected: start ? s.window.start : s.window.end,
      ),
    );
    if (picked == null || !mounted) return;
    _ctl.setWindow(
      start
          ? SpotWindow(start: picked, end: s.window.end)
          : SpotWindow(start: s.window.start, end: picked),
    );
  }

  String _failureText(AppLocalizations l, SpotScheduleEditState s) =>
      switch (s.failure!) {
        SpotScheduleFailure.spotRequired => l.spotScheduleSpotRequired,
        SpotScheduleFailure.memberRequired => l.spotScheduleMemberRequired,
        SpotScheduleFailure.noDays => l.spotScheduleNoDays,
        SpotScheduleFailure.tooMany => l.spotScheduleTooMany,
        SpotScheduleFailure.windowInvalid => l.spotScheduleWindowInvalid,
        SpotScheduleFailure.limit => l.spotScheduleLimit,
        SpotScheduleFailure.notAccepting => l.spotScheduleNotAccepting,
        SpotScheduleFailure.memberNotAccepting =>
          l.spotScheduleMemberNotAccepting,
        SpotScheduleFailure.archived => l.bookSpotArchived,
        SpotScheduleFailure.packagesInvalid => l.spotSchedulePackagesInvalid,
        SpotScheduleFailure.hasBookings =>
          spotHasBookingsText(l, s.bookingCounts) ?? l.spotScheduleError,
        SpotScheduleFailure.generic => l.spotScheduleError,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final s = ref.watch(spotScheduleEditControllerProvider(widget.args));
    final directory = ref.watch(spotDirectoryProvider);
    final conflicts = s.conflicts;
    final days = s.days;
    final limitReached = !s.editing && widget.openCount >= kSpotScheduleMaxOpen;
    // Live: rules the form already breaks, then the last refusal.
    final live = s.problem;
    final message = s.failure != null
        ? _failureText(l, s)
        : (live == SpotScheduleFailure.tooMany ||
                  live == SpotScheduleFailure.windowInvalid
              ? _failureText(l, s.copyWith(failure: live))
              : (limitReached ? l.spotScheduleLimit : null));
    SpotEntry? spotIn(List<SpotEntry> all) =>
        all.where((e) => e.spotId == s.spotId).firstOrNull;
    bool offSeason(SpotEntry? spot) =>
        spot != null &&
        spot.seasonMonths.isNotEmpty &&
        days.any((d) {
          final m = parseDayKey(d)?.month;
          return m != null && !spot.seasonMonths.contains(m);
        });

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3, bottom: AppSpace.s1),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: muted,
          letterSpacing: 0.7,
        ),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s4,
            ),
            children: [
              AsyncView<List<SpotEntry>>(
                value: directory,
                skeleton: (_) =>
                    AppSkeleton.box(height: 56, radius: AppRadius.control),
                onRetry: () => ref.invalidate(spotDirectoryProvider),
                data: (context, all) {
                  final spot = spotIn(all);
                  return _FieldBox(
                    key: const Key('spot-schedule-spot'),
                    label: l.spotScheduleSpot,
                    value: spot == null
                        ? l.spotScheduleSpotPick
                        : l.spotNameCity(spot.name, spot.city),
                    trailing: s.spotLocked ? AppIcons.lock : AppIcons.chevron,
                    onTap: s.spotLocked || s.saving ? null : () => _pickSpot(s),
                  );
                },
              ),
              if (s.spotId case final id?) _EntryNote(spotId: id),
              if (s.studio) ...[
                label(l.spotScheduleMember),
                _MemberPicker(
                  selected: s.assigneeId,
                  locked: s.editing || s.saving,
                  onPick: _ctl.setAssignee,
                ),
              ],
              label(l.spotScheduleDaysLabel),
              SegmentedTabs<SpotScheduleMode>(
                options: [
                  SegmentOption(
                    value: SpotScheduleMode.repeat,
                    label: l.spotScheduleRepeat,
                  ),
                  SegmentOption(
                    value: SpotScheduleMode.pick,
                    label: l.spotSchedulePickDays,
                  ),
                ],
                value: s.mode,
                onChanged: _ctl.setMode,
              ),
              const SizedBox(height: AppSpace.s2),
              if (s.mode == SpotScheduleMode.repeat) ...[
                _WeekdayRow(selected: s.weekdays, onToggle: _ctl.toggleWeekday),
                const SizedBox(height: AppSpace.s2),
                Row(
                  children: [
                    Expanded(
                      child: _FieldBox(
                        key: const Key('spot-schedule-from'),
                        label: l.spotScheduleFrom,
                        value: _day(s.from),
                        onTap: () => _pickDate(s, from: true),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: _FieldBox(
                        key: const Key('spot-schedule-to'),
                        label: l.spotScheduleTo,
                        value: _day(s.to),
                        onTap: () => _pickDate(s, from: false),
                      ),
                    ),
                  ],
                ),
              ] else
                AsyncView<Map<DateTime, AvailabilityDay>>(
                  value: s.availability,
                  skeleton: (_) => AvailabilityCalendar.skeleton(),
                  data: (context, mine) => _calendar(s, mine),
                ),
              const SizedBox(height: AppSpace.s2),
              Row(
                children: [
                  Expanded(
                    child: _FieldBox(
                      key: const Key('spot-schedule-start'),
                      label: l.spotScheduleStart,
                      value: s.window.start,
                      onTap: () => _pickTime(s, start: true),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: _FieldBox(
                      key: const Key('spot-schedule-end'),
                      label: l.spotScheduleEnd,
                      value: s.window.end,
                      onTap: () => _pickTime(s, start: false),
                    ),
                  ),
                ],
              ),
              label(l.spotSchedulePackages),
              AsyncView<List<ServicePackage>>(
                value: ref.watch(myPackagesProvider),
                onRetry: () => ref.invalidate(myPackagesProvider),
                data: (context, packages) => _packages(s, packages),
              ),
              const SizedBox(height: AppSpace.s3),
              AsyncView<Map<DateTime, AvailabilityDay>>(
                value: s.availability,
                skeleton: (_) =>
                    AppSkeleton.box(height: 96, radius: AppRadius.card),
                data: (context, _) => _Preview(
                  days: days,
                  window: s.window,
                  conflicts: conflicts,
                  onRemove: _ctl.toggleDay,
                ),
              ),
              AsyncView<List<SpotEntry>>(
                value: directory,
                skeleton: (_) => const SizedBox.shrink(),
                error: (_, _, _) => const SizedBox.shrink(),
                data: (context, all) {
                  final spot = spotIn(all);
                  if (spot == null || !offSeason(spot)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s2),
                    child: Row(
                      key: const Key('spot-schedule-offseason'),
                      children: [
                        AppIcon(AppIcons.eco, size: 18, color: muted),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Text(
                            l.spotScheduleOffSeason(
                              formatSeasonRange(spot.seasonMonths),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s3),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      key: const Key('spot-schedule-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppFooterBar(
          child: AppButton.primary(
            s.editing ? l.spotScheduleSave : l.spotScheduleOpen,
            key: const Key('spot-schedule-submit'),
            loading: s.saving,
            onPressed: s.saving || conflicts.isNotEmpty || limitReached
                ? null
                : _submit,
          ),
        ),
      ],
    );
  }

  static String _day(String key) {
    final d = parseDayKey(key);
    return d == null ? key : formatDay(d);
  }

  Widget _calendar(
    SpotScheduleEditState s,
    Map<DateTime, AvailabilityDay> mine,
  ) {
    final today = parseDayKey(s.today)!;
    final states = <DateTime, DayState>{
      for (final e in mine.entries)
        if (s.scheduleId == null || e.value.scheduleId != s.scheduleId)
          e.key: e.value.state,
    };
    final month = _month ?? monthOf(today);
    return AvailabilityCalendar(
      key: const Key('spot-schedule-calendar'),
      month: month,
      states: states,
      selectedDays: {for (final d in s.picked) ?parseDayKey(d)},
      today: today,
      minDate: today,
      maxDate: today.add(const Duration(days: kSpotScheduleDaysAhead)),
      onSelect: (d) => _ctl.toggleDay(dayKeyOf(d)),
      onMonthChanged: (m) => setState(() => _month = m),
    );
  }

  Widget _packages(SpotScheduleEditState s, List<ServicePackage> packages) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final active = [
      for (final p in packages)
        if (p.active) p,
    ];
    if (active.isEmpty) {
      return Text(
        l.spotScheduleNoPackages,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    final length = minutesOfTime(s.window.end) - minutesOfTime(s.window.start);
    return Wrap(
      spacing: AppSpace.s2,
      children: [
        AppChip(
          key: const Key('spot-schedule-all-packages'),
          label: l.spotScheduleAllPackages,
          kind: AppChipKind.context,
          selected: s.serviceIds.isEmpty,
          onChanged: (_) => _ctl.allPackages(),
        ),
        for (final p in active)
          if (p.durationMinutes > length)
            // Longer than the window: cannot be booked here.
            Semantics(
              enabled: false,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.45,
                  child: AppChip(
                    key: Key('spot-schedule-package-${p.id}'),
                    label: p.name,
                    kind: AppChipKind.context,
                    selected: false,
                    onChanged: (_) {},
                  ),
                ),
              ),
            )
          else
            AppChip(
              key: Key('spot-schedule-package-${p.id}'),
              label: p.name,
              kind: AppChipKind.context,
              selected: s.serviceIds.contains(p.id),
              onChanged: (_) => _ctl.togglePackage(p.id),
            ),
      ],
    );
  }
}

/// A tappable form field (mock `.field`): small label over the value.
class _FieldBox extends StatelessWidget {
  const _FieldBox({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: trailing == null ? null : AppIcon(trailing!, size: 18),
          ),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// T2…CN toggles in one row of seven (mock `.pkg` grid).
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    return Semantics(
      label: l.spotScheduleWeekdays,
      container: true,
      child: Row(
        children: [
          for (var d = DateTime.monday; d <= DateTime.sunday; d++) ...[
            if (d > DateTime.monday) const SizedBox(width: AppSpace.s1),
            Expanded(
              child: Semantics(
                checked: selected.contains(d),
                button: true,
                child: InkWell(
                  key: Key('spot-weekday-$d'),
                  onTap: () => onToggle(d),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected.contains(d) ? subtle : null,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: selected.contains(d)
                            ? scheme.primary
                            : scheme.outline,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        weekdayLabel(d),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected.contains(d) ? scheme.primary : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "12 ngày · 06:00–11:00", the day pills (red ones tap away) and the
/// reasons.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.days,
    required this.window,
    required this.conflicts,
    required this.onRemove,
  });

  final List<String> days;
  final SpotWindow window;
  final Map<String, SpotDayConflictReason> conflicts;
  final ValueChanged<String> onRemove;

  static String _reason(
    AppLocalizations l,
    SpotDayConflictReason r,
    String day,
  ) => switch (r) {
    SpotDayConflictReason.booked => l.spotScheduleConflictBooked(day),
    SpotDayConflictReason.pending => l.spotScheduleConflictPending(day),
    SpotDayConflictReason.off => l.spotScheduleConflictOff(day),
    SpotDayConflictReason.spot => l.spotScheduleConflictSpot(day),
    SpotDayConflictReason.full => l.spotScheduleConflictFull(day),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bad = scheme.error;
    final red = [
      for (final d in days)
        if (conflicts[d] != null) d,
    ];
    return DecoratedBox(
      key: const Key('spot-schedule-preview'),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColorsDark.glass
            : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.spotScheduleDays(days.length, window.start, window.end),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (days.isEmpty)
              Text(l.spotScheduleNoDays, style: theme.textTheme.bodySmall)
            else ...[
              const SizedBox(height: AppSpace.s2),
              Wrap(
                spacing: AppSpace.s1,
                runSpacing: AppSpace.s1,
                children: [
                  for (final d in days)
                    _DayChip(
                      key: Key('spot-preview-day-$d'),
                      day: d,
                      red: conflicts[d] != null,
                      onRemove: () => onRemove(d),
                    ),
                ],
              ),
            ],
            for (final d in red)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(
                  _reason(l, conflicts[d]!, formatDay(parseDayKey(d)!)),
                  style: theme.textTheme.bodySmall?.copyWith(color: bad),
                ),
              ),
            if (red.isNotEmpty)
              Text(
                l.spotScheduleConflictHint,
                style: theme.textTheme.bodySmall?.copyWith(color: bad),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.day,
    required this.red,
    required this.onRemove,
  });

  final String day;
  final bool red;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final bad = theme.colorScheme.error;
    final date = parseDayKey(day)!;
    final text = formatDayMonth(date);
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: red ? bad.withValues(alpha: 0.18) : theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          red ? l.spotScheduleConflictDay(text) : text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: red ? bad : null,
            fontWeight: red ? FontWeight.w600 : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    if (!red) return pill;
    return Semantics(
      button: true,
      label: l.spotScheduleRemoveDay(formatDay(date)),
      excludeSemantics: true,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}

/// A studio's active members as choice chips (studio relations, #136).
class _MemberPicker extends ConsumerWidget {
  const _MemberPicker({
    required this.selected,
    required this.locked,
    required this.onPick,
  });

  final String? selected;
  final bool locked;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView<List<StudioRelation>>(
      value: ref.watch(myStudioRelationsProvider),
      onRetry: () => ref.invalidate(myStudioRelationsProvider),
      data: (context, relations) {
        final members = [
          for (final r in relations)
            if (r.status == RelationStatus.active) r,
        ];
        if (members.isEmpty) {
          return Text(
            l.spotScheduleNoMembers,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Wrap(
          spacing: AppSpace.s2,
          children: [
            for (final m in members)
              AppChip(
                key: Key('spot-schedule-member-${m.memberId}'),
                label: m.memberName,
                kind: AppChipKind.context,
                selected: selected == m.memberId,
                leading: AppAvatar(
                  url: m.memberAvatarUrl,
                  name: m.memberName,
                  size: AppAvatarSize.xs,
                ),
                onChanged: (_) {
                  if (!locked) onPick(m.memberId);
                },
              ),
          ],
        );
      },
    );
  }
}

/// The 15-minute grid of 05:00–21:00.
class _TimePicker extends StatelessWidget {
  const _TimePicker({required this.title, required this.selected});

  final String title;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final times = [
      for (
        var m = minutesOfTime(kSpotWindowEarliest);
        m <= minutesOfTime(kSpotWindowLatest);
        m += kSpotWindowStepMinutes
      )
        timeOfMinutes(m),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s2,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
        ),
        Flexible(
          child: Material(
            type: MaterialType.transparency,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              childAspectRatio: 2.2,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s4,
              ),
              children: [
                for (final t in times)
                  InkWell(
                    key: Key('time-option-$t'),
                    onTap: () => Navigator.of(context).pop(t),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Semantics(
                      selected: t == selected,
                      button: true,
                      child: Center(
                        child: Text(
                          t,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: t == selected ? scheme.primary : null,
                            fontWeight: t == selected ? FontWeight.w700 : null,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
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

/// "Điểm chụp" sheet: search by name (accents ignored); hot spots first,
/// then the nearest to the provider's service area.
class _SpotPicker extends ConsumerStatefulWidget {
  const _SpotPicker({required this.selected});

  final String? selected;

  @override
  ConsumerState<_SpotPicker> createState() => _SpotPickerState();
}

class _SpotPickerState extends ConsumerState<_SpotPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    // The service-area centre orders the list (display order only).
    final me = uid.isEmpty
        ? null
        : ref.watch(spotPhotographerSummariesProvider(uid)).value?[uid];
    final lat = me?.lat;
    final lng = me?.lng;
    final month = toVn(ref.watch(clockProvider)()).month;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.spotScheduleSpot,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              TextField(
                key: const Key('spot-picker-search'),
                decoration: InputDecoration(
                  hintText: l.spotScheduleSearch,
                  prefixIcon: const AppIcon(AppIcons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ),
        ),
        Flexible(
          child: AsyncView<List<SpotEntry>>(
            value: ref.watch(spotDirectoryProvider),
            onRetry: () => ref.invalidate(spotDirectoryProvider),
            data: (context, all) {
              final q = foldVietnamese(_query.trim());
              final list = [
                for (final s in orderSpots(
                  all,
                  month: month,
                  lat: lat,
                  lng: lng,
                ))
                  if (q.isEmpty || foldVietnamese(s.name).contains(q)) s,
              ];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  child: Text(
                    l.spotScheduleSpotNone,
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Material(
                type: MaterialType.transparency,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpace.s4),
                  children: [
                    for (final s in list)
                      ListTile(
                        key: Key('spot-option-${s.spotId}'),
                        selected: s.spotId == widget.selected,
                        title: Text(s.name),
                        subtitle: Text(
                          l.spotCitySeason(
                            s.city,
                            seasonLabel(l, s.seasonMonths, month),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(s.spotId),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// S29.04 at a ticketed spot, for a provider who is not one of its
/// residents: "Điểm này thu vé ≈ {x}/người. …" (spec §8).
class _EntryNote extends ConsumerWidget {
  const _EntryNote({required this.spotId});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(spotProvider(spotId)).value;
    if (spot == null || !spot.isTicketed) return const SizedBox.shrink();
    final uid = ref.watch(authStateProvider).value?.uid;
    final today = vnDateKey(ref.watch(clockProvider)());
    final residents =
        ref.watch(spotResidentsProvider(spotId)).value ?? const <Resident>[];
    final mine = residents.where((r) => r.providerId == uid).firstOrNull;
    if (mine != null && mine.waiverFor(today).provider) {
      return const SizedBox.shrink();
    }
    final price = entryUnitPrice(
      ref.watch(entryEventProvider(spotId)).value,
      spot.access,
    );
    if (price == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.ticket, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Text(
              context.l10n.s2904_entryNote(formatMoney(price)),
              key: const Key('spot-schedule-entry-note'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
