import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:photobooking/data/verification/phone_verifier.dart';

/// The [PhoneVerifyError] of a Firebase Auth refusal.
PhoneVerifyError phoneVerifyErrorOf(FirebaseAuthException e) =>
    PhoneVerifyError(switch (e.code) {
      'invalid-phone-number' => PhoneVerifyErrorCode.invalidPhone,
      'too-many-requests' ||
      'quota-exceeded' => PhoneVerifyErrorCode.tooManyRequests,
      'invalid-verification-code' => PhoneVerifyErrorCode.invalidCode,
      'session-expired' => PhoneVerifyErrorCode.codeExpired,
      'credential-already-in-use' ||
      'account-exists-with-different-credential' =>
        PhoneVerifyErrorCode.alreadyInUse,
      'network-request-failed' => PhoneVerifyErrorCode.network,
      _ => PhoneVerifyErrorCode.unknown,
    });

/// [PhoneVerifier] over Firebase Auth phone sign-in (the Auth emulator in
/// dev): the number is linked to the signed-in account, never used to sign in.
class FirebasePhoneVerifier implements PhoneVerifier {
  FirebasePhoneVerifier({FirebaseAuth? auth}) : _override = auth;

  final FirebaseAuth? _override;
  FirebaseAuth get _auth => _override ?? FirebaseAuth.instance;

  @override
  Future<PhoneCodeRequest> sendCode(String e164, {int? resendToken}) {
    final done = Completer<PhoneCodeRequest>();
    void fail(Object e) {
      if (!done.isCompleted) {
        done.completeError(switch (e) {
          PhoneVerifyError() => e,
          FirebaseAuthException() => phoneVerifyErrorOf(e),
          _ => const PhoneVerifyError(PhoneVerifyErrorCode.unknown),
        });
      }
    }

    // Not awaited: the callbacks may fire during the call, and the answer is
    // [done], returned to the caller before anything can complete it.
    try {
      _auth
          .verifyPhoneNumber(
            phoneNumber: e164,
            forceResendingToken: resendToken,
            timeout: const Duration(seconds: 60),
            // Android read the SMS itself. Before codeSent: link now and
            // answer an auto-verified request. After it the user types the
            // code anyway, so a late auto-retrieval is ignored (linking twice
            // would fail).
            verificationCompleted: (credential) async {
              if (done.isCompleted) {
                return;
              }
              try {
                await _link(credential);
                if (!done.isCompleted) {
                  done.complete(
                    PhoneCodeRequest(
                      phone: e164,
                      verificationId: credential.verificationId ?? '',
                      resendToken: resendToken,
                      autoVerified: true,
                    ),
                  );
                }
              } on Object catch (e) {
                fail(e);
              }
            },
            verificationFailed: fail,
            codeSent: (verificationId, token) {
              if (!done.isCompleted) {
                done.complete(
                  PhoneCodeRequest(
                    phone: e164,
                    verificationId: verificationId,
                    resendToken: token,
                  ),
                );
              }
            },
            codeAutoRetrievalTimeout: (_) {},
          )
          .catchError(fail);
    } on Object catch (e) {
      fail(e);
    }
    return done.future;
  }

  @override
  Future<void> confirmCode(PhoneCodeRequest request, String smsCode) async {
    if (request.autoVerified) {
      return;
    }
    await _link(
      PhoneAuthProvider.credential(
        verificationId: request.verificationId,
        smsCode: smsCode,
      ),
    );
  }

  /// `updatePhoneNumber` when the account already has the phone provider,
  /// else `linkWithCredential`.
  Future<void> _link(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PhoneVerifyError(PhoneVerifyErrorCode.unknown);
    }
    try {
      final hasPhone = user.providerData.any(
        (p) => p.providerId == PhoneAuthProvider.PROVIDER_ID,
      );
      if (hasPhone) {
        await user.updatePhoneNumber(credential);
      } else {
        await user.linkWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw phoneVerifyErrorOf(e);
    }
  }
}
