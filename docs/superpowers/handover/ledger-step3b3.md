# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3b3-recommendations.md

Branch plan-3b3 from flutter-rewrite 4d84ae9. Worktree: /Users/tonyh/Documents/_project/Tool/booking/.claude/worktrees/agent-aa7e142d7d5513061
Setup: .flutter .home .android-sdk .pub-cache .certs .jdk symlinked from main checkout; app_flutter/.dart_tool copied; lib/firebase_options.dart (git-ignored) copied so analyze passes. .vscode/launch.json and .vscode/settings.json could not be written (sandbox) -> marked skip-worktree (merger: do not commit their deletion).
Verify: analyze --no-pub clean; test/core 364 passed.
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md §3e (reachable).

## Pre-flight scan
| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 -> T3,T4,T5 | recommendation_models.dart types + RecommendationRepository port; dayKeyOf | consistent with T3/T4/T5 usage |
| T2 -> T3,T4,T5 | DayAvailability, AvailabilityLookup, FakeAvailabilityLookup(set/requested/failWith), FirestoreAvailabilityLookup | consistent |
| T3 -> T4 | LocalRecommender ctor, recommendation_contract.dart (contractWorld, recommendationRepositoryContract) | T4 test imports contract from T3; consistent |
| T3 -> T5 | LocalRecommender(clock:, strings: optional) | consistent |
| T2 vs existing code | firestore.rules already has match /availability/{uid}/days/{dayKey} (2d1: read signedIn, owner create/delete off) | see ruling on Task 2 rules |
| T1 self | tests vs code | consistent (copyWith clearCursor present) |
| T2 self | tests vs code | consistent |
| T3 self | test `final _hcm6 = encodeGeohash(...)` used inside `const RecommendationQuery(geohash6: _hcm6)` | compile error; ruling below |
| T4 self | tests vs code | consistent |
| T5 self | tests vs code | consistent |
| T6 | moved to final battery plan | skip |
| Prereqs | fixtures (fixturePhotographer/fixturePost/fixtureNow params), formatDay/Distance/Rating, specialtyLabel, encode/decodeGeohash, haversineKm, vnDateKey, parseDayKey, clampPageSize, clockProvider, content providers | all present |

