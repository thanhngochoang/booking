// lib/data/events/firestore_event_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/firestore_event_mapping.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Reads `events` (and `registrations`) directly; every write is a callable.
class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({
    required this.uid,
    required this.uploader,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  /// The signed-in user; null while signed out (own-data streams are empty).
  final String? uid;
  final MediaUploader uploader;
  final FirebaseFirestore? _override;
  final FirebaseFunctions _functions;

  /// Cover URL → storage path, so [saveDraft] can send `coverPath`.
  final Map<String, String> _coverPaths = {};

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  static const _publicStatuses = ['open', 'full'];

  // ---- reads --------------------------------------------------------------

  @override
  Future<EventPage> list({
    EventType? type,
    bool freeOnly = false,
    required DateTime from,
    String? cursor,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _events.where(
      'status',
      whereIn: _publicStatuses,
    );
    if (type != null) {
      q = q.where('type', isEqualTo: type.code);
    }
    if (freeOnly) {
      q = q.where('price', isEqualTo: 0);
    }
    q = q
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('startAt');
    if (cursor != null) {
      // The cursor is the last id of the previous page; starting after its
      // document keeps events that share a start time from being skipped.
      final last = _validId(cursor) ? await _events.doc(cursor).get() : null;
      if (last == null || !last.exists) {
        return const EventPage(events: []);
      }
      q = q.startAfterDocument(last);
    }
    // One extra row says whether another page exists.
    final snap = await q.limit(limit + 1).get();
    final rows = [
      for (final d in snap.docs) ?eventSummaryFromFirestore(d.id, d.data()),
    ];
    final page = rows.take(limit).toList();
    return EventPage(
      events: page,
      nextCursor: rows.length > limit && page.isNotEmpty ? page.last.id : null,
    );
  }

  @override
  Stream<EventDetail?> watchEvent(String eventId) {
    if (!_validId(eventId)) {
      return Stream.value(null);
    }
    return _orIfDenied<EventDetail?>(
      _events
          .doc(eventId)
          .snapshots()
          .map((s) => eventDetailFromFirestore(s.id, s.data())),
      null,
    );
  }

  @override
  Stream<List<EventSummary>> watchMine() {
    final me = uid;
    if (me == null) {
      return Stream.value(const []);
    }
    // No orderBy: a draft saved before it has a date has no startAt and would
    // drop out of an ordered query. Sorted here, undated drafts first.
    return _events.where('createdBy', isEqualTo: me).snapshots().map((qs) {
      final out = [
        for (final d in qs.docs) ?eventSummaryFromFirestore(d.id, d.data()),
      ];
      out.sort((a, b) {
        if (a.hasSchedule != b.hasSchedule) {
          return a.hasSchedule ? 1 : -1;
        }
        return b.startsAt.compareTo(a.startsAt);
      });
      return out;
    });
  }

  @override
  Stream<List<EventDetail>> watchHostInvitations() {
    final me = uid;
    if (me == null) {
      return Stream.value(const []);
    }
    return _events
        .where('hostId', isEqualTo: me)
        .where('status', isEqualTo: 'draft')
        .snapshots()
        .map((qs) {
          final out = [
            for (final d in qs.docs)
              if (eventDetailFromFirestore(d.id, d.data()) case final e?)
                if (e.hostConsent == HostConsent.pending) e,
          ];
          out.sort(
            (a, b) => (a.hostConsentExpiresAt ?? a.summary.createdAt).compareTo(
              b.hostConsentExpiresAt ?? b.summary.createdAt,
            ),
          );
          return out;
        });
  }

  /// A read the rules refuse (a draft or contact the viewer may not see)
  /// is "nothing there", not a failed stream.
  Stream<T> _orIfDenied<T>(Stream<T> source, T fallback) => source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (error, stack, sink) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          sink.add(fallback);
        } else {
          sink.addError(error, stack);
        }
      },
    ),
  );

  CollectionReference<Map<String, dynamic>> _registrations(String eventId) =>
      _events.doc(eventId).collection('registrations');

  static List<EventRegistration> _parseRegistrations(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = [
      for (final d in docs) ?registrationFromFirestore(d.id, d.data()),
    ];
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Stream<EventRegistration?> watchMyRegistration(String eventId) {
    final me = uid;
    if (me == null || !_validId(eventId)) {
      return Stream.value(null);
    }
    return _registrations(eventId)
        .where('userId', isEqualTo: me)
        .snapshots()
        .map((qs) {
          final mine = _parseRegistrations(qs.docs);
          for (final r in mine) {
            if (r.isActive) {
              return r;
            }
          }
          return mine.isEmpty ? null : mine.first;
        });
  }

  @override
  Stream<List<EventRegistration>> watchMyTickets() {
    final me = uid;
    if (me == null) {
      return Stream.value(const []);
    }
    return _db
        .collectionGroup('registrations')
        .where('userId', isEqualTo: me)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => _parseRegistrations(qs.docs));
  }

  @override
  Stream<List<EventRegistration>> watchRegistrations(String eventId) {
    if (!_validId(eventId)) {
      return Stream.value(const []);
    }
    return _orIfDenied<List<EventRegistration>>(
      _registrations(eventId)
          .snapshots()
          .map((qs) => _parseRegistrations(qs.docs)),
      const [],
    );
  }

  @override
  Stream<BookingContactSnapshot?> watchRegistrationContact(
    String eventId,
    String registrationId,
  ) {
    if (!_validId(eventId) || !_validId(registrationId)) {
      return Stream.value(null);
    }
    final regRef = _registrations(eventId).doc(registrationId);
    return _orIfDenied<BookingContactSnapshot?>(
      regRef.collection('private').doc('contact').snapshots().asyncMap((
        snap,
      ) async {
        final contact = bookingContactFromFirestore(snap.data());
        if (contact == null) {
          return null;
        }
        // The server never writes a phone for a free ticket, and the rules deny
        // the host one; check the registration too so a stray document can never
        // surface a phone for a ticket that does not unlock contact (O3).
        try {
          final reg = registrationFromFirestore(
            registrationId,
            (await regRef.get()).data(),
          );
          if (reg == null ||
              reg.status != RegistrationStatus.paid ||
              !reg.contactEligible) {
            return null;
          }
        } on FirebaseException {
          return null;
        }
        return contact;
      }),
      null,
    );
  }

  // ---- callables ----------------------------------------------------------

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        throw EventError(details['code'] as String);
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const EventError('network');
      }
      throw EventError(e.message ?? e.code);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    throw const EventError('internal');
  }

  @override
  Future<({String eventId, String hashtag})> saveDraft(EventDraft draft) async {
    final payload = draft.toCallable();
    final url = draft.coverUrl;
    if (url != null && draft.coverPath == null) {
      final path = _coverPaths[url];
      if (path != null) {
        payload['coverPath'] = path;
      }
    }
    final data = _asMap(await _call('saveEventDraft', payload));
    final id = data['eventId'];
    final tag = data['hashtag'];
    if (id is! String || tag is! String) {
      throw const EventError('internal');
    }
    return (eventId: id, hashtag: tag);
  }

  @override
  Future<void> publish(String eventId) async {
    await _call('publishEvent', {'eventId': eventId});
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    await _call('cancelEvent', {'eventId': eventId});
  }

  @override
  Future<void> respondToHostConsent(
    String eventId, {
    required bool accept,
  }) async {
    await _call('respondToHostConsent', {'eventId': eventId, 'accept': accept});
  }

  @override
  Future<RegisterOutcome> register(
    String eventId, {
    required int quantity,
    required String name,
    PaymentProviderCode? provider,
  }) async {
    final data = _asMap(
      await _call('registerEvent', {
        'eventId': eventId,
        'quantity': quantity,
        'name': name,
        'provider': ?provider?.code,
      }),
    );
    final id = data['registrationId'];
    if (id is! String) {
      throw const EventError('internal');
    }
    final hold = data['holdExpiresAt'];
    return RegisterOutcome(
      registrationId: id,
      status: RegistrationStatus.fromCode(data['status'] as String?),
      paymentId: data['paymentId'] as String?,
      payUrl: data['payUrl'] as String?,
      holdExpiresAt: hold is String ? DateTime.tryParse(hold)?.toUtc() : null,
    );
  }

  @override
  Future<({RegistrationStatus status, int? refundPercent})> cancelRegistration(
    String eventId,
    String registrationId,
  ) async {
    final data = _asMap(
      await _call('cancelRegistration', {
        'eventId': eventId,
        'registrationId': registrationId,
      }),
    );
    final percent = data['refundPercent'];
    return (
      status: RegistrationStatus.fromCode(data['status'] as String?),
      refundPercent: percent is num ? percent.toInt() : null,
    );
  }

  @override
  Future<({String name, int quantity})> checkIn(
    String eventId,
    String ticketCode,
  ) async {
    final data = _asMap(
      await _call('checkInRegistration', {
        'eventId': eventId,
        'ticketCode': ticketCode,
      }),
    );
    final name = data['name'];
    final quantity = data['quantity'];
    if (name is! String || quantity is! num) {
      throw const EventError('internal');
    }
    return (name: name, quantity: quantity.toInt());
  }

  @override
  Future<String> uploadCover(String eventId, PickedImage image) async {
    final me = uid;
    if (me == null) {
      throw const EventError('permission_denied');
    }
    final path = 'eventCovers/$me/$eventId/${newUlid()}.jpg';
    UploadedMedia? done;
    await for (final e in uploader.upload(image, storagePath: path)) {
      if (e.isDone) {
        done = e.media;
      }
    }
    if (done == null) {
      throw const EventError('network');
    }
    _coverPaths[done.url] = done.storagePath;
    return done.url;
  }

  @override
  String? coverPathOf(String url) => _coverPaths[url];

  @override
  Future<void> deleteCover(String path) async {
    try {
      await uploader.delete(path);
    } catch (_) {
      // An object we could not delete stays behind; nothing depends on it.
    }
  }
}

bool _validId(String id) => id.isNotEmpty && !id.contains('/');
