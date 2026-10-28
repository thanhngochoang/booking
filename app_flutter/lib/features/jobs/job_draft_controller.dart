// lib/features/jobs/job_draft_controller.dart
//
// JobDraftController manages the multi-step job posting draft, local persistence,
// reference image uploads, error mapping and submission.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_draft.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';

@immutable
class JobDraftState {
  const JobDraftState({
    this.step = 1,
    required this.draft,
    this.uploads = const {},
    this.errors = const {},
    this.submitting = false,
    this.fromJobId,
    this.editJobId,
  });

  final int step; // 1 or 2
  final JobDraft draft;
  final Map<String, double> uploads; // local upload progress/indicators if any
  final Map<String, String> errors; // field -> localized error text
  final bool submitting;
  final String? fromJobId;
  final String? editJobId;

  JobDraftState copyWith({
    int? step,
    JobDraft? draft,
    Map<String, double>? uploads,
    Map<String, String>? errors,
    bool? submitting,
    String? fromJobId,
    String? editJobId,
    bool clearEditJobId = false,
    bool clearFromJobId = false,
  }) {
    return JobDraftState(
      step: step ?? this.step,
      draft: draft ?? this.draft,
      uploads: uploads ?? this.uploads,
      errors: errors ?? this.errors,
      submitting: submitting ?? this.submitting,
      fromJobId: clearFromJobId ? null : (fromJobId ?? this.fromJobId),
      editJobId: clearEditJobId ? null : (editJobId ?? this.editJobId),
    );
  }
}

JobDraft _createDefaultDraft({String? draftId}) {
  return JobDraft(
    draftId: draftId ?? newUlid(),
    specialtyId: '',
    title: '',
    description: '',
    references: const [],
    schedule: const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60),
    area: const JobDraftArea(areaId: '', name: '', lat: 0, lng: 0),
    budget: null,
    wants: const JobWants(),
    allowedProviders: AllowedProviders.all,
    deadlineDays: 3,
  );
}

class JobDraftController extends Notifier<JobDraftState> {
  JobDraftController({this.fromJobId, this.editJobId});

  final String? fromJobId;
  final String? editJobId;

