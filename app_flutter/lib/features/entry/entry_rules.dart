// Pure S30 entry-ticket rules for the screens (S29.02-entry, S30.05,
// S04.03-entry, S05.02, S06.01-scan, S11.04-entry). The server decides
// (`bookingEntryDefaults`, `entryRefundPercent`); these mirrors only draw.
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/spots/spot.dart';

/// Most tickets in one order (`ENTRY_TICKETS_PER_ORDER`).
const entryTicketsPerOrder = 10;

/// S30.05 day chips span this many days from today.
const entryChipDays = 14;

/// "≈ {x}" per person: the first visible ticket type on sale, else the
/// first reference fee of a ticketed spot; null when there is no price.
int? entryUnitPrice(EntryEvent? event, SpotAccess? access) {
  final type = event?.visibleTicketTypes.firstOrNull;
  if (type != null) return type.price;
  if (access?.type != SpotAccessType.ticket) return null;
  return access?.fees.firstOrNull?.amountVnd;
}

/// The open days S30.05 offers: from [today] through 13 days later, closed
/// weekdays and days left out (spec S30.05 caption).
List<String> entryDaysFrom(EntryEvent e, String today) {
  final start = parseDayKey(today);
  if (start == null) return const [];
  final last = dayKeyOf(start.add(const Duration(days: entryChipDays - 1)));
  return [
    for (final d in e.openDays(today, entryChipDays))
      if (d.compareTo(last) <= 0) d,
  ];
}

/// The visit day's 00:00 in Việt Nam minus [cutoffHours], as a wall clock.
DateTime entryCutoffWallClock(String visitDay, int cutoffHours) =>
    parseDayKey(visitDay)!.subtract(Duration(hours: cutoffHours));

/// The refund cutoff as an instant (`entryRefundPercent`: 100% up to it).
DateTime entryCutoffAt(String visitDay, int cutoffHours) =>
    fromVnWallClock(entryCutoffWallClock(visitDay, cutoffHours));

/// "00:00 T5 12/11": the cutoff as S30.05 and S11.04 write it.
String entryCutoffLabel(String visitDay, int cutoffHours) {
  final w = entryCutoffWallClock(visitDay, cutoffHours);
  return '${formatHm(w)} ${formatDay(w)}';
}

/// "2 Người lớn · 1 Trẻ em" (S11.04-entry, per-type counts).
String entryItemsLine(List<EntryLine> items) =>
    [for (final i in items) '${i.qty} ${i.name}'].join(' · ');

/// Whether [s] covers the point (its radius, spec §5.1 `spotCovers`).
bool spotCoversPoint(Spot s, double lat, double lng) =>
    haversineKm(s.lat, s.lng, lat, lng) * 1000 <= s.radiusM;

/// The tickets a booking at a ticketed spot carries (S04.03-entry), as the
/// domain's `bookingEntryDefaults` computes them: the customer's picks minus
/// the guests a resident's waiver covers, plus one ticket of the first
/// visible type for the provider unless waived.
@immutable
class BookingEntryQuote {
  const BookingEntryQuote({
    required this.lines,
    required this.providerTicket,
    required this.waivedProvider,
    required this.waivedGuests,
    required this.customerCount,
  });

  /// Charged lines, merged per type.
  final List<EntryLine> lines;
  final bool providerTicket;
  final bool waivedProvider;

  /// Customer tickets the waiver covers.
  final int waivedGuests;
  final int customerCount;

  int get count => lines.fold(0, (n, l) => n + l.qty);
  int get amount => lines.fold(0, (n, l) => n + l.amount);

  /// "Bạn và thợ được miễn vé": nothing to pay, nobody to buy for.
  bool get allWaived =>
      waivedProvider && customerCount > 0 && waivedGuests >= customerCount;

  /// Over `ENTRY_TICKETS_PER_ORDER` with the provider's ticket.
  bool get overLimit =>
      customerCount + (providerTicket ? 1 : 0) > entryTicketsPerOrder;
}

BookingEntryQuote quoteBookingEntry({
  required EntryEvent event,
  required Map<String, int> picks,
  required Waiver waiver,
}) {
  final types = event.visibleTicketTypes;
  var free = waiver.guests
      ? (waiver.maxGuests ?? entryTicketsPerOrder * 10)
      : 0;
  var waived = 0;
  var customers = 0;
  final lines = <EntryLine>[];
  for (final t in types) {
    final q = picks[t.id] ?? 0;
    if (q <= 0) continue;
    customers += q;
    final w = q < free ? q : free;
    free -= w;
    waived += w;
    if (q - w > 0) {
      lines.add(
        EntryLine(ticketTypeId: t.id, name: t.name, price: t.price, qty: q - w),
      );
    }
  }
  final providerTicket = !waiver.provider && types.isNotEmpty;
  if (providerTicket) {
    final first = types.first;
    final i = lines.indexWhere((l) => l.ticketTypeId == first.id);
    if (i >= 0) {
      lines[i] = lines[i].copyWith(qty: lines[i].qty + 1);
    } else {
      lines.add(
        EntryLine(
          ticketTypeId: first.id,
          name: first.name,
          price: first.price,
          qty: 1,
        ),
      );
    }
  }
  return BookingEntryQuote(
    lines: lines,
    providerTicket: providerTicket,
    waivedProvider: waiver.provider,
    waivedGuests: waived,
    customerCount: customers,
  );
}
