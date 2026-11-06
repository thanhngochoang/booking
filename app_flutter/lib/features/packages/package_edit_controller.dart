import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

const kPackageNameMin = 2;
const kPackageNameMax = 60;
const kCountMax = 2000;
const kDeliveryMaxDays = 90;

/// Where an error of the editor shows.
enum PackageEditField {
  name,
  duration,
  edited,
  delivery,
  weekday,
  weekend,
  special,
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun,
}

PackageEditField dayField(Weekday w) => PackageEditField.values.byName(w.name);

enum PackageError {
  nameLength,
  priceRequired,
  priceTooHigh,
  durationRequired,
  countInvalid,
  daysInvalid,
}

/// What [PackageEditController.setMode] did.
enum ModeChange {
  done,

  /// Going from "Từng ngày" to "Hai mức giá" while the 7 prices are not two
  /// levels: ask first, then call `collapseToTwoLevels`.
  needsCollapseConfirm,
}

enum SaveOutcome { saved, invalid, failed }

/// Which package the editor opens: [id] null for a new one. [fromSetup] is
/// S08.01 step 2 adding a package: its typed values are kept as a device
/// draft until saved.
typedef PackageEditArgs = ({String? id, bool fromSetup});

bool _priceOk(int? v) => v != null && v >= 1 && v <= kMaxPriceVnd;

PackageError? _priceError(int? v) => v == null || v <= 0
    ? PackageError.priceRequired
    : v > kMaxPriceVnd
    ? PackageError.priceTooHigh
    : null;

/// The package editor as typed (S08.09).
@immutable
class PackageEditState {
  const PackageEditState({
    this.name = '',
    this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
    this.mode = PriceMode.twoLevels,
    this.weekday,
    this.weekend,
    this.weekendTouched = false,
    this.perDay = const {},
    this.specialOn = false,
    this.specialPrice,
    this.errors = const {},
    this.saving = false,
    this.active = true,
  });

  final String name;
  final int? durationMinutes;
  final int? editedCount;
  final int? deliveryDays;
  final PriceMode mode;

  /// "Hai mức giá": Monday to Friday, and Saturday and Sunday. The weekend
  /// follows the weekday price until it is typed ([weekendTouched]).
  final int? weekday;
  final int? weekend;
  final bool weekendTouched;

  /// "Từng ngày": one price per weekday.
  final Map<Weekday, int?> perDay;
  final bool specialOn;
  final int? specialPrice;
  final Map<PackageEditField, PackageError> errors;
  final bool saving;

  /// A package being edited that is shown to customers ("Ẩn gói" applies).
  final bool active;

  PackageEditState copyWith({
    String? name,
    Object? durationMinutes = _keep,
    Object? editedCount = _keep,
    Object? deliveryDays = _keep,
    PriceMode? mode,
    Object? weekday = _keep,
    Object? weekend = _keep,
    bool? weekendTouched,
    Map<Weekday, int?>? perDay,
    bool? specialOn,
    Object? specialPrice = _keep,
    Map<PackageEditField, PackageError>? errors,
    bool? saving,
  }) => PackageEditState(
    name: name ?? this.name,
    durationMinutes: identical(durationMinutes, _keep)
        ? this.durationMinutes
        : durationMinutes as int?,
    editedCount: identical(editedCount, _keep)
        ? this.editedCount
        : editedCount as int?,
    deliveryDays: identical(deliveryDays, _keep)
        ? this.deliveryDays
        : deliveryDays as int?,
    mode: mode ?? this.mode,
    weekday: identical(weekday, _keep) ? this.weekday : weekday as int?,
    weekend: identical(weekend, _keep) ? this.weekend : weekend as int?,
    weekendTouched: weekendTouched ?? this.weekendTouched,
    perDay: perDay ?? this.perDay,
    specialOn: specialOn ?? this.specialOn,
    specialPrice: identical(specialPrice, _keep)
        ? this.specialPrice
        : specialPrice as int?,
    errors: errors ?? this.errors,
    saving: saving ?? this.saving,
    active: active,
  );

