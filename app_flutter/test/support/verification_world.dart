// test/support/verification_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/verification/phone_verifier.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';
import 'package:photobooking/features/verification/verify_business_screen.dart';
import 'package:photobooking/features/verification/verify_identity_screen.dart';
import 'package:photobooking/features/verification/verify_phone_screen.dart';
import 'package:photobooking/features/verification/verify_rules_screen.dart';
import 'package:photobooking/features/verification/verify_start_screen.dart';

import 'screen_host.dart';

/// Wednesday 15/10/2026 9:40 in Vietnam.
final verificationNow = DateTime.utc(2026, 10, 15, 2, 40);

/// The support address the S21.02 tests pass in (the build has none).
const verificationSupport = 'hotro@photobooking.vn';

/// A signed-in provider with in-memory contact, phone verifier, verification
/// and intro repositories and a fixed clock ([verificationNow]). S21.01 is
/// mounted at `/verify/phone`, S21.02 at `/verify/start` (rules at
/// `/verify/start/rules`), S21.03 at `/verify/identity` and S21.04 at
/// `/verify/business` when [startScreen] is true (stubs otherwise);
/// `/settings/profile`, `/u/:uid` and the profile tab are stubs. [log]
/// records, in order, the phone linked (`link:+84…`), the contact saved
/// (`save:+84…`) and `confirmPhoneVerified`.
class VerificationWorld {
  VerificationWorld({
    this.feeRequired = false,
    this.startScreen = false,
    this.identityReal = false,
  });

  /// Mirrors `identityModeRealProvider`: false shows the fake VNeID sheet.
  final bool identityReal;

  /// Mirrors `verificationFeeRequiredProvider` (false in #135: 3 steps).
  final bool feeRequired;

  /// Mounts the real S21.02 screens instead of a `/verify/start` stub.
  final bool startScreen;

  late String uid;
  final auth = FakeAuthRepository();
  final log = <String>[];
  late final contacts = _LoggingContacts(log);
  late final verifier = _LoggingVerifier(log);
  late final repo = _LoggingVerificationRepository(log, uid: uid);
  final intros = FakePhotographerIntroRepository();
  final launcher = FakeExternalLauncher();
  final uploader = FakeMediaUploader();

  /// The gallery answers, in order (S21.04's registration photo).
  FakeImagePicker picker = FakeImagePicker([
    const [PickedImage(path: '/tmp/gpkd.jpg', name: 'gpkd.jpg')],
  ]);
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

  /// Seeds `verifications/{uid}`; [phoneVerified] is the contact flag both
  /// the app and the fake server read (Decision 3).
  void seedDoc(Map<String, dynamic>? doc, {bool phoneVerified = true}) {
    repo.phoneVerified = phoneVerified;
    repo.seed(uid, doc);
    if (phoneVerified) {
      seedContact('+84912343456', verified: true);
    }
  }

  /// Seeds the own `photographers/{uid}` intro.
  void seedIntro(PhotographerIntro intro) => intros.seed(uid, intro);

  List<Override> get overrides => [
    clockProvider.overrideWithValue(() => verificationNow),
    photographerIntroRepositoryProvider.overrideWithValue(intros),
    externalLauncherProvider.overrideWithValue(launcher),
    authRepositoryProvider.overrideWithValue(auth),
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    userContactRepositoryProvider.overrideWithValue(contacts),
    phoneVerifierProvider.overrideWithValue(verifier),
    verificationRepositoryProvider.overrideWithValue(repo),
    verificationFeeRequiredProvider.overrideWithValue(feeRequired),
    identityModeRealProvider.overrideWithValue(identityReal),
    mediaUploaderProvider.overrideWithValue(uploader),
    imagePickerProvider.overrideWithValue(picker),
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
        if (startScreen)
          GoRoute(
            path: '/verify/start',
            builder: (_, _) =>
                const VerifyStartScreen(supportAddress: verificationSupport),
            routes: [
              GoRoute(
                path: 'rules',
                builder: (_, _) => const VerifyRulesScreen(),
              ),
            ],
          )
        else
          GoRoute(path: '/verify/start', builder: stub),
        if (startScreen) ...[
          GoRoute(
            path: '/verify/identity',
            builder: (_, s) => VerifyIdentityScreen(
              method: s.uri.queryParameters['method'] == 'nfc'
                  ? IdentityMethod.nfc
                  : IdentityMethod.vneid,
            ),
          ),
          GoRoute(
            path: '/verify/business',
            builder: (_, _) => const VerifyBusinessScreen(),
          ),
        ] else ...[
          GoRoute(path: '/verify/identity', builder: stub),
          GoRoute(path: '/verify/business', builder: stub),
        ],
        GoRoute(path: '/settings/profile', builder: stub),
        GoRoute(path: '/u/:uid', builder: stub),
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
  _LoggingVerificationRepository(this.log, {required super.uid})
    : super(now: () => verificationNow);
  final List<String> log;

  /// When set, `completeIdentityVerification` refuses with this code (after
  /// recording the call), as the server does for `underage`,
  /// `identity_in_use`, `not_eligible`…
  String? completeFailWith;

  /// When set, `lookupTaxCode` refuses with this code.
  String? lookupFailWith;

  @override
  Future<String> completeIdentity(String sessionId) async {
    final code = completeFailWith;
    if (code != null) {
      calls.add((
        name: 'completeIdentityVerification',
        data: {'sessionId': sessionId},
      ));
      throw VerificationError(code);
    }
    return super.completeIdentity(sessionId);
  }

  @override
  Future<TaxCodeInfo> lookupTaxCode(String taxCode) async {
    final code = lookupFailWith;
    if (code != null) {
      calls.add((name: 'lookupTaxCode', data: {'taxCode': taxCode}));
      throw VerificationError(code);
    }
    return super.lookupTaxCode(taxCode);
  }

  @override
  Future<void> confirmPhoneVerified() async {
    await super.confirmPhoneVerified();
    log.add('confirm');
  }
}
