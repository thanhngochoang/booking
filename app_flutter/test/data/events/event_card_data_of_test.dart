import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  group('eventCardDataOf', () {
    test('maps EventSummary fields, seatsLeft and soldOut from status full', () {
      final now = DateTime.utc(2026, 10, 12, 10, 0);
      final e = EventSummary(
        id: 'ev_1',
        title: 'Mini session mùa thu',
        hostName: 'Minh Trí',
        hostVerified: true,
        type: EventType.miniSession,
        startsAt: now,
        priceVnd: 600000,
        capacity: 10,
        registeredCount: 7,
        heldCount: 0,
        status: EventStatus.full,
        createdAt: now,
        locationName: 'Công viên Bạch Đằng',
        coverUrl: 'https://example.com/cover.jpg',
      );

      final data = eventCardDataOf(e, l);

      expect(data.id, 'ev_1');
      expect(data.title, 'Mini session mùa thu');
      expect(data.hostName, 'Minh Trí');
      expect(data.hostVerified, isTrue);
      expect(data.typeTag, '#minisession');
      expect(data.typeLabel, l.eventTypeMiniSession);
      expect(data.startsAt, now);
      expect(data.placeName, 'Công viên Bạch Đằng');
      expect(data.priceVnd, 600000);
      expect(data.seatsLeft, 3);
      expect(data.soldOut, isTrue); // status is full
      expect(data.coverUrl, 'https://example.com/cover.jpg');
    });

    test('soldOut is true when seatsLeft is 0', () {
      final now = DateTime.utc(2026, 10, 12, 10, 0);
      final e = EventSummary(
        id: 'ev_2',
        title: 'Photo walk',
        hostName: 'Tuấn',
        hostVerified: false,
        type: EventType.photoWalk,
        startsAt: now,
        priceVnd: 0,
        capacity: 10,
        registeredCount: 10,
        heldCount: 0,
        status: EventStatus.open,
        createdAt: now,
      );

      final data = eventCardDataOf(e, l);
      expect(data.priceVnd, 0);
      expect(data.seatsLeft, 0);
      expect(data.soldOut, isTrue);
    });

    test('soldOut is false when status is open and seats remain', () {
      final now = DateTime.utc(2026, 10, 12, 10, 0);
      final e = EventSummary(
        id: 'ev_3',
        title: 'Workshop',
        hostName: 'An',
        hostVerified: false,
        type: EventType.workshop,
        startsAt: now,
        priceVnd: 200000,
        capacity: 10,
        registeredCount: 5,
        heldCount: 1,
        status: EventStatus.open,
        createdAt: now,
      );

      final data = eventCardDataOf(e, l);
      expect(data.seatsLeft, 4);
      expect(data.soldOut, isFalse);
    });
  });
}
