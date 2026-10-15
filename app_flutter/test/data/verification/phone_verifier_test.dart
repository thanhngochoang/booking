import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/verification/firebase_phone_verifier.dart';
import 'package:photobooking/data/verification/phone_verifier.dart';

class _MockAuth extends Mock implements fb.FirebaseAuth {}

class _MockUser extends Mock implements fb.User {}

class _MockInfo extends Mock implements fb.UserInfo {}

class _MockCredential extends Mock implements fb.UserCredential {}

class _FakeAuthCredential extends Fake implements fb.AuthCredential {}

class _FakePhoneCredential extends Fake implements fb.PhoneAuthCredential {}

const _codes = {
  'invalid-phone-number': PhoneVerifyErrorCode.invalidPhone,
  'too-many-requests': PhoneVerifyErrorCode.tooManyRequests,
  'quota-exceeded': PhoneVerifyErrorCode.tooManyRequests,
  'invalid-verification-code': PhoneVerifyErrorCode.invalidCode,
  'session-expired': PhoneVerifyErrorCode.codeExpired,
  'credential-already-in-use': PhoneVerifyErrorCode.alreadyInUse,
  'account-exists-with-different-credential': PhoneVerifyErrorCode.alreadyInUse,
  'network-request-failed': PhoneVerifyErrorCode.network,
  'something-else': PhoneVerifyErrorCode.unknown,
};

Matcher _verifyError(PhoneVerifyErrorCode code) =>
    isA<PhoneVerifyError>().having((e) => e.code, 'code', code);

