import 'dart:async';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({this.customerId = 'c1', DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final String customerId;
  final DateTime Function() _clock;
  final Map<String, Booking> bookings = {};
  final Map<String, BookingContactSnapshot> contacts = {};
  final Map<String, List<BookingEventRecord>> events = {};

  final _bookingChanges = StreamController<String>.broadcast();
  final _contactChanges = StreamController<String>.broadcast();
  final _eventChanges = StreamController<String>.broadcast();

  BookingErrorCode? nextError;
  BookingErrorCode? nextPaymentError;
  final createCalls =
      <
        ({
          String photographerId,
          String serviceId,
          String day,
          String start,
          String placeName,
          String? note,
          int? expectedPrice,
          List<AddonPick> addons,
          BookingPlace? pickup,
          int? expectedTotal,
        })
      >[];
  final paymentCalls = <({String bookingId, PayMethod method})>[];
  final fakeConfirms = <String>[];
  final fakeConfirmKinds = <FakeTransferKind>[];

  /// When true, [createPayment] returns before the booking stream shows the new
  /// checkout (a slow snapshot); [releaseCheckoutUpdates] delivers it.
  bool deferCheckoutUpdates = false;
  final _deferredCheckouts = <String, BookingCheckout>{};

  /// Writes the checkouts held back by [deferCheckoutUpdates] to their
  /// bookings and notifies the streams.
  void releaseCheckoutUpdates() {
    for (final MapEntry(key: bookingId, value: checkout)
        in _deferredCheckouts.entries) {
      final b = bookings[bookingId];
      if (b == null) continue;
      bookings[bookingId] = b.copyWith(checkout: checkout);
      _bookingChanges.add(bookingId);
    }
    _deferredCheckouts.clear();
  }

  /// paymentId → bookingId, for the payments this fake created.
  final _paymentBooking = <String, String>{};
  final checkCalls = <String>[];

  void remove(String id) {
    bookings.remove(id);
    _bookingChanges.add(id);
  }

  void _checkNextError() {
    final err = nextError;
    if (err != null) {
      nextError = null;
      throw BookingException(_serverCodeFor(err));
    }
  }

  static String _serverCodeFor(BookingErrorCode err) {
    return switch (err) {
      BookingErrorCode.dayTaken => 'day_taken',
      BookingErrorCode.phoneRequired => 'phone_required',
      BookingErrorCode.priceChanged => 'price_changed',
      BookingErrorCode.notEligible => 'not_eligible',
      BookingErrorCode.notAcceptingOrders => 'not_accepting_orders',
      BookingErrorCode.blocked => 'blocked',
      BookingErrorCode.deadlinePassed => 'deadline_passed',
      BookingErrorCode.conflict => 'conflict',
      BookingErrorCode.permissionDenied => 'permission_denied',
      BookingErrorCode.notFound => 'not_found',
      BookingErrorCode.invalidArgument => 'invalid_argument',
      BookingErrorCode.paymentAttemptsExceeded => 'payment_attempts_exceeded',
      BookingErrorCode.addonChanged => 'addon_changed',
      BookingErrorCode.addonNotApplicable => 'addon_not_applicable',
      BookingErrorCode.pickupRequired => 'pickup_required',
      BookingErrorCode.network => 'unavailable',
      BookingErrorCode.unknown => 'unknown',
    };
  }

  void seedBooking(Booking booking) {
    bookings[booking.id] = booking;
    _bookingChanges.add(booking.id);
  }

  void seedContact(String bookingId, BookingContactSnapshot contact) {
    contacts[bookingId] = contact;
    _contactChanges.add(bookingId);
  }

  void seedEvents(String bookingId, List<BookingEventRecord> list) {
    events[bookingId] = List.of(list);
    _eventChanges.add(bookingId);
  }

  void addEvent(BookingEventRecord event) {
    final list = events.putIfAbsent(event.bookingId, () => []);
    list.add(event);
    _eventChanges.add(event.bookingId);
  }

  @override
  Stream<Booking?> watchBooking(String id) {
    return _bookingChanges.stream
        .where((changedId) => changedId == id)
        .map((_) => bookings[id])
        .startWith(bookings[id]);
  }

  @override
  Future<Booking?> getBooking(String id) async {
    return bookings[id];
  }

  @override
  Stream<List<Booking>> watchCustomerBookings(String customerId) {
    List<Booking> list() => bookings.values
        .where(
          (b) => b.customerId == customerId && b.status != BookingStatus.draft,
        )
        .toList();

    return _bookingChanges.stream.map((_) => list()).startWith(list());
  }

  @override
  Stream<List<Booking>> watchPhotographerBookings(String photographerId) {
    List<Booking> list() => bookings.values
        .where(
          (b) =>
              b.photographerId == photographerId &&
              b.status != BookingStatus.draft,
        )
        .toList();

    return _bookingChanges.stream.map((_) => list()).startWith(list());
  }

  List<Booking> _assigned = const [];
  Object? _assignedError;
  final _assignedChanges = StreamController<List<Booking>>.broadcast();

  /// Sets the bookings a studio assigned to the watcher and notifies it.
  void emitAssigned(List<Booking> list) {
    _assigned = List.unmodifiable(list);
    _assignedError = null;
    _assignedChanges.add(_assigned);
  }

  /// Makes the assigned stream fail (e.g. the rule denies the query); a later
  /// watcher fails at once.
  void failAssigned(Object error) {
    _assignedError = error;
    _assignedChanges.addError(error);
  }

  @override
  Stream<List<Booking>> watchAssignedBookings(String uid) async* {
    final error = _assignedError;
    if (error != null) throw error;
    yield _assigned;
    yield* _assignedChanges.stream;
  }

  @override
  Stream<BookingContactSnapshot?> watchBookingContact(String bookingId) {
    return _contactChanges.stream
        .where((changedId) => changedId == bookingId)
        .map((_) => contacts[bookingId])
        .startWith(contacts[bookingId]);
  }

  @override
  Stream<List<BookingEventRecord>> watchEvents(String bookingId) {
    List<BookingEventRecord> list() =>
        List.unmodifiable(events[bookingId] ?? const []);
    return _eventChanges.stream
        .where((id) => id == bookingId)
        .map((_) => list())
        .startWith(list());
  }

  @override
  Future<Booking> createBooking({
    required String photographerId,
    required String serviceId,
    required String day,
    required String start,
    required BookingPlace place,
    String? note,
    int? expectedPrice,
    List<AddonPick> addons = const [],
    BookingPlace? pickup,
    int? expectedTotal,
  }) async {
    _checkNextError();
    createCalls.add((
      photographerId: photographerId,
      serviceId: serviceId,
      day: day,
      start: start,
      placeName: place.name,
      note: note,
      expectedPrice: expectedPrice,
      addons: addons,
      pickup: pickup,
      expectedTotal: expectedTotal,
    ));
    final id = 'booking_${bookings.length + 1}';
    final now = DateTime.now().toUtc();
    final booking = Booking(
      id: id,
      customerId: customerId,
      photographerId: photographerId,
      serviceId: serviceId,
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Gói chụp',
        price: 1000000,
        durationMinutes: 120,
      ),
      day: day,
      start: start,
      end: '11:00',
      place: place,
      note: note,
      status: BookingStatus.draft,
      deposit: 1000000,
      remaining: 0,
      createdAt: now,
      updatedAt: now,
    );
    bookings[id] = booking;
    _bookingChanges.add(id);
    return booking;
  }

  @override
  Future<BookingCheckout> createPayment({
    required String bookingId,
    required PayMethod method,
  }) async {
    _checkNextError();
    final payErr = nextPaymentError;
    if (payErr != null) {
      nextPaymentError = null;
      throw BookingException(_serverCodeFor(payErr));
    }
    paymentCalls.add((bookingId: bookingId, method: method));
    final b = bookings[bookingId];
    // Like the server: the next attempt after the calls made and the one shown.
    final calls = paymentCalls.where((c) => c.bookingId == bookingId).length;
    final shown = (b?.checkout?.attempt ?? 0) + 1;
    final attempt = calls > shown ? calls : shown;
    final paymentId = attempt == 1
        ? 'pay_$bookingId'
        : 'pay_${bookingId}_$attempt';
    _paymentBooking[paymentId] = bookingId;
    final isQr = method == PayMethod.bankQr;
    final checkout = BookingCheckout(
      paymentId: paymentId,
      method: method,
      amount: b?.deposit ?? 1000000,
      expiresAt: _clock().toUtc().add(const Duration(minutes: 15)),
      transferCode: 'PB 7F3K2Q',
      attempt: attempt,
      qrPayload: isQr ? fakeQrPayload : null,
      bankName: isQr ? 'BIDV' : null,
      accountMasked: isQr ? '9624 •••• 3812' : null,
      bankAppsUrl: isQr ? 'https://fake-pay.local/bank-apps' : null,
      payUrl: isQr
          ? null
          : 'https://fake-pay.local/${method.code}?paymentId=$paymentId',
    );
    if (b != null && deferCheckoutUpdates) {
      _deferredCheckouts[bookingId] = checkout;
    } else if (b != null) {
      bookings[bookingId] = b.copyWith(checkout: checkout);
      _bookingChanges.add(bookingId);
    }
    return checkout;
  }

  /// Fixed fake VietQR text (a test value, not a real account).
  static const fakeQrPayload =
      '00020101021238570010A000000727012700069704180113962470000038120208QRIBFTTA53037045802VN6304ABCD';

  @override
  Future<String> confirmFakePayment({
    required String paymentId,
    FakeTransferKind kind = FakeTransferKind.exact,
  }) async {
    _checkNextError();
    fakeConfirms.add(paymentId);
    fakeConfirmKinds.add(kind);
    final bookingId =
        _paymentBooking[paymentId] ?? paymentId.replaceFirst('pay_', '');
    final pays =
        kind == FakeTransferKind.exact || kind == FakeTransferKind.over;
    final b = bookings[bookingId];
    if (pays && b != null) {
      bookings[bookingId] = b.copyWith(
        status: BookingStatus.requested,
        escrowStatus: EscrowStatus.held,
        depositPaidAt: _clock().toUtc(),
      );
      _bookingChanges.add(bookingId);
    }
    return switch (kind) {
      FakeTransferKind.exact => 'paid',
      FakeTransferKind.over => 'paid_with_refund',
      FakeTransferKind.under => 'partial',
      FakeTransferKind.wrongContent => 'needs_review',
    };
  }

  @override
  Future<CheckPaymentResponse> checkPayment({required String bookingId}) async {
    _checkNextError();
    checkCalls.add(bookingId);
    final b = bookings[bookingId];
    return CheckPaymentResponse(
      paid: b != null && b.status != BookingStatus.draft,
      booking: b,
    );
  }

  @override
  Future<Booking> transitionBooking({
    required String bookingId,
    required String action,
    String? reason,
  }) async {
    _checkNextError();
    final b = bookings[bookingId];
    if (b == null) throw StateError('Booking not found');

    BookingStatus nextStatus;
    switch (action) {
      case 'accept':
        nextStatus = BookingStatus.accepted;
        break;
      case 'decline':
        nextStatus = BookingStatus.declined;
        break;
      case 'cancel':
        nextStatus = BookingStatus.cancelled;
        break;
      case 'upcoming':
        nextStatus = BookingStatus.upcoming;
        break;
      case 'mark_shot':
        nextStatus = BookingStatus.shot;
        break;
      case 'complete':
        nextStatus = BookingStatus.completed;
        break;
      case 'cancel_studio_fault':
        nextStatus = BookingStatus.cancelled;
        break;
      default:
        nextStatus = b.status;
    }

    final nowUtc = _clock().toUtc();
    final updated = b.copyWith(
      status: nextStatus,
      cancel: action == 'cancel_studio_fault'
          ? BookingCancel(
              by: 'studio_fault',
              reason: b.studio?.studioFault?.kind.code,
              at: nowUtc,
              refundPercent: 100,
            )
          : b.cancel,
      shotAt: nextStatus == BookingStatus.shot ? nowUtc : b.shotAt,
      completedAt: nextStatus == BookingStatus.completed
          ? nowUtc
          : b.completedAt,
      updatedAt: nowUtc,
    );
    bookings[bookingId] = updated;
    _bookingChanges.add(bookingId);
    return updated;
  }

  final List<({String bookingId, String reason})> disputeCalls = [];

  @override
  Future<Booking> openDispute({
    required String bookingId,
    required String reason,
  }) async {
    _checkNextError();
    disputeCalls.add((bookingId: bookingId, reason: reason));
    final b = bookings[bookingId];
    if (b == null) throw StateError('Booking not found');

    final updated = b.copyWith(
      escrowStatus: EscrowStatus.disputed,
      updatedAt: DateTime.now().toUtc(),
    );
    bookings[bookingId] = updated;
    _bookingChanges.add(bookingId);
    return updated;
  }

  /// Studio callables made, in order: `(name, payload)` with the payload the
  /// Firestore adapter sends.
  final studioCalls = <(String, Map<String, Object?>)>[];

  Future<Booking> _studio(
    String name,
    Map<String, Object?> payload,
    StudioBookingInfo Function(StudioBookingInfo s, DateTime now) change,
  ) async {
    _checkNextError();
    studioCalls.add((name, payload));
    final bookingId = payload['bookingId']! as String;
    // The assignee sees a studio booking only through the assigned stream.
    final b =
        bookings[bookingId] ??
        _assigned.where((a) => a.id == bookingId).firstOrNull;
    final s = b?.studio;
    if (b == null || s == null) throw const BookingException('not_eligible');
    final now = _clock().toUtc();
    final updated = b.copyWith(studio: change(s, now), updatedAt: now);
    bookings[bookingId] = updated;
    _bookingChanges.add(bookingId);
    if (_assigned.any((a) => a.id == bookingId)) {
      emitAssigned([
        for (final a in _assigned) a.id == bookingId ? updated : a,
      ]);
    }
    return updated;
  }

  @override
  Future<Booking> assign(String bookingId, String assigneeId) => _studio(
    'assignBooking',
    {'bookingId': bookingId, 'assigneeId': assigneeId},
    (s, now) => s.copyWith(
      assigneeId: assigneeId,
      assigneeKind: 'member',
      assignStatus: StudioAssignStatus.assigned,
      assignedAt: now,
      assignments: [
        ...s.assignments,
        StudioAssignment(assigneeId: assigneeId, at: now, by: 'studio'),
      ],
      changeRequest: s.changeRequest?.status == ChangeRequestStatus.pending
          ? s.changeRequest!.copyWith(
              status: ChangeRequestStatus.reassigned,
              answeredAt: now,
            )
          : s.changeRequest,
      studioFault: s.studioFault?.kind == StudioFaultKind.assignOverdue
          ? null
          : s.studioFault,
      returnedAt: null,
      returnReason: null,
    ),
  );

  @override
  Future<Booking> requestChange(String bookingId, {String? note}) => _studio(
    'requestAssigneeChange',
    {'bookingId': bookingId, 'note': ?note},
    (s, now) => s.copyWith(
      changeRequest: StudioChangeRequest(
        at: now,
        note: note,
        respondBy: now.add(const Duration(hours: 6)),
      ),
    ),
  );

  @override
  Future<Booking> declineChange(String bookingId, String reason) => _studio(
    'declineAssigneeChange',
    {'bookingId': bookingId, 'reason': reason},
    (s, now) => s.copyWith(
      changeRequest: s.changeRequest?.copyWith(
        status: ChangeRequestStatus.declined,
        declineReason: reason,
        answeredAt: now,
      ),
      studioFault: StudioFault(kind: StudioFaultKind.changeDeclined, at: now),
    ),
  );

  @override
  Future<Booking> returnAssignment(String bookingId, {String? reason}) =>
      _studio(
        'returnAssignment',
        {'bookingId': bookingId, 'reason': ?reason},
        (s, now) => s.copyWith(returnedAt: now, returnReason: reason),
      );
}

extension _StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
