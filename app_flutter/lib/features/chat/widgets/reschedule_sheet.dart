import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/calendar_days.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/async_view.dart';
import 'package:photobooking/core/widgets/availability_calendar.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<({String day, String start})?> showRescheduleSheet(
  BuildContext context, {
  required String photographerId,
  required Booking booking,
}) {
  return showAppSheet<({String day, String start})>(
    context,
    builder: (_) => RescheduleSheet(
      photographerId: photographerId,
      booking: booking,
    ),
  );
}

class RescheduleSheet extends ConsumerStatefulWidget {
  const RescheduleSheet({
    super.key,
    required this.photographerId,
    required this.booking,
  });

  final String photographerId;
  final Booking booking;

  @override
  ConsumerState<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<RescheduleSheet> {
  DateTime? _selectedDay;
  late DateTime _month;
  late String _start;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = monthOf(now);
    _start = widget.booking.start;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final today = calendarDay(now);

    final availabilityAsync = ref.watch(
      availabilityMonthProvider((
        uid: widget.photographerId,
        month: _month,
      )),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.chatReschedule,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpace.s3),
          AsyncView<Map<DateTime, AvailabilityDay>>(
            value: availabilityAsync,
            skeleton: (_) => AvailabilityCalendar.skeleton(),
            onRetry: () => ref.invalidate(
              availabilityMonthProvider((
                uid: widget.photographerId,
                month: _month,
              )),
            ),
            data: (context, knownDays) {
              final dayStates = <DateTime, DayState>{};
              for (final e in knownDays.entries) {
                dayStates[e.key] = e.value.state;
              }

              return AvailabilityCalendar(
                month: _month,
                states: dayStates,
                selected: _selectedDay,
                today: today,
                minDate: today,
                onSelect: (d) {
                  final s = dayStates[d] ?? DayState.free;
                  if (s == DayState.free) {
                    setState(() => _selectedDay = d);
                  }
                },
                onMonthChanged: (m) => setState(() => _month = m),
              );
            },
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l10n.chatReschedule,
            key: const Key('reschedule-confirm-btn'),
            onPressed: _selectedDay == null
                ? null
                : () {
                    final dayStr = dayKeyOf(_selectedDay!);
                    Navigator.of(context).pop((day: dayStr, start: _start));
                  },
          ),
        ],
      ),
    );
  }
}
