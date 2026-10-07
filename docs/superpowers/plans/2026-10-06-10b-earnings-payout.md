# 10b: Earnings and payout account (S06.05 Thu nhập, S06.06 Tài khoản nhận tiền) Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle or performance steps; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, indexes and adds Functions. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **Single session, no lanes.** Tasks run in order on one branch `plan/10b-earnings-payout`; each task is sized for one implementer.

> **Deploy gate (read before merging):** Task 3 binds the Secret Manager secret `PAYOUT_ACCOUNT_KEY` to a callable. `firebase deploy --only functions` fails on `develop` until the secret exists in the dev project (see "Needs the owner"). The PR body says so and the PR is **not self-merged** until the owner confirms the secret is set.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A photographer sees where their money is (Đang giữ · Sắp nhận · Đã nhận), every payment as a row with its money state (including disputed holds and their reason), and registers one bank account for payouts whose number is stored encrypted and only ever shown as "•••• 3456"; staff can batch released money into payouts and execute them against a fake bank gateway (no real bank transfer exists in this plan).

**Architecture:** Every money rule stays in `packages/domain`: payout-account validation and the save use case (behind an `AccountCipher` port), the earnings read model (`earningItemOf`, `summarizeEarnings`, `refreshEarnings`), and payouts (`createPayout`, `executePayout`, `holdPayout`, `resumePayout`) behind a `PayoutGateway` port with a `FakePayoutGateway` reference adapter. Clients still cannot read `payments`, `refunds` or `ledger_entries`; Firestore triggers on `payments/{id}` and `payouts/{id}` call `refreshEarnings`, which writes an owner-only projection `earnings/{uid}` (totals) and `earnings/{uid}/items/{paymentId}` (rows). The bank account lives in `payoutAccounts/{uid}` (owner-readable masked view) and `payoutAccounts/{uid}/accounts/{accountId}` (server-only, AES-256-GCM ciphertext). One callable (`savePayoutAccount`) writes it; staff payout operations are a CLI (`npm run payouts`) like the awards CLI. The app gets `lib/data/earnings/` (models, repository, Firestore adapter, fake, providers, bank catalogue and input rules mirrored from TS), `AuthRepository.reauthenticate`, `StatTile.onTap`, a core `EarningRow`, and the two screens.

**Tech Stack:** TypeScript (domain; Functions v2 `onCall` with `secrets`, `onDocumentWritten`; `node:crypto` AES-256-GCM in the Functions adapter only), Firestore rules and indexes; Flutter, Riverpod 3, `cloud_firestore`, `cloud_functions`, `firebase_auth` (reauthentication), existing `AsyncView`, `StatTile`, `EscrowNotice`, `StatusBadge.custom`, `GlassCard`, `showAppSheet`, `showConfirmSheet`, `EmptyState`, `OfflineBanner`, `AppButton`.

**Spec:** `docs/superpowers/specs/screens/photographer.md` (S06.05, S06.06); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (code table rows S06.05/S06.06), §3g.1–3g.6 (escrow, release, refunds, payouts, ledger, display), §3i.1 (disputes: `openDispute` → `held → disputed`), §3i.6 (staff operations, `executePayout`); `docs/superpowers/specs/data-model/domain-model.md` §2.4 (`Payment`, `LedgerEntry`, `PayoutAccount`, `Payout`, `PayoutItem`), §4 (`EscrowStatus`, `LedgerEntryType`, `PayoutStatus`, `ErrorCode`), §5 (escrow machine: "`released` còn gọi là "sắp nhận" ở S06.05"), §6 invariants 11, 12, 15; `relational-schema.md` (`payments`, `refunds`, `payout_accounts`, `payouts`, `payout_items`, `ledger_entries`, §3 mapping); `data-model/README.md` §4 matrix (`payout_accounts` "S (số che), A" / "S (qua use case có xác nhận)"), §5 (`create_payout`, `execute_payout`); `components/shared-components.md` (`StatTile`, `EscrowNotice`, `StatusBadge`); mock `docs/design/ui-mock.html` `#S06.05`, `#S06.06`, `#S06.01` (KPI row).

**Prerequisite:** `develop` at or after PR #31 (9abc batch) and after plan 9d (`AppIcons` Material Symbols, 60‑30‑10) merges. Booking backend 4a and 4c are done.

## Contract with existing code

Task 1 Step 1 checks the domain/Functions part, Task 4 Step 1 the app part; adapt and ledger any difference:

- Domain (`packages/domain/src`): `escrow.ts` (`Payment` with ISO-string instants, `PaymentStatus`, `PaymentSubject = 'booking' | 'event_registration'`, `Refund`, `LedgerEntry`, `LEDGER_ENTRY_TYPES` incl. `payout_paid`, `releaseEscrowPayment` writes `escrow_released` with `amount = payment.amount − refunds` and `accountOwnerId = payeeId`, `disputeEscrowPayment`); `booking.ts` (`ESCROW_STATUSES` incl. `paid_out`, `disputed`; `Booking.serviceSnapshot`, `day`, `customerId`); `open_dispute.ts` (validates a 1–500 grapheme reason but **does not store it**); `booking_sweeps.ts` (release sweep sums all refunds of a payment); `booking_ports.ts` (`BookingStore.getRefundsForPayment`, `getPaymentsForBooking`); `memory_booking_store.ts` (public maps `payments`, `refunds`, `ledgerEntries`, `bookings`); `fake_payment_gateway.ts` (pattern for a fake adapter); `errors.ts` (`ERROR_CODES`, no `reauth_required` yet); `ports.ts` (`Clock`, `IdGenerator`); `ids.ts` (`isId`, `newUlid`); `booking_requests.ts` (`graphemeCount`); `test/purity.test.ts` (no `node:*` in `src`).
- Functions (`app_flutter/firebase/functions/src`): `infra/booking_firestore.ts` (`PAYMENTS_COLLECTION`, `REFUNDS_COLLECTION`, `LEDGER_COLLECTION`, `paymentToFirestore`/`paymentFromFirestore`, Timestamp ↔ ISO helpers, `FirestoreBookingStore`), `callables/errors.ts` (`TRANSPORT_CODE`, `toHttpsError`), `callables/album.ts` (`run()` wrapper that logs codes only), `callables/get_contact_link.ts` (`CallableInput` has `auth?.uid` only; `award.ts` reads `request.auth?.token?.staffRole`), `config.ts` (`CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`), `index.ts` exports, `tools/awards.ts` + `test/unit/award_cli.test.ts` (CLI pattern: `--actor` with admin claim, emulator or credentials), `seed/fixtures.ts` (`seedDocuments(now)` pure path/data list; payments `seed-payment-<bookingId>`: completed → `released`, cancelled → `refunded`, else `held`), `seed/README.md`, `.env.booking-c1922` (`PAYMENTS_MODE=fake`).
- Rules/indexes: `match /payments|refunds|ledger_entries { allow read, write: if false; }`, `signedIn()`, `isOwner(uid)`, catch-all deny; indexes `payments (escrowStatus, releaseAfter)`, `payments (payeeId, escrowStatus)`.
- CI: `firebase-deploy.yml` runs domain tests, Functions unit + emulator integration tests (`demo-nag`), then deploys functions with `--non-interactive --force`.
- App: `lib/core/screen_codes.dart` (`ScreenCodes.earnings = 'S06.05'`, `payoutAccount = 'S06.06'`), `lib/app/router.dart` (`photographersOnly()`, `/work/calendar` pattern), `lib/features/work/work_screen.dart` (KPI `StatTileRow`, "Đang giữ" tile with the comment "Tapping does nothing until S06.05 exists"), `lib/features/shell/placeholder_tabs.dart` (S09.01 `ProfileTab`, `_MyAlbumsRow` pattern), `lib/core/widgets/stat_tile.dart` (`StatTile(value, label)`, no `onTap`), `escrow_notice.dart`, `status_badge.dart` (`StatusBadge.custom`), `confirm_sheet.dart` (`showConfirmSheet(danger:)`), `app_bottom_sheet.dart` (`showAppSheet(enableDrag:)`), `empty_state.dart`, `offline_banner.dart`, `async_view.dart`, `lib/core/format.dart` (`formatMoney(short:)`, `formatDay`), `lib/core/vn_time.dart` (`parseDayKey`), `lib/core/vnd_input.dart` (grouping formatter pattern), `AppIcons` (`payment`, `wallet`, `lock`, `settings`, `warning`, `chevron`), `lib/data/auth/auth_repository.dart` (`AuthRepository`, `FirebaseAuthRepository` with Google/Facebook/email, `FakeAuthRepository` in the same file), `auth_error.dart`, `lib/data/booking/booking_repository.dart` (`FunctionsException` → code mapping pattern), `lib/data/backend/backend_config.dart` (`functionsRegion`), `lib/features/skills/skills_analytics.dart` (analytics hook pattern), `test/data/skills/rules_catalogue_sync_test.dart` (reads a sibling source file to keep two lists equal), `test/data/booking/booking_rules_test.dart` (reads `../packages/domain/test/fixtures/booking_policy.json`), `scripts/tools/build_ui_components.py`.
- Self-hosted API (`services/api/migrations`): bookings exist, **no `payments`, `refunds`, `ledger_entries` tables yet**.

