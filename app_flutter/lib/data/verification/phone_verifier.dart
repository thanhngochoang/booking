import 'package:flutter/foundation.dart';

/// A code sent by SMS to [phone] (S21.01), to confirm with
/// [PhoneVerifier.confirmCode].
@immutable
class PhoneCodeRequest {
  const PhoneCodeRequest({
    required this.phone,
    required this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });

  /// E.164, e.g. `+84903123456`.
  final String phone;
  final String verificationId;

  /// Passed back to resend without a new reCAPTCHA/SafetyNet check.
  final int? resendToken;

  /// Android read the SMS itself and the number is already linked: no code
  /// to type, go straight to `confirmPhoneVerified`.
  final bool autoVerified;
}

enum PhoneVerifyErrorCode {
  invalidPhone,
  tooManyRequests,
  invalidCode,
  codeExpired,
  alreadyInUse,
  network,
  unknown,
}

class PhoneVerifyError implements Exception {
  const PhoneVerifyError(this.code);
  final PhoneVerifyErrorCode code;

  @override
  String toString() => 'PhoneVerifyError(${code.name})';
}

/// Proves the signed-in user owns a phone number by SMS code and links it to
/// their account; the server then trusts the account's number.
abstract class PhoneVerifier {
  Future<PhoneCodeRequest> sendCode(String e164, {int? resendToken});

  /// Links the number of [request] to the signed-in account (replacing a
  /// previously linked one). Nothing to do for an auto-verified request.
  Future<void> confirmCode(PhoneCodeRequest request, String smsCode);
}

/// In-memory [PhoneVerifier] for tests: [validCode] is the only right code;
/// [sendError] / [confirmError] fail the calls while set.
class FakePhoneVerifier implements PhoneVerifier {
  static const validCode = '123456';

  PhoneVerifyErrorCode? sendError;
  PhoneVerifyErrorCode? confirmError;

  /// Numbers a code was sent to, in order.
  final sent = <String>[];

  /// Numbers linked to the account, in order.
  final linked = <String>[];

  /// Resend tokens received, in order (null for a first send).
  final resendTokens = <int?>[];

  int _seq = 0;

  @override
  Future<PhoneCodeRequest> sendCode(String e164, {int? resendToken}) async {
    resendTokens.add(resendToken);
    final error = sendError;
    if (error != null) {
      throw PhoneVerifyError(error);
    }
    sent.add(e164);
    _seq++;
    return PhoneCodeRequest(
      phone: e164,
      verificationId: 'fake-vid-$_seq',
      resendToken: _seq,
    );
  }

  @override
  Future<void> confirmCode(PhoneCodeRequest request, String smsCode) async {
    final error = confirmError;
    if (error != null) {
      throw PhoneVerifyError(error);
    }
    if (request.autoVerified) {
      return;
    }
    if (smsCode != validCode) {
      throw const PhoneVerifyError(PhoneVerifyErrorCode.invalidCode);
    }
    linked.add(request.phone);
  }
}
