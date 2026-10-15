// lib/features/verification/verify_phone_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/verification/phone_verifier.dart';
import 'package:photobooking/data/verification/verification_providers.dart';

/// Seconds before "Gửi lại mã" is offered again (S21.01-code).
const verifyPhoneResendSeconds = 60;

/// How long "Gửi mã" waits for the SMS service to answer (code sent,
/// auto-verified or refused) before giving up as a network failure, so the
/// screen never stays in [VerifyPhoneStep.sending] with back blocked.
const verifyPhoneSendTimeout = Duration(seconds: 90);

/// Where S21.01 stands: typing the number, waiting for the SMS, typing the
/// code, checking it, or verified.
enum VerifyPhoneStep { enter, sending, code, confirming, done }

/// Why the last action did not go through; shown under the field of the step.
enum VerifyPhoneIssue {
  required,
  invalidPhone,
  inUse,
  tooMany,
  wrongCode,
  expiredCode,
  failed,
}

@immutable
class VerifyPhoneState {
  const VerifyPhoneState({
    required this.step,
    this.phone,
    this.issue,
    this.resendIn = 0,
    this.resending = false,
    this.justVerified = false,
  });

  final VerifyPhoneStep step;

  /// E.164: the saved number on [VerifyPhoneStep.enter] (prefill), the number
  /// the code went to afterwards.
  final String? phone;
  final VerifyPhoneIssue? issue;

  /// Seconds until a resend is allowed (code step).
  final int resendIn;
  final bool resending;

  /// [VerifyPhoneStep.done] reached on this screen (not already verified on
  /// arrival), so the screen moves on by itself.
  final bool justVerified;

  bool get busy =>
      step == VerifyPhoneStep.sending ||
      step == VerifyPhoneStep.confirming ||
      resending;

  /// The digits the SMS went to end with.
  String get last4 {
    final p = phone ?? '';
    return p.length <= 4 ? p : p.substring(p.length - 4);
  }

  VerifyPhoneState copyWith({
    VerifyPhoneStep? step,
    Object? issue = _keep,
    int? resendIn,
    bool? resending,
  }) => VerifyPhoneState(
    step: step ?? this.step,
    phone: phone,
    issue: identical(issue, _keep) ? this.issue : issue as VerifyPhoneIssue?,
    resendIn: resendIn ?? this.resendIn,
    resending: resending ?? this.resending,
    justVerified: justVerified,
  );
}

const Object _keep = Object();

VerifyPhoneIssue _issueOf(PhoneVerifyErrorCode code) => switch (code) {
  PhoneVerifyErrorCode.invalidPhone => VerifyPhoneIssue.invalidPhone,
  PhoneVerifyErrorCode.tooManyRequests => VerifyPhoneIssue.tooMany,
  PhoneVerifyErrorCode.invalidCode => VerifyPhoneIssue.wrongCode,
  PhoneVerifyErrorCode.codeExpired => VerifyPhoneIssue.expiredCode,
  PhoneVerifyErrorCode.alreadyInUse => VerifyPhoneIssue.inUse,
  PhoneVerifyErrorCode.network ||
  PhoneVerifyErrorCode.unknown => VerifyPhoneIssue.failed,
};

/// S21.01: `enter → sending → code → confirming → done`. The code links the
/// number to the Auth account; then a different number is saved to the
/// private contact (keeping the Zalo/WhatsApp choices) and the server is
/// asked to mark it verified (`confirmPhoneVerified`). The resend countdown
/// is a one-shot timer per second, stopped at 0 and on dispose.
class VerifyPhoneController extends Notifier<VerifyPhoneState> {
  Timer? _tick;
  PhoneCodeRequest? _request;

  /// The current [_request] is already linked, so a retry after a failed
  /// save or server call does not link (and fail) a second time.
  bool _linked = false;

  @override
  VerifyPhoneState build() {
    ref.onDispose(_stopTick);
    // Read once: the screen builds this only after the contact loaded, and a
    // later contact change (our own save) must not reset the flow.
    final contact = ref.read(currentContactProvider).value;
    return VerifyPhoneState(
      step: contact?.phoneVerified ?? false
          ? VerifyPhoneStep.done
          : VerifyPhoneStep.enter,
      phone: contact?.phone,
    );
  }

  /// "Gửi mã" with the text of the number field.
  Future<void> send(String fieldText) async {
    if (state.busy) {
      return;
    }
    final e164 = phoneFromField(fieldText);
    if (e164 == null) {
      state = VerifyPhoneState(
        step: VerifyPhoneStep.enter,
        phone: state.phone,
        issue: fieldText.trim().isEmpty
            ? VerifyPhoneIssue.required
            : VerifyPhoneIssue.invalidPhone,
      );
      return;
    }
    _stopTick();
    state = VerifyPhoneState(step: VerifyPhoneStep.sending, phone: e164);
    await _sendCode(e164, resendToken: null);
  }

