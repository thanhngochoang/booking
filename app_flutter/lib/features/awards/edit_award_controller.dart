// lib/features/awards/edit_award_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Limits of the form (plan B1, Global Constraints).
const int kAwardMinYear = 1950;
const int kAwardMaxProofImages = 3;
const int kAwardMaxProofLinks = 2;
const int kAwardCompetitionMin = 2;
const int kAwardCompetitionMax = 120;
const int kAwardCategoryMax = 60;
const int kAwardLinkMax = 300;

/// Which award the sheet edits. [existing] false = a new award whose id was
/// made on the device (the proof files are uploaded under it first).
@immutable
class AwardArgs {
  const AwardArgs(this.awardId, {required this.existing});
  final String awardId;
  final bool existing;

  @override
  bool operator ==(Object other) =>
      other is AwardArgs &&
      other.awardId == awardId &&
      other.existing == existing;

  @override
  int get hashCode => Object.hash(awardId, existing);
}

/// The stored award being edited (with its proof paths and links); null for a
/// new award or when it no longer exists.
final awardDraftProvider = FutureProvider.autoDispose
    .family<AwardDraft?, AwardArgs>((ref, args) async {
      if (!args.existing) {
        return null;
      }
      return ref.watch(awardRepositoryProvider).loadDraft(args.awardId);
    }, retry: (_, _) => null);

enum ProofStatus { uploading, done, failed, saved }

/// One proof image: a fresh upload ([local] set) or a file sent earlier
/// ([ProofStatus.saved], nothing to preview: proofs are private).
@immutable
class ProofTile {
  const ProofTile({
    required this.key,
    this.local,
    this.status = ProofStatus.uploading,
    this.progress = 0.0,
    this.storagePath,
  });

  final String key;
  final PickedImage? local;
  final ProofStatus status;
  final double progress;
  final String? storagePath;

  ProofTile copyWith({
    ProofStatus? status,
    double? progress,
    String? storagePath,
  }) => ProofTile(
    key: key,
    local: local,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    storagePath: storagePath ?? this.storagePath,
  );
}

enum EditPhase { idle, saving, done, error }

/// Why a save failed, mapped to a message by the sheet.
enum EditFailure { generic, limit, rejected }

@immutable
class EditAwardState {
  const EditAwardState({
    this.competition = '',
    this.year = '',
    this.category = '',
    this.result,
    this.workPostId,
    this.workThumbUrl,
    this.tiles = const [],
    this.links = const [],
    this.phase = EditPhase.idle,
    this.failure,
    this.touched = false,
  });

  final String competition;

  /// What was typed; checked by [yearValue].
  final String year;
  final String category;
  final AwardResult? result;
  final String? workPostId;
  final String? workThumbUrl;
  final List<ProofTile> tiles;

  /// Link fields as typed (blank ones are ignored on save).
  final List<String> links;
  final EditPhase phase;
  final EditFailure? failure;

  /// A field lost focus or a submit was tried: show required-field errors.
  final bool touched;

  int? yearValue(int maxYear) {
    final y = int.tryParse(year.trim());
    return y != null && y >= kAwardMinYear && y <= maxYear ? y : null;
  }

  bool get competitionValid {
    final n = competition.trim().characters.length;
    return n >= kAwardCompetitionMin && n <= kAwardCompetitionMax;
  }

  static bool linkValid(String link) {
    final t = link.trim();
    if (t.length > kAwardLinkMax) {
      return false;
    }
    final uri = Uri.tryParse(t);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !t.contains(RegExp(r'\s'));
  }

  List<String> get filledLinks => [
    for (final l in links)
      if (l.trim().isNotEmpty) l.trim(),
  ];

  bool get anyBadLink => filledLinks.any((l) => !linkValid(l));

  int get proofImageCount => tiles
      .where(
        (t) => t.status == ProofStatus.done || t.status == ProofStatus.saved,
      )
      .length;

  int get proofCount => proofImageCount + filledLinks.where(linkValid).length;

  bool get uploading => tiles.any((t) => t.status == ProofStatus.uploading);
  bool get hasFailedTile => tiles.any((t) => t.status == ProofStatus.failed);

  /// Everything the server needs is present and valid.
  bool canSubmit(int maxYear) =>
      competitionValid &&
      category.trim().characters.length <= kAwardCategoryMax &&
      yearValue(maxYear) != null &&
      result != null &&
      proofCount >= 1 &&
      !anyBadLink &&
      !uploading &&
      !hasFailedTile &&
      phase != EditPhase.saving;

