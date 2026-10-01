import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/app/tabs.dart';

/// Count shown on each bottom-bar tab; a missing tab shows no badge.
///
/// Explore: new events since the viewer last opened it (cleared on visit).
/// Work (photographer): requests waiting for an answer.
/// Features override this once they have the data.
final tabBadgesProvider = Provider<Map<AppTab, int>>((ref) => const {});
