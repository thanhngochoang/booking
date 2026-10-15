# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3c-create-post.md

Setup: worktree /Users/tonyh/Documents/_project/Tool/booking/.claude/worktrees/agent-a032520e3c16046d8, branch plan-3c reset to flutter-rewrite 40aa98f (image_picker 1.2.3 added there by the coordinator). Toolchain dirs symlinked; app_flutter/.dart_tool copied (re-copied after 40aa98f); gitignored lib/firebase_options.dart copied from the main checkout (analyze fails without it). .vscode/launch.json and .vscode/settings.json marked skip-worktree (sandbox could not write them) — merger: `git update-index --no-skip-worktree .vscode/launch.json .vscode/settings.json`.
Baseline: analyze clean; test/core 364 passed.
Spec: docs/superpowers/specs/screens/photographer.md (S21), remaining-screens §3.7/§5–7, data-model/domain-model.md, marketplace-design §5; mock docs/design/ui-mock.html data-code="S21".

## Pre-flight scan
| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 self | creates lib/core/ulid.dart + test/core/ulid_test.dart | both already exist (fd52bb8) with the same API, core.dart already exports ulid → R3 |
| T1 self | platform test + Info.plist edit | user standing rule: iOS-only steps deferred to ios-enablement → R4 |
| T1 self | pub add image_picker firebase_storage | already in pubspec at 40aa98f → R1 |
| T2 self | "firebase_storage imported in one file only" | lib/main.dart imports it (emulator wiring, allowed by CLAUDE.md) → R5 |
| T2 self | create firebase/storage.rules (deny-all + posts) | file exists with users/{uid}/** rules → R6 |
| T2 self | firebase.json add storage | already present (rules + emulator 9199) → R6 |
| T1→T2 | PickedImage → MediaUploader.upload | consistent |
| T2→T5 | UploadEvent/UploadedMedia/FakeMediaUploader (failNames, maxConcurrent, deleteFailure) → composer tests | consistent |
| T3 self | imageUrls = download URLs; data-model README prefers storage_key | existing 3b1 post schema/read path uses imageUrls → R7 |
| T3→T4 | publisher doc keys vs validPostCreate hasOnly/hasAll | same 15 keys; imageMeta always written with matching length; consistent. photographers/{uid} portfolio write uses existing rules (no new validators there) |
| T3→T5 | PostDraft/FakePostPublisher(posts, clock, failWith, published) → composer | consistent; FakePostRepository.add exists, removeById added by T3 |
| T4 self | uses hasPhotographerRole(uid) helper | implementer checks it exists in firestore.rules; adds a helper only if absent |
| T5 self | consumes ServiceRepository.activeFor(uid,{limit}) / serviceRepositoryProvider / sharedPreferencesProvider / FakeAuthRepository.registerWithEmail / fixtureService | all exist |
| T5→T6 | postComposerProvider, myServicesProvider → screen | consistent |
| T6 self | consumes OptionRow, DiscoveryWorld (plan 3b4, not done) | → R8 |
| T7 self | HomeFeedController.pinToTop, home_screen chips, discovery_routes_test, FindPhotographerScreen (3b3/3b4, not done) | → R9 |
| T8 | moved | nothing to do |
| all | commit trailer "Claude Sonnet 5.5" | → R2 |
| T2,T4 | npm test (emulator) | → R10 |

Ruling: R1 Task 1 Step 1 `flutter pub add image_picker firebase_storage` skipped — deps added by controller on flutter-rewrite (40aa98f, image_picker 1.2.3; firebase_storage ^13.6.0 already there); step skipped — cost if wrong: none.
Ruling: R2 commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` instead of the plan's Sonnet 5.5 trailer — coordinator instruction — cost if wrong: cosmetic.
Ruling: R3 Task 1 keeps the existing lib/core/ulid.dart (same API, already exported) and merges the plan's ulid test cases into the existing test/core/ulid_test.dart without dropping existing cases — avoids clobbering another plan's file — cost if wrong: none (behaviour identical).
Ruling: R4 Info.plist NSPhotoLibraryUsageDescription edit and the iOS half of media_platform_config_test are skipped and appended to "Deferred iOS steps" in docs/superpowers/plans/2026-10-01-ios-enablement.md (exact key/string and test) — user standing rule in RUN-ORDER.md — cost if wrong: one plist entry + test added later.
Ruling: R5 the firebase_storage single-import test expects exactly {lib/data/media/firebase_media_uploader.dart, lib/main.dart} — main.dart's emulator wiring is allowed by CLAUDE.md — cost if wrong: none.
Ruling: R6 storage.rules is extended, not replaced: add `match /posts/{uid}/{postId}/{file}` (signed-in read; owner create/update for image/* ≤ 8 MiB; owner delete) beside the existing users/{uid}/** block and keep the deny-all fallback; firebase.json unchanged (storage already configured); rules-test package.json `--only firestore` → `--only firestore,storage`, initializeTestEnvironment gets the storage entry — coordinator instruction — cost if wrong: none.
Ruling: R7 posts keep `imageUrls` download URLs as the plan says, although data-model README prefers storage keys — the existing 3b1 post schema, reader and rules use imageUrls; switching needs a MediaUrlResolver out of scope — cost if wrong: a later migration of post image fields.
Ruling: R8 plans 3b3/3b4 are not done: Task 6 uses the existing core `AppOptionTile` instead of 3b4's `OptionRow`, and its tests use a small test-local world (test/support/create_post_world.dart) instead of 3b4's `DiscoveryWorld` — work the plan as far as the code base allows — cost if wrong: swap to OptionRow/DiscoveryWorld after 3b4 merges.
Ruling: R9 Task 7 is reduced to wiring the photographer branch of ActionTab to CreatePostScreen (onAddService → push '/setup/2'; onPublished → go(AppTab.home.path)) with a flow test landing on a stub Home route and a "Thêm gói" test; `HomeFeedController.pinToTop`, the Home chip sync, the home_controller tests and the discovery_routes_test change are deferred until 3b4 merges — they need 3b4's HomeFeedController/HomeScreen — cost if wrong: a follow-up task after 3b4, and a likely conflict in placeholder_tabs.dart with 3b4's customer branch.
Ruling: R10 rules emulator tests (npm test in firebase/rules-test) are written but not run — user standing rule, CI-only — cost if wrong: CI may fail on push and block deploy.

## Tasks
Task 1: ⚠️ image_picker version resolved by controller check: 1.2.3 (≥1.1) at 40aa98f.
Task 1: minor (deferred): PluginImagePicker has no unit test (plan-mandated); sizes read sequentially; long test name line; manifest read at top of main().
Task 1: complete (commits 40aa98f..e2e0250, review clean)
Task 2: rules tests written, not run (R10, CI-only).
Task 2: minor (deferred): FirebaseMediaUploader does not cancel the UploadTask when the stream subscription is cancelled (orphan risk if a later caller cancels mid-upload; plan-mandated code).
Task 2: minor (deferred): getDownloadURL failure after a successful put leaves the object (caller knows storagePath).
Task 2: minor (deferred): no exact-8 MiB rules test; untested non-owner overwrite, unauth delete, owner content-type change on update.
Task 2: minor (deferred): `image/.*` accepts image/svg+xml (same as existing validImage()).
Task 2: minor (deferred): FakeMediaUploader.deleteFailure not exercised in Task 2 tests (used by Task 5).
Task 2: complete (commits e2e0250..b5cbf9b, review clean)
Task 3: minor (deferred): imageMeta entries carry null blurHash/w/h (Task 4 rules must tolerate; they only check list size).
Task 3: minor (deferred): merge-set may create a partial photographers/{uid} doc (portfolio, updatedAt) — Task 4 must confirm existing rules allow it.
Task 3: minor (deferred): offline-deadline test is a source grep (plan-mandated).
Task 3: minor (deferred): post_publisher.dart imports fake_content_repositories for FakePostPublisher (plan-mandated).
Task 3: minor (deferred): no client-side 1–10 image guard in PostDraft (composer/rules enforce).
Task 3: complete (commits b5cbf9b..fcd2c0b, review clean)
Task 4: rules tests written, not run (R10, CI-only).
Ruling: R11 Task 4 review (Important, plan-mandated): a same-id retry after the 20 s timeout is an update and `allow update: if false` rejects it although the first write landed — keep the rules (no client updates), fix in FirestorePostPublisher: when commit fails (timeout or permission-denied), read posts/{id} from the server; if it exists with authorId == draft.photographerId, treat the publish as succeeded (return the PostSummary); otherwise rethrow; the server read failing (offline) rethrows the original error — the spec wants a retry that never duplicates and a retry that reports truthfully — cost if wrong: a retry after a landed first write that carried an edited caption reports success with the old caption.
Task 4: minor (deferred): element/shape types not checked (imageUrls strings / own Storage path, hashtags lower-case strings, imageMeta maps, specialty/style/location types).
Task 4: minor (deferred): "be yours" test uses a non-existent service id (same as missing case); no test forging photographerId alone; report's "unique uids" claim inaccurate (harmless).
Task 4: fix round 1/5 (1 addressed, 0 open — same-id retry after timeout rejected by update:false; fixed in publisher per R11; commits ad10896..ff5f1e9)
Task 4: minor (deferred): R11 tests do not cover the "server read fails" and "authorId mismatch" branches.
Task 4: complete (commits fcd2c0b..ff5f1e9, review clean)
Ruling: R12 Task 5 review — three plan-mandated Important findings are fixed, not parked: (1) composer must be tied to the signed-in uid (rebuild/reset on sign-out or account switch; never carry A's photos/draft to B); (2) publish must not upload a key that a retry is uploading (canPublish false while any image is uploading); (3) a photo cannot be removed while its upload is in flight (and an upload that completes for a key no longer in the form is deleted) — spec: one upload at a time, nothing orphaned, and per-user drafts — cost if wrong: small extra guards in the composer. Cheap minors folded in: inPortfolio counts in the "empty draft" check; setters and pick ignored while publishing; picker room recomputed after the await; prefs read before the publisher await.
Task 5: fix round 1/5 (3 addressed, 0 open — user switch reset, no double upload, no orphan on remove mid-upload; commits cfee1bd..b269805)
Task 5: minor (deferred): test "a photo cannot be removed while it uploads" exercises the publishing guard, not the uploading guard during retryImage nor the delete-on-completion path.
Task 5: minor (deferred): no test of a user switch while the composer is unwatched (paused listener).
Task 5: minor (deferred): catch (_) drops the cause (offline vs permission-denied indistinguishable); per-keystroke prefs writes; auth AsyncError resets form.
Task 5: minor (deferred): brief said 24 tests, it lists 22 (miscount, nothing dropped).
Task 5: complete (commits ff5f1e9..b269805, review clean)
Task 6: deviations (mock wins): place+style one row (stacked >1.15x), AppFooterBar footer, package field focus-ring border, "+" tile field colour; omitted "Bài đăng / Sự kiện" tabs (events plan) and back icon (tab root); ListView→SingleChildScrollView; extra string createServicesError.
Task 6: ⚠️ resolved by controller: portfolio switch is a default SwitchListTile; mock pill uses --cta colour — theme-level, deferred as minor.
Task 6: minor (deferred): 320/1.3x test does not render failed/uploading tiles (retry text may overlap up/down scrim at 1.3x); uploaded tick has no semantics/test; location maxLength 60 silent; AppColors.success constant and manual brightness branches; switch colour vs mock --cta pill.
Task 6: complete (commits b269805..ae8ffd6, review clean)
Resumed 2026-10-02 15:45 by a new controller (previous died ~14:13). Merged flutter-rewrite (plan 3b4: new HomeScreen, ActionTab -> FindPhotographerScreen for customers, photographer placeholder keeps ScreenCode createPost) into plan-3c as 418c26b; ARB conflict resolved by keeping both key blocks + gen-l10n; analyze clean, 1344 tests pass (excluding untracked Task 7 RED test create_post_flow_test.dart).
Ruling: Task 7 is re-briefed against the post-3b4 shell — photographer branch of ActionTab (lib/features/shell/placeholder_tabs.dart) becomes S21, customer branch stays FindPhotographerScreen; 'new post first on Home' targets the new HomeScreen/homeFeedProvider (lib/features/home/), not the deleted HomeTab — the plan predates 3b4 — cost: Task 7 code differs from plan text.
Task 7: dispatched (base 418c26b, implementer sonnet)
Task 7: minor (deferred): 4 minors in task-7-review.md (pinToTop concurrent-build race, silent return on reload failure, last-match loop, confirm Task 6 320dp test)
Task 7: complete (commits 418c26b..2b5916b, review clean)
Task 8: skipped (battery/performance moved to the final plan)
Final review: dispatched (40aa98f..2b5916b, opus)
Final review: needs fixes (2 Important: hidden-package draft keeps Đăng enabled; removing a photo after a timed-out publish deletes its Storage file). Fix wave dispatched (base 2b5916b, sonnet) with both + Firebase-isolation fix for create_post_providers, Home loadMore dedupe, 2 unused ARB keys.
Final review: fix wave 9af2dfc, re-review all 5 ADDRESSED; merged into flutter-rewrite (analyze clean, 1350 tests pass).
