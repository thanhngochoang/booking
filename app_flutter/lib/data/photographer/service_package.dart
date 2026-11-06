import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/pricing/day_pricing.dart';

/// Durations a package can have (spec S08.01: 1, 2, 3, 4, 6 or 8 hours).
const kPackageDurationsMinutes = [60, 120, 180, 240, 360, 480];

/// How the editor shows the 7 day prices: weekday and weekend, or one each.
/// Stored as `priceMode` (`two_levels` | `per_day`).
enum PriceMode {
  twoLevels('two_levels'),
  perDay('per_day');

  const PriceMode(this.code);
  final String code;

  static PriceMode fromCode(Object? code) =>
      code == perDay.code ? perDay : twoLevels;
}

/// What the photographer types for a package. Money is whole VND.
@immutable
class ServicePackageInput {
  const ServicePackageInput({
    required this.name,
    required this.priceVnd,
    required this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
    this.dayPrices,
    this.specialPrice,
    this.priceMode = PriceMode.twoLevels,
    this.order,
  });

  final String name;

  /// The weekday price (Monday), and the price of all 7 days without
  /// [dayPrices]. Saving [dayPrices] writes Monday's price here.
  final int priceVnd;
  final int durationMinutes;
  final int? editedCount;
  final int? deliveryDays;

  /// Price per weekday; null for one price on all days.
  final Map<Weekday, int>? dayPrices;

  /// Price on special days (holidays and the provider's own ranges).
  final int? specialPrice;
  final PriceMode priceMode;

  /// Position in the owner's list, 0-999; null until first reordered.
  final int? order;

  @override
  bool operator ==(Object other) =>
      other is ServicePackageInput &&
      other.name == name &&
      other.priceVnd == priceVnd &&
      other.durationMinutes == durationMinutes &&
      other.editedCount == editedCount &&
      other.deliveryDays == deliveryDays &&
      mapEquals(other.dayPrices, dayPrices) &&
      other.specialPrice == specialPrice &&
      other.priceMode == priceMode &&
      other.order == order;

  @override
  int get hashCode => Object.hash(
    name,
    priceVnd,
    durationMinutes,
    editedCount,
    deliveryDays,
    dayPrices == null
        ? null
        : Object.hashAll(dayPrices!.entries.map((e) => (e.key, e.value))),
    specialPrice,
    priceMode,
    order,
  );
}

/// One of the photographer's own packages (`Service` in the data model),
/// as the owner edits it. Customers read the same documents through plan
/// 3b1's `ServiceSummary`.
@immutable
class ServicePackage implements PricedService {
  const ServicePackage({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
    this.dayPrices,
    this.specialPrice,
    this.priceMode = PriceMode.twoLevels,
    this.order,
    this.active = true,
  });

  final String id;
  final String name;
  final int priceVnd;
  final int durationMinutes;
  final int? editedCount;
  final int? deliveryDays;
  @override
  final Map<Weekday, int>? dayPrices;
  @override
  final int? specialPrice;
  final PriceMode priceMode;
  final int? order;

  @override
  int get price => priceVnd;

  /// Hidden packages stay in Firestore so posts and bookings keep a valid
  /// `serviceId`; customers never see them.
  final bool active;

  ServicePackageInput get input => ServicePackageInput(
    name: name,
    priceVnd: priceVnd,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
    dayPrices: dayPrices,
    specialPrice: specialPrice,
    priceMode: priceMode,
    order: order,
  );

  ServicePackage copyWith({bool? active, int? order}) => ServicePackage(
    id: id,
    name: name,
    priceVnd: priceVnd,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
    dayPrices: dayPrices,
    specialPrice: specialPrice,
    priceMode: priceMode,
    order: order ?? this.order,
    active: active ?? this.active,
  );

  static ServicePackage from(
    String id,
    ServicePackageInput i, {
    bool active = true,
  }) => ServicePackage(
    id: id,
    name: i.name,
    priceVnd: i.priceVnd,
    durationMinutes: i.durationMinutes,
    editedCount: i.editedCount,
    deliveryDays: i.deliveryDays,
    dayPrices: i.dayPrices,
    specialPrice: i.specialPrice,
    priceMode: i.priceMode,
    order: i.order,
    active: active,
  );

  @override
  bool operator ==(Object other) =>
      other is ServicePackage &&
      other.id == id &&
      other.active == active &&
      other.input == input;

  @override
  int get hashCode => Object.hash(id, active, input);
}

/// `photographers/{uid}/services/{id}` fields written by the client.
///
/// `price` is Monday's price; `dayPrices` is left out when all 7 days cost the
/// same (one price), and then so is `priceMode`.
Map<String, dynamic> packageToFirestore(ServicePackageInput p) {
  final prices = p.dayPrices == null
      ? (price: p.priceVnd, dayPrices: null)
      : normalizeDayPrices(p.dayPrices!);
  return {
    'name': p.name,
    'price': prices.price,
    if (prices.dayPrices != null) ...{
      'dayPrices': dayPricesToMap(prices.dayPrices!),
      'priceMode': p.priceMode.code,
    },
    'specialPrice': ?p.specialPrice,
    'order': ?p.order,
    'durationMinutes': p.durationMinutes,
    'deliverables': {
      'editedCount': ?p.editedCount,
      'deliveryDays': ?p.deliveryDays,
    },
  };
}

