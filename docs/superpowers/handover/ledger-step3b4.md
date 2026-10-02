# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3b4-home-detail-find.md

Branch plan-3b4 from d8e49c1 (flutter-rewrite tip: 2c, backend-phase1, 2d1, 3b3 merged).
Setup: .flutter .home .android-sdk .pub-cache .certs symlinked from main checkout; app_flutter/.dart_tool copied; lib/firebase_options.dart (git-ignored) copied, never committed. .vscode/launch.json and .vscode/settings.json could not be written (sandbox) -> marked skip-worktree (merger: do not commit their deletion). Baseline: analyze clean, test/core 365 passing.
Spec: docs/superpowers/specs/screens/discovery.md (S01, S02, S04) + remaining-screens §3b.1, §3e.9, §5-7; mock docs/design/ui-mock.html.

Ruling: commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, not the plan's "Claude Sonnet 5.5" — controller instruction from the user overrides the plan text — cost if wrong: a trailer string.
Ruling: Task 6 (battery/performance) and every battery/blur-budget/idle step inside tasks are skipped (moved to the final battery plan per the plan header); emulator/rules tests are not run (CI-only); device steps skipped — per user instruction — cost: those checks happen later.
Ruling: the workspace (this ledger) is kept after the final review instead of deleted — the user asked for the ledger path in the final reply — cost: a git-ignored directory to remove later.

## Pre-flight scan (full detail: preflight.md in this workspace)
| Row | Producer -> consumer / task | Finding |
|---|---|---|
| T1 self | engagement, book entry, meta, world | consistent; risk: currentContactProvider is autoDispose (.future read) |
| T2 self | S01 | PhotoPill dot is enum; tests at default 800x600 break; _selected vs non-autoDispose feed; loadMore race after selectCategory; count 17 not 18 |
| T3 self | S02 | tests at 800 wide break; button height 52 vs 48; count 16 not 17 |
| T4 self | S04 | tests at 800 wide = 2 columns; "Ẩm thực" off-screen in sheet; chips beyond right edge; loadMore race after filter change |
| T5 self | routes | drops S21 ScreenCode and tab-root title style on photographer placeholder |
| T1->T2,3,4 | discovery_world, engagement/follow, startBooking, meta | signatures agree; engagement/follow not reset on user switch |
| T2->T3 | photoSave/photoUnsave l10n | defined in T2, used in T3: keep order |
| T2->T4 | Delegating/ThrowingRecommender in discovery_world | T4 after T2 |
| T3->T5, T4->T5, T2->T5 | screens -> routes/ActionTab | agree |
| T5->all | responsive_test HomeTab entry | only that entry |
| 3b3 deferred | RecommendationQuery copyWith/date, PostRecommendationQuery == | plan never uses copyWith nor compares queries |

