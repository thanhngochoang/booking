# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step2d2-photographer-profile.md

Branch plan-2d2 from flutter-rewrite 503c846 (3b4 + 3c merged). Toolchain dirs symlinked, .dart_tool and lib/firebase_options.dart copied (never committed). Baseline: analyze clean.
Ruling: commits end with Co-Authored-By: Claude Opus 5.5 — user/harness instruction — cost: trailer string.
Ruling: Task 8 and every battery/idle/blur-budget step skipped (final plan); rules emulator tests not run (CI) — plan header + user — cost: checks happen later.
Ruling: workspace ledger copied to docs/superpowers/handover/ledger-step2d2.md at the end — same as previous plans — cost: none.
Preflight: dispatched (opus).
## Pre-flight scan: 28 findings F1–F28, table in preflight.md. Rulings (controller adopts every proposed ruling; full why/cost per row in preflight.md):
Ruling: F1 T6 imports imagePickerProvider/mediaUploaderProvider from data/media/media_providers.dart — 3c moved them there — cost: none.
Ruling: F2 T7 skips the avatar swap; ProfileTab already uses AppAvatar lg — repo state — cost: none.
Ruling: F3 T7 rows (phone, skills + meter, public profile) go into S31 SettingsScreen "Tài khoản" card, not S30; S30 untouched; tests move to settings_test (Divider count updated) — mock 4be8d89 + account.md S31 — cost: rows move if the user wanted them on S30.
Ruling: F22 T7 strings settingsPhone/settingsPhoneEmpty ("Chưa thêm"), phone row shows last 4 digits; others settingsSkills*/settingsPublicProfile* — spec names — cost: key names.
Ruling: F4 photographer_world only adds picker/uploader overrides; screenRouterApp already supplies photo scope and retry — repo — cost: none.
Ruling: F5 no /u/:uid/book or /ask routes in 2d2 (step 4 adds them as child routes); until then those taps hit the go_router error page in dev — scope — cost: dead taps until step 4.
Ruling: F6/F25 honour 3b4 links to /u/:uid and ?tab=services; add /u/:uid to discovery_routes_test — 3b4 contract — cost: none.
Ruling: F7 avatars at avatars/{uid}/{ulid}.jpg, 5 MB limit; fix the storage comment claiming users/{uid} — plan + data-model §2.6 — cost: none.
Ruling: F8 ProfileBottomBar uses AppFooterBar (mock .foot) — shared component — cost: none.
Ruling: F9 follow button AppButton.outline size xsmall (mock "btn out xs") — mock — cost: none.
Ruling: F10/F11 AppRadius.card instead of raw 20; S03 header avatar AppAvatarSize.lg (64) — tokens + mock — cost: none.
Ruling: F12/F13 no share icon, no masonry (no new package); fixed square 2-column grid; report as deviations — no-new-deps — cost: visual difference from mock.
Ruling: F14/F15 keep skill tags (in the hidden badge row slot), equipment line, "4,9", "~1 giờ"; flag to user as mock differences — spec behaviour — cost: mock update by user.
Ruling: F16/F26 keep PhotographerContactAction with its autoDispose listener while S03 shows; accept 3 reads of the same photographer doc; exception noted for the battery plan — correctness over micro-optimisation — cost: extra reads.
Ruling: F17 AvatarEditor = centred column (avatar lg, small outline button key change-avatar), mock S42; "Lưu" stays the only primary — mock + one-primary rule — cost: none.
Ruling: F18/F20 portfolio from byPhotographer as is (includes customers' real_shoot posts tagged with the photographer); local "similar" query until plan 3r — spec — cost: revisit if work-only portfolio wanted.
Ruling: F19 T4 tests pump const SizedBox() before a second ProfileWorld in the same test — repo precedent — cost: none.
Ruling: F21 keep NetworkImage for the blurred backdrop; on error only the aurora shows — simplicity — cost: none.
Ruling: F23 if S24 tests miss taps after the avatar row, adjust tests (ensureVisible/taller view), never drop the avatar — spec — cost: test edits.
Ruling: F24/F27/F28 controller marks S03 built after merge and adds avatarPath to relational-schema mapping; ReviewsSliver keeps the no-arg form; owner via ref.read accepted — repo — cost: none.
Task 1: dispatched (base 503c846, implementer sonnet)
Task 1: minor (deferred): no load-error test; test hard-codes 390 width; no unbounded-height guard
Task 1: complete (commits 503c846..faa3726, review clean)
Task 2: dispatched (base faa3726, implementer sonnet)
Task 2: complete (commits faa3726..c91d0a2, review clean)
Task 3: dispatched (base c91d0a2, implementer sonnet)
Task 3: ⚠️ resolved by controller: trailer is Opus 5.5; byPhotographer/activeFor signatures compile (analyze clean).
Task 3: minor (deferred): see task-3-review.md
Task 3: complete (commits c91d0a2..661a19a, review clean)
Task 4: dispatched (base 661a19a, implementer sonnet)
Task 4: minor (deferred): owner returning from an edit route sees a skeleton flash (AsyncLoading with previous value falls to _Loading), loses scroll + calendar month (photographer_profile_screen.dart:170-185).
Task 4: Ruling: reviewer's follow-up (photographerProfileProvider without retry: null may sit on the skeleton through Riverpod default retries) is app-wide — no lib provider sets retry; tests pass retry null by convention — treated as a deferred minor for the final review — cost: a real load error shows the skeleton a few seconds before the error state.
Task 4: complete (commits 661a19a..ae3976f, review clean)
Task 5: dispatched (base ae3976f, implementer sonnet)
Task 5: rules emulator tests not run (CI); rules judged by reading.
Task 5: complete (commits ae3976f..22b7306, review clean)
Task 6: dispatched (base 22b7306, implementer sonnet)
Task 6: minor (deferred): pickImages outside AsyncValue.guard (avatar_controller.dart:22) → picker error unhandled, no snackbar (plan-mandated code; final review to triage); import-order nit; thin 320dp coverage.
Task 6: complete (commits 22b7306..8ee1f89, review clean)
Task 7: dispatched (base 8ee1f89, implementer sonnet)
Task 7: minor (deferred): 'reload skills on return' test asserts nothing (greaterThanOrEqualTo(before)); '•••• ' hard-coded outside arb; no 320dp/1.3x photographer test; short-phone edge in last-4 logic.
Task 7: complete (commits 8ee1f89..94ef3ad, review clean)
Task 8: skipped (battery/performance moved)
Final review: dispatched (503c846..94ef3ad, opus)
Ruling: the Task 4 retry ruling is overturned — its premise (no lib provider sets retry) was false; S03's profile/packages/portfolio providers get retry: (_, _) => null like the skills providers — spec error state must show — cost: none. Final review: needs fixes (2 Important: retry; avatar change lost when S42 disposes mid-upload). Fix wave dispatched (base 94ef3ad, sonnet) incl. picker inside guard, '•••• ' into arb, the no-op skills reload test.
Final review: fix wave e2cd01b, re-review all 4 ADDRESSED; merged into flutter-rewrite (analyze clean, 1390 tests pass).
