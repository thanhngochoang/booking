// lib/data/events/event_repository.dart
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';

/// A refused or failed event call. [code] is the domain code the callable sent
/// in `details.code`: `sold_out`, `deadline_passed`, `phone_required`,
/// `day_taken`, `conflict`, `not_eligible`, `limit_exceeded`, `not_found`,
/// `permission_denied`, `invalid_argument`, or `network` / `unknown`.
class EventError implements Exception {
  const EventError(this.code);
  final String code;

  @override
  String toString() => 'EventError($code)';
}

/// The error code of anything thrown by a repository call, for screens.
String eventErrorCodeOf(Object error) {
  if (error is EventError) {
    return error.code;
  }
  if (error is SocketException) {
    return 'network';
  }
  return 'unknown';
}

/// One page of the public list (S11.01).
class EventPage {
  const EventPage({required this.events, this.nextCursor});

  final List<EventSummary> events;

  /// Pass back to [EventRepository.list] for the next page; null at the end.
  final String? nextCursor;
}

class RegisterOutcome {
  const RegisterOutcome({
    required this.registrationId,
    required this.status,
    this.paymentId,
    this.instructions,
    this.holdExpiresAt,
  });

  final String registrationId;
  final RegistrationStatus status;
  final String? paymentId;
  final PaymentInstructions? instructions;
  final DateTime? holdExpiresAt;
}

abstract class EventRepository {
  /// Public events (`open` / `full`) starting at or after [from], soonest
  /// first. [freeOnly] keeps price 0.
  Future<EventPage> list({
    EventType? type,
    bool freeOnly = false,
    required DateTime from,
    String? cursor,
    int limit = 20,
  });

  /// Null when the event does not exist or the viewer may not read it.
  Stream<EventDetail?> watchEvent(String eventId);

  /// Events I created or host (a staff-made event naming me, O1), drafts
  /// included, latest start first (drafts without a date first). A draft
  /// still waiting for my answer as host is an invitation, not listed here.
  Stream<List<EventSummary>> watchMine();

  /// Drafts staff created naming me as host that wait for my answer (owner
  /// decision O1), soonest expiry first.
  Stream<List<EventDetail>> watchHostInvitations();

  /// My active (`held` / `paid`) registration for the event, else my latest.
  Stream<EventRegistration?> watchMyRegistration(String eventId);

  /// All my registrations, newest first (S05.01 "Vé sự kiện").
  Stream<List<EventRegistration>> watchMyTickets();

  /// Every registration of an event (managers), newest first.
  Stream<List<EventRegistration>> watchRegistrations(String eventId);

  /// The attendee's phone snapshot for a manager. Null unless the ticket is
  /// paid and contact-eligible: a free ticket never exposes a phone (O3).
  Stream<BookingContactSnapshot?> watchRegistrationContact(
    String eventId,
    String registrationId,
  );

  Future<({String eventId, String hashtag})> saveDraft(EventDraft draft);

  Future<void> publish(String eventId);

  Future<void> cancelEvent(String eventId);

  /// The invited photographer answers a staff-created draft (O1).
  Future<void> respondToHostConsent(String eventId, {required bool accept});

  Future<RegisterOutcome> register(
    String eventId, {
    required int quantity,
    required String name,
    PayMethod? method,
  });

  Future<({RegistrationStatus status, int? refundPercent})> cancelRegistration(
    String eventId,
    String registrationId,
  );

  /// Asks the gateway about a held ticket's payment and applies it if paid.
  Future<({bool paid, RegistrationStatus status})> checkTicketPayment(
    String eventId,
    String registrationId,
  );

  Future<({String name, int quantity})> checkIn(
    String eventId,
    String ticketCode,
  );

  /// Uploads [image] to `eventCovers/{uid}/{eventId}/{ulid}.jpg` and returns
  /// its download URL. The path is remembered: [saveDraft] sends it as
  /// `coverPath` for a draft that carries the returned URL.
  Future<String> uploadCover(String eventId, PickedImage image);

  /// The storage path [uploadCover] gave [url], or null for a URL it did not
  /// make (a cover saved in an earlier session: its path is on the draft).
  String? coverPathOf(String url);

  /// Removes a cover file that no saved draft points at any more. Best effort:
  /// a failure leaves an orphan file and is not reported.
  Future<void> deleteCover(String path);
}