  EditAwardState copyWith({
    String? competition,
    String? year,
    String? category,
    AwardResult? result,
    Object? workPostId = _keep,
    Object? workThumbUrl = _keep,
    List<ProofTile>? tiles,
    List<String>? links,
    EditPhase? phase,
    Object? failure = _keep,
    bool? touched,
  }) => EditAwardState(
    competition: competition ?? this.competition,
    year: year ?? this.year,
    category: category ?? this.category,
    result: result ?? this.result,
    workPostId: identical(workPostId, _keep)
        ? this.workPostId
        : workPostId as String?,
    workThumbUrl: identical(workThumbUrl, _keep)
        ? this.workThumbUrl
        : workThumbUrl as String?,
    tiles: tiles ?? this.tiles,
    links: links ?? this.links,
    phase: phase ?? this.phase,
    failure: identical(failure, _keep) ? this.failure : failure as EditFailure?,
    touched: touched ?? this.touched,
  );
}

const Object _keep = Object();

/// S25.02's form. Proof images upload as they are picked, each under a fresh
/// file id (storage refuses overwrites, so a retry is a new file). Files that
/// are never saved with the award are deleted when the sheet closes.
class EditAwardController extends Notifier<EditAwardState> {
  EditAwardController(this.args);

  final AwardArgs args;

  static const int maxImages = kAwardMaxProofImages;

  /// Taken in [build] so cleanup still works after the provider is disposed.
  late MediaUploader _uploader;
  late AwardDraft? _initial;

  /// True once the award was saved: the uploaded files now belong to it.
  bool _attached = false;

  /// Storage paths of uploads finished in this session and still wanted.
  final Set<String> _livePaths = {};
  final Set<String> _deletedPaths = {};

  /// Taken at build: the sheet may be gone when an upload ends.
  late String? _uid;

  @override
  EditAwardState build() {
    _uploader = ref.read(mediaUploaderProvider);
    _uid =
        ref.read(authRepositoryProvider).currentUser?.uid ??
        ref.read(authStateProvider).value?.uid;
    _initial = ref.read(awardDraftProvider(args)).value;
    ref.onDispose(() {
      if (_attached) {
        return;
      }
      for (final path in [..._livePaths]) {
        unawaited(_deleteQuietly(path));
      }
    });
    final d = _initial;
    if (d == null) {
      return const EditAwardState(links: ['']);
    }
    return EditAwardState(
      competition: d.competition,
      year: '${d.year}',
      category: d.category ?? '',
      result: d.result,
      workPostId: d.workPostId,
      tiles: [
        for (final p in d.proofPaths)
          ProofTile(
            key: newUlid(),
            status: ProofStatus.saved,
            progress: 1,
            storagePath: p,
          ),
      ],
      links: d.proofLinks.isEmpty ? const [''] : d.proofLinks,
    );
  }

  /// Something differs from what the sheet opened with.
  bool get dirty {
    final s = state;
    final d = _initial;
    if (d == null) {
      return s.competition.isNotEmpty ||
          s.year.isNotEmpty ||
          s.category.isNotEmpty ||
          s.result != null ||
          s.workPostId != null ||
          s.tiles.isNotEmpty ||
          s.filledLinks.isNotEmpty;
    }
    return s.competition != d.competition ||
        s.year != '${d.year}' ||
        s.category != (d.category ?? '') ||
        s.result != d.result ||
        s.workPostId != d.workPostId ||
        !listEquals([for (final t in s.tiles) t.storagePath], d.proofPaths) ||
        !listEquals(s.filledLinks, d.proofLinks);
  }

  bool get _busy => state.phase == EditPhase.saving;

  void _edit(EditAwardState next) {
    state = next.copyWith(phase: EditPhase.idle, failure: null);
  }

  void setCompetition(String v) => _edit(state.copyWith(competition: v));
  void setYear(String v) => _edit(state.copyWith(year: v));
  void setCategory(String v) => _edit(state.copyWith(category: v));
  void touch() => state = state.copyWith(touched: true);

  void setResult(AwardResult r) => _edit(state.copyWith(result: r));

  void setWork(String? postId, String? thumbUrl) =>
      _edit(state.copyWith(workPostId: postId, workThumbUrl: thumbUrl));

  void setLink(int index, String v) {
    final list = [...state.links];
    if (index < 0 || index >= list.length) {
      return;
    }
    list[index] = v;
    _edit(state.copyWith(links: list));
  }

  void addLink() {
    if (state.links.length >= kAwardMaxProofLinks) {
      return;
    }
    _edit(state.copyWith(links: [...state.links, '']));
  }

  void removeLink(int index) {
    final list = [...state.links];
    if (index < 0 || index >= list.length) {
      return;
    }
    list.removeAt(index);
    _edit(state.copyWith(links: list.isEmpty ? const [''] : list));
  }

  Future<void> pickImages() async {
    final room = maxImages - state.tiles.length;
    if (room <= 0 || _busy) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (!ref.mounted || picked.isEmpty) {
      return;
    }
    final allowed = picked.take(maxImages - state.tiles.length).toList();
    final fresh = [
      for (final p in allowed) ProofTile(key: newUlid(), local: p),
    ];
    _edit(state.copyWith(tiles: [...state.tiles, ...fresh]));
    await Future.wait(fresh.map(_upload));
  }

