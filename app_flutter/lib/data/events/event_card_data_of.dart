import 'package:photobooking/core/widgets/event_card.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

EventCardData eventCardDataOf(EventSummary e, AppLocalizations l) {
  final soldOut = e.status == EventStatus.full || e.seatsLeft == 0;
  return EventCardData(
    id: e.id,
    title: e.title,
    hostName: e.hostName,
    hostVerified: e.hostVerified,
    typeTag: e.type.tag,
    typeLabel: e.type.label(l),
    startsAt: e.startsAt,
    placeName: e.locationName,
    priceVnd: e.priceVnd,
    seatsLeft: e.seatsLeft,
    soldOut: soldOut,
    coverUrl: e.coverUrl,
  );
}
