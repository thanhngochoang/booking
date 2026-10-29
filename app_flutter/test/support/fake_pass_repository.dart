// test/support/fake_pass_repository.dart
import 'dart:async';

import 'package:photobooking/data/passes/pass_repository.dart';

/// In-memory passes and a scripted `scanPass`.
class FakePassRepository implements PassRepository {
  final Map<String, String> _bookingPasses = {};
  final Map<String, String> _registrationPasses = {};
  final _changes = StreamController<void>.broadcast();

  /// While set, every pass stream fails with it (offline) and [scan] throws
  /// it.
  Object? failWith;

  /// Scan answers by normalised code (or the raw upper-case code for a
  /// legacy one); a code without an answer is `not_found`.
  final Map<String, Object> scanAnswers = {};

  /// Every code [scan] received, as sent to the server.
  final List<String> scans = [];

  /// Delay before a scan answers (S30.07 "within 2 s").
  Duration scanDelay = Duration.zero;

  void setBookingPass(String bookingId, String? code) {
    if (code == null) {
      _bookingPasses.remove(bookingId);
    } else {
      _bookingPasses[bookingId] = code;
    }
    _changes.add(null);
  }

  void setRegistrationPass(String regId, String? code) {
    if (code == null) {
      _registrationPasses.remove(regId);
    } else {
      _registrationPasses[regId] = code;
    }
    _changes.add(null);
  }

  /// Scripts the answer to [code]: a [ScanResult] or a [PassError].
  void answerScan(String code, Object answer) =>
      scanAnswers[normalizePassCode(code) ?? code.trim().toUpperCase()] =
          answer;

  Stream<String?> _watch(String? Function() read) {
    late final StreamController<String?> c;
    StreamSubscription<void>? sub;
    c = StreamController<String?>(
      onListen: () {
        void emit() {
          final e = failWith;
          if (e != null) {
            c.addError(e);
          } else {
            c.add(read());
          }
        }

        emit();
        sub = _changes.stream.listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<String?> watchBookingPass(String bookingId) =>
      _watch(() => _bookingPasses[bookingId]);

  @override
  Stream<String?> watchRegistrationPass(String eventId, String regId) =>
      _watch(() => _registrationPasses[regId]);

  @override
  Future<ScanResult> scan(String code) async {
    final send = normalizePassCode(code) ?? code.trim().toUpperCase();
    scans.add(send);
    if (scanDelay > Duration.zero) await Future<void>.delayed(scanDelay);
    final e = failWith;
    if (e != null) throw e;
    final a = scanAnswers[send];
    if (a is ScanResult) return a;
    if (a is PassError) throw a;
    throw const PassError(PassErrorCode.notFound);
  }
}
