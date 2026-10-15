// lib/features/verification/verify_identity_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';

/// Where S21.03 stands.
///
/// - [intro]: the VNeID screen, or step 1/2 (chip) of the NFC screen.
/// - [starting]: `startIdentityVerification` is running.
/// - [consent]: fake mode, VNeID: the fake VNeID sheet asks for consent.
/// - [selfie]: fake mode, chip: step 2/2 (selfie) of the NFC screen.
/// - [completing]: `completeIdentityVerification` is running.
/// - [waiting]: real mode: the vendor page is open; the result comes from
///   the `verifications/{uid}` listener.
/// - [passed]: verified; shows the masked name.
enum IdentityPhase {
  intro,
  starting,
  consent,
  selfie,
  completing,
  waiting,
  passed,
}

/// Why the last try did not pass. [underage] and [inUse] are final, and
/// [rateLimited] waits for the next Vietnam day: none of them offers a retry.
enum IdentityIssue {
  underage,
  inUse,
  rateLimited,
  failed;

  bool get canRetry => this == failed;
}

IdentityIssue _issueOf(String code) => switch (code) {
  'underage' => IdentityIssue.underage,
  'identity_in_use' => IdentityIssue.inUse,
  'rate_limited' => IdentityIssue.rateLimited,
  _ => IdentityIssue.failed,
};

/// The failure a check left on the record (`steps.identity.failure`).
IdentityIssue? _recordedIssue(String? failure) => switch (failure) {
  null => null,
  'underage' => IdentityIssue.underage,
  'identity_in_use' => IdentityIssue.inUse,
  _ => IdentityIssue.failed,
};

@immutable
class VerifyIdentityState {
  const VerifyIdentityState({
    required this.method,
    required this.phase,
    this.sessionId,
    this.maskedName,
    this.issue,
  });

  /// Which screen is shown: VNeID or the chip (NFC) fallback.
  final IdentityMethod method;
  final IdentityPhase phase;
  final String? sessionId;
  final String? maskedName;
  final IdentityIssue? issue;

  bool get busy =>
      phase == IdentityPhase.starting ||
      phase == IdentityPhase.completing ||
      phase == IdentityPhase.consent ||
      phase == IdentityPhase.waiting;

  /// The primary action may start a try: no final issue is showing.
  bool get canTry => issue == null || issue!.canRetry;

  VerifyIdentityState copyWith({
    IdentityMethod? method,
    IdentityPhase? phase,
    Object? sessionId = _keep,
    Object? maskedName = _keep,
    Object? issue = _keep,
  }) => VerifyIdentityState(
    method: method ?? this.method,
    phase: phase ?? this.phase,
    sessionId: identical(sessionId, _keep)
        ? this.sessionId
        : sessionId as String?,
    maskedName: identical(maskedName, _keep)
        ? this.maskedName
        : maskedName as String?,
    issue: identical(issue, _keep) ? this.issue : issue as IdentityIssue?,
  );
}

const Object _keep = Object();

/// S21.03: start a session for the chosen method, then
/// - fake mode (`identityModeRealProvider` false): VNeID asks the fake sheet
///   for consent, the chip goes to the selfie step; both then complete the
///   session (`completeIdentityVerification`);
/// - real mode: opens the vendor's `redirectUrl` and waits for the
///   `verifications/{uid}` listener to show the result.
class VerifyIdentityController extends Notifier<VerifyIdentityState> {
  VerifyIdentityController(this.initialMethod);

  final IdentityMethod initialMethod;

  /// `steps.identity.checkedAt` when the session started. The server counts
  /// the try on start and keeps an older failure on the record until the
  /// next check finishes, so only a changed `checkedAt` is this session's
  /// result.
  DateTime? _checkedAtStart;

  @override
  VerifyIdentityState build() {
    ref.listen(myVerificationProvider, (_, next) {
      final s = next.value;
      if (s != null) {
        _onRecord(s);
      }
    });
    // Read once: the screen builds this after the record loaded.
    final s = ref.read(myVerificationProvider).value;
    if (s != null && s.identityPassed) {
      return VerifyIdentityState(
        method: s.identityMethod ?? initialMethod,
        phase: IdentityPhase.passed,
        maskedName: s.maskedName,
      );
    }
    final recorded = _recordedIssue(s?.identityFailure);
    return VerifyIdentityState(
      method: initialMethod,
      phase: IdentityPhase.intro,
      // A final reason (underage, identity in use) says more than the daily
      // limit; a failed vendor check may be retried, so it shows only when
      // no tries are left today.
      issue: recorded != null && recorded != IdentityIssue.failed
          ? recorded
          : s != null && s.identityAttemptsLeft == 0
          ? IdentityIssue.rateLimited
          : null,
    );
  }

