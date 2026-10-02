import 'dart:async';

import 'package:flutter/foundation.dart';

/// Durations a package can have (spec S08.01: 1, 2, 3, 4, 6 or 8 hours).
const kPackageDurationsMinutes = [60, 120, 180, 240, 360, 480];

/// What the photographer types for a package. Money is whole VND.
@immutable
class ServicePackageInput {
  const ServicePackageInput({
    required this.name,
    required this.priceVnd,
    required this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
  });

  final String name;
  final int priceVnd;
  final int durationMinutes;
  final int? editedCount;
  final int? deliveryDays;

  @override
  bool operator ==(Object other) =>
      other is ServicePackageInput &&
      other.name == name &&
      other.priceVnd == priceVnd &&
      other.durationMinutes == durationMinutes &&
      other.editedCount == editedCount &&
      other.deliveryDays == deliveryDays;

  @override
  int get hashCode =>
      Object.hash(name, priceVnd, durationMinutes, editedCount, deliveryDays);
}

/// One of the photographer's own packages (`Service` in the data model),
/// as the owner edits it. Customers read the same documents through plan
/// 3b1's `ServiceSummary`.
@immutable
class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
    this.active = true,
  });

  final String id;
  final String name;
  final int priceVnd;
  final int durationMinutes;
  final int? editedCount;
  final int? deliveryDays;

  /// Hidden packages stay in Firestore so posts and bookings keep a valid
  /// `serviceId`; customers never see them.
  final bool active;

  ServicePackageInput get input => ServicePackageInput(
    name: name,
    priceVnd: priceVnd,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
  );

  ServicePackage copyWith({bool? active}) => ServicePackage(
    id: id,
    name: name,
    priceVnd: priceVnd,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
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
Map<String, dynamic> packageToFirestore(ServicePackageInput p) => {
  'name': p.name,
  'price': p.priceVnd,
  'durationMinutes': p.durationMinutes,
  'deliverables': {
    'editedCount': ?p.editedCount,
    'deliveryDays': ?p.deliveryDays,
  },
};

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
  return ServicePackage(
    id: id,
    name: name,
    priceVnd: price,
    durationMinutes: duration is int ? duration : 60,
    editedCount: edited is int ? edited : null,
    deliveryDays: days is int ? days : null,
    active: d['active'] != false,
  );
}

abstract class ServicePackageRepository {
  /// The photographer's packages, active and hidden, oldest first; live.
  Stream<List<ServicePackage>> watchMine(String uid);

  Future<ServicePackage> add(String uid, ServicePackageInput input);
  Future<void> update(String uid, String id, ServicePackageInput input);

  /// Sets `active: false`; packages are never deleted from the client.
  Future<void> hide(String uid, String id);
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
      List.unmodifiable(_packages[uid] ?? const []);

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
      (old) => ServicePackage.from(id, input, active: old.active),
    );
  }

  @override
  Future<void> hide(String uid, String id) async {
    _check();
    _replace(uid, id, (old) => old.copyWith(active: false));
  }
}