Ruling: commit trailer is `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, not the plan's Sonnet line — controller instruction overrides plan — cost: cosmetic.
Ruling: Task 2 keeps the existing 2d1 `availability/{uid}/days/{dayKey}` rule block unchanged (it already has `allow read: if signedIn()` and owner-only off writes, which the plan explicitly allows); rules tests: add the plan's two tests only where existing rules.test.mjs coverage does not already assert them; rules tests are never run (CI-only) — cost: possible duplicate/missing rules test, CI catches.
Ruling: Task 3 test drops `const` on the RecommendationQuery expressions that use the non-const `_hcm6` (keep the computed geohash, as the plan intends) — plan text does not compile otherwise — cost: none.
Ruling: DayAvailability (port enum, no `free`) stays separate from core `DayState` (UI enum with `free`) — plan interfaces and tests name it; semantics differ (absent = free) — cost: two similar enums.
Ruling: Tasks 4 and 5 go to one implementer dispatch (two commits) and one review — both small transcription tasks on the same folder — cost: a slightly larger review surface.
Ruling: Task 6 and the File Structure row `test/battery/recommendation_battery_test.dart` are skipped — moved to 2026-10-02-final-battery-performance.md per plan header — cost: none.
Skip: rules emulator tests (`npm test` in firebase/rules-test) for Task 2 — CI-only per plan header and controller.

## Tasks
Task 1: implementer (sonnet) DONE, commit 00c8153 (BASE 4d84ae9); reviewer (sonnet) dispatched.
Ruling: Task 2 implementer dispatched while Task 1 review runs (review is read-only; any Task 1 fix waits until Task 2's implementer reports, so never two implementers at once) — saves a wait — cost: a Task 1 fix lands after Task 2's commit.
Task 2: implementer (sonnet) dispatched, BASE 00c8153.
Task 1: review: spec OK, Approved; the three ⚠️ items were resolved by the controller (trailer is Opus 5.5; content imports exist; test evidence is in the report).
Task 1: minor (deferred): copyWith cannot clear specialtyId/styleId/date/geohash6/budgetMax (only cursor), and S04 filter chips may need that.
Task 1: minor (deferred): RecommendationQuery.date equality compares the UTC flag, so utc and local values of the same calendar date are unequal keys.
Task 1: minor (deferred): PostRecommendationQuery has no ==/hashCode/copyWith, and needs them if it becomes a provider family key.
Task 1: complete (commits 4d84ae9..00c8153, review clean)
Task 2: implementer DONE, commit a8b3319 (BASE 00c8153). firestore.rules untouched; one rules test added (signed-in read of a missing day), the others were already covered. Rules tests not run (CI-only). Reviewer (sonnet) dispatched.
Task 3: implementer (sonnet) dispatched, BASE a8b3319 (Task 2 review runs in parallel, read-only).
Task 2: review: spec OK, Approved. Controller resolved the ⚠️ items: the rules block has `allow read: if signedIn()` (firestore.rules:358-359, read in preflight); `dayPath` is defined at rules.test.mjs:654.
Task 2: minor (deferred): the fake's `requested` keeps the caller's duplicate ids while its result de-duplicates; the 'booked' arm in the Firestore _state switch is redundant; the adapter has no class doc comment.
Task 2: complete (commits 00c8153..a8b3319, review clean)
Task 3: implementer NEEDS_CONTEXT: the brief's test "with a date at most 60 day documents are read" fails because quality saturates at 1.0 (completed 112 by default), so c037..c099 tie and the id tie-break keeps c037..c096.
Ruling: Task 3 pre-cut sort (date given, before the 60 cap) breaks quality ties by smoothedRating desc, then reviewCount desc, then id; the test stays as written and the final ranking is unchanged — the spec intent is "best quality first, most reviewed kept", and an id tie-break among saturated candidates is arbitrary — cost: a small deviation from the plan's literal code that step 3r's server need not mirror.
Ruling: Task 3 `nullsLast<T extends num>` instead of `T extends Comparable<T>` (the latter does not compile for int/double) — compile fix — cost: none.
Task 3: implementer resumed with the rulings.
Task 3: implementer DONE, commit 68716d0 (BASE a8b3319); full suite 1139 passed; analyze clean.
Ruling: Task 3 keeps the public named ctor params and puts targeted `// ignore: prefer_initializing_formals` on 3 private-field initialisers — a named parameter cannot be private, so the lint cannot be satisfied without changing the plan's signature — cost: three ignore comments.
Task 3: reviewer (opus, logic-heavy) dispatched.
Tasks 4+5: implementer (sonnet, batched) dispatched, BASE 68716d0.
Task 3: review (opus): spec OK, Approved. Controller resolved the ⚠️ items: formatDay (core/format.dart:58-61) and dayKeyOf both read the calendar fields only, so they agree. The report has no red output for the initial run, but the NEEDS_CONTEXT round documented a failing test before the fix; accepted.
Task 3: minor (deferred): a malformed or empty geohash6 makes _origin/decodeGeohash throw ArgumentError (or decode to 0,0), which breaks the "always works" fallback. The final review should triage this one.
Task 3: minor (deferred): _freeSoon(days:14) is evaluated up to three times per post in recommendPosts, and an IIFE sits inside the collection-for.
Task 3: minor (deferred): _requestId is only microsecond-unique (identical under the fixed test clock), so it needs a counter or random suffix before step 3r ties signals to requestId.
Task 3: minor (deferred): path-echo header comments (`// lib/...`) are left at the top of local_recommender.dart and both test files.
Task 3: complete (commits a8b3319..68716d0, review clean)
Tasks 4+5: implementer DONE, commits d06f9dd (T4) and 805f687 (T5); full suite 1158 passed; analyze clean. Reviewer (sonnet) dispatched on 68716d0..805f687.
Tasks 4+5: review: spec OK, Approved. Controller resolved the ⚠️ items: every branch commit has the Opus 5.5 trailer; markFallback keeps the fallback page's own algorithm ('local-fallback'); the providers exist (preflight).
Task 4: minor (deferred): the "feedback never waits for a slow server" test has no elapsed-time bound; there are no tests for feedback through a working primary or for a fallback that throws; catch (_) also swallows programming Errors from the primary (consider debug logging in 3r).
Task 5: minor (deferred): an unoverridden availabilityLookupProvider builds FirestoreAvailabilityLookup lazily, so screen tests added later must override it.
Task 4: complete (commits 68716d0..d06f9dd, review clean)
Task 5: complete (commits d06f9dd..805f687, review clean)
Task 6: skipped (moved to the final battery plan).

