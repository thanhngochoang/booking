// S13.02: who the customer likes or skips in the current round, the payment
// method of the first round, and "Thanh toán {giá} và gửi lời mời" / "Gửi lời
// mời" / "Thanh toán tiếp". The request listener is the truth: a new round
// (after "Xem 5 người khác") starts a fresh choice, the first round's invite
// waits in `pending_payment` until S04.04 has the money (#202), and the offers
// move the request to `searching` (S13.03).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/instant_payment.dart';

/// At most this many cards per round (spec §2.1: five suggestions).
const kInstantRoundSize = 5;

class ChooseState {
  const ChooseState({
    this.liked = const [],
    this.skipped = const [],
    this.index = 0,
    this.undoDepth = 0,
    this.summary = false,
    this.sending = false,
    this.fetching = false,
    this.amountVnd,
    this.method,
    this.error,
  });

  /// Photographer ids, in the order they were liked.
  final List<String> liked;
  final List<String> skipped;

  /// Cards answered in this round (the next card's position).
  final int index;

  /// How many of those "Hoàn tác" can still bring back.
  final int undoDepth;

  /// "Những người bạn đã chọn" is open.
  final bool summary;

  /// `inviteInstant` is in flight.
  final bool sending;

  /// `nextInstantCandidates` is in flight.
  final bool fetching;

  /// The amount the server answered with `price_changed`; null = the
  /// request's own.
  final int? amountVnd;

  /// The payment method picked on the summary (#202); null = not touched
  /// (see [ChooseController.methodOf]).
  final PayMethod? method;

  /// The last failed call, for the toast.
  final Object? error;

  ChooseState copyWith({
    List<String>? liked,
    List<String>? skipped,
    int? index,
    int? undoDepth,
    bool? summary,
    bool? sending,
    bool? fetching,
    int? amountVnd,
    PayMethod? method,
    Object? error,
    bool clearError = false,
  }) => ChooseState(
    liked: liked ?? this.liked,
    skipped: skipped ?? this.skipped,
    index: index ?? this.index,
    undoDepth: undoDepth ?? this.undoDepth,
    summary: summary ?? this.summary,
    sending: sending ?? this.sending,
    fetching: fetching ?? this.fetching,
    amountVnd: amountVnd ?? this.amountVnd,
    method: method ?? this.method,
    error: clearError ? null : (error ?? this.error),
  );
}

/// The round's cards: the request's candidates, at most [kInstantRoundSize].
List<InstantCandidate> roundCandidates(InstantRequest r) =>
    r.candidates.take(kInstantRoundSize).toList();

class ChooseController extends Notifier<ChooseState> {
  ChooseController(this.requestId);

  final String requestId;

  /// Undo history: who was answered, and whether they were liked.
  final _history = <({String id, bool liked})>[];

  @override
  ChooseState build() {
    _history.clear();
    ref.listen(
      instantRequestProvider(requestId).select((v) => v.value?.round),
      (previous, next) {
        if (previous != null && next != null && previous != next) {
          _history.clear();
          state = ChooseState(amountVnd: state.amountVnd, method: state.method);
        }
      },
    );
    return const ChooseState();
  }

  InstantRequest? get _request =>
      ref.read(instantRequestProvider(requestId)).value;

  void like(InstantCandidate c) {
    _history.add((id: c.photographerId, liked: true));
    state = state.copyWith(
      liked: [...state.liked, c.photographerId],
      index: state.index + 1,
      undoDepth: _history.length,
    );
  }

  void skip(InstantCandidate c) {
    _history.add((id: c.photographerId, liked: false));
    state = state.copyWith(
      skipped: [...state.skipped, c.photographerId],
      index: state.index + 1,
      undoDepth: _history.length,
    );
  }

  /// "Hoàn tác": the last card comes back unanswered.
  void undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    state = state.copyWith(
      liked: last.liked
          ? [
              for (final id in state.liked)
                if (id != last.id) id,
            ]
          : null,
      skipped: last.liked
          ? null
          : [
              for (final id in state.skipped)
                if (id != last.id) id,
            ],
      index: state.index > 0 ? state.index - 1 : 0,
      undoDepth: _history.length,
    );
  }

  /// "Xong", or the last card with someone liked: the summary.
  void done() => state = state.copyWith(summary: true);

  /// Back from the summary to the deck.
  void closeSummary() => state = state.copyWith(summary: false);

  /// "Bỏ chọn" on the summary.
  void unpick(String photographerId) => state = state.copyWith(
    liked: [
      for (final id in state.liked)
        if (id != photographerId) id,
    ],
  );

  /// "Xem 5 người khác" / "Thử lại": a new round without the skipped people.
  /// The listener brings the new candidates (and resets the choice).
  Future<void> more() async {
    if (state.fetching || state.sending) return;
    state = state.copyWith(fetching: true, clearError: true);
    final alive = ref.keepAlive();
    try {
      await ref
          .read(instantRepositoryProvider)
          .nextCandidates(requestId, skipped: state.skipped);
      if (ref.mounted) state = state.copyWith(fetching: false);
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(fetching: false, error: e);
    } finally {
      alive.close();
    }
  }

  /// The payment method on the summary (Decision 2).
  void setMethod(PayMethod m) => state = state.copyWith(method: m);

  /// The method the first round pays with for [r]: the picked one, else the
  /// one [r] waits on, else Chuyển khoản QR.
  PayMethod methodOf(InstantRequest r) => instantPayMethodOf(r, state.method);

  /// The summary's primary (Decision 1, #202). The first round ("Thanh toán
  /// {giá} và gửi lời mời", the request not committed) sends the liked people
  /// with the payment method and gets [InstantPaymentNeeded]: the view opens
  /// S04.04 and the offers go out once the money is in. In `pending_payment`
  /// ("Thanh toán tiếp") the waiting choice is sent again (the server reuses
  /// the open payment). Later rounds ("Gửi lời mời") use the held money and
  /// get [InstantInvited]. Null while a call is in flight (a double tap sends
  /// one invite), with nobody chosen, or when the call failed
  /// ([ChooseState.error]). The notification primer is asked after the
  /// payment (Decision 10), not here.
  Future<InstantInviteResult?> send() async {
    final r = _request;
    if (r == null || state.sending || state.fetching) return null;
    final pending = r.status == InstantStatus.pendingPayment;
    if (pending ? r.pendingInviteIds.isEmpty : state.liked.isEmpty) {
      return null;
    }
    state = state.copyWith(sending: true, clearError: true);
    final alive = ref.keepAlive();
    try {
      final repo = ref.read(instantRepositoryProvider);
      final result = pending
          ? await inviteInstantAgain(repo, r, method: state.method)
          : await repo.invite(
              requestId,
              photographerIds: state.liked,
              skipped: state.skipped,
              expectedAmountVnd: state.amountVnd ?? r.amountVnd,
              payMethod: r.committed ? null : methodOf(r),
            );
      if (!ref.mounted) return result;
      state = switch (result) {
        InstantPriceChanged(:final amountVnd) => state.copyWith(
          sending: false,
          amountVnd: amountVnd,
        ),
        // S04.04 (the view opens it) or S13.03 (the listener moves on).
        InstantPaymentNeeded() ||
        InstantInvited() => state.copyWith(sending: false),
      };
      return result;
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(sending: false, error: e);
      return null;
    } finally {
      alive.close();
    }
  }
}

final chooseControllerProvider = NotifierProvider.autoDispose
    .family<ChooseController, ChooseState, String>(ChooseController.new);