  PackageEditState withActive(bool value) => PackageEditState(
    name: name,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
    mode: mode,
    weekday: weekday,
    weekend: weekend,
    weekendTouched: weekendTouched,
    perDay: perDay,
    specialOn: specialOn,
    specialPrice: specialPrice,
    errors: errors,
    saving: saving,
    active: value,
  );

  PackageEditState _withoutError(PackageEditField f) =>
      errors.containsKey(f) ? copyWith(errors: {...errors}..remove(f)) : this;

  /// The 7 prices as typed, or null while one is missing or out of range.
  Map<Weekday, int>? get weekPrices {
    if (mode == PriceMode.twoLevels) {
      final a = weekday;
      final b = weekend;
      if (!_priceOk(a) || !_priceOk(b)) {
        return null;
      }
      return {for (final w in Weekday.values) w: w.isWeekend ? b! : a!};
    }
    final out = <Weekday, int>{};
    for (final w in Weekday.values) {
      final v = perDay[w];
      if (!_priceOk(v)) {
        return null;
      }
      out[w] = v!;
    }
    return out;
  }

  /// What the 7-day preview prices; null until the prices are valid.
  PricedService? get previewService {
    final prices = weekPrices;
    if (prices == null) {
      return null;
    }
    final n = normalizeDayPrices(prices);
    return _Priced(
      price: n.price,
      dayPrices: n.dayPrices,
      specialPrice: specialOn && _priceOk(specialPrice) ? specialPrice : null,
    );
  }

  /// The errors, or the package to save when there are none.
  ({Map<PackageEditField, PackageError> errors, ServicePackageInput? input})
  validate() {
    final errors = <PackageEditField, PackageError>{};
    final n = name.trim();
    if (n.length < kPackageNameMin || n.length > kPackageNameMax) {
      errors[PackageEditField.name] = PackageError.nameLength;
    }
    final d = durationMinutes;
    if (d == null || !kPackageDurationsMinutes.contains(d)) {
      errors[PackageEditField.duration] = PackageError.durationRequired;
    }
    final e = editedCount;
    if (e != null && (e < 0 || e > kCountMax)) {
      errors[PackageEditField.edited] = PackageError.countInvalid;
    }
    final dl = deliveryDays;
    if (dl != null && (dl < 0 || dl > kDeliveryMaxDays)) {
      errors[PackageEditField.delivery] = PackageError.daysInvalid;
    }
    void price(PackageEditField f, int? v) {
      final err = _priceError(v);
      if (err != null) {
        errors[f] = err;
      }
    }

    if (mode == PriceMode.twoLevels) {
      price(PackageEditField.weekday, weekday);
      price(PackageEditField.weekend, weekend);
    } else {
      for (final w in Weekday.values) {
        price(dayField(w), perDay[w]);
      }
    }
    if (specialOn) {
      price(PackageEditField.special, specialPrice);
    }
    final prices = weekPrices;
    if (errors.isNotEmpty || prices == null) {
      return (errors: errors, input: null);
    }
    final normal = normalizeDayPrices(prices);
    return (
      errors: const {},
      input: ServicePackageInput(
        name: n,
        priceVnd: normal.price,
        durationMinutes: d!,
        editedCount: e,
        deliveryDays: dl,
        dayPrices: normal.dayPrices,
        specialPrice: specialOn ? specialPrice : null,
        // One price on all days has no `dayPrices`, so no mode to keep.
        priceMode: normal.dayPrices == null ? PriceMode.twoLevels : mode,
      ),
    );
  }
}

const Object _keep = Object();

class _Priced extends PricedService {
  const _Priced({required super.price, super.dayPrices, super.specialPrice});
}

/// The editor's state of an existing package.
PackageEditState packageEditStateOf(ServicePackage p) {
  final prices = weekPrices(p);
  return PackageEditState(
    name: p.name,
    durationMinutes: p.durationMinutes,
    editedCount: p.editedCount,
    deliveryDays: p.deliveryDays,
    mode: p.priceMode,
    weekday: prices[Weekday.mon],
    weekend: prices[Weekday.sat],
    weekendTouched: true,
    perDay: {for (final w in Weekday.values) w: prices[w]},
    specialOn: p.specialPrice != null,
    specialPrice: p.specialPrice,
    active: p.active,
  );
}

