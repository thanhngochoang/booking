import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';

/// The writes of S08.08. Each answers whether it went through;
/// the screen says what to tell the user.
class PackagesActions {
  PackagesActions(this._ref);

  final Ref _ref;

  String? get _uid => _ref.read(authRepositoryProvider).currentUser?.uid;

  Future<bool> _run(Future<void> Function(String uid) job) async {
    final uid = _uid;
    if (uid == null) {
      return false;
    }
    try {
      await job(uid);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> setActive(String id, bool active) => _run(
    (uid) =>
        _ref.read(servicePackageRepositoryProvider).setActive(uid, id, active),
  );

  Future<bool> reorder(List<String> idsInOrder) => _run(
    (uid) =>
        _ref.read(servicePackageRepositoryProvider).reorder(uid, idsInOrder),
  );
}

final packagesActionsProvider = Provider<PackagesActions>(PackagesActions.new);
