import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show kMaxPriceVnd;
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

const kPackageNameMin = 2;
const kPackageNameMax = 60;
const kCountMax = 2000;
const kDeliveryMaxDays = 90;

/// Where an error of the editor shows.
enum PackageEditField { name, duration, edited, delivery, price }

enum PackageError {
  nameLength,
  priceRequired,
  priceTooHigh,
  durationRequired,
  countInvalid,
  daysInvalid,
}

enum SaveOutcome { saved, invalid, failed }

/// Which package the editor opens: [id] null for a new one. [fromSetup] is
/// S08.01 step 2 adding a package: its typed values are kept as a device
/// draft until saved.
typedef PackageEditArgs = ({String? id, bool fromSetup});

PackageError? _priceError(int? v) => v == null || v <= 0
    ? PackageError.priceRequired
    : v > kMaxPriceVnd
    ? PackageError.priceTooHigh
    : null;

/// What the form holds, to tell whether anything changed since it opened.
typedef PackageValues = ({
  String name,
  int? durationMinutes,
  int? editedCount,
  int? deliveryDays,
  int? price,
});

/// The package editor as typed (S08.09): the four details and the one price
/// of an ordinary day.
@immutable
class PackageEditState {
  const PackageEditState({
    this.name = '',
    this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
    this.price,
    this.errors = const {},
    this.saving = false,
    this.active = true,
    PackageValues? opened,
  }) : _opened = opened; // ignore: prefer_initializing_formals

  final String name;
  final int? durationMinutes;
  final int? editedCount;
  final int? deliveryDays;

  /// "Giá ngày thường", whole đồng.
  final int? price;
  final Map<PackageEditField, PackageError> errors;
  final bool saving;

  /// A package being edited that is shown to customers ("Ẩn gói" applies).
  final bool active;

  /// The values the form opened with; null means "empty form".
  final PackageValues? _opened;

  PackageValues get _values => (
    name: name,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
    price: price,
  );

  /// Something differs from what the form opened with (a new package: anything
  /// typed), so leaving asks "Bỏ thay đổi?".
  bool get dirty =>
      _values !=
      (_opened ??
          (
            name: '',
            durationMinutes: null,
            editedCount: null,
            deliveryDays: null,
            price: null,
          ));

  PackageEditState copyWith({
    String? name,
    Object? durationMinutes = _keep,
    Object? editedCount = _keep,
    Object? deliveryDays = _keep,
    Object? price = _keep,
    Map<PackageEditField, PackageError>? errors,
    bool? saving,
    bool? active,
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
    price: identical(price, _keep) ? this.price : price as int?,
    errors: errors ?? this.errors,
    saving: saving ?? this.saving,
    active: active ?? this.active,
    opened: _opened,
  );

  /// The same form, taken as unchanged (after a successful save).
  PackageEditState get asOpened => PackageEditState(
    name: name,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
    price: price,
    errors: errors,
    saving: saving,
    active: active,
    opened: _values,
  );

  PackageEditState _withoutError(PackageEditField f) =>
      errors.containsKey(f) ? copyWith(errors: {...errors}..remove(f)) : this;

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
    final priceError = _priceError(price);
    if (priceError != null) {
      errors[PackageEditField.price] = priceError;
    }
    if (errors.isNotEmpty) {
      return (errors: errors, input: null);
    }
    return (
      errors: const {},
      input: ServicePackageInput(
        name: n,
        priceVnd: price!,
        durationMinutes: d!,
        editedCount: e,
        deliveryDays: dl,
      ),
    );
  }
}

const Object _keep = Object();

/// The editor's state of an existing package.
PackageEditState packageEditStateOf(ServicePackage p) => PackageEditState(
  name: p.name,
  durationMinutes: p.durationMinutes,
  editedCount: p.editedCount,
  deliveryDays: p.deliveryDays,
  price: p.priceVnd,
  active: p.active,
).asOpened;

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
      // A device draft is typed but unsaved, so it counts as a change.
      return PackageEditState(
        name: draft.name,
        durationMinutes: draft.durationMinutes,
        editedCount: int.tryParse(draft.edited),
        deliveryDays: int.tryParse(draft.delivery),
        price: parseVnd(draft.price),
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
            price: s.price == null ? '' : groupVnd(s.price!),
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

  void setPrice(int? v) =>
      _edit((s) => s.copyWith(price: v), clears: PackageEditField.price);

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
      state = AsyncData(s.copyWith(saving: false).asOpened);
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
      state = AsyncData(s.copyWith(saving: false, active: false));
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