  void _onRecord(VerificationState s) {
    // A pass on the record is the result whatever the screen is doing.
    if (s.identityPassed) {
      if (state.phase != IdentityPhase.passed) {
        state = state.copyWith(
          phase: IdentityPhase.passed,
          maskedName: s.maskedName,
          sessionId: null,
          issue: null,
        );
      }
      return;
    }
    if (state.phase != IdentityPhase.waiting) {
      return;
    }
    final failure = _recordedIssue(s.identityFailure);
    if (failure != null && s.identityCheckedAt != _checkedAtStart) {
      state = state.copyWith(
        phase: IdentityPhase.intro,
        sessionId: null,
        issue: failure,
      );
    }
  }

  /// "Quét chip CCCD" on the VNeID screen, or Back from the chip screen.
  void useMethod(IdentityMethod method) {
    if (state.busy || state.phase == IdentityPhase.passed) {
      return;
    }
    state = state.copyWith(
      method: method,
      phase: IdentityPhase.intro,
      sessionId: null,
      issue: state.canTry ? null : state.issue,
    );
  }

  /// Back from the selfie step to step 1/2.
  void backToChip() {
    if (state.phase == IdentityPhase.selfie) {
      state = state.copyWith(phase: IdentityPhase.intro, sessionId: null);
    }
  }

  /// "Xác minh bằng VNeID" / "Bắt đầu quét".
  Future<void> start() async {
    if (state.busy || !state.canTry || state.phase != IdentityPhase.intro) {
      return;
    }
    final method = state.method;
    state = state.copyWith(phase: IdentityPhase.starting, issue: null);
    final real = ref.read(identityModeRealProvider);
    _checkedAtStart = ref.read(myVerificationProvider).value?.identityCheckedAt;
    try {
      final session = await ref
          .read(verificationRepositoryProvider)
          .startIdentity(method);
      if (!ref.mounted) {
        return;
      }
      if (real) {
        final url = session.redirectUrl;
        state = state.copyWith(
          phase: IdentityPhase.waiting,
          sessionId: session.sessionId,
        );
        if (url != null) {
          final opened = await ref
              .read(externalLauncherProvider)
              .open(Uri.parse(url));
          if (ref.mounted && !opened) {
            state = state.copyWith(
              phase: IdentityPhase.intro,
              issue: IdentityIssue.failed,
            );
          }
        }
        return;
      }
      state = state.copyWith(
        phase: method == IdentityMethod.vneid
            ? IdentityPhase.consent
            : IdentityPhase.selfie,
        sessionId: session.sessionId,
      );
    } on VerificationError catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: IdentityPhase.intro,
          issue: _issueOf(e.code),
        );
      }
    }
  }

  /// The fake VNeID sheet closed: [agreed] completes the session, otherwise
  /// the screen goes back to its start.
  Future<void> consent({required bool agreed}) async {
    if (state.phase != IdentityPhase.consent) {
      return;
    }
    if (!agreed) {
      state = state.copyWith(phase: IdentityPhase.intro, sessionId: null);
      return;
    }
    await _complete();
  }

  /// "Bắt đầu chụp" (fake mode, chip step 2/2).
  Future<void> capture() async {
    if (state.phase != IdentityPhase.selfie) {
      return;
    }
    await _complete();
  }

  Future<void> _complete() async {
    final sessionId = state.sessionId;
    if (sessionId == null) {
      state = state.copyWith(phase: IdentityPhase.intro);
      return;
    }
    state = state.copyWith(phase: IdentityPhase.completing);
    try {
      final name = await ref
          .read(verificationRepositoryProvider)
          .completeIdentity(sessionId);
      if (ref.mounted) {
        state = state.copyWith(
          phase: IdentityPhase.passed,
          maskedName: name,
          issue: null,
        );
      }
    } on VerificationError catch (e) {
      if (ref.mounted) {
        // A session is used once: any retry starts a new one (the chip
        // screen goes back to step 1/2).
        state = state.copyWith(
          phase: IdentityPhase.intro,
          sessionId: null,
          issue: _issueOf(e.code),
        );
      }
    }
  }
}

final verifyIdentityControllerProvider = NotifierProvider.autoDispose
    .family<VerifyIdentityController, VerifyIdentityState, IdentityMethod>(
      VerifyIdentityController.new,
    );
