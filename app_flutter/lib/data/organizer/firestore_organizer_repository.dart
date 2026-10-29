// lib/data/organizer/firestore_organizer_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';

/// Reads `organizers`, `gate_staff`, `spot_claims` and `entry_days` directly
/// (rules: signed-in / own rows); every write is one of the S30 callables.
class FirestoreOrganizerRepository implements OrganizerRepository {
  FirestoreOrganizerRepository({
    required this.uid,
    required this.uploader,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functionsOverride = functions;

  /// The signed-in user; null while signed out (own-data streams are empty).
  final String? uid;
  final MediaUploader uploader;
  final FirebaseFirestore? _override;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  static bool _validId(String id) => id.isNotEmpty && !id.contains('/');

  // ---- reads ----------------------------------------------------------------

  @override
  Stream<Organizer?> watchMine() {
    final me = uid;
    return me == null ? Stream.value(null) : watch(me);
  }

  @override
  Stream<Organizer?> watch(String uid) {
    if (!_validId(uid)) return Stream.value(null);
    return _db
        .collection('organizers')
        .doc(uid)
        .snapshots()
        .map((s) => organizerFromFirestore(s.id, s.data()));
  }

  @override
  Stream<List<SpotClaim>> watchMyClaims() {
    final me = uid;
    if (me == null) return Stream.value(const []);
    // Equality only (the rules need `organizerId == uid`); sorted here.
    return _db
        .collection('spot_claims')
        .where('organizerId', isEqualTo: me)
        .snapshots()
        .map((qs) {
          final out = [
            for (final d in qs.docs) ?spotClaimFromFirestore(d.id, d.data()),
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return out;
        });
  }

  @override
  Stream<List<GateStaff>> watchGateStaff() {
    final me = uid;
    if (me == null) return Stream.value(const []);
    return _db
        .collection('organizers')
        .doc(me)
        .collection('gate_staff')
        .snapshots()
        .map((qs) {
          final out = [
            for (final d in qs.docs)
              if (gateStaffFromFirestore(me, d.id, d.data()) case final g?)
                if (g.status != GateStaffStatus.removed) g,
          ]..sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
          return out;
        });
  }

  @override
  Stream<List<GateStaff>> watchMyGateInvites() {
    final me = uid;
    if (me == null) return Stream.value(const []);
    // Collection group filtered by `staffUid` (rule + single-field index).
    return _db
        .collectionGroup('gate_staff')
        .where('staffUid', isEqualTo: me)
        .snapshots()
        .map((qs) {
          final out = [
            for (final d in qs.docs)
              if (gateStaffFromFirestore(
                    d.reference.parent.parent?.id ?? '',
                    d.id,
                    d.data(),
                  )
                  case final g?)
                if (g.status != GateStaffStatus.removed) g,
          ]..sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
          return out;
        });
  }

  @override
  Stream<EntryDay?> watchEntryDay(String eventId, String day) {
    if (!_validId(eventId) || !_validId(day)) return Stream.value(null);
    return _db
        .collection('entry_days')
        .doc('${eventId}_$day')
        .snapshots()
        .map((s) => entryDayFromFirestore(s.data()));
  }

  // ---- callables ------------------------------------------------------------

  /// `closeEntryDay` refunds inside the call (60 s on the server).
  static const _refundTimeout = Duration(seconds: 65);

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final r = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
          .call<Object?>(data);
      final out = r.data;
      return out is Map ? out.cast<String, dynamic>() : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        final field = details['field'];
        throw OrganizerError(
          details['code'] as String,
          field: field is String ? field : null,
        );
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const OrganizerError('network');
      }
      throw OrganizerError(e.message ?? e.code);
    }
  }

  String _me() {
    final me = uid;
    if (me == null) throw const OrganizerError('permission_denied');
    return me;
  }

  Future<UploadedMedia> _upload(
    PickedImage image,
    String path,
    ImagePurpose purpose,
  ) async {
    UploadedMedia? done;
    await for (final e in uploader.upload(
      image,
      storagePath: path,
      purpose: purpose,
    )) {
      if (e.isDone) done = e.media;
    }
    if (done == null) throw const OrganizerError('network');
    return done;
  }

  @override
  Future<Organizer?> becomeOrganizer({
    required String name,
    required String bio,
    PickedImage? avatar,
  }) async {
    final me = _me();
    String? avatarUrl;
    if (avatar != null) {
      avatarUrl = (await _upload(
        avatar,
        'avatars/$me/${newUlid()}.jpg',
        ImagePurpose.avatar,
      )).url;
    }
    final data = await _call('becomeOrganizer', {
      'name': name,
      'bio': bio,
      'avatarUrl': ?avatarUrl,
    });
    final raw = data['organizer'];
    return raw is Map
        ? organizerFromFirestore(me, raw.cast<String, dynamic>())
        : null;
  }

  @override
  Future<String> claimSpot({
    String? spotId,
    SpotProposal? proposal,
    required List<PickedImage> proofs,
    String? note,
  }) async {
    final me = _me();
    // One folder per attempt: the claim id is the server's, so the folder is
    // a fresh ULID (Storage rule `spot_claims/{uid}/{claimId}/{file}`).
    final folder = newUlid();
    final paths = <String>[];
    for (final p in proofs) {
      final up = await _upload(
        p,
        'spot_claims/$me/$folder/${newUlid()}.jpg',
        ImagePurpose.document,
      );
      paths.add(up.storagePath);
    }
    final data = await _call('claimSpot', {
      'spotId': ?spotId,
      if (spotId == null && proposal != null) 'proposal': proposal.toCallable(),
      'proofPaths': paths,
      'note': ?note,
    });
    final id = data['claimId'];
    if (id is! String) throw const OrganizerError('internal');
    return id;
  }

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
    UploadedMedia? up;
    if (cover != null) {
      // Storage lets the spot's manager create `spots/{spotId}/{file}` once.
      up = await _upload(
        cover,
        'spots/$spotId/${newUlid()}.jpg',
        ImagePurpose.share,
      );
    }
    await _call('updateManagedSpot', {
      'spotId': spotId,
      'description': ?description,
      'tips': ?tips,
      if (up != null) ...{'coverPath': up.storagePath, 'coverUrl': up.url},
      'openHours': ?openHours?.toCallable(),
      if (access != null)
        'access': access.toCallable()
      else if (clearAccess)
        'access': null,
    });
  }

  @override
  Future<void> saveResident(String spotId, Resident resident) async {
    await _call('saveResident', resident.toCallable(spotId));
  }

  @override
  Future<void> removeResident(String spotId, String providerId) async {
    await _call('removeResident', {'spotId': spotId, 'providerId': providerId});
  }

  @override
  Future<void> inviteGateStaff(String target) async {
    await _call('inviteGateStaff', {'target': target});
  }

  @override
  Future<void> respondGateStaff(
    String organizerId, {
    required bool accept,
  }) async {
    await _call('respondGateStaff', {
      'organizerId': organizerId,
      'accept': accept,
    });
  }

  @override
  Future<void> removeGateStaff(String staffUid) async {
    await _call('removeGateStaff', {'staffUid': staffUid});
  }

  @override
  Future<({int refunded, int left})> closeEntryDay(
    String eventId,
    String day,
  ) async {
    final data = await _call('closeEntryDay', {
      'eventId': eventId,
      'day': day,
    }, timeout: _refundTimeout);
    int n(Object? v) => v is num ? v.toInt() : 0;
    return (refunded: n(data['refunded']), left: n(data['left']));
  }
}
