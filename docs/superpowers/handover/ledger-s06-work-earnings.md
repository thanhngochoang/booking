# Handover ledger — plan S06 work and earnings: S06.01 assigned bookings, S06.02 closed variant, S06.05 tax breakdown, S06.06 name lookup, OTP and 72 hours, daily payouts (issue #134)

Plan: `docs/superpowers/plans/2026-10-07-s06-work-earnings.md`, Tasks 1–10. Branch `plan/134-s06-work-earnings`, stacked on `plan/148-s09-profile-settings` (merge base 1641873; PR #188 open, its CI blocked by GitHub Actions billing). Rebase onto `develop` after #188 merges. Commits: 8d30162 and 3242a07 (mock frames), 82290ff and c431f84 (domain: policy, tax, approval, daily run), 457015c and 0e0d607 (domain: account v2, lookup, OTP), 0172838 (Functions: `createPayouts`, CLI), eaea2d3 (Functions: callables, rules), c3e91d6 (app data), 5ed2444 (S06.05), 4920422 and 2a7682c (S06.06), 506af21 (S06.01 and S06.02), then the docs commit of Task 10.

## Built
- **Mock (Task 1):** new frames `S06.01-assigned`, `S06.06-review`, `S06.06-otp`, `S06.06-pending`; S06.05 shows two expanded rows (paid and estimated) and scrolls (`.body.sc`).
- **Domain (Tasks 2 and 3):**
  - `payout_policy.ts`: `DEFAULT_PAYOUT_POLICY` (fee 0 bp for every provider type; tax 500 + 200 bp for `individual` and `artist`, 0 for `studio`) and `payoutLineOf` (per payment, `Math.round`, net never negative).
  - Payout statuses gain `needs_approval`; `approvePayout`; `SYSTEM_PAYOUT_ACTOR`; `runDailyPayouts` and `DailyPayoutReport` (`daily_payouts.ts`); the ledger gains `tax_withheld` and `platform_fee`.
  - Payout account v2: `account_lookup.ts` (`AccountNameLookup`, `FakeAccountNameLookup`, the other ports), `payout_otp.ts`, `fake_otp_sender.ts`, `payout_account_use_cases.ts` (`lookupPayoutAccountName`, `requestPayoutOtp`, `chargeLookup`), `savePayoutAccount` rewritten (name decision, OTP, 72 hours, re-pointing open payouts, notices).
  - `holderNameDecision`, `isAccountActiveAt`, `ACCOUNT_CHANGE_DELAY_HOURS`, `NAME_LOOKUPS_PER_DAY`.
- **Functions (Tasks 4 and 5):** `createPayouts` (10:00 Asia/Ho_Chi_Minh), CLI `approve` and `run-daily` and `due` listing `needs_approval`, earnings projection with tax and milestones, payouts mapping with old-document defaults, seed (An: verified name, tax 105,000, net 1,395,000), callables `lookupPayoutAccountName`, `requestPayoutOtp`, `savePayoutAccount` v2, Firestore adapters for the OTP challenge and the lookup quota, rules for `assigneeId` read and the two server-only collections.
- **App data (Task 6):** `EarningItem` money split, `PayoutNameLookup`, `PayoutOtpTicket`, `PayoutAccountView.activeFrom/nameStatus`, repository methods, `watchAssignedBookings`, `assignedBookingsProvider`, `myWorkBookingsProvider`, `PhotographerIntro.acceptingOrders`.
- **S06.05 (Task 7):** rows expand on tap with the breakdown, milestone count in the meta, new notice and "Chờ chi trả" label, `EarningRow.breakdown/expanded`.
- **S06.06 (Task 8):** lookup card, mismatch/review/not found/unverifiable states, `OtpCodeField`, OTP sheet, 72-hour pending view, `showReauthSheet` moved to `lib/features/account/widgets/reauth_sheet.dart` (keys `reauth*`) for #141's S22.02.
- **S06.01 and S06.02 (Task 9):** "Giao bởi {studio}" tag on the today card (`BookingSummary.tag`), assigned bookings counted for Hôm nay and Buổi sắp tới only, closed variant of the empty state (`EmptyState.note`, `AppIcons.verifiedUser`), `workDashboard(..., uid:)`.
- **Docs (Task 10):**
  - main spec §2 rows S06.01, S06.02, S06.05, S06.06, plus §3g.4 and §3g.5 (daily job, `tax_withheld`, `platform_fee`);
  - `screens/photographer.md` S06.01, S06.02, S06.05 and S06.06, with strings checked against `app_vi.arb`;
  - `data-model/domain-model.md` and `relational-schema.md` (payout money fields, `needs_approval`, account `nameStatus`/`activeFrom`, `OtpChallenge`, ledger types, indexes);
  - payments spec §6 (one "Đã làm" paragraph under 6.1 and under 6.2).
  - `docs/FIREBASE-SETUP.md` was not changed: it does not list scheduled functions.

## Decisions of the plan
"Cost if wrong" is what it costs to undo the decision.

| # | Decision | Cost if wrong |
|---|---|---|
| 1 | Tax and fee are a domain constant policy, rate snapshotted on each payout (`feeRateBp`, `taxRateBp`) | One constant and a reviewed PR; history is unaffected |
| 2 | Rounding per payment (`Math.round(amount × bp / 10000)`), net = amount − fee − tax; payout totals are sums of items | Rewrite of `payoutLineOf` and its tests; S06.05 rows would stop adding up |
| 3 | Ledger on paid: `payout_paid` −net, `tax_withheld` −tax and `platform_fee` −fee only when > 0 | Replaying entries for already paid payouts |
| 4 | KPIs and row amounts stay gross; only the expanded breakdown shows tax and net | Change in `summarizeEarnings` and S06.05 copy |
| 5 | `needs_approval` status; staff approve with the CLI; approving also sets a `pending_review` account to `staff_confirmed` | A dashboard (S23.02, #83) replaces the CLI; the status stays |
| 6 | `createPayouts` daily 10:00 VN, creates then executes every `pending`; `off` mode logs only; payees without an account get the notice once | Cron string in `CREATE_PAYOUTS_OPTIONS` |
| 7 | 72 hours: first account active at once; a change deactivates the old one and the new one is active from now + 72 h; no money moves to either; open payouts re-pointed and `pending` ones become `needs_approval` | Money could reach the old account during the wait; a rules-and-domain change |
| 8 | OTP replaces re-authentication on a change; `reauth_required` stays in `ERROR_CODES` | `showReauthSheet` is still there (moved) to switch back |
| 9 | OTP: 6 digits, 5 minutes, 5 wrong tries, resend after 60 s, 5 sends a Vietnam day, bound to the target account, single use, salted hashes in server-only `otp_challenges/{uid}_payout_account` (never under `users/{uid}/private/`) | Moving the doc means a rules and adapter change |
| 10 | Fake OTP only where fake payments are allowed (dev project or emulator on `demo-*`); logs `fake otp {uid, code}` | One more function-level gate |
| 11 | Name lookup is a separate port in `account_lookup.ts` with one fake; echoes the caller's verified name except `...4321` (TRAN VAN B), `...9999` (unsupported), `...0404` (not found); 20 lookups per uid per Vietnam day | A second fake in #141 (S22.04) would diverge |
| 12 | `holderNameDecision`: matched, mismatch, review, not_found, unverifiable; verified name is `users/{uid}/private/identity.legalName` (#135) | Matching rules are pure and tested; changing them is a domain edit |
| 13 | Notifications `payout_account_needed` and `payout_account_changed` defined by #138; #134 is their only emitter through `livePayoutNotices()` | A second emitter would double-send |
| 14 | S06.05 rows expand on tap; the old tap-to-open-booking is dropped | The booking is no longer reachable from S06.05 (see Deferred) |
| 15 | Milestones are read from `bookings/{id}/milestones`, not built (#152 writes them) | None here; #130 and #152 own the per-milestone payout change |
| 16 | S06.06 looks up 800 ms after typing stops and at once on submit; cached per `bankCode:number`; save only for `matched` or `review` | One constant |
| 17 | S06.02 closed variant when the own doc says `acceptingOrders == false` (fallback `verified && onboardingComplete`); the button needs `verifyStartReadyProvider` | One flag flip when #135 lands |
| 18 | S06.01 assigned bookings from a second stream `assigneeId == uid` (single-field index); a failing stream is empty; assigned bookings never count for Yêu cầu mới, Tháng này, Đang giữ | Counting rules in `workDashboard` |
| 19 | No `Booking` model change: assigned = `photographerId != uid` | Regenerate `booking.freezed.dart` if #136 adds `assigneeId` to the model |

## Rulings made during execution
1. **Task 9 reads `verifyStartReadyProvider` from #148's `settings_links.dart`** (it does not create it) and adds `EmptyState.note` on top of #148's optional body; #134 is stacked on #148. Cost if wrong: none.
2. **S06.05 body gets the existing `sc` scroll class** (as #148's S09 frames) and keeps both expanded rows (paid and estimate), instead of collapsing the paid one. Cost if wrong: a static screenshot of S06.05 shows the top only.
3. **The first-payout gate is satisfied by any payout to the same account that staff approved and that is `pending`, `processing` or `paid`** (`failed` does not count). A resumed payout that was approved keeps its approval. "Lần chi đầu do staff duyệt" means one approval per account, not one per payout before the first transfer. Cost if wrong: a second payout to a new account moves without a second human look.
4. **History reads are bounded.** The port reads "is there an approved-or-paid payout to this account" (limit 1) and "last 3 finished payouts to this account" (limit 3), scoped by `accountId`, with composite indexes added where the adapter needs them. Cost if wrong: one more composite index.
5. **The save charges the same role and quota transaction as `lookupPayoutAccountName` before any external lookup** (`chargeLookup`), and customers are refused before any lookup or identity read. "Must not become an oracle" covers every lookup path. Cost if wrong: a save attempt uses one of the 20 daily lookups.
6. **A resend makes the old code `otp_invalid` (a counted try), not `otp_required`**, because only the new salted hash is stored. Cost if wrong: S06.06 copy says "sai mã" for a superseded code.
7. **Changing to the account already active is refused as `conflict`**, in the save and in `requestPayoutOtp`, before any OTP or lookup is spent. Cost if wrong: one more refusal code for S06.06 to map.
8. **Seed payout amounts follow #129's 100% payment**: 1,500,000 → tax 105,000, net 1,395,000 (not the brief's pre-#129 450,000 / 31,500 / 418,500). Cost if wrong: seed numbers only.
9. **`requestPayoutOtp` binds the existing `PAYOUT_ACCOUNT_KEY`** (no new secret) because Ruling 7's same-account check decrypts the active account. The fake lookup is used only when `payoutsMode()` is `fake` and `fakePaymentsAllowed` is true (`lookupMode`). Cost if wrong: one more function holds the key; a non-decrypting same-account check (a keyed hash on the account) would remove it.
10. **The mock wins on S06.05**: the paid pill reads "Đã chuyển" (the date moves into the breakdown) and an account card (bank badge, "Tài khoản nhận tiền", masked number, chevron to `/work/earnings/account`) shows when an account exists. Planned for the final fix wave; **not built in the code at the time of this ledger** (the pill still reads "Đã chuyển {date}", the screen still has the gear icon and the "Thêm tài khoản" card). Cost if wrong: a small UI rework. When it lands, change `earningsStatePaid` and the "Khác mock" bullet of S06.05 in `screens/photographer.md`.

## Owner defaults (needs the owner)
1. **Tax withheld from individuals: 7%** (5% GTGT + 2% TNCN), no exemption threshold, **studios 0%** (the accountant confirmed). In `DEFAULT_PAYOUT_POLICY`; changing it is a one-line PR. Fee (commission) is 0%.
2. **OTP only on the emulator and the dev project.** No SMS vendor is chosen. Outside them `requestPayoutOtp` answers `not_eligible`, so changing a payout account is impossible in production until a vendor (Firebase Auth SMS, about $0.15 each, chưa xác nhận; or a local brand-name SMS / Zalo ZNS) is chosen. Adding a first account needs no OTP.

## As built, where it differs from the plan's Contract
- **`PayoutCoreDeps`** (`{store, cipher, clock, ids}`) is the base of both dep sets: `PayoutAccountDeps` adds `lookup, names, otp {sender, phones, crypto}, notices`; `PayoutDeps` adds `gateway, policy, notices`. The CLI and `createPayouts` therefore need no lookup or OTP ports. `Caller` is `{ uid }` (no `authTime`).
- **`PayoutNotices` lives in `account_lookup.ts`** with the other ports and is re-exported from `payout_ports.ts`; `NameLookupResult` also moved there (`payout_account.ts` re-exports it).
- **Bounded history ports** `hasApprovedOrPaidPayout(accountId)` and `lastFinishedPayouts(accountId, limit)` replace the unbounded `accountHistory` of the first draft (Rulings 3 and 4). Two new composite indexes on `payouts` in `firestore.indexes.json`: (`accountId` ASC, `status` ASC, `createdAt` DESC) and (`accountId` ASC, `status` ASC, `approvedBy` ASC). The `status in [...]` plus `approvedBy != null` query has never run against an emulator.
- **`chargeLookup(deps, uid, guard)`** (`payout_account_use_cases.ts`) is the shared role and quota transaction of the lookup and the save (Ruling 5); `isSameAccount` compares bank, last 4 digits and only then decrypts.
- **`PayoutSaveOutcome`** (app controller) has more values than the plan: `sameAccount` (`conflict` from `requestAccountOtp`, key `payoutAccountSameAccount`), `lookupLimit` (`limit_exceeded` on a first save), `otpWait` (the 60 s resend wait is per user, with `otpWaitSeconds`) and `notFound`. `submitOtp` and `resendOtp` live on the controller, which also exposes `lastResendError`.
- **`requestPayoutOtp` binds `PAYOUT_ACCOUNT_KEY`** (Ruling 9). `handleRequestPayoutOtp(request, deps, env)` checks `fakeOtpAllowed` first, after auth, so a refused call spends no send. `otpSender(env, uid)` takes the uid for the `fake otp` log line.
- **`lookupMode(env)`** (`infra/payout_lookup.ts`) is stricter than `payoutsMode()`: `fake` only when both `payoutsMode() === 'fake'` and `fakePaymentsAllowed`. `off` means every lookup is `unsupported`.
- **`CREATE_PAYOUTS_OPTIONS`** is a named constant in `config.ts` (`...SCHEDULE_OPTIONS`, `'0 10 * * *'`, `Asia/Ho_Chi_Minh`, 540 s, `secrets: [PAYOUT_ACCOUNT_KEY]`) so a unit test pins it. `handleCreatePayouts(deps?, mode)` builds the live deps after the mode check, so `off` never reads the secret or Firestore. `livePayoutNotices(hooks, notifyDeps)` takes injectable hooks.
- **`CliIo.listOpenPayouts(statuses)`** takes statuses; `OPEN_PAYOUT_STATUSES` is `needs_approval`, `pending`, `on_hold`, `processing`.
- **Seed amounts** 1,500,000 → tax 105,000, net 1,395,000 (Ruling 8), derived with `payoutLineOf`; seed docs now go through the `src/infra` mappers; An's `users/seed-photographer-an/private/identity.legalName` is "Nguyễn Văn An".
- **`payoutLineOf`** throws `invalid_argument` for a negative or non-integer gross; a ledger line of amount 0 is not written. `createPayout` reads the rates straight from the policy.
- **`resumePayout`** returns to `pending` when the payout already has `approvedBy`, otherwise applies the same gate as create (a missing account goes to `needs_approval`).
- **Old-document defaults** everywhere: fee 0, tax 0, net = amount, `firstPayout` false, `nameStatus` matched, `activeFrom` = `createdAt` (the owner view has no `createdAt`: `updatedAt`).
- **Fake repository** (`FakeEarningsRepository`): extra members `failNextLookup`, `defaultLookup`, `otpTicket`, an optional `clock`; it does not enforce OTP on a change, nor `name_mismatch` or `not_found` from `nextLookup`: tests model refusals with `failNextSave(code)` and assert `saves`. A fake `saves` entry is `BANK:last4` or `BANK:last4:<code>`.
- **Scheduler job count:** the plan and the brief counted 6 jobs. `paymentClock` (#129) was the 7th, so `createPayouts` is the **8th** scheduled function in `src/index.ts` (`releaseEventHolds`, `eventClock`, `bookingClock`, `purgeAwardProofs`, `reconcileBadges`, `pruneNotifications`, `paymentClock`, `createPayouts`). #132's `rollNextFreeDates` will be the 9th.

## Not run (suites written, not run here)
GitHub Actions is blocked by billing, so CI did not run the suites below and nothing here could run an emulator:
- **Rules tests** in `app_flutter/firebase/rules-test/rules.test.mjs` (6 new: the assignee reads a booking and cannot write it; a stranger cannot read it; an assignee query with `where assigneeId == uid` is allowed and an unfiltered one is not; nobody reads or writes `otp_challenges` or `payout_lookups`; the owner still cannot write `payoutAccounts`). The new `assigneeId` clause uses the same `resource.data.get(key, default)` form as the file's other rules, and was not dry-run.
- **Functions integration tests** (`npm run test:integration`): `test/integration/create_payouts.test.ts` (new) and the v2 cases of `test/integration/earnings.test.ts` (first save, customers refused, lookup, full change with OTP). They include the `in` plus `!= null` history query, and the emulator does not enforce indexes either.
- Not exercised either: any real Firestore index, a device build, the emulator walk-through of S06.06, a real deploy.
- Last green runs by the tasks (Task 10 changed no code, so nothing was re-run except the spec test below): domain 987/987 (`npm test`, `typecheck`, `lint`), Functions unit 355/355 (+ `lint`, `build`), Flutter folders `test/data/earnings`, `test/data/booking`, `test/data/photographer`, `test/features/earnings`, `test/features/work`, `test/features/booking`, `test/features/account`, `test/core/widgets`, `test/l10n`, `test/features/notifications`, and `test/core/screen_codes_test.dart`, with `flutter analyze` clean.

## Deploy order and manual steps
1. **Deploy the rules before the app.** The `assigneeId` query is denied until the rule is live; the app tolerates it (the assigned stream reads as empty and logs the error type once), so S06.01 still works, but studio-assigned bookings do not show.
2. **Indexes with the rules:** the two new `payouts` composite indexes ship in `firestore.indexes.json`. Without them the first-payout and repeated-failure checks fail on a real project.
3. **`createPayouts` binds the existing `PAYOUT_ACCOUNT_KEY`**, like `savePayoutAccount` and `requestPayoutOtp`. A Blaze project needs that secret (ledger 10b, `docs/FIREBASE-SETUP.md` section 11) before deploying functions. **Nothing deploys to `booking-c1922`** (Spark; Functions never run there). Everything is exercised on the emulators (`../scripts/backend-local.sh`).
4. **Scheduler jobs go from 7 to 8** (Scheduler is $0.10 per job a month beyond 3 free per billing account). #132's `rollNextFreeDates` will be the 9th. The job logs only counts and `{id, step, code}`, never an account number, name or message.
5. **For #135:** flip `verifyStartReadyProvider` (in `lib/features/settings/settings_links.dart`) to `true` together with the `/verify/start` route; write `users/{uid}/private/identity.legalName` on approval; and exclude `identity` from the owner-read rule of `users/{uid}/private/{docId}` (today it is `allow read: if isOwner(uid)` for any doc id; clients cannot write `identity`). S06.06 reads the verified name from there, so without it a photographer without a bank-supported name lookup gets `not_eligible` in production.
6. **For #136:** the `assigneeId` read rule already exists on `bookings/{bookingId}`; add the sub-collection rules (`private/contact`, `events`) and the model field. Assigned bookings opened from S06.01 go to `/b/:id`, whose party logic assumes the viewer is customer or photographer.
7. **For #135 and #141 (S22.04):** `FakeAccountNameLookup` and `AccountNameLookup` are in `packages/domain/src/account_lookup.ts`; reuse them, no second fake. `showReauthSheet` is in `lib/features/account/widgets/reauth_sheet.dart` for S22.02.

### Running it on the emulator
Only An (`seed-photographer-an`, phone ending 0001) has a verified name (`identity.legalName` "Nguyễn Văn An") in the emulator seed. Binh, Cúc and Dũng get `not_eligible` when saving an account, because the fake lookup echoes the caller's verified name; use An, or add an identity doc. Numbers ending `4321` give a mismatch (TRAN VAN B), `9999` give review, `0404` give not found. The OTP code is in the emulator UI (:4000, Logs, entry `fake otp`).

```bash
cd app_flutter/firebase/functions
# One round of what the 10:00 job does (fake mode only; prints created, needsApproval, onHold, executed, paid, failed, noAccount, notActive, errors)
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  npm run payouts -- run-daily --actor seed-staff-admin
# A first payout to an account waits for staff
npm run payouts -- due
npm run payouts -- approve <payoutId> --actor seed-staff-admin
# Run again to send it
npm run payouts -- run-daily --actor seed-staff-admin
```

## Review notes
From the SDD progress ledger (a local, untracked folder; the rulings are copied above):
- Pre-flight scan: T2 and T3 both touch `payout_ports.ts`, `memory_payout_store.ts`, `index.ts` and `test/support/payout_world.ts` (run sequentially); T4 and T5 both touch `infra/payout_firestore.ts`, `infra/live_payout.ts` and `src/index.ts` (sequential); T7 and T8 both append to `app_vi.arb` (sequential); #134 is stacked on #148 for `verifyStartReadyProvider` (Ruling 1).
- Task 1 (1641873..3242a07): one Important (S06.05 overflow; Ruling 2), fixed in round 1; review clean.
- Task 2 (3242a07..c431f84): Important (payouts created before the first approved one is paid also landed in `needs_approval`; unbounded history read in the transaction; Rulings 3 and 4), fixed in round 1; review clean.
- Task 3 (c431f84..0e0d607): Important plan gap (the save's own bank lookup bypassed the 20 a day cap and ran before the role check; Ruling 5), plus Rulings 6 and 7; fixed in round 1; review clean.
- Task 4 (0e0d607..0172838), Task 5 (0172838..eaea2d3), Task 6 (eaea2d3..c3e91d6), Task 7 (c3e91d6..5ed2444), Task 9 (2a7682c..506af21): spec compliant and quality approved at review 1.
- Task 8 (5ed2444..2a7682c): Important (a new account inside the per-user 60 s resend window showed "too many codes today"), fixed in round 1 with the resend and server-state minors; review clean.

## Deferred
From the plan:
- S06.07 "Nộp bàn giao": the delivery plan of #130 (spec bàn giao §5).
- Copy "cọc" to "đã thanh toán / hoàn 100%" on S06.01 and S06.03: #129 (done in #154).
- Real payout intermediary adapter (transfer, name lookup, webhook or `queryPayout`), real SMS/OTP adapter, email to the old address on account change: after the legal work (payments spec §10–11); needs the owner (item 2 above).
- Staff screen S23.02 (approve first payouts, reconcile, tax export file): phase 1.5 dashboard #83; the CLI covers it until then.
- Studio payout accounts in the company's name (match with the business name, S21.04): #135.
- Partial release per milestone in the earnings rows and payouts (amount released per milestone): the plan that introduces milestones (#152, delivery plan; #130 owns the per-milestone payout change, pinned by its test "shoot milestone paid while delivery held").
- Revenue entries `gateway_fee`, `payout_fee`, `revenue_received` of payments spec §8: no owner yet (V3 in `2026-10-08-s04-reconciliation.md`; #129 did not build them).
- A payout whose gateway keeps throwing stays `processing` (10b deferred, unchanged).
- S06.02 segmented control of the mock; S06.01 banner "bỏ dở xác minh" (#135).
- Go backend (phase 2, #90) port of the payout rules: the domain is reusable as is.

From the execution ledger ("minor (deferred)" lines):
- Task 1: contrast of the `ptag` on the photo overlay (fixed in round 1).
- Task 2: extra exports `taxRateBpOf`, `isAccountWaitingAt`, `NAME_STATUSES`, `DAILY_EXECUTE_LIMIT`; `PHOTOGRAPHERS_COLLECTION` imported from `review_firestore`; an artificial 3-failure test setup; `PayoutNotices` lived in `payout_ports.ts` (moved by Task 3). After the fixes: `payoutLineOf` throws on corrupt amounts, also through the earnings read model (`refreshEarnings` then fails for that payee); `resumePayout` reads `hasApprovedOrPaid` even when `approvedBy` is set; with Ruling 3, payout B can go out before A succeeds; `holdPayout` accepts only `pending` (staff cannot hold a `needs_approval` payout); the new payouts indexes were checked on paper only (the emulator ignores indexes).
- Task 3: a failed OTP send still counts (fail-closed; Task 5 checks `fakeOtpAllowed` first); the stale `auth_time` doc and type in the payout account callable (done in Task 5); `clearFixtureLimits` advances the fixture clock up to 60 s; on a change, a bogus `otpCode` still gets the name verdict before the OTP check (it shares the 20 a day quota).
- Task 4: no unit test of `getSubject` reading `bookings/{id}/milestones` (only the pure `milestonesOfDocs`); a stale "450,000" comment at `seed/fixtures.ts` (listed for the final fix wave); `codeOf` duplicates `errorCodeOf`; `run-daily --actor` is not recorded on the payouts; `CREATE_PAYOUTS_OPTIONS` typing.
- Task 5: no callable test for `requestPayoutOtp` conflict; deps are built with an empty uid for anonymous calls; the integration test regex prints an account number on failure (`earnings.test.ts` around lines 114 and 148); seed photographers without `identity.legalName` get `not_eligible` on the emulator (use An).
- Task 6: the `activeFrom` fallback uses the wall clock (`firestore_earnings_repository.dart`); the `saves` doc says ":otp" but records the code; the fake enforces neither OTP on a change nor `name_mismatch`/`not_found` from `nextLookup` (Task 8 asserts `saves`); the assigned-stream log is untested; one low-value fake test.
- Task 7: stale "Sắp nhận" doc comments (`earnings_screen.dart`, `earnings.dart`); a 180 ms literal; `_expanded` keeps stale ids; Ruling 10's paid pill and account card (open, above).
- Task 8: `limit_exceeded` from a save is ambiguous (wrong tries or the daily lookup quota) and needs a distinct server code; the pending view is frozen at build time; `StatusBadge` upper-cases "CHỜ HIỆU LỰC" (the mock shows "Chờ hiệu lực"; the earnings badges follow the same convention); the OTP field is one field, not six slots; the number field is not autofocused; `LockNote` and `BankField` placement; `OtpCodeField` is not in `components/shared-components.md` or the components gallery; a refused resend always reads as the daily limit unless `resendRefusal` says otherwise; the bank badge draws the bank code, not a logo (the app ships no bank logos).
- Task 9: the closed variant should wait for `myIntroProvider` (no flash of the old empty state); a small primary button per the mock (`EmptyState` action size); the closed-variant disc duplicates `EmptyState.icon`; a misleading KPI comment in `work_screen_test`; an assigned booking opens `/b/:id` and chat, where the viewer is neither customer nor photographer (rules and role logic belong to #136); the `.ptag` uses theme tokens, not the mock's white-on-photo variant; the studio name appears only after `partyProfileProvider` resolves; the tag shows only on the today card.
- Task 1 report: S06.05 frames were not rendered (the browser pane and headless Chrome were blocked); a quick look at `#S06.05` is worth doing.
- If the `assigneeId` rule is denied, the Firestore listener ends after its error and the provider stays empty until it is rebuilt (tab re-mounted or uid changed).
- `PhotographerIntro.acceptingOrders` defaults to false in the constructor: test seeds that do not set it read "not accepting".
- Each earnings refresh of a booking row now costs one more read (the milestones subcollection, 1 read when empty).