/// The optional price fields [packageToFirestore] left out; an update must
/// delete them from the document (`order` is kept: only `reorder` sets it).
const kPackagePriceFields = ['dayPrices', 'specialPrice', 'priceMode'];

ServicePackage? packageFromFirestore(String id, Map<String, dynamic> d) {
  final name = d['name'];
  final price = d['price'];
  final duration = d['durationMinutes'];
  if (name is! String || price is! int || price <= 0) {
    return null;
  }
  final raw = d['deliverables'];
  final del = raw is Map ? raw : const {};
  final edited = del['editedCount'];
  final days = del['deliveryDays'];
  final special = d['specialPrice'];
  final order = d['order'];
  return ServicePackage(
    id: id,
    name: name,
    priceVnd: price,
    durationMinutes: duration is int ? duration : 60,
    editedCount: edited is int ? edited : null,
    deliveryDays: days is int ? days : null,
    dayPrices: dayPricesFromMap(d['dayPrices']),
    specialPrice: special is int && special > 0 ? special : null,
    priceMode: PriceMode.fromCode(d['priceMode']),
    order: order is int ? order : null,
    active: d['active'] != false,
  );
}

/// Packages in the owner's order: by `order`, those without one last, then
/// as given (creation order).
List<ServicePackage> sortedPackages(Iterable<ServicePackage> packages) {
  final indexed = packages.toList().asMap().entries.toList()
    ..sort((a, b) {
      final x = a.value.order ?? 1 << 30;
      final y = b.value.order ?? 1 << 30;
      return x != y ? x.compareTo(y) : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

abstract class ServicePackageRepository {
  /// The photographer's packages, active and hidden, by `order` then oldest
  /// first; live.
  Stream<List<ServicePackage>> watchMine(String uid);

  Future<ServicePackage> add(String uid, ServicePackageInput input);
  Future<void> update(String uid, String id, ServicePackageInput input);

  /// Sets `active: false`; packages are never deleted from the client.
  Future<void> hide(String uid, String id);

  /// Shows or hides a package; [hide] is `setActive(uid, id, false)`.
  Future<void> setActive(String uid, String id, bool active);

  /// Sets `order` 0..n-1 on [idsInOrder], in one batch.
  Future<void> reorder(String uid, List<String> idsInOrder);
}

class FakeServicePackageRepository implements ServicePackageRepository {
  FakeServicePackageRepository({this.failWrites = false});

  bool failWrites;
  int watchers = 0;
  int writes = 0;
  int _seq = 0;
  final _packages = <String, List<ServicePackage>>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, ServicePackage p) {
    (_packages[uid] ??= []).add(p);
    _changes.add(uid);
  }

  List<ServicePackage> stored(String uid) =>
      List.unmodifiable(sortedPackages(_packages[uid] ?? const []));

  @override
  Stream<List<ServicePackage>> watchMine(String uid) {
    late final StreamController<List<ServicePackage>> out;
    StreamSubscription<String>? inner;
    out = StreamController<List<ServicePackage>>(
      onListen: () {
        watchers++;
        out.add(stored(uid));
        inner = _changes.stream
            .where((u) => u == uid)
            .listen((_) => out.add(stored(uid)));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  void _check() {
    if (failWrites) {
      throw StateError('unavailable');
    }
    writes++;
  }

  void _replace(
    String uid,
    String id,
    ServicePackage Function(ServicePackage) change,
  ) {
    final list = _packages[uid] ?? [];
    final i = list.indexWhere((p) => p.id == id);
    if (i < 0) {
      throw StateError('no package $id');
    }
    list[i] = change(list[i]);
    _changes.add(uid);
  }

  @override
  Future<ServicePackage> add(String uid, ServicePackageInput input) async {
    _check();
    final p = ServicePackage.from('pkg-${++_seq}', input);
    seed(uid, p);
    return p;
  }

  @override
  Future<void> update(String uid, String id, ServicePackageInput input) async {
    _check();
    _replace(
      uid,
      id,
      (old) => ServicePackage.from(
        id,
        input.order == null
            ? ServicePackageInput(
                name: input.name,
                priceVnd: input.priceVnd,
                durationMinutes: input.durationMinutes,
                editedCount: input.editedCount,
                deliveryDays: input.deliveryDays,
                dayPrices: input.dayPrices,
                specialPrice: input.specialPrice,
                priceMode: input.priceMode,
                order: old.order,
              )
            : input,
        active: old.active,
      ),
    );
  }

  @override
  Future<void> hide(String uid, String id) async {
    _check();
    _replace(uid, id, (old) => old.copyWith(active: false));
  }

  @override
  Future<void> setActive(String uid, String id, bool active) async {
    _check();
    _replace(uid, id, (old) => old.copyWith(active: active));
  }

  @override
  Future<void> reorder(String uid, List<String> idsInOrder) async {
    _check();
    final list = _packages[uid] ?? [];
    for (final id in idsInOrder) {
      if (!list.any((p) => p.id == id)) {
        throw StateError('no package $id');
      }
    }
    for (var i = 0; i < idsInOrder.length; i++) {
      final at = list.indexWhere((p) => p.id == idsInOrder[i]);
      list[at] = list[at].copyWith(order: i);
    }
    _changes.add(uid);
  }
}
