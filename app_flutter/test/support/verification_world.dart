// test/support/verification_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/verification/phone_verifier.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';
import 'package:photobooking/features/verification/verify_phone_screen.dart';

import 'screen_host.dart';

/// A signed-in provider with in-memory contact, phone verifier and
/// verification repository, S21.01 mounted at `/verify/phone`; `/verify/start`
/// and the profile tab are stubs. [log] records, in order, the phone linked
/// (`link:+84…`), the contact saved (`save:+84…`) and `confirmPhoneVerified`.
class VerificationWorld {
  VerificationWorld({this.feeRequired = false});

  /// Mirrors `verificationFeeRequiredProvider` (false in #135: 3 steps).
  final bool feeRequired;

  late String uid;
  final auth = FakeAuthRepository();
  final log = <String>[];
  late final contacts = _LoggingContacts(log);
  late final verifier = _LoggingVerifier(log);
  late final repo = _LoggingVerificationRepository(log, uid: uid);
  late GoRouter router;

  /// Registers the signed-in provider; call before [app].
  Future<void> init() async {
    final u = await auth.registerWithEmail('tri@b.vn', 'password1', 'Minh Trí');
    uid = u.uid;
  }

  /// Seeds the private contact (E.164 [phone]).
  void seedContact(
    String phone, {
    bool verified = false,
    bool allowZalo = true,
    bool allowWhatsApp = false,
  }) => contacts.seed(
    uid,
    UserContact(
      phone: phone,
      phoneVerified: verified,
      allowZalo: allowZalo,
      allowWhatsApp: allowWhatsApp,
    ),
  );

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    userContactRepositoryProvider.overrideWithValue(contacts),
    phoneVerifierProvider.overrideWithValue(verifier),
    verificationRepositoryProvider.overrideWithValue(repo),
    verificationFeeRequiredProvider.overrideWithValue(feeRequired),
  ];

  Widget app({String location = '/verify/phone', double textScale = 1.0}) {
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/verify/phone',
          builder: (_, s) =>
              VerifyPhoneScreen(returnTo: s.uri.queryParameters['returnTo']),
        ),
        GoRoute(path: '/verify/start', builder: stub),
        GoRoute(path: '/profile', builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      textScale: textScale,
    );
  }
}

class _LoggingContacts extends FakeUserContactRepository {
  _LoggingContacts(this.log);
  final List<String> log;

  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) {
    log.add('save:$phone');
    return super.save(
      uid,
      phone: phone,
      allowZalo: allowZalo,
      allowWhatsApp: allowWhatsApp,
    );
  }
}

class _LoggingVerifier extends FakePhoneVerifier {
  _LoggingVerifier(this.log);
  final List<String> log;

  @override
  Future<void> confirmCode(PhoneCodeRequest request, String smsCode) async {
    await super.confirmCode(request, smsCode);
    log.add('link:${request.phone}');
  }
}

class _LoggingVerificationRepository extends FakeVerificationRepository {
  _LoggingVerificationRepository(this.log, {required super.uid});
  final List<String> log;

  @override
  Future<void> confirmPhoneVerified() async {
    await super.confirmPhoneVerified();
    log.add('confirm');
  }
}
