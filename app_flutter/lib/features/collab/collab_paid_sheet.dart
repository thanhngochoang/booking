import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';

/// S27.06 "Đã trả thù lao": the Vietnam day the studio paid (today,
/// yesterday or a picked day, never after today) and how (Chuyển khoản /
/// Tiền mặt / Khác); "Xác nhận đã trả" records it (Decision 15). The app
/// moves no money.
Future<void> showCollabPaidSheet(BuildContext context, CollabJob job) =>
    showAppSheet<void>(
      context,
      builder: (_) =>
          ScreenCode(ScreenCodes.collaboration, child: _PaidSheet(job: job)),
    );

enum _Day { today, yesterday, other }

class _PaidSheet extends ConsumerStatefulWidget {
  const _PaidSheet({required this.job});

  final CollabJob job;

  @override
  ConsumerState<_PaidSheet> createState() => _PaidSheetState();
}

class _PaidSheetState extends ConsumerState<_PaidSheet> {
  _Day _day = _Day.today;

  /// The picked Vietnam calendar date of [_Day.other].
  DateTime? _other;
  CollabPayMethod _method = CollabPayMethod.bank;
  bool _sending = false;
  String? _error;

  /// Today on the Vietnam calendar (a date, UTC midnight).
  DateTime _today() {
    final vn = toVn(ref.read(clockProvider)());
    return DateTime.utc(vn.year, vn.month, vn.day);
  }

  DateTime _paidOn() {
    final today = _today();
    return switch (_day) {
      _Day.today => today,
      _Day.yesterday => today.subtract(const Duration(days: 1)),
      _Day.other => _other ?? today,
    };
  }

  Future<void> _pickOther() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _other ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = _Day.other;
      _other = DateTime.utc(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _confirm() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(collabRepositoryProvider)
          .reportPaid(
            widget.job.bookingId,
            widget.job.collaboratorId,
            paidOn: _paidOn(),
            method: _method,
          );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = collabErrorText(e, l);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final j = widget.job;
    final other = _other;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3, bottom: AppSpace.s2),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        key: const Key('collab-paid-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.collabPaidSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            '${j.collaboratorName} · ${collabShootText(j, hours: false)} · '
            '${formatMoney(j.agreedFee)}',
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          label(l.collabPaidDate),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              AppChip(
                key: const Key('collab-paid-today'),
                label: l.collabPaidToday,
                selected: _day == _Day.today,
                enabled: !_sending,
                onChanged: (_) => setState(() => _day = _Day.today),
              ),
              AppChip(
                key: const Key('collab-paid-yesterday'),
                label: l.collabPaidYesterday,
                selected: _day == _Day.yesterday,
                enabled: !_sending,
                onChanged: (_) => setState(() => _day = _Day.yesterday),
              ),
              AppChip(
                key: const Key('collab-paid-other'),
                label: _day == _Day.other && other != null
                    ? formatDayMonth(other)
                    : l.collabPaidOtherDay,
                selected: _day == _Day.other,
                enabled: !_sending,
                onChanged: (_) => _pickOther(),
              ),
            ],
          ),
          label(l.collabPaidMethod),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (final m in CollabPayMethod.values)
                AppChip(
                  key: Key('collab-method-${m.code}'),
                  label: collabMethodLabel(m, l),
                  selected: _method == m,
                  enabled: !_sending,
                  onChanged: (_) => setState(() => _method = m),
                ),
            ],
          ),
          if (_error case final e?) ...[
            const SizedBox(height: AppSpace.s3),
            Text(
              e,
              key: const Key('collab-paid-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.collabPaidConfirm,
            key: const Key('collab-paid-confirm'),
            loading: _sending,
            onPressed: _sending ? null : _confirm,
          ),
        ],
      ),
    );
  }
}
