# Step 2c: Photographer Skills (S38, S39, S40) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A photographer declares what they shoot from a fixed catalogue: up to 6 genres, each with a level (at most 3 "Chuyên sâu", each of those backed by 1–3 of their own posts), styles, extra skills, languages, suitable clients and years of experience. This happens at setup step 3/4 (`/setup/3`, "Tiếp tục" → S34 `/setup/4`) and at any time from the profile (`/profile/skills`). The data is stored as `photographers/{uid}.skills` in the shape the recommender reads (spec 3e.3), and both the client and the Firestore rules refuse anything outside the limits.

**Architecture:** Pure Dart in `lib/data/skills/`: the skills catalogue keyed by `(group, id)` (built on the built-in taxonomy file of plan 3a2), the immutable `PhotographerSkills` model with its map mapping, pure validation and edit functions (table tests), and the completeness score (same formula the server will use). A `SkillsRepository` port has an in-memory fake and a Firestore adapter that does one-shot reads and a merge write (never a listener). Rules check shape, limits and catalogue ids, with the ids mirrored from the app by a test. Four stateless core widgets (`SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter`) take plain values. One feature folder `lib/features/skills/` holds the `SkillsController` (draft kept on the device as you edit, validated, then saved), the S40 evidence sheet over the photographer's own posts, and the single scrolling S38/S39 screen in two modes (setup / edit).

**Tech Stack:** Flutter, Riverpod 3, go_router, `cloud_firestore` (adapter only), `fake_cloud_firestore` (dev, added by plan 3b1), `shared_preferences` (device draft), Firestore rules + `@firebase/rules-unit-testing` (Node), `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3e.1–3e.3 (data, limits, completeness), §3e.6 (how `rules-v1` uses levels, missing evidence ×0.85, `audiences`/`extras`), §3e.9, §4, §5 (S38, S39, S40), §7 (validation tests: limits, unknown ids, level 3 without evidence); `docs/superpowers/specs/screens/photographer.md` (S38, S39, S40, exact strings); `docs/superpowers/specs/components/shared-components.md` (`SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter`, `SegmentedTabs`); `docs/superpowers/specs/data-model/README.md` (conventions), `domain-model.md` (`SpecialtySkill`, `SkillTag`, `TaxonomyItem`, `SkillLevel`, `SkillGroup`, invariant 5), `relational-schema.md` §2.2, §3, §6 (seed list); mock `docs/design/ui-mock.html` (`data-code="S38"`, `S39`, `S40`); `services/recommender/api/openapi.yaml` (`specialty` is a taxonomy id; the service reads `photographers/{uid}.skills` directly).

**Prerequisite (run order):** screen-codes → core-display-widgets → 2a → 2b → 3a1 → 3a2 → 3b1 → 3b2 → **2c (this plan)** → 2d. This plan uses, without redefining them:
- screen-codes: `ScreenCode`, `ScreenCodes.skillsPart1` / `.skillsPart2` / `.skillEvidence`, `test/support/idle.dart` (`expectIdle`), `docs/testing/battery-and-performance.md`;
- core-display-widgets: `StepProgress`, `hostWidget` (`test/core/widgets/widget_host.dart`);
- 2b: the route `/setup/4` (S34) that "Tiếp tục" pushes;
- 3a1: `AppChip` / `AppChipKind`, `showAppSheet`, `test/support/blur.dart` (`expectBlurBudget`);
- 3a2: `lib/data/taxonomy/builtin_taxonomy.dart` (`TaxonomyOption`, `kSpecialties`, `kStyles`, `specialtyLabel`, `styleLabel`), `ErrorState`, `AppSkeleton`;
- 3b1: `PostRepository.byPhotographer` / `.byId`, `PostSummary`, `PostPage`, `FakePostRepository`, `postRepositoryProvider`, `fixturePost`, `fake_cloud_firestore`;
- 3b2: `NetworkPhoto` (decodes at display size), `testPhotoScope` (`test/support/photo_scope.dart`).

If one of these plans has not run, stop and run it first; do not re-create its files here. Plan 2d (S24 steps 1–2 and the S03 profile) runs after this one and consumes `PhotographerSkills`, `photographerSkillsProvider`, `skillCatalogProvider` and the route `/profile/skills`.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`, never files inside `core/`; files inside `core/` import each other directly.
- **Firebase isolation:** `cloud_firestore` appears only in `lib/data/skills/firestore_skills_repository.dart` and `lib/data/skills/skills_providers.dart` (which names the adapter). The model, rules, completeness, port and fake import no Firebase package. No Firebase type (`Timestamp`, `FieldValue`, `GeoPoint`) leaves the adapter.
- Data conventions (`data-model/README.md`): ids are opaque strings; catalogue ids are stable `snake_case` codes and never change meaning; levels are the integers 1–3 (the documented exception); the document carries `schemaVersion: 1`.
- **Catalogue keys are `(group, id)`:** the seed list uses `couple` both as a genre and as a suitable-client code, so every lookup takes the group. Labels are data that mirror the `taxonomy` documents (same choice as plan 3a2), so they live in `builtin_taxonomy.dart`, not in the ARB file.
- **Limits (spec 3e.2):** at most 6 genres; at most 3 at level 3; level 3 needs at least 1 evidence post; 0–3 evidence posts per genre; at most 4 styles, 8 extra skills, 4 suitable clients; at least 1 language (of 5); years 0–50. Client validation and Firestore rules enforce the same limits.
- **Server-owned fields:** `skills.completeness` and `skills.updatedAt` are written by Cloud Functions only; the client never writes them (rules test). Until that Function exists the app shows the score computed on the device with the same formula (`skillsCompleteness`).
- **Battery:** no Firestore listener anywhere in this plan (one-shot `get()` only), no timers, no polling; every provider is `autoDispose` and has `retry: (_, _) => null` so an error never leaves a retry timer; the evidence grid is a lazy `GridView.builder` whose images are decoded at tile size through `NetworkPhoto`; at most 4 `BackdropFilter`s on screen and none inside a chip, a level row or a grid tile.
- One primary action per screen (`AppButton.primary`, fixed 52dp via `controlHeight`); "Bỏ thay đổi" / "Bỏ thể loại" are red buttons inside a confirmation sheet, never the gradient button.
- All UI strings in `lib/l10n/app_vi.arb` (Vietnamese, full diacritics, camelCase keys `skills*` / `skillEvidence*` / `completeness*`), then `flutter gen-l10n`. Colours, spacing and radii from `AppColors`/`AppColorsDark`/`AppSpace`/`AppRadius`/`AppText`; no raw hex. No deprecated Flutter API.
- Touch targets ≥ 48dp; state never rests on colour alone; layouts are tested at width 320 and text scale 1.3, in light and dark.
- No analytics layer exists yet: events go through the `skillsAnalyticsProvider` callback (default no-op): `screen_view{code}`, `skills_save{specialties, expert}`, `skills_step{n}`, `skill_evidence_set{skillId, count}`. No post ids or personal data in parameters.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Interfaces for other plans

Plan 2d (S03 profile, S24) and later plans (S22, recommender adapters) consume exactly these:

```dart
// lib/data/skills/skill_taxonomy.dart
enum SkillGroup { specialty, style, extra, language, audience; String get code; static SkillGroup? fromCode(String? code); }
class TaxonomyItem { const TaxonomyItem({required String id, required SkillGroup group, required String labelVi, required int order, bool active = true}); }
class TaxonomyCatalog {
  TaxonomyCatalog(Iterable<TaxonomyItem> items);
  TaxonomyItem? item(SkillGroup group, String id);
  bool isKnown(SkillGroup group, String id);
  bool isSelectable(SkillGroup group, String id);      // known and active
  String label(SkillGroup group, String id);            // falls back to the id
  List<TaxonomyItem> options(SkillGroup group, {Iterable<String> keep = const []}); // active + kept, by order
  List<String> ids(SkillGroup group);                   // active ids, by order
}
final TaxonomyCatalog builtInSkillCatalog;

// lib/data/skills/photographer_skills.dart
abstract final class SkillLevels { static const basic = 1, proficient = 2, expert = 3; static const all = [1, 2, 3]; }
abstract final class SkillLimits { schemaVersion = 1, maxSpecialties = 6, maxExpert = 3, maxEvidence = 3, maxStyles = 4, maxExtras = 8, maxLanguages = 5, maxAudiences = 4, maxYears = 50; static int maxFor(SkillGroup group); }
class SpecialtySkill {
  const SpecialtySkill({required String id, int level = SkillLevels.proficient, int? years, List<String> evidencePostIds = const []});
  final String id; final int level; final int? years; final List<String> evidencePostIds;
  bool get isExpert;
  SpecialtySkill copyWith({int? level, List<String>? evidencePostIds});
}
class PhotographerSkills {
  const PhotographerSkills({List<SpecialtySkill> specialties = const [], List<String> styles = const [], List<String> extras = const [], List<String> languages = const [], List<String> audiences = const [], int? yearsExperience});
  static const empty = PhotographerSkills();
  static const initial = PhotographerSkills(languages: ['vi']);   // what a new photographer starts from
  final List<SpecialtySkill> specialties; final List<String> styles, extras, languages, audiences; final int? yearsExperience;
  List<String> get specialtyIds;
  SpecialtySkill? specialty(String id);
  int get expertCount;
  Set<String> get evidencePostIds;                                // S03: small badge on these posts
  List<String> tags(SkillGroup group);
  bool get isEmpty;
  PhotographerSkills copyWith({List<SpecialtySkill>? specialties, List<String>? styles, List<String>? extras, List<String>? languages, List<String>? audiences, Object? yearsExperience /* int? */});
  PhotographerSkills withTags(SkillGroup group, List<String> ids); // not for SkillGroup.specialty
}
Map<String, Object?> skillsToMap(PhotographerSkills s);           // client part of photographers/{uid}.skills
PhotographerSkills skillsFromMap(Object? raw);                    // tolerant; empty for null/garbage

// lib/data/skills/skills_completeness.dart
enum CompletenessStep { specialties(25), levels(20), evidence(20), styles(10), languages(10), audiences(10), extras(5); final int points; }
class CompletenessHint { const CompletenessHint(CompletenessStep step, {required int percentAfter, String? specialtyId}); }
class CompletenessReport { const CompletenessReport({required int percent, required List<CompletenessStep> missing, CompletenessHint? next}); }
CompletenessReport skillsCompleteness(PhotographerSkills s);

// lib/data/skills/skills_repository.dart
abstract class SkillsRepository {
  Future<PhotographerSkills> load(String uid);               // one-shot; PhotographerSkills.empty when unset
  Future<void> save(String uid, PhotographerSkills skills);  // client part only; callers validate first
}
class FakeSkillsRepository implements SkillsRepository { FakeSkillsRepository(); void seed(String uid, PhotographerSkills s); PhotographerSkills? stored(String uid); int loadCalls; int saveCalls; Object? failLoadWith; Object? failSaveWith; }

// lib/data/skills/skills_providers.dart
final skillsRepositoryProvider = Provider<SkillsRepository>(...);           // FirestoreSkillsRepository
final skillCatalogProvider = Provider<TaxonomyCatalog>(...);                // builtInSkillCatalog
final photographerSkillsProvider = FutureProvider.autoDispose.family<PhotographerSkills, String>(...); // by uid
```

