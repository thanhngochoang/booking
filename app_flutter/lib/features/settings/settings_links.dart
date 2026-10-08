import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ready flags for S09.02 (and S09.01) rows whose screens are built by other
// plans. A row whose route does not exist yet stays hidden, never a dead
// link; the plan that adds the route flips its flag to `true`.

/// #135 flips this when `/verify/start` (S21.02) exists.
final verifyStartReadyProvider = Provider<bool>((ref) => false);

/// #136 flips this when `/me/studio` (S26.03) and `/studio/members` (S26.01)
/// exist.
final studioRoutesReadyProvider = Provider<bool>((ref) => false);

/// The S19 plan flips this when `/me/following` and `/me/saved` exist.
final savedListsReadyProvider = Provider<bool>((ref) => false);
