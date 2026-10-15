import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';

/// What a switch tap came to.
enum AddonToggleResult { saved, limit, failed }

/// The S08.06 form values of an existing add-on, for a full-record save
/// (Decision 9): every field as stored, with [active] as given.
AddonInput addonInputOf(ServiceAddon a, {required bool active}) => AddonInput(
  kind: a.kind,
  name: a.name,
  description: a.description,
  price: a.price,
  unit: a.unit,
  maxQty: a.maxQty,
  choosePackages: a.serviceIds.isNotEmpty,
  serviceIds: a.serviceIds,
  active: active,
);

/// Turns add-ons on and off from the S08.06 list. State = the value each
/// switch shows while its save is in flight or just done (the live list
/// catches up a moment later); a failed save drops the entry so the switch
/// returns to what is stored.
class AddonsController extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  /// Calls `saveAddon` with the full record and [active] flipped.
  Future<AddonToggleResult> toggle(ServiceAddon addon, bool active) async {
    state = {...state, addon.id: active};
    try {
      await ref
          .read(addonRepositoryProvider)
          .save(addonInputOf(addon, active: active), addonId: addon.id);
      return AddonToggleResult.saved;
    } catch (e) {
      state = {...state}..remove(addon.id);
      return addonErrorOf(e).code == AddonErrorCode.addonLimit
          ? AddonToggleResult.limit
          : AddonToggleResult.failed;
    }
  }

  /// Forgets switch values the stored list already agrees with.
  void sync(List<ServiceAddon> stored) {
    if (state.isEmpty) return;
    final next = {...state};
    for (final a in stored) {
      if (next[a.id] == a.active) next.remove(a.id);
    }
    next.removeWhere((id, _) => !stored.any((a) => a.id == id));
    if (next.length != state.length) state = next;
  }
}

final addonsControllerProvider =
    NotifierProvider.autoDispose<AddonsController, Map<String, bool>>(
      AddonsController.new,
    );
