import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/features/packages/my_packages_screen.dart';
import 'package:photobooking/features/packages/special_days_screen.dart';

import 'photographer_world.dart';
import 'screen_host.dart';

/// Monday to Friday 1,5M, Saturday and Sunday 1,8M, holidays 2,2M.
const twoLevelPackage = ServicePackage(
  id: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  editedCount: 40,
  deliveryDays: 3,
  dayPrices: {
    Weekday.mon: 1500000,
    Weekday.tue: 1500000,
    Weekday.wed: 1500000,
    Weekday.thu: 1500000,
    Weekday.fri: 1500000,
    Weekday.sat: 1800000,
    Weekday.sun: 1800000,
  },
  specialPrice: 2200000,
  order: 0,
);

/// 3,2M to 4M, a different price on most days, no special price.
const perDayPackage = ServicePackage(
  id: 'p2',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
  editedCount: 80,
  deliveryDays: 5,
  priceMode: PriceMode.perDay,
  dayPrices: {
    Weekday.mon: 3200000,
    Weekday.tue: 3200000,
    Weekday.wed: 3300000,
    Weekday.thu: 3300000,
    Weekday.fri: 3500000,
    Weekday.sat: 4000000,
    Weekday.sun: 3800000,
  },
  order: 1,
);

/// One price on every day, hidden from customers.
const hiddenPackage = ServicePackage(
  id: 'p3',
  name: 'Sản phẩm 10 món',
  priceVnd: 900000,
  durationMinutes: 120,
  editedCount: 30,
  deliveryDays: 3,
  order: 2,
  active: false,
);

/// A signed-in photographer hosting S08.08 at `/me/packages` and S08.10 at
/// `/me/special-days`, with in-memory packages, holidays and special days.
/// `/me/packages/new` and `/me/packages/:id` show their path.
class PackagesWorld {
  final PhotographerWorld w = PhotographerWorld();
  final holidays = FakeHolidayRepository();
  final specialDays = FakeSpecialDayRepository();
  late GoRouter router;

  Future<void> init({List<ServicePackage> packages = const []}) async {
    await w.init();
    for (final p in packages) {
      w.packages.seed(w.uid, p);
    }
  }

  FakeServicePackageRepository get packages => w.packages;

  /// The 2026 holidays used by the tests: Tết (Mon 16 to Sun 22 Feb) and the
  /// Hùng Kings (Sun 26 Apr).
  void seedHolidays2026() {
    holidays.seed(2026, [
      for (var d = 16; d <= 22; d++)
        Holiday(day: '2026-02-$d', name: 'Tết Nguyên đán'),
      const Holiday(day: '2026-04-26', name: 'Giỗ Tổ Hùng Vương'),
    ]);
  }

  SpecialDayRange seedRange(String id, String name, String from, String to) {
    final r = SpecialDayRange(id: id, name: name, from: from, to: to);
    specialDays.seed(w.uid, r);
    return r;
  }

  List<Override> get overrides => [
    ...w.overrides,
    holidayRepositoryProvider.overrideWithValue(holidays),
    specialDayRepositoryProvider.overrideWithValue(specialDays),
  ];

  Widget app({
    String location = '/me/packages',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/me/packages',
          builder: (_, _) => const MyPackagesScreen(),
        ),
        GoRoute(
          path: '/me/packages/new',
          builder: (_, s) => Text('stub ${s.uri}'),
        ),
        GoRoute(
          path: '/me/packages/:id',
          builder: (_, s) => Text('stub ${s.uri}'),
        ),
        GoRoute(
          path: '/me/special-days',
          builder: (_, _) => const SpecialDaysScreen(),
        ),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }
}
