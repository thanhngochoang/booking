// test/features/events/venue_consent_sheet_test.dart
//
// S11.02-venue-consent (mock #S11.02-venue-consent): the spot manager answers
// an event that asks to take place at their spot (Decision 16).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/features/events/venue_consent_sheet.dart';

import '../../support/event_world.dart';
import '../../support/fake_organizer_repository.dart';
import '../../support/organizer_world.dart' show makeOrganizer;
import '../../support/screen_host.dart';

const _venue = EventVenue(
  kind: VenueKind.managedSpot,
  spotId: 'bd',
  termsVersion: organizerTermsVersion,
);

EventDetail _event({int price = 350000}) => detailOf(
  'ev1',
  title: 'Photo walk cúc hoạ mi',
  priceVnd: price,
  capacity: 30,
  status: EventStatus.draft,
  venue: _venue,
  venueConsent: HostConsent.pending,
  venueConsentExpiresAt: eventNow.add(const Duration(days: 2, hours: 3)),
);

class _World {
  _World({bool business = true}) {
    organizers.putOrganizer(
      makeOrganizer(businessVerified: business, payoutAccountOk: business),
    );
  }

  final events = FakeEventRepository(uid: 'org1', clock: () => eventNow);
  final organizers = FakeOrganizerRepository(clock: () => eventNow);

  Future<void> open(
    WidgetTester tester,
    EventDetail event, {
    double width = 390,
    double textScale = 1,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screenApp(
        brightness: brightness,
        textScale: textScale,
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'org1')),
          ),
          clockProvider.overrideWithValue(() => eventNow),
          eventRepositoryProvider.overrideWithValue(events),
          organizerRepositoryProvider.overrideWithValue(organizers),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => showVenueConsentSheet(
                  context,
                  event: event,
                  spotName: 'Bãi đá sông Hồng',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }
}

Finder _key(String k) => find.byKey(Key(k));

TextField _fee(WidgetTester tester) =>
    tester.widget<TextField>(_key('venue-consent-fee'));

void main() {
  testWidgets('event info, the fee field, the deadline and two answers', (
    tester,
  ) async {
    final w = _World();
    await w.open(tester, _event());
    expect(find.text('Tổ chức tại Bãi đá sông Hồng?'), findsOneWidget);
    expect(
      find.textContaining('Quốc Bảo · '),
      findsOneWidget,
      reason: 'host first',
    );
    expect(
      find.textContaining('tối đa 30 khách · 350.000₫/vé'),
      findsOneWidget,
    );
    expect(find.text('Phí quản lý mỗi khách'), findsOneWidget);
    expect(_fee(tester).enabled, isNot(false));
    expect(find.textContaining('Còn 2 ngày để trả lời.'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.text('Đồng ý'), findsOneWidget);
    // "Từ chối" is red text on an outline button; one primary.
    final decline = tester.widget<AppButton>(_key('venue-consent-decline'));
    expect(
      decline.style?.foregroundColor?.resolve(const {}),
      anyOf(AppColors.error, AppColorsDark.error),
    );
  });

  testWidgets('"Đồng ý" calls respondVenueConsent with the fee', (
    tester,
  ) async {
    final w = _World();
    await w.open(tester, _event());
    await tester.enterText(_key('venue-consent-fee'), '50000');
    await tester.tap(_key('venue-consent-accept'));
    await settle(tester);
    expect(w.events.venueAnswers, [
      (eventId: 'ev1', accept: true, venueFeePerGuest: 50000),
    ]);
    expect(find.text('Tổ chức tại Bãi đá sông Hồng?'), findsNothing);
    expect(find.text('Đã đồng ý'), findsOneWidget);
  });

  testWidgets(
    'without a business the fee is locked at 0 with a hint; "Đồng ý" sends 0',
    (tester) async {
      final w = _World(business: false);
      await w.open(tester, _event());
      expect(_fee(tester).enabled, isFalse);
      expect(
        find.text('Xác minh doanh nghiệp để thu phí quản lý'),
        findsOneWidget,
      );
      await tester.tap(_key('venue-consent-accept'));
      await settle(tester);
      expect(w.events.venueAnswers.single.venueFeePerGuest, 0);
    },
  );

  testWidgets('a free event can only be accepted without a fee', (
    tester,
  ) async {
    final w = _World();
    await w.open(tester, _event(price: 0));
    expect(_fee(tester).enabled, isFalse);
    expect(
      find.text('Sự kiện miễn phí: không thu phí quản lý'),
      findsOneWidget,
    );
    expect(find.textContaining('Không thu phí'), findsWidgets);
    expect(find.textContaining('0₫'), findsNothing);
  });

  testWidgets('a fee not below the price is refused before the call', (
    tester,
  ) async {
    final w = _World();
    await w.open(tester, _event());
    await tester.enterText(_key('venue-consent-fee'), '350000');
    await tester.tap(_key('venue-consent-accept'));
    await settle(tester);
    expect(find.text('Phí phải thấp hơn giá vé 350.000₫'), findsOneWidget);
    expect(w.events.venueAnswers, isEmpty);
  });

  testWidgets('"Từ chối" opens a red ConfirmSheet, then declines', (
    tester,
  ) async {
    final w = _World();
    await w.open(tester, _event());
    await tester.tap(_key('venue-consent-decline'));
    await settle(tester);
    expect(find.text('Từ chối sự kiện này?'), findsOneWidget);
    final red = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Từ chối').last,
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      red.style?.backgroundColor?.resolve(const {}),
      anyOf(AppColors.error, AppColorsDark.error),
    );
    expect(w.events.venueAnswers, isEmpty);
    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Từ chối'),
      ),
    );
    await settle(tester);
    expect(w.events.venueAnswers, [
      (eventId: 'ev1', accept: false, venueFeePerGuest: null),
    ]);
    expect(find.text('Đã từ chối'), findsOneWidget);
  });

  testWidgets('deadline_passed says the 72 h are over', (tester) async {
    final w = _World();
    w.events
      ..failWith = const EventError('deadline_passed')
      ..failOnce = true;
    await w.open(tester, _event());
    await tester.tap(_key('venue-consent-accept'));
    await settle(tester);
    expect(find.text('Đã quá hạn trả lời. Sự kiện đã bị huỷ.'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      final w = _World(business: false);
      await w.open(tester, _event(), width: 320, textScale: 1.3, brightness: b);
      expect(tester.takeException(), isNull);
      expect(_key('venue-consent-accept'), findsOneWidget);
    });
  }
}