/// In-memory repository for tests and previews. Enforces what the server does:
/// seats, one active registration per user, a phone before registering.
class FakeEventRepository implements EventRepository {
  FakeEventRepository({
    this.uid = 'u1',
    List<EventDetail> events = const [],
    List<EventRegistration> registrations = const [],
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()) {
    for (final e in events) {
      _events[e.id] = e;
    }
    _registrations.addAll(registrations);
  }

  /// The signed-in user.
  String? uid;

  /// Without a phone on file `register` answers `phone_required`.
  bool hasPhone = true;

  /// Set while the next call should fail (every call throws it, then clears
  /// when [failOnce] is true).
  Object? failWith;
  bool failOnce = false;

  final DateTime Function() _clock;
  final Map<String, EventDetail> _events = {};
  final List<EventRegistration> _registrations = [];
  final List<EventDraft> savedDrafts = [];
  final List<String> published = [];
  final List<String> cancelledEvents = [];
  final List<({String eventId, bool accept})> consentAnswers = [];
  final List<String> checkedIn = [];
  final Map<String, String> coverPaths = {};
  final _changes = StreamController<void>.broadcast();
  int _seq = 0;

  /// Contact snapshots a manager may read, by `eventId/registrationId`.
  final Map<String, BookingContactSnapshot> contacts = {};

  void putEvent(EventDetail e) {
    _events[e.id] = e;
    _changes.add(null);
  }

  void putRegistration(EventRegistration r) {
    _registrations
      ..removeWhere((x) => x.id == r.id)
      ..add(r);
    _changes.add(null);
  }

  EventDetail? event(String id) => _events[id];
  List<EventRegistration> get registrations =>
      List.unmodifiable(_registrations);

  void _maybeFail() {
    final e = failWith;
    if (e != null) {
      if (failOnce) {
        failWith = null;
      }
      throw e;
    }
  }

  void maybeFailForTest() => _maybeFail();

  /// The current value now, then again after every change. A plain controller
  /// (not `async*`) so a cancel completes at once.
  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        changes = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<EventPage> list({
    EventType? type,
    bool freeOnly = false,
    required DateTime from,
    String? cursor,
    int limit = 20,
  }) async {
    _maybeFail();
    final all =
        _events.values
            .map((d) => d.summary)
            .where(
              (e) =>
                  (e.status == EventStatus.open ||
                      e.status == EventStatus.full) &&
                  !e.startsAt.isBefore(from) &&
                  (type == null || e.type == type) &&
                  (!freeOnly || e.isFree),
            )
            .toList()
          ..sort((a, b) {
            final c = a.startsAt.compareTo(b.startsAt);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
    final start = cursor == null
        ? 0
        : all.indexWhere((e) => e.id == cursor) + 1;
    final page = all.skip(start).take(limit).toList();
    final more = start + page.length < all.length;
    return EventPage(
      events: page,
      nextCursor: more && page.isNotEmpty ? page.last.id : null,
    );
  }

  @override
  Stream<EventDetail?> watchEvent(String eventId) =>
      _watch(() => _events[eventId]);

  @override
  Stream<List<EventSummary>> watchMine() => _watch(() {
    final mine =
        _events.values
            .where(
              (e) =>
                  e.createdBy == uid ||
                  (e.summary.hostId == uid && !_awaitsMyAnswer(e)),
            )
            .map((e) => e.summary)
            .toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return mine;
  });

  /// A staff-made draft naming me that I have not answered (or declined).
  bool _awaitsMyAnswer(EventDetail e) =>
      e.createdBy != uid &&
      e.summary.status == EventStatus.draft &&
      e.hostConsent != HostConsent.accepted;

  @override
  Stream<List<EventDetail>> watchHostInvitations() => _watch(() {
    final out =
        _events.values
            .where(
              (e) =>
                  e.summary.hostId == uid &&
                  e.summary.status == EventStatus.draft &&
                  e.hostConsent == HostConsent.pending,
            )
            .toList()
          ..sort(
            (a, b) => (a.hostConsentExpiresAt ?? a.summary.createdAt).compareTo(
              b.hostConsentExpiresAt ?? b.summary.createdAt,
            ),
          );
    return out;
  });

  EventRegistration? _mineFor(String eventId) {
    final mine =
        _registrations
            .where((r) => r.eventId == eventId && r.userId == uid)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final r in mine) {
      if (r.isActive) {
        return r;
      }
    }
    return mine.isEmpty ? null : mine.first;
  }

  @override
  Stream<EventRegistration?> watchMyRegistration(String eventId) =>
      _watch(() => _mineFor(eventId));

  @override
  Stream<List<EventRegistration>> watchMyTickets() => _watch(() {
    final mine = _registrations.where((r) => r.userId == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  });

  @override
  Stream<List<EventRegistration>> watchRegistrations(String eventId) =>
      _watch(() {
        final all = _registrations.where((r) => r.eventId == eventId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return all;
      });

  @override
  Stream<BookingContactSnapshot?> watchRegistrationContact(
    String eventId,
    String registrationId,
  ) => _watch(() {
    final reg = _registrations
        .where((r) => r.id == registrationId && r.eventId == eventId)
        .firstOrNull;
    if (reg == null || reg.status != RegistrationStatus.paid) {
      return null;
    }
    if (!reg.contactEligible) {
      return null;
    }
    return contacts['$eventId/$registrationId'];
  });

  @override
  Future<({String eventId, String hashtag})> saveDraft(EventDraft draft) async {
    _maybeFail();
    savedDrafts.add(draft);
    final id = draft.eventId ?? 'fake-event-${++_seq}-${'x' * 12}';
    final tag = draft.hashtag ?? 'Event${id.length}';
    return (eventId: id, hashtag: tag);
  }

  @override
  Future<void> publish(String eventId) async {
    _maybeFail();
    published.add(eventId);
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    _maybeFail();
    cancelledEvents.add(eventId);
    final e = _events[eventId];
    if (e != null) {
      _events[eventId] = _withStatus(e, EventStatus.cancelled);
      _changes.add(null);
    }
  }

  @override
  Future<void> respondToHostConsent(
    String eventId, {
    required bool accept,
  }) async {
    _maybeFail();
    consentAnswers.add((eventId: eventId, accept: accept));
  }

  EventDetail _withStatus(
    EventDetail e,
    EventStatus status, {
    int? registered,
    int? held,
  }) {
    final s = e.summary;
    return EventDetail(
      summary: EventSummary(
        id: s.id,
        title: s.title,
        hostName: s.hostName,
        hostVerified: s.hostVerified,
        hostType: s.hostType,
        hostId: s.hostId,
        createdBy: s.createdBy,
        type: s.type,
        startsAt: s.startsAt,
        endsAt: s.endsAt,
        hasSchedule: s.hasSchedule,
        locationName: s.locationName,
        geohash: s.geohash,
        lat: s.lat,
        lng: s.lng,
        priceVnd: s.priceVnd,
        capacity: s.capacity,
        registeredCount: registered ?? s.registeredCount,
        heldCount: held ?? s.heldCount,
        status: status,
        createdAt: s.createdAt,
        coverUrl: s.coverUrl,
      ),
      description: e.description,
      hashtag: e.hashtag,
      endsAt: e.endsAt,
      registrationDeadline: e.registrationDeadline,
      createdBy: e.createdBy,
      meetingPoint: e.meetingPoint,
      hostAvatarUrl: e.hostAvatarUrl,
      chatId: e.chatId,
      postCount: e.postCount,
      completedAt: e.completedAt,
      faq: e.faq,
      hostConsent: e.hostConsent,
      hostConsentExpiresAt: e.hostConsentExpiresAt,
      hashtagLocked: e.hashtagLocked,
      areaId: e.areaId,
      coverPath: e.coverPath,
      priceSet: e.priceSet,
      capacitySet: e.capacitySet,
    );
  }

  @override
  Future<RegisterOutcome> register(
    String eventId, {
    required int quantity,
    required String name,
    PayMethod? method,
  }) async {
    _maybeFail();
    final me = uid;
    final e = _events[eventId];
    if (me == null || e == null || e.summary.status == EventStatus.draft) {
      throw const EventError('not_found');
    }
    if (e.isManagedBy(me, null)) {
      throw const EventError('permission_denied');
    }
    if (quantity < 1) {
      throw const EventError('invalid_argument');
    }
    if (quantity > 4) {
      throw const EventError('limit_exceeded');
    }
    registerMethods.add(method);
    final now = _clock();
    // A lapsed hold is not active any more: the server releases it on the
    // next tap and starts a new hold.
    final lapsed = _registrations.indexWhere(
      (r) => r.eventId == eventId && r.userId == me && r.holdExpired(now),
    );
    if (lapsed >= 0) {
      _release(lapsed, now);
    }
    final active = _registrations
        .where((r) => r.eventId == eventId && r.userId == me && r.isActive)
        .firstOrNull;
    if (active != null) {
      final held = active.status == RegistrationStatus.held;
      final m = method ?? PayMethod.bankQr;
      final exp = active.holdExpiresAt ?? now.add(const Duration(minutes: 10));
      return RegisterOutcome(
        registrationId: active.id,
        status: active.status,
        paymentId: active.paymentId,
        instructions: held
            ? PaymentInstructions(
                paymentId: active.paymentId ?? 'pay-${active.id}',
                method: m,
                amount: active.amount,
                expiresAt: exp,
                transferCode: 'PB 7F3K2Q',
                bankName: 'BIDV',
                accountMasked: '9624 •••• 3812',
                qrPayload: '000201010212...',
                payUrl: 'https://pay.test/${active.id}',
              )
            : null,
        holdExpiresAt: active.holdExpiresAt,
      );
    }
    if (e.summary.status != EventStatus.open &&
        e.summary.status != EventStatus.full) {
      throw const EventError('not_eligible');
    }
    if (now.isAfter(e.registrationDeadline)) {
      throw const EventError('deadline_passed');
    }
    if (!hasPhone) {
      throw const EventError('phone_required');
    }
    if (quantity > e.summary.seatsLeft) {
      throw const EventError('sold_out');
    }
    final free = e.summary.isFree;
    final status = free ? RegistrationStatus.paid : RegistrationStatus.held;
    final id = 'reg-${++_seq}-${'y' * 16}';
    final reg = EventRegistration(
      id: id,
      eventId: eventId,
      userId: me,
      userName: name,
      ticketCode: free ? 'VE-FAKE-${_seq.toString().padLeft(4, '0')}' : '',
      quantity: quantity,
      amount: free ? 0 : quantity * e.summary.priceVnd,
      status: status,
      holdExpiresAt: free ? null : now.add(const Duration(minutes: 10)),
      paymentId: free ? null : 'pay-$id',
      contactEligible: false,
      event: EventTicketSnapshot(
        title: e.summary.title,
        type: e.summary.type,
        startsAt: e.summary.startsAt,
        endsAt: e.endsAt,
        locationName: e.summary.locationName,
        lat: e.summary.lat,
        lng: e.summary.lng,
        coverUrl: e.summary.coverUrl,
      ),
      createdAt: now,
    );
    _registrations.add(reg);
    final s = e.summary;
    final registered = s.registeredCount + (free ? quantity : 0);
    final held = s.heldCount + (free ? 0 : quantity);
    final full = registered + held >= s.capacity;
    _events[eventId] = _withStatus(
      e,
      full ? EventStatus.full : s.status,
      registered: registered,
      held: held,
    );
    _changes.add(null);
    final m = method ?? PayMethod.bankQr;
    final exp = reg.holdExpiresAt ?? now.add(const Duration(minutes: 10));
    return RegisterOutcome(
      registrationId: id,
      status: status,
      paymentId: reg.paymentId,
      instructions: free
          ? null
          : PaymentInstructions(
              paymentId: reg.paymentId ?? 'pay-$id',
              method: m,
              amount: reg.amount,
              expiresAt: exp,
              transferCode: 'PB 7F3K2Q',
              bankName: 'BIDV',
              accountMasked: '9624 •••• 3812',
              qrPayload: '000201010212...',
              payUrl: 'https://pay.test/$id',
            ),
      holdExpiresAt: reg.holdExpiresAt,
    );
  }

  @override
  Future<({RegistrationStatus status, int? refundPercent})> cancelRegistration(
    String eventId,
    String registrationId,
  ) async {
    _maybeFail();
    final i = _registrations.indexWhere(
      (r) => r.id == registrationId && r.eventId == eventId && r.userId == uid,
    );
    final e = _events[eventId];
    if (i < 0 || e == null) {
      throw const EventError('not_found');
    }
    final r = _registrations[i];
    if (!r.isActive || r.isCheckedIn) {
      throw const EventError('conflict');
    }
    final now = _clock();
    if (!now.isBefore(e.summary.startsAt)) {
      throw const EventError('deadline_passed');
    }
    final paidTicket = r.amount > 0 && r.status == RegistrationStatus.paid;
    final percent = paidTicket
        ? (e.summary.startsAt.difference(now) >= const Duration(hours: 48)
              ? 100
              : 0)
        : null;
    final status = percent == 100
        ? RegistrationStatus.refunded
        : RegistrationStatus.cancelled;
    _registrations[i] = EventRegistration(
      id: r.id,
      eventId: r.eventId,
      userId: r.userId,
      userName: r.userName,
      ticketCode: r.ticketCode,
      quantity: r.quantity,
      amount: r.amount,
      status: status,
      event: r.event,
      createdAt: r.createdAt,
      userAvatarUrl: r.userAvatarUrl,
      paymentId: r.paymentId,
      cancelledAt: now,
      refundPercent: percent,
      // The fake gateway pays back at once.
      refundStatus: percent == 100 ? TicketRefundStatus.done : null,
    );
    final s = e.summary;
    final wasHeld = r.status == RegistrationStatus.held;
    _events[eventId] = _withStatus(
      e,
      s.status == EventStatus.full ? EventStatus.open : s.status,
      registered: s.registeredCount - (wasHeld ? 0 : r.quantity),
      held: s.heldCount - (wasHeld ? r.quantity : 0),
    );
    _changes.add(null);
    return (status: status, refundPercent: percent);
  }

  /// The method of every `register` call, in order.
  final List<PayMethod?> registerMethods = [];

  /// Kept for Task 5 compatibility until Task 7 updates tickets_tab_test.
  List<dynamic> get registerProviders => registerMethods;

  /// Payment ids confirmed through confirmFakeTicketPayment / confirmFake.
  final List<String> fakeConfirmed = [];

  /// Payment ids the "gateway" reports as paid to [checkTicketPayment].
  final Set<String> gatewayPaid = {};

  /// Calls of [checkTicketPayment], as `eventId/registrationId`.
  final List<String> paymentChecks = [];

  EventRegistration _with(
    EventRegistration r, {
    RegistrationStatus? status,
    String? ticketCode,
    DateTime? cancelledAt,
    int? refundPercent,
    bool? contactEligible,
    bool? refundDue,
    TicketRefundStatus? refundStatus,
  }) => EventRegistration(
    id: r.id,
    eventId: r.eventId,
    userId: r.userId,
    userName: r.userName,
    ticketCode: ticketCode ?? r.ticketCode,
    quantity: r.quantity,
    amount: r.amount,
    status: status ?? r.status,
    event: r.event,
    createdAt: r.createdAt,
    userAvatarUrl: r.userAvatarUrl,
    paymentId: r.paymentId,
    holdExpiresAt: r.holdExpiresAt,
    checkedInAt: r.checkedInAt,
    cancelledAt: cancelledAt ?? r.cancelledAt,
    refundPercent: refundPercent ?? r.refundPercent,
    contactEligible: contactEligible ?? r.contactEligible,
    refundDue: refundDue ?? r.refundDue,
    refundStatus: refundStatus ?? r.refundStatus,
  );

  /// The hold at [i] gives its seats back (expired or paid too late).
  void _release(int i, DateTime now) {
    final r = _registrations[i];
    _registrations[i] = _with(
      r,
      status: RegistrationStatus.cancelled,
      cancelledAt: now,
    );
    final e = _events[r.eventId];
    if (e != null) {
      final s = e.summary;
      _events[r.eventId] = _withStatus(
        e,
        s.status == EventStatus.full ? EventStatus.open : s.status,
        held: s.heldCount - r.quantity,
      );
    }
  }

  RegistrationStatus _applyPayment(String paymentId) {
    final i = _registrations.indexWhere((r) => r.paymentId == paymentId);
    if (i < 0) {
      throw const EventError('not_found');
    }
    final r = _registrations[i];
    if (r.status != RegistrationStatus.held) {
      return r.status;
    }
    final now = _clock();
    if (r.holdExpired(now)) {
      // Paid too late: the server refunds 100% and frees the seats.
      _release(i, now);
      _registrations[i] = _with(
        _registrations[i],
        refundStatus: TicketRefundStatus.done,
      );
      _changes.add(null);
      return RegistrationStatus.cancelled;
    }
    _registrations[i] = _with(
      r,
      status: RegistrationStatus.paid,
      ticketCode: r.ticketCode.isEmpty
          ? 'VE-PAID-${(++_seq).toString().padLeft(4, '0')}'
          : r.ticketCode,
      contactEligible: true,
    );
    final e = _events[r.eventId];
    if (e != null) {
      final s = e.summary;
      _events[r.eventId] = _withStatus(
        e,
        s.status,
        registered: s.registeredCount + r.quantity,
        held: s.heldCount - r.quantity,
      );
    }
    _changes.add(null);
    return RegistrationStatus.paid;
  }

  /// Test helper to simulate payment settlement on a held ticket.
  RegistrationStatus applyPaymentForTest(String paymentId) =>
      _applyPayment(paymentId);

  @override
  Future<({bool paid, RegistrationStatus status})> checkTicketPayment(
    String eventId,
    String registrationId,
  ) async {
    _maybeFail();
    paymentChecks.add('$eventId/$registrationId');
    final r = _registrations
        .where((x) => x.id == registrationId && x.eventId == eventId)
        .firstOrNull;
    if (r == null || r.userId != uid) {
      throw const EventError('not_found');
    }
    final pay = r.paymentId;
    if (r.status == RegistrationStatus.held &&
        pay != null &&
        gatewayPaid.contains(pay)) {
      final status = _applyPayment(pay);
      return (paid: status == RegistrationStatus.paid, status: status);
    }
    return (paid: r.status == RegistrationStatus.paid, status: r.status);
  }

  @override
  Future<({String name, int quantity})> checkIn(
    String eventId,
    String ticketCode,
  ) async {
    _maybeFail();
    final ev = _events[eventId];
    if (ev != null) {
      if (ev.summary.status == EventStatus.cancelled) {
        throw const EventError('not_eligible');
      }
      // Server window: 00:00 VN on the event day → endAt + 2 h.
      final now = _clock();
      final v = ev.summary.startsAt.toUtc().add(const Duration(hours: 7));
      final opens = DateTime.utc(
        v.year,
        v.month,
        v.day,
      ).subtract(const Duration(hours: 7));
      final closes = ev.endsAt.add(const Duration(hours: 2));
      if (now.isBefore(opens) || now.isAfter(closes)) {
        throw const EventError('not_eligible');
      }
    }
    final i = _registrations.indexWhere(
      (r) =>
          r.eventId == eventId &&
          r.ticketCode == ticketCode &&
          r.status == RegistrationStatus.paid,
    );
    if (i < 0) {
      throw const EventError('not_found');
    }
    final r = _registrations[i];
    if (r.isCheckedIn) {
      throw const EventError('conflict');
    }
    _registrations[i] = EventRegistration(
      id: r.id,
      eventId: r.eventId,
      userId: r.userId,
      userName: r.userName,
      ticketCode: r.ticketCode,
      quantity: r.quantity,
      amount: r.amount,
      status: r.status,
      event: r.event,
      createdAt: r.createdAt,
      userAvatarUrl: r.userAvatarUrl,
      paymentId: r.paymentId,
      checkedInAt: _clock(),
      contactEligible: r.contactEligible,
    );
    checkedIn.add(ticketCode);
    _changes.add(null);
    return (name: r.userName, quantity: r.quantity);
  }

  @override
  Future<String> uploadCover(String eventId, PickedImage image) async {
    _maybeFail();
    final path = 'eventCovers/${uid ?? 'anonymous'}/$eventId/${newUlid()}.jpg';
    final url = 'https://storage.test/$path';
    coverPaths[url] = path;
    return url;
  }

  @override
  String? coverPathOf(String url) => coverPaths[url];

  /// Paths [deleteCover] removed.
  final List<String> deletedCovers = [];

  @override
  Future<void> deleteCover(String path) async {
    deletedCovers.add(path);
  }
}
