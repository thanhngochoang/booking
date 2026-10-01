import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/photographer/photographer_contact.dart';

abstract class PhotographerContactRepository {
  /// Public flags of any photographer (null until set up).
  Stream<ContactChannels?> watchChannels(String photographerId);

  /// The owner's private numbers; other users are refused by the rules.
  Stream<ContactNumbers?> watchNumbers(String photographerId);

  Stream<ServiceArea?> watchServiceArea(String photographerId);

  /// S34 "Hoàn tất": writes the service area and public flags to
  /// `photographers/{uid}`, the numbers to `photographers/{uid}/private/contact`
  /// (one batch, so a channel is never public without a number) and sets
  /// `onboardingComplete`.
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  });
}

class FirestorePhotographerContactRepository
    implements PhotographerContactRepository {
  FirestorePhotographerContactRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  DocumentReference<Map<String, dynamic>> _private(String uid) =>
      _doc(uid).collection('private').doc('contact');

  @override
  Stream<ContactChannels?> watchChannels(String photographerId) =>
      _doc(photographerId)
          .snapshots()
          .map((s) => ContactChannels.fromMap(s.data()?['contactChannels']));

  @override
  Stream<ContactNumbers?> watchNumbers(String photographerId) =>
      _private(photographerId)
          .snapshots()
          .map((s) => ContactNumbers.fromMap(s.data()));

  @override
  Stream<ServiceArea?> watchServiceArea(String photographerId) =>
      _doc(photographerId)
          .snapshots()
          .map((s) => ServiceArea.fromMap(s.data()?['serviceArea']));

  @override
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) {
    final batch = _db.batch();
    // Replaces the whole private doc so a cleared own number really goes away.
    batch.set(_private(uid), {
      ...numbers.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_doc(uid), {
      'serviceArea': area.toMap(),
      'contactChannels': channels.toMap(),
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }
}

class FakePhotographerContactRepository
    implements PhotographerContactRepository {
  FakePhotographerContactRepository({this.failSave = false});
  final bool failSave;

  final _channels = <String, ContactChannels>{};
  final _numbers = <String, ContactNumbers>{};
  final _areas = <String, ServiceArea>{};

  /// Uids whose onboarding was completed through [completeContactSetup].
  final completed = <String>{};
  final _changes = StreamController<String>.broadcast();

  /// Open watch subscriptions, so tests can prove screens stop listening.
  int watchers = 0;

  ContactChannels? channelsOf(String uid) => _channels[uid];
  ContactNumbers? numbersOf(String uid) => _numbers[uid];
  ServiceArea? areaOf(String uid) => _areas[uid];

  /// Test setup without going through [completeContactSetup].
  void seed(
    String uid, {
    ContactChannels? channels,
    ContactNumbers? numbers,
    ServiceArea? area,
  }) {
    if (channels != null) _channels[uid] = channels;
    if (numbers != null) _numbers[uid] = numbers;
    if (area != null) _areas[uid] = area;
    _changes.add(uid);
  }

  Stream<T> _watch<T>(String uid, T Function() read) {
    late final StreamController<T> out;
    StreamSubscription<String>? inner;
    out = StreamController<T>(
      onListen: () {
        watchers++;
        out.add(read());
        inner = _changes.stream.where((u) => u == uid).listen((_) {
          out.add(read());
        });
      },
      // Not awaited: `Stream.first` waits for this future, and a broadcast
      // subscription's cancel only completes on the real event loop, which
      // would leave `first` hanging under a widget test's fake clock.
      onCancel: () {
        watchers--;
        unawaited(inner?.cancel());
      },
    );
    return out.stream;
  }

  @override
  Stream<ContactChannels?> watchChannels(String photographerId) =>
      _watch(photographerId, () => _channels[photographerId]);

  @override
  Stream<ContactNumbers?> watchNumbers(String photographerId) =>
      _watch(photographerId, () => _numbers[photographerId]);

  @override
  Stream<ServiceArea?> watchServiceArea(String photographerId) =>
      _watch(photographerId, () => _areas[photographerId]);

  @override
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) async {
    if (failSave) throw StateError('unavailable');
    _areas[uid] = area;
    _channels[uid] = channels;
    _numbers[uid] = numbers;
    completed.add(uid);
    _changes.add(uid);
  }
}