/// The packages as the stream first reports them; the subscription is
/// dropped at once.
Future<List<ServicePackage>> _firstPackages(
  ServicePackageRepository repo,
  String uid,
) {
  final done = Completer<List<ServicePackage>>();
  late final StreamSubscription<List<ServicePackage>> sub;
  sub = repo
      .watchMine(uid)
      .listen(
        (list) {
          if (!done.isCompleted) {
            done.complete(list);
          }
          unawaited(sub.cancel());
        },
        onError: (Object e, StackTrace st) {
          if (!done.isCompleted) {
            done.completeError(e, st);
          }
          unawaited(sub.cancel());
        },
      );
  return done.future;
}

/// S08.09: edits one package, or a new one, and saves it. Each call answers
/// what happened; the screen shows the message.
class PackageEditController extends AsyncNotifier<PackageEditState> {
  PackageEditController(this.args);

  final PackageEditArgs args;

  bool get _isNew => args.id == null;

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  @override
  Future<PackageEditState> build() async {
    final uid = _uid;
    final id = args.id;
    if (id == null) {
      final draft = args.fromSetup && uid != null
          ? ref.read(setupDraftStoreProvider).package(uid)
          : null;
      if (draft == null) {
        return const PackageEditState();
      }
      final weekday = parseVnd(draft.price);
      return PackageEditState(
        name: draft.name,
        durationMinutes: draft.durationMinutes,
        editedCount: int.tryParse(draft.edited),
        deliveryDays: int.tryParse(draft.delivery),
        weekday: weekday,
        weekend: weekday,
      );
    }
    if (uid == null) {
      throw StateError('not signed in');
    }
    final all = await _firstPackages(
      ref.read(servicePackageRepositoryProvider),
      uid,
    );
    final p = all.where((x) => x.id == id).firstOrNull;
    if (p == null) {
      throw StateError('no package $id');
    }
    return packageEditStateOf(p);
  }

  void _edit(
    PackageEditState Function(PackageEditState s) change, {
    PackageEditField? clears,
  }) {
    final s = state.value;
    if (s == null || s.saving) {
      return;
    }
    var next = change(s);
    if (clears != null) {
      next = next._withoutError(clears);
    }
    state = AsyncData(next);
    _persistDraft(next);
  }

  void _persistDraft(PackageEditState s) {
    final uid = _uid;
    if (!_isNew || !args.fromSetup || uid == null) {
      return;
    }
    ref
        .read(setupDraftStoreProvider)
        .savePackage(
          uid,
          PackageDraft(
            name: s.name,
            price: s.weekday == null ? '' : groupVnd(s.weekday!),
            durationMinutes: s.durationMinutes,
            edited: s.editedCount?.toString() ?? '',
            delivery: s.deliveryDays?.toString() ?? '',
          ),
        );
  }

  void setName(String v) =>
      _edit((s) => s.copyWith(name: v), clears: PackageEditField.name);

  void setDuration(int minutes) => _edit(
    (s) => s.copyWith(durationMinutes: minutes),
    clears: PackageEditField.duration,
  );

  void setEdited(int? v) =>
      _edit((s) => s.copyWith(editedCount: v), clears: PackageEditField.edited);

  void setDelivery(int? v) => _edit(
    (s) => s.copyWith(deliveryDays: v),
    clears: PackageEditField.delivery,
  );

  /// The weekday price; the weekend follows it until it has been typed.
  void setWeekday(int? v) => _edit((s) {
    final next = s.copyWith(weekday: v);
    return s.weekendTouched
        ? next
        : next.copyWith(weekend: v)._withoutError(PackageEditField.weekend);
  }, clears: PackageEditField.weekday);