## Global Constraints

- Escrow (spec 3g.1, verbatim): "Nhiếp ảnh gia hoặc chủ sự kiện **chỉ nhận tiền sau khi buổi chụp / sự kiện hoàn thành** (`completed`)." `held ──(booking/sự kiện completed + hết cửa sổ khiếu nại)──▶ released ──(đưa vào lô chi trả, chuyển khoản xong)──▶ paid_out`; "`released`: số dư chờ chi trả của người nhận". This plan never releases money early: only `released` payments enter a payout.
- Payouts (3g.4): "Nhiếp ảnh gia khai **tài khoản nhận tiền** (ngân hàng) ở S06.06 trước khi nhận được tiền; thiếu thì khoản vẫn tích luỹ ở `released` và ứng dụng nhắc thêm tài khoản." "Mỗi lô `Payout` gồm nhiều khoản `released`, trạng thái `pending → processing → paid` (hoặc `failed`, `on_hold`)."
- Ledger (3g.5): "Mọi biến động tiền là một **bút toán bất biến** (append‑only) trong `ledger_entries`"; invariant 15: "`Payout.amount = Σ PayoutItem.amount`; một `Payment` chỉ nằm trong một lô trừ khi lô trước `failed`." Money is integer VND.
- S06.05 data (verbatim): "Đang giữ = tổng khoản `held`; Sắp nhận = `released` chưa vào lô đã trả và lô `pending/processing`; Đã nhận = tổng lô `paid`. Phân trang theo tháng." States: "khoản `disputed` hiện biểu tượng và lý do tạm giữ; lô `failed` → dải "Chuyển khoản lỗi, kiểm tra tài khoản" (→ S06.06); offline đọc cache." Acceptance: "các số khớp sổ cái; không bao giờ hiện số tài khoản đầy đủ; ba ô cùng một hàng ở 320dp và chữ 1,3×."
- S06.05 layout (mock wins): Back + "Thu nhập" + settings icon (→ S06.06); `EscrowNotice` "Tiền khách trả được giữ an toàn trên ứng dụng và chuyển cho bạn sau khi buổi chụp hoàn thành."; `StatTile` ×3 **Đang giữ · Sắp nhận · Đã nhận** in one row; add-account card "Thêm tài khoản để nhận tiền" / "Cần có trước khi chuyển khoản" (only when no account); section "Các khoản" + "Tháng 10"; rows: "{tên khách} · {gói}", date "T7 12/10", short amount, badge `Đang giữ` (pending colour) · `Chờ chi trả` (warning) · `Đã chuyển 12/10` (ok) · `Đang khiếu nại`.
- S06.06 (verbatim): "chọn ngân hàng (tìm theo tên, danh mục ngân hàng VN có mã); ô số tài khoản (số, 6–20 chữ số); ô tên chủ tài khoản (viết hoa không dấu theo ngân hàng, tự điền nếu có tra cứu)"; "ghi `payout_accounts` (số tài khoản mã hoá, chỉ hiện 4 số cuối); mỗi nhiếp ảnh gia một tài khoản đang bật"; "tài khoản đã có → hiện che (`•••• 3456`) và "Đổi tài khoản"; đổi cần xác nhận lại (mật khẩu hoặc OTP khi có); lỗi định dạng dưới ô; lưu lỗi → SnackBar, giữ dữ liệu"; "số tài khoản không có trong log và phân tích; chỉ chủ đọc/ghi; thay tài khoản không ảnh hưởng khoản đã chuyển"; code table: "Tài khoản hợp lệ mới bật nút; chi trả dùng tài khoản đang bật." Mock copy: intro "Chúng tôi chuyển tiền sau mỗi buổi chụp hoàn thành vào tài khoản này.", note "Tên chủ tài khoản phải trùng tên bạn đã xác minh. Số tài khoản được mã hoá và chỉ hiện 4 số cuối.", primary "Lưu tài khoản".
- Strings from the spec (`s43_*`, `s44_*`) keep their Vietnamese text verbatim under camelCase app keys (`earningsTitle` for `s43_title`, `payoutAccountSave` for `s44_save`, …); new copy is listed in Tasks 5–6.
- Analytics (spec): `earnings_open`, `earnings_item_open{state}`, `payout_account_save` — never a number, bank account or name in parameters.
- CLAUDE.md: Firebase only in data adapters, `firebase_options.dart`, `main.dart`; business rules in `packages/domain` (no Firebase/Node imports); Functions thin, region `asia-southeast1`; strings in `lib/l10n/app_vi.arb`; `AsyncView` for every `AsyncValue`; one primary action per screen; tokens via `AppColors`/`AppSpace`/`AppRadius`; `package:photobooking/...` imports, features import `core/core.dart`; screen codes on every screen; commit trailer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions (where the spec is silent)

