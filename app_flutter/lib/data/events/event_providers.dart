// lib/data/events/event_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/firestore_event_repository.dart';
import 'package:photobooking/data/media/media_providers.dart';

/// Rebuilt when the signed-in user changes, so own-data streams follow it.
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return FirestoreEventRepository(
    uid: uid,
    uploader: ref.watch(mediaUploaderProvider),
  );
});

final eventProvider = StreamProvider.autoDispose.family<EventDetail?, String>(
  (ref, id) => ref.watch(eventRepositoryProvider).watchEvent(id),
);

final myEventRegistrationProvider = StreamProvider.autoDispose
    .family<EventRegistration?, String>(
      (ref, eventId) =>
          ref.watch(eventRepositoryProvider).watchMyRegistration(eventId),
    );

final myTicketsProvider = StreamProvider.autoDispose<List<EventRegistration>>(
  (ref) => ref.watch(eventRepositoryProvider).watchMyTickets(),
);

final myEventsProvider = StreamProvider.autoDispose<List<EventSummary>>(
  (ref) => ref.watch(eventRepositoryProvider).watchMine(),
);

/// Staff-created drafts waiting for my answer as the named host (O1).
final hostInvitationsProvider = StreamProvider.autoDispose<List<EventDetail>>(
  (ref) => ref.watch(eventRepositoryProvider).watchHostInvitations(),
);

/// S30.03: the events waiting for the answer of [spotId]'s manager.
final venueRequestsProvider = StreamProvider.autoDispose
    .family<List<EventDetail>, String>(
      (ref, spotId) =>
          ref.watch(eventRepositoryProvider).watchVenueRequests(spotId),
    );

/// An entry event's registrations of one visit day (S12.03-entry).
final entryDayRegistrationsProvider = StreamProvider.autoDispose
    .family<List<EventRegistration>, ({String eventId, String day})>(
      (ref, k) => ref
          .watch(eventRepositoryProvider)
          .watchEntryRegistrations(k.eventId, day: k.day),
    );

/// An entry event's registrations from a visit day on (S30.04).
final entryRegistrationsFromProvider = StreamProvider.autoDispose
    .family<List<EventRegistration>, ({String eventId, String fromDay})>(
      (ref, k) => ref
          .watch(eventRepositoryProvider)
          .watchEntryRegistrations(k.eventId, fromDay: k.fromDay),
    );

final eventRegistrationsProvider = StreamProvider.autoDispose
    .family<List<EventRegistration>, String>(
      (ref, eventId) =>
          ref.watch(eventRepositoryProvider).watchRegistrations(eventId),
    );
