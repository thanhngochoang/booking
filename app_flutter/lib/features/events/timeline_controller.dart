// lib/features/events/timeline_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/events/event_timeline_repository.dart';

/// Which timeline list: an event's visible rows, or its pending ones.
typedef TimelineKey = ({String eventId, TimelineStatus status});

@immutable
class TimelineListState {
  const TimelineListState({
    this.items = const [],
    this.cursor,
    this.loading = true,
    this.loadingMore = false,
    this.failed = false,
    this.moreFailed = false,
  });

  final List<TimelineItem> items;

  /// Null on the last page.
  final String? cursor;

  /// The first page is on its way.
  final bool loading;
  final bool loadingMore;
  final bool failed;
  final bool moreFailed;

  bool get isEmpty => !loading && !failed && items.isEmpty;

  TimelineListState copyWith({
    List<TimelineItem>? items,
    String? Function()? cursor,
    bool? loading,
    bool? loadingMore,
    bool? failed,
    bool? moreFailed,
  }) => TimelineListState(
    items: items ?? this.items,
    cursor: cursor == null ? this.cursor : cursor(),
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    failed: failed ?? this.failed,
    moreFailed: moreFailed ?? this.moreFailed,
  );
}

const timelinePageSize = 20;

/// Pages one timeline list, 20 at a time, newest first.
class TimelineController extends Notifier<TimelineListState> {
  TimelineController(this.key);

  final TimelineKey key;

  EventTimelineRepository get _repo =>
      ref.read(eventTimelineRepositoryProvider);

  @override
  TimelineListState build() {
    Future.microtask(() {
      if (ref.mounted) {
        unawaited(refresh());
      }
    });
    return const TimelineListState();
  }

  /// Loads the first page again (pull to refresh, retry).
  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }
    if (state.items.isEmpty) {
      state = state.copyWith(loading: true, failed: false);
    }
    try {
      final page = await _repo.page(
        key.eventId,
        status: key.status,
        limit: timelinePageSize,
      );
      if (!ref.mounted) {
        return;
      }
      state = TimelineListState(
        items: page.items,
        cursor: page.cursor,
        loading: false,
      );
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      // Keep what is already shown; only an empty list turns into the error.
      state = state.copyWith(loading: false, failed: state.items.isEmpty);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (cursor == null || state.loadingMore || state.loading) {
      return;
    }
    state = state.copyWith(loadingMore: true, moreFailed: false);
    try {
      final page = await _repo.page(
        key.eventId,
        status: key.status,
        cursor: cursor,
        limit: timelinePageSize,
      );
      if (!ref.mounted) {
        return;
      }
      final seen = {for (final i in state.items) i.postId};
      state = state.copyWith(
        items: [
          ...state.items,
          for (final i in page.items)
            if (seen.add(i.postId)) i,
        ],
        cursor: () => page.cursor,
        loadingMore: false,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(loadingMore: false, moreFailed: true);
      }
    }
  }

  /// A manager approves or hides [item]. The row leaves this list at once and
  /// the other list reloads; returns false when the server refused.
  Future<bool> moderate(TimelineItem item, TimelineAction action) async {
    try {
      await _repo.moderate(key.eventId, item.postId, action);
    } catch (_) {
      return false;
    }
    if (!ref.mounted) {
      return true;
    }
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.postId != item.postId) i,
      ],
    );
    for (final other in TimelineStatus.values) {
      if (other != key.status) {
        ref.invalidate(
          timelineControllerProvider((eventId: key.eventId, status: other)),
        );
      }
    }
    return true;
  }
}

final timelineControllerProvider = NotifierProvider.autoDispose
    .family<TimelineController, TimelineListState, TimelineKey>(
      TimelineController.new,
    );
