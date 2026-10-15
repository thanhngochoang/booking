import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/verification/firebase_phone_verifier.dart';
import 'package:photobooking/data/verification/firestore_verification_repository.dart';
import 'package:photobooking/data/verification/phone_verifier.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_repository.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => FirestoreVerificationRepository(),
);

final phoneVerifierProvider = Provider<PhoneVerifier>(
  (ref) => FirebasePhoneVerifier(),
);

/// A real identity vendor is wired (`--dart-define=REAL_IDENTITY=true`); while
/// false the app shows the fake VNeID / NFC sheets (Decision 6).
final identityModeRealProvider = Provider<bool>(
  (_) => const bool.fromEnvironment('REAL_IDENTITY'),
);

/// Whether the verification fee is a required step (Decision 24). Mirrors the
/// server's `VerificationDeps.feeRequired`; #203 flips both to true together.
final verificationFeeRequiredProvider = Provider<bool>((_) => false);

/// The signed-in provider's verification: `verifications/{uid}` read with the
/// contact's `phoneVerified` flag and the kind of the own provider type. A
/// missing document is `VerificationState.initial(kind)`.
final myVerificationProvider = StreamProvider.autoDispose<VerificationState>((
  ref,
) async* {
  final feeRequired = ref.watch(verificationFeeRequiredProvider);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield VerificationState.initial(
      VerificationKind.individual,
      feeRequired: feeRequired,
    );
    return;
  }
  final contact = await ref.watch(currentContactProvider.future);
  final intro = await ref.watch(myIntroProvider.future);
  final kind = verificationKindOf(
    intro?.providerType ?? ProviderType.individual,
  );
  final now = ref.watch(clockProvider);
  yield* ref
      .watch(verificationRepositoryProvider)
      .watchRaw(user.uid)
      .map(
        (d) => verificationFromFirestore(
          d,
          phoneVerified: contact?.phoneVerified ?? false,
          kind: kind,
          feeRequired: feeRequired,
          now: now(),
        ),
      );
});
