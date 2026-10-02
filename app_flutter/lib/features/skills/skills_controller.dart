// lib/features/skills/skills_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_completeness.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_rules.dart';
import 'package:photobooking/features/skills/skills_analytics.dart';
import 'package:photobooking/features/skills/skills_draft_store.dart';

enum SkillsSubmitResult { saved, invalid, failed }

class SkillsEditorState {
  const SkillsEditorState({
    required this.saved,
    required this.start,
    required this.draft,
    this.restoredDraft = false,
    this.showIssues = false,
    this.issues = const [],
    this.saving = false,
  });

  /// What Firestore holds.
  final PhotographerSkills saved;

  /// What the screen opened with (saved skills or the device draft).
  final PhotographerSkills start;
  final PhotographerSkills draft;

  /// The draft came from the device, not from the server.
  final bool restoredDraft;

  /// Issues are shown after the first refused "Tiếp tục".
  final bool showIssues;
  final List<SkillIssue> issues;
  final bool saving;

  /// Leaving now asks "Lưu bản nháp?".
  bool get dirty => draft != start;

  /// The server does not have this draft yet.
  bool get unsaved => draft != saved;

  bool get canSubmit => draft.specialties.isNotEmpty && !saving;

  CompletenessReport get completeness => skillsCompleteness(draft);

  bool hasIssue(SkillIssueCode code, {String? itemId}) =>
      showIssues &&
      issues.any(
        (i) => i.code == code && (itemId == null || i.itemId == itemId),
      );

  SkillsEditorState copyWith({
    PhotographerSkills? saved,
    PhotographerSkills? start,
    PhotographerSkills? draft,
    bool? showIssues,
    List<SkillIssue>? issues,
    bool? saving,
  }) => SkillsEditorState(
    saved: saved ?? this.saved,
    start: start ?? this.start,
    draft: draft ?? this.draft,
    restoredDraft: restoredDraft,
    showIssues: showIssues ?? this.showIssues,
    issues: issues ?? this.issues,
    saving: saving ?? this.saving,
  );
}

/// S38/S39 editor: loads once, edits a draft (copied to the device on every
/// change), validates and saves once. No listener, no timer.
class SkillsController extends AsyncNotifier<SkillsEditorState> {
  late String _uid;
  late TaxonomyCatalog _catalog;
  late SkillsDraftStore _drafts;
  late SkillsEventLogger _log;

  @override
  Future<SkillsEditorState> build() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) throw StateError('signed_out');
    _uid = uid;
    _catalog = ref.read(skillCatalogProvider);
    _drafts = ref.read(skillsDraftStoreProvider);
    _log = ref.read(skillsAnalyticsProvider);
    final saved = await ref.read(skillsRepositoryProvider).load(uid);
    final local = _drafts.read(uid);
    final opened = local ?? _baseline(saved);
    final draft = await _withoutDeletedEvidence(opened);
    return SkillsEditorState(
      saved: saved,
      start: draft,
      draft: draft,
      restoredDraft: local != null && local != _baseline(saved),
    );
  }

  /// What the screen shows when there is no device draft: the saved skills,
  /// or [PhotographerSkills.initial] for a photographer with none.
  static PhotographerSkills _baseline(PhotographerSkills saved) =>
      saved.isEmpty ? PhotographerSkills.initial : saved;

  Future<PhotographerSkills> _withoutDeletedEvidence(
    PhotographerSkills s,
  ) async {
    // At most 6 genres x 3 posts; a malformed draft must not fan out more.
    final ids = s.evidencePostIds.take(18).toList();
    if (ids.isEmpty) return s;
    final posts = ref.read(postRepositoryProvider);
    try {
      final found = await Future.wait(ids.map(posts.byId));
      return withoutMissingEvidence(s, {
        for (final p in found)
          if (p != null) p.id,
      });
    } catch (_) {
      // Offline: keep the list; the server re-checks evidence.
      return s;
    }
  }

  SkillEdit? toggleSpecialty(String id) =>
      _apply((s) => withSpecialtyToggled(s, id, _catalog));

  SkillEdit? setLevel(String id, int level) =>
      _apply((s) => withSpecialtyLevel(s, id, level));

  SkillEdit? toggleTag(SkillGroup group, String id) =>
      _apply((s) => withTagToggled(s, group, id, _catalog));

  SkillEdit? setEvidence(String specialtyId, List<String> postIds) {
    final e = _apply((s) => withEvidence(s, specialtyId, postIds));
    if (e != null && e.accepted) {
      _log('skill_evidence_set', {
        'skillId': specialtyId,
        'count': e.skills.specialty(specialtyId)!.evidencePostIds.length,
      });
    }
    return e;
  }

  void setYears(int? years) =>
      _apply((s) => SkillEdit(withYearsExperience(s, years)));

  SkillEdit? _apply(SkillEdit Function(PhotographerSkills draft) edit) {
    final current = state.value;
    if (current == null || current.saving) return null;
    final result = edit(current.draft);
    if (!result.accepted || result.skills == current.draft) return result;
    state = AsyncData(
      current.copyWith(
        draft: result.skills,
        issues: current.showIssues
            ? validateSkills(result.skills, _catalog, previous: current.saved)
            : const [],
      ),
    );
    unawaited(
      result.skills == _baseline(current.saved)
          ? _drafts.clear(_uid)
          : _drafts.write(_uid, result.skills),
    );
    return result;
  }

  Future<SkillsSubmitResult> submit() async {
    final current = state.value;
    if (current == null || current.saving) return SkillsSubmitResult.failed;
    final issues = validateSkills(
      current.draft,
      _catalog,
      previous: current.saved,
    );
    if (issues.isNotEmpty) {
      state = AsyncData(current.copyWith(showIssues: true, issues: issues));
      return SkillsSubmitResult.invalid;
    }
    if (!current.unsaved) {
      await _drafts.clear(_uid);
      if (ref.mounted) {
        state = AsyncData(
          SkillsEditorState(
            saved: current.saved,
            start: current.draft,
            draft: current.draft,
          ),
        );
      }
      return SkillsSubmitResult.saved;
    }
    final repo = ref.read(skillsRepositoryProvider);
    state = AsyncData(
      current.copyWith(saving: true, showIssues: false, issues: const []),
    );
    try {
      await repo.save(_uid, current.draft);
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(saving: false));
      return SkillsSubmitResult.failed;
    }
    await _drafts.clear(_uid);
    _log('skills_save', {
      'specialties': current.draft.specialties.length,
      'expert': current.draft.expertCount,
    });
    if (ref.mounted) {
      state = AsyncData(
        SkillsEditorState(
          saved: current.draft,
          start: current.draft,
          draft: current.draft,
        ),
      );
      ref.invalidate(photographerSkillsProvider(_uid));
    }
    return SkillsSubmitResult.saved;
  }

  /// "Bỏ thay đổi": forget the device draft and go back to the saved skills.
  /// Does nothing while a save is in flight (that save wins).
  Future<void> discardDraft() async {
    if (state.value?.saving ?? false) return;
    await _drafts.clear(_uid);
    final current = state.value;
    if (current == null || current.saving || !ref.mounted) return;
    final base = _baseline(current.saved);
    state = AsyncData(
      current.copyWith(
        start: base,
        draft: base,
        showIssues: false,
        issues: const [],
      ),
    );
  }
}

final skillsControllerProvider =
    AsyncNotifierProvider.autoDispose<SkillsController, SkillsEditorState>(
      SkillsController.new,
      retry: (_, _) => null,
    );
