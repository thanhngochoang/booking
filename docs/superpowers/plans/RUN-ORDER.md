# Run order of the implementation plans

Agreed with the user on 2026-10-02. Run the plans top to bottom with subagent-driven development; a plan starts only when every plan above it is done, except plans 8a2–8e, which run in the two lanes below. Screen status lives in the code table of `docs/superpowers/specs/2026-10-01-remaining-screens.md` (column "Trạng thái"); update it when a plan finishes.

Standing rules (user, 2026-10-02):
- The UI matches the committed mock `docs/design/ui-mock.html`; the specs decide behaviour.
- No battery/performance task or test steps inside feature plans; all of it runs once in plan 16.
- No device build or Genymotion install after each plan; it happens once, in plan 16.
- iOS-only steps are skipped in feature plans and appended to "Deferred iOS steps" in plan 15.
- Every screen shows its code (`ScreenCode`) in debug builds.
- Firestore/Storage rules tests on the emulator (`firebase/rules-test`) are not run while executing plans; rules and their tests are still written, CI runs them on push (banner at the top of each plan). Backend phase 1's own emulator-suite work is not affected.

## Two parallel lanes (user, 2026-10-02)

Plans 8a2 and 8b–8e run on two machines at once. The split was made from a file-by-file map of every remaining plan. Each lane owns its files; the few files both lanes touch are append-only and listed at the end.

**Branches (updated 2026-10-03):** `develop` is the protected integration branch; changes land only through PRs into it. Each unit (a row below, or one lane step `<#>/<step>-L<lane>`) gets its own branch `plan/<id>-<slug>` from `origin/develop` and a PR back into `develop`. Which machine holds which unit is tracked on the `board` branch (`CLAIMS.md`), written only by `.claude/skills/run-next-plan/scripts/board.py`; the `run-next-plan` skill picks, claims and runs the next unit. The fixed `lane/ui` / `lane/core` branches from `flutter-rewrite` are retired; the ownership split below still applies. Never push to `main`.

**Ledgers:** SDD ledgers get the lane in the name, `.superpowers/sdd/<plan>/progress-lane1.md` and `progress-lane2.md`, because the same plan can be executed by both lanes (A, 4b–4e).

**Backend:** each machine runs its own `../scripts/backend-local.sh` (own emulators and seed).

| Step | Lane 1 · `lane/ui` (screens) | Lane 2 · `lane/core` (core widgets, server, data) | Gate after the step |
|---|---|---|---|
| 1 | A Tasks 1–3 (SignatureLoader, skeletons, AsyncView, source rules test skipped) | waits for G1 | **G1:** lane 1 merges A1–3 |
| 2 | A Task 4 (migrate the existing screens to AsyncView; the source rules test turns on) | A Tasks 5, 6 (Steps 1–5 only), 7, 8, 9 (new files in `lib/core/widgets/`, `lib/core/payments.dart`, `lib/data/booking/booking_summary.dart`; `showAppSheet` hook if needed) | **G2:** lane 2 merges A5–9 |
| 3 | A Task 6 Step 6 (feature confirmation sheets → `showConfirmSheet`; needs G2) | 4b Task 1 (contract check, `expectedPrice` in domain + callable, booking data additions, `AppSheetFrame`, payments mode), then A Task 10 (gallery + spec) | **G3:** lane 2 merges 4b T1 |
| 4 | 4b Tasks 2–8 (S04.01–S04.04; needs G3) | 4c Task 1 (events read rule, `booking_features.dart`, ticker) | **G4:** lane 2 merges 4c T1 |
| 5 | 4c Tasks 2–7 (S05.01–S05.03, S06.01–S06.03; needs G4) | 4d Tasks 1–6 (chat domain, Functions, rules, indexes, `lib/data/chat`) | **G5:** lane 2 merges 4d T1–6 |
| 6 | 4d Tasks 7–9 (S07.01, entry points, S07.02; needs G5) | 4e Tasks 1–3 (review domain, Functions, rules, `lib/data/review`) | **G6:** lane 2 merges 4e T1–3 |
| 7 | 4e Tasks 4–5 (S05.05, reviews on S03.01; needs G6) | `2026-10-02-shared-components-b1.md` (EventCard, TicketCard, badges, notifications; its Task 6 may edit `lib/features/explore/**`, untouched by lane 1 in steps 1–7) | — |

**Ownership (who may edit what while both lanes run):**
- Lane 1 only: `lib/app/router.dart`, `lib/core/screen_codes.dart`, `lib/features/**` except `booking/booking_features.dart` before G4, `test/features/**`, `test/support/booking_world.dart`, `docs/design/ui-mock.html`, the status cells of `remaining-screens.md`.
- Lane 2 only: `lib/core/widgets/**`, `lib/core/core.dart` and `lib/core/payments.dart` after G1, `lib/data/**`, `packages/domain/**`, `app_flutter/firebase/**` (rules, indexes, rules tests, functions incl. `index.ts`/`config.ts`), `test/core/**`, `test/data/**`, `test/support/fake_*`, `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html`, `shared-components.md`.
- Both, append-only: `lib/l10n/app_vi.arb` (each lane adds its keys as one block at the end of the file; on conflict keep both blocks and run `flutter gen-l10n`), `RUN-ORDER.md` (each lane edits only its own row/cell).
- If a lane needs a file the other lane owns (for example lane 1 finds a bug in a core widget), it writes the request in its ledger and the owning lane makes the change; no cross edits.