  /// "Gửi lại mã", once the countdown reached 0.
  Future<void> resend() async {
    final r = _request;
    if (r == null ||
        state.step != VerifyPhoneStep.code ||
        state.resendIn > 0 ||
        state.busy) {
      return;
    }
    state = state.copyWith(resending: true, issue: null);
    await _sendCode(r.phone, resendToken: r.resendToken);
  }

  /// "Xác nhận" with the six digits typed.
  Future<void> confirm(String code) async {
    final r = _request;
    if (r == null ||
        state.step != VerifyPhoneStep.code ||
        state.busy ||
        code.length != otpCodeLength) {
      return;
    }
    state = state.copyWith(step: VerifyPhoneStep.confirming, issue: null);
    await _finish(r, code);
  }

  /// "Đổi số điện thoại": back to the number, the code request dropped.
  void changeNumber() {
    if (state.busy) {
      return;
    }
    _stopTick();
    _request = null;
    _linked = false;
    state = VerifyPhoneState(step: VerifyPhoneStep.enter, phone: state.phone);
  }

  /// The user edits a field: the message under it goes away.
  void clearIssue() {
    if (state.issue != null && !state.busy) {
      state = state.copyWith(issue: null);
    }
  }

  Future<void> _sendCode(String e164, {required int? resendToken}) async {
    try {
      final r = await ref
          .read(phoneVerifierProvider)
          .sendCode(e164, resendToken: resendToken)
          .timeout(
            verifyPhoneSendTimeout,
            onTimeout: () =>
                throw const PhoneVerifyError(PhoneVerifyErrorCode.network),
          );
      if (!ref.mounted) {
        return;
      }
      _request = r;
      _linked = r.autoVerified;
      if (r.autoVerified) {
        state = VerifyPhoneState(step: VerifyPhoneStep.confirming, phone: e164);
        await _finish(r, '');
        return;
      }
      state = VerifyPhoneState(
        step: VerifyPhoneStep.code,
        phone: e164,
        resendIn: verifyPhoneResendSeconds,
      );
      _startTick();
    } on PhoneVerifyError catch (e) {
      _fail(_issueOf(e.code));
    } on Object {
      _fail(VerifyPhoneIssue.failed);
    }
  }

  Future<void> _finish(PhoneCodeRequest r, String code) async {
    try {
      if (!_linked) {
        await ref.read(phoneVerifierProvider).confirmCode(r, code);
        _linked = true;
      }
      await _saveIfChanged(r.phone);
      await ref.read(verificationRepositoryProvider).confirmPhoneVerified();
      if (!ref.mounted) {
        return;
      }
      _stopTick();
      state = VerifyPhoneState(
        step: VerifyPhoneStep.done,
        phone: r.phone,
        justVerified: true,
      );
    } on PhoneVerifyError catch (e) {
      _fail(_issueOf(e.code));
    } on Object {
      _fail(VerifyPhoneIssue.failed);
    }
  }

  /// Saves [phone] to the private contact when it is not the number there.
  /// The repository resets `phoneVerified` for a new number; the server sets
  /// it again in `confirmPhoneVerified`.
  Future<void> _saveIfChanged(String phone) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw StateError('signed out');
    }
    // The screen keeps the contact stream open, so this is the saved number.
    final contact = ref.read(currentContactProvider).value;
    if (contact?.phone == phone) {
      return;
    }
    await ref
        .read(userContactRepositoryProvider)
        .save(
          uid,
          phone: phone,
          allowZalo: contact?.allowZalo ?? true,
          allowWhatsApp: contact?.allowWhatsApp ?? false,
        );
  }

  /// A refusal: a number already on another account goes back to the number
  /// step; anything else stays on the step it happened in.
  void _fail(VerifyPhoneIssue issue) {
    if (!ref.mounted) {
      return;
    }
    final onCode =
        _request != null &&
        !(_request!.autoVerified) &&
        issue != VerifyPhoneIssue.inUse &&
        (state.step == VerifyPhoneStep.code ||
            state.step == VerifyPhoneStep.confirming);
    if (onCode) {
      state = state.copyWith(
        step: VerifyPhoneStep.code,
        issue: issue,
        resending: false,
      );
      return;
    }
    _stopTick();
    _request = null;
    _linked = false;
    state = VerifyPhoneState(
      step: VerifyPhoneStep.enter,
      phone: state.phone,
      issue: issue,
    );
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer(const Duration(seconds: 1), _onTick);
  }

  void _onTick() {
    _tick = null;
    // Keeps counting while a code is being checked: a wrong code returns to
    // the code step with the time that is left.
    if (!ref.mounted ||
        (state.step != VerifyPhoneStep.code &&
            state.step != VerifyPhoneStep.confirming)) {
      return;
    }
    final left = state.resendIn - 1;
    state = state.copyWith(resendIn: left < 0 ? 0 : left);
    if (left > 0) {
      _tick = Timer(const Duration(seconds: 1), _onTick);
    }
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }
}

final verifyPhoneControllerProvider =
    NotifierProvider.autoDispose<VerifyPhoneController, VerifyPhoneState>(
      VerifyPhoneController.new,
    );