Ruling: every screen test sets a phone-sized view (e.g. tester.view.physicalSize 390 x tall, dpr 1, reset in tearDown) in its _pump/_open helper, keeping the explicit 320/600/900 layout tests — repo convention, the plan's default 800x600 makes the asserts wrong — cost: none beyond test edits.
Ruling: PhotoPill(dot: PhotoPillDot.ok); AppButton heights asserted as 48 (controlHeight); every ProviderContainer in tests gets retry: (_, _) => null — real repo API/convention — cost: none.
Ruling: S04 tab root and the photographer ActionTab placeholder use centerTitle false + tabRootTitleStyle; the photographer placeholder keeps its ScreenCode(ScreenCodes.createPost); S01 title uses tabRootTitleStyle — CLAUDE.md theme rule + mock — cost: none.
Ruling: S04 sheets use the existing AppOptionTile, not a new OptionRow (Task 4 drops option_row.dart, its test and export) — spec shared-components names AppOptionTile for single-choice rows — cost: if the user wanted a distinct sheet row, re-add later.
Ruling: S04 date sheet uses the existing AvailabilityCalendar (no per-photographer states) instead of CalendarDatePicker; dates normalised to local midnight in setDate — spec S04 names AvailabilityCalendar, avoids the CalendarDatePicker firstDate assert; covers the 3b3 date-normalisation item for this plan — cost: calendar visuals may need tuning.
Ruling: 3b3 deferred items (a) RecommendationQuery.copyWith clear flags and (c) PostRecommendationQuery ==/hashCode stay deferred — this plan builds queries by constructor and never compares them — cost: a later plan that uses copyWith/family keys must add them.
Ruling: startBooking keeps pushing the /profile/phone?returnTo= route (not showAddPhoneSheet) — plan + its test; route keeps the caller under it — cost: presentation differs from the S33 sheet; swap is local to book_entry.dart. If reading currentContactProvider.future (autoDispose) is flaky, the implementer holds a listen subscription while awaiting.
Ruling: S02 follow button uses AppButtonSize.xsmall; S02 bottom bar wraps in AppFooterBar; raw Colors.black/white -> AppColors tokens (overlay, foregroundInverse); AppRadius.lg+8 -> AppRadius.card; named constants for repeated numbers — existing widgets/tokens, CLAUDE.md no-magic-numbers — cost: none.
Ruling: formatDuration takes AppLocalizations (ARB keys for phút/giờ) — no hard-coded UI text — cost: signature differs from plan text.
Ruling: S01 large card follows the mock: avatar + name (tick) + meta sit inside the photo overlay (keyed author-<id>, opens S03), save disc top-right, two pills; ReasonChips stay under the card (spec). Implementer may add one optional widget slot to PhotoCard if needed — mock is layout authority — cost: a PhotoCard API addition.
Ruling: S02 author meta follows the mock ("<specialty> · <area> · ★ x (n)", no sessions); S02 package card gets the service thumbnail (coverUrl) next to name/meta/price; meta keeps the fields that exist (photos, delivery, duration) — mock authority, data has no location count — cost: copy differs slightly from mock.
Ruling: S04 keeps the sort-chip row and the fallback note though the mock lacks them, and keeps the spec count string with the date ("rảnh T7 03/10") — spec behaviour; the mock is silent rather than contradictory and I may not edit the mock — cost: the mock should be updated by the user to show them (flagged for merge). Area chip drops the pin icon (mock) and shows "· N km" only if a radius is available.
Ruling: engagementProvider, followProvider and homeFeedProvider reset when the signed-in uid changes; Home initialises its selected chip from the provider; loadMore in Home and Find drops a result whose category/filters no longer match the current state — privacy across users and correctness — cost: small extra code.
Ruling: S02 "Thêm của" may include the photographer's real-shoot posts (as the plan's test expects) — spec says "other posts of the photographer" — cost: revisit if the user wants work posts only.
Ruling: S01 bell/chat icons and S02 share/report are not built (plan) — no backend yet — cost: mock shows them; flagged for the user.
Task 1: dispatched (base d8e49c1, implementer sonnet)
Resumed 2026-10-02 14:45 by a new controller session (previous controller pid 6464 dead). Task 1 left uncommitted partial work (discovery/, l10n, test/support/discovery_world.dart); re-dispatched to a fresh implementer to verify and finish it. BASE d8e49c1.
Task 1: re-dispatched (base d8e49c1, implementer sonnet, agent a43fa879a4f896e56)
Task 1: minor (deferred): 5 minors in task-1-review.md (main: failed toggle revert after a uid change can re-insert the previous user's entry)
Task 1: complete (commits d8e49c1..6b5ef7f, review clean)
Task 2: dispatched (base 6b5ef7f, implementer sonnet)
Ruling: S01 save disc sits where the mock puts it (PhotoCard action, bottom-right of the overlay row), superseding the earlier 'top-right' ruling — mock is layout authority, top-right holds the trailing pill — cost: move one widget if the mock reading is wrong.
Ruling: S01 greeting/title/chips form a fixed header outside the CustomScrollView so each chip keeps its feed scroll position — spec behaviour needs it — cost: header does not scroll away on small screens.
Task 2: minor (deferred): 6 minors in task-2-review.md (real-shoots grid is max-extent so 3-4 columns on wide screens vs brief's 2; two benign transient races: quick chip taps, loadMore during category reload)
Task 2: Ruling: reviewer's unverifiable item (whether AsyncLoading keeps the previous value) treated as minor — reviewer says it only affects a benign transient race, the generation counter guards stale reloads — cost: a brief flash of loading on a fast chip switch.
Task 2: complete (commits 6b5ef7f..7061517, review clean)
Task 3: dispatched (base 7061517, implementer sonnet)
Task 3: minor (deferred): 6 minors in task-3-review.md (real-shoot line 'gói ' with empty service name; no tests for controller partial-failure branches)
Task 3: ⚠️ items resolved: route wiring is Task 5; S03 ?tab=services handling belongs to plan 2d2 (S03 not built yet).
Task 3: complete (commits 7061517..f78e8fa, review clean)
Task 4: dispatched (base f78e8fa, implementer sonnet)
Task 4: fix round 1/5 (1 addressed, 0 open — short filtered first page could not page; commits ca7cac0..9d0a2c5)
Task 4: minor (deferred): see task-4-review.md minors; implementer concerns: filter chips scroll with the list (as brief), findFiltersProvider outlives the screen so old filters persist when arriving via 'Xem tất cả'; mock lacks sort row + fallback note (user to update mock)
Task 4: complete (commits f78e8fa..9d0a2c5, review clean)
Task 5: dispatched (base 9d0a2c5, implementer sonnet)
Task 5: minor (deferred): unused l10n keys emptyHomeTitle/Body, emptyFindTitle/Body; route tests check paths only
Task 5: complete (commits 9d0a2c5..de81900, review clean)
Task 6: skipped (battery/performance moved to the final plan, per ruling)
Final review: dispatched (d8e49c1..de81900, opus)
Final review: needs fixes (1 Important: S04 _fillViewport/loadMore during reload overwrite fresh results). Fix wave dispatched (base de81900, sonnet) with the Important + 5 recommended cheap fixes.
Final review: fix wave 722286b, re-review all 6 ADDRESSED; merged into flutter-rewrite (analyze clean, 1269 tests pass).