void main() {
  late _MockAuth auth;
  late _MockUser user;
  late FirebasePhoneVerifier verifier;

  setUpAll(() {
    registerFallbackValue(_FakeAuthCredential());
    registerFallbackValue(_FakePhoneCredential());
    registerFallbackValue(Duration.zero);
    // Callback parameters of verifyPhoneNumber, matched by type.
    registerFallbackValue((fb.PhoneAuthCredential _) {});
    registerFallbackValue((fb.FirebaseAuthException _) {});
    registerFallbackValue((String _, int? _) {});
    registerFallbackValue((String _) {});
  });

  setUp(() {
    auth = _MockAuth();
    user = _MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.providerData).thenReturn(const []);
    when(() => user.linkWithCredential(any()))
        .thenAnswer((_) async => _MockCredential());
    when(() => user.updatePhoneNumber(any())).thenAnswer((_) async {});
    verifier = FirebasePhoneVerifier(auth: auth);
  });

  /// Stubs `verifyPhoneNumber` to call back as [react] says.
  void onVerify(void Function(Invocation call) react) {
    when(
      () => auth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((call) async => react(call));
  }

  T arg<T>(Invocation call, String name) =>
      call.namedArguments[Symbol(name)] as T;

  test('each FirebaseAuthException code maps to its PhoneVerifyErrorCode', () {
    for (final MapEntry(:key, :value) in _codes.entries) {
      expect(
        phoneVerifyErrorOf(fb.FirebaseAuthException(code: key)).code,
        value,
        reason: key,
      );
    }
  });

  test('a failed send answers the mapped error', () async {
    for (final MapEntry(:key, :value) in _codes.entries) {
      onVerify(
        (call) => arg<fb.PhoneVerificationFailed>(call, 'verificationFailed')(
          fb.FirebaseAuthException(code: key),
        ),
      );
      await expectLater(
        verifier.sendCode('+84903123456'),
        throwsA(_verifyError(value)),
        reason: key,
      );
    }
  });

  test('codeSent answers the request with the resend token', () async {
    onVerify((call) => arg<fb.PhoneCodeSent>(call, 'codeSent')('vid-1', 42));
    final r = await verifier.sendCode('+84903123456', resendToken: 7);
    expect(r.phone, '+84903123456');
    expect(r.verificationId, 'vid-1');
    expect(r.resendToken, 42);
    expect(r.autoVerified, isFalse);
    verify(
      () => auth.verifyPhoneNumber(
        phoneNumber: '+84903123456',
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        forceResendingToken: 7,
        timeout: any(named: 'timeout'),
      ),
    ).called(1);
  });

  test('Android auto-retrieval links at once and marks the request', () async {
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: 'vid-auto',
      smsCode: '123456',
    );
    onVerify(
      (call) => arg<fb.PhoneVerificationCompleted>(
        call,
        'verificationCompleted',
      )(credential),
    );
    final r = await verifier.sendCode('+84903123456');
    expect(r.autoVerified, isTrue);
    expect(r.verificationId, 'vid-auto');
    verify(() => user.linkWithCredential(credential)).called(1);
  });

  test('a failed auto-link answers the mapped error', () async {
    when(() => user.linkWithCredential(any()))
        .thenThrow(fb.FirebaseAuthException(code: 'credential-already-in-use'));
    onVerify(
      (call) => arg<fb.PhoneVerificationCompleted>(
        call,
        'verificationCompleted',
      )(fb.PhoneAuthProvider.credential(verificationId: 'v', smsCode: '1')),
    );
    await expectLater(
      verifier.sendCode('+84903123456'),
      throwsA(_verifyError(PhoneVerifyErrorCode.alreadyInUse)),
    );
  });

  test('link when no phone provider, update when one exists', () async {
    const request = PhoneCodeRequest(
      phone: '+84903123456',
      verificationId: 'vid-1',
    );
    await verifier.confirmCode(request, '123456');
    final linked =
        verify(() => user.linkWithCredential(captureAny())).captured.single
            as fb.PhoneAuthCredential;
    expect(linked.verificationId, 'vid-1');
    expect(linked.smsCode, '123456');
    verifyNever(() => user.updatePhoneNumber(any()));

    final phone = _MockInfo();
    when(() => phone.providerId).thenReturn('phone');
    when(() => user.providerData).thenReturn([phone]);
    await verifier.confirmCode(request, '654321');
    final updated =
        verify(() => user.updatePhoneNumber(captureAny())).captured.single
            as fb.PhoneAuthCredential;
    expect(updated.smsCode, '654321');
    verifyNever(() => user.linkWithCredential(any()));
  });

  test('a wrong or expired code answers the mapped error', () async {
    const request = PhoneCodeRequest(
      phone: '+84903123456',
      verificationId: 'v',
    );
    when(() => user.linkWithCredential(any()))
        .thenThrow(fb.FirebaseAuthException(code: 'invalid-verification-code'));
    await expectLater(
      verifier.confirmCode(request, '000000'),
      throwsA(_verifyError(PhoneVerifyErrorCode.invalidCode)),
    );
    when(() => user.linkWithCredential(any()))
        .thenThrow(fb.FirebaseAuthException(code: 'session-expired'));
    await expectLater(
      verifier.confirmCode(request, '000000'),
      throwsA(_verifyError(PhoneVerifyErrorCode.codeExpired)),
    );
  });

  test('an auto-verified request needs no code', () async {
    const request = PhoneCodeRequest(
      phone: '+84903123456',
      verificationId: 'v',
      autoVerified: true,
    );
    await verifier.confirmCode(request, '');
    verifyNever(() => user.linkWithCredential(any()));
    verifyNever(() => user.updatePhoneNumber(any()));
  });

  test('signed out answers unknown', () async {
    when(() => auth.currentUser).thenReturn(null);
    await expectLater(
      verifier.confirmCode(
        const PhoneCodeRequest(phone: '+84903123456', verificationId: 'v'),
        '123456',
      ),
      throwsA(_verifyError(PhoneVerifyErrorCode.unknown)),
    );
  });

  group('FakePhoneVerifier', () {
    test('sends, confirms the right code and records', () async {
      final fake = FakePhoneVerifier();
      final r = await fake.sendCode('+84903123456');
      expect(r.phone, '+84903123456');
      await fake.confirmCode(r, FakePhoneVerifier.validCode);
      expect(fake.sent, ['+84903123456']);
      expect(fake.linked, ['+84903123456']);
      await expectLater(
        fake.confirmCode(r, '000000'),
        throwsA(_verifyError(PhoneVerifyErrorCode.invalidCode)),
      );
    });

    test('sendError and confirmError fail the next calls', () async {
      final fake = FakePhoneVerifier()
        ..sendError = PhoneVerifyErrorCode.tooManyRequests;
      await expectLater(
        fake.sendCode('+84903123456'),
        throwsA(_verifyError(PhoneVerifyErrorCode.tooManyRequests)),
      );
      fake
        ..sendError = null
        ..confirmError = PhoneVerifyErrorCode.alreadyInUse;
      final r = await fake.sendCode('+84903123456');
      await expectLater(
        fake.confirmCode(r, FakePhoneVerifier.validCode),
        throwsA(_verifyError(PhoneVerifyErrorCode.alreadyInUse)),
      );
    });
  });
}
