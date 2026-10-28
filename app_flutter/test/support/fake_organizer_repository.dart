// test/support/fake_organizer_repository.dart
import 'dart:async';

import 'package:flutter/widgets.dart' show StringCharacters;

import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';

/// In-memory organizer data. Enforces what the screens rely on: a verified
/// phone to apply, one pending claim per spot, ≤ 50 residents, ≤ 10 gate
/// staff, 72 h invites. Every call is recorded in [calls] as
/// `(callable, payload)` with the payload the Firestore adapter sends.
class FakeOrganizerRepository implements OrganizerRepository {
  FakeOrganizerRepository({this.uid = 'org1', DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  /// The signed-in user; null = signed out.
  String? uid;
  final DateTime Function() _clock;

  /// `becomeOrganizer` answers `phone_required` without it.
  bool phoneVerified = true;

  /// While set, the next call throws it (then it clears).
  Object? nextError;

  final Map<String, Organizer> organizers = {};
  final Map<String, SpotClaim> claims = {};

  /// Residents by spot id (writes land here; reads go through the spot fake).
  final Map<String, Map<String, Resident>> residents = {};

  /// Gate staff by organizer id, then staff uid.
  final Map<String, Map<String, GateStaff>> gateStaff = {};
  final Map<String, EntryDay> entryDays = {};

  /// Phone → uid the invite lookup finds.
  final Map<String, String> accounts = {};

  final List<(String, Map<String, Object?>)> calls = [];
  final _changes = StreamController<void>.broadcast();
  int _seq = 0;

  void putOrganizer(Organizer o) {
    organizers[o.id] = o;
    _changes.add(null);
  }

  void putClaim(SpotClaim c) {
    claims[c.id] = c;
    _changes.add(null);
  }

  void putGateStaff(GateStaff g) {
    (gateStaff[g.organizerId] ??= {})[g.staffUid] = g;
    _changes.add(null);
  }

  void putEntryDay(EntryDay d) {
    entryDays['${d.eventId}_${d.day}'] = d;
    _changes.add(null);
  }

  void _check() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  String _me() => uid ?? (throw const OrganizerError('permission_denied'));

  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> c;
    StreamSubscription<void>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = _changes.stream.listen((_) => c.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<Organizer?> watchMine() => _watch(() => organizers[uid]);

  @override
  Stream<Organizer?> watch(String uid) => _watch(() => organizers[uid]);

  @override
  Future<Organizer?> becomeOrganizer({
    required String name,
    required String bio,
    PickedImage? avatar,
  }) async {
    _check();
    final me = _me();
    calls.add((
      'becomeOrganizer',
      {
        'name': name,
        'bio': bio,
        if (avatar != null)
          'avatarUrl': 'https://storage.test/avatars/$me/a.jpg',
      },
    ));
    if (!phoneVerified) throw const OrganizerError('phone_required');
    final n = name.trim().characters.length;
    if (n < 3 || n > 60) {
      throw const OrganizerError('invalid_argument', field: 'name');
    }
    final existing = organizers[me];
    if (existing?.status == OrganizerStatus.suspended) {
      throw const OrganizerError('conflict');
    }
    final now = _clock();
    final o =
        (existing ??
                Organizer(
                  id: me,
                  name: name,
                  status: OrganizerStatus.active,
                  phoneVerified: true,
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(name: name.trim(), bio: bio, updatedAt: now);
    putOrganizer(o);
    return o;
  }

  @override
  Future<String> claimSpot({
    String? spotId,
    SpotProposal? proposal,
    required List<PickedImage> proofs,
    String? note,
  }) async {
    _check();
    final me = _me();
    final paths = [
      for (var i = 0; i < proofs.length; i++)
        'spot_claims/$me/f${_seq + 1}/$i.jpg',
    ];
    calls.add((
      'claimSpot',
      {
        'spotId': ?spotId,
        if (spotId == null && proposal != null)
          'proposal': proposal.toCallable(),
        'proofPaths': paths,
        'note': ?note,
      },
    ));
    if (organizers[me]?.isActive != true) {
      throw const OrganizerError('permission_denied');
    }
    if (proofs.isEmpty || proofs.length > 3) {
      throw const OrganizerError('invalid_argument', field: 'proofPaths');
    }
    final pending = claims.values.any(
      (c) =>
          c.organizerId == me &&
          c.status == SpotClaimStatus.pending &&
          c.spotId == spotId,
    );
    if (pending) throw const OrganizerError('limit_exceeded');
    final id = 'claim-${++_seq}';
    putClaim(
      SpotClaim(
        id: id,
        spotId: spotId,
        proposal: spotId == null ? proposal : null,
        organizerId: me,
        status: SpotClaimStatus.pending,
        proofPaths: paths,
        note: note ?? '',
        createdAt: _clock(),
      ),
    );
    return id;
  }

  @override
  Stream<List<SpotClaim>> watchMyClaims() => _watch(
    () =>
        claims.values.where((c) => c.organizerId == uid).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> updateManagedSpot(
    String spotId, {
    String? description,
    List<String>? tips,
    PickedImage? cover,
    OpenHours? openHours,
    SpotAccess? access,
    bool clearAccess = false,
  }) async {
    _check();
    calls.add((
      'updateManagedSpot',
      {
        'spotId': spotId,
        'description': ?description,
        'tips': ?tips,
        if (cover != null) ...{
          'coverPath': 'spots/$spotId/c.jpg',
          'coverUrl': 'https://storage.test/spots/$spotId/c.jpg',
        },
        'openHours': ?openHours?.toCallable(),
        if (access != null)
          'access': access.toCallable()
        else if (clearAccess)
          'access': null,
      },
    ));
    final me = _me();
    if (organizers[me]?.managedSpotIds.contains(spotId) != true) {
      throw const OrganizerError('not_spot_manager');
    }
  }

  @override
  Future<void> saveResident(String spotId, Resident resident) async {
    _check();
    calls.add(('saveResident', resident.toCallable(spotId)));
    final list = residents[spotId] ??= {};
    if (!list.containsKey(resident.providerId) && list.length >= 50) {
      throw const OrganizerError('limit_exceeded');
    }
    list[resident.providerId] = resident.copyWith(
      addedAt: resident.addedAt ?? _clock(),
      addedBy: resident.addedBy ?? uid,
    );
    _changes.add(null);
  }

  @override
  Future<void> removeResident(String spotId, String providerId) async {
    _check();
    calls.add(('removeResident', {'spotId': spotId, 'providerId': providerId}));
    residents[spotId]?.remove(providerId);
    _changes.add(null);
  }

  @override
  Stream<List<GateStaff>> watchGateStaff() => _watch(
    () => [
      for (final g in (gateStaff[uid] ?? const <String, GateStaff>{}).values)
        if (g.status != GateStaffStatus.removed) g,
    ],
  );

  @override
  Stream<List<GateStaff>> watchMyGateInvites() => _watch(
    () => [
      for (final rows in gateStaff.values)
        for (final g in rows.values)
          if (g.staffUid == uid && g.status != GateStaffStatus.removed) g,
    ],
  );

  @override
  Future<void> inviteGateStaff(String target) async {
    _check();
    calls.add(('inviteGateStaff', {'target': target}));
    final me = _me();
    final staffUid = accounts[target];
    if (staffUid == null) throw const OrganizerError('not_found');
    final rows = gateStaff[me] ??= {};
    final live = rows.values.where((g) => g.status != GateStaffStatus.removed);
    if (live.length >= 10) throw const OrganizerError('limit_exceeded');
    putGateStaff(
      GateStaff(
        organizerId: me,
        staffUid: staffUid,
        status: GateStaffStatus.invited,
        invitedAt: _clock(),
      ),
    );
  }

  @override
  Future<void> respondGateStaff(
    String organizerId, {
    required bool accept,
  }) async {
    _check();
    calls.add((
      'respondGateStaff',
      {'organizerId': organizerId, 'accept': accept},
    ));
    final me = _me();
    final g = gateStaff[organizerId]?[me];
    if (g == null) throw const OrganizerError('not_found');
    if (!g.inviteOpen(_clock())) throw const OrganizerError('deadline_passed');
    putGateStaff(
      g.copyWith(
        status: accept ? GateStaffStatus.active : GateStaffStatus.removed,
        respondedAt: _clock(),
      ),
    );
  }

  @override
  Future<void> removeGateStaff(String staffUid) async {
    _check();
    calls.add(('removeGateStaff', {'staffUid': staffUid}));
    final me = _me();
    final g = gateStaff[me]?[staffUid];
    if (g != null) putGateStaff(g.copyWith(status: GateStaffStatus.removed));
  }

  @override
  Stream<EntryDay?> watchEntryDay(String eventId, String day) =>
      _watch(() => entryDays['${eventId}_$day']);

  /// What [closeEntryDay] answers.
  ({int refunded, int left}) closeAnswer = (refunded: 0, left: 0);

  @override
  Future<({int refunded, int left})> closeEntryDay(
    String eventId,
    String day,
  ) async {
    _check();
    calls.add(('closeEntryDay', {'eventId': eventId, 'day': day}));
    final key = '${eventId}_$day';
    putEntryDay(
      (entryDays[key] ?? EntryDay(eventId: eventId, day: day)).copyWith(
        closed: true,
      ),
    );
    return closeAnswer;
  }
}
