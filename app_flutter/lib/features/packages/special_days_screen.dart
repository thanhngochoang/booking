import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/features/packages/special_day_rules.dart';
import 'package:photobooking/features/packages/special_day_sheet.dart';

/// S08.10, `/me/special-days`: the public holidays of a year (read-only), the
/// provider's own ranges, a note, and the sticky "Thêm khoảng ngày". Layout
/// follows mock `#S08.10`; ranges that ended are hidden.
class SpecialDaysScreen extends ConsumerStatefulWidget {
  const SpecialDaysScreen({super.key});

  @override
  ConsumerState<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends ConsumerState<SpecialDaysScreen> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final today = ref.watch(calendarTodayProvider);
    final year = _year ?? today.year;
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final mine = uid == null
        ? const AsyncData<List<SpecialDayRange>>([])
        : ref.watch(specialDaysProvider(uid));
    final holidays = ref.watch(holidaysProvider(year));
    final live = [
      for (final r in mine.value ?? const <SpecialDayRange>[])
        if (parseDayKey(r.to) case final to? when !to.isBefore(today)) r,
    ];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3, bottom: AppSpace.s2),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: AppText.xs2,
            color: muted,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );

    return ScreenCode(
      ScreenCodes.dayPricing,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.s0810Old_title)),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    children: [
                      Row(
                        children: [
                          Expanded(child: heading(l.s0810_public)),
                          for (final y in [today.year, today.year + 1]) ...[
                            AppChip(
                              key: Key('special-year-$y'),
                              label: '$y',
                              kind: AppChipKind.context,
                              selected: year == y,
                              semanticsLabel: l.s0810_year(y),
                              onChanged: (_) => setState(() => _year = y),
                            ),
                            const SizedBox(width: AppSpace.s1),
                          ],
                        ],
                      ),
                      AsyncView<List<Holiday>>(
                        value: holidays,
                        onRetry: () => ref.invalidate(holidaysProvider(year)),
                        skeleton: (_) => AppSkeleton.group(
                          child: AppSkeleton.card(height: 120),
                        ),
                        error: (context, _, _) => ErrorState(
                          message: l.s0810Old_loadError,
                          onRetry: () => ref.invalidate(holidaysProvider(year)),
                        ),
                        isEmpty: (list) => list.isEmpty,
                        empty: (_) => Padding(
                          padding: const EdgeInsets.all(AppSpace.s3),
                          child: Text(
                            l.s0810_noHolidays(year),
                            key: const Key('special-holidays-empty'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        data: (context, list) =>
                            _HolidayList(runs: holidayRuns(list)),
                      ),
                      heading(l.s0810_mine),
                      if (mine.hasError && !mine.hasValue)
                        ErrorState(
                          message: l.s0810Old_loadError,
                          onRetry: () =>
                              ref.invalidate(specialDaysProvider(uid ?? '')),
                        )
                      else if (live.isEmpty && mine.hasValue)
                        Padding(
                          padding: const EdgeInsets.all(AppSpace.s3),
                          child: Text(
                            l.s0810_emptyMine,
                            key: const Key('special-mine-empty'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        )
                      else
                        for (final r in live)
                          _RangeCard(
                            range: r,
                            onTap: () => showSpecialDaySheet(
                              context,
                              range: r,
                              existingCount: live.length,
                            ),
                          ),
                      const SizedBox(height: AppSpace.s2),
                      _Note(text: l.s0810_note),
                    ],
                  ),
                ),
                AppFooterBar(
                  child: AppButton.primary(
                    l.s0810Old_add,
                    key: const Key('special-days-add'),
                    onPressed: () => showSpecialDaySheet(
                      context,
                      existingCount: live.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _runDays(HolidayRun r) => r.from == r.to
    ? formatDay(r.from)
    : '${formatDay(r.from)} – ${formatDay(r.to)}';

class _HolidayList extends StatelessWidget {
  const _HolidayList({required this.runs});

  final List<HolidayRun> runs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: dark ? AppColorsDark.border : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          for (final r in runs)
            Padding(
              key: Key('holiday-${r.from.toIso8601String()}'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2h,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(r.name, style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Flexible(
                    child: Text(
                      _runDays(r),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.range, required this.onTap});

  final SpecialDayRange range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final from = parseDayKey(range.from);
    final to = parseDayKey(range.to);
    final days = from == null || to == null ? 0 : daysBetween(from, to).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: dark ? AppColorsDark.border : AppColors.border,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('special-range-${range.id}'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(range.name, style: theme.textTheme.titleSmall),
                        Text(
                          from == null || to == null
                              ? ''
                              : l.s0810_range(
                                  formatDay(from),
                                  formatDay(to),
                                  days,
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.chevron, size: 18, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(AppIcons.info, size: 18, color: muted),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Text(
            text,
            key: const Key('special-days-note'),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