  void setWeekend(int? v) => _edit(
    (s) => s.copyWith(weekend: v, weekendTouched: true),
    clears: PackageEditField.weekend,
  );

  void setDay(Weekday d, int? v) => _edit(
    (s) => s.copyWith(perDay: {...s.perDay, d: v}),
    clears: dayField(d),
  );

  /// Turns the special price on or off; [price] sets it when given.
  void setSpecial(bool on, [int? price]) => _edit(
    (s) => s.copyWith(specialOn: on, specialPrice: price ?? s.specialPrice),
    clears: on ? null : PackageEditField.special,
  );

  void setSpecialPrice(int? v) => _edit(
    (s) => s.copyWith(specialPrice: v),
    clears: PackageEditField.special,
  );

  /// "Hai mức giá" ↔ "Từng ngày". To per day fills the 7 prices from the two;
  /// back to two levels asks first when the 7 are not two levels.
  ModeChange setMode(PriceMode to) {
    final s = state.value;
    if (s == null || s.saving || s.mode == to) {
      return ModeChange.done;
    }
    if (to == PriceMode.perDay) {
      _edit(
        (s) => s.copyWith(
          mode: to,
          perDay: {
            for (final w in Weekday.values)
              w: w.isWeekend ? s.weekend : s.weekday,
          },
          errors: const {},
        ),
      );
      return ModeChange.done;
    }
    final mon = s.perDay[Weekday.mon];
    final weekdays = [Weekday.tue, Weekday.wed, Weekday.thu, Weekday.fri];
    final isTwoLevels =
        weekdays.every((d) => s.perDay[d] == mon) &&
        s.perDay[Weekday.sat] == s.perDay[Weekday.sun];
    if (!isTwoLevels) {
      return ModeChange.needsCollapseConfirm;
    }
    _edit(
      (s) => s.copyWith(
        mode: to,
        weekday: mon,
        weekend: s.perDay[Weekday.sat],
        weekendTouched: true,
        errors: const {},
      ),
    );
    return ModeChange.done;
  }

  /// Confirmed "Dùng hai mức": Monday for the weekdays, Saturday for the
  /// weekend.
  void collapseToTwoLevels() => _edit(
    (s) => s.copyWith(
      mode: PriceMode.twoLevels,
      weekday: s.perDay[Weekday.mon],
      weekend: s.perDay[Weekday.sat],
      weekendTouched: true,
      errors: const {},
    ),
  );

  Future<SaveOutcome> save() async {
    final s = state.value;
    final uid = _uid;
    if (s == null || s.saving || uid == null) {
      return SaveOutcome.failed;
    }
    final check = s.validate();
    final input = check.input;
    if (input == null) {
      state = AsyncData(s.copyWith(errors: check.errors));
      return SaveOutcome.invalid;
    }
    final repo = ref.read(servicePackageRepositoryProvider);
    final drafts = ref.read(setupDraftStoreProvider);
    state = AsyncData(s.copyWith(saving: true, errors: const {}));
    try {
      final id = args.id;
      if (id == null) {
        await repo.add(uid, input);
      } else {
        await repo.update(uid, id, input);
      }
      await drafts.clearPackage(uid);
      state = AsyncData(s.copyWith(saving: false));
      return SaveOutcome.saved;
    } on Object {
      state = AsyncData(s.copyWith(saving: false));
      return SaveOutcome.failed;
    }
  }

  /// "Ẩn gói": the package stays for bookings and posts.
  Future<bool> hide() async {
    final id = args.id;
    final uid = _uid;
    final s = state.value;
    if (id == null || uid == null || s == null || s.saving) {
      return false;
    }
    final repo = ref.read(servicePackageRepositoryProvider);
    state = AsyncData(s.copyWith(saving: true));
    try {
      await repo.hide(uid, id);
      state = AsyncData(s.copyWith(saving: false).withActive(false));
      return true;
    } on Object {
      state = AsyncData(s.copyWith(saving: false));
      return false;
    }
  }
}

final packageEditControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PackageEditController, PackageEditState, PackageEditArgs>(
      PackageEditController.new,
    );
