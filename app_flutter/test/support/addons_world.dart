import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/addons/addons_screen.dart';

import 'fake_addon_repository.dart';
import 'photographer_world.dart';
import 'screen_host.dart';

/// A signed-in photographer with in-memory add-ons and packages, hosting
/// S08.06 (and so the S08.07 sheet) at `/me/addons`.
class AddonsWorld {
  final PhotographerWorld w = PhotographerWorld();
  final FakeAddonRepository addons = FakeAddonRepository();
  late GoRouter router;

  Future<void> init({List<ServicePackage> packages = const []}) async {
    await w.init();
    addons.ownerUid = w.uid;
    for (final p in packages) {
      w.packages.seed(w.uid, p);
    }
  }

  /// Seeds an add-on of the signed-in photographer.
  ServiceAddon seed(
    String id, {
    String name = 'Trang điểm',
    AddonKind kind = AddonKind.makeup,
    AddonUnit unit = AddonUnit.perPerson,
    int price = 800000,
    int maxQty = 4,
    List<String> serviceIds = const [],
    bool active = true,
    String? description,
  }) {
    final a = ServiceAddon(
      id: id,
      providerId: w.uid,
      kind: kind,
      name: name,
      description: description,
      price: price,
      unit: unit,
      maxQty: maxQty,
      serviceIds: serviceIds,
      active: active,
      createdAt: DateTime.utc(2026, 10),
      updatedAt: DateTime.utc(2026, 10),
    );
    addons.seed(a);
    return a;
  }

  Widget app({
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    List<RouteBase> extraRoutes = const [],
  }) {
    router = GoRouter(
      initialLocation: '/me/addons',
      routes: [
        GoRoute(path: '/me/addons', builder: (_, _) => const AddonsScreen()),
        ...extraRoutes,
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: [
        ...w.overrides,
        addonRepositoryProvider.overrideWithValue(addons),
      ],
      brightness: brightness,
      textScale: textScale,
    );
  }
}
