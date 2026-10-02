import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in user's private contact details. Lives apart from the public
/// users/{uid} profile; only the owner can read or write it.
class UserContact {
  const UserContact({
    required this.phone,
    this.phoneVerified = false,
    this.allowZalo = true,
    this.allowWhatsApp = false,
  });

  /// E.164, e.g. `+84903123456`.
  final String phone;

  /// Always false until phone verification exists; the client never sets it.
  final bool phoneVerified;
  final bool allowZalo;
  final bool allowWhatsApp;

  UserContact copyWith({
    String? phone,
    bool? phoneVerified,
    bool? allowZalo,
    bool? allowWhatsApp,
  }) => UserContact(
    phone: phone ?? this.phone,
    phoneVerified: phoneVerified ?? this.phoneVerified,
    allowZalo: allowZalo ?? this.allowZalo,
    allowWhatsApp: allowWhatsApp ?? this.allowWhatsApp,
  );

  @override
  bool operator ==(Object other) =>
      other is UserContact &&
      other.phone == phone &&
      other.phoneVerified == phoneVerified &&
      other.allowZalo == allowZalo &&
      other.allowWhatsApp == allowWhatsApp;

  @override
  int get hashCode =>
      Object.hash(phone, phoneVerified, allowZalo, allowWhatsApp);
}

/// Fields a client writes. `phoneVerified` is deliberately absent: only the
/// repository resets it (to false) and only a server process may set it true.
Map<String, dynamic> contactToFirestore(UserContact c) => {
  'phone': c.phone,
  'allowZalo': c.allowZalo,
  'allowWhatsApp': c.allowWhatsApp,
};

abstract class UserContactRepository {
  Stream<UserContact?> watch(String uid);

  /// Creates or updates the contact. A changed number is marked unverified.
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  });
}

class FirestoreUserContactRepository implements UserContactRepository {
  FirestoreUserContactRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('contact');

  @override
  Stream<UserContact?> watch(String uid) => _doc(uid).snapshots().map((s) {
    final d = s.data();
    if (d == null || d['phone'] is! String) return null;
    return UserContact(
      phone: d['phone'] as String,
      phoneVerified: d['phoneVerified'] == true,
      allowZalo: d['allowZalo'] != false,
      allowWhatsApp: d['allowWhatsApp'] == true,
    );
  });

  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    final ref = _doc(uid);
    final before = (await ref.get()).data();
    final changed = before == null || before['phone'] != phone;
    await ref.set({
      ...contactToFirestore(
        UserContact(
          phone: phone,
          allowZalo: allowZalo,
          allowWhatsApp: allowWhatsApp,
        ),
      ),
      if (changed) 'phoneVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FakeUserContactRepository implements UserContactRepository {
  FakeUserContactRepository({this.failSave = false});
  final bool failSave;
  final _contacts = <String, UserContact>{};
  final _controllers = <String, StreamController<UserContact?>>{};

  StreamController<UserContact?> _c(String uid) => _controllers.putIfAbsent(
    uid,
    () => StreamController<UserContact?>.broadcast(),
  );

  UserContact? stored(String uid) => _contacts[uid];

  /// Test setup without going through [save].
  void seed(String uid, UserContact contact) => _contacts[uid] = contact;

  /// Open [watch] subscriptions, so tests can prove screens stop listening.
  int watchers = 0;

  @override
  Stream<UserContact?> watch(String uid) {
    late final StreamController<UserContact?> out;
    StreamSubscription<UserContact?>? inner;
    out = StreamController<UserContact?>(
      onListen: () {
        watchers++;
        out.add(_contacts[uid]);
        inner = _c(uid).stream.listen(out.add);
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    if (failSave) throw StateError('unavailable');
    final before = _contacts[uid];
    final next = UserContact(
      phone: phone,
      phoneVerified:
          before != null && before.phone == phone && before.phoneVerified,
      allowZalo: allowZalo,
      allowWhatsApp: allowWhatsApp,
    );
    _contacts[uid] = next;
    _c(uid).add(next);
  }
}
