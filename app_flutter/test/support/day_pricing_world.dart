import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/day_pricing_analytics.dart';
import 'package:photobooking/features/day_pricing/day_pricing_screen.dart';
import 'package:photobooking/features/day_pricing/price_rules_screen.dart';

import 'fake_price_rule_repository.dart';
import 'photographer_world.dart';
import 'screen_host.dart';

/// Portrait, 1,5M, on.
const portrait = ServicePackage(
  id: 'p1',
  name: 'Chân dung',
  priceVnd: 1500000,
  durationMinutes: 120,
  order: 0,
);

/// Couple, 3,2M, on.
const couple = ServicePackage(
  id: 'p2',
  name: 'Cặp đôi',
  priceVnd: 3200000,
  durationMinutes: 240,
  order: 1,
);

/// Product, 1,2M, hidden.
const product = ServicePackage(
  id: 'p3',
  name: 'Sản phẩm',
  priceVnd: 1200000,
  durationMinutes: 60,
  order: 2,
  active: false,
);

/// Weekend 1,8M on Saturday and Sunday.
PriceRule weekendRule({String id = 'r-weekend', String serviceId = 'p1'}) =>
    PriceRule(
      id: id,
      serviceId: serviceId,
      price: 1800000,
      repeat: PriceRepeat.weekly,
      name: 'Cuối tuần',
      weekdays: const {Weekday.sat, Weekday.sun},
    );

/// "Mùa cưới" 2M every 14/11 - 22/11.
PriceRule weddingRule({
  String id = 'r-wedding',
  String serviceId = 'p1',
  Map<String, Object?> exceptions = const {},
}) => PriceRule(
  id: id,
  serviceId: serviceId,
  price: 2000000,
  repeat: PriceRepeat.yearly,
  name: 'Mùa cưới',
  from: '11-14',
  to: '11-22',
  exceptions: exceptions,
);

/// Tết, 2,5M, lunar 23/12 - 5/1.
PriceRule tetRule({String id = 'r-tet', String serviceId = 'p1'}) => PriceRule(
  id: id,
  serviceId: serviceId,
  price: 2500000,
  repeat: PriceRepeat.yearly,
  lunar: true,
  name: 'Tết Nguyên đán',
  from: '12-23',
  to: '01-05',
  template: 'tet',
);

/// A signed-in photographer with packages and price series in memory, hosting
/// S08.10 at `/me/day-pricing` and the list at `/me/day-pricing/rules`.
/// `/me/packages/new` shows its path. Today is Fri 6 Nov 2026 (the lunar 27th
/// of month 9), so November is on screen.
class DayPricingWorld {
  final PhotographerWorld w = PhotographerWorld();
  final events = <({String name, Map<String, Object> params})>[];
  late GoRouter router;

  FakePriceRuleRepository get rules => w.priceRules;

  Future<void> init({
    List<ServicePackage> packages = const [portrait, couple],
    DateTime? today,
  }) async {
    w.today = today ?? DateTime.utc(2026, 11, 6);
    await w.init();
    for (final p in packages) {
      w.packages.seed(w.uid, p);
    }
    rules.packages = [
      for (final p in packages)
        PricedPackage(id: p.id, price: p.priceVnd, active: p.active),
    ];
  }

  void seed(PriceRule rule) => rules.seed(rule);

  Widget app({
    String location = '/me/day-pricing?service=p1',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/me/day-pricing',
          builder: (_, s) =>
              DayPricingScreen(serviceId: s.uri.queryParameters['service']),
        ),
        GoRoute(
          path: '/me/day-pricing/rules',
          builder: (_, s) => PriceRulesScreen(
            fromCalendar: s.uri.queryParameters['from'] == 'calendar',
          ),
        ),
        GoRoute(
          path: '/me/packages/new',
          builder: (_, s) => Text('stub ${s.uri}'),
        ),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: [
        ...w.overrides,
        dayPricingAnalyticsProvider.overrideWithValue(
          (name, params) => events.add((name: name, params: params)),
        ),
      ],
      brightness: brightness,
      textScale: textScale,
    );
  }

  /// Pumps the app at [location] on a phone-sized window and lets the first
  /// loads settle.
  Future<void> open(
    WidgetTester tester, {
    String location = '/me/day-pricing?service=p1',
    double width = 390,
    double height = 1600,
    double textScale = 1.0,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(location: location, textScale: textScale, brightness: brightness),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The calendar cell of [day] (a UTC date).
Finder dayCell(DateTime day) =>
    find.byKey(ValueKey('app-calendar-day-${dayKey(day)}'));

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The short price line under [day] on S08.10.
Finder priceLine(DateTime day) =>
    find.byKey(Key('day-pricing-price-${dayKey(day)}'));

Finder keyed(String key) => find.byKey(Key(key));

Future<void> tapDay(WidgetTester tester, DateTime day) async {
  await tester.tap(dayCell(day));
  await tester.pumpAndSettle();
}

/// Press, hold and drag from [a] to [b], the way a range is selected.
Future<void> dragRange(WidgetTester tester, DateTime a, DateTime b) async {
  final g = await tester.startGesture(tester.getCenter(dayCell(a)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await g.moveTo(tester.getCenter(dayCell(b)));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

Future<void> typePrice(WidgetTester tester, String key, String digits) async {
  await tester.enterText(keyed(key), digits);
  await tester.pump();
}

/// Taps a widget by key and settles.
Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(keyed(key));
  await tester.pumpAndSettle();
  await tester.tap(keyed(key));
  await tester.pumpAndSettle();
}
