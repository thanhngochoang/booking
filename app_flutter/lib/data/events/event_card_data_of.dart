import 'package:photobooking/core/widgets/event_card.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

EventCardData eventCardDataOf(EventSummary e, AppLocalizations l) {
  final soldOut = e.status == EventStatus.full || e.seatsLeft == 0;
  return EventCardData(
    id: e.id,
    title: e.title,
    hostName: e.isPlatformHosted ? l.eventHostPlatform : e.hostName,
    hostVerified: !e.isPlatformHosted && e.hostVerified,
    typeTag: e.type.tag,
    typeLabel: e.type.label(l),
    startsAt: e.startsAt,
    hasDate: e.hasSchedule,
    placeName: e.locationName,
    priceVnd: e.priceVnd,
    seatsLeft: e.seatsLeft,
    soldOut: soldOut,
    coverUrl: e.coverUrl,
    capacity: e.capacity,
    registeredCount: e.registeredCount,
  );
}