Routes: `/setup/3` (S38 setup mode, step 3/4; "Quay lại" → back or `/setup/2`; "Tiếp tục" saves and `push('/setup/4')`), `/profile/skills` (edit mode; "Lưu thay đổi" saves and pops, or goes to `/profile`), `/profile/skills/evidence?skill=<specialtyId>` (opens S38 in edit mode with the S40 sheet open for that genre). The routes are literal paths; plan 2d registers `/setup/1` and `/setup/2` literally too (or puts any `/setup/:step` route after the literal ones). Plan 2d adds the "Kỹ năng" row on the profile that pushes `/profile/skills`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/data/taxonomy/builtin_taxonomy.dart` (modify) | add `kExtras`, `kLanguages`, `kAudiences`, `extraLabel`, `languageLabel`, `audienceLabel` |
| `lib/data/skills/skill_taxonomy.dart` (create) | `SkillGroup`, `TaxonomyItem`, `TaxonomyCatalog`, `builtInSkillCatalog` |
| `lib/data/skills/photographer_skills.dart` (create) | `SkillLevels`, `SkillLimits`, `SpecialtySkill`, `PhotographerSkills`, `skillsToMap`, `skillsFromMap` |
| `lib/data/skills/skills_rules.dart` (create) | `SkillIssueCode`, `SkillIssue`, `validateSkills`, `SkillEditRejection`, `SkillEdit`, `withSpecialtyToggled`, `withSpecialtyLevel`, `withTagToggled`, `withEvidence`, `withYearsExperience`, `withoutMissingEvidence` |
| `lib/data/skills/skills_completeness.dart` (create) | `CompletenessStep`, `CompletenessHint`, `CompletenessReport`, `skillsCompleteness` |
| `lib/data/skills/skills_repository.dart` (create) | `SkillsRepository`, `FakeSkillsRepository` |
| `lib/data/skills/firestore_skills_repository.dart` (create) | `FirestoreSkillsRepository` |
| `lib/data/skills/skills_providers.dart` (create) | `skillsRepositoryProvider`, `skillCatalogProvider`, `photographerSkillsProvider` |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (modify) | `skills` field rules and tests |
| `lib/core/widgets/skill_chip.dart`, `completeness_meter.dart`, `level_selector.dart`, `evidence_picker.dart` (create) | the four shared widgets (+ `PostThumb`) |
| `lib/core/core.dart` (modify) | export them |
| `lib/features/skills/skills_analytics.dart` (create) | `SkillsEventLogger`, `skillsAnalyticsProvider` |
| `lib/features/skills/skills_draft_store.dart` (create) | `SkillsDraftStore`, `skillsDraftStoreProvider` |
| `lib/features/skills/skills_controller.dart` (create) | `SkillsEditorState`, `SkillsSubmitResult`, `SkillsController`, `skillsControllerProvider` |
| `lib/features/skills/own_posts_controller.dart` (create) | `OwnPostsState`, `OwnPostsController`, `ownPostsProvider` |
| `lib/features/skills/evidence_sheet.dart` (create) | S40: `showEvidenceSheet`, `EvidenceSheet` |
| `lib/features/skills/skills_screen.dart` (create) | S38 + S39: `SkillsMode`, `SkillsScreen` |
| `lib/app/router.dart` (modify) | the three routes |
| `lib/l10n/app_vi.arb` (modify) | strings listed per task |
| `docs/superpowers/specs/...` (modify, Task 13) | align specs with what was built |
| `test/support/skills_world.dart` (create) | shared harness for skills screen tests |
| `test/data/skills/*`, `test/core/widgets/*`, `test/features/skills/*`, `test/battery/skills_battery_test.dart` | tests |

---

### Task 1: Skills catalogue

**Files:**
- Modify: `lib/data/taxonomy/builtin_taxonomy.dart`
- Create: `lib/data/skills/skill_taxonomy.dart`, `test/data/skills/skill_taxonomy_test.dart`

**Interfaces:**
- Consumes: `TaxonomyOption`, `kSpecialties`, `kStyles`, `_label` (plan 3a2, same file).
- Produces: `const List<TaxonomyOption> kExtras`, `kLanguages`, `kAudiences`; `String extraLabel(String id)`, `languageLabel`, `audienceLabel`; and in `skill_taxonomy.dart` exactly the `SkillGroup`, `TaxonomyItem`, `TaxonomyCatalog`, `builtInSkillCatalog` signatures of "Interfaces for other plans".

- [ ] **Step 1: Write the failing test**

```dart
// test/data/skills/skill_taxonomy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

void main() {
  test('each group mirrors the seed list of relational-schema.md §6', () {
    final c = builtInSkillCatalog;
    expect(c.ids(SkillGroup.specialty), [
      'portrait', 'wedding', 'couple', 'family', 'graduation', 'event', 'product',
      'travel', 'fashion', 'food', 'real_estate', 'newborn', 'street', 'commercial',
    ]);
    expect(c.ids(SkillGroup.style), ['natural_light', 'film', 'minimal', 'editorial', 'documentary']);
    expect(c.ids(SkillGroup.extra), [
      'retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light', 'outdoor',
    ]);
    expect(c.ids(SkillGroup.language), ['vi', 'en', 'zh', 'ko', 'ja']);
    expect(c.ids(SkillGroup.audience), ['couple', 'family_kids', 'business', 'foreigner', 'shy_subjects']);
  });

  test('ids are snake_case codes, unique inside their group, labels are not empty', () {
    for (final list in [kSpecialties, kStyles, kExtras, kLanguages, kAudiences]) {
      expect(list.map((o) => o.id).toSet(), hasLength(list.length));
      for (final o in list) {
        expect(o.id, matches(RegExp(r'^[a-z][a-z_]*$')));
        expect(o.labelVi.trim(), isNotEmpty);
      }
    }
  });

  test('the same code may live in two groups without clashing', () {
    final c = builtInSkillCatalog;
    expect(c.label(SkillGroup.specialty, 'couple'), 'Cặp đôi');
    expect(c.label(SkillGroup.audience, 'couple'), 'Cặp đôi');
    expect(c.isKnown(SkillGroup.style, 'couple'), isFalse);
  });

  test('labels follow the spec and the mock', () {
    final c = builtInSkillCatalog;
    expect(c.label(SkillGroup.specialty, 'graduation'), 'Kỷ yếu');
    expect(c.label(SkillGroup.extra, 'posing'), 'Chỉ đạo tạo dáng');
    expect(c.label(SkillGroup.extra, 'drone'), 'Flycam');
    expect(c.label(SkillGroup.language, 'vi'), 'Tiếng Việt');
    expect(c.label(SkillGroup.language, 'ko'), '한국어');
    expect(c.label(SkillGroup.audience, 'shy_subjects'), 'Người ngại ống kính');
    expect(extraLabel('low_light'), 'Thiếu sáng');
    expect(languageLabel('en'), 'English');
    expect(audienceLabel('foreigner'), 'Khách nước ngoài');
  });

  test('unknown codes render as themselves', () {
    expect(builtInSkillCatalog.label(SkillGroup.style, 'neon'), 'neon');
    expect(extraLabel('juggling'), 'juggling');
    expect(builtInSkillCatalog.item(SkillGroup.style, 'neon'), isNull);
  });

  test('retired items stay readable, are not offered, and are kept when already chosen', () {
    final c = TaxonomyCatalog(const [
      TaxonomyItem(id: 'b', group: SkillGroup.style, labelVi: 'B', order: 2),
      TaxonomyItem(id: 'a', group: SkillGroup.style, labelVi: 'A', order: 1),
      TaxonomyItem(id: 'old', group: SkillGroup.style, labelVi: 'Cũ', order: 0, active: false),
    ]);
    expect(c.ids(SkillGroup.style), ['a', 'b']);
    expect(c.isKnown(SkillGroup.style, 'old'), isTrue);
    expect(c.isSelectable(SkillGroup.style, 'old'), isFalse);
    expect(c.label(SkillGroup.style, 'old'), 'Cũ');
    expect(c.options(SkillGroup.style, keep: ['old']).map((i) => i.id), ['old', 'a', 'b']);
    expect(c.options(SkillGroup.extra), isEmpty);
  });

  test('group codes round-trip', () {
    for (final g in SkillGroup.values) {
      expect(SkillGroup.fromCode(g.code), g);
    }
    expect(SkillGroup.fromCode('area'), isNull);
    expect(SkillGroup.fromCode(null), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/skills/skill_taxonomy_test.dart`
Expected: FAIL, `skill_taxonomy.dart` does not exist and `kExtras` is undefined.

- [ ] **Step 3: Implement**

`lib/data/taxonomy/builtin_taxonomy.dart` after this task (plan 3a2 created everything above `kExtras`; keep it as is and add the rest. If the file is somehow missing, create it with this whole content):

```dart
// lib/data/taxonomy/builtin_taxonomy.dart
/// One entry of a stable-code catalogue (`taxonomy/skills/items/{id}`).
class TaxonomyOption {
  const TaxonomyOption(this.id, this.labelVi);
  final String id;
  final String labelVi;
}

/// Built-in copy of the specialty catalogue (data-model/domain-model.md §4).
/// The `taxonomy` repository of plan 2c supersedes it; ids never change.
const List<TaxonomyOption> kSpecialties = [
  TaxonomyOption('portrait', 'Chân dung'),
  TaxonomyOption('wedding', 'Cưới'),
  TaxonomyOption('couple', 'Cặp đôi'),
  TaxonomyOption('family', 'Gia đình'),
  TaxonomyOption('graduation', 'Kỷ yếu'),
  TaxonomyOption('event', 'Sự kiện'),
  TaxonomyOption('product', 'Sản phẩm'),
  TaxonomyOption('travel', 'Du lịch'),
  TaxonomyOption('fashion', 'Thời trang'),
  TaxonomyOption('food', 'Ẩm thực'),
  TaxonomyOption('real_estate', 'Bất động sản'),
  TaxonomyOption('newborn', 'Em bé'),
  TaxonomyOption('street', 'Đường phố'),
  TaxonomyOption('commercial', 'Thương mại'),
];

const List<TaxonomyOption> kStyles = [
  TaxonomyOption('natural_light', 'Ánh sáng tự nhiên'),
  TaxonomyOption('film', 'Film'),
  TaxonomyOption('minimal', 'Tối giản'),
  TaxonomyOption('editorial', 'Editorial'),
  TaxonomyOption('documentary', 'Tư liệu'),
];

/// Extra skills (spec 3e.2 `extras`). Mirrored in firestore.rules
/// (`skillExtraIds`); a test keeps the two lists equal.
const List<TaxonomyOption> kExtras = [
  TaxonomyOption('retouch', 'Hậu kỳ'),
  TaxonomyOption('posing', 'Chỉ đạo tạo dáng'),
  TaxonomyOption('video', 'Quay video'),
  TaxonomyOption('drone', 'Flycam'),
  TaxonomyOption('studio', 'Studio'),
  TaxonomyOption('kids', 'Chụp trẻ em'),
  TaxonomyOption('pets', 'Thú cưng'),
  TaxonomyOption('low_light', 'Thiếu sáng'),
  TaxonomyOption('outdoor', 'Ngoài trời'),
];

/// Languages a photographer works in, labelled in their own language.
const List<TaxonomyOption> kLanguages = [
  TaxonomyOption('vi', 'Tiếng Việt'),
  TaxonomyOption('en', 'English'),
  TaxonomyOption('zh', '中文'),
  TaxonomyOption('ko', '한국어'),
  TaxonomyOption('ja', '日本語'),
];

/// Suitable clients (spec 3e.2 `audiences`): matching signals, not
/// techniques. `couple` is also a specialty code; look items up by group.
const List<TaxonomyOption> kAudiences = [
  TaxonomyOption('couple', 'Cặp đôi'),
  TaxonomyOption('family_kids', 'Gia đình có bé nhỏ'),
  TaxonomyOption('business', 'Doanh nghiệp'),
  TaxonomyOption('foreigner', 'Khách nước ngoài'),
  TaxonomyOption('shy_subjects', 'Người ngại ống kính'),
];

String _label(List<TaxonomyOption> list, String id) {
  for (final o in list) {
    if (o.id == id) {
      return o.labelVi;
    }
  }
  return id;
}

String specialtyLabel(String id) => _label(kSpecialties, id);
String styleLabel(String id) => _label(kStyles, id);
String extraLabel(String id) => _label(kExtras, id);
String languageLabel(String id) => _label(kLanguages, id);
String audienceLabel(String id) => _label(kAudiences, id);
```

```dart
// lib/data/skills/skill_taxonomy.dart
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// Group of a skills catalogue item (`taxonomy/skills/items/{id}.group`).
enum SkillGroup {
  specialty('specialty'),
  style('style'),
  extra('extra'),
  language('language'),
  audience('audience');

  const SkillGroup(this.code);

  /// Stable string code used in data and rules.
  final String code;

  static SkillGroup? fromCode(String? code) {
    for (final g in values) {
      if (g.code == code) return g;
    }
    return null;
  }
}

/// One catalogue entry. A retired entry (`active: false`) still renders on
/// old profiles but cannot be chosen again (spec 3e.2).
class TaxonomyItem {
  const TaxonomyItem({
    required this.id,
    required this.group,
    required this.labelVi,
    required this.order,
    this.active = true,
  });

  final String id;
  final SkillGroup group;
  final String labelVi;
  final int order;
  final bool active;
}

/// The skills catalogue, keyed by `(group, id)` because a code may exist in
/// two groups (`couple` is a specialty and an audience).
class TaxonomyCatalog {
  TaxonomyCatalog(Iterable<TaxonomyItem> items)
    : _items = {for (final i in items) (i.group, i.id): i};

  final Map<(SkillGroup, String), TaxonomyItem> _items;

  TaxonomyItem? item(SkillGroup group, String id) => _items[(group, id)];

  bool isKnown(SkillGroup group, String id) => _items.containsKey((group, id));

  bool isSelectable(SkillGroup group, String id) =>
      _items[(group, id)]?.active ?? false;

  /// Vietnamese label; the code itself for unknown ids, so old data renders.
  String label(SkillGroup group, String id) =>
      _items[(group, id)]?.labelVi ?? id;

  /// What a picker shows: active items plus the retired ones in [keep]
  /// (already chosen), in catalogue order.
  List<TaxonomyItem> options(
    SkillGroup group, {
    Iterable<String> keep = const [],
  }) {
    final kept = keep.toSet();
    return _items.values
        .where((i) => i.group == group && (i.active || kept.contains(i.id)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Active ids of [group], in catalogue order.
  List<String> ids(SkillGroup group) => [for (final i in options(group)) i.id];
}

Iterable<TaxonomyItem> _fromOptions(
  SkillGroup group,
  List<TaxonomyOption> options,
) sync* {
  for (var i = 0; i < options.length; i++) {
    yield TaxonomyItem(
      id: options[i].id,
      group: group,
      labelVi: options[i].labelVi,
      order: i,
    );
  }
}

/// Built-in mirror of `taxonomy/skills` (seed list in relational-schema.md
/// §6). A remote catalogue can replace it through `skillCatalogProvider`.
final TaxonomyCatalog builtInSkillCatalog = TaxonomyCatalog([
  ..._fromOptions(SkillGroup.specialty, kSpecialties),
  ..._fromOptions(SkillGroup.style, kStyles),
  ..._fromOptions(SkillGroup.extra, kExtras),
  ..._fromOptions(SkillGroup.language, kLanguages),
  ..._fromOptions(SkillGroup.audience, kAudiences),
]);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/skills/skill_taxonomy_test.dart test/data/taxonomy && flutter analyze`
Expected: PASS (7 new tests; plan 3a2's taxonomy tests still pass); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/taxonomy lib/data/skills test/data/skills
git commit -m "feat(skills): skills catalogue keyed by group and id

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `PhotographerSkills` model and map mapping

**Files:**
- Create: `lib/data/skills/photographer_skills.dart`, `test/data/skills/photographer_skills_test.dart`

**Interfaces:**
- Consumes: `SkillGroup` (Task 1).
- Produces: `SkillLevels`, `SkillLimits`, `SpecialtySkill`, `PhotographerSkills`, `skillsToMap`, `skillsFromMap` exactly as in "Interfaces for other plans". `skillsToMap` writes `{schemaVersion, specialties[{id, level, years?, evidencePostIds}], styles, extras, languages, audiences, yearsExperience}` (no `completeness`, no `updatedAt`); the same map is the JSON of the device draft.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/skills/photographer_skills_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';

const full = PhotographerSkills(
  specialties: [
    SpecialtySkill(id: 'portrait', level: 3, years: 6, evidencePostIds: ['p1', 'p2']),
    SpecialtySkill(id: 'couple'),
  ],
  styles: ['natural_light', 'film'],
  extras: ['retouch', 'posing'],
  languages: ['vi', 'en'],
  audiences: ['couple', 'shy_subjects'],
  yearsExperience: 6,
);

void main() {
  test('writes the spec 3e.3 shape, without server fields', () {
    expect(skillsToMap(full), {
      'schemaVersion': 1,
      'specialties': [
        {'id': 'portrait', 'level': 3, 'years': 6, 'evidencePostIds': ['p1', 'p2']},
        {'id': 'couple', 'level': 2, 'evidencePostIds': <String>[]},
      ],
      'styles': ['natural_light', 'film'],
      'extras': ['retouch', 'posing'],
      'languages': ['vi', 'en'],
      'audiences': ['couple', 'shy_subjects'],
      'yearsExperience': 6,
    });
    expect(skillsToMap(PhotographerSkills.empty)['yearsExperience'], isNull);
    expect(skillsToMap(full).containsKey('completeness'), isFalse);
  });

  test('round-trips through the map and through JSON', () {
    expect(skillsFromMap(skillsToMap(full)), full);
    expect(skillsFromMap(jsonDecode(jsonEncode(skillsToMap(full)))), full);
  });

  test('reads missing or broken data without throwing', () {
    expect(skillsFromMap(null), PhotographerSkills.empty);
    expect(skillsFromMap('x'), PhotographerSkills.empty);
    final s = skillsFromMap({
      'specialties': [
        {'id': 'portrait', 'level': 9},
        {'id': 'portrait', 'level': 1},
        {'level': 2},
        'junk',
        {'id': 'wedding', 'level': 3, 'evidencePostIds': ['a', 7, 'a']},
      ],
      'styles': ['film', 3, 'film'],
      'languages': 'vi',
      'yearsExperience': '6',
      'completeness': 72,
    });
    expect(s.specialties, const [
      SpecialtySkill(id: 'portrait'),
      SpecialtySkill(id: 'wedding', level: 3, evidencePostIds: ['a']),
    ]);
    expect(s.styles, ['film']);
    expect(s.languages, isEmpty);
    expect(s.yearsExperience, isNull);
  });

  test('derived values', () {
    expect(full.specialtyIds, ['portrait', 'couple']);
    expect(full.expertCount, 1);
    expect(full.evidencePostIds, {'p1', 'p2'});
    expect(full.specialty('couple')!.level, SkillLevels.proficient);
    expect(full.specialty('food'), isNull);
    expect(full.tags(SkillGroup.audience), ['couple', 'shy_subjects']);
    expect(full.tags(SkillGroup.specialty), ['portrait', 'couple']);
    expect(PhotographerSkills.empty.isEmpty, isTrue);
    expect(full.isEmpty, isFalse);
    expect(PhotographerSkills.initial.languages, ['vi']);
  });

  test('value equality, copyWith and withTags', () {
    expect(skillsFromMap(skillsToMap(full)).hashCode, full.hashCode);
    expect(full.copyWith(yearsExperience: null).yearsExperience, isNull);
    expect(full.copyWith().yearsExperience, 6);
    expect(full.withTags(SkillGroup.style, ['minimal']).styles, ['minimal']);
    expect(full.withTags(SkillGroup.language, ['ja']).languages, ['ja']);
    expect(() => full.withTags(SkillGroup.specialty, const []), throwsArgumentError);
    expect(full == full.copyWith(styles: ['film', 'natural_light']), isFalse);
    expect(
      const SpecialtySkill(id: 'x', years: 2).copyWith(level: 3),
      const SpecialtySkill(id: 'x', level: 3, years: 2),
    );
  });

  test('limits match spec 3e.2', () {
    expect(SkillLimits.maxFor(SkillGroup.specialty), 6);
    expect(SkillLimits.maxFor(SkillGroup.style), 4);
    expect(SkillLimits.maxFor(SkillGroup.extra), 8);
    expect(SkillLimits.maxFor(SkillGroup.language), 5);
    expect(SkillLimits.maxFor(SkillGroup.audience), 4);
    expect(SkillLimits.maxExpert, 3);
    expect(SkillLimits.maxEvidence, 3);
    expect(SkillLimits.maxYears, 50);
    expect(SkillLevels.all, [1, 2, 3]);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/skills/photographer_skills_test.dart`
Expected: FAIL, `photographer_skills.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/skills/photographer_skills.dart
import 'package:flutter/foundation.dart' show listEquals;

import 'package:photobooking/data/skills/skill_taxonomy.dart';

/// Specialty levels. The data model keeps them as the numbers 1..3 on
/// purpose (they have a real order); the recommender weighs them
/// 0.4 / 0.7 / 1.0 (spec 3e.6).
abstract final class SkillLevels {
  static const basic = 1;
  static const proficient = 2;
  static const expert = 3;
  static const all = [basic, proficient, expert];
}

/// Limits of spec 3e.2, shared by validation, edits, widgets and the
/// Firestore rules (which repeat the numbers).
abstract final class SkillLimits {
  static const schemaVersion = 1;
  static const maxSpecialties = 6;
  static const maxExpert = 3;
  static const maxEvidence = 3;
  static const maxStyles = 4;
  static const maxExtras = 8;
  static const maxLanguages = 5;
  static const maxAudiences = 4;
  static const maxYears = 50;

  static int maxFor(SkillGroup group) => switch (group) {
    SkillGroup.specialty => maxSpecialties,
    SkillGroup.style => maxStyles,
    SkillGroup.extra => maxExtras,
    SkillGroup.language => maxLanguages,
    SkillGroup.audience => maxAudiences,
  };
}

/// One chosen genre with its level and evidence posts.
class SpecialtySkill {
  const SpecialtySkill({
    required this.id,
    this.level = SkillLevels.proficient,
    this.years,
    this.evidencePostIds = const [],
  });

  final String id;

  /// 1 Cơ bản, 2 Thành thạo, 3 Chuyên sâu.
  final int level;

  /// Optional years in this genre (kept as read; not edited in S38).
  final int? years;

  /// The photographer's own post ids, 0..3, in the order they were picked.
  final List<String> evidencePostIds;

  bool get isExpert => level == SkillLevels.expert;

  SpecialtySkill copyWith({int? level, List<String>? evidencePostIds}) =>
      SpecialtySkill(
        id: id,
        level: level ?? this.level,
        years: years,
        evidencePostIds: evidencePostIds ?? this.evidencePostIds,
      );

  @override
  bool operator ==(Object other) =>
      other is SpecialtySkill &&
      other.id == id &&
      other.level == level &&
      other.years == years &&
      listEquals(other.evidencePostIds, evidencePostIds);

  @override
  int get hashCode =>
      Object.hash(id, level, years, Object.hashAll(evidencePostIds));

  @override
  String toString() => 'SpecialtySkill($id, $level, $years, $evidencePostIds)';
}

const Object _keep = Object();

/// The client-owned part of `photographers/{uid}.skills` (spec 3e.3).
/// `completeness` and `updatedAt` belong to the server and are not here.
class PhotographerSkills {
  const PhotographerSkills({
    this.specialties = const [],
    this.styles = const [],
    this.extras = const [],
    this.languages = const [],
    this.audiences = const [],
    this.yearsExperience,
  });

  static const empty = PhotographerSkills();

  /// Where a photographer without saved skills starts: Vietnamese ticked.
  static const initial = PhotographerSkills(languages: ['vi']);

  final List<SpecialtySkill> specialties;
  final List<String> styles;
  final List<String> extras;
  final List<String> languages;
  final List<String> audiences;
  final int? yearsExperience;

  List<String> get specialtyIds => [for (final s in specialties) s.id];

  SpecialtySkill? specialty(String id) {
    for (final s in specialties) {
      if (s.id == id) return s;
    }
    return null;
  }

  int get expertCount => specialties.where((s) => s.isExpert).length;

  /// Every post used as evidence, for the small badge on S03.
  Set<String> get evidencePostIds => {
    for (final s in specialties) ...s.evidencePostIds,
  };

  /// The chosen ids of one group.
  List<String> tags(SkillGroup group) => switch (group) {
    SkillGroup.specialty => specialtyIds,
    SkillGroup.style => styles,
    SkillGroup.extra => extras,
    SkillGroup.language => languages,
    SkillGroup.audience => audiences,
  };

  bool get isEmpty => this == empty;

  /// [yearsExperience] takes an `int?`; pass `null` to clear it.
  PhotographerSkills copyWith({
    List<SpecialtySkill>? specialties,
    List<String>? styles,
    List<String>? extras,
    List<String>? languages,
    List<String>? audiences,
    Object? yearsExperience = _keep,
  }) => PhotographerSkills(
    specialties: specialties ?? this.specialties,
    styles: styles ?? this.styles,
    extras: extras ?? this.extras,
    languages: languages ?? this.languages,
    audiences: audiences ?? this.audiences,
    yearsExperience: identical(yearsExperience, _keep)
        ? this.yearsExperience
        : yearsExperience as int?,
  );

  /// Replaces the ids of a tag group; specialties have their own rows.
  PhotographerSkills withTags(SkillGroup group, List<String> ids) =>
      switch (group) {
        SkillGroup.specialty => throw ArgumentError.value(
          group,
          'group',
          'specialties are edited as SpecialtySkill rows',
        ),
        SkillGroup.style => copyWith(styles: ids),
        SkillGroup.extra => copyWith(extras: ids),
        SkillGroup.language => copyWith(languages: ids),
        SkillGroup.audience => copyWith(audiences: ids),
      };

  @override
  bool operator ==(Object other) =>
      other is PhotographerSkills &&
      listEquals(other.specialties, specialties) &&
      listEquals(other.styles, styles) &&
      listEquals(other.extras, extras) &&
      listEquals(other.languages, languages) &&
      listEquals(other.audiences, audiences) &&
      other.yearsExperience == yearsExperience;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(specialties),
    Object.hashAll(styles),
    Object.hashAll(extras),
    Object.hashAll(languages),
    Object.hashAll(audiences),
    yearsExperience,
  );

  @override
  String toString() => 'PhotographerSkills(${skillsToMap(this)})';
}

/// The map written to `photographers/{uid}.skills` (and the device draft's
/// JSON). `yearsExperience` is always present (null when unknown) so a merge
/// write clears an old value; server fields are never included.
Map<String, Object?> skillsToMap(PhotographerSkills s) => {
  'schemaVersion': SkillLimits.schemaVersion,
  'specialties': [
    for (final sp in s.specialties)
      {
        'id': sp.id,
        'level': sp.level,
        if (sp.years != null) 'years': sp.years,
        'evidencePostIds': [...sp.evidencePostIds],
      },
  ],
  'styles': [...s.styles],
  'extras': [...s.extras],
  'languages': [...s.languages],
  'audiences': [...s.audiences],
  'yearsExperience': s.yearsExperience,
};

/// Tolerant reader: malformed entries are dropped and a bad level becomes
/// [SkillLevels.proficient], so old or partial documents still open.
PhotographerSkills skillsFromMap(Object? raw) {
  if (raw is! Map) return PhotographerSkills.empty;
  final specialties = <SpecialtySkill>[];
  final seen = <String>{};
  final list = raw['specialties'];
  if (list is List) {
    for (final e in list) {
      if (e is! Map) continue;
      final id = e['id'];
      if (id is! String || !seen.add(id)) continue;
      final level = e['level'];
      final years = e['years'];
      specialties.add(
        SpecialtySkill(
          id: id,
          level: level is int && SkillLevels.all.contains(level)
              ? level
              : SkillLevels.proficient,
          years: years is int ? years : null,
          evidencePostIds: _strings(e['evidencePostIds']),
        ),
      );
    }
  }
  final years = raw['yearsExperience'];
  return PhotographerSkills(
    specialties: specialties,
    styles: _strings(raw['styles']),
    extras: _strings(raw['extras']),
    languages: _strings(raw['languages']),
    audiences: _strings(raw['audiences']),
    yearsExperience: years is int ? years : null,
  );
}

List<String> _strings(Object? v) => v is List
    ? [
        ...<String>{
          for (final x in v)
            if (x is String) x,
        },
      ]
    : const [];
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/skills/photographer_skills_test.dart && flutter analyze`
Expected: PASS, 6 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/skills test/data/skills
git commit -m "feat(skills): PhotographerSkills model and spec 3e.3 map mapping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Validation and edit rules (table tests)

**Files:**
- Create: `lib/data/skills/skills_rules.dart`, `test/data/skills/skills_rules_test.dart`

**Interfaces:**
- Consumes: `PhotographerSkills`, `SpecialtySkill`, `SkillLevels`, `SkillLimits` (Task 2); `TaxonomyCatalog`, `SkillGroup`, `builtInSkillCatalog` (Task 1).
- Produces:
  - `enum SkillIssueCode { noSpecialty, noLanguage, tooManyItems, duplicateItem, unknownItem, retiredItem, invalidLevel, tooManyExpert, expertNeedsEvidence, tooManyEvidence, duplicateEvidence, invalidEvidenceId, yearsOutOfRange }`
  - `class SkillIssue { const SkillIssue(SkillIssueCode code, {SkillGroup? group, String? itemId}); }` with value equality.
  - `List<SkillIssue> validateSkills(PhotographerSkills s, TaxonomyCatalog catalog, {PhotographerSkills previous = PhotographerSkills.empty})` — issues in screen order (genres, levels/evidence, styles, extras, languages, audiences, years); `previous` lets retired ids already saved stay.
  - `enum SkillEditRejection { tooManyItems, tooManyExpert, tooManyEvidence, notSelectable }`, `class SkillEdit { const SkillEdit(PhotographerSkills skills, {SkillEditRejection? rejection, SkillGroup? group}); bool get accepted; }`
  - `SkillEdit withSpecialtyToggled(PhotographerSkills s, String id, TaxonomyCatalog catalog)` (adds at level 2; removal drops its evidence), `SkillEdit withSpecialtyLevel(PhotographerSkills s, String id, int level)`, `SkillEdit withTagToggled(PhotographerSkills s, SkillGroup group, String id, TaxonomyCatalog catalog)`, `SkillEdit withEvidence(PhotographerSkills s, String specialtyId, List<String> postIds)`, `PhotographerSkills withYearsExperience(PhotographerSkills s, int? years)`, `PhotographerSkills withoutMissingEvidence(PhotographerSkills s, Set<String> existingPostIds)`. A rejected edit returns the input unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/skills/skills_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_rules.dart';

final catalog = builtInSkillCatalog;

SpecialtySkill sp(String id, [int level = 2, List<String> ev = const []]) =>
    SpecialtySkill(id: id, level: level, evidencePostIds: ev);

const valid = PhotographerSkills(
  specialties: [
    SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1']),
    SpecialtySkill(id: 'couple'),
  ],
  styles: ['film'],
  languages: ['vi'],
);

SkillIssue issue(SkillIssueCode code, [SkillGroup? group, String? id]) =>
    SkillIssue(code, group: group, itemId: id);

void main() {
  group('validateSkills (spec §7: limits, unknown ids, level 3 without evidence)', () {
    const g = SkillGroup.specialty;
    final cases = <(String, PhotographerSkills, List<SkillIssue>)>[
      ('a valid profile', valid, []),
      ('the mock profile', const PhotographerSkills(
        specialties: [
          SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['a', 'b']),
          SpecialtySkill(id: 'couple'),
          SpecialtySkill(id: 'family', level: 1),
        ],
        styles: ['natural_light', 'film'],
        extras: ['retouch', 'posing', 'kids'],
        languages: ['vi', 'en'],
        audiences: ['couple', 'family_kids', 'shy_subjects'],
        yearsExperience: 6,
      ), []),
      ('no genre', valid.copyWith(specialties: []), [issue(SkillIssueCode.noSpecialty, g)]),
      ('7 genres', valid.copyWith(specialties: [
        for (final id in ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event', 'product']) sp(id),
      ]), [issue(SkillIssueCode.tooManyItems, g)]),
      ('unknown genre', valid.copyWith(specialties: [sp('underwater')]),
          [issue(SkillIssueCode.unknownItem, g, 'underwater')]),
      ('an audience code used as a genre', valid.copyWith(specialties: [sp('shy_subjects')]),
          [issue(SkillIssueCode.unknownItem, g, 'shy_subjects')]),
      ('duplicate genre', valid.copyWith(specialties: [sp('portrait'), sp('portrait')]),
          [issue(SkillIssueCode.duplicateItem, g, 'portrait')]),
      ('level 4', valid.copyWith(specialties: [sp('portrait', 4)]),
          [issue(SkillIssueCode.invalidLevel, g, 'portrait')]),
      ('level 0', valid.copyWith(specialties: [sp('portrait', 0)]),
          [issue(SkillIssueCode.invalidLevel, g, 'portrait')]),
      ('level 3 without evidence', valid.copyWith(specialties: [sp('portrait', 3)]),
          [issue(SkillIssueCode.expertNeedsEvidence, g, 'portrait')]),
      ('4 genres at level 3', valid.copyWith(specialties: [
        sp('portrait', 3, ['a']), sp('wedding', 3, ['b']), sp('couple', 3, ['c']), sp('family', 3, ['d']),
      ]), [issue(SkillIssueCode.tooManyExpert, g)]),
      ('4 evidence posts', valid.copyWith(specialties: [sp('portrait', 2, ['a', 'b', 'c', 'd'])]),
          [issue(SkillIssueCode.tooManyEvidence, g, 'portrait')]),
      ('duplicate evidence', valid.copyWith(specialties: [sp('portrait', 3, ['a', 'a'])]),
          [issue(SkillIssueCode.duplicateEvidence, g, 'portrait')]),
      ('malformed evidence id', valid.copyWith(specialties: [sp('portrait', 2, ['a/b'])]),
          [issue(SkillIssueCode.invalidEvidenceId, g, 'portrait')]),
      ('genre years 60', valid.copyWith(specialties: [const SpecialtySkill(id: 'portrait', years: 60)]),
          [issue(SkillIssueCode.yearsOutOfRange, g, 'portrait')]),
      ('5 styles', valid.copyWith(styles: ['natural_light', 'film', 'minimal', 'editorial', 'documentary']),
          [issue(SkillIssueCode.tooManyItems, SkillGroup.style)]),
      ('unknown style', valid.copyWith(styles: ['neon']),
          [issue(SkillIssueCode.unknownItem, SkillGroup.style, 'neon')]),
      ('duplicate style', valid.copyWith(styles: ['film', 'film']),
          [issue(SkillIssueCode.duplicateItem, SkillGroup.style, 'film')]),
      ('9 extras', valid.copyWith(extras: [
        'retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light', 'outdoor',
      ]), [issue(SkillIssueCode.tooManyItems, SkillGroup.extra)]),
      ('5 audiences', valid.copyWith(audiences: ['couple', 'family_kids', 'business', 'foreigner', 'shy_subjects']),
          [issue(SkillIssueCode.tooManyItems, SkillGroup.audience)]),
      ('unknown language', valid.copyWith(languages: ['vi', 'fr']),
          [issue(SkillIssueCode.unknownItem, SkillGroup.language, 'fr')]),
      ('no language', valid.copyWith(languages: []),
          [issue(SkillIssueCode.noLanguage, SkillGroup.language)]),
      ('all five languages', valid.copyWith(languages: ['vi', 'en', 'zh', 'ko', 'ja']), []),
      ('51 years', valid.copyWith(yearsExperience: 51), [issue(SkillIssueCode.yearsOutOfRange)]),
      ('-1 years', valid.copyWith(yearsExperience: -1), [issue(SkillIssueCode.yearsOutOfRange)]),
      ('0 and 50 years', valid.copyWith(yearsExperience: 50), []),
    ];
    for (final (name, skills, expected) in cases) {
      test(name, () => expect(validateSkills(skills, catalog), expected));
    }

    test('several problems are all reported, in screen order', () {
      final s = valid.copyWith(
        specialties: [sp('portrait', 3)],
        styles: ['neon'],
        languages: [],
        yearsExperience: 99,
      );
      expect(validateSkills(s, catalog), [
        issue(SkillIssueCode.expertNeedsEvidence, g, 'portrait'),
        issue(SkillIssueCode.unknownItem, SkillGroup.style, 'neon'),
        issue(SkillIssueCode.noLanguage, SkillGroup.language),
        issue(SkillIssueCode.yearsOutOfRange),
      ]);
    });

    test('a retired item is refused when new, kept when it was already saved', () {
      final c = TaxonomyCatalog([
        ...SkillGroup.values.expand((grp) => [
          for (final id in builtInSkillCatalog.ids(grp))
            builtInSkillCatalog.item(grp, id)!,
        ]),
        const TaxonomyItem(id: 'lomo', group: SkillGroup.style, labelVi: 'Lomo', order: 99, active: false),
      ]);
      final s = valid.copyWith(styles: ['lomo']);
      expect(validateSkills(s, c), [issue(SkillIssueCode.retiredItem, SkillGroup.style, 'lomo')]);
      expect(validateSkills(s, c, previous: s), isEmpty);
    });
  });

  group('edits', () {
    test('choosing a genre adds a Thành thạo row; removing drops its evidence', () {
      final added = withSpecialtyToggled(PhotographerSkills.initial, 'portrait', catalog);
      expect(added.accepted, isTrue);
      expect(added.skills.specialties, [const SpecialtySkill(id: 'portrait')]);
      final withEv = withEvidence(added.skills, 'portrait', ['a']).skills;
      final removed = withSpecialtyToggled(withEv, 'portrait', catalog);
      expect(removed.skills.specialties, isEmpty);
      expect(removed.skills.evidencePostIds, isEmpty);
    });

    test('the 7th genre is refused and nothing changes', () {
      final six = valid.copyWith(specialties: [
        for (final id in ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event']) sp(id),
      ]);
      final e = withSpecialtyToggled(six, 'product', catalog);
      expect(e.rejection, SkillEditRejection.tooManyItems);
      expect(e.group, SkillGroup.specialty);
      expect(e.skills, six);
    });

    test('unknown or retired items cannot be chosen', () {
      expect(withSpecialtyToggled(valid, 'underwater', catalog).rejection, SkillEditRejection.notSelectable);
      expect(withTagToggled(valid, SkillGroup.style, 'neon', catalog).rejection, SkillEditRejection.notSelectable);
    });

    test('the 4th Chuyên sâu is refused and the old level is kept', () {
      final three = valid.copyWith(specialties: [
        sp('portrait', 3, ['a']), sp('wedding', 3, ['b']), sp('couple', 3, ['c']), sp('family'),
      ]);
      final e = withSpecialtyLevel(three, 'family', SkillLevels.expert);
      expect(e.rejection, SkillEditRejection.tooManyExpert);
      expect(e.skills.specialty('family')!.level, SkillLevels.proficient);
      expect(withSpecialtyLevel(three, 'portrait', 3).accepted, isTrue, reason: 'already expert');
      expect(withSpecialtyLevel(three, 'family', 1).skills.specialty('family')!.level, 1);
    });

    test('level edits need a chosen genre and a level of 1..3', () {
      expect(() => withSpecialtyLevel(valid, 'food', 2), throwsArgumentError);
      expect(() => withSpecialtyLevel(valid, 'couple', 4), throwsArgumentError);
    });

    test('tag limits per group', () {
      var s = PhotographerSkills.initial;
      for (final id in ['natural_light', 'film', 'minimal', 'editorial']) {
        s = withTagToggled(s, SkillGroup.style, id, catalog).skills;
      }
      final fifth = withTagToggled(s, SkillGroup.style, 'documentary', catalog);
      expect((fifth.rejection, fifth.group), (SkillEditRejection.tooManyItems, SkillGroup.style));
      expect(withTagToggled(s, SkillGroup.style, 'film', catalog).skills.styles,
          ['natural_light', 'minimal', 'editorial']);
      for (final id in ['en', 'zh', 'ko', 'ja']) {
        s = withTagToggled(s, SkillGroup.language, id, catalog).skills;
      }
      expect(s.languages, hasLength(5));
      expect(withTagToggled(s, SkillGroup.language, 'vi', catalog).skills.languages, hasLength(4),
          reason: 'unticking the last language is allowed; Tiếp tục reports it');
      expect(() => withTagToggled(s, SkillGroup.specialty, 'portrait', catalog), throwsArgumentError);
    });

    test('evidence: order kept, duplicates dropped, more than 3 refused', () {
      expect(withEvidence(valid, 'couple', ['b', 'a', 'b']).skills.specialty('couple')!.evidencePostIds, ['b', 'a']);
      final e = withEvidence(valid, 'couple', ['a', 'b', 'c', 'd']);
      expect(e.rejection, SkillEditRejection.tooManyEvidence);
      expect(e.skills, valid);
      expect(() => withEvidence(valid, 'food', ['a']), throwsArgumentError);
    });

    test('years are stored as given and checked by validation', () {
      expect(withYearsExperience(valid, 7).yearsExperience, 7);
      expect(withYearsExperience(valid, null).yearsExperience, isNull);
    });

    test('deleted posts leave the evidence lists', () {
      final s = valid.copyWith(specialties: [sp('portrait', 3, ['a', 'gone']), sp('couple', 2, ['gone'])]);
      final pruned = withoutMissingEvidence(s, {'a'});
      expect(pruned.specialty('portrait')!.evidencePostIds, ['a']);
      expect(pruned.specialty('couple')!.evidencePostIds, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/skills/skills_rules_test.dart`
Expected: FAIL, `skills_rules.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/skills/skills_rules.dart
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';

enum SkillIssueCode {
  noSpecialty,
  noLanguage,
  tooManyItems,
  duplicateItem,
  unknownItem,
  retiredItem,
  invalidLevel,
  tooManyExpert,
  expertNeedsEvidence,
  tooManyEvidence,
  duplicateEvidence,
  invalidEvidenceId,
  yearsOutOfRange,
}

/// One reason the skills cannot be saved. [group] says which section to
/// show it in; [itemId] is the offending id (a genre for evidence/levels).
class SkillIssue {
  const SkillIssue(this.code, {this.group, this.itemId});

  final SkillIssueCode code;
  final SkillGroup? group;
  final String? itemId;

  @override
  bool operator ==(Object other) =>
      other is SkillIssue &&
      other.code == code &&
      other.group == group &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(code, group, itemId);

  @override
  String toString() => 'SkillIssue(${code.name}, ${group?.code}, $itemId)';
}

/// Same pattern as data-model ids and the Firestore rules.
final _postId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Everything that stops [s] from being saved, in the order the sections
/// appear on S38/S39. Ids already in [previous] may be retired items.
List<SkillIssue> validateSkills(
  PhotographerSkills s,
  TaxonomyCatalog catalog, {
  PhotographerSkills previous = PhotographerSkills.empty,
}) {
  final issues = <SkillIssue>[];

  void checkItems(SkillGroup group, List<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        issues.add(
          SkillIssue(SkillIssueCode.duplicateItem, group: group, itemId: id),
        );
      } else if (!catalog.isKnown(group, id)) {
        issues.add(
          SkillIssue(SkillIssueCode.unknownItem, group: group, itemId: id),
        );
      } else if (!catalog.isSelectable(group, id) &&
          !previous.tags(group).contains(id)) {
        issues.add(
          SkillIssue(SkillIssueCode.retiredItem, group: group, itemId: id),
        );
      }
    }
    if (ids.length > SkillLimits.maxFor(group)) {
      issues.add(SkillIssue(SkillIssueCode.tooManyItems, group: group));
    }
  }

  const g = SkillGroup.specialty;
  if (s.specialties.isEmpty) {
    issues.add(const SkillIssue(SkillIssueCode.noSpecialty, group: g));
  }
  checkItems(g, s.specialtyIds);
  for (final sp in s.specialties) {
    if (!SkillLevels.all.contains(sp.level)) {
      issues.add(
        SkillIssue(SkillIssueCode.invalidLevel, group: g, itemId: sp.id),
      );
    }
    final years = sp.years;
    if (years != null && (years < 0 || years > SkillLimits.maxYears)) {
      issues.add(
        SkillIssue(SkillIssueCode.yearsOutOfRange, group: g, itemId: sp.id),
      );
    }
    final ev = sp.evidencePostIds;
    if (ev.length > SkillLimits.maxEvidence) {
      issues.add(
        SkillIssue(SkillIssueCode.tooManyEvidence, group: g, itemId: sp.id),
      );
    }
    if (ev.toSet().length != ev.length) {
      issues.add(
        SkillIssue(SkillIssueCode.duplicateEvidence, group: g, itemId: sp.id),
      );
    }
    if (ev.any((id) => !_postId.hasMatch(id))) {
      issues.add(
        SkillIssue(SkillIssueCode.invalidEvidenceId, group: g, itemId: sp.id),
      );
    }
    if (sp.isExpert && ev.isEmpty) {
      issues.add(
        SkillIssue(SkillIssueCode.expertNeedsEvidence, group: g, itemId: sp.id),
      );
    }
  }
  if (s.expertCount > SkillLimits.maxExpert) {
    issues.add(const SkillIssue(SkillIssueCode.tooManyExpert, group: g));
  }
  checkItems(SkillGroup.style, s.styles);
  checkItems(SkillGroup.extra, s.extras);
  checkItems(SkillGroup.language, s.languages);
  if (s.languages.isEmpty) {
    issues.add(
      const SkillIssue(SkillIssueCode.noLanguage, group: SkillGroup.language),
    );
  }
  checkItems(SkillGroup.audience, s.audiences);
  final years = s.yearsExperience;
  if (years != null && (years < 0 || years > SkillLimits.maxYears)) {
    issues.add(const SkillIssue(SkillIssueCode.yearsOutOfRange));
  }
  return issues;
}

enum SkillEditRejection { tooManyItems, tooManyExpert, tooManyEvidence, notSelectable }

/// Result of one edit: the new skills, or the unchanged input plus why the
/// edit was refused ([group] tells which limit for `tooManyItems`).
class SkillEdit {
  const SkillEdit(this.skills, {this.rejection, this.group});

  final PhotographerSkills skills;
  final SkillEditRejection? rejection;
  final SkillGroup? group;

  bool get accepted => rejection == null;
}

/// Ticks or unticks a genre. A new genre starts at "Thành thạo"; unticking
/// removes its level and evidence.
SkillEdit withSpecialtyToggled(
  PhotographerSkills s,
  String id,
  TaxonomyCatalog catalog,
) {
  if (s.specialty(id) != null) {
    return SkillEdit(
      s.copyWith(specialties: [
        for (final sp in s.specialties)
          if (sp.id != id) sp,
      ]),
    );
  }
  if (!catalog.isSelectable(SkillGroup.specialty, id)) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.notSelectable,
      group: SkillGroup.specialty,
    );
  }
  if (s.specialties.length >= SkillLimits.maxSpecialties) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyItems,
      group: SkillGroup.specialty,
    );
  }
  return SkillEdit(
    s.copyWith(specialties: [...s.specialties, SpecialtySkill(id: id)]),
  );
}

/// Sets a chosen genre's level; a 4th "Chuyên sâu" is refused.
SkillEdit withSpecialtyLevel(PhotographerSkills s, String id, int level) {
  final current = s.specialty(id);
  if (current == null) {
    throw ArgumentError.value(id, 'id', 'genre is not chosen');
  }
  if (!SkillLevels.all.contains(level)) {
    throw ArgumentError.value(level, 'level', 'must be 1..3');
  }
  if (current.level == level) return SkillEdit(s);
  if (level == SkillLevels.expert && s.expertCount >= SkillLimits.maxExpert) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyExpert,
      group: SkillGroup.specialty,
    );
  }
  return SkillEdit(
    s.copyWith(specialties: [
      for (final sp in s.specialties)
        sp.id == id ? sp.copyWith(level: level) : sp,
    ]),
  );
}

/// Ticks or unticks a style, extra skill, language or audience.
SkillEdit withTagToggled(
  PhotographerSkills s,
  SkillGroup group,
  String id,
  TaxonomyCatalog catalog,
) {
  if (group == SkillGroup.specialty) {
    throw ArgumentError.value(group, 'group', 'use withSpecialtyToggled');
  }
  final ids = s.tags(group);
  if (ids.contains(id)) {
    return SkillEdit(s.withTags(group, [
      for (final x in ids)
        if (x != id) x,
    ]));
  }
  if (!catalog.isSelectable(group, id)) {
    return SkillEdit(s, rejection: SkillEditRejection.notSelectable, group: group);
  }
  if (ids.length >= SkillLimits.maxFor(group)) {
    return SkillEdit(s, rejection: SkillEditRejection.tooManyItems, group: group);
  }
  return SkillEdit(s.withTags(group, [...ids, id]));
}

/// Replaces a genre's evidence posts (order kept, duplicates dropped).
SkillEdit withEvidence(
  PhotographerSkills s,
  String specialtyId,
  List<String> postIds,
) {
  if (s.specialty(specialtyId) == null) {
    throw ArgumentError.value(specialtyId, 'specialtyId', 'genre is not chosen');
  }
  final unique = <String>{...postIds}.toList();
  if (unique.length > SkillLimits.maxEvidence) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyEvidence,
      group: SkillGroup.specialty,
    );
  }
  return SkillEdit(
    s.copyWith(specialties: [
      for (final sp in s.specialties)
        sp.id == specialtyId ? sp.copyWith(evidencePostIds: unique) : sp,
    ]),
  );
}

PhotographerSkills withYearsExperience(PhotographerSkills s, int? years) =>
    s.copyWith(yearsExperience: years);

/// Drops evidence ids whose post no longer exists (spec S40: a deleted post
/// leaves the evidence and the S38 warning comes back).
PhotographerSkills withoutMissingEvidence(
  PhotographerSkills s,
  Set<String> existingPostIds,
) => s.copyWith(specialties: [
  for (final sp in s.specialties)
    sp.copyWith(evidencePostIds: [
      for (final id in sp.evidencePostIds)
        if (existingPostIds.contains(id)) id,
    ]),
]);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/skills/skills_rules_test.dart && flutter analyze`
Expected: PASS (26 table cases + 2 validation tests + 9 edit tests); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/skills test/data/skills
git commit -m "feat(skills): pure validation and edit rules with table tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Completeness score

**Files:**
- Create: `lib/data/skills/skills_completeness.dart`, `test/data/skills/skills_completeness_test.dart`

**Interfaces:**
- Consumes: `PhotographerSkills`, `SpecialtySkill`, `SkillLevels` (Task 2).
- Produces: `CompletenessStep`, `CompletenessHint`, `CompletenessReport`, `skillsCompleteness` (signatures in "Interfaces for other plans"). Formula (spec 3e.2): 25 at least one genre + 20 every genre has a level + 20 every level-3 genre has evidence + 10 styles + 10 languages + 10 audiences + 5 extras; the "levels" and "evidence" points need at least one genre. `next` is the first missing step in that order (highest points first) with the percentage once it is done; for `evidence` it names the first level-3 genre without evidence. The server Function must use this same formula (Task 13 writes it into the spec).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/skills/skills_completeness_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_completeness.dart';

void main() {
  test('weights add up to 100', () {
    expect(CompletenessStep.values.fold(0, (s, x) => s + x.points), 100);
  });

  test('empty: 0%, first thing to do is choosing a genre', () {
    final r = skillsCompleteness(PhotographerSkills.empty);
    expect(r.percent, 0);
    expect(r.missing, CompletenessStep.values);
    expect(r.next!.step, CompletenessStep.specialties);
    expect(r.next!.percentAfter, 65);
  });

  test('a new photographer with Vietnamese ticked starts at 10%', () {
    final r = skillsCompleteness(PhotographerSkills.initial);
    expect(r.percent, 10);
    expect(r.next!.percentAfter, 75);
  });

  test('one genre at Thành thạo earns genre, level and evidence points', () {
    const s = PhotographerSkills(specialties: [SpecialtySkill(id: 'portrait')], languages: ['vi']);
    final r = skillsCompleteness(s);
    expect(r.percent, 75);
    expect(r.next!.step, CompletenessStep.styles);
    expect(r.next!.percentAfter, 85);
  });

  test('a Chuyên sâu genre without evidence is named in the hint', () {
    const s = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'couple'),
        SpecialtySkill(id: 'portrait', level: 3),
      ],
      styles: ['film'],
      extras: ['retouch'],
      languages: ['vi', 'en'],
      audiences: ['couple'],
    );
    final r = skillsCompleteness(s);
    expect(r.percent, 80);
    expect(r.missing, [CompletenessStep.evidence]);
    expect(r.next!.step, CompletenessStep.evidence);
    expect(r.next!.specialtyId, 'portrait');
    expect(r.next!.percentAfter, 100);
  });

  test('a complete profile is 100% with no hint', () {
    const s = PhotographerSkills(
      specialties: [SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['a'])],
      styles: ['film'],
      extras: ['retouch'],
      languages: ['vi'],
      audiences: ['couple'],
    );
    final r = skillsCompleteness(s);
    expect(r.percent, 100);
    expect(r.missing, isEmpty);
    expect(r.next, isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/skills/skills_completeness_test.dart`
Expected: FAIL, `skills_completeness.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/skills/skills_completeness.dart
import 'package:photobooking/data/skills/photographer_skills.dart';

/// The parts of the "Độ khớp hồ sơ" score (spec 3e.2), highest first.
/// The server Function that writes `skills.completeness` uses the same
/// weights; keep both in sync.
enum CompletenessStep {
  specialties(25),
  levels(20),
  evidence(20),
  styles(10),
  languages(10),
  audiences(10),
  extras(5);

  const CompletenessStep(this.points);
  final int points;
}

/// The next thing to do and what the score becomes once it is done.
class CompletenessHint {
  const CompletenessHint(this.step, {required this.percentAfter, this.specialtyId});

  final CompletenessStep step;
  final int percentAfter;

  /// For [CompletenessStep.evidence]: the first level-3 genre without posts.
  final String? specialtyId;
}

class CompletenessReport {
  const CompletenessReport({required this.percent, required this.missing, this.next});

  /// 0..100; shown only to the photographer.
  final int percent;
  final List<CompletenessStep> missing;
  final CompletenessHint? next;
}

bool _done(PhotographerSkills s, CompletenessStep step) => switch (step) {
  CompletenessStep.specialties => s.specialties.isNotEmpty,
  CompletenessStep.levels =>
    s.specialties.isNotEmpty &&
        s.specialties.every((x) => SkillLevels.all.contains(x.level)),
  CompletenessStep.evidence =>
    s.specialties.isNotEmpty &&
        s.specialties.every((x) => !x.isExpert || x.evidencePostIds.isNotEmpty),
  CompletenessStep.styles => s.styles.isNotEmpty,
  CompletenessStep.languages => s.languages.isNotEmpty,
  CompletenessStep.audiences => s.audiences.isNotEmpty,
  CompletenessStep.extras => s.extras.isNotEmpty,
};

int _percent(PhotographerSkills s) => CompletenessStep.values
    .where((step) => _done(s, step))
    .fold(0, (sum, step) => sum + step.points);

/// Score and next step for [s]; pure, so S38 updates it on every tap.
CompletenessReport skillsCompleteness(PhotographerSkills s) {
  final missing = [
    for (final step in CompletenessStep.values)
      if (!_done(s, step)) step,
  ];
  final percent = _percent(s);
  if (missing.isEmpty) {
    return CompletenessReport(percent: percent, missing: missing);
  }
  final step = missing.first;
  final after = switch (step) {
    CompletenessStep.specialties => s.copyWith(
      specialties: const [SpecialtySkill(id: '_')],
    ),
    CompletenessStep.levels => s.copyWith(specialties: [
      for (final x in s.specialties)
        SkillLevels.all.contains(x.level)
            ? x
            : x.copyWith(level: SkillLevels.proficient),
    ]),
    CompletenessStep.evidence => s.copyWith(specialties: [
      for (final x in s.specialties)
        x.isExpert && x.evidencePostIds.isEmpty
            ? x.copyWith(evidencePostIds: const ['_'])
            : x,
    ]),
    CompletenessStep.styles => s.copyWith(styles: const ['_']),
    CompletenessStep.languages => s.copyWith(languages: const ['_']),
    CompletenessStep.audiences => s.copyWith(audiences: const ['_']),
    CompletenessStep.extras => s.copyWith(extras: const ['_']),
  };
  String? specialtyId;
  if (step == CompletenessStep.evidence) {
    specialtyId = s.specialties
        .firstWhere((x) => x.isExpert && x.evidencePostIds.isEmpty)
        .id;
  }
  return CompletenessReport(
    percent: percent,
    missing: missing,
    next: CompletenessHint(
      step,
      percentAfter: _percent(after),
      specialtyId: specialtyId,
    ),
  );
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/skills/skills_completeness_test.dart && flutter analyze`
Expected: PASS, 6 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/skills test/data/skills
git commit -m "feat(skills): completeness score with next-step hint

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 5: `SkillsRepository` port, fake, Firestore adapter and providers

**Files:**
- Create: `lib/data/skills/skills_repository.dart`, `lib/data/skills/firestore_skills_repository.dart`, `lib/data/skills/skills_providers.dart`, `test/data/skills/skills_repository_test.dart`

**Interfaces:**
- Consumes: `PhotographerSkills`, `skillsToMap`, `skillsFromMap` (Task 2); `builtInSkillCatalog`, `TaxonomyCatalog` (Task 1); `FakeFirebaseFirestore` (plan 3b1 added the dev dependency).
- Produces: `SkillsRepository`, `FakeSkillsRepository`, `skillsRepositoryProvider`, `skillCatalogProvider`, `photographerSkillsProvider` (signatures in "Interfaces for other plans"); `FirestoreSkillsRepository({FirebaseFirestore? db})`: `load` is one `get()` of `photographers/{uid}` reading the `skills` field; `save` is one `set({'skills': skillsToMap(s), 'updatedAt': serverTimestamp}, merge: true)`, so `skills.completeness` written by the server survives and other fields of the document are untouched.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/skills/skills_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';

const skills = PhotographerSkills(
  specialties: [SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1'])],
  styles: ['film'],
  languages: ['vi'],
  yearsExperience: 4,
);

void contract(String name, Future<SkillsRepository> Function() create) {
  group('$name contract', () {
    test('a photographer without skills loads as empty', () async {
      expect(await (await create()).load('nobody'), PhotographerSkills.empty);
    });

    test('save then load returns the same skills', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect(await repo.load('u1'), skills);
    });

    test('a second save replaces lists and clears years', () async {
      final repo = await create();
      await repo.save('u1', skills);
      const next = PhotographerSkills(
        specialties: [SpecialtySkill(id: 'wedding')],
        styles: ['minimal'],
        languages: ['en'],
      );
      await repo.save('u1', next);
      expect(await repo.load('u1'), next);
    });

    test('photographers are kept apart', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect(await repo.load('u2'), PhotographerSkills.empty);
    });
  });
}

void main() {
  contract('fake', () async => FakeSkillsRepository());
  contract('firestore', () async => FirestoreSkillsRepository(db: FakeFirebaseFirestore()));

  test('the fake counts calls, seeds and fails on demand', () async {
    final repo = FakeSkillsRepository()..seed('u1', skills);
    expect(await repo.load('u1'), skills);
    expect(repo.loadCalls, 1);
    repo.failSaveWith = StateError('offline');
    await expectLater(repo.save('u1', PhotographerSkills.empty), throwsStateError);
    expect(repo.stored('u1'), skills);
    expect(repo.saveCalls, 1);
    repo.failLoadWith = StateError('offline');
    await expectLater(repo.load('u1'), throwsStateError);
  });

  group('Firestore adapter', () {
    test('writes photographers/{uid}.skills in the spec shape and keeps other fields', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'bio': 'Chân dung',
        'onboardingComplete': false,
        'skills': {'completeness': 40, 'styles': ['editorial']},
      });
      await FirestoreSkillsRepository(db: db).save('u1', skills);
      final data = (await db.collection('photographers').doc('u1').get()).data()!;
      expect(data['bio'], 'Chân dung');
      expect(data['updatedAt'], isA<Timestamp>());
      final stored = Map<String, dynamic>.from(data['skills'] as Map);
      expect(stored['completeness'], 40, reason: 'server-owned, never written by the client');
      expect(stored['schemaVersion'], 1);
      expect(stored['styles'], ['film']);
      expect(stored['specialties'], [
        {'id': 'portrait', 'level': 3, 'evidencePostIds': ['p1']},
      ]);
      expect(stored['yearsExperience'], 4);
    });

    test('a document with only the old flat specialties list has no skills yet', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({'specialties': ['wedding']});
      expect(await FirestoreSkillsRepository(db: db).load('u1'), PhotographerSkills.empty);
    });
  });

  test('providers: built-in catalogue and a per-photographer read', () async {
    final repo = FakeSkillsRepository()..seed('u1', skills);
    final container = ProviderContainer(
      overrides: [skillsRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    expect(container.read(skillCatalogProvider).ids(SkillGroup.language), hasLength(5));
    final sub = container.listen(photographerSkillsProvider('u1'), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(photographerSkillsProvider('u1').future), skills);
    expect(repo.loadCalls, 1);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/skills/skills_repository_test.dart`
Expected: FAIL, the repository files do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/skills/skills_repository.dart
import 'package:photobooking/data/skills/photographer_skills.dart';

/// Reads and writes `photographers/{uid}.skills`. One-shot reads only: the
/// skills change when their owner saves them, so no screen needs a listener.
abstract class SkillsRepository {
  /// [PhotographerSkills.empty] when the photographer has not saved any.
  Future<PhotographerSkills> load(String uid);

  /// Writes the client-owned part (never `completeness` or `updatedAt` inside
  /// `skills`). Callers validate with `validateSkills` first.
  Future<void> save(String uid, PhotographerSkills skills);
}

class FakeSkillsRepository implements SkillsRepository {
  final _stored = <String, PhotographerSkills>{};
  int loadCalls = 0;
  int saveCalls = 0;
  Object? failLoadWith;
  Object? failSaveWith;

  void seed(String uid, PhotographerSkills skills) => _stored[uid] = skills;

  PhotographerSkills? stored(String uid) => _stored[uid];

  @override
  Future<PhotographerSkills> load(String uid) async {
    loadCalls++;
    final failure = failLoadWith;
    if (failure != null) throw failure;
    return _stored[uid] ?? PhotographerSkills.empty;
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) async {
    saveCalls++;
    final failure = failSaveWith;
    if (failure != null) throw failure;
    _stored[uid] = skills;
  }
}
```

```dart
// lib/data/skills/firestore_skills_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_repository.dart';

/// `photographers/{uid}.skills` on Firestore. The merge write keeps the
/// server's `skills.completeness` and every other field of the document.
class FirestoreSkillsRepository implements SkillsRepository {
  FirestoreSkillsRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  @override
  Future<PhotographerSkills> load(String uid) async {
    final snap = await _doc(uid).get();
    return skillsFromMap(snap.data()?['skills']);
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) => _doc(uid).set({
    'skills': skillsToMap(skills),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
```

```dart
// lib/data/skills/skills_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_repository.dart';

final skillsRepositoryProvider = Provider<SkillsRepository>(
  (ref) => FirestoreSkillsRepository(),
);

/// The skills catalogue. Built in today; a remote `taxonomy/skills` reader
/// (with this list as fallback) can override it without touching screens.
final skillCatalogProvider = Provider<TaxonomyCatalog>(
  (ref) => builtInSkillCatalog,
);

/// Any photographer's skills, read once while a screen shows them (S03).
final photographerSkillsProvider = FutureProvider.autoDispose
    .family<PhotographerSkills, String>(
      (ref, uid) => ref.watch(skillsRepositoryProvider).load(uid),
      retry: (_, _) => null,
    );
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/skills/skills_repository_test.dart && flutter analyze`
Expected: PASS (4 contract tests × 2, plus 4 tests); analyze clean. If the Firestore adapter fails "keeps other fields" because `fake_cloud_firestore` replaces the `skills` map instead of merging it, check the package version first (deep merge of nested maps with `SetOptions(merge: true)` is supported in current releases); if the installed version really does not merge, keep the production code (real Firestore merges nested maps) and seed the test document through the adapter-independent path `db.collection('photographers').doc('u1').update({'skills.completeness': 40})` after the save, asserting the save did not write `completeness` (`skillsToMap` has no such key). If `retry:` is not accepted by `FutureProvider.autoDispose.family` in the pinned Riverpod version, remove it (tests already pass `retry: (_, _) => null` to the container) and note it for the app-wide `ProviderScope`.

- [ ] **Step 5: Commit**

```bash
git add lib/data/skills test/data/skills
git commit -m "feat(skills): SkillsRepository port, fake and Firestore adapter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Firestore rules for `photographers/{uid}.skills`

**Files:**
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`
- Create: `test/data/skills/rules_catalogue_sync_test.dart`

**Interfaces:**
- Consumes: the existing `isOwner`, `hasPhotographerRole`, `verifiedUntouched`, `onlyKeys`, `photographerClientFields` (as changed by plan 2b) in `firebase/firestore.rules`; the `asPhotographer(uid)` helper and imports (`doc, setDoc, getDoc, updateDoc`) in `rules.test.mjs`; `builtInSkillCatalog` (Task 1).
- Produces: `photographers/{uid}` accepts a `skills` map only when it is unchanged or valid: keys limited to the spec shape, `schemaVersion == 1`, 1–6 genres with unique catalogue ids, levels 1–3 (int), at most 3 at level 3, each level-3 genre with 1–3 evidence ids, 0–3 unique evidence ids of the id pattern, optional genre `years` 0–50; styles ≤ 4, extras ≤ 8, audiences ≤ 4, languages 1–5, all unique catalogue ids; `yearsExperience` null or int 0–50; `completeness` and `skills.updatedAt` never changed by a client. Evidence ownership is not checked here (it would need one `get()` per post, beyond the rules' 10-read limit); the evidence sheet only offers the photographer's own posts and the server Function re-checks.

- [ ] **Step 1: Write the failing tests**

Append to `firebase/rules-test/rules.test.mjs`:

```js
// ---- photographers/{uid}.skills (plan 2c, spec 3e.2–3e.3) ----
const goodSkills = () => ({
  schemaVersion: 1,
  specialties: [
    { id: 'portrait', level: 3, evidencePostIds: ['post1', 'post2'] },
    { id: 'couple', level: 2, evidencePostIds: [] },
    { id: 'family', level: 1, evidencePostIds: [] },
  ],
  styles: ['natural_light', 'film'],
  extras: ['retouch', 'posing'],
  languages: ['vi', 'en'],
  audiences: ['couple', 'shy_subjects'],
  yearsExperience: 6,
});
const genre = (id, level = 2, evidencePostIds = []) => ({ id, level, evidencePostIds });
const skillsOwner = async (uid, extra = {}) => {
  await asPhotographer(uid);
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), `photographers/${uid}`), { onboardingComplete: false, verified: false, ...extra }));
  return env.authenticatedContext(uid).firestore();
};
const writeSkills = (db, uid, skills) => setDoc(doc(db, `photographers/${uid}`), { skills }, { merge: true });

test('a photographer can save valid skills in the spec shape', async () => {
  const db = await skillsOwner('k1');
  await assertSucceeds(writeSkills(db, 'k1', goodSkills()));
  await assertSucceeds(writeSkills(db, 'k1', { ...goodSkills(), yearsExperience: null }));
  await assertSucceeds(writeSkills(db, 'k1', {
    ...goodSkills(),
    specialties: [{ id: 'wedding', level: 2, years: 4, evidencePostIds: [] }],
    languages: ['vi', 'en', 'zh', 'ko', 'ja'],
  }));
});

test('skills reject ids outside the catalogue', async () => {
  const db = await skillsOwner('k2');
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), specialties: [genre('underwater')] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), specialties: [genre('shy_subjects')] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), styles: ['neon'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), extras: ['juggling'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), languages: ['fr'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), audiences: ['kids'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), styles: [7] }));
});

test('skills enforce the limits', async () => {
  const db = await skillsOwner('k3');
  const seven = ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event', 'product'].map((id) => genre(id));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: seven }));
  await assertSucceeds(writeSkills(db, 'k3', { ...goodSkills(), specialties: seven.slice(0, 6) }));
  const fourExperts = ['portrait', 'wedding', 'couple', 'family'].map((id, i) => genre(id, 3, [`e${i}`]));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: fourExperts }));
  await assertSucceeds(writeSkills(db, 'k3', { ...goodSkills(), specialties: fourExperts.slice(0, 3) }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait', 2, ['a', 'b', 'c', 'd'])] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait', 2, ['a', 'a'])] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait', 2, ['a/b'])] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait'), genre('portrait')] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), styles: ['natural_light', 'film', 'minimal', 'editorial', 'documentary'] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), styles: ['film', 'film'] }));
  await assertFails(writeSkills(db, 'k3', {
    ...goodSkills(),
    extras: ['retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light', 'outdoor'],
  }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), audiences: ['couple', 'family_kids', 'business', 'foreigner', 'shy_subjects'] }));
});

test('level 3 needs evidence; levels are the integers 1..3', async () => {
  const db = await skillsOwner('k4');
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', 3, [])] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [{ id: 'portrait', level: 3 }] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', 4)] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', 0)] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', '3', ['a'])] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [{ ...genre('portrait'), note: 'x' }] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [{ ...genre('portrait'), years: 60 }] }));
});

test('at least one genre and one language; years 0..50', async () => {
  const db = await skillsOwner('k5');
  await assertFails(writeSkills(db, 'k5', { ...goodSkills(), specialties: [] }));
  await assertFails(writeSkills(db, 'k5', { ...goodSkills(), languages: [] }));
  for (const years of [51, -1, 6.5, '6']) {
    await assertFails(writeSkills(db, 'k5', { ...goodSkills(), yearsExperience: years }));
  }
  await assertSucceeds(writeSkills(db, 'k5', { ...goodSkills(), yearsExperience: 0 }));
  await assertSucceeds(writeSkills(db, 'k5', { ...goodSkills(), yearsExperience: 50 }));
});

test('completeness and skills.updatedAt are server-only', async () => {
  const db = await skillsOwner('k6');
  await assertFails(writeSkills(db, 'k6', { ...goodSkills(), completeness: 99 }));
  await assertFails(writeSkills(db, 'k6', { ...goodSkills(), updatedAt: new Date() }));
  const db7 = await skillsOwner('k7', { skills: { ...goodSkills(), completeness: 40 } });
  // The app's merge write leaves the server value in place.
  await assertSucceeds(writeSkills(db7, 'k7', { ...goodSkills(), styles: ['minimal'] }));
  await assertFails(updateDoc(doc(db7, 'photographers/k7'), { 'skills.completeness': 99 }));
  const snap = await getDoc(doc(db7, 'photographers/k7'));
  assert.equal(snap.data().skills.completeness, 40);
});

test('skills shape: known keys only, schema version 1, owner only', async () => {
  const db = await skillsOwner('k8');
  await assertFails(writeSkills(db, 'k8', { ...goodSkills(), schemaVersion: 2 }));
  const { schemaVersion, ...noVersion } = goodSkills();
  assert.equal(schemaVersion, 1);
  await assertFails(writeSkills(db, 'k8', noVersion));
  await assertFails(writeSkills(db, 'k8', { ...goodSkills(), equipment: ['A7'] }));
  await assertFails(writeSkills(db, 'k8', 'portrait'));
  await skillsOwner('k9');
  await assertFails(writeSkills(db, 'k9', goodSkills()));
});

test('unchanged legacy skills do not block other profile edits', async () => {
  const db = await skillsOwner('k10', { skills: { schemaVersion: 1, specialties: [] } });
  await assertSucceeds(updateDoc(doc(db, 'photographers/k10'), { bio: 'Chân dung' }));
  await assertFails(writeSkills(db, 'k10', { schemaVersion: 1, specialties: [], styles: ['film'] }));
});
```

Create the sync test (a new catalogue id must be added to the rules in the same change):

```dart
// test/data/skills/rules_catalogue_sync_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';

List<String> _idsOf(String rules, String function) {
  final m = RegExp(
    'function $function\\(\\)\\s*\\{\\s*return\\s*\\[([^\\]]*)\\]',
  ).firstMatch(rules);
  expect(m, isNotNull, reason: '$function() not found in firestore.rules');
  return [
    for (final x in RegExp(r"'([a-z_]+)'").allMatches(m!.group(1)!)) x.group(1)!,
  ];
}

void main() {
  test('firestore.rules accepts exactly the built-in catalogue ids', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    for (final (function, group) in [
      ('skillSpecialtyIds', SkillGroup.specialty),
      ('skillStyleIds', SkillGroup.style),
      ('skillExtraIds', SkillGroup.extra),
      ('skillLanguageIds', SkillGroup.language),
      ('skillAudienceIds', SkillGroup.audience),
    ]) {
      expect(_idsOf(rules, function), builtInSkillCatalog.ids(group), reason: function);
    }
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/skills/rules_catalogue_sync_test.dart`
Expected: FAIL, "skillSpecialtyIds() not found in firestore.rules".

Run (from `firebase/rules-test`; needs Node, Java and the Firestore emulator, as in CI): `npm ci && npm test`
Expected: the first new test FAILS (`skills` is not an allowed key of `photographers/{uid}`). If the emulator cannot run in this sandbox, say so in the report and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

In `firebase/firestore.rules`, add `'skills'` to the list returned by `photographerClientFields()` and keep every other entry (after plan 2b it reads):

```
    function photographerClientFields() {
      return ['bio', 'specialties', 'styles', 'equipment', 'yearsExperience', 'serviceArea',
              'contactChannels', 'portfolio', 'skills', 'onboardingComplete', 'verified',
              'createdAt', 'updatedAt'];
    }
```

Add these functions next to the other photographer functions:

```
    // ---- photographers/{uid}.skills (spec 3e.2–3e.3) ----
    // Catalogue ids, mirrored from lib/data/taxonomy/builtin_taxonomy.dart; the Dart test
    // test/data/skills/rules_catalogue_sync_test.dart keeps both lists equal.
    function skillSpecialtyIds() {
      return ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event', 'product',
              'travel', 'fashion', 'food', 'real_estate', 'newborn', 'street', 'commercial'];
    }
    function skillStyleIds() { return ['natural_light', 'film', 'minimal', 'editorial', 'documentary']; }
    function skillExtraIds() {
      return ['retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light', 'outdoor'];
    }
    function skillLanguageIds() { return ['vi', 'en', 'zh', 'ko', 'ja']; }
    function skillAudienceIds() { return ['couple', 'family_kids', 'business', 'foreigner', 'shy_subjects']; }

    function uniqueTags(xs, allowed, maxSize) {
      return xs is list && xs.size() <= maxSize && xs.hasOnly(allowed) && xs.toSet().size() == xs.size();
    }
    function validPostId(v) { return v is string && v.matches('^[A-Za-z0-9_-]{1,64}$'); }
    function validEvidence(ev) {
      return ev is list && ev.size() <= 3 && ev.toSet().size() == ev.size()
        && (ev.size() < 1 || validPostId(ev[0]))
        && (ev.size() < 2 || validPostId(ev[1]))
        && (ev.size() < 3 || validPostId(ev[2]));
    }
    function validSpecialty(s) {
      return s is map
        && s.keys().hasAll(['id', 'level'])
        && s.keys().hasOnly(['id', 'level', 'years', 'evidencePostIds'])
        && s.id in skillSpecialtyIds()
        && s.level is int && s.level >= 1 && s.level <= 3
        && (!('years' in s) || (s.years is int && s.years >= 0 && s.years <= 50))
        && validEvidence(s.get('evidencePostIds', []))
        && (s.level != 3 || s.get('evidencePostIds', []).size() >= 1);
    }
    // Rules cannot loop: the six possible genre slots are checked one by one.
    function specialtySlotOk(sp, i) { return sp.size() <= i || validSpecialty(sp[i]); }
    function expertAt(sp, i) { return (sp.size() > i && sp[i].level == 3) ? 1 : 0; }
    function specialtyIdList(sp) {
      return sp.size() == 1 ? [sp[0].id]
        : sp.size() == 2 ? [sp[0].id, sp[1].id]
        : sp.size() == 3 ? [sp[0].id, sp[1].id, sp[2].id]
        : sp.size() == 4 ? [sp[0].id, sp[1].id, sp[2].id, sp[3].id]
        : sp.size() == 5 ? [sp[0].id, sp[1].id, sp[2].id, sp[3].id, sp[4].id]
        : [sp[0].id, sp[1].id, sp[2].id, sp[3].id, sp[4].id, sp[5].id];
    }
    function validSpecialties(sp) {
      return sp is list && sp.size() >= 1 && sp.size() <= 6
        && specialtySlotOk(sp, 0) && specialtySlotOk(sp, 1) && specialtySlotOk(sp, 2)
        && specialtySlotOk(sp, 3) && specialtySlotOk(sp, 4) && specialtySlotOk(sp, 5)
        && specialtyIdList(sp).toSet().size() == sp.size()
        && expertAt(sp, 0) + expertAt(sp, 1) + expertAt(sp, 2)
           + expertAt(sp, 3) + expertAt(sp, 4) + expertAt(sp, 5) <= 3;
    }
    // skills.completeness and skills.updatedAt are written by Cloud Functions only.
    function skillsServerFieldsUntouched(after) {
      let before = resource == null ? {} : resource.data.get('skills', {});
      return after.get('completeness', null) == before.get('completeness', null)
        && after.get('updatedAt', null) == before.get('updatedAt', null);
    }
    // Checked only when the client changes skills, so an old document never blocks other edits.
    function validSkills() {
      let d = request.resource.data;
      return !('skills' in d)
        || (resource != null && resource.data.get('skills', null) == d.skills)
        || (d.skills is map
            && d.skills.keys().hasOnly(['schemaVersion', 'specialties', 'styles', 'extras', 'languages',
                                        'audiences', 'yearsExperience', 'completeness', 'updatedAt'])
            && d.skills.get('schemaVersion', 0) == 1
            && validSpecialties(d.skills.get('specialties', []))
            && uniqueTags(d.skills.get('styles', []), skillStyleIds(), 4)
            && uniqueTags(d.skills.get('extras', []), skillExtraIds(), 8)
            && uniqueTags(d.skills.get('languages', []), skillLanguageIds(), 5)
            && d.skills.get('languages', []).size() >= 1
            && uniqueTags(d.skills.get('audiences', []), skillAudienceIds(), 4)
            && (d.skills.get('yearsExperience', null) == null
                || (d.skills.yearsExperience is int
                    && d.skills.yearsExperience >= 0 && d.skills.yearsExperience <= 50))
            && skillsServerFieldsUntouched(d.skills));
    }
```

In `match /photographers/{uid}`, append `&& validSkills()` as the last condition of `allow create, update` (after plan 2b it ends with `&& validContactChannels(uid)`, so it becomes `... && validContactChannels(uid) && validSkills();`).

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/skills/rules_catalogue_sync_test.dart`
Expected: PASS.

Run (from `firebase/rules-test`): `npm test`
Expected: all rules tests pass, old and new. If the emulator reports a function-call or expression limit, split `validSpecialties` into two functions (slots 0–2 and slots 3–5 plus the id and expert checks) rather than loosening a check. If any other new expression is rejected, read the emulator's rule error (it names the line), fix that expression and keep the test unchanged.

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules firebase/rules-test/rules.test.mjs test/data/skills/rules_catalogue_sync_test.dart
git commit -m "feat(rules): validate photographers/{uid}.skills shape, limits and catalogue ids

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 7: `SkillChip` and `CompletenessMeter`

**Files:**
- Create: `lib/core/widgets/skill_chip.dart`, `lib/core/widgets/completeness_meter.dart`, `test/core/widgets/skill_chip_test.dart`, `test/core/widgets/completeness_meter_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `AppChip`, `AppChipKind` (plan 3a1); `ctaGradientFor` (`cta_surface.dart`); `hostWidget`.
- Produces:
  - `const SkillChip({super.key, required String label, required bool selected, required VoidCallback onTap, bool disabled = false})` — `AppChip(kind: context)`; `disabled` (the group is at its limit) dims an unselected chip to 50% and adds the hint "Đã đủ số lượng", but taps are still reported so the screen can say which limit was reached. No `BackdropFilter`.
  - `const CompletenessMeter({super.key, required int percent, String? nextHint})` — title "Độ khớp hồ sơ" + "72%", a 6dp gradient bar, the hint line; one semantics node (label, value "72%", hint). Values outside 0..100 are clamped.
  - l10n: `skillChipFull`, `completenessTitle`, `completenessPercent(int percent)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/skill_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('a context-kind chip that reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(hostWidget(SkillChip(label: 'Chân dung', selected: true, onTap: () => taps++)));
    expect(tester.widget<AppChip>(find.byType(AppChip)).kind, AppChipKind.context);
    expect(tester.widget<AppChip>(find.byType(AppChip)).selected, isTrue);
    await tester.tap(find.text('Chân dung'));
    expect(taps, 1);
  });

  testWidgets('at the limit: dimmed, hint read out, taps still reported', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(hostWidget(
      SkillChip(label: 'Cưới', selected: false, disabled: true, onTap: () => taps++),
    ));
    final opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(SkillChip), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.5);
    expect(
      tester.getSemantics(find.byType(SkillChip)),
      containsSemantics(label: 'Cưới', hint: 'Đã đủ số lượng', isButton: true),
    );
    await tester.tap(find.text('Cưới'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a selected chip is never dimmed', (tester) async {
    await tester.pumpWidget(hostWidget(
      SkillChip(label: 'Cưới', selected: true, disabled: true, onTap: () {}),
    ));
    final opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(SkillChip), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('no blur inside a chip; fits 320dp at 1.3x in both themes', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(hostWidget(
        Wrap(children: [
          for (final l in ['Người ngại ống kính', 'Gia đình có bé nhỏ', 'Chỉ đạo tạo dáng', 'Ánh sáng tự nhiên'])
            SkillChip(label: l, selected: l.length.isEven, disabled: true, onTap: () {}),
        ]),
        width: 320,
        textScale: 1.3,
        brightness: b,
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });
}
```

```dart
// test/core/widgets/completeness_meter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('title, percentage, bar fill and hint', (tester) async {
    await tester.pumpWidget(hostWidget(
      const CompletenessMeter(percent: 72, nextHint: 'Thêm ảnh minh chứng cho Chân dung để lên 92%'),
    ));
    expect(find.text('Độ khớp hồ sơ'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('Thêm ảnh minh chứng cho Chân dung để lên 92%'), findsOneWidget);
    expect(tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor, 0.72);
  });

  testWidgets('one semantics node with value and hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const CompletenessMeter(percent: 40, nextHint: 'Gợi ý')));
    expect(
      tester.getSemantics(find.byType(CompletenessMeter)),
      containsSemantics(label: 'Độ khớp hồ sơ', value: '40%', hint: 'Gợi ý'),
    );
    handle.dispose();
  });

  testWidgets('clamps to 0..100 and works without a hint', (tester) async {
    await tester.pumpWidget(hostWidget(const CompletenessMeter(percent: 140)));
    expect(find.text('100%'), findsOneWidget);
    await tester.pumpWidget(hostWidget(const CompletenessMeter(percent: -5)));
    expect(find.text('0%'), findsOneWidget);
    expect(tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor, 0);
  });

  testWidgets('fits 320dp at 1.3x in both themes, no blur', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(hostWidget(
        const CompletenessMeter(percent: 85, nextHint: 'Chọn khách phù hợp để lên 95%'),
        width: 320,
        textScale: 1.3,
        brightness: b,
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/widgets/skill_chip_test.dart test/core/widgets/completeness_meter_test.dart`
Expected: FAIL, `SkillChip` and `CompletenessMeter` are undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "skillChipFull": "Đã đủ số lượng",
  "completenessTitle": "Độ khớp hồ sơ",
  "completenessPercent": "{percent}%",
  "@completenessPercent": {
    "placeholders": {
      "percent": {"type": "int"}
    }
  },
```

```dart
// lib/core/widgets/skill_chip.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/widgets/app_chip.dart';

/// Multi-select chip for a catalogue item (S38, S39).
///
/// [disabled] means "this group is full": an unselected chip is dimmed and
/// announces "Đã đủ số lượng", but taps are still reported so the screen can
/// explain the limit (spec S38: "chọn thể loại thứ 7 → báo").
class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final dim = disabled && !selected;
    return MergeSemantics(
      child: Semantics(
        hint: dim ? context.l10n.skillChipFull : null,
        child: Opacity(
          opacity: dim ? 0.5 : 1,
          child: AppChip(
            label: label,
            selected: selected,
            kind: AppChipKind.context,
            onChanged: (_) => onTap(),
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/core/widgets/completeness_meter.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// "Độ khớp hồ sơ 72%" with a gradient bar and the next thing to do
/// (S38, later S30 and S22). Only the photographer sees it.
class CompletenessMeter extends StatelessWidget {
  const CompletenessMeter({super.key, required this.percent, this.nextHint});

  final int percent;
  final String? nextHint;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final p = percent.clamp(0, 100);
    final radius = BorderRadius.circular(AppRadius.full);
    return Semantics(
      container: true,
      label: l.completenessTitle,
      value: l.completenessPercent(p),
      hint: nextHint,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.completenessTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                l.completenessPercent(p),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          SizedBox(
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: radius,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: p / 100,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ctaGradientFor(theme.brightness),
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (nextHint != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              nextHint!,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
```

Export both from `lib/core/core.dart`:

```dart
export 'package:photobooking/core/widgets/completeness_meter.dart';
export 'package:photobooking/core/widgets/skill_chip.dart';
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/widgets/skill_chip_test.dart test/core/widgets/completeness_meter_test.dart && flutter analyze`
Expected: PASS (4 + 4 tests); analyze clean. If `containsSemantics` does not find the hint on the chip, the hint landed on a separate node: keep `MergeSemantics` as the outermost widget of `SkillChip` (it must wrap both the `Semantics(hint)` and the `AppChip`).

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets
git commit -m "feat(core): SkillChip and CompletenessMeter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `LevelSelector`

**Files:**
- Create: `lib/core/widgets/level_selector.dart`, `test/core/widgets/level_selector_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `controlRadius` (`app_theme.dart`); tokens; `hostWidget`.
- Produces: `const LevelSelector({super.key, required String title, required int level, required ValueChanged<int> onChanged, bool expertDisabled = false})` — one row: the genre name in a fixed 74dp column (wraps at 1.3x), then three equal 48dp segments Cơ bản / Thành thạo / Chuyên sâu (`Key('level-option-1')`…`'-3'`). One tab stop; left/right arrows step the level; screen readers get one adjustable node "Chân dung, mức Chuyên sâu" with increase/decrease actions. `expertDisabled` dims "Chuyên sâu" and adds the hint "Đã đủ 3 mức Chuyên sâu"; a tap on it is still reported (the controller refuses it and the screen explains). It draws its own segments instead of `SegmentedTabs` because `SegmentedTabs` has no dimmed segment; the look (field-coloured track, `primarySubtle` + primary border for the selected segment) is the same.
- l10n: `skillsLevelBasic`, `skillsLevelGood`, `skillsLevelExpert`, `skillsLevelSemantics(String name, String level)`, `skillsExpertFull`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/level_selector_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _stateful({int initial = 1, bool expertDisabled = false, List<int>? log}) {
  var level = initial;
  return hostWidget(StatefulBuilder(
    builder: (context, setState) => LevelSelector(
      title: 'Chân dung',
      level: level,
      expertDisabled: expertDisabled,
      onChanged: (v) {
        log?.add(v);
        setState(() => level = v);
      },
    ),
  ));
}

void main() {
  testWidgets('shows the genre and the three levels', (tester) async {
    await tester.pumpWidget(_stateful());
    for (final t in ['Chân dung', 'Cơ bản', 'Thành thạo', 'Chuyên sâu']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('a tap reports that level', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_stateful(log: log));
    await tester.tap(find.text('Chuyên sâu'));
    await tester.pump();
    expect(log, [3]);
  });

  testWidgets('screen readers get "Chân dung, mức Chuyên sâu" and adjust actions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_stateful(initial: 3));
    final node = find.bySemanticsLabel('Chân dung, mức Chuyên sâu');
    expect(node, findsOneWidget);
    expect(
      tester.getSemantics(node),
      containsSemantics(hasDecreaseAction: true, hasIncreaseAction: false),
    );
    await tester.pumpWidget(_stateful(initial: 1));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Chân dung, mức Cơ bản')),
      containsSemantics(hasDecreaseAction: false, hasIncreaseAction: true),
    );
    handle.dispose();
  });

  testWidgets('arrow keys step the level once the row has focus', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_stateful(log: log));
    await tester.tap(find.text('Cơ bản'));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'LevelSelector');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(log, [1, 2, 3, 2]);
  });

  testWidgets('expertDisabled dims Chuyên sâu, explains, still reports the tap', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <int>[];
    await tester.pumpWidget(_stateful(initial: 2, expertDisabled: true, log: log));
    final style = tester.widget<Text>(find.text('Chuyên sâu')).style!;
    expect(style.color, AppColorsDark.foregroundDisabled);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Chân dung, mức Thành thạo')),
      containsSemantics(hint: 'Đã đủ 3 mức Chuyên sâu'),
    );
    await tester.tap(find.text('Chuyên sâu'));
    expect(log, [3]);
    handle.dispose();
  });

  testWidgets('long names wrap; 320dp at 1.3x in both themes; no blur', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(hostWidget(
        LevelSelector(title: 'Bất động sản', level: 2, onChanged: (_) {}),
        width: 320,
        textScale: 1.3,
        brightness: b,
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.getSize(find.byKey(const Key('level-option-1'))).height, greaterThanOrEqualTo(48));
    }
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/level_selector_test.dart`
Expected: FAIL, `LevelSelector` is undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "skillsLevelBasic": "Cơ bản",
  "skillsLevelGood": "Thành thạo",
  "skillsLevelExpert": "Chuyên sâu",
  "skillsLevelSemantics": "{name}, mức {level}",
  "@skillsLevelSemantics": {
    "placeholders": {
      "name": {"type": "String"},
      "level": {"type": "String"}
    }
  },
  "skillsExpertFull": "Đã đủ 3 mức Chuyên sâu",
```

```dart
// lib/core/widgets/level_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Three-step level picker for one genre (S38): Cơ bản · Thành thạo ·
/// Chuyên sâu. One tab stop; arrow keys step the level; screen readers get
/// one adjustable node ("Chân dung, mức Chuyên sâu").
class LevelSelector extends StatefulWidget {
  const LevelSelector({
    super.key,
    required this.title,
    required this.level,
    required this.onChanged,
    this.expertDisabled = false,
  });

  final String title;

  /// 1..3; other values are shown as the nearest level.
  final int level;
  final ValueChanged<int> onChanged;

  /// Three genres are already "Chuyên sâu": dim that option. Taps on it are
  /// still reported so the screen can explain the limit.
  final bool expertDisabled;

  @override
  State<LevelSelector> createState() => _LevelSelectorState();
}

class _LevelSelectorState extends State<LevelSelector> {
  final _focus = FocusNode(debugLabel: 'LevelSelector');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  int get _current => widget.level.clamp(1, 3);

  void _select(int v) {
    _focus.requestFocus();
    widget.onChanged(v);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && _current > 1) {
      widget.onChanged(_current - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && _current < 3) {
      widget.onChanged(_current + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String _label(AppLocalizations l, int v) => switch (v) {
    1 => l.skillsLevelBasic,
    2 => l.skillsLevelGood,
    _ => l.skillsLevelExpert,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final disabled = dark
        ? AppColorsDark.foregroundDisabled
        : AppColors.foregroundDisabled;
    final ring = dark ? AppColorsDark.focusRing : AppColors.focusRing;
    final current = _current;
    final radius = BorderRadius.circular(controlRadius);

    return Semantics(
      container: true,
      label: l.skillsLevelSemantics(widget.title, _label(l, current)),
      hint: widget.expertDisabled && current != 3 ? l.skillsExpertFull : null,
      onIncrease: current < 3 ? () => widget.onChanged(current + 1) : null,
      onDecrease: current > 1 ? () => widget.onChanged(current - 1) : null,
      excludeSemantics: true,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: _focus,
          builder: (context, _) => Row(
            children: [
              SizedBox(
                width: 74,
                child: Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      width: 2,
                      color: _focus.hasFocus ? ring : Colors.transparent,
                    ),
                  ),
                  child: Material(
                    color: scheme.secondary,
                    borderRadius: radius,
                    child: Row(
                      children: [
                        for (final v in const [1, 2, 3])
                          Expanded(
                            child: InkWell(
                              key: Key('level-option-$v'),
                              canRequestFocus: false,
                              borderRadius: radius,
                              onTap: () => _select(v),
                              child: SizedBox(
                                height: 48,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpace.s1),
                                  child: DecoratedBox(
                                    decoration: v == current
                                        ? BoxDecoration(
                                            color: subtle,
                                            borderRadius: BorderRadius.circular(
                                              controlRadius - AppSpace.s1,
                                            ),
                                            border: Border.all(
                                              color: scheme.primary,
                                            ),
                                          )
                                        : const BoxDecoration(),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpace.s1,
                                          ),
                                          child: Text(
                                            _label(l, v),
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: AppText.sm,
                                              fontWeight: FontWeight.w600,
                                              color: v == current
                                                  ? scheme.primary
                                                  : (v == 3 &&
                                                            widget
                                                                .expertDisabled)
                                                  ? disabled
                                                  : secondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```

Export from `lib/core/core.dart`: `export 'package:photobooking/core/widgets/level_selector.dart';`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/level_selector_test.dart && flutter analyze`
Expected: PASS, 6 tests; analyze clean. If the arrow-key test receives no key events, the focus did not land on the selector: check that the segments have `canRequestFocus: false` and `_select` calls `_focus.requestFocus()` before `onChanged`.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets
git commit -m "feat(core): LevelSelector with arrow keys and adjustable semantics

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `EvidencePicker`

**Files:**
- Create: `lib/core/widgets/evidence_picker.dart`, `test/core/widgets/evidence_picker_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `NetworkPhoto` (plan 3b2, `lib/core/widgets/network_photo.dart`); `testPhotoScope`, `PhotoRequest` (`test/support/photo_scope.dart`); `hostWidget`.
- Produces:
  - `class PostThumb { const PostThumb({required String id, required String imageUrl}); }`
  - `const EvidencePicker({super.key, required List<PostThumb> posts, required Set<String> selected, required ValueChanged<Set<String>> onChanged, int max = 3, VoidCallback? onMaxReached, VoidCallback? onEndReached})` — a lazy 3-column `GridView.builder` (`Key('evidence-grid')`); each tile (`Key('evidence-<postId>')`) is a `NetworkPhoto` (decoded at tile width) with a primary border and a check when selected, a 48dp+ target and `Semantics(button, selected, label: "Ảnh n")`. A tap on an unselected tile when `selected.length == max` plays the alert sound and calls `onMaxReached` (the S40 sheet shows the message inline; a `SnackBar` would sit behind the modal). `onEndReached` fires when the grid is scrolled within 300 px of its end. `onChanged` receives a new insertion-ordered set. No `BackdropFilter`.
- l10n: `skillEvidencePhoto(int index)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/evidence_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

List<PostThumb> _thumbs(int n) => [
  for (var i = 0; i < n; i++) PostThumb(id: 'p$i', imageUrl: 'https://img.test/p$i.jpg'),
];

Widget _host({
  int count = 6,
  Set<String> initial = const {},
  List<Set<String>>? changes,
  VoidCallback? onMax,
  VoidCallback? onEnd,
  List<PhotoRequest>? photos,
  double height = 400,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) {
  var selected = initial;
  return hostWidget(
    testPhotoScope(
      log: photos,
      child: SizedBox(
        height: height,
        child: StatefulBuilder(
          builder: (context, setState) => EvidencePicker(
            posts: _thumbs(count),
            selected: selected,
            onChanged: (v) {
              changes?.add(v);
              setState(() => selected = v);
            },
            onMaxReached: onMax,
            onEndReached: onEnd,
          ),
        ),
      ),
    ),
    width: width,
    textScale: textScale,
    brightness: brightness,
  );
}

void main() {
  testWidgets('tapping selects and unselects, in tap order', (tester) async {
    final changes = <Set<String>>[];
    await tester.pumpWidget(_host(changes: changes));
    await tester.tap(find.byKey(const Key('evidence-p2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('evidence-p0')));
    await tester.pump();
    expect(changes.last.toList(), ['p2', 'p0']);
    expect(
      find.descendant(of: find.byKey(const Key('evidence-p2')), matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('evidence-p2')));
    await tester.pump();
    expect(changes.last.toList(), ['p0']);
  });

  testWidgets('a 4th pick is refused and reported', (tester) async {
    final changes = <Set<String>>[];
    var maxed = 0;
    await tester.pumpWidget(_host(initial: {'p0', 'p1', 'p2'}, changes: changes, onMax: () => maxed++));
    await tester.tap(find.byKey(const Key('evidence-p3')));
    await tester.pump();
    expect(changes, isEmpty);
    expect(maxed, 1);
  });

  testWidgets('tiles are buttons with a selected state and a label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(initial: {'p1'}));
    expect(
      tester.getSemantics(find.byKey(const Key('evidence-p1'))),
      containsSemantics(label: 'Ảnh 2', isButton: true, isSelected: true),
    );
    expect(tester.getSize(find.byKey(const Key('evidence-p0'))).width, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('the grid is lazy and photos are decoded at tile size', (tester) async {
    final photos = <PhotoRequest>[];
    await tester.pumpWidget(_host(count: 60, photos: photos));
    final grid = tester.widget<GridView>(find.byKey(const Key('evidence-grid')));
    expect(grid.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(find.byType(NetworkPhoto).evaluate().length, lessThan(60));
    expect(photos, isNotEmpty);
    for (final p in photos) {
      expect(p.cacheWidth, isNotNull, reason: p.url);
      expect(p.cacheWidth!, lessThanOrEqualTo(400), reason: 'tile ≈ 125dp at 3x');
    }
  });

  testWidgets('scrolling near the end asks for more', (tester) async {
    var ends = 0;
    await tester.pumpWidget(_host(count: 60, onEnd: () => ends++));
    await tester.drag(find.byKey(const Key('evidence-grid')), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(ends, greaterThan(0));
  });

  testWidgets('320dp at 1.3x in both themes; no blur in tiles', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(_host(initial: {'p0'}, width: 320, textScale: 1.3, brightness: b));
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/evidence_picker_test.dart`
Expected: FAIL, `EvidencePicker` and `PostThumb` are undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "skillEvidencePhoto": "Ảnh {index}",
  "@skillEvidencePhoto": {
    "placeholders": {
      "index": {"type": "int"}
    }
  },
```

```dart
// lib/core/widgets/evidence_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// A post offered as evidence: its id and the cover image.
class PostThumb {
  const PostThumb({required this.id, required this.imageUrl});
  final String id;
  final String imageUrl;
}

/// 3-column grid to pick up to [max] of the photographer's own posts (S40).
/// Lazy: only visible tiles are built, and each photo is decoded at tile
/// width by [NetworkPhoto]. No blur inside tiles.
class EvidencePicker extends StatelessWidget {
  const EvidencePicker({
    super.key,
    required this.posts,
    required this.selected,
    required this.onChanged,
    this.max = 3,
    this.onMaxReached,
    this.onEndReached,
  });

  final List<PostThumb> posts;

  /// Insertion-ordered (the order of picking).
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int max;

  /// A pick beyond [max] was refused.
  final VoidCallback? onMaxReached;

  /// The grid was scrolled near its end; load the next page.
  final VoidCallback? onEndReached;

  void _toggle(String id) {
    if (selected.contains(id)) {
      onChanged({
        for (final x in selected)
          if (x != id) x,
      });
      return;
    }
    if (selected.length >= max) {
      SystemSound.play(SystemSoundType.alert);
      onMaxReached?.call();
      return;
    }
    onChanged({...selected, id});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.md);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onEndReached != null && n.metrics.extentAfter < 300) {
          onEndReached!();
        }
        return false;
      },
      child: GridView.builder(
        key: const Key('evidence-grid'),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.s2,
          crossAxisSpacing: AppSpace.s2,
        ),
        itemCount: posts.length,
        itemBuilder: (context, i) {
          final post = posts[i];
          final on = selected.contains(post.id);
          return Semantics(
            key: Key('evidence-${post.id}'),
            button: true,
            selected: on,
            label: l.skillEvidencePhoto(i + 1),
            onTap: () => _toggle(post.id),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: radius,
              onTap: () => _toggle(post.id),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkPhoto(url: post.imageUrl),
                    if (on)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: scheme.primary, width: 3),
                        ),
                      ),
                    if (on)
                      Positioned(
                        top: AppSpace.s1,
                        right: AppSpace.s1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

Export from `lib/core/core.dart`: `export 'package:photobooking/core/widgets/evidence_picker.dart';`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/evidence_picker_test.dart && flutter analyze`
Expected: PASS, 6 tests; analyze clean. If `getSemantics(find.byKey('evidence-p1'))` resolves to the grid instead of the tile, the key is on `Semantics` without its own node; it has `button: true` and `excludeSemantics: true`, which already make it a node, so check that the key sits on that `Semantics` widget and not on the `InkWell`.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets
git commit -m "feat(core): EvidencePicker, a lazy 3-column grid of own posts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 10: Device draft, analytics hook and `SkillsController`

**Files:**
- Create: `lib/features/skills/skills_analytics.dart`, `lib/features/skills/skills_draft_store.dart`, `lib/features/skills/skills_controller.dart`, `test/support/skills_world.dart`, `test/features/skills/skills_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 1–5; `authRepositoryProvider`, `FakeAuthRepository`; `sharedPreferencesProvider` (`lib/features/settings/theme_mode_controller.dart`); `postRepositoryProvider`, `FakePostRepository` (`failWith`), `PostSummary`, `fixturePost` (plan 3b1).
- Produces:
  - `typedef SkillsEventLogger = void Function(String name, Map<String, Object> params);`, `final skillsAnalyticsProvider = Provider<SkillsEventLogger>(...)` (no-op default).
  - `class SkillsDraftStore { SkillsDraftStore(SharedPreferences prefs); static String keyFor(String uid); PhotographerSkills? read(String uid); Future<void> write(String uid, PhotographerSkills s); Future<void> clear(String uid); }`, `skillsDraftStoreProvider`. The draft is the `skillsToMap` JSON under `skillsDraft.<uid>`; it can hold invalid skills (that is the point of a draft), Firestore never does.
  - `enum SkillsSubmitResult { saved, invalid, failed }`.
  - `class SkillsEditorState` — `saved` (on the server), `start` (what the screen opened with), `draft`, `restoredDraft`, `showIssues`, `issues`, `saving`; getters `dirty` (draft ≠ start: leaving asks), `unsaved` (draft ≠ saved: "Lưu thay đổi" enabled), `canSubmit` (≥ 1 genre and not saving), `completeness`, `hasIssue(SkillIssueCode code, {String? itemId})`.
  - `class SkillsController extends AsyncNotifier<SkillsEditorState>` with `SkillEdit? toggleSpecialty(String id)`, `SkillEdit? setLevel(String id, int level)`, `SkillEdit? toggleTag(SkillGroup group, String id)`, `SkillEdit? setEvidence(String specialtyId, List<String> postIds)`, `void setYears(int? years)`, `Future<SkillsSubmitResult> submit()`, `Future<void> discardDraft()`; `skillsControllerProvider` (`AsyncNotifierProvider.autoDispose`, no retry).
  - Loading: one `SkillsRepository.load`; the device draft wins over the saved skills; a photographer with nothing saved starts from `PhotographerSkills.initial`; evidence ids whose post no longer exists are dropped (one `PostRepository.byId` per evidence id, at most 18; skipped when offline).
  - Every accepted edit writes the device draft, or clears it when the draft is back to the baseline (the saved skills, or `PhotographerSkills.initial` when nothing is saved). `submit` validates; with issues it shows them and saves nothing; otherwise it writes once (nothing when unchanged), clears the device draft, logs `skills_save{specialties, expert}` and refreshes `photographerSkillsProvider(uid)`. `setEvidence` logs `skill_evidence_set{skillId, count}`.
  - Test harness `SkillsWorld` in `test/support/skills_world.dart`: `static Future<SkillsWorld> create({PhotographerSkills? saved, List<PostSummary> Function(String uid)? posts, Map<String, Object> prefs = const {}})`, fields `auth`, `uid`, `skills`, `posts`, `prefs`, `events`, getter `overrides`, `ProviderContainer container()`.

- [ ] **Step 1: Write the harness and the failing test**

```dart
// test/support/skills_world.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/skills/skills_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fakes for every skills test: a signed-in photographer, their saved
/// skills, their posts, device storage and an analytics log.
class SkillsWorld {
  SkillsWorld._(this.auth, this.uid, this.skills, this.posts, this.prefs);

  static Future<SkillsWorld> create({
    PhotographerSkills? saved,
    List<PostSummary> Function(String uid)? posts,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final store = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final user = await auth.registerWithEmail('p@b.vn', 'password1', 'Minh Thư');
    final skills = FakeSkillsRepository();
    if (saved != null) skills.seed(user.uid, saved);
    return SkillsWorld._(
      auth,
      user.uid,
      skills,
      FakePostRepository(posts?.call(user.uid) ?? const []),
      store,
    );
  }

  final FakeAuthRepository auth;
  final String uid;
  final FakeSkillsRepository skills;
  final FakePostRepository posts;
  final SharedPreferences prefs;
  final events = <(String, Map<String, Object>)>[];

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    skillsRepositoryProvider.overrideWithValue(skills),
    postRepositoryProvider.overrideWithValue(posts),
    sharedPreferencesProvider.overrideWithValue(prefs),
    skillsAnalyticsProvider.overrideWithValue(
      (name, params) => events.add((name, params)),
    ),
  ];

  ProviderContainer container() =>
      ProviderContainer(overrides: overrides, retry: (_, _) => null);

  /// Parameters of the only event called [name].
  Map<String, Object> event(String name) =>
      events.where((e) => e.$1 == name).single.$2;
}
```

```dart
// test/features/skills/skills_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_rules.dart';
import 'package:photobooking/features/skills/skills_controller.dart';
import 'package:photobooking/features/skills/skills_draft_store.dart';

import '../../support/content_fixtures.dart';
import '../../support/skills_world.dart';

Future<(SkillsWorld, ProviderContainer)> _open({
  PhotographerSkills? saved,
  List<PostSummary> Function(String uid)? posts,
  Future<void> Function(SkillsWorld w)? before,
}) async {
  final w = await SkillsWorld.create(saved: saved, posts: posts);
  await before?.call(w);
  final c = w.container();
  addTearDown(c.dispose);
  c.listen(skillsControllerProvider, (_, _) {});
  await c.read(skillsControllerProvider.future);
  return (w, c);
}

SkillsController _ctrl(ProviderContainer c) => c.read(skillsControllerProvider.notifier);
SkillsEditorState _st(ProviderContainer c) => c.read(skillsControllerProvider).requireValue;

const _wedding = PhotographerSkills(specialties: [SpecialtySkill(id: 'wedding')], languages: ['vi']);

void main() {
  test('nothing saved yet: Vietnamese ticked, nothing to leave behind, Tiếp tục off', () async {
    final (w, c) = await _open();
    expect(_st(c).draft, PhotographerSkills.initial);
    expect(_st(c).saved, PhotographerSkills.empty);
    expect(_st(c).dirty, isFalse);
    expect(_st(c).canSubmit, isFalse);
    expect(_st(c).completeness.percent, 10);
    expect(w.skills.loadCalls, 1);
  });

  test('an edit changes the draft and keeps a copy on the device', () async {
    final (w, c) = await _open();
    expect(_ctrl(c).toggleSpecialty('portrait')!.accepted, isTrue);
    expect(_st(c).draft.specialtyIds, ['portrait']);
    expect(_st(c).dirty, isTrue);
    expect(_st(c).canSubmit, isTrue);
    await pumpEventQueue();
    expect(SkillsDraftStore(w.prefs).read(w.uid), _st(c).draft);
  });

  test('the 7th genre and the 4th Chuyên sâu are refused; the draft stays', () async {
    final (_, c) = await _open();
    for (final id in ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event']) {
      _ctrl(c).toggleSpecialty(id);
    }
    final before = _st(c).draft;
    final e = _ctrl(c).toggleSpecialty('product')!;
    expect((e.rejection, e.group), (SkillEditRejection.tooManyItems, SkillGroup.specialty));
    expect(_st(c).draft, before);
    for (final id in ['portrait', 'wedding', 'couple']) {
      _ctrl(c).setLevel(id, SkillLevels.expert);
    }
    expect(_ctrl(c).setLevel('family', SkillLevels.expert)!.rejection, SkillEditRejection.tooManyExpert);
    expect(_st(c).draft.specialty('family')!.level, SkillLevels.proficient);
  });

  test('submit with problems saves nothing; issues refresh as they are fixed', () async {
    final (w, c) = await _open();
    _ctrl(c).toggleSpecialty('portrait');
    _ctrl(c).setLevel('portrait', SkillLevels.expert);
    _ctrl(c).toggleTag(SkillGroup.language, 'vi');
    expect(await _ctrl(c).submit(), SkillsSubmitResult.invalid);
    expect(w.skills.saveCalls, 0);
    expect(_st(c).hasIssue(SkillIssueCode.expertNeedsEvidence, itemId: 'portrait'), isTrue);
    expect(_st(c).hasIssue(SkillIssueCode.noLanguage), isTrue);
    _ctrl(c).toggleTag(SkillGroup.language, 'en');
    expect(_st(c).hasIssue(SkillIssueCode.noLanguage), isFalse);
    expect(_st(c).hasIssue(SkillIssueCode.expertNeedsEvidence, itemId: 'portrait'), isTrue);
  });

  test('a valid submit writes ids once, clears the device draft and logs', () async {
    final (w, c) = await _open();
    _ctrl(c).toggleSpecialty('portrait');
    _ctrl(c).setLevel('portrait', SkillLevels.expert);
    _ctrl(c).setEvidence('portrait', ['p1']);
    _ctrl(c).toggleTag(SkillGroup.style, 'film');
    _ctrl(c).toggleTag(SkillGroup.audience, 'couple');
    _ctrl(c).setYears(6);
    expect(await _ctrl(c).submit(), SkillsSubmitResult.saved);
    expect(w.skills.saveCalls, 1);
    expect(
      w.skills.stored(w.uid),
      const PhotographerSkills(
        specialties: [SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1'])],
        styles: ['film'],
        languages: ['vi'],
        audiences: ['couple'],
        yearsExperience: 6,
      ),
    );
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNull);
    expect(_st(c).dirty, isFalse);
    expect(_st(c).unsaved, isFalse);
    expect(w.event('skills_save'), {'specialties': 1, 'expert': 1});
    expect(w.event('skill_evidence_set'), {'skillId': 'portrait', 'count': 1});
  });

  test('an unchanged submit writes nothing', () async {
    final (w, c) = await _open(saved: _wedding);
    expect(await _ctrl(c).submit(), SkillsSubmitResult.saved);
    expect(w.skills.saveCalls, 0);
  });

  test('a failed save keeps the draft and the device copy', () async {
    final (w, c) = await _open();
    _ctrl(c).toggleSpecialty('portrait');
    w.skills.failSaveWith = StateError('offline');
    expect(await _ctrl(c).submit(), SkillsSubmitResult.failed);
    expect(_st(c).saving, isFalse);
    expect(_st(c).draft.specialtyIds, ['portrait']);
    await pumpEventQueue();
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNotNull);
  });

  test('a device draft is reopened, and can be thrown away', () async {
    const draft = PhotographerSkills(specialties: [SpecialtySkill(id: 'food')], languages: ['vi']);
    final (w, c) = await _open(
      saved: _wedding,
      before: (w) => SkillsDraftStore(w.prefs).write(w.uid, draft),
    );
    expect(_st(c).draft, draft);
    expect(_st(c).restoredDraft, isTrue);
    expect(_st(c).saved, _wedding);
    expect(_st(c).dirty, isFalse, reason: 'nothing changed since it was reopened');
    expect(_st(c).unsaved, isTrue);
    await _ctrl(c).discardDraft();
    expect(_st(c).draft, _wedding);
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNull);
  });

  test('evidence of deleted posts is dropped when the screen opens', () async {
    const saved = PhotographerSkills(
      specialties: [SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['kept', 'gone'])],
      languages: ['vi'],
    );
    final (_, c) = await _open(
      saved: saved,
      posts: (uid) => [fixturePost('kept', photographerId: uid)],
    );
    expect(_st(c).draft.specialty('portrait')!.evidencePostIds, ['kept']);
    expect(_st(c).unsaved, isTrue, reason: '"Lưu thay đổi" stores the cleaned list');
  });

  test('offline, the evidence check is skipped and the list kept', () async {
    const saved = PhotographerSkills(
      specialties: [SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['a'])],
      languages: ['vi'],
    );
    final (_, c) = await _open(saved: saved, before: (w) async => w.posts.failWith = StateError('offline'));
    expect(_st(c).draft, saved);
  });

  test('a failed load is an error state, without a retry timer', () async {
    final w = await SkillsWorld.create();
    w.skills.failLoadWith = StateError('offline');
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(skillsControllerProvider, (_, _) {});
    await expectLater(c.read(skillsControllerProvider.future), throwsStateError);
    expect(c.read(skillsControllerProvider).hasError, isTrue);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/skills/skills_controller_test.dart`
Expected: FAIL, `skills_controller.dart` and the other new files do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/skills/skills_analytics.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No analytics layer exists yet; the skills screens report through this
/// hook and a later plan points it at the real sink. Parameters never hold
/// post ids or personal data.
typedef SkillsEventLogger = void Function(String name, Map<String, Object> params);

final skillsAnalyticsProvider = Provider<SkillsEventLogger>(
  (ref) => (_, _) {},
);
```

```dart
// lib/features/skills/skills_draft_store.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// The unsaved S38 draft, kept on this device so leaving the screen (or the
/// app) loses nothing. It may be incomplete; Firestore only ever gets valid
/// skills.
class SkillsDraftStore {
  SkillsDraftStore(this._prefs);
  final SharedPreferences _prefs;

  static String keyFor(String uid) => 'skillsDraft.$uid';

  PhotographerSkills? read(String uid) {
    final raw = _prefs.getString(keyFor(uid));
    if (raw == null) return null;
    try {
      return skillsFromMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String uid, PhotographerSkills skills) async {
    await _prefs.setString(keyFor(uid), jsonEncode(skillsToMap(skills)));
  }

  Future<void> clear(String uid) async {
    await _prefs.remove(keyFor(uid));
  }
}

final skillsDraftStoreProvider = Provider<SkillsDraftStore>(
  (ref) => SkillsDraftStore(ref.watch(sharedPreferencesProvider)),
);
```

```dart
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
      issues.any((i) => i.code == code && (itemId == null || i.itemId == itemId));

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

  Future<PhotographerSkills> _withoutDeletedEvidence(PhotographerSkills s) async {
    final ids = s.evidencePostIds;
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
  Future<void> discardDraft() async {
    await _drafts.clear(_uid);
    final current = state.value;
    if (current == null || !ref.mounted) return;
    final base = _baseline(current.saved);
    state = AsyncData(
      current.copyWith(start: base, draft: base, showIssues: false, issues: const []),
    );
  }
}

final skillsControllerProvider =
    AsyncNotifierProvider.autoDispose<SkillsController, SkillsEditorState>(
      SkillsController.new,
      retry: (_, _) => null,
    );
```


- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/skills/skills_controller_test.dart && flutter analyze`
Expected: PASS, 11 tests; analyze clean. If `retry:` is not a named parameter of `AsyncNotifierProvider.autoDispose` in the pinned Riverpod 3 version, drop it there and rely on the app-wide `ProviderScope(retry: (_, _) => null)` set in tests, and note in the PR that the production `ProviderScope` should set the same (an error state must not leave a retry timer running).

- [ ] **Step 5: Commit**

```bash
git add lib/features/skills test/support/skills_world.dart test/features/skills
git commit -m "feat(skills): SkillsController with device draft and one-shot save

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: S40 evidence sheet over the photographer's own posts

**Files:**
- Create: `lib/features/skills/own_posts_controller.dart`, `lib/features/skills/evidence_sheet.dart`, `test/features/skills/own_posts_controller_test.dart`, `test/features/skills/evidence_sheet_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `EvidencePicker`, `PostThumb` (Task 9); `showAppSheet`, `ErrorState`, `EmptyState`, `AppSkeleton`, `AppButton`, `ScreenCode`, `ScreenCodes.skillEvidence`, `controlHeight`; `PostRepository.byPhotographer`, `PostPage`, `PostSummary` (`authorId`, `images`, `cover`), `PostKind`, `fixturePost`; `SkillsWorld` (Task 10); `testPhotoScope`.
- Produces:
  - `class OwnPostsState { const OwnPostsState({List<PostThumb> posts = const [], String? nextCursor, bool loadingMore = false}); bool get hasMore; }`, `class OwnPostsController extends AsyncNotifier<OwnPostsState>` (`static const pageSize = 30`, `Future<void> loadMore()`), `ownPostsProvider` (`AsyncNotifierProvider.autoDispose`, no retry). Only posts whose `authorId` is the signed-in photographer (not a customer's `real_shoot` shared on their page) and that have an image.
  - `Future<List<String>?> showEvidenceSheet(BuildContext context, {required String specialtyName, required List<String> initial, required bool requiresOne, required VoidCallback onCreatePost})` — `null` when dismissed; the chosen ids in pick order after "Xong".
  - `class EvidenceSheet extends ConsumerStatefulWidget` (same parameters) with keys `evidence-count`, `evidence-max`, `evidence-done`.
  - l10n: `skillsCount(int n, int max)`, `skillEvidenceTitle(String name)`, `skillEvidenceBody`, `skillEvidenceDone`, `skillEvidenceEmpty`, `skillEvidenceEmptyBody`, `skillEvidenceEmptyAction`, `skillEvidenceMax`, `skillEvidenceNeedOne`, `skillEvidenceLoadError`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/skills/own_posts_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/skills/own_posts_controller.dart';

import '../../support/content_fixtures.dart';
import '../../support/skills_world.dart';

void main() {
  test('own posts only, 30 per page, newest first', () async {
    final w = await SkillsWorld.create(posts: (uid) => [
      for (var i = 0; i < 40; i++) fixturePost('m$i', photographerId: uid, age: Duration(minutes: i + 1)),
      fixturePost('shared', photographerId: uid, authorId: 'customer1', kind: PostKind.realShoot),
      fixturePost('other', photographerId: 'someone-else'),
    ]);
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    final first = await c.read(ownPostsProvider.future);
    expect(first.posts, hasLength(30));
    expect(first.posts.first.id, 'm0');
    expect(first.posts.first.imageUrl, 'https://img.test/m0-0.jpg');
    expect(first.hasMore, isTrue);
    await c.read(ownPostsProvider.notifier).loadMore();
    final all = c.read(ownPostsProvider).requireValue;
    expect(all.posts.map((p) => p.id), [for (var i = 0; i < 40; i++) 'm$i']);
    expect(all.hasMore, isFalse);
    await c.read(ownPostsProvider.notifier).loadMore();
    expect(c.read(ownPostsProvider).requireValue.posts, hasLength(40), reason: 'no page after the last');
  });

  test('a failed next page keeps what is shown and is not retried by scrolling', () async {
    final w = await SkillsWorld.create(posts: (uid) => [
      for (var i = 0; i < 35; i++) fixturePost('m$i', photographerId: uid, age: Duration(minutes: i + 1)),
    ]);
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    await c.read(ownPostsProvider.future);
    w.posts.failWith = StateError('offline');
    await c.read(ownPostsProvider.notifier).loadMore();
    await c.read(ownPostsProvider.notifier).loadMore();
    final s = c.read(ownPostsProvider).requireValue;
    expect(s.posts, hasLength(30));
    expect(s.loadingMore, isFalse);
  });
}
```

```dart
// test/features/skills/evidence_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/skills/evidence_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/content_fixtures.dart';
import '../../support/photo_scope.dart';
import '../../support/skills_world.dart';

class _Probe {
  List<String>? result;
  bool closed = false;
  int createPost = 0;
}

Widget _app(
  SkillsWorld w,
  _Probe probe, {
  bool requiresOne = false,
  List<String> initial = const [],
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) => ProviderScope(
  retry: (_, _) => null,
  overrides: w.overrides,
  child: MaterialApp(
    theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => testPhotoScope(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            probe.result = await showEvidenceSheet(
              context,
              specialtyName: 'Chân dung',
              initial: initial,
              requiresOne: requiresOne,
              onCreatePost: () => probe.createPost++,
            );
            probe.closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<SkillsWorld> _world({int own = 6}) => SkillsWorld.create(posts: (uid) => [
  for (var i = 0; i < own; i++) fixturePost('m$i', photographerId: uid, age: Duration(minutes: i + 1)),
  fixturePost('shared', photographerId: uid, authorId: 'customer1', kind: PostKind.realShoot),
]);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('own posts only; picking updates "n / 3"; Xong returns them in order', (tester) async {
    final w = await _world();
    final probe = _Probe();
    await tester.pumpWidget(_app(w, probe));
    await _open(tester);
    expect(find.text('Minh chứng · Chân dung'), findsOneWidget);
    expect(find.text('Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.'), findsOneWidget);
    expect(find.byKey(const Key('evidence-shared')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('evidence-count'))).data, '0 / 3');
    await tester.tap(find.byKey(const Key('evidence-m3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('evidence-m1')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('evidence-count'))).data, '2 / 3');
    await tester.tap(find.byKey(const Key('evidence-done')));
    await tester.pumpAndSettle();
    expect(probe.result, ['m3', 'm1']);
  });

  testWidgets('a 4th pick shows the limit message inside the sheet', (tester) async {
    final w = await _world();
    await tester.pumpWidget(_app(w, _Probe(), initial: ['m0', 'm1', 'm2']));
    await _open(tester);
    expect(tester.widget<Text>(find.byKey(const Key('evidence-count'))).data, '3 / 3');
    await tester.tap(find.byKey(const Key('evidence-m4')));
    await tester.pump();
    expect(find.text('Tối đa 3 ảnh. Bỏ chọn một ảnh để chọn ảnh khác.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('evidence-m0')));
    await tester.pump();
    expect(find.byKey(const Key('evidence-max')), findsNothing);
  });

  testWidgets('Chuyên sâu: Xong stays off until one photo is picked', (tester) async {
    final w = await _world();
    await tester.pumpWidget(_app(w, _Probe(), requiresOne: true));
    await _open(tester);
    FilledButton done() => tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('evidence-done')), matching: find.byType(FilledButton)),
    );
    expect(done().onPressed, isNull);
    expect(find.text('Mức Chuyên sâu cần ít nhất 1 ảnh'), findsOneWidget);
    await tester.tap(find.byKey(const Key('evidence-m0')));
    await tester.pump();
    expect(done().onPressed, isNotNull);
  });

  testWidgets('no posts: "Đăng bài trước" and a way to S21, no Xong', (tester) async {
    final w = await SkillsWorld.create();
    final probe = _Probe();
    await tester.pumpWidget(_app(w, probe));
    await _open(tester);
    expect(find.text('Đăng bài trước'), findsOneWidget);
    expect(find.byKey(const Key('evidence-done')), findsNothing);
    await tester.tap(find.text('Đăng bài'));
    await tester.pumpAndSettle();
    expect(probe.createPost, 1);
    expect(probe.closed, isTrue);
    expect(probe.result, isNull);
  });

  testWidgets('a load error offers a retry', (tester) async {
    final w = await _world();
    w.posts.failWith = StateError('offline');
    await tester.pumpWidget(_app(w, _Probe()));
    await _open(tester);
    expect(find.text('Không tải được bài đăng của bạn.'), findsOneWidget);
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence-m0')), findsOneWidget);
  });

  testWidgets('dismissing returns null and changes nothing', (tester) async {
    final w = await _world();
    final probe = _Probe();
    await tester.pumpWidget(_app(w, probe, initial: ['m0']));
    await _open(tester);
    await tester.tap(find.byKey(const Key('evidence-m1')));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(probe.closed, isTrue);
    expect(probe.result, isNull);
  });

  testWidgets('320dp at 1.3x in both themes; Xong is 52dp tall', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final b in Brightness.values) {
      final w = await _world();
      await tester.pumpWidget(_app(w, _Probe(), brightness: b, textScale: 1.3));
      await _open(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('evidence-done'))).height, controlHeight);
      Navigator.of(tester.element(find.byType(EvidenceSheet))).pop();
      await tester.pumpAndSettle();
    }
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/skills/own_posts_controller_test.dart test/features/skills/evidence_sheet_test.dart`
Expected: FAIL, `own_posts_controller.dart` and `evidence_sheet.dart` do not exist.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "skillsCount": "{n} / {max}",
  "@skillsCount": {
    "placeholders": {
      "n": {"type": "int"},
      "max": {"type": "int"}
    }
  },
  "skillEvidenceTitle": "Minh chứng · {name}",
  "@skillEvidenceTitle": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "skillEvidenceBody": "Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.",
  "skillEvidenceDone": "Xong",
  "skillEvidenceEmpty": "Đăng bài trước",
  "skillEvidenceEmptyBody": "Bạn chưa có bài đăng nào. Đăng ảnh vào portfolio rồi quay lại chọn ảnh minh chứng.",
  "skillEvidenceEmptyAction": "Đăng bài",
  "skillEvidenceMax": "Tối đa 3 ảnh. Bỏ chọn một ảnh để chọn ảnh khác.",
  "skillEvidenceNeedOne": "Mức Chuyên sâu cần ít nhất 1 ảnh",
  "skillEvidenceLoadError": "Không tải được bài đăng của bạn.",
```

```dart
// lib/features/skills/own_posts_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';

class OwnPostsState {
  const OwnPostsState({
    this.posts = const [],
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<PostThumb> posts;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;
}

/// The signed-in photographer's own posts for S40, a page at a time
/// (one-shot reads; nothing stays open when the sheet closes).
class OwnPostsController extends AsyncNotifier<OwnPostsState> {
  static const pageSize = 30;

  late String _uid;
  String? _failedCursor;

  @override
  Future<OwnPostsState> build() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) throw StateError('signed_out');
    _uid = uid;
    _failedCursor = null;
    final page = await ref
        .read(postRepositoryProvider)
        .byPhotographer(uid, limit: pageSize);
    return OwnPostsState(posts: _thumbs(page), nextCursor: page.nextCursor);
  }

  /// Only what the photographer posted themselves, with a photo.
  List<PostThumb> _thumbs(PostPage page) => [
    for (final p in page.posts)
      if (p.authorId == _uid && p.images.isNotEmpty)
        PostThumb(id: p.id, imageUrl: p.cover.url),
  ];

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null ||
        current.loadingMore ||
        cursor == null ||
        cursor == _failedCursor) {
      return;
    }
    final repo = ref.read(postRepositoryProvider);
    state = AsyncData(
      OwnPostsState(posts: current.posts, nextCursor: cursor, loadingMore: true),
    );
    try {
      final page = await repo.byPhotographer(
        _uid,
        cursor: cursor,
        limit: pageSize,
      );
      if (!ref.mounted) return;
      state = AsyncData(
        OwnPostsState(
          posts: [...current.posts, ..._thumbs(page)],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      // Shown posts stay; scrolling does not hammer a failing network.
      _failedCursor = cursor;
      if (ref.mounted) state = AsyncData(current);
    }
  }
}

final ownPostsProvider =
    AsyncNotifierProvider.autoDispose<OwnPostsController, OwnPostsState>(
      OwnPostsController.new,
      retry: (_, _) => null,
    );
```

```dart
// lib/features/skills/evidence_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/skills/own_posts_controller.dart';

/// S40: pick 1–3 of your own posts as evidence for one genre. Returns the
/// ids in pick order after "Xong", or null when dismissed (nothing changes).
Future<List<String>?> showEvidenceSheet(
  BuildContext context, {
  required String specialtyName,
  required List<String> initial,
  required bool requiresOne,
  required VoidCallback onCreatePost,
}) => showAppSheet<List<String>>(
  context,
  builder: (_) => EvidenceSheet(
    specialtyName: specialtyName,
    initial: initial,
    requiresOne: requiresOne,
    onCreatePost: onCreatePost,
  ),
);

class EvidenceSheet extends ConsumerStatefulWidget {
  const EvidenceSheet({
    super.key,
    required this.specialtyName,
    required this.initial,
    required this.requiresOne,
    required this.onCreatePost,
  });

  final String specialtyName;
  final List<String> initial;

  /// The genre is "Chuyên sâu": "Xong" needs at least one photo.
  final bool requiresOne;

  /// Called after the sheet closes from the empty state ("Đăng bài").
  final VoidCallback onCreatePost;

  @override
  ConsumerState<EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<EvidenceSheet> {
  late Set<String> _selected = {...widget.initial};
  bool _maxed = false;

  void _createPost() {
    Navigator.of(context).pop();
    widget.onCreatePost();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final posts = ref.watch(ownPostsProvider);
    final hasPosts = posts.value?.posts.isNotEmpty ?? false;
    final blocked = widget.requiresOne && _selected.isEmpty;
    return ScreenCode(
      ScreenCodes.skillEvidence,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.skillEvidenceTitle(widget.specialtyName),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Text(
                  l.skillsCount(_selected.length, 3),
                  key: const Key('evidence-count'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Text(l.skillEvidenceBody, style: theme.textTheme.bodySmall),
            if (_maxed) ...[
              const SizedBox(height: AppSpace.s2),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.skillEvidenceMax,
                  key: const Key('evidence-max'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s3),
            Flexible(
              child: posts.when(
                loading: () => const _GridSkeleton(),
                error: (_, _) => ErrorState(
                  message: l.skillEvidenceLoadError,
                  onRetry: () => ref.invalidate(ownPostsProvider),
                ),
                data: (s) => s.posts.isEmpty
                    ? EmptyState(
                        title: l.skillEvidenceEmpty,
                        body: l.skillEvidenceEmptyBody,
                        actionLabel: l.skillEvidenceEmptyAction,
                        onAction: _createPost,
                      )
                    : EvidencePicker(
                        posts: s.posts,
                        selected: _selected,
                        onChanged: (v) => setState(() {
                          _selected = v;
                          _maxed = false;
                        }),
                        onMaxReached: () => setState(() => _maxed = true),
                        onEndReached: s.hasMore
                            ? () => ref.read(ownPostsProvider.notifier).loadMore()
                            : null,
                      ),
              ),
            ),
            if (hasPosts) ...[
              const SizedBox(height: AppSpace.s3),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Text(
                    l.skillEvidenceNeedOne,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                height: controlHeight,
                child: AppButton.primary(
                  l.skillEvidenceDone,
                  key: const Key('evidence-done'),
                  onPressed: blocked
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    mainAxisSpacing: AppSpace.s2,
    crossAxisSpacing: AppSpace.s2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (var i = 0; i < 6; i++) const AppSkeleton.box(height: 100),
    ],
  );
}
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/skills/own_posts_controller_test.dart test/features/skills/evidence_sheet_test.dart && flutter analyze`
Expected: PASS (2 + 7 tests); analyze clean. If the dismiss test's `tapAt(10, 10)` lands on the sheet (very tall at 600dp test height), tap above the sheet with `tester.tapAt(Offset(10, tester.getTopLeft(find.byType(EvidenceSheet)).dy - 20))` instead. If `PostThumb` is not visible from `own_posts_controller.dart`, check that `core.dart` exports `evidence_picker.dart` (Task 9).

- [ ] **Step 5: Commit**

```bash
git add lib/features/skills lib/l10n test/features/skills
git commit -m "feat(skills): S40 evidence sheet over own posts, paged

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 12: S38 + S39 screen and routes

**Files:**
- Create: `lib/features/skills/skills_screen.dart`, `test/support/skills_app.dart`, `test/features/skills/skills_screen_test.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: everything above; `StepProgress`, `GlassCard`, `AuroraBackground`, `AppButton`, `ErrorState`, `AppSkeleton`, `showAppSheet`, `ScreenCode`, `ScreenCodes.skillsPart1` / `.skillsPart2`, `controlHeight`, `controlRadius`; `AppTab.profile.path`, `AppTab.action.path` (`lib/app/tabs.dart`); `testPhotoScope`; `routerProvider`, `FakeUserRepository`, `userRepositoryProvider`.
- Produces:
  - `enum SkillsMode { setup, edit }`, `const SkillsScreen({super.key, required SkillsMode mode, String? openEvidenceFor})`.
  - Routes in `lib/app/router.dart`: `/setup/3`, `/profile/skills`, `/profile/skills/evidence?skill=<id>`.
  - Widget keys: `specialty-<id>`, `style-<id>`, `extra-<id>`, `language-<id>`, `audience-<id>`, `level-<id>`, `evidence-row-<id>`, `evidence-edit-<id>`, `skills-years`, `skills-back`, `skills-submit`, `confirm-keep`, `confirm-discard`.
  - Test helper `Widget skillsApp(SkillsWorld w, {required String initialLocation, Brightness brightness = Brightness.dark, double textScale = 1})` in `test/support/skills_app.dart` (stub routes `/start`, `/setup/2`, `/setup/4`, `/profile`, `/action`).
  - Behaviour: one scrolling page (S38 part, then the S39 part wrapped in `ScreenCode(ScreenCodes.skillsPart2)`); setup mode shows `StepProgress(3/4)`, "Quay lại" + "Tiếp tục" (saves, logs `skills_step{n: 3}`, pushes `/setup/4`); edit mode shows "Lưu thay đổi" (enabled when the draft differs from the saved skills) and pops after saving (or goes to `/profile`). "Tiếp tục" is off without a genre; with problems it saves nothing, shows them in place, scrolls to the first and shows "Kiểm tra lại các mục được đánh dấu". Refused edits show the limit in a `SnackBar`. Leaving with changes (Back, system back, "Quay lại") asks "Lưu bản nháp?" ("Giữ bản nháp" keeps the device draft, red "Bỏ thay đổi" drops it, dismissing stays). Unticking a genre that has evidence asks first. A reopened device draft is announced once. The deep link opens S40 for that genre once loaded. Logs `screen_view{code: S38}` once.
  - l10n keys listed in Step 3.

- [ ] **Step 1: Write the harness and the failing tests**

```dart
// test/support/skills_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/skills/skills_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import 'photo_scope.dart';
import 'skills_world.dart';

/// The skills routes as the app registers them, plus stubs for where they
/// lead. `/start` pushes `/profile/skills` so Back has somewhere to go.
Widget skillsApp(
  SkillsWorld w, {
  required String initialLocation,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/profile/skills'),
              child: const Text('open skills'),
            ),
          ),
        ),
      ),
      GoRoute(path: '/setup/2', builder: (_, _) => const Scaffold(body: Text('S24 bước 2'))),
      GoRoute(path: '/setup/3', builder: (_, _) => const SkillsScreen(mode: SkillsMode.setup)),
      GoRoute(path: '/setup/4', builder: (_, _) => const Scaffold(body: Text('S34'))),
      GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('S30'))),
      GoRoute(path: '/profile/skills', builder: (_, _) => const SkillsScreen(mode: SkillsMode.edit)),
      GoRoute(
        path: '/profile/skills/evidence',
        builder: (_, s) => SkillsScreen(
          mode: SkillsMode.edit,
          openEvidenceFor: s.uri.queryParameters['skill'],
        ),
      ),
      GoRoute(path: '/action', builder: (_, _) => const Scaffold(body: Text('S21'))),
    ],
  );
  return ProviderScope(
    retry: (_, _) => null,
    overrides: w.overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => testPhotoScope(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
}
```

```dart
// test/features/skills/skills_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/skills/evidence_sheet.dart';
import 'package:photobooking/features/skills/skills_draft_store.dart';

import '../../support/content_fixtures.dart';
import '../../support/skills_app.dart';
import '../../support/skills_world.dart';

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<SkillsWorld> _pump(
  WidgetTester tester, {
  String at = '/setup/3',
  PhotographerSkills? saved,
  List<PostSummary> Function(String uid)? posts,
  Future<void> Function(SkillsWorld w)? before,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) async {
  final w = await SkillsWorld.create(saved: saved, posts: posts);
  await before?.call(w);
  await tester.pumpWidget(skillsApp(w, initialLocation: at, brightness: brightness, textScale: textScale));
  await tester.pumpAndSettle();
  return w;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) => _tap(tester, find.byKey(Key(key)));

Future<void> _level(WidgetTester tester, String id, String label) => _tap(
  tester,
  find.descendant(of: find.byKey(Key('level-$id')), matching: find.text(label)),
);

VoidCallback? _submitPressed(WidgetTester tester) => tester
    .widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('skills-submit')), matching: find.byType(FilledButton)),
    )
    .onPressed;

List<PostSummary> Function(String) _ownPosts(int n) =>
    (uid) => [for (var i = 0; i < n; i++) fixturePost('m$i', photographerId: uid, age: Duration(minutes: i + 1))];

const _portraitWithEvidence = PhotographerSkills(
  specialties: [SpecialtySkill(id: 'portrait', evidencePostIds: ['m0'])],
  languages: ['vi'],
);

void main() {
  testWidgets('setup: step 3/4, intro, meter; Tiếp tục off until a genre is chosen', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester);
    final step = tester.widget<StepProgress>(find.byType(StepProgress));
    expect((step.current, step.total), (3, 4));
    expect(find.text('Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.'), findsOneWidget);
    expect(tester.widget<CompletenessMeter>(find.byType(CompletenessMeter)).percent, 10);
    expect(find.text('Chọn ít nhất 1 thể loại để lên 75%'), findsOneWidget);
    expect(_submitPressed(tester), isNull);
    await _tapKey(tester, 'specialty-portrait');
    expect(find.byKey(const Key('level-portrait')), findsOneWidget);
    expect(tester.widget<LevelSelector>(find.byKey(const Key('level-portrait'))).level, 2);
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.text('Chân dung: 0 / 3 ảnh minh chứng'), findsOneWidget);
    expect(_submitPressed(tester), isNotNull);
    expect(w.event('screen_view'), {'code': 'S38'});
  });

  testWidgets('the 7th genre is refused with "Tối đa 6 thể loại"', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    for (final id in ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event']) {
      await _tapKey(tester, 'specialty-$id');
    }
    await _tapKey(tester, 'specialty-product');
    expect(find.text('Tối đa 6 thể loại'), findsOneWidget);
    expect(find.byType(LevelSelector), findsNWidgets(6));
  });

  testWidgets('the 4th Chuyên sâu is refused and the old level kept', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    for (final id in ['portrait', 'wedding', 'couple', 'family']) {
      await _tapKey(tester, 'specialty-$id');
    }
    for (final id in ['portrait', 'wedding', 'couple']) {
      await _level(tester, id, 'Chuyên sâu');
    }
    await _level(tester, 'family', 'Chuyên sâu');
    expect(find.text('Chỉ chọn tối đa 3 thể loại mức Chuyên sâu'), findsOneWidget);
    expect(tester.widget<LevelSelector>(find.byKey(const Key('level-family'))).level, 2);
    expect(tester.widget<LevelSelector>(find.byKey(const Key('level-family'))).expertDisabled, isTrue);
  });

  testWidgets('Chuyên sâu without evidence: warning, and Tiếp tục saves nothing', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _level(tester, 'portrait', 'Chuyên sâu');
    expect(find.text('Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng'), findsOneWidget);
    expect(find.text('Thêm ảnh minh chứng cho Chân dung để lên 75%'), findsOneWidget);
    await _tapKey(tester, 'skills-submit');
    expect(find.text('Kiểm tra lại các mục được đánh dấu'), findsOneWidget);
    expect(find.text('S34'), findsNothing);
    expect(w.skills.saveCalls, 0);
  });

  testWidgets('no language: the error appears under Ngôn ngữ', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'language-vi');
    expect(find.text('Chọn ít nhất 1 ngôn ngữ'), findsNothing);
    await _tapKey(tester, 'skills-submit');
    expect(find.text('Chọn ít nhất 1 ngôn ngữ'), findsOneWidget);
    await _tapKey(tester, 'language-en');
    expect(find.text('Chọn ít nhất 1 ngôn ngữ'), findsNothing);
  });

  testWidgets('a valid setup saves catalogue ids and opens S34', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'style-film');
    await _tapKey(tester, 'extra-posing');
    await _tapKey(tester, 'audience-shy_subjects');
    await tester.ensureVisible(find.byKey(const Key('skills-years')));
    await tester.enterText(find.byKey(const Key('skills-years')), '6');
    await tester.pumpAndSettle();
    await _tapKey(tester, 'skills-submit');
    expect(find.text('S34'), findsOneWidget);
    expect(
      w.skills.stored(w.uid),
      const PhotographerSkills(
        specialties: [SpecialtySkill(id: 'portrait')],
        styles: ['film'],
        extras: ['posing'],
        languages: ['vi'],
        audiences: ['shy_subjects'],
        yearsExperience: 6,
      ),
    );
    expect(w.event('skills_step'), {'n': 3});
    expect(w.event('skills_save'), {'specialties': 1, 'expert': 0});
  });

  testWidgets('evidence: pick in S40, the row updates, saved with the skills', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester, posts: _ownPosts(4));
    await _tapKey(tester, 'specialty-portrait');
    await _level(tester, 'portrait', 'Chuyên sâu');
    await _tapKey(tester, 'evidence-edit-portrait');
    expect(find.byType(EvidenceSheet), findsOneWidget);
    await _tapKey(tester, 'evidence-m1');
    await _tapKey(tester, 'evidence-m2');
    await _tapKey(tester, 'evidence-done');
    expect(find.text('Chân dung: 2 / 3 ảnh minh chứng'), findsOneWidget);
    expect(find.text('Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng'), findsNothing);
    await _tapKey(tester, 'skills-submit');
    expect(find.text('S34'), findsOneWidget);
    expect(w.skills.stored(w.uid)!.specialty('portrait')!.evidencePostIds, ['m1', 'm2']);
  });

  testWidgets('no posts yet: the sheet leads to S21', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'evidence-edit-portrait');
    expect(find.text('Đăng bài trước'), findsOneWidget);
    await _tap(tester, find.text('Đăng bài'));
    expect(find.text('S21'), findsOneWidget);
  });

  testWidgets('edit mode: saved skills shown; Lưu thay đổi only after a change; saving goes back', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester, at: '/start', saved: _portraitWithEvidence, posts: _ownPosts(1));
    await _tap(tester, find.text('open skills'));
    expect(find.byType(StepProgress), findsNothing);
    expect(find.byKey(const Key('skills-back')), findsNothing);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(_submitPressed(tester), isNull);
    await _tapKey(tester, 'style-minimal');
    expect(_submitPressed(tester), isNotNull);
    await _tapKey(tester, 'skills-submit');
    expect(find.text('open skills'), findsOneWidget);
    expect(w.skills.stored(w.uid)!.styles, ['minimal']);
  });

  testWidgets('leaving with changes asks; "Giữ bản nháp" keeps the device draft', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester, at: '/start');
    await _tap(tester, find.text('open skills'));
    await _tapKey(tester, 'specialty-wedding');
    await _tap(tester, find.byType(BackButton));
    expect(find.text('Lưu bản nháp?'), findsOneWidget);
    await _tapKey(tester, 'confirm-keep');
    expect(find.text('open skills'), findsOneWidget);
    expect(SkillsDraftStore(w.prefs).read(w.uid)!.specialtyIds, ['wedding']);
  });

  testWidgets('"Bỏ thay đổi" forgets the draft and leaves; dismissing stays', (tester) async {
    _tallPhone(tester);
    final w = await _pump(tester, at: '/start');
    await _tap(tester, find.text('open skills'));
    await _tapKey(tester, 'specialty-wedding');
    await _tap(tester, find.byType(BackButton));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('skills-submit')), findsOneWidget, reason: 'dismissed: still here');
    await _tap(tester, find.byType(BackButton));
    await _tapKey(tester, 'confirm-discard');
    expect(find.text('open skills'), findsOneWidget);
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNull);
  });

  testWidgets('unticking a genre with evidence asks first', (tester) async {
    _tallPhone(tester);
    await _pump(tester, at: '/profile/skills', saved: _portraitWithEvidence, posts: _ownPosts(1));
    await _tapKey(tester, 'specialty-portrait');
    expect(find.text('Bỏ thể loại Chân dung?'), findsOneWidget);
    await _tapKey(tester, 'confirm-keep');
    expect(find.byKey(const Key('level-portrait')), findsOneWidget);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'confirm-discard');
    expect(find.byKey(const Key('level-portrait')), findsNothing);
  });

  testWidgets('setup "Quay lại" without changes goes to step 2', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    await _tapKey(tester, 'skills-back');
    expect(find.text('S24 bước 2'), findsOneWidget);
  });

  testWidgets('the deep link opens S40 for that genre', (tester) async {
    _tallPhone(tester);
    await _pump(tester, at: '/profile/skills/evidence?skill=portrait', saved: _portraitWithEvidence, posts: _ownPosts(2));
    expect(find.byType(EvidenceSheet), findsOneWidget);
    expect(find.text('Minh chứng · Chân dung'), findsOneWidget);
  });

  testWidgets('a reopened device draft is announced', (tester) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: _portraitWithEvidence,
      posts: _ownPosts(1),
      before: (w) => SkillsDraftStore(w.prefs).write(
        w.uid,
        const PhotographerSkills(specialties: [SpecialtySkill(id: 'food')], languages: ['vi']),
      ),
    );
    expect(find.text('Đã mở lại bản nháp chưa lưu'), findsOneWidget);
    expect(find.byKey(const Key('level-food')), findsOneWidget);
  });

  testWidgets('a load error shows a message and retries', (tester) async {
    _tallPhone(tester);
    final w = await SkillsWorld.create();
    w.skills.failLoadWith = StateError('offline');
    await tester.pumpWidget(skillsApp(w, initialLocation: '/setup/3'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được kỹ năng.'), findsOneWidget);
    w.skills.failLoadWith = null;
    await _tapKey(tester, 'error-retry');
    expect(find.byKey(const Key('specialty-portrait')), findsOneWidget);
  });

  testWidgets('320dp at 1.3x in both themes: no overflow, buttons 52dp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const rich = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'real_estate', level: 3),
        SpecialtySkill(id: 'graduation'),
        SpecialtySkill(id: 'newborn', level: 1),
      ],
      styles: ['natural_light'],
      audiences: ['shy_subjects', 'family_kids'],
      languages: ['vi', 'ko'],
      yearsExperience: 12,
    );
    for (final b in Brightness.values) {
      await _pump(tester, saved: rich, brightness: b, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('skills-submit'))).height, controlHeight);
      expect(tester.getSize(find.byKey(const Key('skills-back'))).height, controlHeight);
    }
  });

  testWidgets('the app router registers the three skills routes', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final paths = container.read(routerProvider).configuration.routes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, containsAll(['/setup/3', '/profile/skills', '/profile/skills/evidence']));
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/skills/skills_screen_test.dart`
Expected: FAIL, `skills_screen.dart` does not exist.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "skillsTitle": "Kỹ năng",
  "skillsIntro": "Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.",
  "skillsTypes": "Thể loại chụp",
  "skillsLevels": "Mức độ",
  "skillsMaxExpert": "Chuyên sâu tối đa 3",
  "skillsEvidenceRow": "{name}: {n} / 3 ảnh minh chứng",
  "@skillsEvidenceRow": {
    "placeholders": {
      "name": {"type": "String"},
      "n": {"type": "int"}
    }
  },
  "skillsEvidenceEdit": "Chỉnh",
  "skillsEvidenceNeeded": "Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng",
  "skillsTooMany": "Tối đa 6 thể loại",
  "skillsTooManyExpert": "Chỉ chọn tối đa 3 thể loại mức Chuyên sâu",
  "skillsTooManyStyles": "Tối đa 4 phong cách",
  "skillsTooManyExtras": "Tối đa 8 kỹ năng thêm",
  "skillsTooManyAudiences": "Tối đa 4 nhóm khách phù hợp",
  "skillsStyles": "Phong cách",
  "skillsExtras": "Kỹ năng thêm",
  "skillsLanguages": "Ngôn ngữ",
  "skillsAudiences": "Khách phù hợp",
  "skillsYears": "Kinh nghiệm",
  "skillsYearsSuffix": "năm",
  "skillsYearsRange": "Từ 0 đến 50 năm",
  "skillsNeedLang": "Chọn ít nhất 1 ngôn ngữ",
  "skillsBack": "Quay lại",
  "skillsContinue": "Tiếp tục",
  "skillsSave": "Lưu thay đổi",
  "skillsSaveError": "Không lưu được kỹ năng. Thử lại nhé.",
  "skillsLoadError": "Không tải được kỹ năng.",
  "skillsFixIssues": "Kiểm tra lại các mục được đánh dấu",
  "skillsDraftRestored": "Đã mở lại bản nháp chưa lưu",
  "skillsHintSpecialty": "Chọn ít nhất 1 thể loại để lên {percent}%",
  "@skillsHintSpecialty": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintEvidence": "Thêm ảnh minh chứng cho {name} để lên {percent}%",
  "@skillsHintEvidence": {"placeholders": {"name": {"type": "String"}, "percent": {"type": "int"}}},
  "skillsHintStyles": "Chọn phong cách để lên {percent}%",
  "@skillsHintStyles": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintLanguages": "Chọn ngôn ngữ để lên {percent}%",
  "@skillsHintLanguages": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintAudiences": "Chọn khách phù hợp để lên {percent}%",
  "@skillsHintAudiences": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintExtras": "Chọn kỹ năng thêm để lên {percent}%",
  "@skillsHintExtras": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintDone": "Hồ sơ kỹ năng đã đầy đủ",
  "skillsLeaveTitle": "Lưu bản nháp?",
  "skillsLeaveBody": "Thay đổi chưa được lưu vào hồ sơ. Giữ bản nháp trên máy để làm tiếp lần sau nhé.",
  "skillsLeaveKeep": "Giữ bản nháp",
  "skillsLeaveDiscard": "Bỏ thay đổi",
  "skillsRemoveTitle": "Bỏ thể loại {name}?",
  "@skillsRemoveTitle": {"placeholders": {"name": {"type": "String"}}},
  "skillsRemoveBody": "Ảnh minh chứng đã gắn cho thể loại này cũng sẽ bị gỡ.",
  "skillsRemoveKeep": "Giữ lại",
  "skillsRemoveConfirm": "Bỏ thể loại",
```

```dart
// lib/features/skills/skills_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_completeness.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_rules.dart';
import 'package:photobooking/features/skills/evidence_sheet.dart';
import 'package:photobooking/features/skills/skills_analytics.dart';
import 'package:photobooking/features/skills/skills_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

enum SkillsMode {
  /// Setup step 3/4 (`/setup/3`): "Quay lại" + "Tiếp tục" → S34.
  setup,

  /// From the profile (`/profile/skills`): "Lưu thay đổi" → back.
  edit,
}

/// S38 + S39: genres and levels, then styles, extra skills, languages,
/// suitable clients and years, on one scrolling page.
class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key, required this.mode, this.openEvidenceFor});

  final SkillsMode mode;

  /// Deep link `/profile/skills/evidence?skill=…`: open S40 for this genre
  /// once the skills are loaded (ignored when the genre is not chosen).
  final String? openEvidenceFor;

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  final _scroll = ScrollController();
  final _years = TextEditingController();
  final _sectionKeys = {for (final g in SkillGroup.values) g: GlobalKey()};
  final _yearsKey = GlobalKey();
  bool _loaded = false;
  bool _allowPop = false;

  bool get _setup => widget.mode == SkillsMode.setup;

  SkillsController get _ctrl => ref.read(skillsControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    ref.listenManual(skillsControllerProvider, (_, next) {
      final s = next.value;
      if (s != null && !_loaded) {
        _loaded = true;
        _onLoaded(s);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _years.dispose();
    super.dispose();
  }

  void _onLoaded(SkillsEditorState s) {
    ref.read(skillsAnalyticsProvider)('screen_view', {
      'code': ScreenCodes.skillsPart1,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _years.text = s.draft.yearsExperience?.toString() ?? '';
      if (s.restoredDraft) _snack(context.l10n.skillsDraftRestored);
      final open = widget.openEvidenceFor;
      if (open != null && s.draft.specialty(open) != null) _editEvidence(open);
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _report(SkillEdit? e) {
    if (e == null || e.accepted) return;
    final text = _rejectionText(context.l10n, e);
    if (text != null) _snack(text);
  }

  Future<void> _toggleSpecialty(SkillsEditorState s, String id) async {
    final chosen = s.draft.specialty(id);
    if (chosen != null && chosen.evidencePostIds.isNotEmpty) {
      final l = context.l10n;
      final name = ref.read(skillCatalogProvider).label(SkillGroup.specialty, id);
      final remove = await showAppSheet<bool>(
        context,
        builder: (_) => _ConfirmSheet(
          title: l.skillsRemoveTitle(name),
          body: l.skillsRemoveBody,
          keepLabel: l.skillsRemoveKeep,
          discardLabel: l.skillsRemoveConfirm,
        ),
      );
      if (remove != true || !mounted) return;
    }
    _report(_ctrl.toggleSpecialty(id));
  }

  Future<void> _editEvidence(String id) async {
    final sp = ref.read(skillsControllerProvider).value?.draft.specialty(id);
    if (sp == null) return;
    final name = ref.read(skillCatalogProvider).label(SkillGroup.specialty, id);
    final router = GoRouter.of(context);
    final picked = await showEvidenceSheet(
      context,
      specialtyName: name,
      initial: sp.evidencePostIds,
      requiresOne: sp.isExpert,
      onCreatePost: () => router.go(AppTab.action.path),
    );
    if (picked == null || !mounted) return;
    _report(_ctrl.setEvidence(id, picked));
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final log = ref.read(skillsAnalyticsProvider);
    final result = await _ctrl.submit();
    if (!mounted) return;
    switch (result) {
      case SkillsSubmitResult.saved:
        if (_setup) {
          log('skills_step', {'n': 3});
          context.push('/setup/4');
        } else {
          _leave();
        }
      case SkillsSubmitResult.invalid:
        final issues = ref.read(skillsControllerProvider).value?.issues;
        if (issues != null && issues.isNotEmpty) _scrollTo(issues.first);
        _snack(l.skillsFixIssues);
      case SkillsSubmitResult.failed:
        _snack(l.skillsSaveError);
    }
  }

  void _scrollTo(SkillIssue issue) {
    final key = issue.code == SkillIssueCode.yearsOutOfRange && issue.group == null
        ? _yearsKey
        : _sectionKeys[issue.group ?? SkillGroup.specialty]!;
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  Future<void> _back() async {
    final s = ref.read(skillsControllerProvider).value;
    if (s != null && s.dirty) {
      final l = context.l10n;
      final discard = await showAppSheet<bool>(
        context,
        builder: (_) => _ConfirmSheet(
          title: l.skillsLeaveTitle,
          body: l.skillsLeaveBody,
          keepLabel: l.skillsLeaveKeep,
          discardLabel: l.skillsLeaveDiscard,
        ),
      );
      if (discard == null || !mounted) return;
      if (discard) await _ctrl.discardDraft();
      if (!mounted) return;
    }
    _leave();
  }

  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(_setup ? '/setup/2' : AppTab.profile.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(skillsControllerProvider);
    final dirty = async.value?.dirty ?? false;
    return ScreenCode(
      ScreenCodes.skillsPart1,
      child: PopScope(
        canPop: _allowPop || !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text(l.skillsTitle)),
            body: SafeArea(
              top: false,
              child: async.when(
                loading: () => const _SkillsSkeleton(),
                error: (_, _) => Center(
                  child: ErrorState(
                    message: l.skillsLoadError,
                    onRetry: () => ref.invalidate(skillsControllerProvider),
                  ),
                ),
                data: _content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(SkillsEditorState s) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final catalog = ref.watch(skillCatalogProvider);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final report = s.completeness;
    final count = s.draft.specialties.length;
    final enabled = s.canSubmit && (_setup || s.unsaved);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s5,
              AppSpace.s2,
              AppSpace.s5,
              AppSpace.s6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_setup) ...[
                  const StepProgress(current: 3, total: 4),
                  const SizedBox(height: AppSpace.s4),
                ],
                Text(
                  l.skillsIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpace.s4),
                GlassCard(
                  highlight: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: CompletenessMeter(
                      percent: report.percent,
                      nextHint: _hintText(l, catalog, report),
                    ),
                  ),
                ),
                Column(
                  key: _sectionKeys[SkillGroup.specialty],
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(
                      title: l.skillsTypes,
                      trailing: l.skillsCount(count, SkillLimits.maxSpecialties),
                    ),
                    Wrap(
                      spacing: AppSpace.s2,
                      children: [
                        for (final item in catalog.options(
                          SkillGroup.specialty,
                          keep: s.draft.specialtyIds,
                        ))
                          SkillChip(
                            key: Key('specialty-${item.id}'),
                            label: item.labelVi,
                            selected: s.draft.specialty(item.id) != null,
                            disabled: count >= SkillLimits.maxSpecialties,
                            onTap: () => _toggleSpecialty(s, item.id),
                          ),
                      ],
                    ),
                    if (count > 0) ...[
                      _SectionHeader(
                        title: l.skillsLevels,
                        trailing: l.skillsMaxExpert,
                      ),
                      for (final sp in s.draft.specialties) ...[
                        LevelSelector(
                          key: Key('level-${sp.id}'),
                          title: catalog.label(SkillGroup.specialty, sp.id),
                          level: sp.level,
                          expertDisabled:
                              s.draft.expertCount >= SkillLimits.maxExpert &&
                              !sp.isExpert,
                          onChanged: (v) => _report(_ctrl.setLevel(sp.id, v)),
                        ),
                        const SizedBox(height: AppSpace.s1),
                        _EvidenceRow(
                          key: Key('evidence-row-${sp.id}'),
                          text: l.skillsEvidenceRow(
                            catalog.label(SkillGroup.specialty, sp.id),
                            sp.evidencePostIds.length,
                          ),
                          warning: sp.isExpert && sp.evidencePostIds.isEmpty
                              ? l.skillsEvidenceNeeded
                              : null,
                          editLabel: l.skillsEvidenceEdit,
                          editKey: Key('evidence-edit-${sp.id}'),
                          onEdit: () => _editEvidence(sp.id),
                        ),
                        const SizedBox(height: AppSpace.s3),
                      ],
                    ],
                  ],
                ),
                ScreenCode(
                  ScreenCodes.skillsPart2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _tagSection(s, catalog, SkillGroup.style, l.skillsStyles),
                      _tagSection(s, catalog, SkillGroup.extra, l.skillsExtras),
                      _tagSection(
                        s,
                        catalog,
                        SkillGroup.language,
                        l.skillsLanguages,
                        error: s.hasIssue(SkillIssueCode.noLanguage)
                            ? l.skillsNeedLang
                            : null,
                      ),
                      _tagSection(s, catalog, SkillGroup.audience, l.skillsAudiences),
                      Padding(
                        key: _yearsKey,
                        padding: const EdgeInsets.only(top: AppSpace.s5),
                        child: TextField(
                          key: const Key('skills-years'),
                          controller: _years,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: InputDecoration(
                            labelText: l.skillsYears,
                            suffixText: l.skillsYearsSuffix,
                            errorText: s.hasIssue(SkillIssueCode.yearsOutOfRange)
                                ? l.skillsYearsRange
                                : null,
                          ),
                          onChanged: (v) => _ctrl.setYears(int.tryParse(v)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            AppSpace.s3,
            AppSpace.s5,
            AppSpace.s4,
          ),
          child: Row(
            children: [
              if (_setup) ...[
                Expanded(
                  flex: 9,
                  child: SizedBox(
                    height: controlHeight,
                    child: AppButton.outline(
                      l.skillsBack,
                      key: const Key('skills-back'),
                      onPressed: s.saving ? null : _back,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
              ],
              Expanded(
                flex: 16,
                child: SizedBox(
                  height: controlHeight,
                  child: AppButton.primary(
                    _setup ? l.skillsContinue : l.skillsSave,
                    key: const Key('skills-submit'),
                    loading: s.saving,
                    onPressed: enabled ? _submit : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagSection(
    SkillsEditorState s,
    TaxonomyCatalog catalog,
    SkillGroup group,
    String title, {
    String? error,
  }) {
    final l = context.l10n;
    final ids = s.draft.tags(group);
    final max = SkillLimits.maxFor(group);
    final limited = group != SkillGroup.language;
    return Column(
      key: _sectionKeys[group],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: title,
          trailing: limited ? l.skillsCount(ids.length, max) : null,
        ),
        Wrap(
          spacing: AppSpace.s2,
          children: [
            for (final item in catalog.options(group, keep: ids))
              SkillChip(
                key: Key('${group.code}-${item.id}'),
                label: item.labelVi,
                selected: ids.contains(item.id),
                disabled: limited && ids.length >= max,
                onTap: () => _report(_ctrl.toggleTag(group, item.id)),
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

String _hintText(
  AppLocalizations l,
  TaxonomyCatalog catalog,
  CompletenessReport report,
) {
  final h = report.next;
  if (h == null) return l.skillsHintDone;
  return switch (h.step) {
    CompletenessStep.specialties ||
    CompletenessStep.levels => l.skillsHintSpecialty(h.percentAfter),
    CompletenessStep.evidence => l.skillsHintEvidence(
      catalog.label(SkillGroup.specialty, h.specialtyId!),
      h.percentAfter,
    ),
    CompletenessStep.styles => l.skillsHintStyles(h.percentAfter),
    CompletenessStep.languages => l.skillsHintLanguages(h.percentAfter),
    CompletenessStep.audiences => l.skillsHintAudiences(h.percentAfter),
    CompletenessStep.extras => l.skillsHintExtras(h.percentAfter),
  };
}

String? _rejectionText(AppLocalizations l, SkillEdit e) => switch (e.rejection) {
  null || SkillEditRejection.notSelectable => null,
  SkillEditRejection.tooManyExpert => l.skillsTooManyExpert,
  SkillEditRejection.tooManyEvidence => l.skillEvidenceMax,
  SkillEditRejection.tooManyItems => switch (e.group) {
    SkillGroup.specialty => l.skillsTooMany,
    SkillGroup.style => l.skillsTooManyStyles,
    SkillGroup.extra => l.skillsTooManyExtras,
    SkillGroup.audience => l.skillsTooManyAudiences,
    SkillGroup.language || null => null,
  },
};

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s5, bottom: AppSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s2),
            Text(
              trailing!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Chân dung: 2 / 3 ảnh minh chứng" + "Chỉnh"; a level-3 genre without
/// evidence turns into a yellow warning row (icon and text, not colour only).
class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    super.key,
    required this.text,
    required this.editLabel,
    required this.editKey,
    required this.onEdit,
    this.warning,
  });

  final String text;
  final String editLabel;
  final Key editKey;
  final VoidCallback onEdit;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final edit = TextButton(
      key: editKey,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onEdit,
      child: Text(editLabel),
    );
    if (warning == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ),
          edit,
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? AppColorsDark.warning.withValues(alpha: 0.16)
            : AppColors.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpace.s3),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: theme.textTheme.bodySmall),
                  Text(
                    warning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            edit,
          ],
        ),
      ),
    );
  }
}

/// Confirmation sheet: the safe choice is the main button, the destructive
/// one is red. Pops `false` (keep), `true` (discard) or null (dismissed).
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.body,
    required this.keepLabel,
    required this.discardLabel,
  });

  final String title;
  final String body;
  final String keepLabel;
  final String discardLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s5, 0, AppSpace.s5, AppSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpace.s5),
          SizedBox(
            height: controlHeight,
            child: AppButton.primary(
              keepLabel,
              key: const Key('confirm-keep'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          SizedBox(
            height: controlHeight,
            child: FilledButton(
              key: const Key('confirm-discard'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
                foregroundColor: AppColors.destructiveForeground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(controlRadius),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(discardLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSkeleton extends StatelessWidget {
  const _SkillsSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.s5),
    physics: const NeverScrollableScrollPhysics(),
    children: const [
      AppSkeleton.card(height: 88),
      SizedBox(height: AppSpace.s4),
      AppSkeleton.line(width: 120),
      SizedBox(height: AppSpace.s3),
      AppSkeleton.box(height: 96),
      SizedBox(height: AppSpace.s4),
      AppSkeleton.line(width: 120),
      SizedBox(height: AppSpace.s3),
      AppSkeleton.box(height: 48),
      SizedBox(height: AppSpace.s2),
      AppSkeleton.box(height: 48),
    ],
  );
}
```

`lib/app/router.dart`: add `import 'package:photobooking/features/skills/skills_screen.dart';` (alphabetical among the feature imports) and, in the top-level `routes` list just before `StatefulShellRoute.indexedStack(` (next to plan 2b's `/setup/4`):

```dart
      GoRoute(
        path: '/setup/3',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.setup),
      ),
      GoRoute(
        path: '/profile/skills',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.edit),
      ),
      GoRoute(
        path: '/profile/skills/evidence',
        builder: (_, state) => SkillsScreen(
          mode: SkillsMode.edit,
          openEvidenceFor: state.uri.queryParameters['skill'],
        ),
      ),
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/skills && flutter test && flutter analyze`
Expected: the 17 screen tests PASS, the whole suite passes (including `test/app` and `responsive_test.dart`), analyze clean. If the router test cannot build `routerProvider` without a binding, add `TestWidgetsFlutterBinding.ensureInitialized();` (it is a `testWidgets`, so the binding exists; the usual cause is a missing provider override, which the error names). If a chip is hidden behind the bottom bar at 320dp, `_tap` scrolls it into view first; do not shrink the bar.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(skills): S38/S39 skills screen at /setup/3 and /profile/skills, S40 deep link

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Align the specs with what was built

**Files:**
- Modify: `docs/superpowers/specs/screens/photographer.md` (S38, S40), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§3e.2, §3e.3), `docs/superpowers/specs/components/shared-components.md` (SkillChip, LevelSelector, EvidencePicker), `docs/superpowers/specs/data-model/README.md` (§8)

**Interfaces:** none (documentation).

- [ ] **Step 1: Edit**

1. `photographer.md`, S38 **Dữ liệu**: replace
   `- **Dữ liệu**: \`skillsControllerProvider\` giữ nháp; danh mục từ \`taxonomy/skills\`; lưu vào \`photographers/{uid}.skills\`; \`completeness\` do Function tính và trả về qua snapshot.`
   with
   `- **Dữ liệu**: \`skillsControllerProvider\` giữ nháp; nháp tự lưu **trên máy** (\`SharedPreferences\`, khoá \`skillsDraft.<uid>\`) sau mỗi thay đổi, nên nháp được phép chưa hợp lệ; Firestore chỉ nhận kỹ năng hợp lệ khi bấm "Tiếp tục"/"Lưu thay đổi" (một lần ghi \`photographers/{uid}.skills\`, gộp với dữ liệu sẵn có). Danh mục là bản tích hợp (\`builtInSkillCatalog\`, khoá theo nhóm + id); đọc \`taxonomy/skills\` từ xa để sau. Độ khớp hồ sơ tính ngay trên máy bằng đúng công thức 3e.2 (\`skillsCompleteness\`); khi có Function \`onPhotographerWrite\` thì Function ghi \`completeness\` theo cùng công thức. Không dùng snapshot.`
   In S38 **Chuỗi**, append: `Khoá arb dạng camelCase: \`skills*\`, \`completeness*\` (\`lib/l10n/app_vi.arb\`).`
   In S38 **Tương tác**, append: `Thoát khi có thay đổi: sheet "Lưu bản nháp?" với "Giữ bản nháp" (giữ nháp trên máy) và nút đỏ "Bỏ thay đổi". Chế độ sửa: nút chính "Lưu thay đổi" chỉ bật khi khác bản đã lưu.`
2. `photographer.md`, S40 **Thông tin**: replace `(sheet)` with `(sheet mở từ dòng "Chỉnh" ở S38; link này mở S38 ở chế độ sửa rồi mở sheet cho thể loại \`skill\`)`. In S40 **Trạng thái**, replace `chọn quá 3 → báo, bỏ chọn một ảnh để chọn thêm` with `chọn quá 3 → âm báo và dòng báo ngay trong sheet (SnackBar sẽ bị modal che), bỏ chọn một ảnh để chọn thêm`. In S40 **Dữ liệu**, append: `Chỉ bài có \`authorId\` là chính nhiếp ảnh gia (không gồm bài \`real_shoot\` của khách gắn vào trang), 30 bài mỗi trang.`
3. `2026-10-01-remaining-screens.md` §3e.3, after the bullet that starts `- Công khai (đọc bởi mọi người đã đăng nhập)`, add:
   `- Cách kiểm hiện tại: rules so id với danh sách cố định trong \`firestore.rules\` (sao từ danh mục tích hợp; test \`rules_catalogue_sync_test.dart\` giữ hai bên trùng nhau, nên thêm mục danh mục cần deploy rules), kiểm giới hạn, mức 3 cần ≥ 1 minh chứng, không cho client đổi \`completeness\`/\`skills.updatedAt\`. Việc \`evidencePostIds\` thuộc bài của chính họ **không** kiểm trong rules (cần một lần đọc cho mỗi bài, vượt giới hạn 10 lần đọc); sheet S40 chỉ cho chọn bài của mình và Function \`onPhotographerWrite\` kiểm lại.`
   In §3e.2, after the sentence that starts `- Danh mục lấy từ \`taxonomy/skills\``, add: `Id chỉ duy nhất **trong một nhóm**: \`couple\` vừa là thể loại vừa là khách phù hợp, nên mọi tra cứu dùng cặp (\`group\`, \`id\`).`
4. `shared-components.md`:
   - SkillChip: append `\`disabled\` chỉ làm mờ chip chưa chọn và đọc "Đã đủ số lượng"; chạm vẫn báo lên để màn nêu giới hạn.`
   - LevelSelector: append `Vẽ ba ô riêng (cùng kiểu \`SegmentedTabs\`) vì \`SegmentedTabs\` không có ô bị làm mờ. Một điểm dừng Tab; trình đọc màn hình thấy một nút điều chỉnh được (tăng/giảm).`
   - EvidencePicker: replace the signature with `EvidencePicker({required List<PostThumb> posts, required Set<String> selected, required ValueChanged<Set<String>> onChanged, int max = 3, VoidCallback? onMaxReached, VoidCallback? onEndReached})` (\`PostThumb(id, imageUrl)\`) and replace `vượt \`max\` phát tiếng báo và \`SnackBar\`` with `vượt \`max\` phát âm báo và gọi \`onMaxReached\` (sheet S40 hiện dòng báo); lưới lười (\`GridView.builder\`), ảnh giải mã đúng cỡ ô qua \`NetworkPhoto\`; \`onEndReached\` khi cuộn gần cuối để tải trang sau`.
5. `data-model/README.md` §8 **Câu hỏi mở**, append a numbered item (next number in that list):
   `Mã danh mục trùng giữa hai nhóm: \`couple\` là thể loại và cũng là khách phù hợp (seed ở relational-schema.md §6), trong khi \`taxonomy_items.id\` là khoá chính và \`taxonomy/skills/items/{id}\` là id tài liệu. Ứng dụng đã tra theo (\`group\`, \`id\`). Trước khi di trú cần chọn: khoá chính (\`grp\`, \`id\`) và khoá ngoại hai cột, hoặc đổi mã khách thành \`couples\` (cần di trú dữ liệu \`audiences\`).`
6. Run `git diff --stat docs/` and read each hunk once.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs
git commit -m "docs: align S38/S40, skills rules and components with the implementation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Battery and performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-step2c-skills.md"). Nothing to do here.
