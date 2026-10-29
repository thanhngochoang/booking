// S30.07, S30.07-booking, S30.07-error: what one scan did, in a sheet over
// the camera. Green with the head count (or "Đang chụp · {khách}") on
// success, closing itself after 3 s; red with the reason on a refusal;
// "Chưa quét được, kiểm tra kết nối" keeps the code for "Thử lại".
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/passes/pass_repository.dart';
import 'package:photobooking/features/scan/scan_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// How the result sheet was left.
enum ScanSheetExit { next, backToShoot, retry }

/// A success closes itself after this long (spec S30.07).
const scanAutoClose = Duration(seconds: 3);

/// "Quét tiếp" / "Về buổi chụp" height (spec S30.07: 52 dp).
const scanNextHeight = 52.0;

/// The title of a success: the shooter's booking, the gate's head count, or
/// an event manager's check-in.
String scanSuccessTitle(ScanResult r, AppLocalizations l) {
  final b = r.booking;
  if (b != null) return l.s3007_shooting(b.customerName);
  final entry = r.registrations.any((x) => x.kind == ScanKind.entry);
  final gate = r.registrations.any((x) => x.kind == ScanKind.venueGate);
  if (entry) return l.s3007_entered(r.gateCount);
  if (gate || r.waivedCount > 0) return l.s3007_gate(r.gateCount);
  final n = r.registrations.fold(0, (s, x) => s + x.quantity);
  return l.s3007_entered(n);
}

String _hm(DateTime t) => formatHm(toVn(t));

String _day(String? key) {
  final d = key == null ? null : parseDayKey(key);
  return d == null ? (key ?? '') : formatDay(d);
}

/// The title of a refusal (spec §6.2 codes).
String scanErrorTitle(PassError e, AppLocalizations l) => switch (e.code) {
  PassErrorCode.wrongDay => l.s3007_wrongDay(_day(e.day)),
  PassErrorCode.tooEarly =>
    e.opensAt == null ? l.s3007_notYours : l.s3007_tooEarly(_hm(e.opensAt!)),
  PassErrorCode.alreadyCheckedIn =>
    e.at == null ? l.s3007_refunded : l.s3007_already(_hm(e.at!)),
  PassErrorCode.refunded => l.s3007_refunded,
  PassErrorCode.notYourPass ||
  PassErrorCode.notEligible ||
  PassErrorCode.permissionDenied => l.s3007_notYours,
  PassErrorCode.notFound || PassErrorCode.invalidArgument => l.s3007_notFound,
  PassErrorCode.network => l.s3007_offline,
  PassErrorCode.unknown => l.s3007_failed,
};

Future<ScanSheetExit> showScanResultSheet(
  BuildContext context, {
  required ScanState state,
  required bool shooter,
  String? bookingLine,
  String? ticketNote,
}) async {
  final exit = await showAppSheet<ScanSheetExit>(
    context,
    builder: (sheet) => ScreenCode(
      ScreenCodes.scanPass,
      label: state.phase == ScanPhase.done ? 'result' : 'error',
      child: ScanResultSheet(
        state: state,
        shooter: shooter,
        bookingLine: bookingLine,
        ticketNote: ticketNote,
      ),
    ),
  );
  return exit ?? ScanSheetExit.next;
}

class ScanResultSheet extends StatefulWidget {
  const ScanResultSheet({
    super.key,
    required this.state,
    required this.shooter,
    this.bookingLine,
    this.ticketNote,
  });

  final ScanState state;

  /// Opened from S06.01 "Quét mã khách": the button is "Về buổi chụp".
  final bool shooter;

  /// "Chân dung 2 giờ · 15:30–17:30 · Bãi đá sông Hồng" (S30.07-booking).
  final String? bookingLine;

  /// The photographer's entry ticket line (S30.07-booking).
  final String? ticketNote;

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  Timer? _close;

  bool get _ok => widget.state.phase == ScanPhase.done;

  @override
  void initState() {
    super.initState();
    if (_ok) {
      _close = Timer(scanAutoClose, () {
        if (mounted) Navigator.of(context).pop(ScanSheetExit.next);
      });
    }
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final s = widget.state;
    final result = s.result;
    final error = s.error;
    final offline = error?.code == PassErrorCode.network;
    final color = _ok
        ? AppColors.success
        : (dark ? AppColorsDark.destructive : AppColors.destructive);
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final booking = result?.booking;
    final title = result != null
        ? scanSuccessTitle(result, l)
        : scanErrorTitle(error ?? const PassError(PassErrorCode.unknown), l);
    final code = s.code;
    final shown = code == null
        ? null
        : (code.length == 8 ? passDisplay(code) : code);
    final detail = <String>[
      if (booking != null && widget.bookingLine != null) widget.bookingLine!,
      if (booking == null && result != null)
        ...{for (final r in result.registrations) r.eventTitle}
            .where((t) => t.isNotEmpty),
      ?shown,
    ].join(' · ');
    final icon = switch ((booking != null, error?.code)) {
      (true, _) => AppIcons.camera,
      (_, PassErrorCode.wrongDay) => AppIcons.eventBusy,
      (_, PassErrorCode.network) => AppIcons.cloudOff,
      _ when _ok => AppIcons.check,
      _ => AppIcons.error,
    };
    final back = widget.shooter && booking != null;
    final nextStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(scanNextHeight),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: DecoratedBox(
        key: Key(_ok ? 'scan-result-ok' : 'scan-result-error'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: _ok ? null : Border.all(color: color, width: 1.5),
        ),
        child: Padding(
          padding: EdgeInsets.all(_ok ? 0 : AppSpace.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AppIcon(
                          icon,
                          size: 24,
                          color: AppColors.foregroundInverse,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            key: const Key('scan-result-title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: AppSpace.s1),
                            Text(
                              detail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: secondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (error?.code == PassErrorCode.wrongDay) ...[
                const SizedBox(height: AppSpace.s3),
                Text(
                  l.s3007_wrongDayNote,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
              if (booking != null && widget.ticketNote != null) ...[
                const SizedBox(height: AppSpace.s3),
                Row(
                  key: const Key('scan-ticket-note'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(AppIcons.ticket, size: 18, color: secondary),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Text(
                        widget.ticketNote!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s4),
              if (offline) ...[
                AppButton.outline(
                  l.s3007_retry,
                  key: const Key('scan-retry'),
                  style: nextStyle,
                  onPressed: () =>
                      Navigator.of(context).pop(ScanSheetExit.retry),
                ),
                const SizedBox(height: AppSpace.s2),
              ],
              // "Quét tiếp" (sec), or "Về buổi chụp" for the shooter; never a
              // gradient button on S30.07.
              AppButton.outline(
                back ? l.s3007_backToShoot : l.s3007_next,
                key: Key(back ? 'scan-back-to-shoot' : 'scan-next'),
                style: nextStyle,
                onPressed: () => Navigator.of(context)
                    .pop(back ? ScanSheetExit.backToShoot : ScanSheetExit.next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
