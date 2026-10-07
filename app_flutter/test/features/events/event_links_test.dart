import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

void main() {
  test('calendar URL holds UTC start and end', () {
    final uri = eventCalendarUri(
      title: 'Photo walk',
      startsAt: DateTime.utc(2026, 10, 19, 23),
      endsAt: DateTime.utc(2026, 10, 20, 2, 30),
      location: 'Hồ Hoàn Kiếm',
    );
    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['action'], 'TEMPLATE');
    expect(uri.queryParameters['text'], 'Photo walk');
    expect(uri.queryParameters['dates'], '20261019T230000Z/20261020T023000Z');
    expect(uri.queryParameters['location'], 'Hồ Hoàn Kiếm');
  });

  test('a start given in another zone is converted to UTC', () {
    final uri = eventCalendarUri(
      title: 'x',
      startsAt: DateTime.parse('2026-10-20T06:00:00+07:00'),
      endsAt: DateTime.parse('2026-10-20T09:00:00+07:00'),
    );
    expect(uri.queryParameters['dates'], '20261019T230000Z/20261020T020000Z');
  });

  test('directions use the event point, then the place name', () {
    final byPoint = eventDirectionsUri(lat: 10.78, lng: 106.7);
    expect(byPoint.queryParameters['destination'], '10.78,106.7');
    final byName = eventDirectionsUri(placeName: 'Bạch Đằng');
    expect(byName.queryParameters['query'], 'Bạch Đằng');
  });

  test('the share link is the in-app path', () {
    expect(eventShareLink('abc'), '/e/abc');
  });

  test('the when line reads in Vietnam time with the long weekday', () {
    final AppLocalizations l = AppLocalizationsVi();
    expect(
      eventWhenLabel(
        l,
        DateTime.utc(2026, 10, 19, 23),
        DateTime.utc(2026, 10, 20, 2),
      ),
      'Thứ ba 20/10 · 06:00–09:00',
    );
  });

  test('no support address yet: no mailto line (owner question)', () {
    expect(eventSupportEmail, isNull);
    expect(eventSupportUri(), isNull);
    expect(eventSupportUri('a@b.vn'), Uri(scheme: 'mailto', path: 'a@b.vn'));
  });
}
