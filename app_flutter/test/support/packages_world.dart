import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/packages/my_packages_screen.dart';
import 'package:photobooking/features/packages/package_edit_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';

import 'fake_price_rule_repository.dart';
import 'photographer_world.dart';
import 'screen_host.dart';

/// 1,5M on an ordinary day, 2 hours, 40 edited photos, 3 days.
const portraitPackage = ServicePackage(
  id: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  editedCount: 40,
  deliveryDays: 3,
  order: 0,
);

/// 3,2M, 4 hours.
const couplePackage = ServicePackage(
  id: 'p2',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
  editedCount: 80,
  deliveryDays: 5,
  order: 1,
);

/// 900k, hidden from customers.
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

/// "Cuối tuần" 1,8M on Saturday and Sunday.
PriceRule weekendSeries({String serviceId = 'p1'}) => PriceRule(
  id: 'weekend-$serviceId',
  serviceId: serviceId,
  price: 1800000,
  repeat: PriceRepeat.weekly,
  name: 'Cuối tuần',
  weekdays: const {Weekday.sat, Weekday.sun},
);

/// "Mùa cưới" 2M every 14/11 - 22/11.
PriceRule weddingSeries({String serviceId = 'p1'}) => PriceRule(
  id: 'wedding-$serviceId',
  serviceId: serviceId,
  price: 2000000,
  repeat: PriceRepeat.yearly,
  name: 'Mùa cưới',
  from: '11-14',
  to: '11-22',
);

/// "Tết" 2,5M, lunar 23/12 - 5/1.
PriceRule tetSeries({String serviceId = 'p1'}) => PriceRule(
  id: 'tet-$serviceId',
  serviceId: serviceId,
  price: 2500000,
  repeat: PriceRepeat.yearly,
  lunar: true,
  name: 'Tết',
  from: '12-23',
  to: '01-05',
);

/// A signed-in photographer hosting S08.08 at `/me/packages`, with in-memory
/// packages and price series (today is Fri 6 Nov 2026, from [PhotographerWorld]).
/// `/me/day-pricing` and the other links show their path.
class PackagesWorld {
  final PhotographerWorld w = PhotographerWorld();
  late GoRouter router;

  Future<void> init({List<ServicePackage> packages = const []}) async {
    await w.init();
    for (final p in packages) {
      w.packages.seed(w.uid, p);
    }
    rules.packages = [
      for (final p in packages)
        PricedPackage(id: p.id, price: p.priceVnd, active: p.active),
    ];
  }

  FakeServicePackageRepository get packages => w.packages;
  FakePriceRuleRepository get rules => w.priceRules;

  List<Override> get overrides => w.overrides;

  /// [editor]: `/me/packages/new` and `/me/packages/:id` are the real
  /// S08.09, and `/setup/2` is S08.01 step 2; else they show their path.
  Widget app({
    String location = '/me/packages',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    bool editor = false,
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
          builder: (_, s) => editor
              ? PackageEditScreen(
                  fromSetup: s.uri.queryParameters['from'] == 'setup',
                )
              : Text('stub ${s.uri}'),
        ),
        GoRoute(
          path: '/me/packages/:id',
          builder: (_, s) => editor
              ? PackageEditScreen(
                  packageId: s.pathParameters['id'],
                  fromSetup: s.uri.queryParameters['from'] == 'setup',
                )
              : Text('stub ${s.uri}'),
        ),
        GoRoute(
          path: '/setup/2',
          builder: (_, _) => const SetupPackagesScreen(),
        ),
        GoRoute(path: '/setup/1', builder: (_, s) => Text('stub ${s.uri}')),
        GoRoute(path: '/setup/3', builder: (_, s) => Text('stub ${s.uri}')),
        GoRoute(path: '/me/addons', builder: (_, s) => Text('stub ${s.uri}')),
        GoRoute(
          path: '/me/day-pricing',
          builder: (_, s) => Text('stub ${s.uri}'),
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