  String? _resolveUid() {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo.currentUser?.uid != null) {
        return authRepo.currentUser!.uid;
      }
    } catch (_) {}
    try {
      final user = ref.read(authStateProvider).value;
      if (user?.uid != null) return user!.uid;
    } catch (_) {}
    try {
      final profile = ref.read(currentProfileProvider).value;
      if (profile?.uid != null) return profile!.uid;
    } catch (_) {}
    return null;
  }

  String? _resolveKey() {
    final uid = _resolveUid();
    return uid != null ? 'jobDraft:$uid' : null;
  }

  @override
  JobDraftState build() {
    final defaultDraft = _createDefaultDraft();
    final initial = JobDraftState(
      step: 1,
      draft: defaultDraft,
      fromJobId: fromJobId,
      editJobId: editJobId,
    );

    // If edit or fromJobId is specified, fetch the job
    if (editJobId != null || fromJobId != null) {
      final targetId = editJobId ?? fromJobId!;
      Future.microtask(() async {
        try {
          final repo = ref.read(jobRepositoryProvider);
          final job = await repo.getJob(targetId);
          if (job != null) {
            final draft = JobDraft.fromJob(
              job,
              draftId: newUlid(),
              resetSchedule: fromJobId != null,
            );
            state = state.copyWith(draft: draft);
          }
        } catch (_) {}
      });
      return initial;
    }

    // Try restoring from SharedPreferences
    final key = _resolveKey();
    if (key != null) {
      try {
        final prefs = ref.watch(sharedPreferencesProvider);
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final restored = JobDraft.fromJson(decoded);
          return JobDraftState(
            step: 1,
            draft: restored.draftId != null
                ? restored
                : restored.copyWith(draftId: newUlid()),
          );
        }
      } catch (_) {}
    }

    return initial;
  }

  void setSpecialty(String specialtyId) {
    state = state.copyWith(
      draft: state.draft.copyWith(specialtyId: specialtyId),
      errors: _withoutError('specialty'),
    );
  }

  void setTitle(String title) {
    state = state.copyWith(
      draft: state.draft.copyWith(title: title),
      errors: _withoutError('title'),
    );
  }

  void setDescription(String description) {
    state = state.copyWith(
      draft: state.draft.copyWith(description: description),
      errors: _withoutError('description'),
    );
  }

  Future<void> addReferences(List<PickedImage> images) async {
    final draftId = state.draft.draftId ?? newUlid();
    final repo = ref.read(jobRepositoryProvider);
    final currentRefs = List<JobReference>.from(state.draft.references);

    for (final img in images) {
      if (currentRefs.length >= 5) break;
      try {
        final refObj = await repo.uploadReference(img, draftId: draftId);
        currentRefs.add(refObj);
      } catch (_) {
        final errs = Map<String, String>.from(state.errors);
        errs['references'] = 'Chưa tải được ảnh. Thử lại.';
        state = state.copyWith(errors: errs);
        return;
      }
    }
    state = state.copyWith(
      draft: state.draft.copyWith(references: currentRefs, draftId: draftId),
      errors: _withoutError('references'),
    );
  }

  Future<void> removeReference(JobReference reference) async {
    final currentRefs = List<JobReference>.from(state.draft.references);
    currentRefs.remove(reference);
    state = state.copyWith(
      draft: state.draft.copyWith(references: currentRefs),
    );
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.deleteReference(reference);
    } catch (_) {}
  }

  void setSchedule(JobSchedule schedule) {
    state = state.copyWith(
      draft: state.draft.copyWith(schedule: schedule),
      errors: _withoutError('schedule'),
    );
  }

  void setArea(JobDraftArea area) {
    state = state.copyWith(
      draft: state.draft.copyWith(area: area),
      errors: _withoutError('area'),
    );
  }

  void setBudget(int min, int max) {
    state = state.copyWith(
      draft: state.draft.copyWith(budget: JobBudget(min: min, max: max)),
      errors: _withoutError('budget'),
    );
  }

  void clearBudget() {
    state = state.copyWith(
      draft: state.draft.copyWith(clearBudget: true),
      errors: _withoutError('budget'),
    );
  }

  void setWants(JobWants wants) {
    state = state.copyWith(
      draft: state.draft.copyWith(wants: wants),
      errors: _withoutError('wants'),
    );
  }

  void setAllowed(AllowedProviders allowed) {
    state = state.copyWith(
      draft: state.draft.copyWith(allowedProviders: allowed),
      errors: _withoutError('allowedProviders'),
    );
  }

  void setDeadlineDays(int days) {
    state = state.copyWith(
      draft: state.draft.copyWith(deadlineDays: days),
      errors: _withoutError('deadlineDays'),
    );
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool canProceed() {
    if (state.step == 1) {
      return state.draft.specialtyId.isNotEmpty && state.draft.title.trim().length >= 10;
    } else {
      // Step 2 validation
      if (state.draft.schedule.kind == ScheduleKind.fixed) {
        final day = state.draft.schedule.day;
        final start = state.draft.schedule.start;
        final end = state.draft.schedule.end;
        if (day == null || day.isEmpty || start == null || start.isEmpty || end == null || end.isEmpty) {
          return false;
        }
        if (_timeToMinutes(end) <= _timeToMinutes(start)) {
          return false;
        }
      } else {
        final from = state.draft.schedule.from;
        final to = state.draft.schedule.to;
        if (from == null || from.isEmpty || to == null || to.isEmpty) {
          return false;
        }
      }
      return true;
    }
  }

  bool next() {
    if (state.step == 1) {
      if (!canProceed()) {
        return false;
      }
      state = state.copyWith(step: 2);
      return true;
    }
    return false;
  }

  void back() {
    if (state.step > 1) {
      state = state.copyWith(step: state.step - 1);
    }
  }

  Future<void> saveDraft() async {
    final key = _resolveKey();
    if (key == null) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = jsonEncode(state.draft.toJson());
      await prefs.setString(key, jsonStr);
    } catch (_) {}
  }

  Future<void> discard() async {
    final repo = ref.read(jobRepositoryProvider);
    for (final r in state.draft.references) {
      try {
        await repo.deleteReference(r);
      } catch (_) {}
    }
    final key = _resolveKey();
    if (key != null) {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove(key);
      } catch (_) {}
    }
    state = JobDraftState(draft: _createDefaultDraft());
  }

  Map<String, String> _withoutError(String field) {
    if (!state.errors.containsKey(field)) return state.errors;
    final errs = Map<String, String>.from(state.errors);
    errs.remove(field);
    return errs;
  }

  Future<({String jobId, int matched})?> submit() async {
    state = state.copyWith(submitting: true, errors: const {});
    final repo = ref.read(jobRepositoryProvider);
    try {
      if (state.editJobId != null) {
        await repo.updateJob(state.editJobId!, state.draft);
        state = state.copyWith(submitting: false);
        return (jobId: state.editJobId!, matched: 0);
      } else {
        final res = await repo.createJob(state.draft);
        final key = _resolveKey();
        if (key != null) {
          try {
            final prefs = ref.read(sharedPreferencesProvider);
            await prefs.remove(key);
          } catch (_) {}
        }
        state = state.copyWith(submitting: false);
        return res;
      }
    } catch (e) {
      final err = jobErrorOf(e);
      final errs = Map<String, String>.from(state.errors);

      // Decision 15 & error mapping:
      // description.contact -> Bỏ số điện thoại hoặc link khỏi mô tả
      // field: 'description' -> Mô tả tối đa 1000 ký tự
      // title.contact -> Bỏ số điện thoại hoặc link khỏi tiêu đề
      // field: 'title' -> Tiêu đề cần 10–60 ký tự
      if (err.field == 'description.contact') {
        errs['description'] = 'Bỏ số điện thoại hoặc link khỏi mô tả';
      } else if (err.field == 'description') {
        errs['description'] = 'Mô tả tối đa 1000 ký tự';
      } else if (err.field == 'title.contact') {
        errs['title'] = 'Bỏ số điện thoại hoặc link khỏi tiêu đề';
      } else if (err.field == 'title') {
        errs['title'] = 'Tiêu đề cần 10–60 ký tự';
      } else if (err.field != null) {
        errs[err.field!] = err.code;
      } else {
        errs['general'] = err.code;
      }

      state = state.copyWith(submitting: false, errors: errs);
      return null;
    }
  }
}

final jobDraftStateProvider = NotifierProvider.autoDispose<JobDraftController, JobDraftState>(
  JobDraftController.new,
);
