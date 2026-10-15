// test/data/contracts/firestore_contracts_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';

import 'photographer_contact_contract.dart';
import 'user_contact_contract.dart';
import 'user_repository_contract.dart';

/// The Firebase adapters against an in-memory Firestore. Rules are tested
/// separately (firebase/rules-test); this checks the adapters' behaviour.
/// ContactLinkRepository's Firebase adapter (a callable) runs in phase 1's
/// emulator tests.
void main() {
  userRepositoryContract(
    'Firestore',
    () async =>
        (repo: FirestoreUserRepository(db: FakeFirebaseFirestore()), uid: 'u1'),
  );
  userContactRepositoryContract(
    'Firestore',
    () async => (
      repo: FirestoreUserContactRepository(db: FakeFirebaseFirestore()),
      uid: 'u1',
    ),
  );
  photographerContactRepositoryContract(
    'Firestore',
    () async => (
      repo: FirestorePhotographerContactRepository(db: FakeFirebaseFirestore()),
      uid: 'p1',
    ),
  );
}