## Final review (opus) on 4d84ae9..805f687: With fixes
Important 1: with a date, the 60-candidate cut is by quality only and ignores distance and the sort, so nearby or cheap photographers drop out once more than 60 match (a plan defect).
Ruling: fix the final-review Important 1 now. The dated cut uses the requested sort's comparator over a pre-availability key (best = 0.5q + 0.3geo; near/price/rating use their own key, then that); the final ranking is unchanged — a user-visible ranking defect, cheap to fix locally — cost: a deviation from the plan's literal code.
Ruling: also fix these in the same wave: Minor 1 (move the score-monotonicity check out of the contract into the local tests, since spec 3e.6 MMR may re-order), Minor 2 (pin that an availability failure propagates, plus a doc line), Minor 3 (similar clamps at 20 per openapi.yaml:48), Minor 5 (nextFreeDate null-guard), Minor 6 (replace the tautological ReasonCode check), Minor 4 (doc only: post ranks are per page), and the T3 deferred geohash6 guard (the fallback is the last line of defence, spec 3e.1) — all small and local to one file — cost: a slightly larger fix diff.
Ruling: the remaining deferred minors stay deferred as the final review triaged them (copyWith clear flags, date normalisation and PostRecommendationQuery equality go to the S04/Home plans; requestId uniqueness and the resilient-wrapper test gaps go to 3r; the provider override pattern matches the existing providers) — each has a named consumer plan — cost: those plans must pick them up.
Final fix wave: one implementer (sonnet) dispatched with final-fix-brief.md, FIX_BASE 805f687.
Final fix wave: DONE_WITH_CONCERNS, commit 2096d52; full suite 1163 passed; analyze clean.
Ruling: the F5 malformed-date fixture is '2026-10-03x' instead of the brief's '2026-10-0x' — the brief's value never reached the crash path, and the new one does — cost: none.
Final fix wave: scoped re-review (opus) dispatched on 805f687..2096d52.
Final fix wave: re-review (opus): F1–F8 all ADDRESSED, no new breakage.
Final: minor (deferred): no test pins a far high-quality photographer being dropped for a near average one in the dated best cut; _distance is computed twice for dated candidates; the F3 test should use await expectLater.

## SUMMARY
Branch: plan-3b3 (from flutter-rewrite 4d84ae9). Commits 4d84ae9..2096d52 (6):
00c8153 T1 models/port; a8b3319 T2 AvailabilityLookup; 68716d0 T3 LocalRecommender + contract; d06f9dd T4 resilient wrapper; 805f687 T5 providers; 2096d52 final-review fixes.
Tests (controller-verified at 2096d52): flutter analyze --no-pub clean; flutter test --no-pub 1163/1163 passed. Rules emulator tests not run (CI-only); Task 6 battery skipped (moved to the final battery plan).
Merger notes: .vscode/launch.json and .vscode/settings.json are marked skip-worktree in this worktree (do not commit their deletion). lib/firebase_options.dart was copied (ignored file). Files likely to conflict: app_flutter/lib/l10n/app_vi.arb and the generated app_localizations*.dart (6 reason* keys appended), lib/core/vn_time.dart (+dayKeyOf), firebase/rules-test/rules.test.mjs (+1 availability test).

