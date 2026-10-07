# S06 · Nhận việc & thu nhập Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and adds Functions. Write the rules tests (`app_flutter/firebase/rules-test/rules.test.mjs`) and the Functions integration test; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A photographer sees on S06.05 where each payment is and what reaches the bank (tax withheld, net, milestones when they exist), gets paid automatically every day by a `createPayouts` job (first payout to each account approved by staff), registers or changes the payout account on S06.06 without typing the holder name (name looked up and matched against the verified name; a change needs an OTP and takes effect after 72 hours), sees "Bắt đầu nhận đơn" on S06.02 while not accepting orders, and sees "Giao bởi {Studio}" on S06.01 for studio bookings assigned to them.

**Architecture:** All money and account rules live in `packages/domain`: a payout policy (`payout_policy.ts`: platform fee and individual tax, integer VND), the payout lifecycle (`needs_approval` for the first payout of an account, `on_hold` after three failures), the daily run (`daily_payouts.ts`), and payout account v2 (`save_payout_account.ts`, `payout_account_use_cases.ts`, `payout_otp.ts`) behind four new ports (`AccountNameLookup`, `VerifiedNameReader`, `OtpSender`, `OtpPhoneReader`) with fake adapters. Functions stay thin: three callables (`lookupPayoutAccountName`, `requestPayoutOtp`, `savePayoutAccount` v2), the scheduled `createPayouts` (daily 10:00 Asia/Ho_Chi_Minh, fake gateway only), the staff CLI gains `approve` and `run-daily` (the emulator never fires schedules, so `run-daily` is how the job is exercised locally). The app reads the richer earnings projection and calls the callables through `EarningsRepository`; S06.01 adds a second listener on `bookings where assigneeId == uid` (data written later by #136); S06.02 reads `acceptingOrders` from the photographer's own intro stream.

**Tech Stack:** TypeScript (domain, Functions v2 `onCall`/`onSchedule`, `node --test`), Firestore rules; Flutter, Riverpod 3, go_router, `flutter_test`, fakes in `test/support/`.

**Spec:** `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §1 (M4–M6, M8), §4, §6, §7, §9, §13; `2026-10-06-identity-verification-design.md` §3 (`users/{uid}/private/identity.legalName`), §4 (S06.02 entry point); `2026-10-06-studio-members-design.md` §4 (S06.01 "Giao bởi {Studio}"), §5.2 (`assigneeId`); main spec `2026-10-01-remaining-screens.md` §2 (S06 rows), §3g; `screens/photographer.md` (S06.01, S06.02, S06.05, S06.06); mock `docs/design/ui-mock.html` `#S06.01`, `#S06.02`, `#S06.05`, `#S06.06`, `#S06.06-mismatch`; handover `ledger-earnings-payout-10b.md`, `ledger-s03-orders-closed.md`. **Issue:** #134

**Branch:** `plan/134-s06-work-earnings`, PR into `develop` titled `feat(payouts): S06 daily payouts, tax line, payout account lookup and OTP [#134]`.

**Not in this plan:** S06.07 "Nộp bàn giao" is built by the delivery plan of #130 (spec bàn giao §5); the "cọc" → "đã thanh toán" copy on S06.01/S06.03 belongs to #129 (100% payment); the S21.02 screen itself is #135.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. Each task's Step 1 re-checks its part; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `Payout`, `PayoutItem`, `PAYOUT_STATUSES = ['pending','on_hold','processing','paid','failed']`, `isPayoutPayable`, `PLATFORM_PAYEE` (`payout.ts`); `createPayout`, `executePayout`, `holdPayout`, `resumePayout`, `listDuePayees`, `StaffActor` (`payout_use_cases.ts`); `PayoutTx`, `PayoutStore` (`listDuePayees()`), `PayoutGateway.transfer`, `PayoutAccountDeps {store, cipher, clock, ids}`, `PayoutDeps` (+ `gateway`) (`payout_ports.ts`); `PayoutAccount {id, userId, bankCode, accountNumberEnc, accountLast4, holderName, active, createdAt, deactivatedAt?}`, `PayoutAccountView`, `normalizeAccountNumber`, `normalizeHolderName` (folds diacritics, `Đ`→`D`, upper case), `REAUTH_MAX_AGE_SECONDS` (`payout_account.ts`); `savePayoutAccount(deps, {uid, authTime}, raw)` with exact keys `accountNumber, bankCode, holderName` (`save_payout_account.ts`); `FakePayoutGateway` (number ending `0000` → `failed`); `EarningItem`, `earningItemOf`, `summarizeEarnings`, `HOLD_REASON_PAYOUT_ON_HOLD` (`earnings.ts`); `EarningsTx.getSubject` → `EarningSubject {counterpartName, label, day}` (`earnings_ports.ts`); `refreshEarnings` (`refresh_earnings.ts`); `LEDGER_ENTRY_TYPES` (`escrow.ts`); `ERROR_CODES` (`errors.ts`); `ProviderType`, `providerTypeOf` (`provider_type.ts`); `bankByCode`, `VnBank.shortName` (`vn_banks.ts`); `formatVnDate`, `formatVnTime` (`booking_policy.ts`); `notify`, `NotifyDeps`, `NOTIFICATION_TYPES`, `renderNotification`, `formatVnd` (notification modules). Memory stores `MemoryPayoutStore` (`seedRole`), `MemoryEarningsStore`; test support `test/support/payout_world.ts` (`createPayoutWorld`, `addAccount`, `paidBooking`, `release`, `ADMIN`), `test/support/notify_world.ts` (`createNotifyWorld`).
- Functions (`app_flutter/firebase/functions/src`): `PAYOUT_ACCOUNT_KEY` (`defineSecret`), `payoutsMode()` (`fake` on the emulator or `PAYOUTS_MODE=fake`), `SCHEDULE_OPTIONS`, `CALLABLE_OPTIONS`, `DEV_PROJECT_ID`, `currentProjectId` (`config.ts`); `fakePaymentsAllowed(env)` (`infra/fake_payments.ts`); `livePayoutAccountDeps()`, `livePayoutDeps(keyB64, gateway)`, `payoutGateway(mode)`, `liveEarningsDeps()` (`infra/live_payout.ts`); `FirestorePayoutStore`, `payoutToFirestore`/`payoutFromFirestore`, `accountToFirestore`/`accountFromFirestore`, `accountViewToFirestore`, `PAYOUTS_COLLECTION = 'payouts'`, `PAYOUT_ACCOUNTS_COLLECTION = 'payoutAccounts'` (history under `payoutAccounts/{uid}/accounts/{id}`) (`infra/payout_firestore.ts`); `earningItemToFirestore`/`earningItemFromFirestore`, `FirestoreEarningsStore` (`infra/earnings_firestore.ts`); `handleSavePayoutAccount(request, deps)` (`callables/payout_account.ts`); `toHttpsError` + `TRANSPORT_CODE` (`callables/errors.ts`); `liveNotifyDeps()` (`infra/live_notification.ts`); exports `savePayoutAccount` (with `secrets: [PAYOUT_ACCOUNT_KEY]`), `onPaymentWritten`, `onPayoutWritten` (`index.ts`); staff CLI `tools/payouts.ts` (`parseArgs`, `runCli`, `cliPayoutsMode`, commands `due|show|create|execute|hold|resume`); emulator key `seed/emulator_key.ts` + `functions/.secret.local`; seed `seed/fixtures.ts` (`AN`, `SEED_AN_ACCOUNT` VCB `0123456789` holder `NGUYEN VAN AN`, `SEED_PAYOUT_AN`, `SEED_PAID_OUT_BOOKING`, `payoutAndEarningsDocuments`); photographer phone at `photographers/{uid}/private/contact.phone`. Six scheduled functions exist today (`releaseEventHolds`, `eventClock`, `bookingClock`, `purgeAwardProofs`, `reconcileBadges`, `pruneNotifications`).
- Rules: `match /bookings/{bookingId}` read = customer or photographer; `match /payoutAccounts/{uid}` owner read, no write; `match /payouts/{payoutId}` deny; `users/{uid}/private/{docId}` owner read (any doc id). Rules tests live in one file `app_flutter/firebase/rules-test/rules.test.mjs`.
- App data: `EarningItem`, `EarningsSummary`, `PayoutAccountView`, `PayoutAccountError(code)` (`lib/data/earnings/earnings.dart`); `EarningsRepository` + `FakeEarningsRepository` (`earnings_repository.dart`); `FirestoreEarningsRepository` (`earningItemFrom`, `payoutAccountViewFrom`, `payoutAccountErrorCodeOf`, callable `savePayoutAccount`) (`firestore_earnings_repository.dart`); `earningsRepositoryProvider`, `earningsSummaryProvider`, `earningItemsProvider(limit)`, `payoutAccountProvider` (`earnings_providers.dart`); `vnBanks` (`vn_banks.dart`); `normalizeAccountNumber` (`payout_account_rules.dart`); `Booking` (freezed; `photographerId`, `customerId`) and `bookingFromFirestore` (`lib/data/booking/booking.dart`); `BookingRepository.watchPhotographerBookings` (`booking_repository.dart`, `firestore_booking_repository.dart`); `myBookingsProvider(BookingRole)` (`booking_providers.dart`); `PhotographerIntro {bio, equipment, onboardingComplete, …}` + mapping (`lib/data/photographer/photographer_intro.dart`), `myIntroProvider` (`photographer_setup_providers.dart`).
- App features: `EarningsScreen` (`_row`, `_badge`, `_holdLabel`, KPI `earningsHeld/earningsSoon/earningsReceived`, `earningsNotice`), `PayoutAccountScreen` (`_save`, `_AccountForm`, `_ReadView`, `showConfirmSheet` before a change), `PayoutAccountController` + `PayoutAccountForm {bank, number, holder, editing, saving, justSaved}` + `PayoutSaveOutcome`, `widgets/account_inputs.dart`, `widgets/bank_picker_sheet.dart`, `widgets/reauth_sheet.dart` (`showReauthSheet`) under `lib/features/earnings/`; `WorkScreen` (`_todayCard` → `BookingCard`, `_RequestCard`, `StatTileRow`), `WorkEmptyState` + `workEmptyInputsProvider` (`lib/features/work/work_empty.dart`), `workDashboardProvider` (`work_dashboard.dart`), `workDashboard(List<Booking>, DateTime)` + `WorkDashboard` + `bookingSummaryFor` (`lib/features/booking/booking_view_rules.dart`), `partyProfileProvider(uid)` (`lib/features/booking/booking_parties.dart`); precedent for a route-ready flag: `eventRoutesReadyProvider` (`lib/features/explore/event_routes.dart`).
- Core: `EarningRow {title, meta, amount, amountLabel, badge, note, noteIcon, onTap}` (`core/widgets/earning_row.dart`), `BookingSummary`/`BookingCard` (`core/widgets/booking_card.dart`), `EmptyState {title, body, actionLabel, onAction, illustration}` (`core/widgets/empty_state.dart`), `AppIcons` (no `verified_user` entry yet), `showAppSheet`, `CountdownText`, `AppButton`, `AsyncView`, `StatusBadge.custom`, `formatMoney`, `toVn`, `formatDayMonth`, `clockProvider`.
- Routes: S06.05 `/work/earnings`, S06.06 `/work/earnings/account`, S21.02 `/verify/start` (not registered yet; #135).

## Global Constraints

- CLAUDE.md money rules (do not weaken): 100% paid up front, money held, released in two milestones; "only identity-verified, staff-approved providers receive orders"; payments spec M5: "Chi **tự động mỗi ngày**, không ngưỡng tối thiểu; **lần chi đầu của mỗi tài khoản nhận tiền do staff duyệt**"; M6: "tên chủ tài khoản phải khớp tên đã xác minh; đổi tài khoản cần OTP và có hiệu lực sau 72 giờ"; M4: "Nền tảng chịu phí cổng và phí chi" (never deducted from the photographer).
- Owner ruling 2 (2026-10-07): payouts, name lookup and OTP run on fake adapters only (`payoutsMode()`, the `fakePaymentsAllowed` rule); no real bank, SMS or Secret Manager integration. Real adapters go under Deferred.
- Owner ruling 3: `booking-c1922` is on Spark, Functions never run there; everything is exercised on the emulators (`scripts/backend-local.sh`). `PAYOUT_ACCOUNT_KEY` is not available on dev: keep the emulator `functions/.secret.local` path, add no new secret and no Secret Manager dependency (binding the existing `PAYOUT_ACCOUNT_KEY` to `createPayouts` is the same secret `savePayoutAccount` already binds); never copy a key value into code, tests, docs or logs.
- Ruling 5 (`ProviderOrderGate`) does not apply: this plan creates no booking, quote, assignment or instant invite.
- Business rules in `packages/domain` (no Firebase/Node imports; `purity.test.ts`); Functions are thin adapters, region `asia-southeast1` (`REGION`); Firebase only in `lib/data/**`, `firebase_options.dart`, `main.dart`.
- Ids, time, money: ULID/opaque ids, UTC instants (ISO strings in domain, `Timestamp` in Firestore), integer VND, string enum codes (`data-model/README.md`).
- App: imports `package:photobooking/...` only, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; one primary action per screen (`AppButton.primary`); strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; every screen and sheet wrapped in `ScreenCode`.
- The account number never leaves the S06.06 screen state, the callable payload and the encrypted store: not in logs, analytics, errors, notifications or test output (10b rule). Log only error codes.
- Commits: Conventional Commits, subject ends with `[#134]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Tests: Flutter `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time, never the whole suite in one command; bounded pumps (`pump(Duration)`), no endless animation or timer left running. Domain `cd packages/domain && npm test && npm run lint`. Functions `cd app_flutter/firebase/functions && npm test && npm run build`. Rules tests and Functions integration tests are written, not run.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Shared files with #138 (notifications): `notification.ts`, `notification_render.ts`, `notification_visuals.dart`, `notification_targets.dart`, `app_vi.arb` are append-only here; on a merge conflict keep both sides.

## Decisions

1. **Tax and fee are a domain constant policy** (`DEFAULT_PAYOUT_POLICY` in `payout_policy.ts`): platform fee 0 bp for `individual`, `artist`, `studio`; individual tax 500 bp GTGT + 200 bp TNCN = 7% for `individual` and `artist` (both are natural persons), 0 for `studio` (spec §7 "mặc định không khấu trừ"). Changing it is a reviewed code change; the rate used is snapshotted on each payout (`taxRateBp`, `feeRateBp`) so history never changes. Spec §7 says "cấu hình"; a versioned constant is that configuration until S23.02 needs an editor.
2. **Rounding:** tax and fee are computed per payment (`Math.round(amount × bp / 10_000)`), net = amount − fee − tax; a payout's totals are the sums of its items, so the S06.05 breakdown of each row adds up and the ledger nets to zero per payment.
3. **Ledger on payout paid:** per item `payout_paid` −net, `tax_withheld` −tax (only when > 0), `platform_fee` −fee (only when > 0). `LEDGER_ENTRY_TYPES` gains `tax_withheld` and `platform_fee`; the other renames of payments spec §8 (`payment_received`, `gateway_fee`, …) belong to #129.
4. **KPIs and row amounts stay gross** (the booking money); the per-row breakdown shows tax and net. "Đã nhận" stays the gross sum of paid-out rows (as today).
5. **Payout statuses gain `needs_approval`.** A payout is created `needs_approval` when it is the first one to its account (no `paid` payout with that `accountId`) or the account's `nameStatus` is `pending_review`; `on_hold` (`holdReason: 'repeated_failure'`) when the last three payouts to that account all `failed`; else `pending`. Staff approve with the CLI (`npm run payouts -- approve <payoutId> --actor <uid>`); no callable and no dashboard (S23.02 is #83). Approving also sets a `pending_review` account to `staff_confirmed`.
6. **Daily job:** `createPayouts` runs every day at 10:00 Asia/Ho_Chi_Minh (spec §6.1 "đề xuất 10:00"), `maxInstances: 1`, `retryCount: 0`, timeout 540 s, `secrets: [PAYOUT_ACCOUNT_KEY]`. In `payoutsMode() === 'off'` it logs and returns without creating anything (no real bank adapter). It (a) creates one payout per due payee with an active account, (b) executes every `pending` payout (approved ones included), one failure never stopping the others. Payees without an account get the `payout_account_needed` notice once (dedupe per payee). Running twice the same day creates nothing new: batched payments carry `payoutId`.
7. **72 hours:** the first account is active at once; a change deactivates the old account immediately and the new one is `active` with `activeFrom = now + 72 h`. `createPayout` and `executePayout` refuse (`not_eligible`) while `activeFrom > now`, so no money moves to either account during the wait (spec §6.2 "tạm dừng chi"). Open payouts (`pending`, `on_hold`, `needs_approval`) are re-pointed to the new account and every re-pointed `pending` one becomes `needs_approval` (first payout to the new account). `resumePayout` returns to `needs_approval` instead of `pending` when its account has no paid payout.
8. **OTP replaces re-authentication** for a change (spec §6.2): `savePayoutAccount` no longer throws `reauth_required`; `showReauthSheet` and the `payoutAccountReauth*` strings are removed; `reauth_required` stays in `ERROR_CODES` (unused, harmless). The OTP goes to `photographers/{uid}/private/contact.phone` (every set-up photographer has one, S08.05); missing → `phone_required`. #135 (S21.01) may switch the reader to the verified phone; the port stays.
9. **OTP rules:** 6 digits, valid 5 minutes, 5 wrong tries per code, resend after 60 s, 5 sends per Vietnam day; the code is bound to the account being saved (`targetHash` of `bankCode:number`) and single-use. Stored as salted SHA-256 in `otp_challenges/{uid}_payout_account` (server-only). It must NOT live under `users/{uid}/private/`, whose rule lets the owner read any doc.
10. **Fake OTP:** `FakeOtpSender` is allowed exactly where fake payments are (`fakePaymentsAllowed`: dev project or emulator on a `demo-*` project); it logs the code with `logger.info('fake otp', {uid, code})` so a tester reads it in the emulator UI (:4000 → Logs). Elsewhere `requestPayoutOtp` answers `not_eligible` (no SMS vendor yet; Deferred).
11. **Name lookup:** a separate port `AccountNameLookup.lookup({bankCode, accountNumber})` → `found {holderName}` | `unsupported` | `not_found`. The fake echoes the caller's verified name (so testers can match their own account) except: number ending `4321` → found `TRAN VAN B` (mock S06.06-mismatch), `9999` → `unsupported`, `0404` → `not_found`. In `off` mode the lookup answers `unsupported` (staff compares). Lookups are limited to 20 per uid per Vietnam day (`payout_lookups/{uid}`, server-only): the lookup reveals a stranger's name for any number, so it must not become an oracle.
12. **Match decision** (`holderNameDecision`, pure): both names through `normalizeHolderName`; found + verified name equal → `matched`; found + different → `mismatch` (save refused `name_mismatch`); `not_found` → refused `not_found`; `unsupported` + verified name → `review` (saved `pending_review`, holder = verified name); no verified name + found → `review` (holder = looked-up name); no verified name + `unsupported` → `unverifiable` (refused `not_eligible`). The verified name is `users/{uid}/private/identity.legalName` (identity spec §3, written by #135); seed writes it for An. Studio business names (S21.04) are #135's.
13. **Notifications owned here:** `payout_account_needed` (category `booking`, tab `system`, not critical; target `/work/earnings/account`) and `payout_account_changed` (category `booking`, tab `system`, **critical**; same target). Email to the old address is Deferred. `payout_released` is emitted by #138 from `onPayoutWritten`; nothing here.
14. **S06.05 rows expand on tap** (mock caption "Chạm một khoản để bung chi tiết"); the old tap-to-open-booking is dropped (the mock has no link). Paid rows show "Đã chuyển theo mốc · Hoa hồng (only when > 0) · Thuế khấu trừ (n%) · Thực nhận" from the payout item; other rows show "Số tiền · Thuế khấu trừ (n%) · Thực nhận dự kiến" from the policy (estimate). No tax line for studios.
15. **Milestones are read, not built:** the earnings projection reads `bookings/{id}/milestones` (spec 2026-10-05 §4.2; written later by #129/#130). With docs present the row meta shows "mốc {done}/{total}" or "đủ {total} mốc"; absent → day only. Partial release amounts per milestone are the job of the plan that introduces milestones (Deferred).
16. **S06.06 lookup trigger:** when a bank is chosen and the number is valid, the controller looks up after 800 ms of no typing (and at once on submit); results are cached per `bankCode:number` for the screen's life. Save is enabled only for `matched` or `review`.
17. **S06.02 condition:** the closed variant shows when the own photographer doc says `acceptingOrders == false` (fallback `verified == true && onboardingComplete == true`, same as `photographerSummaryFrom`). The button pushes `/verify/start` only while `verifyStartReadyProvider` is true; it is `false` until #135 registers the route and flips it (one-line change named in #135's contract). While false the button is hidden and the text stays. The mock's segmented control on S06.02 is not added (S06.01 has none; out of scope, ledgered).
18. **S06.01 assigned bookings:** a second stream `bookings where assigneeId == uid` (single-field index, no composite) merged with the own stream, own document wins on duplicate id. A booking is "assigned" when `photographerId != uid`. Assigned bookings count for "Hôm nay" and "Buổi sắp tới" but never for "Yêu cầu mới", "Tháng này" or "Đang giữ" (the money goes to the studio). The label is "Giao bởi {Studio}" with the studio name from `partyProfileProvider(photographerId)`. The rules gain read for `assigneeId == auth.uid` (studio spec §8; #136 keeps it). A denied or failing assignee stream is treated as empty (logged once) so S06.01 never breaks for everyone.
19. **No Booking model change:** "assigned" is derived from `photographerId != uid`, so `booking.freezed.dart` is not regenerated.

## Needs the owner

1. Tax withheld from individuals: 7% (5% GTGT + 2% TNCN), no exemption threshold, studios 0% (spec M8, "chờ kế toán xác nhận"). **Default:** as stated, in `DEFAULT_PAYOUT_POLICY`; changing it is a one-line PR.
2. Production OTP channel for account changes: an SMS vendor (≈ $0.15/SMS through Firebase Auth, chưa xác nhận) or a local brand-name SMS / Zalo ZNS. **Default:** none until chosen; outside the emulator/dev project `requestPayoutOtp` answers `not_eligible`, so account changes are impossible in production until then (first accounts need no OTP).

## Contract

### Data (Firestore; server-written unless noted)

- `payouts/{id}` adds: `platformFee: int`, `taxWithheld: int`, `amountNet: int` (= `amount` − fee − tax; `amount` stays gross), `feeRateBp: int`, `taxRateBp: int`, `firstPayout: bool`, `approvedBy: string|null`, `approvedAt: Timestamp|null`, `idempotencyKey: string` (= payout id), `provider: 'fake'`; `items[]` add `fee`, `tax`, `net`; `status` adds `needs_approval`; `holdReason` may be `'repeated_failure'`. Old docs read with fee 0, tax 0, net = amount.
- `payoutAccounts/{uid}/accounts/{id}` adds `nameStatus: 'matched'|'pending_review'|'staff_confirmed'`, `activeFrom: Timestamp`; `holderName` is the looked-up name (or the verified name for `review`). The owner view `payoutAccounts/{uid}` adds `activeFrom`, `nameStatus`. Old docs read `nameStatus: 'matched'`, `activeFrom: createdAt`.
- `earnings/{uid}/items/{paymentId}` adds `platformFee`, `taxWithheld`, `netAmount`, `feeRateBp`, `taxRateBp`, `estimated: bool`, `milestonesDone: int|null`, `milestonesTotal: int|null`.
- New, server-only (rules deny all): `otp_challenges/{uid}_payout_account` `{uid, purpose: 'payout_account', codeHash, salt, targetHash, expiresAt, attempts, sentAt, sendDay, sendsToday, consumedAt|null}`; `payout_lookups/{uid}` `{day: 'yyyy-MM-dd', count}`.
- Read only (written by #135): `users/{uid}/private/identity.legalName`. Read only (written by #136): `bookings/{id}.assigneeId`. Read only (written by #129/#130): `bookings/{id}/milestones/{kind}.status`.
- `ledger_entries` types add `tax_withheld`, `platform_fee`.

### Domain (`packages/domain/src`)

```ts
// payout_policy.ts (new)
export interface PayoutPolicy {
  readonly feeBp: Readonly<Record<ProviderType, number>>;
  readonly individualTaxBp: { readonly vat: number; readonly pit: number };
}
export const DEFAULT_PAYOUT_POLICY: PayoutPolicy; // fee 0/0/0, tax vat 500 + pit 200
export interface PayoutLine { readonly gross: number; readonly fee: number; readonly tax: number; readonly net: number; readonly feeRateBp: number; readonly taxRateBp: number }
/** Integer VND; tax only for 'individual' and 'artist'; Math.round per line. */
export function payoutLineOf(gross: number, payee: ProviderType, policy: PayoutPolicy): PayoutLine;

// payout.ts
export const PAYOUT_STATUSES = ['pending', 'needs_approval', 'on_hold', 'processing', 'paid', 'failed'] as const;
export interface PayoutItem { readonly paymentId: string; readonly amount: number; readonly fee: number; readonly tax: number; readonly net: number }
export interface Payout { /* existing fields */ readonly platformFee: number; readonly taxWithheld: number; readonly amountNet: number;
  readonly feeRateBp: number; readonly taxRateBp: number; readonly firstPayout: boolean; readonly approvedBy?: string; readonly approvedAt?: string }
export const HOLD_REASON_REPEATED_FAILURE = 'repeated_failure';
export const MAX_CONSECUTIVE_FAILURES = 3;

// payout_account.ts
export const ACCOUNT_CHANGE_DELAY_HOURS = 72;
export const NAME_LOOKUPS_PER_DAY = 20;
export type NameStatus = 'matched' | 'pending_review' | 'staff_confirmed';
export interface PayoutAccount { /* existing */ readonly nameStatus: NameStatus; readonly activeFrom: string }
export interface PayoutAccountView { /* existing */ readonly nameStatus: NameStatus; readonly activeFrom: string }
export type NameLookupResult = { status: 'found'; holderName: string } | { status: 'unsupported' } | { status: 'not_found' };
export type HolderNameDecision = 'matched' | 'mismatch' | 'review' | 'not_found' | 'unverifiable';
export function holderNameDecision(lookup: NameLookupResult, verifiedName: string | null): HolderNameDecision;
export function isAccountActiveAt(a: Pick<PayoutAccount, 'active' | 'activeFrom'>, now: Date): boolean;

// payout_otp.ts (new)
export const OTP_TTL_SECONDS = 300; export const OTP_MAX_ATTEMPTS = 5; export const OTP_RESEND_SECONDS = 60; export const OTP_MAX_SENDS_PER_DAY = 5;
export interface OtpChallenge { readonly uid: string; readonly purpose: 'payout_account'; readonly codeHash: string; readonly salt: string; readonly targetHash: string;
  readonly expiresAt: string; readonly attempts: number; readonly sentAt: string; readonly sendDay: string; readonly sendsToday: number; readonly consumedAt: string | null }
/** 6 digits from 4 random bytes (u32 % 1e6, zero-padded). */
export function otpCodeFrom(bytes: Uint8Array): string;
export type OtpVerdict = 'ok' | 'required' | 'expired' | 'too_many' | 'wrong';
/** required = missing, consumed or bound to another account. */
export function checkOtp(c: OtpChallenge | null, given: { codeHash: string; targetHash: string }, now: Date): OtpVerdict;

// payout_ports.ts (additions)
export interface AccountNameLookup { lookup(r: { bankCode: string; accountNumber: string }): Promise<NameLookupResult> }
export interface VerifiedNameReader { legalName(uid: string): Promise<string | null> }
export interface OtpSender { send(r: { phone: string; code: string; purpose: 'payout_account' }): Promise<void> }
export interface OtpPhoneReader { phoneOf(uid: string): Promise<string | null> }
export interface OtpCrypto { sha256Hex(input: string): Promise<string>; random(n: number): Uint8Array }
export interface PayoutNotices {
  accountNeeded(payeeId: string, amount: number): Promise<void>;
  accountChanged(uid: string, v: { bankCode: string; accountLast4: string; activeFrom: string }): Promise<void>;
}
// PayoutTx gains (all reads before writes inside a transaction):
//   getPayeeType(uid): Promise<ProviderType>
//   getOtpChallenge(uid): Promise<OtpChallenge | null>; putOtpChallenge(c: OtpChallenge): void
//   getLookupQuota(uid): Promise<{ day: string; count: number } | null>; putLookupQuota(uid, q): void
// PayoutStore gains: listPayoutIdsByStatus(statuses: readonly PayoutStatus[], limit: number): Promise<string[]>
// PayoutAccountDeps gains: lookup: AccountNameLookup; names: VerifiedNameReader; otp: { sender: OtpSender; phones: OtpPhoneReader; crypto: OtpCrypto }; notices: PayoutNotices
// PayoutDeps gains: policy: PayoutPolicy; notices: PayoutNotices
// EarningsDeps gains: policy: PayoutPolicy; EarningsTx gains getPayeeType(uid): Promise<ProviderType>;
// EarningSubject gains milestones: { done: number; total: number } | null

// payout_use_cases.ts
export const SYSTEM_PAYOUT_ACTOR: StaffActor; // { uid: 'system:createPayouts', isAdmin: true }
export async function approvePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout>; // needs_approval → pending
// createPayout / executePayout / resumePayout change per Decisions 2, 3, 5, 7.

// daily_payouts.ts (new)
export interface DailyPayoutReport { created: number; needsApproval: number; onHold: number; executed: number; paid: number; failed: number; noAccount: number; notActive: number; errors: number }
export async function runDailyPayouts(deps: PayoutDeps, onError?: (id: string, step: 'create' | 'execute', e: unknown) => void): Promise<DailyPayoutReport>;

// save_payout_account.ts (rewritten) and payout_account_use_cases.ts (new)
export interface Caller { readonly uid: string }
/** raw: exactly {bankCode, accountNumber} or {bankCode, accountNumber, otpCode}. */
export async function savePayoutAccount(deps: PayoutAccountDeps, caller: Caller, raw: unknown):
  Promise<{ accountId: string; accountLast4: string; activeFrom: string; nameStatus: NameStatus }>;
export async function lookupPayoutAccountName(deps: PayoutAccountDeps, caller: Caller, raw: unknown):
  Promise<{ decision: HolderNameDecision; holderName: string | null; verifiedName: string | null }>;
export async function requestPayoutOtp(deps: PayoutAccountDeps, caller: Caller, raw: unknown):
  Promise<{ phoneLast4: string; expiresInSeconds: number; resendInSeconds: number }>;

// fake_account_name_lookup.ts, fake_otp_sender.ts (new)
export class FakeAccountNameLookup implements AccountNameLookup { constructor(echoName: string | null) }
export class FakeOtpSender implements OtpSender { readonly sent: { phone: string; code: string }[] }

// payout_notifications.ts (new)
export async function notifyPayoutAccountNeeded(deps: NotifyDeps, e: { payeeId: string; amount: number }): Promise<NotifyResult>;
export async function notifyPayoutAccountChanged(deps: NotifyDeps, e: { uid: string; bankCode: string; accountLast4: string; activeFrom: string }): Promise<NotifyResult>;

// errors.ts ERROR_CODES gains 'name_mismatch', 'otp_required', 'otp_invalid', 'otp_expired'
// escrow.ts LEDGER_ENTRY_TYPES gains 'tax_withheld', 'platform_fee'
```

Notification copy (added to `NotificationContent` and `renderNotification`, verbatim):
- `{ type: 'payout_account_needed'; amount: number }` → title `Thêm tài khoản để nhận ${formatVnd(amount)}`, body `Tiền của bạn đã sẵn sàng chuyển. Thêm tài khoản nhận tiền để nhận mỗi ngày.`; dedupe `payout_account_needed_{payeeId}`.
- `{ type: 'payout_account_changed'; bank: string; last4: string; activeFrom: string /* 'HH:mm dd/MM' VN */ }` → title `Tài khoản nhận tiền đã đổi`, body `${bank} •••• ${last4} có hiệu lực lúc ${activeFrom}. Không phải bạn đổi? Liên hệ hỗ trợ ngay.`; dedupe `payout_account_changed_{accountId}`.

### Callables (region `asia-southeast1`, `CALLABLE_OPTIONS`; errors via `toHttpsError`, `details.code`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `lookupPayoutAccountName` | `{bankCode, accountNumber}` | `{decision, holderName, verifiedName}` | `unauthenticated`, `permission_denied` (not photographer), `invalid_argument`, `limit_exceeded` (21st lookup of the day) |
| `requestPayoutOtp` | `{bankCode, accountNumber}` | `{phoneLast4, expiresInSeconds, resendInSeconds}` | `permission_denied`, `invalid_argument`, `not_eligible` (no current account, or OTP not available outside fake mode), `phone_required`, `limit_exceeded` (resend < 60 s or 6th send of the day) |
| `savePayoutAccount` (v2, `secrets: [PAYOUT_ACCOUNT_KEY]`) | `{bankCode, accountNumber, otpCode?}` | `{accountId, accountLast4, activeFrom, nameStatus}` | `permission_denied`, `invalid_argument`, `name_mismatch`, `not_found`, `not_eligible` (unverifiable), `otp_required`, `otp_invalid`, `otp_expired`, `limit_exceeded` (5 wrong codes), `conflict` (a payout is `processing`) |

`TRANSPORT_CODE`: `name_mismatch`, `otp_required`, `otp_invalid`, `otp_expired` → `failed-precondition`.

Scheduled: `createPayouts` = `onSchedule({ ...SCHEDULE_OPTIONS, schedule: '0 10 * * *', timeZone: 'Asia/Ho_Chi_Minh', timeoutSeconds: 540, secrets: [PAYOUT_ACCOUNT_KEY] }, () => handleCreatePayouts())`.

CLI (`tools/payouts.ts`): `approve <payoutId> --actor <uid>`; `run-daily --actor <uid>` (fake mode only; prints the `DailyPayoutReport`); `due` also lists `needs_approval` payouts as `open:`.

### Rules

```
match /bookings/{bookingId} {
  allow read: if signedIn()
    && (resource.data.customerId == request.auth.uid
        || resource.data.photographerId == request.auth.uid
        || resource.data.get('assigneeId', null) == request.auth.uid);
  ...
}
match /otp_challenges/{id} { allow read, write: if false; }
match /payout_lookups/{uid} { allow read, write: if false; }
```
No new composite index (`assigneeId ==` alone uses the automatic single-field index).

### App (`lib/`)

```dart
// data/earnings/earnings.dart
enum PayoutNameStatus { matched, pendingReview, staffConfirmed } // codes matched | pending_review | staff_confirmed; unknown → matched
enum PayoutNameDecision { matched, mismatch, review, notFound, unverifiable } // codes; unknown → review
class PayoutNameLookup { const PayoutNameLookup({required this.decision, this.holderName, this.verifiedName}); }
class PayoutOtpTicket { const PayoutOtpTicket({required this.phoneLast4, required this.expiresInSeconds, required this.resendInSeconds}); }
// EarningItem gains: feeVnd, taxVnd, netVnd, feeRateBp, taxRateBp (int, default 0 / net = amountVnd), estimated (bool, default true),
//                    milestonesDone (int?), milestonesTotal (int?)
// PayoutAccountView gains: activeFrom (DateTime), nameStatus (PayoutNameStatus); bool pendingAt(DateTime now) => activeFrom.isAfter(now)
// PayoutAccountError codes add: name_mismatch, not_found, not_eligible, otp_required, otp_invalid, otp_expired, limit_exceeded, phone_required

// data/earnings/earnings_repository.dart (interface + FakeEarningsRepository)
Future<PayoutNameLookup> lookupAccountName({required String bankCode, required String accountNumber});
Future<PayoutOtpTicket> requestAccountOtp({required String bankCode, required String accountNumber});
Future<({String accountId, String accountLast4, DateTime activeFrom})> saveAccount({required String bankCode, required String accountNumber, String? otpCode});

// data/booking/booking_repository.dart
Stream<List<Booking>> watchAssignedBookings(String uid); // assigneeId == uid, drafts dropped
// data/booking/booking_providers.dart
final assignedBookingsProvider = StreamProvider.autoDispose<List<Booking>>(...); // error → empty list (logged)
final myWorkBookingsProvider = Provider.autoDispose<AsyncValue<List<Booking>>>(...); // own ∪ assigned, own wins
// data/photographer/photographer_intro.dart: PhotographerIntro gains `final bool acceptingOrders;` (mapping as Decision 17)
// features/verification/verification_routes.dart (new)
final verifyStartReadyProvider = Provider<bool>((ref) => false); // #135 flips to true
const verifyStartPath = '/verify/start';
// features/booking/booking_view_rules.dart
WorkDashboard workDashboard(List<Booking> mine, DateTime now, {required String uid});
// core: BookingSummary gains `final String? tag;` (BookingCard draws a pill with AppIcons.store);
//       EmptyState gains `final String? note;` (caption under body); AppIcons.verifiedUser = Symbols.verified_user_rounded;
//       EarningRow gains `final List<EarningBreakdownLine>? breakdown; final bool expanded;` and `class EarningBreakdownLine {label, value, strong}`;
//       new OtpCodeField({required TextEditingController controller, String? errorText, ValueChanged<String>? onCompleted}) (6 digits, AutofillHints.oneTimeCode)
// features/earnings/widgets/name_lookup_card.dart (new): NameLookupCard({required PayoutLookupView view})
// features/earnings/widgets/payout_otp_sheet.dart (new):
Future<bool> showPayoutOtpSheet(BuildContext context, {required PayoutOtpTicket ticket,
  required Future<PayoutOtpSubmit> Function(String code) onSubmit, required Future<PayoutOtpTicket?> Function() onResend});
enum PayoutOtpSubmit { saved, wrong, expired, tooMany, failed }
```

l10n keys (key: exact text). Changed values: `earningsSoon`: "Chờ chi trả"; `earningsNotice`: "Chi tự động mỗi ngày · lần chi đầu do staff duyệt · phí chuyển do nền tảng trả"; `payoutAccountIntro`: "Nhập tài khoản đứng tên bạn, tiền sẽ chi tự động vào đây."; `payoutAccountHint`: "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài khoản được mã hoá, chỉ hiện 4 số cuối.". Removed: `payoutAccountHolder`, `payoutAccountHolderError`, `payoutAccountChangeTitle`, `payoutAccountChangeBody`, `payoutAccountChangeConfirm`, `payoutAccountReauthTitle`, `payoutAccountReauthBody`, `payoutAccountReauthPassword`, `payoutAccountReauthGo`, `payoutAccountReauthWrong`. New:
- `earningsBreakdownReleased`: "Đã chuyển theo mốc" · `earningsBreakdownAmount`: "Số tiền" · `earningsBreakdownFee`: "Hoa hồng ({percent})" · `earningsBreakdownTax`: "Thuế khấu trừ ({percent})" · `earningsBreakdownNet`: "Thực nhận" · `earningsBreakdownNetEstimated`: "Thực nhận dự kiến" · `earningsMilestones`: "mốc {done}/{total}" · `earningsMilestonesAll`: "đủ {total} mốc" (`percent` is a pre-formatted String like "7%" or "7,5%").
- `payoutAccountIntroChange`: "Đang dùng {bank} •••• {last4}. Nhập tài khoản mới đứng tên bạn, tiền sẽ chi tự động vào đây." · `payoutAccountChangeNote`: "Đổi tài khoản cần OTP và có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi. Tài khoản cũ sẽ nhận thông báo."
- `payoutLookupLoading`: "Đang tra tên chủ tài khoản…" · `payoutLookupMatched`: "Khớp tên đã xác minh" · `payoutLookupMismatch`: "Không khớp" · `payoutLookupMismatchTitle`: "Tên chủ tài khoản không khớp tên đã xác minh ({name})" · `payoutLookupMismatchBody`: "Chỉ chi tiền vào tài khoản đứng tên bạn. Kiểm tra lại ngân hàng và số tài khoản." · `payoutLookupReview`: "Ngân hàng chưa hỗ trợ tra tên" · `payoutLookupReviewSub`: "Staff đối chiếu tên trước lần chi đầu" · `payoutLookupNotFound`: "Không tìm thấy tài khoản. Kiểm tra lại số tài khoản." · `payoutLookupUnverifiable`: "Cần xác minh danh tính trước khi thêm tài khoản ở ngân hàng này" · `payoutLookupLimit`: "Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai." · `payoutLookupError`: "Không tra được tên. Thử lại"
- `payoutOtpTitle`: "Nhập mã xác nhận" · `payoutOtpBody`: "Mã 6 số đã gửi tới số điện thoại •••• {last4}. Mã có hiệu lực 5 phút." · `payoutOtpField`: "Mã OTP" · `payoutOtpConfirm`: "Xác nhận đổi tài khoản" · `payoutOtpResend`: "Gửi lại mã" · `payoutOtpResendIn`: "Gửi lại sau {seconds} giây" · `payoutOtpNote`: "Tài khoản mới có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi." · `payoutOtpWrong`: "Mã chưa đúng. Kiểm tra lại tin nhắn" · `payoutOtpExpired`: "Mã đã hết hạn. Gửi lại mã mới" · `payoutOtpTooMany`: "Bạn đã nhập sai quá nhiều lần. Gửi lại mã mới" · `payoutOtpLimit`: "Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai." · `payoutPhoneRequired`: "Cần số điện thoại trong hồ sơ để nhận mã" · `payoutOtpUnavailable`: "Chưa đổi được tài khoản lúc này. Liên hệ hỗ trợ"
- `payoutAccountPendingTitle`: "Tài khoản mới có hiệu lực lúc {time}" · `payoutAccountPendingBody`: "Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do staff duyệt." · `payoutAccountPendingBadge`: "Chờ hiệu lực" · `payoutAccountReviewNote`: "Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu." · `payoutAccountChangeSaved`: "Đã đổi tài khoản. Có hiệu lực sau 72 giờ"
- `workAssignedBy`: "Giao bởi {studio}" · `workClosedTitle`: "Mở nhận đơn để khách đặt được bạn" · `workClosedBody`: "Bạn vẫn đăng portfolio, tạo gói và trò chuyện. Khách chỉ đặt lịch và xin báo giá sau khi bạn xác minh: số điện thoại, phí xác minh, danh tính và quy định nhận việc." · `workClosedNote`: "Staff duyệt trong 24 giờ sau khi bạn gửi" · `workClosedStart`: "Bắt đầu nhận đơn"

Notification visuals/targets (append): `notificationVisualOf('payout_account_needed')` → `(AppIcons.payment, NotificationTone.action)`; `'payout_account_changed'` → `(AppIcons.lock, NotificationTone.action)`. `safeTarget` allows `/work/earnings` and `/work/earnings/account` (no query); skip a line if #138 already added it.

## Review Focus

1. **The name lookup used as an oracle** for other people's account names: 21 lookups in one Vietnam day must be refused, non-photographers refused, and no number ever logged. Pinned in Task 3 (`lookupPayoutAccountName: the 21st lookup of the day is limit_exceeded; the count resets the next Vietnam day`) and Task 5 (`lookup callable logs only the code`).
2. **OTP brute force and replay:** a wrong code must be counted even though the call fails (the transaction must commit the increment before refusing), the 6th try is refused even with the right code, a used code cannot save a second account, and a code requested for one account cannot save another. Pinned in Task 3 (`wrong codes are counted across calls…`, `a consumed code is otp_required`, `a code for another account is otp_required`).
3. **Money moving during the 72 hours or to an unapproved new account:** a payout pending at the time of the change must become `needs_approval`, the daily run must skip the payee until `activeFrom`, and `executePayout` must refuse before `activeFrom`. Pinned in Task 2 (`executePayout refuses before the account's activeFrom`) and Task 3 (`a change re-points open payouts and sends them to needs_approval`).
4. **Tax arithmetic and the ledger:** per payment `payout_paid + tax_withheld + platform_fee == −amount`, the transfer sends `amountNet`, a studio has no tax, and the S06.05 breakdown equals the payout item. Pinned in Task 2 (`ledger nets each paid payment to −amount`, `transfer receives amountNet`) and Task 7 (`paid row breakdown shows 1.500.000₫ · 105.000₫ · 1.395.000₫`).
5. **S06.01 breaks for every photographer** if the new `assigneeId` query is denied (rules not yet deployed, or a stale client): the assignee stream error must yield an empty list, not an error state. Pinned in Task 9 (`a failing assigned stream still shows the dashboard`) and the rules test in Task 5.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` (Firestore: nam5 upper bound $0.06/100K reads, $0.18/100K writes, **chưa xác nhận** for Singapore; Functions Tier 2 inside the free tier at these volumes; Scheduler $0.10/job/month beyond 3 free per billing account; SMS VN $0.15 **chưa xác nhận**). Scale: (b) 1,000 MAU, 100 photographers, ~300 bookings/month; (c) 10,000 MAU, 1,000 photographers, ~3,000 bookings/month.

| User action / job | Reads | Writes | Notes |
|---|---|---|---|
| Open S06.05 | unchanged (summary doc + 20 rows, listeners as in 10b) | 0 | new fields ride on the existing projection docs |
| Open S06.01 (photographer) | +1 (empty `assigneeId` query; listener only while the tab is mounted) | 0 | (b) 100 × 30 opens = 3K/month; (c) 30K/month |
| S06.06 lookup (debounced) | 3 (role, quota, identity) | 1 (quota) | ~2 per account set-up; (b) ~60 calls/month, (c) ~600 |
| S06.06 request OTP | 4 (role, account, challenge, phone) | 1 | changes only: (b) ~2/month, (c) ~20/month |
| S06.06 save | ~8 (+ open payouts) | 3–6 | as in 10b plus identity + challenge |
| `createPayouts` daily | per due payment ≈ 2 (listDuePayees: payment + refunds query) + per payee ≈ 6 + per payout execute ≈ 3 × (2 + n) | per payout ≈ 3 + 2n + up to 3n ledger | plus existing `onPayoutWritten`/`onPaymentWritten` refreshes, each now +2 reads (payee type, milestones query) |

- New callables: `lookupPayoutAccountName` (b) ~60/month, (c) ~600; `requestPayoutOtp` (b) ~2, (c) ~20; 256 MiB, 10 s. Negligible against the 2M free invocations.
- New scheduled job: `createPayouts`, daily (30 runs/month), the repo's 7th job → **+$0.10/month** (Scheduler). Reads per run ≈ 10 per paid-out payment: (b) ~300 payments/month → ~3K reads + refresh triggers ~20K reads/month; (c) ~3,000 payments → ~30K + ~200K reads/month. Frequency is daily, not minutes.
- No new Storage path. No Maps. SMS: none now (fake). When a real OTP adapter lands: (b) ~2 × $0.15 = $0.30, (c) ~20 × $0.15 = $3/month (**chưa xác nhận**). Name lookup and payouts are charged by the payment intermediary (outside Google).
- **Conclusion:** (b) ≈ **+$0.12/month** (Scheduler $0.10 + ~25K reads), (c) ≈ **+$0.30/month** (Scheduler + ~260K reads ≈ $0.16 + writes ≈ $0.05); +$3/month at (c) once real SMS OTP exists. Below the $5 threshold.

## Tasks

### Task 1: Mock frames for the new S06 states

**Files:**
- Modify: `docs/design/ui-mock.html` (S06 section only)

**Interfaces:** none (design source). Later tasks build to these frame ids.

- [ ] **Step 1:** Read the S06 section (`<h2 id="S06">` … end of its `.rail`) and reuse its classes (`.step`, `.phone`, `.scr`, `.sb`, `.body`, `.bar`, `.field`, `.lkp`, `.warnc`, `.lockn`, `.sheet`, `.grab`, `.h3`, `.btn pri`, `.btn out`, `.meta x`, `.irow2 x`, `.brk`, `.ptag`, `.cap`, Material Symbols `<span class="ms">`).
- [ ] **Step 2:** Edit `#S06.05`: make the "Thu Hà · Kỷ yếu nửa ngày" row expanded (`class="irow2 x" aria-expanded="true"`) with `<div class="brk"><div><span>Số tiền</span><span class="tn">1.500.000₫</span></div><div><span>Thuế khấu trừ (7%)</span><span class="tn">105.000₫</span></div><div><span>Thực nhận dự kiến</span><span class="tn">1.395.000₫</span></div></div>`; add to its caption: "Khoản chưa chuyển bung ra Số tiền, Thuế khấu trừ và Thực nhận dự kiến; studio không có dòng thuế."
- [ ] **Step 3:** Add after `#S06.01` a frame `id="S06.01-assigned"` (`data-code="S06.01"`): same bar as S06.01; the today card shows "Hôm nay · 09:00", "Ngọc Mai · Cưới hỏi nửa ngày", "Nhà thờ Đức Bà · đã thanh toán" and under the title a pill `<span class="ptag"><span class="ms">storefront</span>Giao bởi Studio Ánh Dương</span>`; KPI row "4,2M Tháng này · 1,5M Đang giữ · 3 Buổi sắp tới". Caption: `<span class="n new">Mới</span><span class="n">S06.01 · Buổi studio giao</span><b>Biết buổi nào do studio giao</b><span>Booking studio đã giao cho thợ hiện ở Hôm nay và Buổi sắp tới với nhãn "Giao bởi {Studio}". Không tính vào Tháng này và Đang giữ: tiền về studio. Studio trả lời yêu cầu, nên buổi giao không nằm trong Yêu cầu mới.</span>`.
- [ ] **Step 4:** Add after `#S06.06-mismatch` three frames (all `data-code="S06.06"`):
  - `id="S06.06-review"`: bank field "Techcombank" ("Ngân hàng TMCP Kỹ thương Việt Nam"), number field "1903 5566 9999", a `.lkp` with icon `info` (neutral, not `.bad`) and `<b>Ngân hàng chưa hỗ trợ tra tên</b><span>Staff đối chiếu tên trước lần chi đầu</span>`, the hint line "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài khoản được mã hoá, chỉ hiện 4 số cuối.", foot `.btn pri` "Lưu tài khoản" (enabled). Caption: "Mới · S06.06 · Chưa tra được tên — Ngân hàng không hỗ trợ tra tên: vẫn lưu được, tài khoản chờ staff đối chiếu; lần chi đầu do staff duyệt."
  - `id="S06.06-otp"`: behind, the change form (intro "Đang dùng MB •••• 3456. Nhập tài khoản mới đứng tên bạn, tiền sẽ chi tự động vào đây.", bank "Techcombank", number "1903 5566 7788", `.lkp` matched "NGUYEN MINH TRI · Khớp tên đã xác minh"); `.dim` + `.sheet`: `.grab`, `.h3` "Nhập mã xác nhận", `.meta x` "Mã 6 số đã gửi tới số điện thoại •••• 4567. Mã có hiệu lực 5 phút.", `.field foc` `<small>Mã OTP</small><span class="tn">4 8 2 _ _ _</span>`, centred `.meta x` "Gửi lại sau 42 giây", `.lockn` (lock) "Tài khoản mới có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi.", `.btn pri` "Xác nhận đổi tài khoản". Caption: "Mới · S06.06 · Nhập OTP khi đổi — Mã gửi tới số điện thoại trong hồ sơ, hiệu lực 5 phút, sai 5 lần phải gửi lại mã; gửi lại sau 60 giây, tối đa 5 lần một ngày. Không có OTP khi thêm tài khoản lần đầu."
  - `id="S06.06-pending"`: read view: card (bank badge "TCB", `<b>Techcombank •••• 7788</b>`, meta "NGUYEN MINH TRI", `.badge b-warn` "Chờ hiệu lực"); card with icon `schedule`: `<b>Tài khoản mới có hiệu lực lúc 10:15, 13/10</b>` and "Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do staff duyệt."; `.btn out` "Đổi tài khoản". Caption: "Mới · S06.06 · Chờ 72 giờ — Sau khi đổi, tài khoản mới hiện ngay nhưng chỉ nhận tiền từ thời điểm hiệu lực; trong lúc chờ không chi vào tài khoản nào."
- [ ] **Step 5:** Open the file in a browser (or check the HTML is well formed with `python3 -c "import html.parser,sys;html.parser.HTMLParser().feed(open('docs/design/ui-mock.html').read())"`); `#S06.06-otp` and the other ids resolve.
- [ ] **Step 6: Commit** `docs(mock): S06 assigned booking, payout account review, OTP and 72-hour states [#134]` (TonyH trailer).

### Task 2: Domain — payout policy, tax, approval and the daily run

**Files:**
- Create: `packages/domain/src/payout_policy.ts`, `packages/domain/src/daily_payouts.ts`, `packages/domain/test/payout_policy.test.ts`, `packages/domain/test/daily_payouts.test.ts`
- Modify: `packages/domain/src/payout.ts`, `payout_ports.ts`, `payout_use_cases.ts`, `escrow.ts` (ledger types), `earnings.ts`, `earnings_ports.ts`, `refresh_earnings.ts`, `memory_payout_store.ts`, `memory_earnings_store.ts`, `index.ts`, `test/support/payout_world.ts`, `test/payout_use_cases.test.ts`, `test/earnings.test.ts`, `test/refresh_earnings.test.ts`

**Interfaces:**
- Produces: `PayoutPolicy`, `DEFAULT_PAYOUT_POLICY`, `PayoutLine`, `payoutLineOf`, `PAYOUT_STATUSES` with `needs_approval`, `PayoutItem.fee/tax/net`, `Payout` money fields, `HOLD_REASON_REPEATED_FAILURE`, `MAX_CONSECUTIVE_FAILURES`, `SYSTEM_PAYOUT_ACTOR`, `approvePayout`, `runDailyPayouts`, `DailyPayoutReport`, `PayoutNotices`, `PayoutTx.getPayeeType`, `PayoutStore.listPayoutIdsByStatus`, `PayoutDeps.policy/notices`, `EarningItem` breakdown fields, `EarningsTx.getPayeeType`, `EarningSubject.milestones`, `EarningsDeps.policy`, ledger types `tax_withheld`, `platform_fee` (Contract).
- `PayoutAccount` gains `nameStatus` and `activeFrom` already here (needed by `createPayout`); the save path that writes them is Task 3. `payout_world.ts` `addAccount` writes an account directly into the memory store with `nameStatus: 'matched'`, `activeFrom: now` until Task 3 replaces it.

- [ ] **Step 1:** Contract check of the domain names above; ledger differences.
- [ ] **Step 2: Failing tests.**
  `payout_policy.test.ts`:
  - `individual: 1,500,000 → tax 105,000, net 1,395,000, taxRateBp 700`.
  - `artist pays the individual tax; studio pays none`.
  - `fee bp applies before tax and both round per line` (policy fee 1000 bp on 450,500 → fee 45,050, tax 31,535, net 373,915).
  - `zero and one đồng stay integers` (no NaN, no negative net).
  `payout_use_cases.test.ts` (extend):
  - `createPayout snapshots fee, tax and net per item and in total` (two payments 450,000 + 1,500,000 → tax 31,500 + 105,000; `amountNet` = Σ net).
  - `the first payout to an account is needs_approval; the next one is pending`.
  - `a pending_review account always gets needs_approval`.
  - `three failed payouts in a row to the account make the next one on_hold with repeated_failure`.
  - `createPayout refuses before the account's activeFrom (not_eligible)`.
  - `approvePayout: needs_approval → pending with approvedBy/approvedAt; any other status is conflict; non-admin permission_denied`.
  - `approvePayout confirms a pending_review account (staff_confirmed) and its owner view`.
  - `executePayout refuses a needs_approval payout (conflict)`.
  - `executePayout refuses before the account's activeFrom (not_eligible) and writes nothing`.
  - `transfer receives amountNet` (FakePayoutGateway call amount).
  - `ledger nets each paid payment to −amount` (payout_paid −net, tax_withheld −tax; no zero-amount platform_fee entry).
  - `resumePayout goes to needs_approval when the account has no paid payout`.
  `daily_payouts.test.ts`:
  - `creates one payout per due payee and executes it the same run` (report `created 1, paid 1` for an account with a paid history).
  - `a first payout waits for approval and is not executed` (report `needsApproval 1, executed 0`).
  - `a payee without an account calls notices.accountNeeded with the payee and the amount and creates no payout` (report `noAccount 1`; the one-row-per-payee dedupe is pinned in Task 3's `payout_notifications.test.ts`).
  - `a payee inside the 72 hours is skipped (notActive 1)`.
  - `running twice creates nothing new` (second report `created 0`, gateway calls unchanged).
  - `one payee's failure does not stop the others` (store throws for p2 → `errors 1`, p1 paid, `onError` called with p2's id and step `create`).
  - `a failed transfer is counted and the money is payable again next run` (number ending `0000`).
  `earnings.test.ts` / `refresh_earnings.test.ts`:
  - `a paid-out row carries the payout item's fee, tax and net (estimated false)`.
  - `a held row carries the policy estimate (estimated true); a studio row has tax 0`.
  - `milestones from the subject reach the row; null when absent`.
- [ ] **Step 3:** `cd packages/domain && npm test` → the new tests fail.
- [ ] **Step 4: Implement.** `payoutLineOf` per Decision 1–2. `createPayout`: read account (`not_eligible` when none or `!isAccountActiveAt`), payee type, payable payments, refunds, paid/failed history (all reads first), then build items with `payoutLineOf(net, payeeType, deps.policy)` and the status per Decision 5. `executePayout`: refuse `needs_approval` (existing `conflict` check), check `activeFrom` in the first (read-only) transaction, transfer `amountNet` (fallback `amount` for old docs), write the ledger per Decision 3. `runDailyPayouts`:
  ```ts
  export async function runDailyPayouts(deps: PayoutDeps, onError = () => undefined): Promise<DailyPayoutReport> {
    const r: DailyPayoutReport = { created: 0, needsApproval: 0, onHold: 0, executed: 0, paid: 0, failed: 0, noAccount: 0, notActive: 0, errors: 0 };
    for (const due of await deps.store.listDuePayees()) {
      if (!due.hasAccount) { r.noAccount += 1; await deps.notices.accountNeeded(due.payeeId, due.amount).catch((e) => onError(due.payeeId, 'create', e)); continue; }
      try {
        const p = await createPayout(deps, SYSTEM_PAYOUT_ACTOR, due.payeeId);
        r.created += 1;
        if (p.status === 'needs_approval') r.needsApproval += 1;
        if (p.status === 'on_hold') r.onHold += 1;
      } catch (e) {
        if (e instanceof DomainError && e.code === 'not_eligible') { r.notActive += 1; continue; } // no money left or account not active yet
        r.errors += 1; onError(due.payeeId, 'create', e);
      }
    }
    for (const id of await deps.store.listPayoutIdsByStatus(['pending'], 200)) {
      try {
        const done = await executePayout(deps, SYSTEM_PAYOUT_ACTOR, id);
        r.executed += 1;
        if (done.status === 'paid') r.paid += 1; else r.failed += 1;
      } catch (e) {
        if (e instanceof DomainError && e.code === 'not_eligible') { r.notActive += 1; continue; }
        r.errors += 1; onError(id, 'execute', e);
      }
    }
    return r;
  }
  ```
  `listDuePayees().hasAccount` must mean "has an account doc" (unchanged); a payee whose account is inside the 72 hours lands in `notActive` through `createPayout`'s `not_eligible`. Earnings: `earningItemOf` gains `payeeType` and `policy` inputs (paid-out rows read the payout item by `paymentId`); `refreshEarnings` passes `await tx.getPayeeType(payeeId)` and `deps.policy`. Memory stores implement the new methods (refuse a read after a write in a transaction, like `memory_album_store.ts`).
- [ ] **Step 5:** `npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): payout tax line, first-payout approval and the daily payout run [#134]`.

### Task 3: Domain — payout account v2: name lookup, match, OTP, 72 hours, notices

**Files:**
- Create: `packages/domain/src/payout_otp.ts`, `payout_account_use_cases.ts`, `fake_account_name_lookup.ts`, `fake_otp_sender.ts`, `payout_notifications.ts`; tests `packages/domain/test/payout_otp.test.ts`, `payout_account_use_cases.test.ts`, `payout_notifications.test.ts`
- Modify: `packages/domain/src/payout_account.ts`, `save_payout_account.ts`, `payout_ports.ts`, `errors.ts`, `notification.ts`, `notification_render.ts`, `memory_payout_store.ts`, `index.ts`, `test/support/payout_world.ts`, `test/save_payout_account.test.ts`, `test/payout_account.test.ts`, `test/notification_render.test.ts`

**Interfaces:**
- Consumes: Task 2 `PayoutAccount.nameStatus/activeFrom`, `PayoutNotices`, statuses.
- Produces: `holderNameDecision`, `isAccountActiveAt`, `ACCOUNT_CHANGE_DELAY_HOURS`, `NAME_LOOKUPS_PER_DAY`, OTP model and `checkOtp`/`otpCodeFrom`, ports `AccountNameLookup`, `VerifiedNameReader`, `OtpSender`, `OtpPhoneReader`, `OtpCrypto`, `PayoutTx` OTP/quota methods, `savePayoutAccount` v2, `lookupPayoutAccountName`, `requestPayoutOtp`, `FakeAccountNameLookup`, `FakeOtpSender`, `notifyPayoutAccountNeeded`, `notifyPayoutAccountChanged`, error codes `name_mismatch`, `otp_required`, `otp_invalid`, `otp_expired`, notification types `payout_account_needed`, `payout_account_changed` (Contract). `payout_world.ts` gains `names: Map<uid, legalName>`, `phones: Map<uid, phone>`, a `FakeOtpSender`, a deterministic `OtpCrypto` (sha256 via a tiny pure test hash is fine, or `node:crypto` in the test support only — never in `src/`), and `addAccount(w, number?)` going through `savePayoutAccount` again.

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests.**
  `payout_account.test.ts`: `holderNameDecision` table — `found "Nguyễn Văn An" vs verified "NGUYEN VAN AN" → matched`; `found "TRAN VAN B" vs "NGUYEN VAN AN" → mismatch`; `not_found → not_found`; `unsupported + verified → review`; `found + no verified → review`; `unsupported + no verified → unverifiable`; `extra spaces and lower case still match`.
  `payout_otp.test.ts`: `otpCodeFrom gives 6 digits, zero padded`; `checkOtp: missing → required; consumed → required; other target → required; expired → expired; attempts 5 → too_many; wrong hash → wrong; right → ok`.
  `save_payout_account.test.ts` (rewrite the suite):
  - `first account: no OTP, active at once, nameStatus matched, holder = looked-up name`.
  - `refuses holderName in the input (invalid_argument)` and `refuses unknown keys`.
  - `mismatch is name_mismatch and writes nothing`; `not_found is not_found`; `unverifiable is not_eligible`.
  - `unsupported bank with a verified name saves pending_review with the verified name as holder`.
  - `a change without otpCode is otp_required`.
  - `a change with the right code: old account inactive, new active from now + 72 h, view updated, notices.accountChanged called`.
  - `wrong codes are counted across calls and the 6th try is limit_exceeded even with the right code` (Review Focus 2: the attempt counter is persisted although the call fails).
  - `a consumed code is otp_required` (second save with the same code).
  - `a code for another account is otp_required` (OTP requested for number A, save with number B).
  - `an expired code is otp_expired`.
  - `a change re-points open payouts and sends them to needs_approval` (Review Focus 3).
  - `a change while a payout is processing is conflict`.
  - `the account number never appears in a thrown error or a stored field except accountNumberEnc` (scan all stored docs and error messages for the digits).
  `payout_account_use_cases.test.ts`:
  - `lookupPayoutAccountName returns decision, holder and verified name`.
  - `lookupPayoutAccountName: the 21st lookup of the day is limit_exceeded; the count resets the next Vietnam day` (Review Focus 1; clock at 23:59 and 00:01 UTC+7).
  - `lookup by a customer is permission_denied`.
  - `requestPayoutOtp sends a 6-digit code to the photographer's phone and stores only its hash` (FakeOtpSender has the code; the stored challenge has no plain code).
  - `requestPayoutOtp without a current account is not_eligible`; `without a phone is phone_required`.
  - `a resend within 60 s is limit_exceeded; the 6th send of the day is limit_exceeded`.
  - `a resend replaces the code (old code is otp_required at save)`.
  `payout_notifications.test.ts` (with `createNotifyWorld`):
  - `account needed: title "Thêm tài khoản để nhận 1.500.000₫", target /work/earnings/account, one row for two calls`.
  - `account changed: critical (inbox even when the booking channel is off), body names bank, last 4 and "HH:mm dd/MM"`.
  `notification_render.test.ts`: both new copies verbatim.
- [ ] **Step 3:** `npm test` → fail.
- [ ] **Step 4: Implement.** `savePayoutAccount` v2: validate keys (`otpCode` optional, 6 digits), bank, number; read the verified name and run the lookup **outside** the transaction; decide (`holderNameDecision`), refuse per Decision 12; encrypt; then one transaction that reads everything first and returns a refusal code instead of throwing when an attempt must be persisted:
  ```ts
  const outcome = await deps.store.runTransaction(async (tx) => {
    if ((await tx.getUserRole(caller.uid)) !== 'photographer') throw new DomainError('permission_denied');
    const now = deps.clock.now();
    const current = await tx.getActiveAccount(caller.uid);
    const processing = current ? await tx.listPayouts(caller.uid, ['processing']) : [];
    const open = current ? await tx.listPayouts(caller.uid, ['pending', 'needs_approval', 'on_hold']) : [];
    const challenge = current ? await tx.getOtpChallenge(caller.uid) : null;
    if (current !== null) {
      if (otpCode === undefined) throw new DomainError('otp_required');
      if (processing.length > 0) throw new DomainError('conflict');
      const given = {
        codeHash: challenge ? await deps.otp.crypto.sha256Hex(`${challenge.salt}:${otpCode}`) : '',
        targetHash: challenge ? await deps.otp.crypto.sha256Hex(`${challenge.salt}:${bank.code}:${number}`) : '',
      };
      const verdict = checkOtp(challenge, given, now);
      if (verdict === 'wrong') {
        tx.putOtpChallenge({ ...challenge!, attempts: challenge!.attempts + 1 }); // committed, then refused below
        return { refused: 'otp_invalid' as const };
      }
      if (verdict === 'required') throw new DomainError('otp_required');
      if (verdict === 'expired') throw new DomainError('otp_expired');
      if (verdict === 'too_many') throw new DomainError('limit_exceeded');
      tx.putOtpChallenge({ ...challenge!, consumedAt: now.toISOString() });
      tx.putAccount({ ...current, active: false, deactivatedAt: now.toISOString() });
    }
    // new account: activeFrom = current ? now + 72 h : now; nameStatus per decision; re-point `open`
    // (pending → needs_approval); putAccountView with activeFrom and nameStatus
    return { refused: null, accountId, activeFrom, nameStatus };
  });
  if (outcome.refused !== null) throw new DomainError(outcome.refused);
  if (current-changed) await deps.notices.accountChanged(...).catch(() => undefined); // never fails the save
  ```
  `lookupPayoutAccountName`: role check and quota in one transaction (`count >= 20` on the same VN day → `limit_exceeded`; else increment), then the lookup and the verified name outside it; return the decision. `requestPayoutOtp`: role, current account (else `not_eligible`), phone (else `phone_required`), resend/day limits from the stored challenge, new code via `otpCodeFrom(deps.otp.crypto.random(4))`, salt = 16 random bytes hex, store hashes, send **after** the commit, return `{ phoneLast4, expiresInSeconds: 300, resendInSeconds: 60 }`. Notification types per Decision 13 and Contract copy (`formatVnTime`/`formatVnDate` → `HH:mm dd/MM`).
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): payout account name match, OTP and 72-hour change [#134]`.

### Task 4: Functions — payouts mapping, `createPayouts` job, CLI, earnings projection, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/scheduled/create_payouts.ts`, `test/unit/create_payouts.test.ts`, `test/integration/create_payouts.test.ts` (written, not run)
- Modify: `src/infra/payout_firestore.ts` (payout/item/account/view fields, `getPayeeType`, `listPayoutIdsByStatus`), `src/infra/earnings_firestore.ts` (item fields, `getPayeeType`, milestones in `getSubject`), `src/infra/live_payout.ts` (`policy`, `notices` via `livePayoutNotices()`), `src/index.ts` (`createPayouts`), `tools/payouts.ts` (`approve`, `run-daily`, `due` lists `needs_approval`), `seed/fixtures.ts`, `seed/README.md`, `test/unit/payout_cli.test.ts`, `test/unit/earnings_firestore.test.ts`, `test/unit/seed_fixtures.test.ts`

**Interfaces:**
- Consumes: Task 2 domain.
- Produces:
  ```ts
  // scheduled/create_payouts.ts
  export async function handleCreatePayouts(
    deps?: PayoutDeps,           // default: livePayoutDeps(PAYOUT_ACCOUNT_KEY.value(), payoutGateway()) + policy + notices
    mode: 'fake' | 'off' = payoutsMode(),
  ): Promise<DailyPayoutReport | null>; // null and a log line when mode is off
  // infra/live_payout.ts
  export function livePayoutNotices(): PayoutNotices; // notifyPayoutAccountNeeded/Changed with liveNotifyDeps(); errors logged by code only
  ```
  Logging: `logger.info('createPayouts', report)`; per-item errors `logger.error('createPayouts item failed', { id, step, code })` — never an account number.

- [ ] **Step 1:** Contract check of the Functions files; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `create_payouts.test.ts`: `off mode creates nothing and returns null`; `fake mode runs the daily payouts and logs the report` (in-memory `PayoutDeps` from the domain's memory stores); `a thrown error of one payee is logged with the payee id and code only`.
  - `payout_cli.test.ts`: `approve needs --actor and an admin`; `approve moves needs_approval to pending`; `run-daily is refused in off mode`; `run-daily prints the report`; `due shows needs_approval payouts as open`.
  - `earnings_firestore.test.ts`: `item round-trips fee, tax, net, rates, estimated and milestones`; `old items without the fields read net = amount, estimated true`.
  - Payout mapping (in `earnings_firestore.test.ts`, where `payoutToFirestore` is tested today): `payout round-trips money fields and needs_approval`; `an old payout reads fee 0, tax 0, net = amount, firstPayout false`; `an old account reads nameStatus matched and activeFrom = createdAt`.
  - `seed_fixtures.test.ts`: `An's seeded payout has tax 31,500 and net 418,500 with a tax_withheld ledger entry`; `An's account is matched and active from SEED_CREATED_AT`; `An has an identity legalName`.
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` → fail.
- [ ] **Step 4: Implement.** Mapping per Contract; `getSubject` reads `bookings/{id}/milestones` (count `status == 'released'` / total; no docs → `null`); `getPayeeType` reads `photographers/{uid}.providerType` via `providerTypeOf`. Export in `index.ts`:
  ```ts
  /** Daily 10:00 Asia/Ho_Chi_Minh: batch released money per payee and send it (fake gateway only; off elsewhere). */
  export const createPayouts = onSchedule(
    { ...SCHEDULE_OPTIONS, schedule: '0 10 * * *', timeZone: 'Asia/Ho_Chi_Minh', timeoutSeconds: 540, secrets: [PAYOUT_ACCOUNT_KEY] },
    async () => { await handleCreatePayouts(); },
  );
  ```
  CLI: `run-daily` builds the same deps as `execute` (key from env or the emulator key) and calls `runDailyPayouts`; usage/help text updated. Seed: payout and items with the new money fields (An is `individual`: 450,000 → tax 31,500, net 418,500), `firstPayout: true`, `approvedBy: ADMIN`; ledger `payout_paid` −418,500 + `tax_withheld` −31,500; An's account `nameStatus: 'matched'`, `activeFrom: SEED_CREATED_AT`; `users/seed-photographer-an/private/identity` `{ legalName: 'Nguyễn Văn An', method: 'fake', provider: 'fake', verifiedAt: SEED_CREATED_AT }` (test value; #135 owns this doc's full shape). README: one row "identity legalName (An)" and a short "Daily payouts on the emulator: `npm run payouts -- run-daily --actor seed-staff-admin`; approve a first payout with `npm run payouts -- approve <id> --actor seed-staff-admin`".
  Integration test (written, not run): seed a released payment and an account, call `handleCreatePayouts` against the emulator, expect a `needs_approval` payout; approve with the domain use case; run again; expect `paid` and `earnings/{uid}` received updated.
- [ ] **Step 5:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. Ledger: integration test written, not run.
- [ ] **Step 6: Commit** `feat(functions): daily createPayouts job, approve and run-daily CLI, tax in payouts [#134]`.

### Task 5: Functions — account callables, fake lookup and OTP, rules

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/payout_lookup.ts`, `src/infra/otp.ts`, `test/unit/payout_lookup_otp.test.ts`
- Modify: `src/callables/payout_account.ts`, `src/callables/errors.ts`, `src/infra/live_payout.ts` (`livePayoutAccountDeps(uid)`), `src/infra/payout_firestore.ts` (OTP and quota tx methods), `src/index.ts` (`lookupPayoutAccountName`, `requestPayoutOtp`, `savePayoutAccount` wiring), `test/unit/payout_account_callable.test.ts`, `test/unit/errors.test.ts`; `app_flutter/firebase/firestore.rules`; `app_flutter/firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Consumes: Task 3 domain.
- Produces:
  ```ts
  // infra/payout_lookup.ts
  export class FirestoreVerifiedNameReader implements VerifiedNameReader { constructor(db: Firestore) } // users/{uid}/private/identity.legalName
  export function accountNameLookup(mode: 'fake' | 'off', echoName: string | null): AccountNameLookup; // off → always unsupported
  // infra/otp.ts
  export function fakeOtpAllowed(env?: Env): boolean;          // same rule as fakePaymentsAllowed
  export function otpSender(env?: Env): OtpSender;              // fake: logger.info('fake otp', {uid?, code}); else: throws DomainError('not_eligible')
  export const nodeOtpCrypto: OtpCrypto;                        // node:crypto createHash('sha256'), randomBytes
  export class FirestorePhotographerPhoneReader implements OtpPhoneReader { constructor(db: Firestore) } // photographers/{uid}/private/contact.phone
  // callables/payout_account.ts
  export async function handleLookupPayoutAccountName(request: PayoutAccountCallableInput, deps: PayoutAccountDeps): Promise<{decision: string; holderName: string | null; verifiedName: string | null}>;
  export async function handleRequestPayoutOtp(request: PayoutAccountCallableInput, deps: PayoutAccountDeps): Promise<{phoneLast4: string; expiresInSeconds: number; resendInSeconds: number}>;
  export async function handleSavePayoutAccount(request: PayoutAccountCallableInput, deps: PayoutAccountDeps): Promise<{accountId: string; accountLast4: string; activeFrom: string; nameStatus: string}>;
  ```
  `livePayoutAccountDeps(uid)` reads the caller's verified name once (for the fake echo) and wires `lookup`, `names`, `otp` (`sender`, `phones`, `crypto`), `notices: livePayoutNotices()`. Exports: `lookupPayoutAccountName = onCall(CALLABLE_OPTIONS, …)`, `requestPayoutOtp = onCall(CALLABLE_OPTIONS, …)`, `savePayoutAccount` keeps `secrets: [PAYOUT_ACCOUNT_KEY]`.

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `payout_lookup_otp.test.ts`: `fake lookup echoes the verified name; 4321 → TRAN VAN B; 9999 → unsupported; 0404 → not_found`; `off lookup is unsupported`; `fakeOtpAllowed: emulator on demo-* and the dev project only; FUNCTIONS_EMULATOR on another project is false`; `the off sender refuses with not_eligible`; `nodeOtpCrypto hashes deterministically and random gives n bytes`.
  - `payout_account_callable.test.ts`: `lookup without auth is unauthenticated`; `lookup passes data through and returns the decision`; `lookup callable logs only the code` (spy on the logger: no digits of the number in any log argument; Review Focus 1); `requestPayoutOtp returns phoneLast4`; `save maps name_mismatch / otp_invalid to failed-precondition with details.code`; `save no longer reads auth_time` (an old token still saves a first account).
  - `errors.test.ts`: the four new codes map to `failed-precondition`.
  - Rules (`rules.test.mjs`, written not run): `the assignee can read a booking with assigneeId == uid`; `a stranger cannot read it`; `an assignee query (where assigneeId == uid) is allowed`; `nobody reads or writes otp_challenges`; `nobody reads or writes payout_lookups`; `the owner still cannot write payoutAccounts`.
- [ ] **Step 3:** `npm test` → fail.
- [ ] **Step 4: Implement** the adapters, callables, wiring, `TRANSPORT_CODE` lines, and the rules from the Contract (keep the existing bookings rule text, add the `assigneeId` clause only to the top-level `allow read`; the `private/contact` and `events` sub-rules are #136's).
- [ ] **Step 5:** `npm test && npm run build` (functions) green. Ledger: rules tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): payout account lookup, OTP and v2 save callables; assignee booking read [#134]`.

### Task 6: App data — earnings model, repository, assigned bookings, own acceptingOrders

**Files:**
- Modify: `app_flutter/lib/data/earnings/earnings.dart`, `earnings_repository.dart` (interface + `FakeEarningsRepository`), `firestore_earnings_repository.dart`, `lib/data/booking/booking_repository.dart` (interface), `firestore_booking_repository.dart`, `booking_providers.dart`, `lib/data/photographer/photographer_intro.dart`, `test/support/fake_booking_repository.dart`, `test/support/earnings_world.dart`
- Test: `test/data/earnings/firestore_earnings_repository_test.dart` (mocktail `FirebaseFunctions`/`HttpsCallable` + `FakeFirebaseFirestore`, as today), `test/data/booking/booking_repository_test.dart` (assigned query) and a new `test/data/booking/work_bookings_provider_test.dart` (merge and error), `test/data/photographer/photographer_intro_test.dart`

**Interfaces:**
- Consumes: callables and fields of Tasks 4–5.
- Produces: Contract "App" data types, `lookupAccountName`, `requestAccountOtp`, `saveAccount` v2, `watchAssignedBookings`, `assignedBookingsProvider`, `myWorkBookingsProvider`, `PhotographerIntro.acceptingOrders`. `FakeEarningsRepository` gains `nextLookup` (map `bankCode:number` → `PayoutNameLookup`), `failNextOtp(code)`, `otpCalls`, `lookupCalls`, and records saves as `bankCode:last4[:otp]` (never full numbers). `FakeBookingRepository` gains `emitAssigned(List<Booking>)` and `failAssigned(Object error)`.

- [ ] **Step 1:** Contract check (app data); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `earningItemFrom reads fee, tax, net, rates, estimated and milestones`; `an old item reads net = amount, tax 0, estimated true, milestones null`.
  - `payoutAccountViewFrom reads activeFrom and nameStatus; an old view is matched and active`.
  - `lookupAccountName calls lookupPayoutAccountName and maps each decision code`.
  - `saveAccount sends otpCode only when given and returns activeFrom`.
  - `callable errors map to PayoutAccountError codes (name_mismatch, otp_invalid, otp_expired, otp_required, limit_exceeded, phone_required, not_eligible, not_found)`; `no argument appears in the error's toString`.
  - `myWorkBookingsProvider merges own and assigned, own wins on the same id`.
  - `an assigned stream error yields the own list (no AsyncError)` (Review Focus 5).
  - `PhotographerIntro.acceptingOrders: stored flag wins; missing flag falls back to verified && onboardingComplete`.
- [ ] **Step 3:** Run them (`flutter test --no-pub --timeout 60s test/data/earnings`, then `test/data/booking`, then `test/data/photographer`) → fail.
- [ ] **Step 4: Implement.** `myWorkBookingsProvider`:
  ```dart
  final myWorkBookingsProvider = Provider.autoDispose<AsyncValue<List<Booking>>>((ref) {
    final own = ref.watch(myBookingsProvider(BookingRole.photographer));
    final assigned = ref.watch(assignedBookingsProvider).value ?? const <Booking>[];
    return own.whenData((list) {
      final ids = {for (final b in list) b.id};
      return [...list, for (final b in assigned) if (!ids.contains(b.id)) b];
    });
  });
  ```
  `assignedBookingsProvider` catches stream errors (`handleError` → empty list, `debugPrint` the error type once). Remove `holderName` from `saveAccount`.
- [ ] **Step 5:** `flutter analyze` clean; the three test folders green, one at a time.
- [ ] **Step 6: Commit** `feat(data): earnings breakdown, payout lookup/OTP repository, assigned bookings [#134]`.

### Task 7: S06.05 Thu nhập — breakdown, labels, notice

**Files:**
- Modify: `app_flutter/lib/core/widgets/earning_row.dart`, `lib/features/earnings/earnings_screen.dart`, `lib/l10n/app_vi.arb`
- Test: `test/core/widgets/earning_row_test.dart`, `test/features/earnings/earnings_screen_test.dart`

**Interfaces:**
- Consumes: `EarningItem` breakdown fields (Task 6).
- Produces: `EarningRow.breakdown/expanded`, `EarningBreakdownLine`; l10n `earningsBreakdown*`, `earningsMilestones*`, changed `earningsSoon`, `earningsNotice`.
- **Backend wiring:** unchanged listeners (`earnings/{uid}`, `earnings/{uid}/items` via `FirestoreEarningsRepository`); the numbers come from the projection written by `onPaymentWritten`/`onPayoutWritten` (Task 4). Seed An on the emulator shows a paid row with tax.
- **Mock parity (`#S06.05`):** KPI labels "Đang giữ · Chờ chi trả · Đã nhận"; the notice line verbatim; account card (bank badge, "Tài khoản nhận tiền", "{bank} •••• {last4}", chevron) unchanged; section "Các khoản" + month; row meta "T3 01/10 · đủ 2 mốc" when milestones exist; status pills "Đang giữ / Chờ chi trả / Đã chuyển / Đang khiếu nại"; tap expands `.brk` lines in the mock's order; expanded state announced (`Semantics(expanded:)`).

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `EarningRow` : `collapsed shows no breakdown; expanded shows each line label and value`; `expanded is announced to screen readers`; `fits 320 dp at 1.3× text`.
  - Screen: `KPI shows "Chờ chi trả"`; `notice reads "Chi tự động mỗi ngày · lần chi đầu do staff duyệt · phí chuyển do nền tảng trả"`; `paid row breakdown shows 1.500.000₫ · 105.000₫ · 1.395.000₫ with "Đã chuyển theo mốc", "Thuế khấu trừ (7%)", "Thực nhận"` (Review Focus 4); `held row shows "Số tiền" and "Thực nhận dự kiến"`; `a studio row has no tax line`; `a row with fee > 0 shows "Hoa hồng (10%)"`; `meta shows "mốc 1/2" and "đủ 2 mốc"; nothing without milestones`; `tapping a row toggles only that row`; `tapping a booking row no longer opens the booking` (Decision 14).
- [ ] **Step 3:** Run → fail.
- [ ] **Step 4: Implement.** Percent string: `bp % 100 == 0 ? '${bp ~/ 100}%' : '${(bp / 100).toStringAsFixed(1).replaceAll('.', ',')}%'`. Expanded ids live in the screen state (`Set<String>`). Amounts in the breakdown use `formatMoney(v)` (full đồng, never short).
- [ ] **Step 5:** `flutter analyze`; `flutter test --no-pub --timeout 60s test/core/widgets/earning_row_test.dart`; then `test/features/earnings/earnings_screen_test.dart` green.
- [ ] **Step 6: Commit** `feat(earnings): S06.05 tax and net breakdown per payment, daily payout notice [#134]`.

### Task 8: S06.06 Tài khoản nhận tiền — lookup card, mismatch, OTP sheet, 72-hour view

**Files:**
- Create: `app_flutter/lib/core/widgets/otp_code_field.dart` (export in `lib/core/core.dart`), `lib/features/earnings/widgets/name_lookup_card.dart`, `lib/features/earnings/widgets/payout_otp_sheet.dart`, tests `test/core/widgets/otp_code_field_test.dart`, `test/features/earnings/payout_otp_sheet_test.dart`
- Modify: `lib/features/earnings/payout_account_controller.dart`, `payout_account_screen.dart`, `widgets/account_inputs.dart`, `lib/l10n/app_vi.arb`, `lib/features/notifications/notification_visuals.dart` and `notification_targets.dart` (append the two payout types and the two `/work/earnings` paths, Contract), `test/features/earnings/payout_account_controller_test.dart`, `test/features/earnings/payout_account_screen_test.dart`, `test/features/notifications/notification_visuals_test.dart`, `test/features/notifications/notification_targets_test.dart`, `test/support/earnings_world.dart`
- Delete: `lib/features/earnings/widgets/reauth_sheet.dart` (and its strings; `AuthRepository.reauthenticate` stays)

**Interfaces:**
- Consumes: Task 6 repository and models.
- Produces:
  ```dart
  sealed class PayoutLookupView { const PayoutLookupView(); }
  class LookupIdle extends PayoutLookupView {} class LookupLoading extends PayoutLookupView {}
  class LookupDone extends PayoutLookupView { final PayoutNameLookup result; }
  class LookupFailed extends PayoutLookupView { final String code; } // limit_exceeded | network | unknown
  // PayoutAccountForm: {bank, number, editing, saving, justSaved, lookup: PayoutLookupView}; holder removed;
  //   valid != null only when lookup is LookupDone with decision matched or review
  // PayoutAccountController: setBank, setNumber (schedules lookup after 800 ms), lookupNow(), startChange, cancelChange, ackSaved,
  //   Future<PayoutSaveOutcome> save({required Future<bool> Function(PayoutOtpTicket) askOtp})
  enum PayoutSaveOutcome { saved, changed, cancelled, conflict, failed, invalid, phoneRequired, otpLimit, otpUnavailable, mismatch }
  ```
  The controller cancels its debounce `Timer` in `ref.onDispose`.
- **Backend wiring:** `lookupPayoutAccountName`, `requestPayoutOtp`, `savePayoutAccount` callables through `FirestoreEarningsRepository`; owner view `payoutAccounts/{uid}` listener for the read view (rule unchanged). On the emulator: seed An (`an.verified@seed.test`) changes VCB to MB `0987654321` → mismatch; MB `0123459999` → review; MB `0123451234` → matched; the OTP code is in the Functions emulator log.
- **Mock parity:** `#S06.06` (intro "Đang dùng MB •••• 3456…", bank field with logo and search icon, number field focused, `.lkp` matched card with check + name + "Khớp tên đã xác minh", hint line, lock note, foot primary "Lưu tài khoản"); `#S06.06-mismatch` (number field error border, `.lkp.bad` close + "TRAN VAN B" + "Không khớp", `.warnc` alert with the verified name in the title, disabled primary that still reads "Lưu tài khoản" with `aria-disabled`); `#S06.06-review`; `#S06.06-otp` (sheet order: title, body with •••• last 4, OTP field, resend countdown, lock note, primary "Xác nhận đổi tài khoản"); `#S06.06-pending` (masked account, "Chờ hiệu lực" badge, effective time card, outline "Đổi tài khoản"). One primary per screen/sheet; the form has no holder field.

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `OtpCodeField`: `accepts only 6 digits`; `calls onCompleted at the 6th digit`; `shows errorText`; `has AutofillHints.oneTimeCode`.
  - Controller: `a valid number looks up after 800 ms, once` (fake async; `lookupCalls == 1` after typing three more digits within 800 ms); `the same bank and number is not looked up twice`; `save is invalid until the lookup is matched or review`; `first account saves without asking for OTP`; `a change asks for OTP with the ticket, then saves with the code` (`saves` ends with `:otp`); `wrong code keeps the sheet open (askOtp sees wrong)`; `phone_required → phoneRequired`; `not_eligible from requestAccountOtp → otpUnavailable`; `name_mismatch from save → mismatch`; `the typed number is cleared after a successful save`.
  - Screen: `matched lookup shows the name and "Khớp tên đã xác minh"`; `mismatch shows the two names, the warning text and a disabled "Lưu tài khoản"`; `review shows "Ngân hàng chưa hỗ trợ tra tên" and enables save`; `not_found / unverifiable / limit show their texts and disable save`; `no holder name field exists`; `change form shows the intro with the current bank and last 4 and the lock note`; `OTP sheet: resend is disabled for 60 s then enabled` (bounded pumps); `after a change the read view shows "Chờ hiệu lực" and "Tài khoản mới có hiệu lực lúc 10:15, 13/10"`; `a pending_review account shows the staff note`; `fits 320 dp at 1.3× text` (form, mismatch, OTP sheet).
  - Notifications: `payout_account_needed is a payment icon in the action tone; payout_account_changed a lock in the action tone`; `safeTarget allows /work/earnings and /work/earnings/account and refuses them with a query`.
- [ ] **Step 3:** Run → fail.
- [ ] **Step 4: Implement.** Save flow for a change: `requestAccountOtp` → `askOtp(ticket)` (the screen opens `showPayoutOtpSheet`, whose `onSubmit` calls `saveAccount(..., otpCode)` and maps errors to `PayoutOtpSubmit`; `onResend` calls `requestAccountOtp` again) → `changed`. Time label `HH:mm, dd/MM` in Vietnam time (`toVn`). Remove the change confirm sheet (the OTP sheet is the confirmation) and the re-auth path; delete `reauth_sheet.dart` and the removed keys; run `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze`; `flutter test --no-pub --timeout 60s test/core/widgets/otp_code_field_test.dart`, then `test/features/earnings` green.
- [ ] **Step 6: Commit** `feat(earnings): S06.06 name lookup, mismatch, OTP change and 72-hour pending view [#134]`.

### Task 9: S06.01 "Giao bởi {Studio}" and S06.02 "Bắt đầu nhận đơn"

**Files:**
- Create: `app_flutter/lib/features/verification/verification_routes.dart`
- Modify: `lib/core/widgets/booking_card.dart` (`BookingSummary.tag`), `lib/core/widgets/empty_state.dart` (`note`), `lib/core/theme/app_icons.dart` (`verifiedUser`), `lib/features/booking/booking_view_rules.dart` (`workDashboard(..., uid:)`, `bookingSummaryFor(..., tag:)`), `lib/features/work/work_dashboard.dart` (uses `myWorkBookingsProvider` and the uid), `lib/features/work/work_screen.dart` (tag on the today card), `lib/features/work/work_empty.dart` (closed variant), `lib/l10n/app_vi.arb`, `docs/superpowers/specs/components/shared-components.md` (icons table row `verifiedUser` · `verified_user`; `BookingCard` tag; `EmptyState` note)
- Test: `test/core/widgets/booking_card_test.dart`, `test/core/widgets/empty_state_test.dart`, `test/features/work/work_screen_test.dart`, `test/features/work/work_empty_test.dart`, `test/features/booking/` (the `workDashboard` rules test file)

**Interfaces:**
- Consumes: `myWorkBookingsProvider`, `PhotographerIntro.acceptingOrders` (Task 6), `partyProfileProvider`.
- Produces: `verifyStartReadyProvider` (`false`), `verifyStartPath`, `BookingSummary.tag`, `EmptyState.note`, `AppIcons.verifiedUser`, l10n `workAssignedBy`, `workClosed*`.
- **Backend wiring:** own bookings listener (unchanged) + `bookings where assigneeId == uid` listener (rule from Task 5, written by #136 later); own `photographers/{uid}` via `myIntroProvider` (`FirestorePhotographerIntroRepository`). On the emulator: Bình (`binh.unverified@seed.test`, `acceptingOrders: false`) with no bookings sees the closed variant; An sees the old empty state when empty. No seed data has `assigneeId` until #136 (a widget test covers the label).
- **Mock parity:** `#S06.02` (illustration disc with `verified_user`, title, body, tertiary note "Staff duyệt trong 24 giờ sau khi bạn gửi", small primary "Bắt đầu nhận đơn"); `#S06.01-assigned` (pill "Giao bởi {Studio}" with the storefront icon under the card title; KPIs exclude the assigned booking's money). The S06.02 segmented control is not added (Decision 17).

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `BookingCard`: `draws the tag pill when BookingSummary.tag is set; nothing otherwise`.
  - `EmptyState`: `shows note under the body when given`.
  - `workDashboard`: `an assigned booking today becomes the today card`; `assigned bookings count in Buổi sắp tới`; `assigned bookings never count in requests, Tháng này or Đang giữ`.
  - Work screen: `today's assigned booking shows "Giao bởi Studio Ánh Dương"` (fake party profile for the studio uid); `a failing assigned stream still shows the dashboard` (Review Focus 5).
  - Work empty: `a photographer not accepting orders sees "Mở nhận đơn để khách đặt được bạn", the body and the note`; `"Bắt đầu nhận đơn" is hidden while verifyStartReadyProvider is false`; `with the flag overridden to true it pushes /verify/start` (stub route); `an accepting photographer keeps the old empty state ("Buổi chụp tiếp theo bắt đầu từ đây")`; `closed variant fits 320 dp at 1.3× text`.
- [ ] **Step 3:** Run → fail.
- [ ] **Step 4: Implement** per Decisions 17–19. `WorkEmptyState` watches `myIntroProvider`; while it loads, keep today's behaviour (no flash of the closed variant: show the existing loader).
- [ ] **Step 5:** `flutter analyze`; `test/core/widgets`, `test/features/booking`, `test/features/work` green, one folder at a time.
- [ ] **Step 6: Commit** `feat(work): S06.01 assigned-by-studio label and S06.02 start accepting orders [#134]`.

### Task 10: Specs, data model, ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S06.01: "✅ đã làm (4c) · nhãn Giao bởi {Studio} (#134, dữ liệu #136) · ẩn Sự kiện của tôi"; S06.02: "✅ · biến thể chưa nhận đơn (#134), nút mở khi có S21.02 (#135)"; S06.05: "✅ (10b, #134) · thuế khấu trừ, chi tự động mỗi ngày"; S06.06: "✅ (10b, #134) · tra tên, OTP, 72 giờ (cổng giả)"); `docs/superpowers/specs/screens/photographer.md` (S06.01, S06.02, S06.05, S06.06 paragraphs and string lists matching `app_vi.arb`); `docs/superpowers/specs/data-model/domain-model.md` (`Payout` money fields, `needs_approval`, `PayoutAccount.nameStatus/activeFrom`, `OtpChallenge`, ledger types); `docs/superpowers/specs/data-model/relational-schema.md` (payout columns `platform_fee`, `tax_withheld`, `amount_net`, `fee_rate_bp`, `tax_rate_bp`, `first_payout`, `approved_by`, `approved_at`; payout account `name_status`, `active_from`; `otp_challenges`; status check adds `needs_approval`); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §6 (one line each: daily job name and time, CLI `approve`/`run-daily`, fake lookup/OTP rules); `docs/FIREBASE-SETUP.md` (only if it lists scheduled functions: add `createPayouts`)
- Create: `docs/superpowers/handover/ledger-s06-work-earnings.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names); check every string in `photographer.md` against `app_vi.arb` and the mock.
- [ ] **Step 2:** Write the ledger: rulings (Decisions 1–19 and anything ledgered during the tasks), deferred list below, skipped suites (rules tests and `test/integration/create_payouts.test.ts` written, not run), deploy-order notes: (1) rules before the app (the `assigneeId` query is denied until the rule is deployed; the app tolerates it); (2) `createPayouts` binds the existing `PAYOUT_ACCOUNT_KEY`, so a Blaze project needs that secret (ledger 10b) before deploy; nothing deploys to `booking-c1922` (Spark); (3) Scheduler jobs go from 6 to 7; (4) for #135: flip `verifyStartReadyProvider` to true with the `/verify/start` route, write `users/{uid}/private/identity.legalName` on approval, and exclude `identity` from the owner-read rule of `users/{uid}/private/{docId}`; (5) for #136: `assigneeId` read rule already exists, add the sub-collection rules.
- [ ] **Step 3: Commit** `docs(spec): S06 payouts, payout account v2 and work tab states [#134]`.

## Deferred

- S06.07 "Nộp bàn giao" → delivery plan of #130 (spec bàn giao §5).
- "cọc" → "đã thanh toán / hoàn 100%" copy on S06.01 and S06.03 → #129.
- Real payout intermediary adapter (transfer, name lookup, webhook/`queryPayout`), real SMS/OTP adapter, email to the old address on account change → after legal work (payments spec §10–11); Needs the owner 2.
- Staff screen S23.02 (approve first payouts, reconcile, tax export file) → phase 1.5 dashboard #83; the CLI covers it until then.
- Studio payout accounts in the company's name (match with the business name, S21.04) → #135.
- Partial release per milestone in the earnings rows and payouts (amount released per milestone) → the plan that introduces milestones (#129/#130).
- Revenue entries (`gateway_fee`, `payout_fee`, `revenue_received`) and the other ledger renames of payments spec §8 → #129.
- A payout whose gateway keeps throwing stays `processing` (10b deferred, unchanged).
- S06.02 segmented control of the mock; S06.01 banner "bỏ dở xác minh" (#135).
- Go backend (phase 2, #90) port of the payout rules: the domain is reusable as is.
