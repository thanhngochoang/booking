import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ready flags for S09.02 (and S09.01) rows whose screens are built by other
// plans. A row whose route does not exist yet stays hidden, never a dead
// link; the plan that adds the route flips its flag to `true`.

/// `/verify/start` (S21.02) exists since #135.
final verifyStartReadyProvider = Provider<bool>((ref) => true);

/// `/me/studio` (S26.03) and `/studio/members` (S26.01) exist since #136.
final studioRoutesReadyProvider = Provider<bool>((ref) => true);

/// The S19 plan flips this when `/me/following` and `/me/saved` exist.
final savedListsReadyProvider = Provider<bool>((ref) => true);
