# Run order of the implementation plans

Agreed with the user on 2026-10-02. Run the plans top to bottom with subagent-driven development; a plan starts only when every plan above it is done. Screen status lives in the code table of `docs/superpowers/specs/2026-10-01-remaining-screens.md` (column "Trạng thái"); update it when a plan finishes.

Standing rules (user, 2026-10-02):
- The UI matches the committed mock `docs/design/ui-mock.html`; the specs decide behaviour.
- No battery/performance task or test steps inside feature plans; all of it runs once in plan 16.
- No device build or Genymotion install after each plan; it happens once, in plan 16.
- iOS-only steps are skipped in feature plans and appended to "Deferred iOS steps" in plan 15.
- Every screen shows its code (`ScreenCode`) in debug builds.
- Firestore/Storage rules tests on the emulator (`firebase/rules-test`) are not run while executing plans; rules and their tests are still written, CI runs them on push (banner at the top of each plan). Backend phase 1's own emulator-suite work is not affected.

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
| 8a2 | `2026-10-02-shared-components-a.md` (SignatureLoader, white skeletons, AsyncView, migration of existing screens, money/decision/countdown/booking/chat widgets) | not started; needs 8a; runs before every screen plan (user 2026-10-02: components first, screens after) |
| 8b | `2026-10-02-step4b-booking-sheet.md` (S04.01–S04.04) | not started; needs 8a2 |
| 8c | `2026-10-02-step4c-booking-detail-lists.md` (S05.02, S05.03, S05.01, S06.01, S06.02, S06.03) | not started; needs 8b; fixes 4a's missing read rule for `bookings/{id}/events` |
| 8d | `2026-10-02-step4d-chat.md` (S07.01, S07.02 chat list, reschedule) | not started; needs 8c; adds new screen code S07.02 (mock section for the user to review) |
| 8e | `2026-10-02-step4e-review-share.md` (S05.05, reviews on S03.01) | not started; needs 8d |
| 8a | `2026-10-02-step4a-booking-backend.md` (booking domain, fake payments, escrow, rules, app repository) | done 2026-10-02; screen UI plans 4b–4e to follow |
| 9 | `2026-10-01-backend-phase2-selfhosted-postgres.md` | not started |
| 10 | `2026-10-01-instant-i2-dispatch-core.md` | not started |
| 11 | `2026-10-01-instant-i3-dispatch-service.md` | not started |
| 12 | `2026-10-01-instant-i4-photographer-app.md` (S13.08, S14) | not started |
| 13 | `2026-10-01-instant-i5-customer-app.md` (S13) | not started |
| 14 | `2026-10-01-instant-i6-payments.md` | not started; needs the user's MoMo / VNPay sandbox keys before its Task 13; its dependency on iOS enablement Task 1 is deferred to plan 15 |
| 15 | `2026-10-01-ios-enablement.md` + the deferred iOS steps | last feature work |
| 16 | `2026-10-02-final-battery-performance.md` (all checks + device build and profiling) | very last |

## Not planned yet

Booking flow and work UI (S04.01–S04.04, S05.02, S05.03, S05.05, S07.01, S05.01, S06.01, S06.03, S06.05, S06.06; backend and repository done in 4a), events (S11.01–S11.04, S12, S11.05, S11.06), badges (S03.02), notifications (S17), job posts "Đăng việc" (S15, S16, still in design).
