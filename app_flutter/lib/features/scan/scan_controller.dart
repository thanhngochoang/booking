// S30.07: one scan at a time against `scanPass` (Decision 9). The server
// decides from the scanner's roles what the code changes; this controller
// only sends it, keeps it for a retry and remembers the answer.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:photobooking/data/passes/pass_repository.dart';

/// `VE-XXXX-MMDD` and other ticket codes from before S30: `scanPass` resolves
/// them through `ticket_codes` (Decision 7), so they are sent as typed.
final _legacyTicketCode = RegExp(r'^VE-[A-Z0-9]{4}-[0-9]{4}$');

/// What is sent for [raw] (a QR payload or a typed code): the 8-character
/// pass code, a legacy ticket code in capitals, or null for anything else.
String? scanCodeOf(String raw) {
  final pass = normalizePassCode(raw);
  if (pass != null) return pass;
  final upper = raw.trim().toUpperCase();
  return _legacyTicketCode.hasMatch(upper) ? upper : null;
}

enum ScanPhase { idle, checking, done, failed }

@immutable
class ScanState {
  const ScanState({
    this.phase = ScanPhase.idle,
    this.code,
    this.result,
    this.error,
    this.todayCount,
  });

  final ScanPhase phase;

  /// The code of the scan on screen, kept for "Thử lại" when offline.
  final String? code;
  final ScanResult? result;
  final PassError? error;

  /// The day's `checkedIn` after the last gate scan of an entry day.
  final int? todayCount;

  bool get busy => phase != ScanPhase.idle;
}

final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);

class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  /// Sends [raw] unless a scan is on screen. A code that is no pass or
  /// ticket code is `not_found` without a call. Success vibrates short, a
  /// refusal long (spec S30.07).
  Future<void> submit(String raw) async {
    if (state.busy) return;
    final code = scanCodeOf(raw);
    if (code == null) {
      state = ScanState(
        phase: ScanPhase.failed,
        code: raw.trim(),
        error: const PassError(PassErrorCode.notFound),
        todayCount: state.todayCount,
      );
      await _vibrateLong();
      return;
    }
    await _send(code);
  }

  /// "Thử lại": the same code again (offline answer).
  Future<void> retry() async {
    final code = state.code;
    if (code == null || state.phase == ScanPhase.checking) return;
    await _send(code);
  }

  Future<void> _send(String code) async {
    state = ScanState(
      phase: ScanPhase.checking,
      code: code,
      todayCount: state.todayCount,
    );
    try {
      final r = await ref.read(passRepositoryProvider).scan(code);
      if (!ref.mounted) return;
      state = ScanState(
        phase: ScanPhase.done,
        code: code,
        result: r,
        todayCount: r.todayCount ?? state.todayCount,
      );
      await _vibrateShort();
    } catch (e) {
      if (!ref.mounted) return;
      state = ScanState(
        phase: ScanPhase.failed,
        code: code,
        error: passErrorOf(e),
        todayCount: state.todayCount,
      );
      await _vibrateLong();
    }
  }

  /// Back to the camera ("Quét tiếp", the 3 s close, a closed sheet).
  void reset() {
    if (state.phase == ScanPhase.checking) return;
    state = ScanState(todayCount: state.todayCount);
  }

  Future<void> _vibrateShort() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> _vibrateLong() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