  Future<void> retry(String key) async {
    final i = state.tiles.indexWhere((t) => t.key == key);
    if (i < 0 || state.tiles[i].status != ProofStatus.failed || _busy) {
      return;
    }
    final tile = state.tiles[i].copyWith(
      status: ProofStatus.uploading,
      progress: 0,
    );
    final list = [...state.tiles];
    list[i] = tile;
    _edit(state.copyWith(tiles: list));
    await _upload(tile);
  }

  void removeTile(String key) {
    final i = state.tiles.indexWhere((t) => t.key == key);
    if (i < 0) {
      return;
    }
    final tile = state.tiles[i];
    final list = [...state.tiles]..removeAt(i);
    _edit(state.copyWith(tiles: list));
    final path = tile.storagePath;
    if (path != null && _livePaths.remove(path)) {
      // Uploaded in this session and never saved: no one else needs it.
      unawaited(_deleteQuietly(path));
    }
  }

  Future<void> _upload(ProofTile tile) async {
    final local = tile.local;
    final uid = _uid;
    if (local == null || uid == null) {
      _markFailed(tile.key);
      return;
    }
    // A fresh file id for every attempt: storage refuses overwrites.
    final path = ref
        .read(awardRepositoryProvider)
        .proofPath(uid, args.awardId, newUlid());
    try {
      await for (final event in _uploader.upload(
        local,
        storagePath: path,
        purpose: ImagePurpose.document,
      )) {
        final media = event.media;
        final dropped =
            !ref.mounted ||
            state.tiles.indexWhere((t) => t.key == tile.key) < 0;
        if (media != null) {
          if (dropped) {
            // Removed or left behind while it uploaded.
            unawaited(_deleteQuietly(media.storagePath));
            continue;
          }
          _livePaths.add(media.storagePath);
          _update(
            tile.key,
            (t) => t.copyWith(
              status: ProofStatus.done,
              progress: 1,
              storagePath: media.storagePath,
            ),
          );
        } else if (!dropped) {
          _update(tile.key, (t) => t.copyWith(progress: event.fraction));
        }
      }
      // The stream ended with neither a result nor an error.
      final i = state.tiles.indexWhere((t) => t.key == tile.key);
      if (ref.mounted &&
          i >= 0 &&
          state.tiles[i].status == ProofStatus.uploading) {
        unawaited(_deleteQuietly(path));
        _markFailed(tile.key);
      }
    } catch (_) {
      unawaited(_deleteQuietly(path));
      _markFailed(tile.key);
    }
  }

  void _update(String key, ProofTile Function(ProofTile) change) {
    if (!ref.mounted) {
      return;
    }
    final i = state.tiles.indexWhere((t) => t.key == key);
    if (i < 0) {
      return;
    }
    final list = [...state.tiles];
    list[i] = change(list[i]);
    state = state.copyWith(tiles: list);
  }

  void _markFailed(String key) =>
      _update(key, (t) => t.copyWith(status: ProofStatus.failed));

  /// Sends the award for review. True when saved.
  Future<bool> submit({required int maxYear}) async {
    final s = state;
    if (_busy) {
      return false;
    }
    if (!s.canSubmit(maxYear)) {
      state = s.copyWith(touched: true);
      return false;
    }
    state = s.copyWith(phase: EditPhase.saving, failure: null);
    final category = s.category.trim();
    final draft = AwardDraft(
      awardId: args.awardId,
      competition: s.competition.trim(),
      year: s.yearValue(maxYear)!,
      category: category.isEmpty ? null : category,
      result: s.result!,
      workPostId: s.workPostId,
      proofPaths: [
        for (final t in s.tiles)
          if (t.storagePath != null) t.storagePath!,
      ],
      proofLinks: s.filledLinks,
    );
    final repo = ref.read(awardRepositoryProvider);
    try {
      if (args.existing) {
        await repo.update(draft);
      } else {
        await repo.create(draft);
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: EditPhase.error,
          failure: e is AwardError
              ? switch (e.code) {
                  'limit_exceeded' => EditFailure.limit,
                  'invalid_argument' => EditFailure.rejected,
                  _ => EditFailure.generic,
                }
              : EditFailure.generic,
        );
      }
      return false;
    }
    _attached = true;
    if (ref.mounted) {
      state = state.copyWith(phase: EditPhase.done);
    }
    return true;
  }

  Future<void> _deleteQuietly(String path) async {
    if (!_deletedPaths.add(path)) {
      return;
    }
    try {
      await _uploader.delete(path);
    } catch (_) {}
  }
}

final editAwardControllerProvider = NotifierProvider.autoDispose
    .family<EditAwardController, EditAwardState, AwardArgs>(
      EditAwardController.new,
    );
