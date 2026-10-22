// S14.02: answering the pending offers. The server is the referee (first
// accept wins, Decision 4); this only remembers which cards to drop.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';

/// The won request, as the overlay needs it. [name] is null when the request
/// could not be read in time: the screen then goes straight to S14.03.
class OfferMatch {
  const OfferMatch({
    required this.requestId,
    this.name,
    this.place,
    this.avatarUrl,
  });

  final String requestId;
  final String? name;
  final String? place;
  final String? avatarUrl;
}

class OfferUiState {
  const OfferUiState({
    this.dropped = const {},
    this.busyOfferId,
    this.accepting = false,
    this.match,
  });

  /// Offers answered here, or refused as taken/expired: off the stack even
  /// before the listener drops them.
  final Set<String> dropped;

  /// The offer whose answer is in flight; every button waits for it.
  final String? busyOfferId;

  /// The call in flight is an accept (its button shows the loader).
  final bool accepting;

  /// Set once an accept won.
  final OfferMatch? match;

  bool get busy => busyOfferId != null;
}

/// How long S14.02 waits for the won request before going on without the
/// overlay.
const _requestWait = Duration(seconds: 5);

/// Owns S14.02's answers. A refusal rethrows its error for the toast;
/// `already_assigned`, `offer_expired` and `blocked` also drop the card (it
/// can never be accepted again).
class OfferController extends Notifier<OfferUiState> {
  OfferController(this.screen);

  /// The S14.02 instance these answers belong to.
  final OfferScreenKey screen;

  @override
  OfferUiState build() => const OfferUiState();

  OfferUiState _settled({Set<String>? dropped}) =>
      OfferUiState(dropped: dropped ?? state.dropped, match: state.match);

  Set<String> _plus(String id) => {...state.dropped, id};

  /// `answerInstantOffer(accept: true)`, then one read of the won request
  /// for the overlay (customer name, meet point name).
  Future<void> accept(String offerId) async {
    if (state.busy || state.match != null) return;
    state = OfferUiState(
      dropped: state.dropped,
      busyOfferId: offerId,
      accepting: true,
    );
    final repo = ref.read(instantRepositoryProvider);
    final String requestId;
    try {
      requestId = await repo.answerOffer(offerId, accept: true);
    } on Object catch (e) {
      if (!ref.mounted) return;
      final kind = InstantError(instantErrorCodeOf(e)).kind;
      state = _settled(
        dropped: _dropsOnAccept.contains(kind) ? _plus(offerId) : null,
      );
      rethrow;
    }
    InstantRequest? request;
    try {
      request = await repo.watchRequest(requestId).first.timeout(_requestWait);
    } on Object {
      request = null;
    }
    if (!ref.mounted) return;
    final name = request?.customerName ?? '';
    // The meet point's typed name; its area when none was typed.
    final place = request == null
        ? null
        : request.meetPoint.name.isNotEmpty
        ? request.meetPoint.name
        : request.areaLabel;
    state = OfferUiState(
      dropped: _plus(offerId),
      match: OfferMatch(
        requestId: requestId,
        name: name.isEmpty ? null : name,
        place: place,
        avatarUrl: request?.customerAvatarUrl,
      ),
    );
  }

  /// `answerInstantOffer(accept: false)`; at once, no reason (Decision 25).
  /// An offer that is already over is dropped silently.
  Future<void> decline(String offerId) async {
    if (state.busy || state.match != null) return;
    state = OfferUiState(dropped: state.dropped, busyOfferId: offerId);
    try {
      await ref
          .read(instantRepositoryProvider)
          .answerOffer(offerId, accept: false);
      if (!ref.mounted) return;
      state = _settled(dropped: _plus(offerId));
    } on Object catch (e) {
      if (!ref.mounted) return;
      final kind = InstantError(instantErrorCodeOf(e)).kind;
      if (_overOnDecline.contains(kind)) {
        state = _settled(dropped: _plus(offerId));
        return;
      }
      state = _settled();
      rethrow;
    }
  }

  static const _dropsOnAccept = {
    InstantErrorKind.alreadyAssigned,
    InstantErrorKind.offerExpired,
    InstantErrorKind.blocked,
  };
  static const _overOnDecline = {
    InstantErrorKind.alreadyAssigned,
    InstantErrorKind.offerExpired,
  };
}

/// One per S14.02 on the stack (identity key): two screens never share
/// their dropped cards or their call in flight.
final class OfferScreenKey {}

final offerControllerProvider = NotifierProvider.autoDispose
    .family<OfferController, OfferUiState, OfferScreenKey>(OfferController.new);
