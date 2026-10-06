import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/features/explore/explore_badge.dart';
import 'package:photobooking/features/work/work_dashboard.dart';

/// Count shown on each bottom-bar tab; a missing tab shows no badge.
///
/// Explore: new events since the viewer last opened it (cleared on visit).
/// Work (photographer): requests waiting for an answer, the same number as
/// S06.01's "Yêu cầu mới".
/// Profile: unread notifications (the server's count, one document listener).
final tabBadgesProvider = Provider<Map<AppTab, int>>((ref) {
  final count = ref.watch(exploreBadgeCountProvider);
  // A reload keeps the previous value; treat it as nothing new so a cleared
  // badge does not linger while the query runs.
  final explore = count.isLoading ? 0 : (count.value ?? 0);
  final requests = ref.watch(workRequestCountProvider);
  final unread = ref.watch(unreadCountProvider).value ?? 0;
  return {
    if (explore > 0) AppTab.explore: explore,
    if (requests > 0) AppTab.bookings: requests,
    if (unread > 0) AppTab.profile: unread,
  };
});
