import 'dart:async';

import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';

/// In-memory [AddonRepository]: seed add-ons, record saves and deletes, and
/// fail the next call with a server code.
class FakeAddonRepository implements AddonRepository {
  final Map<String, ServiceAddon> addons = {};
  final saves = <({AddonInput input, String? addonId})>[];
  final deletes = <String>[];

  /// The next `save`/`delete` throws `AddonException(code, field: ...)`.
  String? nextErrorCode;
  String? nextErrorField;

  final _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  void seed(ServiceAddon addon) {
    addons[addon.id] = addon;
    _changes.add(null);
  }

  void _maybeFail() {
    final code = nextErrorCode;
    if (code == null) return;
    final field = nextErrorField;
    nextErrorCode = null;
    nextErrorField = null;
    throw AddonException(code, field: field);
  }

  List<ServiceAddon> _of(String uid, {required bool onlyActive}) {
    final list = addons.values
        .where((a) => a.providerId == uid && (!onlyActive || a.active))
        .toList();
    list.sort((a, b) {
      final k = a.kind.index.compareTo(b.kind.index);
      return k != 0 ? k : a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  Future<List<ServiceAddon>> activeFor(String providerId) async =>
      _of(providerId, onlyActive: true);

  @override
  Stream<List<ServiceAddon>> watchMine(String uid) async* {
    yield _of(uid, onlyActive: false);
    await for (final _ in _changes.stream) {
      yield _of(uid, onlyActive: false);
    }
  }

  @override
  Future<String> save(AddonInput input, {String? addonId}) async {
    _maybeFail();
    saves.add((input: input, addonId: addonId));
    return addonId ?? 'addon_${_nextId++}';
  }

  @override
  Future<void> delete(String addonId) async {
    _maybeFail();
    deletes.add(addonId);
    addons.remove(addonId);
    _changes.add(null);
  }
}
