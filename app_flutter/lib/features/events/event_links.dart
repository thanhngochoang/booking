// lib/features/events/event_links.dart
import 'package:flutter/services.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// `yyyyMMddTHHmmssZ`, the form Google Calendar takes.
String _calendarStamp(DateTime instant) {
  final u = instant.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Google Calendar "new event" template (Decision 21): UTC start and end, the
/// place as location. Opened through the external launcher; no package.
Uri eventCalendarUri({
  required String title,
  required DateTime startsAt,
  required DateTime endsAt,
  String? location,
  String? details,
}) => Uri.https('calendar.google.com', '/calendar/render', {
  'action': 'TEMPLATE',
  'text': title,
  'dates': '${_calendarStamp(startsAt)}/${_calendarStamp(endsAt)}',
  'location': ?location,
  'details': ?details,
});

/// Google Maps directions to the event's point. Falls back to a text search
/// for [placeName] when the event has no coordinates.
Uri eventDirectionsUri({double? lat, double? lng, String? placeName}) {
  if (lat != null && lng != null) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    });
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': placeName ?? '',
  });
}

/// No public web host exists yet, so the in-app path is what is copied
/// (album precedent).
String eventShareLink(String eventId) => '/e/$eventId';

Future<void> copyEventLink(String eventId) =>
    Clipboard.setData(ClipboardData(text: eventShareLink(eventId)));

/// "Chủ nhật 20/10 · 06:00–09:00" in Vietnam time (events are one day).
String eventWhenLabel(AppLocalizations l, DateTime startsAt, DateTime endsAt) {
  final s = toVn(startsAt);
  final e = toVn(endsAt);
  String two(int n) => n.toString().padLeft(2, '0');
  String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
  return '${l.eventWeekdayLong(s.weekday.toString())} ${formatDayMonth(s)}'
      ' · ${hm(s)}–${hm(e)}';
}
