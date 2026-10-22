// S13.01: price list, the customer's position and "Xem nhiếp ảnh gia phù hợp".
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant/instant_draft.dart';

/// A refusal S13.01 shows in place (not as a toast).
enum InstantRequestProblem {
  /// "Tên điểm hẹn" is empty: the line under the field.
  meetPointRequired,

  /// `outside_service_area`: the line with "Đặt lịch thường".
  outsideArea,

  /// `not_eligible`: Chụp ngay is paused.
  disabled,
}

/// What S13.01 shows.
class InstantRequestView {
  const InstantRequestView({
    required this.config,
    required this.permission,
    this.position,
    this.busy = false,
    this.error,
  });

  final InstantConfig config;
  final LocationPermissionStatus permission;

  /// The meet point's GPS fix; null shows `#S13.01-noloc` (Chụp ngay needs
  /// a position, Decision 3).
  final LocationFix? position;

  /// A request is being created: the primary button shows its loader.
  final bool busy;
  final InstantRequestProblem? error;

  InstantRequestView copyWith({
    LocationPermissionStatus? permission,
    LocationFix? position,
    bool? busy,
    InstantRequestProblem? error,
    bool clearError = false,
    bool clearPosition = false,
  }) => InstantRequestView(
    config: config,
    permission: permission ?? this.permission,
    position: clearPosition ? null : (position ?? this.position),
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

/// What "Xem nhiếp ảnh gia phù hợp" led to; the screen navigates.
sealed class InstantSubmit {
  const InstantSubmit();
}

/// Created: open `/instant/{requestId}`.
final class InstantSubmitCreated extends InstantSubmit {
  const InstantSubmitCreated(this.requestId);
  final String requestId;
}

/// No phone number (app check or server `phone_required`): S04.05 first,
/// the draft keeps everything.
final class InstantSubmitNeedsPhone extends InstantSubmit {
  const InstantSubmitNeedsPhone();
}

/// `conflict`: the customer already has an open request ([requestId], null
/// when it could not be read).
final class InstantSubmitHasActive extends InstantSubmit {
  const InstantSubmitHasActive(this.requestId);
  final String? requestId;
}

/// Shown in place: [InstantRequestView.error] says what.
final class InstantSubmitRefused extends InstantSubmit {
  const InstantSubmitRefused();
}

/// Anything else (network, unknown): a toast.
final class InstantSubmitFailed extends InstantSubmit {
  const InstantSubmitFailed(this.error);
  final Object error;
}

/// Owns S13.01. Opening asks for the location once when it was never asked
/// (tapping "Chụp ngay" is the reason); a refusal shows the no-location view.
/// Fixes are low power: the meet point does not need GPS grade.
class InstantRequestController extends AsyncNotifier<InstantRequestView> {
  bool _locating = false;

  LocationRepository get _location => ref.read(locationRepositoryProvider);

  @override
  Future<InstantRequestView> build() async {
    _locating = false;
    final config = await ref.watch(instantConfigProvider.future);
    // Nothing to choose: the error state (with retry), not a dead button.
    if (config.packages.isEmpty) throw const InstantError('not_eligible');
    var permission = await _location.permissionStatus();
    if (permission == LocationPermissionStatus.notAsked) {
      permission = await _ask();
    }
    final fix = permission == LocationPermissionStatus.granted
        ? await _location.currentFix()
        : null;
    return InstantRequestView(
      config: config,
      permission: permission,
      position: fix,
    );
  }

  Future<LocationPermissionStatus> _ask() async {
    try {
      return await _location.request();
    } on Object {
      return LocationPermissionStatus.denied;
    }
  }

  void _set(InstantRequestView Function(InstantRequestView v) change) {
    final v = state.value;
    if (v == null || !ref.mounted) return;
    state = AsyncData(change(v));
  }

  /// The map's "Về vị trí của tôi": a new fix. No fix keeps the last one;
  /// a permission taken back (in Settings) drops it.
  Future<void> refreshLocation() async {
    if (_locating || state.value == null) return;
    _locating = true;
    try {
      final permission = await _location.permissionStatus();
      final granted = permission == LocationPermissionStatus.granted;
      final fix = granted ? await _location.currentFix() : null;
      _set(
        (v) => v.copyWith(
          permission: permission,
          position: fix,
          clearPosition: !granted,
        ),
      );
    } finally {
      _locating = false;
    }
  }

  /// "Cho phép vị trí": asks the OS when it still can; refused for good
  /// opens the app's settings, location off the system location switch;
  /// granted → a fix.
  Future<void> allowLocation() async {
    if (_locating || state.value == null) return;
    _locating = true;
    try {
      var permission = await _location.permissionStatus();
      if (permission == LocationPermissionStatus.serviceOff) {
        await _location.openLocationSettings();
        return;
      }
      if (permission == LocationPermissionStatus.deniedForever) {
        await _location.openSettings();
        return;
      }
      if (permission != LocationPermissionStatus.granted) {
        permission = await _ask();
      }
      final fix = permission == LocationPermissionStatus.granted
          ? await _location.currentFix()
          : null;
      _set((v) => v.copyWith(permission: permission, position: fix));
    } finally {
      _locating = false;
    }
  }

  /// Back in the app (from Settings): takes a fix if there is none yet.
  Future<void> resumed() async {
    final v = state.value;
    if (v == null || v.position != null) return;
    await refreshLocation();
  }

  /// The customer typed a name: the "required" line goes.
  void clearError() {
    if (state.value?.error == InstantRequestProblem.meetPointRequired) {
      _set((v) => v.copyWith(clearError: true));
    }
  }

  /// Name → phone → `createRequest`; null while a call is in flight or
  /// without a position. The draft is reset only once the request exists.
  /// The controller is kept alive for the call: the customer may leave
  /// S13.01 while it runs, and the request then still resets the draft.
  Future<InstantSubmit?> submit() async {
    final v = state.value;
    final position = v?.position;
    if (v == null || v.busy || position == null) return null;
    final draft = ref.read(instantDraftProvider);
    final name = draft.meetPointName.trim();
    final package = draft.packageOf(v.config.packages);
    if (name.isEmpty) {
      state = AsyncData(
        v.copyWith(error: InstantRequestProblem.meetPointRequired),
      );
      return const InstantSubmitRefused();
    }
    if (package == null) return null;
    state = AsyncData(v.copyWith(busy: true, clearError: true));
    final alive = ref.keepAlive();
    try {
      if (!await _hasPhone()) {
        _set((v) => v.copyWith(busy: false));
        return const InstantSubmitNeedsPhone();
      }
      final note = draft.note.trim();
      final id = await ref
          .read(instantRepositoryProvider)
          .createRequest(
            packageCode: package.code,
            genre: draft.genre,
            lat: position.lat,
            lng: position.lng,
            meetPointName: name,
            note: note.isEmpty ? null : note,
          );
      ref.read(instantDraftProvider.notifier).reset();
      // Home (kept alive by the tab shell) now resumes this request.
      ref.invalidate(instantActiveRequestIdProvider);
      // Stays busy: the screen leaves for the request.
      return InstantSubmitCreated(id);
    } on Object catch (e) {
      final kind = InstantError(instantErrorCodeOf(e)).kind;
      switch (kind) {
        case InstantErrorKind.phoneRequired:
          _set((v) => v.copyWith(busy: false));
          return const InstantSubmitNeedsPhone();
        case InstantErrorKind.outsideServiceArea:
        case InstantErrorKind.notEligible:
          _set(
            (v) => v.copyWith(
              busy: false,
              error: kind == InstantErrorKind.notEligible
                  ? InstantRequestProblem.disabled
                  : InstantRequestProblem.outsideArea,
            ),
          );
          return const InstantSubmitRefused();
        case InstantErrorKind.conflict:
          final active = await _activeRequestId();
          ref.invalidate(instantActiveRequestIdProvider);
          _set((v) => v.copyWith(busy: false));
          return InstantSubmitHasActive(active);
        default:
          _set((v) => v.copyWith(busy: false));
          return InstantSubmitFailed(e);
      }
    } finally {
      alive.close();
    }
  }

  /// The contact read fails closed: no number means S04.05 (as `startBooking`).
  Future<bool> _hasPhone() async {
    // currentContactProvider is autoDispose: hold a listener while we wait.
    final hold = ref.listen(currentContactProvider, (_, _) {});
    try {
      return await ref.read(currentContactProvider.future) != null;
    } on Object {
      return false;
    } finally {
      hold.close();
    }
  }

  Future<String?> _activeRequestId() async {
    try {
      return await ref.read(instantRepositoryProvider).myActiveRequestId();
    } on Object {
      return null;
    }
  }
}

final instantRequestControllerProvider =
    AsyncNotifierProvider.autoDispose<
      InstantRequestController,
      InstantRequestView
    >(InstantRequestController.new);
