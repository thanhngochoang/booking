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

screen-codes · core-display-widgets · 2a · 2b · 2c · 3a1 · 3a2 · 3b1 · 3b2 · backend-phase1 · 2d1 · 3b3 · 3b4 · 3c · 2d2

## To run

| # | Plan | State |
|---|------|-------|
| 1 | `2026-10-02-mock-parity-1.md` (built screens match the mock) | done 2026-10-02 (a07dcb6); mock not edited by user decision; deferred minors in `handover/ledger-mock-parity-1.md` |
| 2 | `2026-10-01-step2c-skills.md` (S38, S39, S40) | done 2026-10-02; entry links to /setup/3 and /profile/skills come with plan 3 (2d1) and the S30/S42 links |
| 3 | `2026-10-01-backend-phase1-firebase-local.md` | done 2026-10-02 (c97514c); CI not yet run (push needs gh workflow scope) |
| 4 | `2026-10-01-step2d1-photographer-setup-calendar.md` (S24, S20) | done 2026-10-02 |
| 5 | `2026-10-01-step3b3-recommendations.md` | done 2026-10-02 |
| 6 | `2026-10-01-step3b4-home-detail-find.md` (S01, S02, S04) | done 2026-10-02; /u/:id and /u/:id/book routes come with 2d2 and step 4 (taps there hit the router error page until then) |
| 7 | `2026-10-01-step3c-create-post.md` (S21) | done 2026-10-02 |
| 8 | `2026-10-01-step2d2-photographer-profile.md` (S03) | done 2026-10-02; S30 rows (phone, skills, public profile) went to S31 per the new mock; /u/:uid/book and /ask come with step 4 |
| 9 | `2026-10-01-backend-phase2-selfhosted-postgres.md` | not started |
| 10 | `2026-10-01-instant-i2-dispatch-core.md` | not started |
| 11 | `2026-10-01-instant-i3-dispatch-service.md` | not started |
| 12 | `2026-10-01-instant-i4-photographer-app.md` (S52–S55) | not started |
| 13 | `2026-10-01-instant-i5-customer-app.md` (S47–S51, S55) | not started |
| 14 | `2026-10-01-instant-i6-payments.md` | not started; needs the user's MoMo / VNPay sandbox keys before its Task 13; its dependency on iOS enablement Task 1 is deferred to plan 15 |
| 15 | `2026-10-01-ios-enablement.md` + the deferred iOS steps | last feature work |
| 16 | `2026-10-02-final-battery-performance.md` (all checks + device build and profiling) | very last |

## Not planned yet

Booking flow and work (S05–S12, S14, S19, S23, S43, S44), events (S15–S18, S25–S27, S45, S46), badges (S37), notifications (S63–S65), job posts "Đăng việc" (S56–S62, still in design).
