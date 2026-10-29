// S30.07 `/scan`: one scan screen for the gate (organizer and gate staff),
// event managers and the photographer meeting a customer (S30.07-booking,
// `?booking=`). Full-screen camera on dark, close and torch, "Nhập mã 8 ký
// tự", the day's count for the gate; results in a sheet. No gradient button.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/scan/manual_code_sheet.dart';
import 'package:photobooking/features/scan/scan_controller.dart';
import 'package:photobooking/features/scan/scan_result_sheet.dart';

/// A booking's pass scans from this long before its start (Decision 10;
/// S06.01-scan "Mở lúc {time}" until then).
const scanOpensBefore = Duration(hours: 2);

/// `/scan`, with `?booking=<id>` from S06.01 ("Quét mã khách") or
/// `?event=<id>` from S12.03 ("Quét mã check-in").
String scanLocation({String? bookingId, String? eventId}) => Uri(
  path: '/scan',
  queryParameters: {'booking': ?bookingId, 'event': ?eventId},
).toString().replaceFirst(RegExp(r'\?$'), '');

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.bookingId, this.eventId});

  /// The photographer's booking (S30.07-booking): title "Quét mã khách" and
  /// "Về buổi chụp" after the scan.
  final String? bookingId;
  final String? eventId;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late final PassScanner _scanner = ref.read(passScannerFactoryProvider)();
  StreamSubscription<String>? _codes;
  bool _sheetOpen = false;

  /// Why the preview shows no camera (set after the frame that drew it):
  /// the primer replaces the frame and the hint.
  PassScannerFailure? _failure;

  bool get _shooter => widget.bookingId != null;

  @override
  void initState() {
    super.initState();
    _codes = _scanner.codes().listen(_onCode);
  }

  @override
  void dispose() {
    unawaited(_codes?.cancel());
    _scanner.dispose();
    super.dispose();
  }

  void _onCode(String raw) {
    if (_sheetOpen || ref.read(scanControllerProvider).busy) return;
    unawaited(ref.read(scanControllerProvider.notifier).submit(raw));
  }

  Future<void> _manual() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final code = await showManualCodeSheet(context);
    _sheetOpen = false;
    if (code != null && mounted) {
      unawaited(ref.read(scanControllerProvider.notifier).submit(code));
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go('/');

  /// Opens the result sheet once a scan answered; "Quét tiếp" (or the 3 s
  /// close) returns to the camera, "Thử lại" sends the kept code again.
  void _onState(ScanState? prev, ScanState next) {
    final answered =
        next.phase == ScanPhase.done || next.phase == ScanPhase.failed;
    if (!answered || prev?.phase == next.phase) return;
    unawaited(_showResult(next));
  }

  Future<void> _showResult(ScanState s) async {
    if (_sheetOpen || !mounted) return;
    _sheetOpen = true;
    final booking = _shooter
        ? ref.read(bookingProvider(widget.bookingId!)).value
        : null;
    final exit = await showScanResultSheet(
      context,
      state: s,
      shooter: _shooter,
      bookingLine: booking == null ? null : _bookingLine(booking),
      ticketNote: booking == null ? null : _ticketNote(booking),
    );
    _sheetOpen = false;
    if (!mounted) return;
    final ctl = ref.read(scanControllerProvider.notifier);
    switch (exit) {
      case ScanSheetExit.retry:
        unawaited(ctl.retry());
      case ScanSheetExit.backToShoot:
        ctl.reset();
        final id = s.result?.booking?.id ?? widget.bookingId;
        if (id != null) context.go('/b/$id');
      case ScanSheetExit.next:
        ctl.reset();
    }
  }

  String _bookingLine(Booking b) =>
      '${b.serviceSnapshot.name} · ${b.start}–${b.end} · ${b.place.name}';

  /// The photographer's ticket (S30.07-booking): bought with the booking,
  /// waived as a resident, or to buy at the gate of a ticketed spot.
  String? _ticketNote(Booking b) {
    final l = context.l10n;
    final entry = b.entry;
    if (entry != null) {
      if (entry.providerTicket) return l.s3007_ticketBought;
      if (entry.waivedProvider) return l.s3007_ticketWaived;
    }
    final spotId = b.spotId;
    if (spotId == null) return null;
    final spot = ref.read(spotProvider(spotId)).value;
    return spot?.isTicketed == true ? l.s3007_ticketOnSite : null;
  }

  /// The spot the scanner keeps the gate of: my first managed spot, else
  /// the first managed spot of the organizer I am active gate staff for.
  String? _gateSpotId() {
    final mine = ref.watch(myOrganizerProvider).value;
    final own = mine?.managedSpotIds.firstOrNull;
    if (own != null) return own;
    for (final g in ref.watch(myGateInvitesProvider).value ?? const []) {
      if (g.status != GateStaffStatus.active) continue;
      final org = ref.watch(organizerProvider(g.organizerId)).value;
      final id = org?.managedSpotIds.firstOrNull;
      if (id != null) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.listen(scanControllerProvider, _onState);
    final scan = ref.watch(scanControllerProvider);
    if (_shooter) {
      // Read ahead: the result sheet names the shoot and the ticket.
      final b = ref.watch(bookingProvider(widget.bookingId!)).value;
      if (b?.spotId case final id?) ref.watch(spotProvider(id));
    }
    final spotId = _shooter || widget.eventId != null ? null : _gateSpotId();
    final spotName = spotId == null
        ? null
        : ref.watch(spotProvider(spotId)).value?.name;
    final title = _shooter
        ? l.s0601_scan
        : spotName != null
        ? l.s3007_gateTitle(spotName)
        : l.s3007_title;

    // "Hôm nay: {in} / {sold} khách đã vào": the gate only (spec §3.5).
    String? today;
    if (spotId != null) {
      final entry = ref.watch(entryEventProvider(spotId)).value;
      if (entry != null) {
        final day = vnDateKey(ref.watch(clockProvider)());
        final row = ref
            .watch(entryDayProvider((eventId: entry.id, day: day)))
            .value;
        final sold = row?.sold ?? 0;
        final entered = scan.todayCount ?? row?.checkedIn ?? 0;
        today = l.s3007_today(entered, sold);
      }
    }

    const ink = AppColors.onScrim;
    return ScreenCode(
      ScreenCodes.scanPass,
      label: _shooter ? 'booking' : null,
      child: Scaffold(
        backgroundColor: AppColorsDark.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _scanner.preview(
                errorBuilder: (context, failure) {
                  if (_failure != failure) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _failure = failure);
                    });
                  }
                  return _CameraOff(
                    failure: failure,
                    onSettings: () => unawaited(_scanner.openSettings()),
                    onManual: _manual,
                  );
                },
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('scan-close'),
                          tooltip: l.s30_close,
                          color: ink,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.overlay,
                          ),
                          icon: const AppIcon(AppIcons.close),
                          onPressed: _close,
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Text(
                            title,
                            key: const Key('scan-title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ink,
                              fontSize: AppText.md,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        IconButton(
                          key: const Key('scan-torch'),
                          tooltip: l.s3007_torch,
                          color: ink,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.overlay,
                          ),
                          icon: const AppIcon(AppIcons.flashlight),
                          onPressed: () => unawaited(_scanner.toggleTorch()),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_failure != PassScannerFailure.permissionDenied) ...[
                    const Center(child: _Frame()),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      l.s3007_hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ink, fontSize: AppText.sm),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Center(
                      child: TextButton(
                        key: const Key('scan-manual'),
                        style: TextButton.styleFrom(
                          foregroundColor: ink,
                          backgroundColor: AppColors.overlay,
                          minimumSize: const Size(48, 44),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s4,
                          ),
                        ),
                        onPressed: _manual,
                        child: Text(l.s3007_manual),
                      ),
                    ),
                  ],
                  if (scan.phase == ScanPhase.checking) ...[
                    const SizedBox(height: AppSpace.s3),
                    const Center(
                      child: DotRingLoader(key: Key('scan-checking')),
                    ),
                  ],
                  const Spacer(),
                  if (today != null)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: Text(
                        today,
                        key: const Key('scan-today'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ink,
                          fontSize: AppText.sm,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square the QR goes into.
class _Frame extends StatelessWidget {
  const _Frame();

  @override
  Widget build(BuildContext context) {
    final side = (MediaQuery.sizeOf(context).width * 0.62).clamp(160.0, 280.0);
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.onScrim, width: 2),
      ),
    );
  }
}

/// No camera: the shared primer with "Mở cài đặt" after a refusal (spec
/// S30.07, like S17.03), else a line pointing to the manual entry.
class _CameraOff extends StatelessWidget {
  const _CameraOff({
    required this.failure,
    required this.onSettings,
    required this.onManual,
  });

  final PassScannerFailure failure;
  final VoidCallback onSettings;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (failure != PassScannerFailure.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s6),
          child: Text(
            l.s3007_cameraOff,
            key: const Key('scan-camera-off'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.onScrim),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          88,
          AppSpace.s4,
          AppSpace.s4,
        ),
        child: Material(
          key: const Key('scan-camera-primer'),
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: PermissionPrimer(
            icon: AppIcons.camera,
            title: l.s3007_cameraTitle,
            benefits: [PrimerBenefit(AppIcons.qrScanner, l.s3007_cameraBody)],
            enableLabel: l.s3007_openSettings,
            laterLabel: l.s3007_manual,
            onEnable: onSettings,
            onLater: onManual,
          ),
        ),
      ),
    );
  }
}
