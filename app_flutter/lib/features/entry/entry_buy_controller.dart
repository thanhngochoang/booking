// S30.05: the visit day, the counts per ticket type and the
// `registerEntry` call. The server holds the tickets 15 minutes and prices
// them; this only counts.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/features/entry/entry_rules.dart';

@immutable
class EntryBuyState {
  const EntryBuyState({
    this.day,
    this.counts = const {},
    this.submitting = false,
    this.refusal,
  });

  /// The chosen visit day (`yyyy-MM-dd`); null until one is open.
  final String? day;

  /// Ticket type id → count; a missing type is 0. Null [counts] entries are
  /// never stored.
  final Map<String, int> counts;
  final bool submitting;

  /// The last refusal of `registerEntry`, shown above the primary.
  final RegisterRefusal? refusal;

  int get total => counts.values.fold(0, (n, q) => n + q);

  int countOf(String typeId) => counts[typeId] ?? 0;

  int amountFor(List<EntryTicketType> types) =>
      types.fold(0, (sum, t) => sum + t.price * countOf(t.id));

  EntryBuyState copyWith({
    String? day,
    Map<String, int>? counts,
    bool? submitting,
    RegisterRefusal? refusal,
    bool clearRefusal = false,
  }) => EntryBuyState(
    day: day ?? this.day,
    counts: counts ?? this.counts,
    submitting: submitting ?? this.submitting,
    refusal: clearRefusal ? null : (refusal ?? this.refusal),
  );
}

/// The outcome of "Thanh toán": the held order, or why it was refused.
sealed class EntryBuyOutcome {
  const EntryBuyOutcome();
}

final class EntryHeld extends EntryBuyOutcome {
  const EntryHeld(this.outcome);
  final RegisterOutcome outcome;
}

final class EntryRefused extends EntryBuyOutcome {
  const EntryRefused(this.refusal);
  final RegisterRefusal refusal;
}

final entryBuyControllerProvider = NotifierProvider.autoDispose
    .family<EntryBuyController, EntryBuyState, String>(EntryBuyController.new);

class EntryBuyController extends Notifier<EntryBuyState> {
  EntryBuyController(this.spotId);

  final String spotId;
  bool _started = false;

  @override
  EntryBuyState build() => const EntryBuyState();

  /// The first open types arrive: one ticket of the first type (the
  /// customer usually buys at least theirs).
  void start(EntryEvent event) {
    if (_started) return;
    _started = true;
    final first = event.visibleTicketTypes.firstOrNull;
    if (first != null) state = state.copyWith(counts: {first.id: 1});
  }

  void selectDay(String day) {
    if (state.submitting) return;
    state = state.copyWith(day: day, clearRefusal: true);
  }

  /// Sets [typeId] to [count] while the order stays within
  /// [entryTicketsPerOrder] tickets.
  void setCount(String typeId, int count) {
    if (state.submitting || count < 0) return;
    final others = state.total - state.countOf(typeId);
    if (others + count > entryTicketsPerOrder) return;
    final next = Map<String, int>.of(state.counts);
    if (count == 0) {
      next.remove(typeId);
    } else {
      next[typeId] = count;
    }
    state = state.copyWith(counts: next, clearRefusal: true);
  }

  /// A refused day (sold out, closed) is no longer the chosen one.
  void dropDay() =>
      state = EntryBuyState(counts: state.counts, refusal: state.refusal);

  /// Holds the tickets of [day] (`registerEntry`; the screen passes the
  /// chosen day or the first one on sale). Null while a call runs or there
  /// is nothing to buy.
  Future<EntryBuyOutcome?> submit(EntryEvent event, String day) async {
    if (state.submitting || state.total == 0) return null;
    state = state.copyWith(submitting: true, clearRefusal: true);
    try {
      final name = ref.read(currentProfileProvider).value?.displayName ?? '';
      final outcome = await ref
          .read(eventRepositoryProvider)
          .registerEntry(
            eventId: event.id,
            visitDay: day,
            items: [
              for (final t in event.visibleTicketTypes)
                if (state.countOf(t.id) > 0)
                  EntryItem(ticketTypeId: t.id, qty: state.countOf(t.id)),
            ],
            name: name.trim(),
          );
      if (ref.mounted) state = state.copyWith(submitting: false);
      return EntryHeld(outcome);
    } catch (e) {
      final refusal = registerRefusalOf(e);
      if (ref.mounted) {
        state = state.copyWith(submitting: false, refusal: refusal);
      }
      return EntryRefused(refusal);
    }
  }
}