Rulings (14):
- Ruling: commit trailer is `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, not the plan's Sonnet line — controller instruction overrides plan — cost: cosmetic.
- Ruling: Task 2 keeps the existing 2d1 `availability/{uid}/days/{dayKey}` rule block unchanged (it already has `allow read: if signedIn()` and owner-only off writes, which the plan explicitly allows); rules tests: add the plan's two tests only where existing rules.test.mjs coverage does not already assert them; rules tests are never run (CI-only) — cost: possible duplicate/missing rules test, CI catches.
- Ruling: Task 3 test drops `const` on the RecommendationQuery expressions that use the non-const `_hcm6` (keep the computed geohash, as the plan intends) — plan text does not compile otherwise — cost: none.
- Ruling: DayAvailability (port enum, no `free`) stays separate from core `DayState` (UI enum with `free`) — plan interfaces and tests name it; semantics differ (absent = free) — cost: two similar enums.
- Ruling: Tasks 4 and 5 go to one implementer dispatch (two commits) and one review — both small transcription tasks on the same folder — cost: a slightly larger review surface.
- Ruling: Task 6 and the File Structure row `test/battery/recommendation_battery_test.dart` are skipped — moved to 2026-10-02-final-battery-performance.md per plan header — cost: none.
- Ruling: Task 2 implementer dispatched while Task 1 review runs (review is read-only; any Task 1 fix waits until Task 2's implementer reports, so never two implementers at once) — saves a wait — cost: a Task 1 fix lands after Task 2's commit.
- Ruling: Task 3 pre-cut sort (date given, before the 60 cap) breaks quality ties by smoothedRating desc, then reviewCount desc, then id; the test stays as written and the final ranking is unchanged — the spec intent is "best quality first, most reviewed kept", and an id tie-break among saturated candidates is arbitrary — cost: a small deviation from the plan's literal code that step 3r's server need not mirror.
- Ruling: Task 3 `nullsLast<T extends num>` instead of `T extends Comparable<T>` (the latter does not compile for int/double) — compile fix — cost: none.
- Ruling: Task 3 keeps the public named ctor params and puts targeted `// ignore: prefer_initializing_formals` on 3 private-field initialisers — a named parameter cannot be private, so the lint cannot be satisfied without changing the plan's signature — cost: three ignore comments.
- Ruling: fix the final-review Important 1 now. The dated cut uses the requested sort's comparator over a pre-availability key (best = 0.5q + 0.3geo; near/price/rating use their own key, then that); the final ranking is unchanged — a user-visible ranking defect, cheap to fix locally — cost: a deviation from the plan's literal code.
- Ruling: also fix these in the same wave: Minor 1 (move the score-monotonicity check out of the contract into the local tests, since spec 3e.6 MMR may re-order), Minor 2 (pin that an availability failure propagates, plus a doc line), Minor 3 (similar clamps at 20 per openapi.yaml:48), Minor 5 (nextFreeDate null-guard), Minor 6 (replace the tautological ReasonCode check), Minor 4 (doc only: post ranks are per page), and the T3 deferred geohash6 guard (the fallback is the last line of defence, spec 3e.1) — all small and local to one file — cost: a slightly larger fix diff.
- Ruling: the remaining deferred minors stay deferred as the final review triaged them (copyWith clear flags, date normalisation and PostRecommendationQuery equality go to the S04/Home plans; requestId uniqueness and the resilient-wrapper test gaps go to 3r; the provider override pattern matches the existing providers) — each has a named consumer plan — cost: those plans must pick them up.
- Ruling: the F5 malformed-date fixture is '2026-10-03x' instead of the brief's '2026-10-0x' — the brief's value never reached the crash path, and the new one does — cost: none.

Deferred minors:
- Task 1: minor (deferred): copyWith cannot clear specialtyId/styleId/date/geohash6/budgetMax (only cursor), and S04 filter chips may need that.
- Task 1: minor (deferred): RecommendationQuery.date equality compares the UTC flag, so utc and local values of the same calendar date are unequal keys.
- Task 1: minor (deferred): PostRecommendationQuery has no ==/hashCode/copyWith, and needs them if it becomes a provider family key.
- Task 2: minor (deferred): the fake's `requested` keeps the caller's duplicate ids while its result de-duplicates; the 'booked' arm in the Firestore _state switch is redundant; the adapter has no class doc comment.
- Task 3: minor (deferred): a malformed or empty geohash6 makes _origin/decodeGeohash throw ArgumentError (or decode to 0,0), which breaks the "always works" fallback. The final review should triage this one.
- Task 3: minor (deferred): _freeSoon(days:14) is evaluated up to three times per post in recommendPosts, and an IIFE sits inside the collection-for.
- Task 3: minor (deferred): _requestId is only microsecond-unique (identical under the fixed test clock), so it needs a counter or random suffix before step 3r ties signals to requestId.
- Task 3: minor (deferred): path-echo header comments (`// lib/...`) are left at the top of local_recommender.dart and both test files.
- Task 4: minor (deferred): the "feedback never waits for a slow server" test has no elapsed-time bound; there are no tests for feedback through a working primary or for a fallback that throws; catch (_) also swallows programming Errors from the primary (consider debug logging in 3r).
- Task 5: minor (deferred): an unoverridden availabilityLookupProvider builds FirestoreAvailabilityLookup lazily, so screen tests added later must override it.
- Final: minor (deferred): no test pins a far high-quality photographer being dropped for a near average one in the dated best cut; _distance is computed twice for dated candidates; the F3 test should use await expectLater.
