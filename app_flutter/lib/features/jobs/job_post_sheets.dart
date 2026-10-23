// lib/features/jobs/job_post_sheets.dart
//
// Bottom sheets for S15.01 step 2 pickers:
// - Fixed schedule (date, start time, end time) & Flexible schedule (range, duration)
// - Wants picker (min edited photos, delivery days)
// - Deadline days picker (1 to 7 days)
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';

String _formatDayHyphen(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

Future<JobSchedule?> showScheduleSheet(
  BuildContext context, {
  required JobSchedule current,
  required DateTime minFixedDay,
  required DateTime maxFixedDay,
}) {
  return showAppSheet<JobSchedule>(
    context,
    builder: (ctx) => _ScheduleSheet(
      current: current,
      minFixedDay: minFixedDay,
      maxFixedDay: maxFixedDay,
    ),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.current,
    required this.minFixedDay,
    required this.maxFixedDay,
  });

  final JobSchedule current;
  final DateTime minFixedDay;
  final DateTime maxFixedDay;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late ScheduleKind _kind;
  DateTime? _fixedDay;
  TimeOfDay? _start;
  TimeOfDay? _end;

  DateTime? _flexFrom;
  DateTime? _flexTo;
  int _flexDurationMinutes = 120; // default 2 hours

  @override
  void initState() {
    super.initState();
    _kind = widget.current.kind;
    if (widget.current.day != null) {
      _fixedDay = DateTime.tryParse(widget.current.day!);
    }
    if (widget.current.start != null) {
      _start = _parseTime(widget.current.start!);
    }
    if (widget.current.end != null) {
      _end = _parseTime(widget.current.end!);
    }

    if (widget.current.from != null) {
      _flexFrom = DateTime.tryParse(widget.current.from!);
    }
    if (widget.current.to != null) {
      _flexTo = DateTime.tryParse(widget.current.to!);
    }
    if (widget.current.durationMinutes > 0) {
      _flexDurationMinutes = widget.current.durationMinutes;
    }
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _timeDiffMinutes(TimeOfDay start, TimeOfDay end) {
    return (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
  }

  bool get _canSave {
    if (_kind == ScheduleKind.fixed) {
      if (_fixedDay == null || _start == null || _end == null) return false;
      return _timeDiffMinutes(_start!, _end!) > 0;
    } else {
      if (_flexFrom == null || _flexTo == null) return false;
      if (_flexTo!.isBefore(_flexFrom!)) return false;
      final diffDays = _flexTo!.difference(_flexFrom!).inDays;
      return diffDays <= 30 && _flexDurationMinutes > 0;
    }
  }

  void _save() {
    if (!_canSave) return;
    if (_kind == ScheduleKind.fixed) {
      final dayStr = _formatDayHyphen(_fixedDay!);
      final startStr = _formatTime(_start!);
      final endStr = _formatTime(_end!);
      final duration = _timeDiffMinutes(_start!, _end!);

      Navigator.of(context).pop(
        JobSchedule(
          kind: ScheduleKind.fixed,
          day: dayStr,
          start: startStr,
          end: endStr,
          durationMinutes: duration,
        ),
      );
    } else {
      final fromStr = _formatDayHyphen(_flexFrom!);
      final toStr = _formatDayHyphen(_flexTo!);
      Navigator.of(context).pop(
        JobSchedule(
          kind: ScheduleKind.flexible,
          from: fromStr,
          to: toStr,
          durationMinutes: _flexDurationMinutes,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.jobPostWhen,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: _canSave ? _save : null,
                  child: Text(l.jobPostSave),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            SegmentedTabs<ScheduleKind>(
              options: [
                SegmentOption(value: ScheduleKind.fixed, label: l.jobPostFixed),
                SegmentOption(value: ScheduleKind.flexible, label: l.jobPostFlexible),
              ],
              value: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: AppSpace.s4),
            if (_kind == ScheduleKind.fixed) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.jobPostWhen),
                subtitle: Text(_fixedDay != null ? formatDay(_fixedDay!) : l.jobPostWhenEmpty),
                trailing: const AppIcon(AppIcons.calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fixedDay ?? widget.minFixedDay,
                    firstDate: widget.minFixedDay,
                    lastDate: widget.maxFixedDay,
                  );
                  if (picked != null) setState(() => _fixedDay = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.jobPostStart),
                subtitle: Text(_start != null ? _formatTime(_start!) : '--:--'),
                trailing: const AppIcon(AppIcons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _start ?? const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (picked != null) {
                    final m = picked.minute < 15 ? 0 : (picked.minute < 45 ? 30 : 0);
                    final h = picked.minute >= 45 ? (picked.hour + 1) % 24 : picked.hour;
                    setState(() => _start = TimeOfDay(hour: h, minute: m));
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.jobPostEnd),
                subtitle: Text(_end != null ? _formatTime(_end!) : '--:--'),
                trailing: const AppIcon(AppIcons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _end ?? const TimeOfDay(hour: 10, minute: 0),
                  );
                  if (picked != null) {
                    final m = picked.minute < 15 ? 0 : (picked.minute < 45 ? 30 : 0);
                    final h = picked.minute >= 45 ? (picked.hour + 1) % 24 : picked.hour;
                    setState(() => _end = TimeOfDay(hour: h, minute: m));
                  }
                },
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.jobPostFlexFrom),
                subtitle: Text(_flexFrom != null ? formatDay(_flexFrom!) : l.jobPostWhenEmpty),
                trailing: const AppIcon(AppIcons.calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _flexFrom ?? widget.minFixedDay,
                    firstDate: widget.minFixedDay,
                    lastDate: widget.maxFixedDay,
                  );
                  if (picked != null) setState(() => _flexFrom = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.jobPostFlexTo),
                subtitle: Text(_flexTo != null ? formatDay(_flexTo!) : l.jobPostWhenEmpty),
                trailing: const AppIcon(AppIcons.calendar),
                onTap: () async {
                  final first = _flexFrom ?? widget.minFixedDay;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _flexTo ?? first.add(const Duration(days: 7)),
                    firstDate: first,
                    lastDate: widget.maxFixedDay,
                  );
                  if (picked != null) setState(() => _flexTo = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.jobPostDuration),
                subtitle: Text('$_flexDurationMinutes phút (${(_flexDurationMinutes / 60).toStringAsFixed(1)} giờ)'),
                trailing: DropdownButton<int>(
                  value: _flexDurationMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 60, child: Text('1 giờ')),
                    DropdownMenuItem(value: 90, child: Text('1.5 giờ')),
                    DropdownMenuItem(value: 120, child: Text('2 giờ')),
                    DropdownMenuItem(value: 180, child: Text('3 giờ')),
                    DropdownMenuItem(value: 240, child: Text('4 giờ')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _flexDurationMinutes = v);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<JobWants?> showWantsSheet(
  BuildContext context, {
  required JobWants current,
}) {
  return showAppSheet<JobWants>(
    context,
    builder: (ctx) => _WantsSheet(current: current),
  );
}

class _WantsSheet extends StatefulWidget {
  const _WantsSheet({required this.current});
  final JobWants current;

  @override
  State<_WantsSheet> createState() => _WantsSheetState();
}

class _WantsSheetState extends State<_WantsSheet> {
  late TextEditingController _editedCtl;
  late TextEditingController _daysCtl;

  @override
  void initState() {
    super.initState();
    _editedCtl = TextEditingController(
      text: widget.current.editedCount != null ? widget.current.editedCount.toString() : '',
    );
    _daysCtl = TextEditingController(
      text: widget.current.deliveryDays != null ? widget.current.deliveryDays.toString() : '',
    );
  }

  @override
  void dispose() {
    _editedCtl.dispose();
    _daysCtl.dispose();
    super.dispose();
  }

  void _save() {
    final edited = int.tryParse(_editedCtl.text.trim());
    final days = int.tryParse(_daysCtl.text.trim());
    Navigator.of(context).pop(
      JobWants(
        editedCount: edited,
        deliveryDays: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.jobPostWants,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: _save,
                  child: Text(l.jobPostSave),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              controller: _editedCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.jobPostWantsEdited,
                hintText: 'VD: 30',
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              controller: _daysCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.jobPostWantsDays,
                hintText: 'VD: 5',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showDeadlineSheet(
  BuildContext context, {
  required int currentDays,
}) {
  return showAppSheet<int>(
    context,
    builder: (ctx) {
      final l = ctx.l10n;
      final now = DateTime.now();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.jobPostDeadline,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpace.s2),
              for (int d = 1; d <= 7; d++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.jobPostDeadlineValue(d, formatDay(now.add(Duration(days: d))))),
                  selected: d == currentDays,
                  trailing: d == currentDays ? const AppIcon(AppIcons.check) : null,
                  onTap: () => Navigator.of(ctx).pop(d),
                ),
            ],
          ),
        ),
      );
    },
  );
}
