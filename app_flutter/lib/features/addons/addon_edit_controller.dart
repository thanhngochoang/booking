import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';

/// Saves or deletes one add-on from the S08.07 sheet. The state is loading
/// while a call runs (the sheet locks the form and shows the button's
/// spinner). Each call answers null on success, else what went wrong.
class AddonEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AddonError?> save(AddonInput input, {String? addonId}) => _run(
    () => ref.read(addonRepositoryProvider).save(input, addonId: addonId),
  );

  Future<AddonError?> delete(String addonId) =>
      _run(() => ref.read(addonRepositoryProvider).delete(addonId));

  Future<AddonError?> _run(Future<void> Function() job) async {
    state = const AsyncLoading();
    try {
      await job();
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = const AsyncData(null);
      return addonErrorOf(e);
    }
  }
}

final addonEditControllerProvider =
    AsyncNotifierProvider.autoDispose<AddonEditController, void>(
      AddonEditController.new,
    );