**Why this split:** the 4b→4e chain shares the booking screens (`booking_detail_screen`, `my_bookings_screen`, `booking_features`), the router and `firestore.rules`, so its UI stays in one lane; its server/data tasks only add new files plus append-only exports and rules, so they move to lane 2 and run one step ahead. A Tasks 1–3 are the base every widget uses, hence G1. A Task 4 and A Task 6 Step 6 both edit feature screens (`create_post_screen`), so both are lane 1.

**Not in either lane yet:** instant plans I2–I6 (rows 10–14) are stale against the rewritten instant spec (match flow, no automatic refund on `no_match`) and against plan A (`CountdownRing`, `ApertureLoader`, `ProviderPicker`); they are rewritten after the user approves the instant spec. Backend phase 2 (row 9) shares no file with plans A or 4b–4e except `pubspec.yaml`, so it can be a third lane or lane 2's step 7. iOS (15) and final battery (16) stay last.

## Done

screen-codes · core-display-widgets · 2a · 2b · 2c · 3a1 · 3a2 · 3b1 · 3b2 · backend-phase1 · 2d1 · 3b3 · 3b4 · 3c · 2d2 · 4a

## To run

| # | Plan | State |
|---|------|-------|
| 1 | `2026-10-02-mock-parity-1.md` (built screens match the mock) | done 2026-10-02 (a07dcb6); mock not edited by user decision; deferred minors in `handover/ledger-mock-parity-1.md` |
| 2 | `2026-10-01-step2c-skills.md` (S08.02, S08.03, S08.04) | done 2026-10-02; entry links to /setup/3 and /profile/skills come with plan 3 (2d1) and the S09.01/S09.03 links |
| 3 | `2026-10-01-backend-phase1-firebase-local.md` | done 2026-10-02 (c97514c); CI not yet run (push needs gh workflow scope) |
| 4 | `2026-10-01-step2d1-photographer-setup-calendar.md` (S08.01, S06.04) | done 2026-10-02 |
| 5 | `2026-10-01-step3b3-recommendations.md` | done 2026-10-02 |
| 6 | `2026-10-01-step3b4-home-detail-find.md` (S02.01, S02.02, S02.06) | done 2026-10-02; /u/:id and /u/:id/book routes come with 2d2 and step 4 (taps there hit the router error page until then) |
| 7 | `2026-10-01-step3c-create-post.md` (S10.01) | done 2026-10-02 |
| 8 | `2026-10-01-step2d2-photographer-profile.md` (S03.01) | done 2026-10-02; S09.01 rows (phone, skills, public profile) went to S09.02 per the new mock; /u/:uid/book and /ask come with step 4 |
| 8a2 | `2026-10-02-shared-components-a.md` (SignatureLoader, white skeletons, AsyncView, migration of existing screens, money/decision/countdown/booking/chat widgets) | partly done 2026-10-03: A Tasks 1–3 (G1, PR #2) and 5, 7, 8 (PR #3) merged; remaining: Task 4 (lane 1 step 2), Task 6 Steps 1–5 + Task 9 (lane 2 step 2), Task 6 Step 6 (lane 1 step 3), Task 10 (lane 2 step 3); needs 8a; runs before every screen plan (user 2026-10-02: components first, screens after); split across lanes 1 and 2 (see "Two parallel lanes") |
| 8b | `2026-10-02-step4b-booking-sheet.md` (S04.01–S04.04) | not started; needs 8a2 |
| 8c | `2026-10-02-step4c-booking-detail-lists.md` (S05.02, S05.03, S05.01, S06.01, S06.02, S06.03) | not started; needs 8b; fixes 4a's missing read rule for `bookings/{id}/events` |
| 8d | `2026-10-02-step4d-chat.md` (S07.01, S07.02 chat list, reschedule) | not started; needs 8c; adds new screen code S07.02 (mock section for the user to review) |
| 8e | `2026-10-02-step4e-review-share.md` (S05.05, reviews on S03.01) | not started; needs 8d |
| 8a | `2026-10-02-step4a-booking-backend.md` (booking domain, fake payments, escrow, rules, app repository) | done 2026-10-02; screen UI plans 4b–4e to follow |
| 9 | `2026-10-01-backend-phase2-selfhosted-postgres.md` | not started; disjoint from 8a2–8e, can run as a third lane |
| 10 | `2026-10-01-instant-i2-dispatch-core.md` | stale: rewrite after the instant spec is approved (I2–I6) |
| 11 | `2026-10-01-instant-i3-dispatch-service.md` | not started |
| 12 | `2026-10-01-instant-i4-photographer-app.md` (S13.08, S14) | not started |
| 13 | `2026-10-01-instant-i5-customer-app.md` (S13) | not started |
| 14 | `2026-10-01-instant-i6-payments.md` | not started; needs the user's MoMo / VNPay sandbox keys before its Task 13; its dependency on iOS enablement Task 1 is deferred to plan 15 |
| 15 | `2026-10-01-ios-enablement.md` + the deferred iOS steps | last feature work |
| 16 | `2026-10-02-final-battery-performance.md` (all checks + device build and profiling) | very last |

## Not planned yet

Booking flow and work UI (S04.01–S04.04, S05.02, S05.03, S05.05, S07.01, S05.01, S06.01, S06.03, S06.05, S06.06; backend and repository done in 4a), events (S11.01–S11.04, S12, S11.05, S11.06), badges (S03.02), notifications (S17), job posts "Đăng việc" (S15, S16, still in design).