1. **Contract basis.** Earnings follow the escrow that exists today (plan 4a: one deposit `Payment` per booking, released at `completedAt + 24 h`, late-cancel kept part at start + 24 h). The milestone labels of spec 10-05 ("Chờ duyệt", 100 % via app) wait for plans D1–D5; `EarningState` is a string code set the D plans extend.
2. **Read model is a server projection.** `payments`, `refunds`, `ledger_entries` stay closed to clients. `refreshEarnings(payeeId, paymentIds)` (domain) recomputes the named rows and the totals in one transaction; triggers `onPaymentWritten` and `onPayoutWritten` call it (idempotent, safe to retry). Totals are recomputed from all rows of the payee (fine at v1 volume; the self-hosted server computes the same with SQL sums).
3. **Totals.** Đang giữ = Σ net of rows `held | disputed` (escrow `held`, `partially_refunded`, `disputed`; same rule as A1's ruling and S06.01). Sắp nhận = Σ net of `released` rows (released, not yet in a `paid` payout: no payout, or in a `pending`/`processing`/`on_hold` payout, or returned by a `failed` one). Đã nhận = Σ net of `paid_out` rows (= Σ `paid` payouts). Net of a payment = `amount − Σ refunds.amount`.
4. **One row per payment.** Row id = `paymentId`; `counterpartName` = `users/{customerId}.displayName` (empty → app shows "Khách"), `subjectLabel` = `serviceSnapshot.name`, `day` = shoot day. Fully refunded payments (net 0) have no row; partially refunded ones show the kept part. Event tickets (`event_registration`) are modelled but produce rows only when the events plans exist (they group tickets per event; the mock's "Photo walk phố cổ · 14 vé").
5. **Dispute reason.** `openDispute` now stores `dispute: {reason, openedAt}` on the `Payment` (server-only). The row's `holdReason` = the dispute reason when disputed, else the payout's `holdReason` when its payout is `on_hold`, else null. The photographer sees the customer's text (they answer it in S18.02 later); see "Needs the owner" 3.
6. **Account storage.** `payoutAccounts/{uid}` = owner-readable view `{accountId, bankCode, accountLast4, holderName, updatedAt}`; `payoutAccounts/{uid}/accounts/{accountId}` = server-only `{userId, bankCode, accountNumberEnc, accountLast4, holderName, active, createdAt, deactivatedAt?}` (history kept; payouts point at `accountId`). Ciphertext `v1:<iv b64>:<tag b64>:<data b64>` (AES-256-GCM, 12-byte IV, key = 32 bytes base64 from secret `PAYOUT_ACCOUNT_KEY`; `v1` is the key version for rotation). The domain sees only the `AccountCipher` port.
7. **Changing the account.** First save: no re-confirmation. With an active account, every save is a change: it needs a sign-in within the last 5 minutes (`auth_time` of the ID token) or it fails with the new code `reauth_required`; the app re-authenticates (password for email users, the provider flow for Google/Facebook), refreshes the ID token and retries once. A change deactivates the old account, re-points `pending`/`on_hold` payouts to the new one, and fails with `conflict` while a payout is `processing`. `paid` payouts keep their old `accountId`.
8. **Holder name.** Normalised to upper-case ASCII (strip diacritics, `Đ → D`, single spaces), 2–50 characters `[A-Z ]`; the app applies the same normalisation while typing. No comparison with a verified identity (S21 does not exist) and no name lookup (no provider): the field is typed. Shared fixture `packages/domain/test/fixtures/payout_account.json` keeps TS and Dart equal.
9. **Bank catalogue.** Static list `VN_BANKS` (VietQR `code`, NAPAS `bin`, short name, full name) in `packages/domain/src/vn_banks.ts`, mirrored in `lib/data/earnings/vn_banks.dart`, kept equal by a sync test. Initial list: VCB 970436 Vietcombank, ICB 970415 VietinBank, BIDV 970418, VBA 970405 Agribank, TCB 970407 Techcombank, MB 970422 MBBank, ACB 970416, VPB 970432 VPBank, TPB 970423 TPBank, STB 970403 Sacombank, HDB 970437 HDBank, VIB 970441, SHB 970443, MSB 970426, OCB 970448, SEAB 970440 SeABank, EIB 970431 Eximbank, LPB 970449 LPBank, NAB 970428 Nam A Bank, SCB 970429 (implementer re-checks codes against the VietQR bank list; ledger any change).
10. **Payouts are staff-only and fake.** No staff callables until S23 exists: staff use `npm run payouts` (Admin SDK, `--actor` with the `staffRole: admin` claim, like the awards CLI) which calls the domain use cases. `PayoutGateway.transfer` has one reference adapter, `FakePayoutGateway` (account last 4 = `0000` → `failed: account_rejected`, else `paid` with reference `FAKE-<payoutId>`; idempotent by `payoutId`). The live wiring uses it only in the emulator or when `PAYOUTS_MODE=fake` (dev project); anywhere else `execute` fails with `not_eligible`. **Payout execution to a real bank is out of scope**: there is no real provider; a bank/gateway adapter later implements the same port.
11. **Payout ledger.** `executePayout` writes one `payout_paid` entry per item (`paymentId`, `payoutId`, `accountOwnerId = payeeId`, `amount = −item.amount`) and sets each payment `escrowStatus = paid_out`, `updatedAt`. A `failed` payout clears `payoutId` on its payments (they become payable again). Execute accepts `pending` or `processing` (retry after a crash; the gateway is idempotent by `payoutId`).
12. **Paging.** Rows ordered by `day` desc (then id desc), live stream with a growing limit (30, 60, …: "Xem thêm" at the end when the last page was full); the app groups rows into month sections "Tháng 10" (other years "Tháng 10/2025").
13. **Entry points.** S06.01 "Đang giữ" tile (new `StatTile.onTap`) and an S09.01 row "Thu nhập" for photographers (spec; the mock is silent, same card as "Album của tôi") → `/work/earnings`. On S06.05 the mock's header settings icon (semantics "Tài khoản nhận tiền") replaces the spec's text button; the add-account card and the failed-payout banner also open `/work/earnings/account`. A row opens S05.02 `/b/:id` (event rows later open S12.03).
14. **Offline.** Rows and totals come from the Firestore cache; the summary stream carries `fromCache` and S06.05 shows `OfflineBanner` while it is true. S06.06 saving offline → generic save SnackBar, input kept.
15. **No notifications.** `payout_released` (spec 3h.2) waits for S17; ledgered.
16. **Self-hosted parity.** `services/api` has no payment tables yet, so no migration; the target DDL in `relational-schema.md` gains the new columns and the projection is documented as a computed view, not a table.
17. **Analytics.** `earningsAnalyticsProvider` hook (same shape as `skillsAnalyticsProvider`); events: `earnings_open{}`, `earnings_item_open{state}`, `payout_account_save{change: bool}`.

### Controller rulings on the owner items (2026-10-06, single session; owner may revise)

- **R1 Secret.** Code reads `PAYOUT_ACCOUNT_KEY` via `defineSecret`; unit tests use a test key; nothing deploys from the stack branch. Before this reaches `develop` the owner creates the secret (FIREBASE-SETUP.md gains a section in Task 3).
- **R2 Real payouts** stay out of scope: `FakePayoutGateway` only.
- **R3 Dispute text on S06.05** shows a fixed label per dispute reason category (from the domain's reason enum), never the customer's free text.
- **R4 Holder name** is a hint only until identity verification (S21) exists; no match against a verified name.

## Review Focus

1. The full account number never leaves the server in plain text: not in the owner view, not in logs, not in analytics, not readable by the owner from the history doc. Pinned by Task 1 ("the stored account holds no plain digits beyond the last four"), Task 3 ("a refused save logs only the code", rules "the owner cannot read the accounts history"), Task 6 ("analytics gets no account data").
2. Changing the payout account cannot be done with a stale session and never moves money already paid. Pinned by Task 1 ("a change without a recent sign-in is reauth_required", "a change re-points pending payouts and keeps paid ones", "a change during processing is a conflict") and Task 6 ("reauth_required re-authenticates and retries once").
3. Held or disputed money never enters a payout; executing twice never pays twice; a failed payout puts its money back in Sắp nhận. Pinned by Task 2 ("held and disputed payments are never batched", "executing a paid payout is a conflict", "a retried execute uses the same gateway call", "a failed payout returns its payments").
4. Totals match the ledger. Pinned by Task 2 ("summary equals the ledger sums" over a world with deposit, partial refund, release, dispute, paid payout).
5. A trigger retry or two concurrent payment writes for one payee never leave stale totals. Pinned by Task 2 ("refresh is idempotent") and Task 3 integration ("two payments released together give one consistent summary").
6. Three KPI tiles stay in one row at 320 dp and text scale 1.3, and the disputed row shows its reason without relying on colour. Pinned by Task 5 tests.

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/errors.ts`, `escrow.ts`, `open_dispute.ts`, `index.ts` (modify) | `reauth_required`; `Payment.dispute`, `Payment.payoutId`; dispute reason stored |
| `packages/domain/src/vn_banks.ts`, `payout_account.ts`, `payout_ports.ts`, `save_payout_account.ts` (create) | bank list, input rules, ports, save use case |
| `packages/domain/src/payout.ts`, `fake_payout_gateway.ts`, `payout_use_cases.ts`, `memory_payout_store.ts` (create) | payouts, fake gateway, reference store |
| `packages/domain/src/earnings.ts`, `earnings_ports.ts`, `refresh_earnings.ts`, `memory_earnings_store.ts` (create) | read model and refresh use case |
| `packages/domain/test/fixtures/payout_account.json`, `test/*.test.ts` (create) | shared cases, tests |
| `app_flutter/firebase/functions/src/infra/account_cipher.ts`, `payout_firestore.ts`, `earnings_firestore.ts`, `live_payout.ts` (create); `booking_firestore.ts` (modify: payment `dispute`, `payoutId`) | adapters |
| `app_flutter/firebase/functions/src/callables/payout_account.ts`, `triggers/payment_write.ts`, `triggers/payout_write.ts` (create); `callables/errors.ts`, `config.ts`, `index.ts` (modify) | callable, triggers |
| `app_flutter/firebase/functions/tools/payouts.ts` (create), `package.json` (script `payouts`) | staff CLI |
| `app_flutter/firebase/functions/.env.booking-c1922` (modify: `PAYOUTS_MODE=fake`), `.secret.local` (create: emulator-only key) | config |
| `app_flutter/firebase/functions/seed/fixtures.ts`, `seed/README.md` (modify) | seeded account, payout, dispute, projection |
| `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (modify) | owner reads, indexes |
| `docs/superpowers/specs/data-model/domain-model.md`, `relational-schema.md`, `README.md`, `docs/FIREBASE-SETUP.md` (modify) | docs |
| `app_flutter/lib/data/earnings/earnings.dart`, `vn_banks.dart`, `payout_account_rules.dart`, `earnings_repository.dart` (interface + fake), `firestore_earnings_repository.dart`, `earnings_providers.dart` (create) | app data |
| `app_flutter/lib/data/auth/auth_repository.dart`, `auth_error.dart` (modify) | `reauthMethod`, `reauthenticate` |
| `app_flutter/lib/core/widgets/stat_tile.dart` (modify), `earning_row.dart` (create), `core.dart` (modify); `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html` (regenerate) | widgets |
| `app_flutter/lib/features/earnings/earnings_screen.dart`, `earnings_controller.dart`, `earnings_analytics.dart`, `payout_account_screen.dart`, `payout_account_controller.dart`, `widgets/bank_picker_sheet.dart`, `widgets/reauth_sheet.dart`, `widgets/account_inputs.dart` (create) | S06.05, S06.06 |
| `app_flutter/lib/app/router.dart`, `lib/features/work/work_screen.dart`, `lib/features/shell/placeholder_tabs.dart`, `lib/l10n/app_vi.arb` (modify) | routes, entries, strings |
| `docs/superpowers/specs/2026-10-01-remaining-screens.md`, `specs/screens/photographer.md`, `specs/components/shared-components.md` (modify) | status cells, spec notes |

---

### Task 1: Domain — payout account, bank list, dispute reason, `reauth_required`

**Files:**
- Create: `packages/domain/src/vn_banks.ts`, `payout_account.ts`, `payout_ports.ts`, `save_payout_account.ts`, `memory_payout_store.ts` (account part; Task 2 extends it), `test/fixtures/payout_account.json`
- Modify: `src/errors.ts`, `src/escrow.ts`, `src/open_dispute.ts`, `src/index.ts`
- Test: `test/payout_account.test.ts`, `test/save_payout_account.test.ts`, `test/open_dispute_reason.test.ts`

**Interfaces:**
- Produces:

```ts
// errors.ts: append 'reauth_required' to ERROR_CODES
// escrow.ts: Payment gains
readonly dispute?: { readonly reason: string; readonly openedAt: string } | null;
readonly payoutId?: string | null;          // current batch; cleared when that batch fails

// vn_banks.ts
export interface VnBank { readonly code: string; readonly bin: string; readonly shortName: string; readonly name: string; }
export const VN_BANKS: readonly VnBank[];   // Decision 9, in that order
export function bankByCode(code: unknown): VnBank | null;

// payout_account.ts
export const ACCOUNT_NUMBER_MIN = 6, ACCOUNT_NUMBER_MAX = 20, HOLDER_NAME_MIN = 2, HOLDER_NAME_MAX = 50, REAUTH_MAX_AGE_SECONDS = 300;
export function normalizeAccountNumber(raw: unknown): string | null;   // drop spaces, '.', '-'; then ^[0-9]{6,20}$ or null
export function normalizeHolderName(raw: unknown): string | null;      // Decision 8 or null
export function accountLast4(n: string): string;
export interface PayoutAccount {
  readonly id: string; readonly userId: string; readonly bankCode: string; readonly accountNumberEnc: string;
  readonly accountLast4: string; readonly holderName: string; readonly active: boolean;
  readonly createdAt: string; readonly deactivatedAt?: string;
}
export interface PayoutAccountView {
  readonly accountId: string; readonly bankCode: string; readonly accountLast4: string;
  readonly holderName: string; readonly updatedAt: string;
}

// payout_ports.ts (Task 2 adds the payout members to PayoutTx)
export interface AccountCipher { encrypt(plain: string): Promise<string>; decrypt(enc: string): Promise<string>; }
export interface PayoutTx {
  getUserRole(uid: string): Promise<string | null>;
  getActiveAccount(userId: string): Promise<PayoutAccount | null>;
  getAccount(userId: string, accountId: string): Promise<PayoutAccount | null>;
  listPayouts(payeeId: string, statuses: readonly PayoutStatus[]): Promise<Payout[]>;
  putAccount(a: PayoutAccount): void;
  putAccountView(userId: string, v: PayoutAccountView): void;
  putPayout(p: Payout): void;
}
export interface PayoutStore { runTransaction<T>(fn: (tx: PayoutTx) => Promise<T>): Promise<T>; }
export interface PayoutAccountDeps { readonly store: PayoutStore; readonly cipher: AccountCipher; readonly clock: Clock; readonly ids: IdGenerator; }

// save_payout_account.ts
export interface Caller { readonly uid: string; readonly authTime: Date | null; }
export function savePayoutAccount(deps: PayoutAccountDeps, caller: Caller, raw: unknown):
  Promise<{ accountId: string; accountLast4: string }>;
```

`Payout`/`PayoutStatus` are declared in `payout.ts` in this task (type only: `PAYOUT_STATUSES = ['pending','on_hold','processing','paid','failed']`, `Payout { id, payeeId, accountId, amount, status, items: readonly {paymentId, amount}[], reference?, failureReason?, holdReason?, createdBy, createdAt, updatedAt, processingAt?, paidAt? }`) so the account use case can re-point payouts; Task 2 adds the use cases.

Behaviour of `savePayoutAccount` (one transaction; validation before any read):
- `raw` must be `{bankCode, accountNumber, holderName}` (no other keys) → else `invalid_argument`; bank via `bankByCode`, number via `normalizeAccountNumber`, name via `normalizeHolderName`.
- `getUserRole(uid) !== 'photographer'` → `permission_denied`.
- No active account → create `{id: ids.newId(), active: true, accountNumberEnc: await cipher.encrypt(number) (before the transaction), …}` and the view.
- Active account exists → change: `authTime` null or older than `REAUTH_MAX_AGE_SECONDS` → `reauth_required`; any `processing` payout → `conflict`; old account `active: false, deactivatedAt: now`; new account active; every `pending`/`on_hold` payout gets the new `accountId`; view replaced.
- `open_dispute.ts`: after `disputeEscrowPayment`, set `dispute: { reason: trimmed reason, openedAt: now }` on the payment it writes.

- [ ] **Step 1: Contract check** (domain and Functions parts of "Contract with existing code"); ledger differences.
- [ ] **Step 2: Write the failing tests:**
  - `payout_account.test.ts` (cases from `fixtures/payout_account.json`): "account number keeps 6–20 digits after removing spaces, dots and dashes"; "letters in the account number are invalid"; "holder name is upper-case ASCII without diacritics"; "Đ becomes D and spaces collapse"; "holder name with digits or over 50 characters is invalid"; "last four of 0123456789 is 6789"; "every bank code is unique and has a 6-digit bin"; "bankByCode ignores unknown codes".
  - `save_payout_account.test.ts` (memory store + a test cipher that prefixes `enc:` and reverses): "first save creates one active account and the view"; "the stored account holds no plain digits beyond the last four"; "a customer is permission_denied"; "extra keys are invalid_argument"; "a change without a recent sign-in is reauth_required"; "a change within five minutes deactivates the old account"; "a change re-points pending payouts and keeps paid ones"; "a change during processing is a conflict and writes nothing"; "two first saves racing leave one active account" (second one becomes a change → `reauth_required` with a stale `authTime`).
  - `open_dispute_reason.test.ts`: "a dispute stores the trimmed reason and the time on the payment".
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → fail. **Step 4: Implement.** **Step 5: Run** `npm test && npm run typecheck && npm run lint` → pass (purity test included).
- [ ] **Step 6: Commit** `feat(domain): payout account, bank list and dispute reason [10b]`.

### Task 2: Domain — earnings read model and payouts with a fake gateway

**Files:**
- Create: `packages/domain/src/earnings.ts`, `earnings_ports.ts`, `refresh_earnings.ts`, `memory_earnings_store.ts`, `payout_use_cases.ts`, `fake_payout_gateway.ts`; extend `payout.ts`, `payout_ports.ts`, `memory_payout_store.ts`; modify `src/index.ts`
- Modify docs: `docs/superpowers/specs/data-model/domain-model.md` (§2.4: `Payment.dispute`, `Payment.payoutId` "Firestore cache of the open batch; relational: join on `payout_items`", `PayoutAccount.deactivatedAt`, `Payout.items/holdReason/createdBy`, read model `EarningItem`/`EarningsSummary` as a projection; §4: `ErrorCode` `reauth_required`, `EarningState`; §6: new invariant 22 "Chỉ `Payment` `released` vào lô; `escrowStatus = paid_out` ⇔ lô chứa nó `paid`; mỗi item một bút toán `payout_paid` âm cho người nhận"), `relational-schema.md` (`payments.dispute_reason text`, `payments.disputed_at timestamptz`; `payout_accounts.deactivated_at timestamptz`; `payouts.hold_reason text`, `payouts.created_by text references users(id)`; §3 rows `earnings/{uid}` + `items` → "view computed by `earningsOf` (no table)", `payoutAccounts/{uid}` + `accounts/{id}` → `payout_accounts`), `data-model/README.md` (§5: `save_payout_account`, `refresh_earnings`, `hold_payout`; Functions names `savePayoutAccount`, `onPaymentWritten`, `onPayoutWritten`, CLI `payouts`)
- Test: `test/earnings.test.ts`, `test/refresh_earnings.test.ts`, `test/payout_use_cases.test.ts`

**Interfaces:**
- Produces:

```ts
// earnings.ts
export const EARNING_STATES = ['held', 'disputed', 'released', 'paid_out'] as const;
export type EarningState = (typeof EARNING_STATES)[number];
export interface EarningSubject { readonly counterpartName: string; readonly label: string; readonly day: string; }
export interface EarningItem {
  readonly id: string; readonly payeeId: string; readonly subjectType: PaymentSubject; readonly subjectId: string;
  readonly counterpartName: string; readonly subjectLabel: string; readonly day: string; readonly amount: number;
  readonly state: EarningState; readonly holdReason: string | null; readonly paidOutAt: string | null; readonly updatedAt: string;
}
export interface EarningsSummary {
  readonly payeeId: string; readonly heldAmount: number; readonly soonAmount: number; readonly receivedAmount: number;
  readonly lastPayout: { readonly id: string; readonly status: PayoutStatus; readonly at: string } | null; readonly updatedAt: string;
}
export function earningStateOf(p: Payment): EarningState | null;   // held|partially_refunded → held; disputed → disputed; released → released; paid_out → paid_out; else null
export function earningItemOf(i: { payment: Payment; refunded: number; subject: EarningSubject; payout: Payout | null; now: Date }): EarningItem | null; // null when no payee, state null or net ≤ 0
export function summarizeEarnings(payeeId: string, items: readonly EarningItem[], lastPayout: Payout | null, now: Date): EarningsSummary;

// earnings_ports.ts
export interface EarningsTx {
  getPayment(id: string): Promise<Payment | null>;
  refundedTotal(paymentId: string): Promise<number>;
  getSubject(p: Payment): Promise<EarningSubject | null>;      // null when the booking is gone
  getPayout(id: string): Promise<Payout | null>;
  latestPayout(payeeId: string): Promise<Payout | null>;       // newest createdAt
  listItems(payeeId: string): Promise<EarningItem[]>;
  putItem(i: EarningItem): void; deleteItem(payeeId: string, id: string): void; putSummary(s: EarningsSummary): void;
}
export interface EarningsStore { runTransaction<T>(fn: (tx: EarningsTx) => Promise<T>): Promise<T>; }
export interface EarningsDeps { readonly store: EarningsStore; readonly clock: Clock; }
// refresh_earnings.ts
export function refreshEarnings(deps: EarningsDeps, input: { payeeId: string; paymentIds: readonly string[] }): Promise<EarningsSummary>;

// payout_ports.ts additions to PayoutTx
listPayablePayments(payeeId: string): Promise<Payment[]>;     // escrowStatus 'released' and no payoutId
getPayments(ids: readonly string[]): Promise<(Payment | null)[]>;
refundedTotal(paymentId: string): Promise<number>;
getPayout(id: string): Promise<Payout | null>;
setPayment(p: Payment): void; addLedgerEntry(e: LedgerEntry): void;
// PayoutStore addition (outside a transaction, for the CLI)
listDuePayees(): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]>;
export interface PayoutGateway {
  transfer(r: { payoutId: string; amount: number; bankCode: string; accountNumber: string; holderName: string }):
    Promise<{ status: 'paid' | 'failed'; reference?: string; failureReason?: string }>;
}
export interface PayoutDeps extends PayoutAccountDeps { readonly gateway: PayoutGateway; }

// payout_use_cases.ts
export interface StaffActor { readonly uid: string; readonly isAdmin: boolean; }
export function createPayout(deps: PayoutDeps, actor: StaffActor, payeeId: string): Promise<Payout>;
export function executePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout>;
export function holdPayout(deps: PayoutDeps, actor: StaffActor, payoutId: string, reason: string): Promise<Payout>;  // reason 5–200 graphemes
export function resumePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout>;
export function listDuePayees(deps: PayoutDeps, actor: StaffActor): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]>;
// fake_payout_gateway.ts
export class FakePayoutGateway implements PayoutGateway { readonly calls: string[]; }   // Decision 10
```

Behaviour:
- Every payout use case: `!actor.isAdmin` → `permission_denied`.
- `createPayout`: no active account → `not_eligible`; payable = `listPayablePayments`, net = amount − refunded, skip net ≤ 0; none → `not_eligible`; one `pending` payout `{amount = Σ items, accountId = active id, createdBy = actor.uid}`; each payment gets `payoutId`.
- `executePayout`: tx 1: status must be `pending` or `processing` (`on_hold`, `paid`, `failed` → `conflict`); set `processing`, `processingAt`. Decrypt the account (`getAccount(payeeId, accountId)`, `cipher.decrypt`) outside the transaction, call `gateway.transfer`. tx 2 (re-read; if no longer `processing` → `conflict`): `paid` → payout `paid`, `paidAt`, `reference`; each payment `escrowStatus: 'paid_out'` and one `payout_paid` ledger entry per item (Decision 11); `failed` → payout `failed`, `failureReason`; each payment `payoutId: null`.
- `holdPayout`: `pending` → `on_hold` with `holdReason`; `resumePayout`: `on_hold` → `pending`, `holdReason` cleared.
- `refreshEarnings`: in one transaction read every named payment (+ refunded total, subject, its payout), all current items and the latest payout; put or delete each named item; recompute the summary from the merged items; write it. A payment of another payee is ignored.

Sample (easy to get wrong: reads before writes, and the summary from the merged rows):

```ts
return deps.store.runTransaction(async (tx) => {
  const now = deps.clock.now();
  const existing = new Map((await tx.listItems(payeeId)).map((i) => [i.id, i]));
  const next = new Map(existing);
  for (const id of new Set(paymentIds)) {
    const p = await tx.getPayment(id);
    if (p !== null && p.payeeId !== payeeId) continue;
    const subject = p === null ? null : await tx.getSubject(p);
    const item = p === null || subject === null ? null : earningItemOf({
      payment: p, refunded: await tx.refundedTotal(id), subject,
      payout: p.payoutId ? await tx.getPayout(p.payoutId) : null, now });
    if (item === null) next.delete(id); else next.set(id, item);
  }
  const summary = summarizeEarnings(payeeId, [...next.values()], await tx.latestPayout(payeeId), now);
  for (const id of existing.keys()) if (!next.has(id)) tx.deleteItem(payeeId, id);
  for (const [id, item] of next) if (!sameItem(existing.get(id), item)) tx.putItem(item);
  tx.putSummary(summary);
  return summary;
});
```

(`sameItem` compares every field except `updatedAt`, so a retry writes only the summary.)

- [ ] **Step 1: Write the failing tests:**
  - `earnings.test.ts`: "held and partially refunded payments are Đang giữ with the kept amount"; "a disputed payment carries its reason"; "a fully refunded payment has no row"; "a released payment in an on_hold payout shows the hold reason"; "paid_out rows carry the payout date"; "summary adds disputed money to held"; "summary counts released money in pending, processing and failed payouts as soon"; "summary equals the ledger sums" (world built with the booking use cases: deposit, 50 % refund, release, a dispute, a paid payout; held = Σ received − refund_issued − escrow_released of held payments, soon = Σ escrow_released − Σ |payout_paid| over released payments, received = Σ |payout_paid|).
  - `refresh_earnings.test.ts`: "refresh writes the named rows and the summary"; "a payment of another payee is ignored"; "refresh is idempotent" (second run writes only the summary); "a deleted booking removes its row".
  - `payout_use_cases.test.ts`: "a non-admin is permission_denied"; "no active account is not_eligible"; "held and disputed payments are never batched"; "the payout amount equals the sum of its items"; "a payment already in an open payout is not batched twice"; "execute pays, marks payments paid_out and writes one payout_paid per item"; "executing a paid payout is a conflict"; "a retried execute uses the same gateway call" (fake gateway sees `payoutId` once in its outcome map); "a failed payout returns its payments" (account ending 0000 → payments payable again); "an on_hold payout cannot execute until resumed"; "hold needs a 5–200 character reason"; "due payees list released money and whether they have an account".
- [ ] **Step 2: Run** `npm test` → fail. **Step 3: Implement** (+ index exports). **Step 4: Run** `npm test && npm run typecheck && npm run lint` → pass.
- [ ] **Step 5: Update the data-model docs** listed above.
- [ ] **Step 6: Commit** `feat(domain): earnings read model and payouts with a fake gateway [10b]`.

### Task 3: Functions — cipher, `savePayoutAccount`, earnings triggers, staff CLI, rules, indexes, seed

**Files:**
- Create: `functions/src/infra/account_cipher.ts`, `payout_firestore.ts`, `earnings_firestore.ts`, `live_payout.ts`; `src/callables/payout_account.ts`; `src/triggers/payment_write.ts`, `payout_write.ts`; `tools/payouts.ts`; `.secret.local`
- Modify: `src/infra/booking_firestore.ts` (map `dispute {reason, openedAt: Timestamp}` and `payoutId` both ways; absent → `null`), `src/callables/errors.ts` (`reauth_required: 'failed-precondition'`), `src/config.ts` (`PAYOUT_ACCOUNT_KEY = defineSecret('PAYOUT_ACCOUNT_KEY')`, `payoutsMode()` = `'fake'` when `FUNCTIONS_EMULATOR === 'true'` or `PAYOUTS_MODE === 'fake'`, else `'off'`), `src/index.ts`, `package.json` (`"payouts": "tsx tools/payouts.ts"`), `.env.booking-c1922` (add `PAYOUTS_MODE=fake`), `seed/fixtures.ts`, `seed/README.md`
- Modify: `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`; `docs/FIREBASE-SETUP.md` (new section "Payout account key": create the secret, grant the CI deploy service account `roles/secretmanager.admin` on it, emulator key in `.secret.local`)
- Test: `test/unit/account_cipher.test.ts`, `payout_account_callable.test.ts`, `payout_cli.test.ts`, `earnings_firestore.test.ts`; `test/integration/earnings.test.ts`

**Interfaces:**
- Produces: callable `savePayoutAccount({bankCode, accountNumber, holderName}) → {accountId, accountLast4}` (`onCall({...CALLABLE_OPTIONS, secrets: [PAYOUT_ACCOUNT_KEY]})`); triggers `onPaymentWritten` (`payments/{paymentId}`, `TRIGGER_OPTIONS`: payee = `after?.payeeId ?? before?.payeeId`; none → skip; `refreshEarnings(payee, [paymentId])`) and `onPayoutWritten` (`payouts/{payoutId}`: payee as above, `paymentIds` = union of before/after `items[].paymentId`); CLI `npm run payouts -- due | show <payoutId> | create <payeeId> --actor <uid> | execute <payoutId> --actor <uid> | hold <payoutId> "<reason>" --actor <uid> | resume <payoutId> --actor <uid>`.
- Firestore shapes: `earnings/{uid}` `{heldAmount, soonAmount, receivedAmount, lastPayout: {id, status, at: Timestamp} | null, updatedAt}`; `earnings/{uid}/items/{paymentId}` `{payeeId, subjectType, subjectId, counterpartName, subjectLabel, day, amount, state, holdReason, paidOutAt: Timestamp | null, updatedAt}`; `payoutAccounts/{uid}` and `/accounts/{accountId}` per Decision 6; `payouts/{id}` per `Payout` (instants as Timestamps, `items` array).

`account_cipher.ts` (sample; the IV must be fresh per value and the tag checked):

```ts
export function aesGcmCipher(keyB64: string): AccountCipher {
  const key = Buffer.from(keyB64, 'base64');
  if (key.length !== 32) throw new Error('PAYOUT_ACCOUNT_KEY must be 32 bytes, base64');
  return {
    encrypt: async (plain) => {
      const iv = randomBytes(12);
      const c = createCipheriv('aes-256-gcm', key, iv);
      const data = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
      return ['v1', iv.toString('base64'), c.getAuthTag().toString('base64'), data.toString('base64')].join(':');
    },
    decrypt: async (enc) => {
      const [v, iv, tag, data] = enc.split(':');
      if (v !== 'v1' || !iv || !tag || !data) throw new Error('unknown ciphertext version');
      const d = createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'base64'));
      d.setAuthTag(Buffer.from(tag, 'base64'));
      return Buffer.concat([d.update(Buffer.from(data, 'base64')), d.final()]).toString('utf8');
    },
  };
}
```

Also export a synchronous `encryptSyncForSeed(keyB64, plain)` for `seedDocuments(now)` (same format).

Callable: `authTime` = `request.auth.token.auth_time` (seconds) → `Date`, else null; widen the local `CallableInput` type with `token?: { auth_time?: number }`. Use the album `run()` pattern: log only the code, never `request.data`. The CLI reads `PAYOUT_ACCOUNT_KEY` from the environment (or `.secret.local` when `FIRESTORE_EMULATOR_HOST` is set), checks the actor's `staffRole` claim through the Auth Admin SDK, uses `FakePayoutGateway` only when `payoutsMode()` is `'fake'` (else a gateway that throws `not_eligible`), and `show` prints the masked account (`•••• 6789`) only.

Rules (sample):

```
match /earnings/{uid} {
  allow read: if isOwner(uid);
  allow write: if false;
  match /items/{itemId} { allow read: if isOwner(uid); allow write: if false; }
}
match /payoutAccounts/{uid} {
  allow read: if isOwner(uid);          // masked view only
  allow write: if false;                // savePayoutAccount
  match /accounts/{accountId} { allow read, write: if false; }   // ciphertext, server only
}
match /payouts/{payoutId} {
  allow read: if signedIn() && resource.data.payeeId == request.auth.uid;   // matrix: người nhận
  allow write: if false;
}
```

Indexes: `payouts (payeeId ASC, createdAt DESC)`, `payouts (status ASC, createdAt ASC)` (CLI). Items use the automatic `day` index.

Seed (`seedDocuments(now)`, emulator key from `.secret.local`): An gets a payout account (VCB, `0123456789`, `NGUYEN VAN AN`); `seed-booking-completed-old`'s payment becomes `paid_out` in `seed-payout-an-1` (`paid`, with its `payout_paid` ledger entry); a new booking `seed-booking-disputed` (Lan ↔ An, completed 10 h before seeding) with a `disputed` payment, reason "Ảnh giao thiếu so với gói"; Bình has no account. The seed also writes the `earnings` projection by running the pure `earningItemOf`/`summarizeEarnings` over the seeded payments (so it does not depend on trigger timing). Update `seed_fixtures.test.ts` counts and `seed/README.md` (tables + "Staff CLI for payouts").

- [ ] **Step 1: Write the failing tests.** Unit: "encrypt then decrypt returns the number"; "two encryptions of one number differ"; "a tampered ciphertext fails"; "a key that is not 32 bytes is refused"; "unauthenticated save is refused"; "auth_time reaches the use case as authTime"; "reauth_required maps to failed-precondition with details.code"; "a refused save logs only the code" (spy on the logger: no call contains the digits); "payment mapping keeps dispute and payoutId"; "earnings mapping round-trips an item"; CLI "create needs --actor"; "execute refuses outside fake mode"; "show masks the account number"; "due lists payees with released money". Integration (do not run): "a released payment appears in Sắp nhận"; "two payments released together give one consistent summary"; "a dispute updates the row with its reason"; "savePayoutAccount stores ciphertext and the masked view"; "a fresh sign-in may change the account". Rules (do not run): "the owner reads their earnings"; "another user cannot read earnings or items"; "nobody writes earnings"; "the owner reads the masked account view"; "the owner cannot read the accounts history"; "a payee reads their payouts"; "payments stay closed".
- [ ] **Step 2: Run** `(cd app_flutter/firebase/functions && npm test)` → fail. **Step 3: Implement.** **Step 4: Run** `npm test && npm run typecheck && npm run lint && npm run build` → pass; ledger the skipped emulator suites.
- [ ] **Step 5: Commit** `feat(functions): payout account callable, earnings projection, payouts CLI [10b]`.

### Task 4: App data — earnings repository, bank list, input rules, re-authentication

**Files:**
- Create: `app_flutter/lib/data/earnings/earnings.dart`, `vn_banks.dart`, `payout_account_rules.dart`, `earnings_repository.dart` (interface + `FakeEarningsRepository`), `firestore_earnings_repository.dart`, `earnings_providers.dart`
- Modify: `lib/data/auth/auth_repository.dart` (interface, Firebase and fake implementations), `auth_error.dart` (`requiresRecentLogin` mapping if needed)
- Test: `test/data/earnings/earnings_parsing_test.dart`, `firestore_earnings_repository_test.dart`, `payout_account_rules_test.dart` (reads `../packages/domain/test/fixtures/payout_account.json`), `vn_banks_sync_test.dart` (reads `../packages/domain/src/vn_banks.ts`), `test/data/auth/reauthenticate_test.dart`

**Interfaces:**
- Produces:

```dart
enum EarningState { held, disputed, released, paidOut }   // codes 'held','disputed','released','paid_out'; unknown code → row skipped
@immutable class EarningItem {
  const EarningItem({required this.id, required this.subjectType, required this.subjectId, required this.counterpartName,
    required this.subjectLabel, required this.day, required this.amountVnd, required this.state, this.holdReason, this.paidOutAt});
  final String id, subjectType, subjectId, counterpartName, subjectLabel, day;   // day = yyyy-MM-dd
  final int amountVnd; final EarningState state; final String? holdReason; final DateTime? paidOutAt;
}
@immutable class EarningsSummary {
  const EarningsSummary({this.heldVnd = 0, this.soonVnd = 0, this.receivedVnd = 0, this.lastPayoutFailed = false, this.fromCache = false});
  final int heldVnd, soonVnd, receivedVnd; final bool lastPayoutFailed, fromCache;   // missing doc → all zero
}
@immutable class PayoutAccountView { final String accountId, bankCode, accountLast4, holderName; final DateTime updatedAt; }
@immutable class VnBank { final String code, bin, shortName, name; }
const List<VnBank> vnBanks = [...];               // same order as VN_BANKS
VnBank? bankByCode(String code);
String? normalizeAccountNumber(String raw);       // mirrors TS
String? normalizeHolderName(String raw);          // mirrors TS
String maskedAccount(String last4) => '•••• $last4';

abstract class EarningsRepository {
  Stream<EarningsSummary> watchSummary(String uid);                        // fromCache from snapshot metadata
  Stream<List<EarningItem>> watchItems(String uid, {required int limit});  // day desc, id desc
  Stream<PayoutAccountView?> watchAccount(String uid);
  Future<({String accountId, String accountLast4})> saveAccount({required String bankCode, required String accountNumber, required String holderName});
}
class PayoutAccountError implements Exception { const PayoutAccountError(this.code); final String code; }
// codes: 'reauth_required','conflict','invalid_argument','permission_denied','network','unknown'

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) => FirestoreEarningsRepository());
final earningsSummaryProvider = StreamProvider.autoDispose<EarningsSummary>(...);          // signed-in uid; signed out → empty
final earningItemsProvider = StreamProvider.autoDispose.family<List<EarningItem>, int>(...); // arg = limit
final payoutAccountProvider = StreamProvider.autoDispose<PayoutAccountView?>(...);

// auth_repository.dart
enum ReauthMethod { password, google, facebook }
abstract class AuthRepository {
  // existing members …
  ReauthMethod? get reauthMethod;                     // from the current user's providers; null when signed out
  /// Signs the current user in again (password for email accounts, else the provider flow), then refreshes
  /// the ID token so callables see a new auth_time. Throws AuthException (cancelled, wrongPassword, network, unknown).
  Future<void> reauthenticate({String? password});
}
```

`FirestoreEarningsRepository.saveAccount` calls `savePayoutAccount` in `functionsRegion` and maps `FirebaseFunctionsException.details['code']` (fallback `message`; `unavailable`/`deadline-exceeded` and `SocketException` → `network`) like `bookingErrorOf`. It never logs its arguments. `FakeEarningsRepository` has `emitSummary`, `emitItems`, `setAccount`, `failNextSave(code)`, and records `saves` as `bankCode:last4` only.

- [ ] **Step 1: Contract check** (app part). **Step 2: Write the failing tests:** "a summary doc parses its three totals"; "a missing summary doc is all zero"; "a failed last payout sets lastPayoutFailed"; "a cached snapshot sets fromCache"; "an item doc parses state, reason and payout date"; "an unknown state is skipped"; "items are asked newest day first with the limit"; "the account view never has a full number field"; "saveAccount maps reauth_required"; "saveAccount maps a network failure"; rules mirror "holder and number cases match the shared fixture"; "bank list equals VN_BANKS"; auth "email users re-authenticate with their password"; "a cancelled provider flow throws cancelled"; "the fake records re-authentication".
- [ ] **Step 3: Run** `flutter test test/data` → fail. **Step 4: Implement.** **Step 5: Run** `flutter analyze && flutter test test/data` → pass.
- [ ] **Step 6: Commit** `feat(data): earnings repository, bank list and re-authentication [10b]`.

### Task 5: `StatTile.onTap`, `EarningRow`, S06.05 Thu nhập and its entry points

**Files:**
- Modify: `lib/core/widgets/stat_tile.dart` (`onTap`), `lib/core/core.dart`; create `lib/core/widgets/earning_row.dart`; gallery (`scripts/tools/build_ui_components.py`, regenerate `docs/design/ui-components.html`), `docs/superpowers/specs/components/shared-components.md` (`StatTile` `onTap`, `EarningRow`)
- Create: `lib/features/earnings/earnings_screen.dart`, `earnings_controller.dart`, `earnings_analytics.dart`
- Modify: `lib/app/router.dart` (`/work/earnings`, `photographersOnly()`), `lib/features/work/work_screen.dart` ("Đang giữ" tile `onTap` → `/work/earnings`; remove the "does nothing" comment), `lib/features/shell/placeholder_tabs.dart` (photographers: `_EarningsRow` "Thu nhập" after "Album của tôi", `Key('open-earnings')`), `lib/l10n/app_vi.arb` (one block)
- Test: `test/core/widgets/stat_tile_test.dart` (extend), `earning_row_test.dart`, `test/features/earnings/earnings_screen_test.dart`, `test/features/work/work_screen_test.dart` (extend), `test/features/shell/profile_tab_test.dart` (extend)

**Interfaces:**
- Produces:

```dart
// StatTile gains: final VoidCallback? onTap;  → Semantics(button: true, label: '$value, $label'), InkWell with the tile radius, ≥ 48 dp
class EarningRow extends StatelessWidget {     // mock S06.05 .card: title + meta left; amount (tabular) + badge right; optional note line
  const EarningRow({super.key, required this.title, required this.meta, required this.amount, required this.amountLabel,
    required this.badge, this.note, this.noteIcon, this.onTap});
  static Widget skeleton({Key? key});
  final String title, meta, amount;   // amount already formatted (short)
  final String amountLabel;           // full amount for screen readers
  final Widget badge; final String? note; final IconData? noteIcon; final VoidCallback? onTap;
}
// features/earnings
class EarningsScreen extends ConsumerWidget { const EarningsScreen({super.key}); }   // ScreenCode(ScreenCodes.earnings, …)
final earningsLimitProvider = NotifierProvider.autoDispose<EarningsLimit, int>(...);  // 30, +30 on "Xem thêm"
List<({String monthKey, List<EarningItem> items})> groupByMonth(List<EarningItem> items);   // pure, tested
final earningsAnalyticsProvider = Provider<void Function(String, Map<String, Object>)>((ref) => (_, _) {});
```

Behaviour (mock `#S06.05`):
- App bar: back, title `earningsTitle`, `IconButton(AppIcons.settings, tooltip: payoutAccountTitle)` → `/work/earnings/account`.
- Body (scroll): `OfflineBanner` when `summary.fromCache`; `EscrowNotice(text: earningsNotice)`; `StatTileRow` of three `StatTile`s (`formatMoney(v, short: true)`; labels `earningsHeld`, `earningsSoon`, `earningsReceived`); failed-payout banner (`GlassCard`, `AppIcons.warning`, `earningsPayoutFailed`, tap → S06.06) when `lastPayoutFailed`; add-account card (`AppIcons.payment`, `earningsAddAccount` / `earningsAddAccountSub`, chevron, tap → S06.06) when `payoutAccountProvider` is `null`; `SectionHeader` `earningsItems` with the first month on the right (mock "Các khoản · Tháng 10"), later months as their own headers; rows = `EarningRow(title: "$name · $label", meta: formatDay(day), amount: formatMoney(short: true), badge: StatusBadge.custom(...), note: holdReason != null ? earningsHoldReason(reason) : null, noteIcon: AppIcons.warning)`; badge colours: held → `bookingWaiting`, released → `warning` with dark ink, paidOut → `success` ("Đã chuyển {dd/MM}" from `paidOutAt`), disputed → `bookingDenied`; tap → `/b/$subjectId` for `booking` rows and `earnings_item_open{state}`. "Xem thêm" outline button at the end when the page was full.
- Every async part through `AsyncView` (skeletons: `StatTile.skeleton()` ×3, `EarningRow.skeleton()` ×4). Empty (no rows) → `EmptyState(title: earningsEmptyTitle, body: earningsEmptyBody)` below the tiles (tiles still show zeros). `earnings_open` once on first build.
- No primary button on this screen.

Strings (block): `earningsTitle` "Thu nhập", `earningsNotice` (spec text), `earningsHeld` "Đang giữ", `earningsSoon` "Sắp nhận", `earningsReceived` "Đã nhận", `earningsStateHeld` "Đang giữ", `earningsStateReleased` "Chờ chi trả", `earningsStatePaid` "Đã chuyển {date}", `earningsStateDispute` "Đang khiếu nại", `earningsAddAccount` "Thêm tài khoản để nhận tiền", `earningsAddAccountSub` "Cần có trước khi chuyển khoản", `earningsItems` "Các khoản", `earningsMonth` "Tháng {month}", `earningsMonthYear` "Tháng {month}/{year}", `earningsPayoutFailed` "Chuyển khoản lỗi, kiểm tra tài khoản", `earningsHoldReason` "Lý do: {reason}", `earningsCustomerFallback` "Khách", `earningsEmptyTitle` "Chưa có khoản thu nào", `earningsEmptyBody` "Khoản đầu tiên hiện ở đây khi khách đặt lịch và thanh toán cọc cho bạn.", `earningsMore` "Xem thêm", `profileEarnings` "Thu nhập", `profileEarningsSub` "Tiền đang giữ, sắp nhận và đã nhận".

- [ ] **Step 1: Write the failing tests:** core "a tile with onTap is a button and calls it"; "a tile without onTap is not a button"; "earning row reads title, date, full amount and badge"; "earning row shows its note with an icon"; "skeleton has the row's shape"; screen "the three totals show in one row at 320 dp and text scale 1.3"; "rows group by month newest first"; "a held row shows Đang giữ"; "a paid row shows Đã chuyển with its date"; "a disputed row shows Đang khiếu nại and the reason"; "without an account the add-account card opens S06.06"; "with an account the card is hidden"; "a failed last payout shows the banner"; "the settings icon opens S06.06"; "tapping a booking row opens its detail and logs earnings_item_open"; "no rows shows the empty state"; "a cached summary shows the offline banner"; "Xem thêm raises the limit"; `groupByMonth` "keeps day order inside a month"; work "the Đang giữ tile opens Thu nhập"; profile tab "photographers see Thu nhập" and "customers do not".
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** `flutter gen-l10n && flutter analyze && flutter test test/core test/features` → pass.
- [ ] **Step 5: Commit** `feat(earnings): S06.05 Thu nhập, EarningRow and tappable StatTile [10b]`.

### Task 6: S06.06 Tài khoản nhận tiền

**Files:**
- Create: `lib/features/earnings/payout_account_screen.dart`, `payout_account_controller.dart`, `widgets/bank_picker_sheet.dart`, `widgets/reauth_sheet.dart`, `widgets/account_inputs.dart`
- Modify: `lib/app/router.dart` (`/work/earnings/account`, `photographersOnly()`), `lib/l10n/app_vi.arb` (block)
- Modify docs: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S06.05, S06.06 status "✅ đã làm (10b)"), §3g.4 (one line: payouts run through the staff CLI with a fake gateway until a bank provider and S23 exist); `specs/screens/photographer.md` (S06.05/S06.06 "Đã có"; settings icon per mock; hold reason; month sections; re-confirmation = recent sign-in)
- Test: `test/features/earnings/payout_account_screen_test.dart`, `bank_picker_sheet_test.dart`, `account_inputs_test.dart`, `payout_account_controller_test.dart`

**Interfaces:**
- Consumes: `payoutAccountProvider`, `EarningsRepository.saveAccount`, `authRepositoryProvider` (`reauthMethod`, `reauthenticate`), `vnBanks`, `normalizeAccountNumber`, `normalizeHolderName`, `showAppSheet`, `showConfirmSheet(danger: false)`, `AppButton`.
- Produces:

```dart
class PayoutAccountScreen extends ConsumerWidget { const PayoutAccountScreen({super.key}); }   // ScreenCode(ScreenCodes.payoutAccount, …)
Future<VnBank?> showBankPicker(BuildContext context, {String? selected});   // enableDrag: false (search field)
Future<bool> showReauthSheet(BuildContext context);                          // true after a successful reauthenticate
class AccountNumberFormatter extends TextInputFormatter { }   // digits only, groups of 4 ("0123 4567 890"), max 20 digits, caret kept
class HolderNameFormatter extends TextInputFormatter { }      // normalizeHolderName on the fly (upper-case, no diacritics, single spaces)
// controller state
@immutable class PayoutAccountForm { final VnBank? bank; final String number; final String holder; final bool editing; final bool saving; }
```

Behaviour (mock `#S06.06`):
- No account → form: intro `payoutAccountIntro`; field "Ngân hàng" (tap → bank picker: search by short or full name, accent-insensitive; rows "shortName · name"); "Số tài khoản" (`AccountNumberFormatter`, numeric keyboard, `tabularFigures`); "Tên chủ tài khoản" (`HolderNameFormatter`, `TextCapitalization.characters`); note `payoutAccountHint`; primary `AppButton.primary(payoutAccountSave)` in the bottom bar, enabled only when bank chosen and both normalisers return a value; format errors under the fields after the field loses focus (`payoutAccountNumberError`, `payoutAccountHolderError`).
- Account exists → read view: bank name, `maskedAccount(last4)` (`tabularFigures`), holder, note; `AppButton.outline(payoutAccountChange)` opens the empty form (bank preselected). No full number is ever kept after a save (controller clears it).
- Save of a change → `showConfirmSheet(title: payoutAccountChangeTitle, body: payoutAccountChangeBody, confirmLabel: payoutAccountChangeConfirm, keepLabel: actionCancel, danger: false)` first. Then `saveAccount`; `reauth_required` → `showReauthSheet` (email: password field + `payoutAccountReauthGo`; Google/Facebook: body + button that runs the provider flow) → on success retry once; cancelled → nothing (input kept). `conflict` → SnackBar `payoutAccountBusy`; other errors → SnackBar `payoutAccountSaveError`; input kept in every failure. Success → SnackBar `payoutAccountSaved`, back to the read view, `payout_account_save{change}` (no other parameters).
- The account number and holder name are never passed to analytics, `debugPrint` or error reports.

Strings (block): `payoutAccountTitle` "Tài khoản nhận tiền", `payoutAccountIntro` "Chúng tôi chuyển tiền sau mỗi buổi chụp hoàn thành vào tài khoản này.", `payoutAccountBank` "Ngân hàng", `payoutAccountBankPick` "Chọn ngân hàng", `payoutAccountBankSearch` "Tìm ngân hàng", `payoutAccountBankNone` "Không tìm thấy ngân hàng", `payoutAccountNumber` "Số tài khoản", `payoutAccountHolder` "Tên chủ tài khoản", `payoutAccountSave` "Lưu tài khoản", `payoutAccountHint` "Tên chủ tài khoản phải trùng tên bạn đã xác minh. Số tài khoản được mã hoá và chỉ hiện 4 số cuối.", `payoutAccountMasked` "•••• {last4}", `payoutAccountChange` "Đổi tài khoản", `payoutAccountNumberError` "Số tài khoản gồm 6–20 chữ số", `payoutAccountHolderError` "Nhập họ tên viết hoa không dấu, 2–50 chữ cái", `payoutAccountChangeTitle` "Đổi tài khoản nhận tiền?", `payoutAccountChangeBody` "Các khoản chưa chuyển sẽ chuyển vào tài khoản mới. Khoản đã chuyển không thay đổi.", `payoutAccountChangeConfirm` "Đổi tài khoản", `payoutAccountReauthTitle` "Xác nhận lại để đổi tài khoản", `payoutAccountReauthBody` "Vì an toàn, hãy đăng nhập lại trước khi đổi tài khoản nhận tiền.", `payoutAccountReauthPassword` "Mật khẩu", `payoutAccountReauthGo` "Xác nhận", `payoutAccountReauthWrong` "Mật khẩu chưa đúng", `payoutAccountSaved` "Đã lưu tài khoản nhận tiền", `payoutAccountSaveError` "Không lưu được. Thử lại", `payoutAccountBusy` "Đang chuyển một lô tiền, thử lại sau ít phút".

- [ ] **Step 1: Write the failing tests:** inputs "number groups by four and keeps the caret"; "letters are dropped from the number"; "holder name turns upper-case without diacritics while typing"; picker "search finds Vietcombank by vietcom and by VCB"; "search ignores diacritics"; "picking closes the sheet with the bank"; screen "save stays disabled until bank, number and holder are valid"; "a short number shows the error under its field"; "first save sends normalised values and shows the masked view"; "an existing account shows •••• and Đổi tài khoản, never the full number"; "a change asks to confirm first"; "reauth_required re-authenticates and retries once"; "a cancelled re-authentication keeps the input"; "a wrong password shows the error in the sheet"; "conflict shows the busy SnackBar and keeps the input"; "analytics gets no account data" (fake logger params ⊆ {change}); "S06.06 is for photographers only" (router redirect).
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** `flutter gen-l10n && flutter analyze && flutter test` → pass.
- [ ] **Step 5: Update** the spec cells and notes listed above.
- [ ] **Step 6: Commit** `feat(earnings): S06.06 Tài khoản nhận tiền with re-confirmation [10b]`.

---

## Needs the owner

1. **Secret before merge.** Create the secret in the dev project and let CI bind it: `openssl rand -base64 32 | firebase functions:secrets:set PAYOUT_ACCOUNT_KEY --project dev --data-file -`, and give the CI deploy service account (`FIREBASE_SERVICE_ACCOUNT` of the `dev` environment) `roles/secretmanager.admin` (deploy grants the runtime accessor role). Without it the `deploy-functions` job fails on `develop`. Same again for `prod` when that project exists. Keep the key safe: losing it makes stored account numbers unreadable.
2. **Real payouts.** A bank/payout provider (chi hộ API) and the legal review of holding money (open question 19) are needed before any real payout; this plan only has the port, a fake adapter, and the staff CLI.
3. **Dispute text visible to the photographer.** Decision 5 shows the customer's dispute reason verbatim on S06.05. Confirm, or ask for a fixed "Khách đã báo vấn đề, đang chờ xử lý" instead (a one-line change in the projection).
4. **Holder name check.** "Tên chủ tài khoản phải trùng tên bạn đã xác minh" is only a hint until identity verification (S21) exists; confirm that saving an unmatched name is acceptable for now.
