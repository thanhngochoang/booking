# S22 · Thanh toán & tài khoản (payment history, refund account, delete account, privacy & data) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (2026-10-02, user):** this plan changes `firestore.rules`, `storage.rules`, indexes and adds Functions. Write the rules tests and the integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A customer sees every payment in one place (S22.01: method, held money including Chụp ngay still searching, refunds in progress and done, no word "cọc"), chooses where a bank-transfer refund goes (S22.04: the account that paid, or another one with the holder name looked up), deletes the account when nothing is pending (S22.02, with each blocker listed and a way to it; the account is locked at once and purged after 30 days, and signing in within those 30 days offers "Khôi phục tài khoản" on S22.05), and on S22.03 hides a photographer profile from suggestions and search and downloads a copy of their data.

**Architecture:** Builds on #129's payment model. `packages/domain` gets: the payer history projection (`payerRowOf`, `refreshPayerHistory`) written by the existing `onPaymentWritten` trigger and a new `onRefundWritten` trigger into `users/{uid}/payments/{paymentId}` (customer-readable, no provider refs, no account numbers); the refund-account rules (policy refunds paid by bank transfer wait in `awaiting_account` for the customer's choice, default to the paying account after 24 hours; a name-lookup port with a fake adapter); account deletion (pure blockers, a data map, a reauthenticated request that locks the account for a 30-day restore window (`deletion_pending`, sessions revoked, hidden from discovery), a restore call, then a step in the existing daily `pruneNotifications` job that starts the purge of due accounts and an idempotent purge trigger that tombstones `users/{uid}`); and data export (pure document builder, cooldown, a callable that writes JSON to Storage `exports/{uid}/`). Functions stay thin adapters (Firestore, Storage, Auth Admin). The app gets `features/payments/` (S22.01, S22.04), `features/account/` (S22.02, S22.03), new rows on S09.02, the S05.02/S05.03/S11.04/S18.02 hooks into S22.04, the S22.05 restore screen behind a router guard, and the discovery filter. Money stays on the fake gateway.

**Tech Stack:** TypeScript (`packages/domain`, `node --test`; Functions v2 `onCall`, `onDocumentWritten`, `onDocumentCreated`, Admin SDK Firestore/Storage/Auth), Firestore and Storage rules, indexes; Flutter, Riverpod 3, go_router, freezed (`Booking`), `firebase_storage` (download URL), `url_launcher` via `externalLauncherProvider`, `flutter_test`.

**Spec:** main spec `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S22 rows), §3i.5 (S22.01–S22.03), §8 question 25; `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §3.3, §5 (refund by method, S22.04), §12 (S22.01, S22.04); `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §9 (deletion keeps `idHash`, when #135 exists); `docs/superpowers/specs/screens/account.md` (S09.02); `docs/legal/terms-and-help-notes.md` P10, P11; mock `docs/design/ui-mock.html` `#S22.04`, `#S05.03`, `#S06.05` (row pattern), `#S06.06` (account form), `#S09.02`; plan `docs/superpowers/plans/2026-10-07-s04-payments.md` (#129 as built, PR #154) and `2026-10-08-s04-reconciliation.md` (what the superseded `2026-10-07-s04-booking-payment.md` promised and who builds it now: V2 for `awaiting_account` and payer capture; the clock rule); `2026-10-07-s06-work-earnings.md` (#134: `account_lookup.ts`, the moved re-auth sheet); `2026-10-07-s17-notifications.md` (#138: the `notifyRefundAccountNeeded` hook, copy and target); `2026-10-07-s18-disputes-help.md` (#142: `dispatchDisputeRefund`, S18.02); `2026-10-07-s09-profile-settings.md` (#148: `settingsGroupOrder`).

**Split (owner, 2026-10-08):** this plan holds two issues.
- **#205** (S22 · Xoá tài khoản & quyền riêng tư): Tasks 1–5 — delete account with the 30-day restore (S22.02, S22.05), privacy & data export (S22.03), hide from discovery, the S09.02 group "Thanh toán và dữ liệu" with its privacy row. **Blocked by: nothing.** Its inputs are merged: #148 (S09, in #188: `settingsGroupOrder` slot `paymentsData`), #134 (S06, in #193: `REAUTH_MAX_AGE_SECONDS`, `earnings/{uid}`, `lib/features/account/widgets/reauth_sheet.dart`), #129 (S04, in #154: `payments`, `refunds`, the order-gate adapter). The money blockers read `payments` and `refunds` directly (Decision 12), not #141's history rows, so #205 does not wait for #141. The other blocker sources (#136, #139, #140, #151, #152, #142) are soft: a source whose plan has not merged reads an empty collection and its blocker is simply absent until it lands; the `ACCOUNT_DATA_MAP` rows for their collections are no-ops until then (#135's identity row too). Branch `plan/205-s22-delete-account-privacy`, PR into `develop` titled `feat(account): S22.02 delete account with restore, S22.03 privacy and data [#205]`.
- **#141** (S22 · Thanh toán & tài khoản): Tasks 6–11 — payer payment history (S22.01) and the refund account (S22.04). **Blocked by: #201** (V2 refund destination, `docs/superpowers/plans/2026-10-08-v2-refund-destination.md`; hard: refund `method`/`destination`/`confirmBy`/`awaiting_account`, `Payment.payer`, `Payment.refundedAmount`, `BookingTx.getRefund`, `awaitingRefundsDue`, `sendRefundOnce`/`mergeRefundOutcome` and the re-send of `pending` refunds; Decisions 5–7). Soft: V1 (#200, `2026-10-08-v1-subject-payments.md`: the subject-independent `PaymentsRepository`; without it Task 8 adds the history methods to a booking-only repository and ledgers it), #138 (merged in #155: `notifyRefundAccountNeeded`), #142 (S18 disputes: `DisputeRefund` and the S18.02 entry; if absent, written against #142's Contract names and ledgered as a carry), #140 (`instant_request` rows render from a fixture). In this plan a "policy" refund means `fromEscrow: true` and an "excess" refund `fromEscrow: false` (#129's names); `Booking.paymentMethod` does not exist (a booking's method is `checkout.method`, kept after payment). Branch `plan/141-s22-payments-account` (claimed with `project.py claim 141`), PR into `develop` titled `feat(payments): S22.01 payment history and S22.04 refund account [#141]`.

**Execution wave:** 5 (cross-plan review 2026-10-07). **Owns (others consume):** the payer history projection and `refund_account.ts` (#141); `account_deletion.ts` (`ACCOUNT_DATA_MAP`, `BLOCKER_KINDS`), `data_export.ts`, S22.05 and the `deletion_pending` router guard (#205).

## Global Constraints

- Main spec §3i.5, verbatim: "**S22.01**: khách xem mọi khoản đã trả và đang được giữ, kể cả tiền Chụp ngay đang treo khi chưa tìm được người (spec Chụp ngay), hoàn tiền đang xử lý và đã xong; mỗi dòng mở chi tiết booking/vé/yêu cầu. Nhiếp ảnh gia đã có S06.05 cho tiền nhận."
- Main spec §3i.5: "**S22.02 Xoá tài khoản** (bắt buộc với Google Play và App Store khi có đăng ký tài khoản): chặn khi còn booking chưa xong, vé chưa diễn ra, tiền đang giữ hoặc khiếu nại mở (liệt kê từng thứ kèm lối đi); xoá dữ liệu cá nhân, giữ bút toán sổ cái ẩn danh theo yêu cầu kế toán; bài công khai gỡ xuống."
- Main spec §3i.5: "**S22.03**: ẩn hồ sơ khỏi gợi ý và tìm kiếm (nhiếp ảnh gia vẫn nhận khách cũ), tải bản sao dữ liệu (gửi link qua email trong 48 giờ)." (delivery changed to an in-app link, Decision 9).
- Payments spec §12: "S22.01 | lịch sử thanh toán: bỏ chữ "cọc", thêm phương thức, hoàn tiền đang xử lý"; "**S22.04** | **Tài khoản nhận hoàn** (sheet, mới)".
- Payments spec §5: "VietQR | **Chi một khoản** về tài khoản đã chuyển … Khách xác nhận ở **S22.04 Tài khoản nhận hoàn** (sheet): "Hoàn về Vietcombank •••• 6789 · NGUYEN THANH HA"; nút chính "Hoàn về tài khoản này", liên kết "Dùng tài khoản khác" (form như S06.06, có tra tên). Thiếu thông tin người chuyển → bắt buộc khai tài khoản." "Ví MoMo / ZaloPay | API hoàn của ví".
- Mock `#S22.04` caption: "Mở sau khi xác nhận huỷ ở S05.03, hoặc khi booking bị từ chối hay hết hạn (S05.02), với đơn trả bằng chuyển khoản QR. … Trả bằng ví MoMo/ZaloPay thì tiền về ví, không hiện sheet này."
- Identity spec §9: "Xoá tài khoản (S22.02): xoá `identity`, giữ `idHash` …" (#135, wave 3, lands before this plan; the `ACCOUNT_DATA_MAP` identity row is this plan's and is a no-op if #135 has not merged).
- Owner ruling 2026-10-07: money and refunds stay on the fake gateway; the account-name lookup has a fake adapter only; no new Secret Manager secret (the existing `PAYOUT_ACCOUNT_KEY`/`AccountCipher` encrypts refund account numbers); the dev project is Spark, everything is tested on the emulators.
- Clock steps (the clock rule, restated in `2026-10-08-s04-reconciliation.md`; cross-plan review finding 36): add the step as a named entry at the end of the handler's step list, each in its own try/catch that logs and continues; do not change existing parameters; a new dependency goes into the optional last `extras` object (`EventClockExtras` / `BookingClockExtras`; create it if absent, one optional field per plan). This plan adds one step to #129's payment clock (`handlePaymentClock`, its own 5-minute `paymentClock` schedule) and one step to `pruneNotifications`; it changes no signature.
- Notifications (#138 owns types, copy, targets, dedupe keys and the app allowlist; cross-plan review finding 29): this plan (#141) only calls `notifyRefundAccountNeeded` from `notification_hooks.ts` (#138 merged in #155).
- S09.02 groups follow #148's `settingsGroupOrder` (Decision 12 of the S09 plan): #205 creates the `paymentsData` group (after `notifications`, before `support`) with key `settings-group-paymentsData` and its privacy row; #141 adds the "Lịch sử thanh toán" row above it (creating the group the same way if #205 has not merged); nothing is added to the order test.
- Owner 2026-10-07: account deletion has a 30-day restore window (Decision 11).
- CLAUDE.md: business rules in `packages/domain` (no Firebase/Node imports); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; imports `package:photobooking/...`, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; one `AppButton.primary` per screen, destructive actions are red inside a confirmation sheet; every screen/sheet in `ScreenCode`; `AsyncView` for every `AsyncValue`; phone numbers never in `users/{uid}`.
- `data-model/README.md`: ULIDs/opaque ids, UTC ISO instants in the domain, integer VND, string enum codes.
- Commits: Conventional Commits, subject ends with `[#205]` (Tasks 1–5) or `[#141]` (Tasks 6–11), message ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Tests: domain `cd packages/domain && npm test && npm run lint && npm run typecheck`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; Flutter from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`: `flutter test --no-pub --timeout 60s <file or folder>` one folder at a time (bounded pumps, no endless animation/timer); `flutter analyze`. Rules tests (`app_flutter/firebase/rules-test/rules.test.mjs`) and Functions integration tests are written, not run.

## Decisions

1. **History is a server-written projection.** `payments` stay server-only (they hold provider refs, dispute text and encrypted payer numbers). `users/{uid}/payments/{paymentId}` holds one customer row per payment (title, day, method, amounts, status code, refunds with a masked destination label); `users/{uid}/private/paymentTotals` holds `{held, refunding}`. The existing `onPaymentWritten` trigger refreshes the row (only when `status`, `escrowStatus`, `receivedAmount` or `refundedAmount` changed) and a new `onRefundWritten` trigger refreshes it on every refund write. S22.01 listens to the first 20 rows (`createdAt desc`) and grows by 20 with "Xem thêm", like S06.05.
2. **Which payments get a row:** only payments that received money (`receivedAmount > 0`). Live unpaid intents belong to S04.04; expired empty intents never appear. A row whose payment loses all money (never happens) is deleted.
3. **Row status precedence** (one code per row): any refund `awaiting_account` → `refund_account_needed`; any refund `pending`/`failed` → `refunding` (a `failed` refund is staff work, the customer still sees "Đang hoàn"); escrow `disputed` → `disputed`; payment `refunded` (or expired/late money fully refunded) → `refunded`; escrow `released`/`paid_out` → `released`, or `partially_refunded` when a policy refund was made; paid with escrow `held`/`partially_refunded` → `held`. `open` = `held | disputed | refund_account_needed | refunding`.
4. **Chụp ngay rows.** The row model accepts subject `instant_request` (title "Chụp ngay · {area}", meta "đang tìm thợ" while unmatched); #140 writes those payments through V1's settlement (#200, `2026-10-08-v1-subject-payments.md`). This plan renders and tests them with a fixture row; no instant backend here.
5. **Refund-account window (S22.04).** A **policy** refund (customer cancel, decline, request expired, event cancelled) of a `bank_qr` payment starts `awaiting_account`: with a payer account from the transfer it is prefilled (`destination.source = 'payer'`) and `confirmBy = createdAt + 24 h`; without one it waits for the customer (no `confirmBy`). The customer confirms the payer account or a looked-up other account (S22.04); the payment clock (#129's `paymentClock`, every 5 minutes) sends due ones to the payer account. **Excess** refunds (`fromEscrow: false`: `overpaid_excess`, `late_transfer`, `extra_transfer`, `underpaid_expired`) keep #129's behaviour: straight to the paying account (spec §3.3 "hoàn tự động"). Wallet refunds never wait. **Dispute refunds too** (cross-plan review finding 31): a `refund` or `split` outcome of #142's `resolveDispute` on a `bank_qr` payment creates its policy refund through the same `applyRefundToPayment`, so it starts `awaiting_account` like any other policy refund; #142's `dispatchDisputeRefund` already skips an `awaiting_account` refund (it is sent by `chooseRefundAccount` or the 24-hour default, never twice); S18.02 (#142, dispute detail) shows the outline "Chọn tài khoản nhận hoàn" while the dispute's refund waits and opens this plan's S22.04 sheet with `DisputeRefund(disputeId)` (a third `RefundSubject`; `pendingRefund` accepts `{disputeId}` and resolves the dispute's payment). If #142 has not merged, the `DisputeRefund` subject and its test are written against #142's Contract names and the S18.02 entry is ledgered as a carry for #142.
6. **Mirrors for the app.** `bookings/{id}.refundAccountNeeded: bool` (server-written) drives the S05.02 row; tickets already mirror `refundStatus` (now including `awaiting_account`). The notification goes through #138's hook `notifyRefundAccountNeeded(deps, {uid, refundId, amount, hasPayer})` (type `refund_account_needed`, category `booking`, critical, deduped by refund id, target `/me/payments` allowlisted by #138; copy in #138's catalogue, taken from this plan's Contract). The hook is called once per refund by the code that set `awaiting_account` (Task 7); no other emitter.
7. **Other account.** Two calls: `lookupRefundAccount` stores an encrypted candidate on the refund and returns the looked-up holder name; `chooseRefundAccount({use: 'candidate'})` commits it. The customer never types the name (as S06.06). Customers have no verified name, so no name match is required (owner question 2); the looked-up name is shown before confirming and kept on the refund.
8. **Name lookup port: consumed from #134** (cross-plan review finding 8). `AccountNameLookup`, `NameLookupResult` and the one fake `FakeAccountNameLookup` live in `packages/domain/src/account_lookup.ts`, created by #134 (merged in #193; reuse). The fake keeps #134's shape and numbers: `constructor(echoName: string | null)`; number ending `4321` → found `TRAN VAN B`, `9999` → `unsupported`, `0404` → `not_found`, else found `echoName` (`null` → `unsupported`). This plan passes the caller's display name normalised by `normalizeHolderName` as `echoName` and adds no second fake and no `0000` rule (`0000` is the payout gateway's failure number). The real adapter is the intermediary's (Deferred).
9. **Data export by in-app link, not email.** No email vendor exists. `requestDataExport` builds the JSON synchronously (bounded lists, Decision 10), writes `exports/{uid}/{exportId}.json` to Storage, records `users/{uid}/private/dataExport {status, path, sizeBytes, createdAt, expiresAt}`; S22.03 shows "Tải xuống" (download URL opened in the browser) until `expiresAt` (7 days). One export per 24 hours (`limit_exceeded`). Files older than 7 days are deleted by a step added to the existing daily `pruneNotifications` job (no new Scheduler job). The download URL is a bearer link for 7 days at most (accepted; owner question 1).
10. **Export contents** (`EXPORT_LIMITS`): profile (`users/{uid}`), contact (`users/{uid}/private/contact`: the user's own phone), photographer profile and services, bookings as customer and as photographer (≤ 1000 each, no other party's phone), registrations (≤ 1000), payment history rows (≤ 1000), posts (≤ 1000, metadata and image paths), reviews written (≤ 1000), messages sent (≤ 2000, text and image paths), notifications (≤ 200), likes/saves/follows (≤ 1000 each), earnings summary and payout account view (bank, last 4, holder). Never: encrypted numbers, provider refs, raw webhooks, device tokens, `idHash`, other users' phones.
11. **Deletion: locked at once, restorable for 30 days, then purged with a tombstone (Owner 2026-10-07; main spec question 25).** `requestAccountDeletion` (sign-in within 5 minutes, `REAUTH_MAX_AGE_SECONDS` as S06.06; no blockers, re-checked on the server) in one transaction writes `account_deletions/{uid} {status: 'pending', requestedAt, restoreUntil: requestedAt + ACCOUNT_RESTORE_DAYS (30) days, done: []}`, sets `users/{uid}.accountStatus = 'deletion_pending'` + `restoreUntil` and, for a provider, `photographers/{uid}.deletionPending = true` (server field); after the commit it revokes the refresh tokens (`revokeRefreshTokens`; the Auth user is **not** disabled, so the owner can sign in to restore). While pending: Find, `LocalRecommender` and the order gate treat the provider as hidden and not accepting (`deletionPending`, Decision 13 and the `ProviderOrderGate` adapter `FirestoreProviderOrderGate`, `infra/booking_readers.ts`, from #133); nothing is deleted yet; the app opens only S22.05 (router guard on `accountStatus`). Signing in within 30 days lands on **S22.05** ("Tài khoản đang chờ xoá", primary "Khôi phục tài khoản", text button "Tiếp tục xoá" = sign out, deletion stays scheduled). `restoreAccount` (pending and `now < restoreUntil`, inside one transaction on `account_deletions/{uid}`) sets `status: 'restored'`, `accountStatus: 'active'`, clears `restoreUntil` and `deletionPending`: everything is kept as it was. After 30 days a step `startDueAccountPurges` in the existing daily `pruneNotifications` job (no new Scheduler job) moves due `pending` documents (`restoreUntil <= now`, ≤ 50 per run) to `status: 'purging'` in a transaction that re-checks the status, so a restore and the purge start cannot both win; the `onAccountDeletionUpdated` trigger (status → `purging`) runs the purge in idempotent steps (`account_deletions/{uid}.done[]`, re-checks blockers first: if any appeared, it stops, sets `status: 'blocked'` and logs `deletion_blocked` for staff) and deletes the Auth user last (`status: 'done'`). A purged account cannot be restored (its Auth user is gone; signing in again with the same Google/Facebook account creates a new, empty account). `users/{uid}` is not deleted but replaced by a tombstone (`displayName: 'Người dùng đã xoá'`, `avatarUrl: null`, `avatarPath: null`, `deleted: true`, `deletedAt`, `role` kept, `accountStatus`/`restoreUntil` removed), so chats, reviews and booking histories of other people keep working without app changes. **Data export during the window:** an export made before confirming stays downloadable from S22.05 until its `expiresAt`; no new export while pending (`requestDataExport` → `not_eligible`); the purge deletes `exports/{uid}/`. The S22.02 confirm sheet reminds the user to download a copy first (link to S22.03).
12. **Blockers** (`accountDeletionBlockers`, in this order; cross-plan review finding 20: this plan, last in wave order, owns every blocker, other plans add none): `open_booking` (as customer: every status except `draft|declined|expired|cancelled|completed|reviewed`, so #130's `shot`, `delivered`, `revision_requested`, `approved` and disputed bookings count), `open_job` (as photographer, `photographerId == uid`, or as an assigned studio member or collaborator, `assigneeId == uid` (#136/#151): same statuses), `open_job_post` (#139: `jobs` with `customerId == uid` and status `open`), `open_quote` (#139: collection group `quotes` with `photographerId == uid` and status `submitted`), `active_instant` (#140: `instant_requests` with `customerId == uid` or `photographerId == uid` and status in `pending_payment|searching|assigned|en_route|arrived|in_progress|finished`), `studio_membership` (#136: `studio_members` with `memberId == uid` or `studioId == uid` and status `active`), `open_collab` (#151: `studio_collaborations` with `studioId == uid` or `collaboratorId == uid` and status `active`, or `collab_jobs` with `offerStatus` `pending|accepted` and `closedAt == null`, or `payStatus` `due|paid_reported|disputed`), `live_ticket` (registration `held|paid` whose event has not ended), `hosted_event` (`hostId == uid`, status `open|full|closed`), `open_dispute` (a payment of the user with `escrowStatus == 'disputed'`), `held_payment` (a paid payment of the user with `escrowStatus` `held|partially_refunded`), `refund_in_progress` (a refund of one of the user's payments with status `pending|failed`, or `awaiting_account` once V2 exists) — **read directly from `payments` (`payerId == uid`, newest 200, index `payments (payerId ASC, createdAt DESC)`) and `refunds` (`paymentId in` those ids, chunks of 30)**, never from #141's history rows, so #205 is correct without #141 (split 2026-10-08), `unpaid_earnings` (`earnings/{uid}.heldAmount + soonAmount > 0`). Each carries a count or an amount and the first item to open. A source whose plan has not merged reads an empty collection, so the blocker is simply absent until it lands.
13. **Hide from discovery** is a photographer-written boolean `photographers/{uid}.hiddenFromDiscovery` (rules: owner, bool). Find (S02.06, `FindResultsController._visible`) and `LocalRecommender` (Home shelves, similar) drop hidden profiles and profiles with the server field `deletionPending == true` (Decision 11); the profile, its posts in feeds, and booking from a link or an old booking keep working ("vẫn nhận khách cũ"). Customers have no public profile, so S22.03 shows them only the data section. The remote recommender gets a description note only.
14. **Entry points:** S09.02 gets (#205) the group "Thanh toán và dữ liệu" in #148's `paymentsData` slot of `settingsGroupOrder` (after "Thông báo", before "Hỗ trợ"; key `settings-group-paymentsData`; cross-plan review finding 25) with "Lịch sử thanh toán" (`/me/payments`, #141) and "Quyền riêng tư & dữ liệu" (`/settings/privacy`, #205); "Xoá tài khoản" lives at the bottom of S22.03 (→ `/settings/delete-account`). The rest of the S09.02 mock parity stays with #148.
15. **One primary per screen.** S22.01: none (the small "Chọn tài khoản nhận hoàn" on a row is outline). S22.02: outline "Xoá tài khoản" (disabled with blockers) opens a confirmation sheet whose red "Xoá tài khoản" is the destructive action. S22.03: outline buttons only; "Xoá tài khoản" is a red text button. S22.04: primary "Hoàn về tài khoản này" (mock). S22.05: primary "Khôi phục tài khoản"; "Tiếp tục xoá" is a text button (it only signs out).
16. **No new Scheduler job.** The 24-hour default runs in #129's payment clock (`handlePaymentClock`, its own 5-minute `paymentClock` schedule, as a named step per the clock rule); export purge (`pruneDataExports`) and the start of due account purges (`startDueAccountPurges`) are named steps of the existing daily `pruneNotifications`, each in its own try/catch.

## Needs the owner

1. **Data copy delivery:** an in-app download link valid 7 days (default, no email vendor yet) instead of "gửi link qua email trong 48 giờ"?
2. **Refund to another person's account:** allowed with the looked-up name shown and kept (default), or only accounts whose name matches the paying account?
3. **No answer on S22.04:** send the refund to the paying account after 24 hours (default), or wait until the customer chooses?

## Contract

### Existing code this plan builds on (checked 2026-10-07 on `develop` 812afd6; #129 re-checked 2026-10-08 on develop 87d8187 as built)

Tasks 2–3 (#205) and Tasks 6–8 (#141) re-check their part in Step 1; adapt and ledger any difference; if a name below does not exist, stop and report.

- From #134 (merged in #193; reuse): `packages/domain/src/account_lookup.ts` (`AccountNameLookup`, `NameLookupResult`, `FakeAccountNameLookup(echoName: string | null)`), `lib/features/account/widgets/reauth_sheet.dart` (`Future<bool> showReauthSheet(BuildContext context)`, moved there from `features/earnings/widgets/`, keys `reauth*`).
- From #138 (S17 plan): `notification_hooks.ts` `notifyRefundAccountNeeded(deps: NotifyDeps, e: {uid: string; refundId: string; amount: number; hasPayer: boolean}): Promise<void>` (type `refund_account_needed`, copy, target `/me/payments` and the app type parsing owned by #138).
- From #142 (S18 plan): `dispatchDisputeRefund(deps, payment, refund)` (skips `awaiting_account`), dispute detail S18.02 (`lib/features/disputes/dispute_detail_screen.dart`), `disputes/{id}.paymentId`.
- From #148 (S09 plan): `settingsGroupOrder` (slot `paymentsData`), `_SectionLabel` keys `settings-group-<name>`.
- From #129 (merged in #154): `Payment` (`method`, `transferCode`, `expiresAt`, `receivedAmount`), `Refund` (`fromEscrow`, `reason`, `status` `pending|done|failed`), `isEscrowRefund`, `escrowRefundedTotal`, `applyRefundToPayment`, `transferRefund`, `dispatchRefund`/`dispatchRefunds`, `dispatchTicketRefund` (private in `event_payments.ts`), `runPaymentSweeps` + `handlePaymentClock` (own `paymentClock` schedule; steps per the clock rule), `payment_notifications`, `ProviderOrderGate` (`acceptsOrders`, Firestore adapter), `PayMethod` (Dart), `Booking` (`deposit` = full price, `depositRefunded`, `depositRefundedAt`, `checkout.method`), `BookingRepository.confirmFakePayment`, `AppIcons.qrCode`. From V2 (#201, plan `2026-10-08-v2-refund-destination.md`, not on develop; its merged code wins over these quotes): `Payment.payer`, `Payment.refundedAmount`, `Refund.method`/`destination`/`confirmBy` (added but never set by V2)/`attempts`/`lastAttemptAt`, status `awaiting_account` (V2 uses it only for a bank transfer without a payer account), `StoredBankAccount` and `PayerBankAccount` (both keyed by `bankCode`), `RefundMethod`, `PaymentGateway.issueRefund` (same name; params gain `method`, `destination?: PayerBankAccount`; result gains `pending?`), `sendRefundOnce(d: {gateway, cipher, clock}, refund, payment: Pick<Payment, 'id' | 'provider'>)`, `mergeRefundOutcome(stored, next)`, `BookingTx.getRefund` / `BookingStore.getRefund`, the refund re-send, and the query `BookingStore.awaitingRefundsDue(now, limit)`. There is no `Refund.kind`: policy vs excess is `fromEscrow`. The old `PaymentLookup` is built as `BookingStore` queries (`findPaymentsByTransferCode`, `findPaymentsToReconcile`, `findOverduePayments`, `getTransferRecord`; #129). From V1 (#200, plan `2026-10-08-v1-subject-payments.md`, not on develop; soft for #141; its contract and Deviations table win): `SettlementDeps = {payments, gateway, clock, subjects}` (`payments` is V1's `PaymentLookup`), `liveSettlementDeps()` (Functions), `PaymentsRepository` (`confirmFake`, `instructions`)/`FunctionsPaymentsRepository`/`paymentsRepositoryProvider`, `PaymentCheck`, flat `PaymentInstructions`. Not on develop, add if needed: `AppIcons.bank`.
- Domain (`packages/domain/src`): `payout_account.ts` (`normalizeAccountNumber`, `normalizeHolderName`, `accountLast4`, `REAUTH_MAX_AGE_SECONDS`), `payout_ports.ts` (`AccountCipher`), `vn_banks.ts` (`VN_BANKS`, `bankByCode`), `notification_render.ts` (`formatVnd`), `earnings.ts` (`EarningsSummary.heldAmount`, `soonAmount`), `event.ts` (`RegistrationDoc.refundStatus?: RefundStatus | null`), `commit_transition.ts`, `event_payments.ts` (`refundTicket`, `cancelEventWithRefunds`), `errors.ts`, `ids.ts`.
- Functions: `triggers/payment_write.ts` (`handlePaymentWrite`, earnings only), `index.ts` (`onPaymentWritten`, `pruneNotifications` 03:45 daily, `savePayoutAccount` with `secrets: [PAYOUT_ACCOUNT_KEY]`), `callables/payout_account.ts` (`PayoutAccountCallableInput` with `token.auth_time`), `infra/admin.ts` (`db()` only; no Auth/Storage helpers), `infra/live_award.ts` (`getStorage().bucket()` pattern), `infra/live_payout.ts` (lazy cipher), `infra/earnings_firestore.ts` (subject lookup for earnings rows), `scheduled/prune_notifications.ts`.
- Rules: `users/{uid}` (owner writes `displayName`, `avatarUrl`, `avatarPath`, `role`, `createdAt`, `updatedAt`), `users/{uid}/private/{docId}` (owner reads; owner writes only `contact`, `notification_prefs`), `photographers/{uid}` (`photographerClientFields()`, `photographerServerFieldsUntouched()`), catch-all deny; Storage: `avatars/`, `posts/`, `users/`, `awardProofs/`, `chats/`, `eventCovers/`, catch-all deny. Indexes: `bookings (customerId, status)`, `(photographerId, status)`, `registrations` collection group `(userId, createdAt desc)`, `events (hostId, startAt desc)`.
- App: `lib/features/settings/settings_screen.dart` (`_SectionLabel`, `GlassCard`, `ListTile` rows, `_RowDivider`), `lib/app/router.dart` (`/settings` with children `profile`, `notifications`), `lib/core/screen_codes.dart` (`paymentHistory = 'S22.01'`, `deleteAccount = 'S22.02'`, `privacy = 'S22.03'`, `refundAccount = 'S22.04'` already declared), `lib/features/earnings/widgets/bank_picker_sheet.dart` (`showBankPicker(context, {selected})`), `widgets/account_inputs.dart` (`AccountNumberFormatter`), `lib/data/earnings/vn_banks.dart` (`VnBank`), `lib/core/widgets/earning_row.dart` (`EarningRow`), `StatTile`/`StatTileRow`, `MoneyBreakdown`, `EmptyState`, `showConfirmSheet(danger:)`, `showAppSheet`, `externalLauncherProvider`, `clockProvider`, `authRepositoryProvider` (`signOut`, `reauthenticate`), `lib/features/booking/cancel_sheet.dart`, `booking_detail_screen.dart`, `lib/features/events/tickets_tab.dart`, `lib/features/find/find_controller.dart` (`_visible`), `lib/data/recommendation/local_recommender.dart` (`recommendPhotographers`, `similar`), `lib/data/content/photographer_summary.dart` (`PhotographerSummary`, `photographerSummaryFrom` in `firestore_photographer_repository.dart`), the router redirect in `lib/app/router.dart`.

### Data model

- `users/{uid}/payments/{paymentId}` (new; owner read, server write): `PayerPaymentRow` below, instants as Timestamps.
- `users/{uid}/private/paymentTotals` (new; owner read via the existing private rule, server write): `{held: int, refunding: int, updatedAt}`.
- `users/{uid}/private/dataExport` (new; same rule): `{status: 'ready', path, sizeBytes, createdAt, expiresAt}`.
- `refunds/{id}` (server-only) gains `candidate` (`StoredBankAccount | null`, this plan); `confirmBy` (Timestamp | null) and `destination.source` `payer|customer` come from V2 (#201), this plan sets `confirmBy`.
- `bookings/{id}` gains `refundAccountNeeded: bool` (server-written).
- `photographers/{uid}` gains `hiddenFromDiscovery: bool` (owner-written) and `deletionPending: bool` (server-written, Decision 11).
- `users/{uid}` gains `accountStatus: 'active' | 'deletion_pending'` (server-written, missing = active) and `restoreUntil` (Timestamp | null); tombstone fields (server-written): `deleted: true`, `deletedAt`.
- `account_deletions/{uid}` (new, server-only): `{status: 'pending'|'restored'|'purging'|'blocked'|'done', requestedAt, restoreUntil, restoredAt?, purgeStartedAt?, done: string[], doneAt?}`.
- Storage `exports/{uid}/{exportId}.json` (new): owner read, no client write.

### Domain (packages/domain/src)

```ts
// payer_history.ts (new)
export const PAYER_ROW_STATUSES = ['held', 'disputed', 'released', 'refund_account_needed', 'refunding', 'refunded', 'partially_refunded'] as const;
export type PayerRowStatus = (typeof PAYER_ROW_STATUSES)[number];
export type PayerSubjectType = PaymentSubject | 'instant_request';
export interface PayerRefundView {
  readonly refundId: string; readonly amount: number; readonly status: RefundStatus; readonly method: RefundMethod;
  readonly kind: RefundKind /* 'policy' (fromEscrow true) | 'excess' (fromEscrow false); #129 and V2 have no RefundKind, derive it here */; readonly destinationLabel: string | null; // 'Vietcombank •••• 6789'; null for wallets/none
  readonly createdAt: string; readonly doneAt: string | null;
}
export interface PayerSubjectView { readonly title: string; readonly day: string | null; readonly eventId: string | null; readonly searching: boolean; readonly cancelled: boolean }
export interface PayerPaymentRow {
  readonly paymentId: string; readonly payerId: string; readonly subjectType: PayerSubjectType; readonly subjectId: string;
  readonly eventId: string | null; readonly title: string; readonly day: string | null; readonly method: PaymentMethod;
  readonly amount: number; readonly status: PayerRowStatus; readonly open: boolean;
  readonly heldAmount: number; readonly refundingAmount: number; readonly refundedAmount: number;
  readonly searching: boolean; readonly cancelled: boolean; readonly refunds: readonly PayerRefundView[];
  readonly createdAt: string; readonly paidAt: string | null; readonly updatedAt: string;
}
/** Null when no money ever arrived (Decision 2). Status by Decision 3. */
export function payerRowOf(p: Payment, refunds: readonly Refund[], subject: PayerSubjectView, now: Date): PayerPaymentRow | null;
export function payerTotals(rows: readonly PayerPaymentRow[]): { held: number; refunding: number };
export function destinationLabel(d: { bankName: string; accountLast4: string } | null | undefined): string | null; // 'Vietcombank •••• 6789'
export interface PayerHistoryStore {
  payment(id: string): Promise<Payment | null>;
  refundsOf(paymentId: string): Promise<readonly Refund[]>;
  subjectOf(p: Payment): Promise<PayerSubjectView>;
  putRow(row: PayerPaymentRow): Promise<void>;
  deleteRow(payerId: string, paymentId: string): Promise<void>;
  openRows(payerId: string): Promise<readonly PayerPaymentRow[]>;
  putTotals(payerId: string, totals: { held: number; refunding: number }, at: Date): Promise<void>;
}
export async function refreshPayerHistory(deps: { store: PayerHistoryStore; clock: Clock }, paymentId: string): Promise<'written' | 'deleted' | 'missing'>;

// account_lookup.ts — consumed from #134 (created by the S06 plan; if not landed, create exactly as defined there);
// payout_ports.ts re-exports it. Do not define a second variant or a second fake.
export type NameLookupResult = { status: 'found'; holderName: string } | { status: 'unsupported' } | { status: 'not_found' };
export interface AccountNameLookup {
  lookup(r: { bankCode: string; accountNumber: string }): Promise<NameLookupResult>;
}
// …4321 → found 'TRAN VAN B'; …9999 → unsupported; …0404 → not_found; else found echoName (null → unsupported)
export class FakeAccountNameLookup implements AccountNameLookup { constructor(echoName: string | null) }

// refund_account.ts (new)
export const REFUND_ACCOUNT_CONFIRM_HOURS = 24;
/** A policy refund paid back by bank transfer waits for the customer (Decision 5). */
export function needsAccountChoice(r: Pick<Refund, 'fromEscrow' | 'method'>): boolean;   // fromEscrow && method === 'bank_transfer' (V2 has no Refund.kind); as built in escrow.ts with canChooseRefundAccount (booking/ticket subjects)
export type RefundSubjectRef = { bookingId: string } | { eventId: string; registrationId: string } | { disputeId: string }; // dispute: #142 (Decision 5)
export interface PendingRefundView { readonly refundId: string; readonly amount: number; readonly payer: { bankName: string; accountLast4: string; holderName: string } | null; readonly confirmBy: string | null }
export interface RefundAccountDeps {
  readonly bookings: BookingDeps; readonly events: EventPaymentDeps;  // #129 deps (cipher, gateway inside)
  readonly payments: BookingStore;                                      // #129's payment queries (the old PaymentLookup); V2 adds awaitingRefundsDue
  readonly lookup: AccountNameLookup; readonly clock: Clock;
}
export async function pendingRefundFor(deps: RefundAccountDeps, caller: { uid: string }, raw: unknown): Promise<PendingRefundView | null>;
export async function lookupRefundAccount(deps: RefundAccountDeps, caller: { uid: string }, raw: unknown):
  Promise<{ holderName: string; bankName: string; accountLast4: string }>;
  // raw {refundId, bankCode, accountNumber}; payer only (permission_denied); refund awaiting_account else conflict;
  // bad bank/number invalid_argument; 'not_found' → not_found; 'unsupported' → not_eligible; stores encrypted candidate
  // charges Refund.accountLookups {day, count} before asking the bank: the 21st attempt of a Vietnam day → limit_exceeded
export async function chooseRefundAccount(deps: RefundAccountDeps, caller: { uid: string }, raw: unknown): Promise<{ status: RefundStatus }>;
  // raw {refundId, use: 'payer' | 'candidate'}; not awaiting → returns the current status (idempotent);
  // 'payer' without a payer destination or 'candidate' without a candidate → invalid_argument; then pending + dispatch
export async function confirmDueRefundAccounts(deps: RefundAccountDeps, now: Date, limit: number): Promise<number>; // a named step of runPaymentSweeps (#129's payment clock)
// consumed from V2 (#201): BookingStore.awaitingRefundsDue(now: Date, limit: number): Promise<readonly Refund[]>, BookingTx.getRefund(id); this plan adds neither
// applyRefundToPayment (#129) changes: needsAccountChoice → status 'awaiting_account', destination = payer (source 'payer') | null,
//   confirmBy = payer ? createdAt + 24 h : null; commit_transition / refundTicket set the mirrors (Decision 6) and do not dispatch it

// account_deletion.ts (new)
export const DELETED_USER_NAME = 'Người dùng đã xoá';
export const ACCOUNT_RESTORE_DAYS = 30; // Owner 2026-10-07
export const OPEN_BOOKING_EXCLUDED = ['draft', 'declined', 'expired', 'cancelled', 'completed', 'reviewed'] as const; // every other status is open
export const BLOCKER_KINDS = ['open_booking', 'open_job', 'open_job_post', 'open_quote', 'active_instant', 'studio_membership', 'open_collab',
  'live_ticket', 'hosted_event', 'open_dispute', 'held_payment', 'refund_in_progress', 'unpaid_earnings'] as const;
export type BlockerKind = (typeof BLOCKER_KINDS)[number];
export interface BlockerItem { readonly id: string; readonly title: string; readonly day: string | null; readonly eventId?: string }
export interface Blocker { readonly kind: BlockerKind; readonly count: number; readonly amount: number | null; readonly first: BlockerItem | null }
export interface AccountSnapshot {
  readonly openBookings: readonly BlockerItem[]; readonly openJobs: readonly BlockerItem[];          // openJobs: photographerId or assigneeId == uid
  readonly openJobPosts: readonly BlockerItem[]; readonly openQuotes: readonly BlockerItem[];         // #139
  readonly activeInstants: readonly BlockerItem[];                                                    // #140
  readonly studioRelations: readonly BlockerItem[]; readonly openCollabs: readonly BlockerItem[];     // #136, #151
  readonly liveTickets: readonly BlockerItem[]; readonly hostedEvents: readonly BlockerItem[];
  readonly payerMoney: readonly PayerMoneyItem[];  // from payments (payerId == uid) and their refunds, not #141's history rows (Decision 12)
  readonly unpaidEarnings: number;
}
export interface PayerMoneyItem { readonly paymentId: string; readonly state: 'held' | 'disputed' | 'refunding'; readonly amount: number; readonly item: BlockerItem }
export function accountDeletionBlockers(s: AccountSnapshot): readonly Blocker[];
export type DeletionStatus = 'pending' | 'restored' | 'purging' | 'blocked' | 'done';
export interface AccountDeletionRecord { readonly uid: string; readonly status: DeletionStatus; readonly requestedAt: string; readonly restoreUntil: string; readonly done: readonly string[] }
export interface AccountDeletionDeps {
  snapshot(uid: string, now: Date): Promise<AccountSnapshot>;
  // one transaction on account_deletions/{uid} + users/{uid} (+ photographers/{uid}.deletionPending when the doc exists)
  lock(uid: string, requestedAt: Date, restoreUntil: Date): Promise<'locked' | 'already'>;
  unlock(uid: string, now: Date): Promise<'restored' | 'not_pending' | 'expired'>;   // transaction: pending && now < restoreUntil
  startPurge(uid: string, now: Date): Promise<boolean>;                             // transaction: pending && restoreUntil <= now → purging
  duePending(now: Date, limit: number): Promise<readonly string[]>;                 // status == pending && restoreUntil <= now
  revokeSessions(uid: string): Promise<void>;
  readonly clock: Clock;
}
export async function getAccountDeletionBlockers(deps: AccountDeletionDeps, caller: { uid: string }): Promise<{ blockers: readonly Blocker[] }>;
export async function requestAccountDeletion(deps: AccountDeletionDeps, caller: { uid: string; authTime: Date | null }, raw: unknown):
  Promise<{ status: 'deletion_pending'; restoreUntil: string }>;
  // raw must be {} (invalid_argument otherwise); auth older than REAUTH_MAX_AGE_SECONDS → reauth_required; blockers → conflict;
  // lock, then revokeSessions; a second request while pending returns the same restoreUntil (idempotent)
export async function restoreAccount(deps: AccountDeletionDeps, caller: { uid: string }, raw: unknown): Promise<{ status: 'restored' }>;
  // raw must be {}; not pending → not_found; restoreUntil passed or purging → deadline_passed
export async function startDueAccountPurges(deps: AccountDeletionDeps, now: Date, limit: number): Promise<number>; // daily pruneNotifications step
export const ACCOUNT_DATA_MAP: ReadonlyArray<{ readonly target: string; readonly action: 'delete' | 'anonymize' | 'tombstone' | 'keep'; readonly note: string }>;
export function tombstoneOf(user: { role?: unknown }, now: Date): Record<string, unknown>; // also deletes accountStatus, restoreUntil

// data_export.ts (new)
export const EXPORT_SCHEMA_VERSION = 1;
export const EXPORT_COOLDOWN_HOURS = 24;
export const EXPORT_TTL_DAYS = 7;
export const EXPORT_LIMITS = { bookings: 1000, registrations: 1000, payments: 1000, posts: 1000, reviews: 1000, messages: 2000, notifications: 200, markers: 1000 } as const;
export const EXPORT_REDACTED_KEYS: readonly string[]; // accountNumberEnc, candidate, payer, providerRef, raw, token, idHash, instructions
export interface ExportParts { readonly [section: string]: unknown }
/** Pure: schemaVersion, generatedAt, the sections with redacted keys removed at any depth. */
export function buildExportDocument(parts: ExportParts, now: Date): Record<string, unknown>;
export function exportAllowed(last: Date | null, now: Date): boolean;
export interface DataExportDeps {
  gather(uid: string, limits: typeof EXPORT_LIMITS): Promise<ExportParts>;
  last(uid: string): Promise<Date | null>;
  write(uid: string, exportId: string, json: string): Promise<{ path: string; sizeBytes: number }>;
  record(uid: string, rec: { path: string; sizeBytes: number; createdAt: Date; expiresAt: Date }): Promise<void>;
  readonly clock: Clock; readonly ids: IdGenerator;
}
export async function requestDataExport(deps: DataExportDeps, caller: { uid: string }, raw: unknown): Promise<{ path: string; sizeBytes: number; expiresAt: string }>;
  // raw must be {}; account deletion_pending → not_eligible (Decision 11); within 24 h of the last → limit_exceeded
  // DataExportDeps gains pending(uid): Promise<boolean>

// Notifications: consumed from #138 (notification_hooks.ts); #138's catalogue holds this copy (taken from this plan):
// notifyRefundAccountNeeded(deps, { uid, refundId, amount, hasPayer }) → type refund_account_needed, meta('booking', 'activity', true),
//   dedupe key `refund_account_needed:${refundId}`, target '/me/payments'
//   title 'Chọn tài khoản nhận hoàn'; body hasPayer ? `Bạn được hoàn ${formatVnd(amount)}. Sau 24 giờ tiền tự về tài khoản đã chuyển, hoặc chọn tài khoản khác.`
//                                                 : `Bạn được hoàn ${formatVnd(amount)}. Chọn tài khoản để nhận tiền.`
```

### Callables and triggers (Functions, `asia-southeast1`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `pendingRefund` (callable, #141) | `{bookingId}`, `{eventId, registrationId}` or `{disputeId}` | `PendingRefundView \| null` | `invalid_argument`, `not_found`, `permission_denied` |
| `lookupRefundAccount` (callable, #141, secrets `PAYOUT_ACCOUNT_KEY`) | `{refundId, bankCode, accountNumber}` | `{holderName, bankName, accountLast4}` | `invalid_argument`, `permission_denied`, `conflict`, `not_found`, `not_eligible`, `limit_exceeded` (`NAME_LOOKUPS_PER_DAY` attempts per refund per Vietnam day, every attempt counts; #141 fix round 1) |
| `chooseRefundAccount` (callable, #141, `PAYMENT_CALLABLE_OPTIONS`, secrets `PAYOUT_ACCOUNT_KEY`) | `{refundId, use: 'payer'\|'candidate'}` (`'candidate'` cũng mang `bankCode` + `accountLast4` của tài khoản đang hiện) | `{status}` | `invalid_argument`, `permission_denied`, `not_found`, `conflict` (lỗi, không phải kết quả thành công) |
| `getAccountDeletionBlockers` (callable, #205) | `{}` | `{blockers: Blocker[]}` | — |
| `requestAccountDeletion` (callable, #205) | `{}` | `{status: 'deletion_pending', restoreUntil}` | `reauth_required`, `conflict` (`details.blockers`: kinds) |
| `restoreAccount` (callable, #205) | `{}` | `{status: 'restored'}` | `not_found`, `deadline_passed` |
| `requestDataExport` (callable, #205, 120 s, 512 MiB) | `{}` | `{path, sizeBytes, expiresAt}` | `limit_exceeded`, `not_eligible` (deletion pending) |
| `onRefundWritten` (trigger, #141, `refunds/{refundId}`) | — | refreshes the payer row | — |
| `onPaymentWritten` (existing; #141) | — | earnings + payer row (when relevant fields changed) | — |
| `onAccountDeletionUpdated` (#205, trigger `onDocumentUpdated`, `account_deletions/{uid}`, runs only when `status` becomes `purging`; `TRIGGER_OPTIONS` + 300 s, 512 MiB) | — | purge (Decision 11), Auth user deleted last | retried; idempotent by `done[]` |
| `pruneNotifications` (existing, daily 03:45; #205) | — | + named steps `pruneDataExports` (Storage `exports/` older than 7 days) and `startDueAccountPurges` (≤ 50 due accounts per run) | — |
| `paymentClock` (existing, #129; step by #141) | — | #129's payment clock (`handlePaymentClock`) gains the step `confirmDueRefundAccounts` | — |

### Rules, Storage rules, indexes

- `match /users/{uid}/payments/{paymentId} { allow read: if isOwner(uid); allow write: if false; }`; `match /account_deletions/{uid} { allow read, write: if false; }`; `users/{uid}` client update must not touch `deleted`/`deletedAt`/`accountStatus`/`restoreUntil` (already enforced by `onlyKeys(userClientFields())`; add a rules test); `photographerServerFieldsUntouched()` gains `deletionPending`; `photographerClientFields()` gains `hiddenFromDiscovery` with `!('hiddenFromDiscovery' in changed) || request.resource.data.hiddenFromDiscovery is bool`.
- Storage: `match /exports/{uid}/{file} { allow read: if isOwner(uid); allow write: if false; }`.
- Indexes: field overrides for collection group `registrations.userId` (ascending, collection-group scope) is covered by the existing `(userId, createdAt desc)` composite (query with that order); add field override `timeline.authorId` (ascending, collection-group) for the purge; composite `account_deletions (status, restoreUntil)` for `startDueAccountPurges`; `bookings (assigneeId, status)` for the `open_job` blocker (skip if #136 already added it); blocker queries on `jobs (customerId, status)`, collection group `quotes (photographerId, status)`, `instant_requests (customerId|photographerId, status)`, `studio_members (memberId|studioId, status)`, `studio_collaborations (studioId|collaboratorId, status)` use the indexes their plans add (the snapshot adapter adds any that is missing and ledgers it); composite `payments (payerId ASC, createdAt DESC)` for the money blockers (#205, Decision 12); `users/{uid}/payments` (#141): `createdAt desc` is single-field (automatic). All other index items on this line are #205's.

### App (Dart)

```dart
// lib/data/payments/payment_history.dart (new, #141)
enum PayerRowStatus { held, disputed, released, refundAccountNeeded, refunding, refunded, partiallyRefunded }
enum PayerSubjectType { booking, eventRegistration, instantRequest }
class PayerRefundView { final String refundId; final int amount; final String status; final bool wallet; final String? destinationLabel; final DateTime createdAt; final DateTime? doneAt; … }
class PayerPaymentRow { final String paymentId; final PayerSubjectType subjectType; final String subjectId; final String? eventId; final String title; final String? day; final PayMethod method; final int amount; final PayerRowStatus status; final bool open; final int heldAmount; final int refundingAmount; final int refundedAmount; final bool searching; final bool cancelled; final List<PayerRefundView> refunds; final DateTime createdAt; final DateTime? paidAt; … }
class PaymentTotals { const PaymentTotals({this.held = 0, this.refunding = 0}); final int held; final int refunding; }
PayerPaymentRow? payerRowFrom(String id, Map<String, dynamic>? data);
sealed class RefundSubject { const RefundSubject(); }
final class BookingRefund extends RefundSubject { const BookingRefund(this.bookingId); final String bookingId; }
final class TicketRefund extends RefundSubject { const TicketRefund(this.eventId, this.registrationId); final String eventId; final String registrationId; }
final class DisputeRefund extends RefundSubject { const DisputeRefund(this.disputeId); final String disputeId; } // S18.02 (#142), Decision 5
class PendingRefund { final String refundId; final int amount; final ({String bankName, String accountLast4, String holderName})? payer; final DateTime? confirmBy; … }
enum RefundAccountChoice { payer, candidate }

// PaymentsRepository (V1) gains (#141); FunctionsPaymentsRepository is renamed FirebasePaymentsRepository (Firestore + Functions):
Stream<List<PayerPaymentRow>> watchHistory(String uid, {required int limit});
Stream<PaymentTotals> watchTotals(String uid);
Future<PendingRefund?> pendingRefund(RefundSubject subject);
Future<({String holderName, String bankName, String accountLast4})> lookupRefundAccount({required String refundId, required String bankCode, required String accountNumber});
Future<String> chooseRefundAccount({required String refundId, required RefundAccountChoice use});

// lib/data/account/account_repository.dart (new, #205)
enum BlockerKind { openBooking, openJob, openJobPost, openQuote, activeInstant, studioMembership, openCollab, liveTicket, hostedEvent, openDispute, heldPayment, refundInProgress, unpaidEarnings }
class DeletionBlocker { final BlockerKind kind; final int count; final int? amount; final ({String id, String title, String? day, String? eventId})? first; … }
class DataExport { final String path; final int sizeBytes; final DateTime createdAt; final DateTime expiresAt; bool usableAt(DateTime now) => now.isBefore(expiresAt); }
abstract class AccountRepository {
  Future<List<DeletionBlocker>> deletionBlockers();
  Future<DateTime> requestDeletion();             // returns restoreUntil; throws AccountException('reauth_required' | 'conflict' | …)
  Future<void> restore();                         // throws AccountException('deadline_passed' | 'not_found')
  Stream<AccountLock?> watchLock(String uid);     // users/{uid}.accountStatus == 'deletion_pending' → AccountLock(restoreUntil)
  Future<DataExport> requestExport();
  Stream<DataExport?> watchExport(String uid);    // users/{uid}/private/dataExport
  Future<Uri> exportDownloadUrl(String path);     // FirebaseStorage getDownloadURL
  Future<void> setHiddenFromDiscovery(String uid, bool hidden); // photographers/{uid} merge
}
class AccountException implements Exception { const AccountException(this.code); final String code; }
class AccountLock { const AccountLock(this.restoreUntil); final DateTime restoreUntil; }
final accountLockProvider = StreamProvider<AccountLock?>(…); // null when signed out or active
class FirebaseAccountRepository implements AccountRepository { … }
final accountRepositoryProvider = Provider<AccountRepository>((ref) => FirebaseAccountRepository());

// Booking (freezed) gains bool refundAccountNeeded (default false; #141); PhotographerSummary gains bool hiddenFromDiscovery and bool deletionPending (default false; #205)

// lib/features/payments/payment_history_screen.dart (S22.01, #141), payment_history_controller.dart
// lib/features/payments/refund_account_sheet.dart (S22.04, #141):
Future<void> showRefundAccountSheet(BuildContext context, WidgetRef ref, RefundSubject subject); // no-op when pendingRefund is null
// lib/features/account/delete_account_screen.dart (S22.02, #205), delete_account_controller.dart
// lib/features/account/privacy_screen.dart (S22.03), privacy_controller.dart
// lib/features/account/restore_account_screen.dart (S22.05), restore_account_controller.dart
```

- Routes: `/me/payments` → `PaymentHistoryScreen`; `/settings/privacy` → `PrivacyScreen`; `/settings/delete-account` → `DeleteAccountScreen` (children of `/settings`); `/account/restore` → `RestoreAccountScreen` (top level). Router redirect: when `accountLockProvider` has a lock, every location except `/account/restore` and `/login` redirects to `/account/restore`; with no lock, `/account/restore` redirects to `/`.
- `AppIcons` adds (#205) `privacy = Symbols.privacy_tip_rounded`, `download = Symbols.download_rounded`, `restore = Symbols.restore_rounded`; `receipt` exists (checked 2026-10-08 on develop 4e25834).
- Screen codes: all declared on develop 4e25834, including `restoreAccount = 'S22.05'` and its `ScreenCodes.all` entry (check only).

### l10n (`lib/l10n/app_vi.arb`) — key: exact text

S09.02 (`settingsPaymentHistory*` #141, the rest #205): `settingsPaymentsData` "Thanh toán và dữ liệu"; `settingsPaymentHistory` "Lịch sử thanh toán"; `settingsPaymentHistoryBody` "Khoản đã trả, đang giữ, đang hoàn"; `settingsPrivacy` "Quyền riêng tư & dữ liệu"; `settingsPrivacyBody` "Ẩn hồ sơ, tải bản sao dữ liệu, xoá tài khoản"; `settingsPrivacyBodyCustomer` "Tải bản sao dữ liệu, xoá tài khoản".

S22.01 (#141): `paymentsTitle` "Lịch sử thanh toán"; `paymentsHeld` "Đang giữ"; `paymentsRefunding` "Đang hoàn"; `paymentsHeldNote` "Tiền bạn trả được trung gian thanh toán giữ, chỉ chuyển cho thợ theo 2 mốc."; `paymentsItems` "Các khoản"; `paymentsMore` "Xem thêm"; `paymentsEmptyTitle` "Chưa có khoản thanh toán nào"; `paymentsEmptyBody` "Khi bạn đặt lịch hay mua vé, các khoản sẽ hiện ở đây."; `payStatusHeld` "Đang giữ"; `payStatusDisputed` "Đang khiếu nại"; `payStatusReleasedBooking` "Đã chuyển cho thợ"; `payStatusReleasedTicket` "Đã chuyển cho chủ sự kiện"; `payStatusReleasedPlatform` "Đã thanh toán"; `payStatusRefunding` "Đang hoàn"; `payStatusNeedsAccount` "Cần tài khoản"; `payStatusRefunded` "Đã hoàn"; `payStatusPartlyRefunded` "Đã hoàn một phần"; `payMetaSearching` "đang tìm thợ"; `payMetaCancelled` "đã huỷ"; `payTitleTicket` "{title} · {n} vé"; `payTitleInstant` "Chụp ngay · {area}"; `payDetailPaid` "Đã trả"; `payDetailRefundTo` "Hoàn về {destination}"; `payDetailWallet` "ví {wallet}"; `payDetailRefundPending` "đang xử lý"; `payDetailRefundDone` "đã về"; `payDetailWillGetBack` "Sẽ nhận lại"; `payDetailOpenBooking` "Xem buổi chụp"; `payDetailOpenTicket` "Xem vé"; `payDetailOpenInstant` "Xem yêu cầu Chụp ngay"; `payChooseRefundAccount` "Chọn tài khoản nhận hoàn".

S22.04 (#141): `refundAccountTitle` "Tài khoản nhận hoàn"; `refundAccountYouGet` "Bạn được hoàn"; `refundAccountToPayer` "Tiền hoàn về tài khoản đã chuyển:"; `refundAccountConfirm` "Hoàn về tài khoản này"; `refundAccountOther` "Dùng tài khoản khác"; `refundAccountWalletNote` "Ví MoMo/ZaloPay: hoàn về ví, không cần chọn."; `refundAccountAutoNote` "Không chọn thì sau 24 giờ tiền tự hoàn về tài khoản đã chuyển."; `refundAccountNoPayer` "Chưa có thông tin tài khoản đã chuyển. Nhập tài khoản để nhận tiền hoàn."; `refundAccountBank` "Ngân hàng"; `refundAccountNumber` "Số tài khoản"; `refundAccountLookup` "Tra tên chủ tài khoản"; `refundAccountLookupNote` "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ."; `refundAccountEncrypted` "Số tài khoản được mã hoá, chỉ hiện 4 số cuối."; `refundAccountNotFound` "Không tìm thấy tài khoản này. Kiểm tra lại ngân hàng và số tài khoản."; `refundAccountUnsupported` "Ngân hàng này chưa tra được tên chủ tài khoản. Chọn ngân hàng khác hoặc hoàn về tài khoản đã chuyển."; `refundAccountSent` "Đã gửi yêu cầu hoàn tiền"; `refundAccountClose` "Đóng". S05.02 row: `detailRefundAccountTitle` "Bạn được hoàn {amount}"; `detailRefundAccountBody` "Chọn tài khoản để nhận tiền hoàn."

S22.02 (#205): `deleteAccountTitle` "Xoá tài khoản"; `deleteBlockedTitle` "Chưa xoá được tài khoản"; `deleteBlockedBody` "Xong các việc dưới đây rồi quay lại."; `deleteBlockBooking` "{count} buổi chụp chưa xong"; `deleteBlockJob` "{count} buổi chụp khách đã đặt"; `deleteBlockJobPost` "{count} tin tìm thợ đang mở"; `deleteBlockJobPostBody` "Đóng tin hoặc chọn thợ trước."; `deleteBlockQuote` "{count} báo giá đang chờ khách"; `deleteBlockQuoteBody` "Rút báo giá hoặc đợi khách chọn."; `deleteBlockInstant` "{count} yêu cầu Chụp ngay chưa xong"; `deleteBlockStudio` "{count} quan hệ studio đang hoạt động"; `deleteBlockStudioBody` "Rời studio hoặc gỡ thành viên trước."; `deleteBlockCollab` "{count} cộng tác đang mở"; `deleteBlockCollabBody` "Kết thúc cộng tác và xong các việc được giao."; `deleteBlockTicket` "{count} vé sự kiện chưa diễn ra"; `deleteBlockEvent` "{count} sự kiện bạn tổ chức còn mở"; `deleteBlockDispute` "{count} khiếu nại đang mở"; `deleteBlockHeld` "{amount} đang được giữ"; `deleteBlockHeldBody` "Đợi tiền được chuyển xong rồi xoá."; `deleteBlockRefund` "{amount} đang hoàn"; `deleteBlockRefundBody` "Đợi tiền hoàn về tài khoản của bạn."; `deleteBlockEarnings` "{amount} chờ chi trả"; `deleteBlockEarningsBody` "Thêm tài khoản nhận tiền hoặc đợi lần chi tới."; `deleteConsequencesTitle` "Khi xoá tài khoản"; `deleteConsequence1` "Tài khoản bị khoá ngay; hồ sơ không còn hiện với người khác."; `deleteConsequence2` "Tin nhắn bạn đã gửi vẫn còn ở phía người nhận, tên hiện là "Người dùng đã xoá"."; `deleteConsequence3` "Đánh giá bạn đã viết được giữ, không kèm tên."; `deleteConsequence4` "Lịch sử giao dịch được giữ ẩn danh theo quy định kế toán."; `deleteConsequence5` "Trong 30 ngày, đăng nhập lại để khôi phục. Sau 30 ngày, hồ sơ, ảnh đại diện, số điện thoại và bài đăng bị xoá hẳn, không khôi phục được."; `deleteExportHint` "Muốn giữ dữ liệu? Tải bản sao trước khi xoá."; `deleteExportHintLink` "Tải bản sao dữ liệu"; `deleteAction` "Xoá tài khoản"; `deleteConfirmTitle` "Xoá tài khoản?"; `deleteConfirmBody` "Tài khoản bị khoá ngay và xoá hẳn sau 30 ngày. Trong 30 ngày, đăng nhập lại để khôi phục. Bạn có thể cần đăng nhập lại để xác nhận."; `deleteConfirmKeep` "Giữ tài khoản"; `deleteAccountDone` "Tài khoản đã khoá, sẽ xoá hẳn vào {date}."; `deleteAccountFailed` "Chưa xoá được, thử lại sau."

S22.03 (#205): `privacyTitle` "Quyền riêng tư & dữ liệu"; `privacyProfile` "Hồ sơ"; `privacyHide` "Ẩn hồ sơ khỏi gợi ý và tìm kiếm"; `privacyHideBody` "Hồ sơ không hiện trong Tìm thợ và gợi ý. Khách cũ vẫn mở được hồ sơ và đặt lại; bài đăng vẫn hiện như thường."; `privacyData` "Dữ liệu của bạn"; `privacyExport` "Tải bản sao dữ liệu"; `privacyExportBody` "Hồ sơ, đặt lịch, vé, thanh toán, bài đăng, đánh giá và tin nhắn bạn đã gửi, trong một tệp JSON."; `privacyExportCreate` "Tạo bản sao"; `privacyExportCreating` "Đang tạo bản sao…"; `privacyExportReady` "Bản sao tạo lúc {time} · tải được tới {date}"; `privacyExportDownload` "Tải xuống"; `privacyExportCooldown` "Mỗi 24 giờ tạo được một bản sao."; `privacyExportLimit` "Bạn vừa tạo bản sao, thử lại sau 24 giờ."; `privacyExportFailed` "Chưa tạo được bản sao, thử lại sau."; `privacyDelete` "Xoá tài khoản".

S22.05 (#205; Owner 2026-10-07): `restoreAccountTitle` "Tài khoản đang chờ xoá"; `restoreAccountBody` "Tài khoản của bạn sẽ bị xoá hẳn vào {date}. Khôi phục để dùng tiếp như cũ: hồ sơ, lịch sử và tin nhắn vẫn còn nguyên."; `restoreAccountAction` "Khôi phục tài khoản"; `restoreAccountContinue` "Tiếp tục xoá"; `restoreAccountContinueNote` "Bạn sẽ được đăng xuất; tài khoản vẫn bị xoá vào {date}."; `restoreAccountExport` "Tải bản sao dữ liệu"; `restoreAccountDone` "Đã khôi phục tài khoản."; `restoreAccountExpired` "Đã quá 30 ngày, tài khoản không khôi phục được nữa."; `restoreAccountFailed` "Chưa khôi phục được, thử lại sau."; `privacyExportPending` "Tài khoản đang chờ xoá, không tạo bản sao mới được."

Notifications: type `refund_account_needed` is owned by #138 (catalogue row, server-rendered copy as in Domain above, app type parsing, target `/me/payments` in `safeTarget`, dedupe by refund id); this plan only calls `notifyRefundAccountNeeded` and adds the `/me/payments` route.

## Review Focus

1. **A refund waiting for the customer is never sent twice or never at all** — the customer confirms on S22.04 at the same moment the 24-hour default fires: exactly one dispatch under the refund id; a refund without a payer account must stay waiting (not sent to nowhere) and must appear on S22.01 with "Chọn tài khoản nhận hoàn". The same holds for a dispute refund (#142): a `refund`/`split` outcome on a `bank_qr` payment waits in `awaiting_account`, `dispatchDisputeRefund` does not send it, and S18.02 opens S22.04 for it. Pin: Task 7 `choose and the 24-hour default racing dispatch once`, `no payer: stays awaiting_account and is listed as refund_account_needed` and `a dispute refund of a bank_qr payment waits for the account and is sent once`.
2. **The history never shows money the customer did not pay or hides money still held** — overpaid/late transfers (excess refunds) must show the paid row with "Đã hoàn" lines, an expired QR with money refunded must show "Đã hoàn", a 50% cancel must show held 50% then "Đã chuyển cho thợ" (partially refunded). Pin: Task 6 `payerRowOf` table tests and `a 50% cancel then release reads partially_refunded with heldAmount 0`.
3. **Deleting an account with money in flight** — a photographer with released-but-unpaid earnings, or a customer with a refund still `pending`, must be blocked; the server checks again at request time (a stale S22.02 must not delete). Every order path's open state blocks too: a booking in delivery (`shot`…`approved`), an open job post or submitted quote, an active Chụp ngay request, an active studio relation or collaboration. Pin: Task 2 `requestAccountDeletion re-checks blockers server-side`, `unpaid earnings block a photographer` and `a delivered booking, an open job post, a submitted quote, an active instant request, an active studio membership and an open collab job each block`.
4. **The purge leaves no phone number or bank number behind and survives a retry** — booking contact snapshots of the customer's bookings, registration contacts, `photographers/{uid}/private/contact`, payout accounts and Storage prefixes are gone; a second run after a crash completes without errors and deletes the Auth user once. Pin: Task 2 `purge removes contacts and payout accounts and is idempotent` (memory adapters) and the integration test (written).
5. **Hidden photographers disappear from Find and suggestions but stay bookable by link** — Find's empty-page look-ahead keeps working when a page is all hidden profiles; the profile page and "Đặt lịch" from an old booking still work. Pin: Task 4 `hidden profiles are left out of Find; a page of only hidden ones loads the next page` and `a hidden profile opened by link still shows Đặt lịch`.
6. **The 30-day restore window (Owner 2026-10-07)** — a restored account keeps everything (profile, posts, bookings, chats, payout account; `deletionPending` cleared so it is found again); a purged account cannot be restored; a restore at the same moment as the purge start has exactly one winner; nothing is deleted before `restoreUntil`; the locked user sees only S22.05. Pin: Task 2 `restoreAccount within 30 days keeps every document`, `restore and the purge start racing: exactly one wins`, `nothing is purged before restoreUntil`, `after the purge restoreAccount → not_found`; Task 4 `a locked account is redirected to /account/restore`.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`: Firestore $0.06/100K reads, $0.18/100K writes, $0.02/100K deletes (nam5 upper bound, Singapore **chưa xác nhận**); Storage $0.020/GB-month, egress $0.12/GB (**giả định, chưa xác nhận**); Scheduler: no new job.

**Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s.

**Per user action:**

| Action | Reads | Writes | get / listener | Why |
|---|---|---|---|---|
| Open S22.01 | 20 rows + 1 totals doc | 0 | listener, `limit(20)`, "Xem thêm" +20 | refund status changes live (Đang hoàn → Đã hoàn); paginated |
| Payment write (trigger, existing `onPaymentWritten`) | +~6 (payment, refunds of it, subject 1–2, open rows ≤ 5) | +2 (row, totals) | — | only when a relevant field changed (~4 of ~6 writes per payment) |
| Refund write (new `onRefundWritten`) | ~6 | 2 | — | ~2 writes per refund; refunds ≈ 10–15% of payments |
| S22.04 open / lookup / choose | 3 / 3 / 4 | 0 / 1 / 2 + dispatch (#129) | callables | |
| S22.02 open (`getAccountDeletionBlockers`) | ~20 (13 blocker queries, `limit` 5–50; empty sources cost 1 read each) | 0 | callable | |
| Confirm deletion (lock) | ~20 (blockers re-checked) + 3 | 3 (`account_deletions`, `users`, `photographers`) | callable | once per account |
| S22.05 restore | 3 | 3 | callable | only users who come back within 30 days |
| Daily purge start (`startDueAccountPurges`) | 1 query + 1 per due account | 1 per due account | daily job step | 30 runs/month |
| Account purge (30 days later) | ~200–2,000 | ~50 updates, ~200–2,000 deletes | trigger | once per account |
| S22.03 export | ~500–3,000 (bounded by `EXPORT_LIMITS`) | 1 doc + 1 Storage object (~0.2–1 MB) | callable | ≤ 1 per user per 24 h |
| S22.03 hide toggle | 0 | 1 | — | |

**New functions:** 7 callables (`pendingRefund`, `lookupRefundAccount`, `chooseRefundAccount`, `getAccountDeletionBlockers`, `requestAccountDeletion`, `restoreAccount`, `requestDataExport`), 2 triggers (`onRefundWritten`, `onAccountDeletionUpdated`, the latter doing work only on `status → purging`). Calls/month: (b) ~2,000 (trigger runs ~1,600 payment + ~100 refund, callables ~300); (c) ~20,000; `requestDataExport` 512 MiB/120 s: (c) 200 × ~3 s × 1 vCPU ≈ 600 vCPU-s; purges (c) ~20 × ~30 s ≈ 600 vCPU-s. By the rule above: (b) $0; (c) 20,000 × $0.40/M ≈ $0.01 + ~1,500 vCPU-s × $0.0000336 ≈ $0.05 + ~1,000 GiB-s × $0.0000035 ≈ $0.004 → **≈ $0.06**. **No new Scheduler job** (Decision 16): the 24-hour default adds one query per 5-minute run to #129's existing `paymentClock` (8,640 reads/month), export purge lists `exports/` once a day.

**Storage:** `exports/{uid}/{id}.json`, uncompressed JSON ~0.2–1 MB, no thumbnail; (b) ~20 exports/month, (c) ~200; deleted after 7 days → ≤ 0.2 GB stored at any time ($0.004); egress = one download each: (b) 0.02 GB ($0.002), (c) 0.2 GB ($0.024).

**Paid APIs:** none (fake name lookup; the real lookup is the intermediary's, outside Google).

**Conclusion:**
- (b) 1,000 MAU: reads ≈ 42,000 (S22.01) + 10,000 (triggers) + 50,000 (exports) + 8,640 (clock step) + deletions 15,000 ≈ 126,000 → $0.08; writes ≈ 3,500 → $0.006; deletes ≈ 15,000 → $0.003; Storage/egress ≈ $0.01; Functions $0 → **≈ +$0.10/month**. The 30-day window adds a few reads per locked account (blockers once, a daily due-query that returns little) and delays, not adds, the purge cost.
- (c) 10,000 MAU: reads ≈ 420,000 + 100,000 + 500,000 + 8,640 + 150,000 ≈ 1.18M → $0.71; writes ≈ 35,000 → $0.06; deletes ≈ 150,000 → $0.03; Storage/egress ≈ $0.03; Functions ≈ $0.06 (Tier 2, rule above) → **≈ +$0.91/month**. Below $5; the main lever if it grows is S22.01's listener (switch to `get` + pull-to-refresh) and lowering `EXPORT_LIMITS`. Firestore figures use the nam5 upper bound (Singapore chưa xác nhận).

---

**#205 = Tasks 1–5** (delete account, restore, export, privacy, hide from discovery; Blocked by nothing). **#141 = Tasks 6–11** (payment history and refund account; Blocked by #201). Old task numbers (cross-plan review, ledgers before 2026-10-08) are given in each heading.

### Task 1 (#205): Mock check, screen specs and the S22 code table (was Task 1)

**Files:**
- Check only: `docs/design/ui-mock.html` (every frame below exists since #187 (checked 2026-10-08 on develop 4e25834), plus `#S22.01-more`; the S22.04 24-hour line is there; the S09.02 group is checked and added only if missing). Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 rows S22.01–S22.04 status "⬜ có mock (2026-10-07), có plan (#141)" (the `S22.05` row already exists; set its status the same way); §3i.5 S22.02 sentence gains "Khoá ngay, xoá hẳn sau 30 ngày; đăng nhập lại trong 30 ngày thì khôi phục được (S22.05)."; §8 question 25 marked "đã chốt 2026-10-07: 30 ngày"; S22.01 row text "Lịch sử thanh toán: đã trả, đang giữ (kể cả Chụp ngay chưa tìm được người), hoàn tiền, phương thức, trạng thái từng khoản" (drop "cọc"); §3i.5 S22.03 sentence "(gửi link qua email trong 48 giờ)" → "(link tải trong app, 7 ngày)" with a pointer to owner question 1 of this plan), `docs/superpowers/specs/screens/account.md` (new sections S22.01, S22.02, S22.03, S22.04, S22.05 in the template of `screens/README.md`, strings = the l10n block above; S09.02 "Thay đổi cần làm" gains the new group), `docs/superpowers/specs/components/shared-components.md` (`EarningRow` reused for S22.01 rows; no new shared widget), `app_flutter/lib/core/screen_codes.dart` (check only: `restoreAccount = 'S22.05'` and every S22 code are already in `ScreenCodes.all`)

Every frame uses `.step` + `.phone` + `.cap`, Material Symbols `<span class="ms">`, and existing classes (`bar`, `ic`, `kpi`, `sec`, `irow2`, `irow2 x`, `brk`, `st ok|wait|live|dis`, `card`, `warnc`, `lockn`, `lkp`, `bnk`, `field`, `foc`, `sw2`, `btn pri|out|txt|dng|sm|xs`, `tlink`, `sheet`, `grab`, `dim`, `h3`, `meta`, `meta x`, `foot`). Reference copy (already in the mock; Step 1 checks it, nothing is re-added; where the committed mock differs, the mock wins and the difference is ledgered):

- **`S22.01`** (`/me/payments`): bar back + "Lịch sử thanh toán". KPI row: `3,0M` "Đang giữ" · `500K` "Đang hoàn". Meta: "Tiền bạn trả được trung gian thanh toán giữ, chỉ chuyển cho thợ theo 2 mốc." Section "Các khoản" / "Tháng 10". Rows:
  1. expanded (`irow2 x`): "Photo walk phố cổ · 2 vé" / "CN 20/10 · ZaloPay" / `500K` / `st wait` "Đang hoàn"; `brk`: "Đã trả" `500.000₫` · "Hoàn về ví ZaloPay · đang xử lý" `500.000₫` · (last, bold) "Sẽ nhận lại" `500.000₫`; under it `tlink` "Xem vé".
  2. "Minh Trí · Chân dung 2 giờ" / "T7 12/10 · Chuyển khoản QR" / `1,5M` / `st live` "Đang giữ".
  3. "Chụp ngay · Quận 1" / "Hôm nay 09:12 · MoMo · đang tìm thợ" / `800K` / `st live` "Đang giữ".
  4. "Quốc Bảo · Gia đình 1 giờ" / "28/9 · Chuyển khoản QR · đã huỷ" / `1,2M` / `st wait` "Cần tài khoản", and under the meta `btn out xs` "Chọn tài khoản nhận hoàn".
  5. "Hồng Nhung · Cưới cả ngày" / "03/09 · Chuyển khoản QR" / `8,0M` / `st ok` "Đã chuyển cho thợ".
  6. "Lan Anh · Chân dung 2 giờ" / "12/08 · MoMo · đã huỷ" / `1,5M` / `st ok` "Đã hoàn".
  Caption: `<span class="n new">Mới</span><span class="n">S22.01 · Lịch sử thanh toán</span><b>Tiền của mình đang ở đâu</b><span>Mọi khoản đã trả (buổi chụp, vé, Chụp ngay), mới nhất trước, nhóm theo tháng; không có chữ "cọc". Trạng thái bằng chữ: Đang giữ, Đang khiếu nại, Đã chuyển cho thợ (vé: cho chủ sự kiện; sự kiện của nền tảng: Đã thanh toán), Cần tài khoản, Đang hoàn, Đã hoàn, Đã hoàn một phần. Chạm một khoản để bung: đã trả, từng khoản hoàn (về ví hoặc ngân hàng •••• 4 số, đang xử lý / đã về), sẽ nhận lại, và lối mở buổi chụp / vé / yêu cầu Chụp ngay. "Cần tài khoản" có nút mở S22.04. Chưa có khoản nào: "Chưa có khoản thanh toán nào · Khi bạn đặt lịch hay mua vé, các khoản sẽ hiện ở đây." Mở từ Cài đặt (S09.02). Nhiếp ảnh gia xem tiền nhận ở S06.05.</span>`
- **`S22.04`** (existing frame): add `<div class="meta x">Không chọn thì sau 24 giờ tiền tự hoàn về tài khoản đã chuyển.</div>` right after the `tlink` "Dùng tài khoản khác" (before the wallet line).
- **`S22.04-other`** (sheet over the same S05.02 background as `S22.04`): header "Tài khoản nhận hoàn" + close; row "Bạn được hoàn" `1.500.000₫`; `field` "Ngân hàng" with `bnk` "VCB", "Vietcombank", meta x "Ngân hàng TMCP Ngoại thương Việt Nam", search icon; `field foc` "Số tài khoản" `0071000123456`; `lkp` with check: "NGUYEN THANH HA" / meta "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ."; `btn pri` "Hoàn về tài khoản này"; meta x "Số tài khoản được mã hoá, chỉ hiện 4 số cuối." Caption: `<span class="n new">Mới</span><span class="n">S22.04 · Dùng tài khoản khác</span><b>Chọn ngân hàng, gõ số, app tra tên</b><span>Như S06.06: chọn ngân hàng VietQR, gõ số tài khoản, app tra tên chủ tài khoản; không khớp thì báo "Không tìm thấy tài khoản này…", ngân hàng chưa tra được tên thì báo và gợi ý hoàn về tài khoản đã chuyển. Khi không có thông tin tài khoản đã chuyển, sheet mở thẳng form này với dòng "Chưa có thông tin tài khoản đã chuyển. Nhập tài khoản để nhận tiền hoàn."</span>`
- **`S05.02-refund`** (S05.02 of a declined booking): bar "Buổi chụp #A1F3"; card "Minh Trí · Chân dung 2 giờ" / "T7 12/10 · 15:30–17:30" + `badge b-bad` "Từ chối"; `card` with `<b>Bạn được hoàn 1.500.000₫</b><span class="meta">Chọn tài khoản để nhận tiền hoàn.</span>` and `btn out sm` "Chọn tài khoản nhận hoàn"; then the usual timeline (first step "Đã gửi & thanh toán", then "Đã từ chối"). Caption: `<span class="n new">Mới</span><span class="n">S05.02 · Chờ chọn tài khoản hoàn</span><b>Hoàn tiền chưa biết gửi về đâu</b><span>Booking trả bằng chuyển khoản QR bị từ chối, hết hạn hoặc huỷ: thẻ này hiện tới khi khách chọn tài khoản (S22.04) hoặc hết 24 giờ (tự hoàn về tài khoản đã chuyển). Trả bằng ví thì không có thẻ này.</span>`
- **`S22.02`** (blocked): bar back + "Xoá tài khoản"; `warnc` with `<b>Chưa xoá được tài khoản</b>Xong các việc dưới đây rồi quay lại.`; `card` (column) with three `irow2` rows, each icon + text + chevron: (`calendar_today`) "1 buổi chụp chưa xong" / "Minh Trí · T7 12/10"; (`confirmation_number`) "1 vé sự kiện chưa diễn ra" / "Photo walk phố cổ · CN 20/10"; (`receipt_long`) "500.000₫ đang hoàn" / "Đợi tiền hoàn về tài khoản của bạn."; section label "Khi xoá tài khoản"; five `meta` lines with "•": the five `deleteConsequence*` texts; `foot` with `btn out` `aria-disabled="true"` (dimmed) "Xoá tài khoản". Caption: `<span class="n new">Mới</span><span class="n">S22.02 · Xoá tài khoản</span><b>Nói rõ vì sao chưa xoá được và đi đâu để xong</b><span>Chặn khi còn: buổi chụp chưa xong (khách, kể cả đang bàn giao) hoặc buổi chụp khách đã đặt / được giao (thợ, thành viên studio, cộng tác viên), tin tìm thợ đang mở, báo giá đang chờ, yêu cầu Chụp ngay chưa xong, quan hệ studio hay cộng tác đang hoạt động, vé chưa diễn ra, sự kiện mình tổ chức còn mở, khiếu nại đang mở, tiền đang được giữ, tiền đang hoàn, tiền chờ chi trả (thợ, → S06.05). Mỗi dòng mở đúng màn để xử lý. Hết chặn thì nút "Xoá tài khoản" mở S22.02-confirm. Bắt buộc theo Google Play và App Store.</span>`
- **`S22.02-confirm`** (no blockers, sheet open): body: bar "Xoá tài khoản", section "Khi xoá tài khoản" + the five lines, then meta x "Muốn giữ dữ liệu? Tải bản sao trước khi xoá." with `tlink` "Tải bản sao dữ liệu"; `dim`; `sheet`: `h3` "Xoá tài khoản?", meta "Tài khoản bị khoá ngay và xoá hẳn sau 30 ngày. Trong 30 ngày, đăng nhập lại để khôi phục. Bạn có thể cần đăng nhập lại để xác nhận.", row `btn out` "Giữ tài khoản" + `btn dng` "Xoá tài khoản". Caption: `<span class="n new">Mới</span><span class="n">S22.02 · Xác nhận xoá</span><b>Nút đỏ chỉ có trong sheet</b><span>Đăng nhập quá 5 phút thì hỏi đăng nhập lại (như S06.06) rồi xoá. Xác nhận xong tài khoản bị khoá ngay (ẩn khỏi tìm kiếm, mọi phiên đăng xuất), app về S01.03 với thông báo "Tài khoản đã khoá, sẽ xoá hẳn vào {ngày}." Trong 30 ngày đăng nhập lại thì gặp S22.05. Sau 30 ngày dữ liệu bị xoá hẳn; tin nhắn, đánh giá và lịch sử giao dịch của người khác vẫn còn, tên hiện "Người dùng đã xoá".</span>`
- **`S22.05`** (new, `/account/restore`, full screen, no tab bar): centered `ic` with `ms` `restore` (large), `h3` "Tài khoản đang chờ xoá", meta "Tài khoản của bạn sẽ bị xoá hẳn vào 06/11. Khôi phục để dùng tiếp như cũ: hồ sơ, lịch sử và tin nhắn vẫn còn nguyên."; `card` (only when an export is still valid) with `download` icon + `tlink` "Tải bản sao dữ liệu"; `foot`: `btn pri` "Khôi phục tài khoản", `btn txt` "Tiếp tục xoá", meta x "Bạn sẽ được đăng xuất; tài khoản vẫn bị xoá vào 06/11." Caption: `<span class="n new">Mới</span><span class="n">S22.05 · Khôi phục tài khoản</span><b>30 ngày để đổi ý</b><span>Chủ tài khoản đăng nhập lại trong 30 ngày sau khi xác nhận xoá thì chỉ thấy màn này. "Khôi phục tài khoản" mở lại mọi thứ như cũ và về Trang chủ với thông báo "Đã khôi phục tài khoản.". "Tiếp tục xoá" đăng xuất, lịch xoá giữ nguyên. Quá 30 ngày thì dữ liệu đã bị xoá hẳn, không khôi phục được; đăng nhập lại sẽ tạo tài khoản mới. Quyết định của chủ sản phẩm 2026-10-07.</span>`
- **`S22.03`** (photographer, export ready): bar back + "Quyền riêng tư & dữ liệu"; section label "Hồ sơ"; `card`: `<b>Ẩn hồ sơ khỏi gợi ý và tìm kiếm</b><span class="meta">Hồ sơ không hiện trong Tìm thợ và gợi ý. Khách cũ vẫn mở được hồ sơ và đặt lại; bài đăng vẫn hiện như thường.</span>` + `sw2` (off, `role="switch"`, `aria-checked="false"`); section label "Dữ liệu của bạn"; `card` (column): `<b>Tải bản sao dữ liệu</b>`, meta "Hồ sơ, đặt lịch, vé, thanh toán, bài đăng, đánh giá và tin nhắn bạn đã gửi, trong một tệp JSON.", meta x "Bản sao tạo lúc 09:41 hôm nay · tải được tới 14/10", `btn out sm` with `download` icon "Tải xuống"; meta x "Mỗi 24 giờ tạo được một bản sao."; spacer; `btn txt` (colour `var(--bad)`) "Xoá tài khoản". Caption: `<span class="n new">Mới</span><span class="n">S22.03 · Quyền riêng tư & dữ liệu</span><b>Tự quyết hồ sơ có được gợi ý không, và lấy dữ liệu của mình</b><span>Chỉ nhiếp ảnh gia có nhóm "Hồ sơ". Bản sao là tệp JSON tạo ngay trong app, tải được 7 ngày, mỗi 24 giờ một lần; chưa có thì nút "Tạo bản sao", đang tạo thì "Đang tạo bản sao…". "Xoá tài khoản" mở S22.02.</span>`
- **`S09.02`**: insert, in #148's canonical order (after the "Thông báo" group, before "Hỗ trợ" when present, else before "Đăng xuất"), a section label "Thanh toán và dữ liệu" and a `card` (column, like "Tài khoản") with two rows: (`receipt_long`) "Lịch sử thanh toán" / meta x "Khoản đã trả, đang giữ, đang hoàn"; (`privacy_tip`) "Quyền riêng tư & dữ liệu" / meta x "Ẩn hồ sơ, tải bản sao dữ liệu, xoá tài khoản". Add one sentence to its caption: "Thanh toán và dữ liệu: Lịch sử thanh toán (S22.01), Quyền riêng tư & dữ liệu (S22.03, có Xoá tài khoản)."

- [ ] **Step 1:** Check the frames above against this copy (ids unique, `data-code` set); add only the S09.02 group if it is missing.
- [ ] **Step 2:** Spec §2 rows (S22.01–S22.05), §3i.5 sentences, §8 question 25, `screens/account.md` sections (Thông tin, Mục đích, Điểm vào → ra, Bố cục, Dữ liệu, Trạng thái, Tương tác, Chuỗi = l10n keys above, Chấp nhận), `shared-components.md` note; `screen_codes.dart` check only.
- [ ] **Step 3:** Check every string in `screens/account.md` S22 sections equals the mock copy and the l10n block of this plan.
- [ ] **Step 4: Commit** `docs(spec): S22 screen specs and spec rows [#205]` (docs for all five S22 screens, so #141 needs no docs task of its own before code).

### Task 2 (#205): Domain + Functions — delete account (30-day lock, restore, purge), data export, hide from discovery (was Task 4)

**Files:**
- Create: `packages/domain/src/account_deletion.ts`, `packages/domain/src/data_export.ts`, tests `packages/domain/test/account_deletion.test.ts`, `data_export.test.ts`; Functions `src/infra/admin.ts` (add `adminAuth()` = `getAuth()` and `bucket()` = `getStorage().bucket()`, initialised like `db()`), `src/infra/account_firestore.ts` (`liveAccountDeletionDeps()`, snapshot queries), `src/infra/account_purge.ts` (`purgeAccount(uid, deps)` + `PurgeDeps` port so it is unit-testable), `src/infra/data_export_firestore.ts` (`liveDataExportDeps()`: gather queries, Storage write, record), `src/callables/account.ts` (`handleGetAccountDeletionBlockers`, `handleRequestAccountDeletion`, `handleRestoreAccount`, `handleRequestDataExport`), `src/triggers/account_deletion.ts` (`handleAccountDeletionUpdated`: acts only when `before.status != 'purging' && after.status == 'purging'`), `src/scheduled/prune_data_exports.ts` (`pruneDataExports(bucket, now)`), `src/scheduled/start_account_purges.ts` (`startDueAccountPurges` wiring); tests `test/unit/account_callables.test.ts`, `account_purge.test.ts`, `data_export.test.ts`, `prune_data_exports.test.ts`, `start_account_purges.test.ts`; integration (written) `test/integration/account.test.ts`
- Modify: `packages/domain/src/index.ts`; Functions `src/index.ts` (four callables, `onAccountDeletionUpdated`, `pruneNotifications` gains the named steps `pruneDataExports` and `startDueAccountPurges`, each in its own try/catch), #129's order-gate adapter (`acceptsOrders` is false while `photographers/{uid}.deletionPending == true`; one condition, its test in this task), `app_flutter/firebase/firestore.rules` (`account_deletions`, `hiddenFromDiscovery` in `photographerClientFields()`, `deletionPending` in `photographerServerFieldsUntouched()`), `app_flutter/firebase/storage.rules` (`exports/{uid}/{file}`), `firestore.indexes.json` (field override `timeline.authorId` collection group, `account_deletions (status, restoreUntil)`, `payments (payerId, createdAt desc)` (money blockers, Decision 12), `bookings (assigneeId, status)` if absent), `rules-test/rules.test.mjs`, `seed/README.md` (how to try deletion, restore and export on the emulator; to test the purge, set `restoreUntil` in the past in the emulator UI and run `pruneNotifications` from the Functions shell)

**Interfaces:**
- Consumes: `payments` and `refunds` (#129) for the money blockers (Decision 12; not #141's history rows), `REAUTH_MAX_AGE_SECONDS`, `EarningsSummary`, `PayoutAccountCallableInput` (auth_time pattern).
- Produces: Contract → `account_deletion.ts`, `data_export.ts`; callables `getAccountDeletionBlockers`, `requestAccountDeletion`, `restoreAccount`, `requestDataExport`; trigger `onAccountDeletionUpdated`; daily step `startDueAccountPurges`.

`ACCOUNT_DATA_MAP` (the single list the purge and the ledger follow; this plan, last in wave order, writes every row, including those for collections of #135/#136/#139/#140/#151; a step whose collection does not exist yet is a no-op):

| target | action |
|---|---|
| `users/{uid}` | tombstone (`displayName` = `DELETED_USER_NAME`, `avatarUrl`/`avatarPath` null, `deleted`, `deletedAt`; `role` kept) |
| `users/{uid}/private/*`, `notifications/*`, `badges/*`, `payments/*` | delete |
| `photographers/{uid}` + `services/*` + `private/*` | delete |
| `availability/{uid}/days/*` | delete |
| `payoutAccounts/{uid}` + `accounts/*`, `earnings/{uid}` + `items/*` | delete |
| `devices` (`userId`), `likes`/`saves`/`follows` (`userId`), `follows` (`photographerId`) | delete |
| `posts` (`authorId`) + `events/*/timeline/{postId}` (`authorId`) | delete |
| `albums` (`photographerId`), `awards` (`photographerId`) + `awardProofs/{awardId}` | delete |
| `bookings/*/private/contact` of the customer's bookings | delete (bookings themselves kept) |
| `events/*/registrations/*` (`userId`) | anonymize `userName` = `DELETED_USER_NAME`, `userAvatarUrl` null; delete `private/contact` |
| `events` (`hostId`) | anonymize `host.name`, `host.avatarUrl` |
| `chats`, messages, `reviews`, `bookings`, `payments`, `refunds`, `ledger_entries`, `payouts`, `payment_notifications`, `contact_access_log` | keep (names come from the tombstone; accounting/security) |
| Storage `avatars/{uid}/`, `posts/{uid}/`, `users/{uid}/`, `awardProofs/{uid}/`, `eventCovers/{uid}/`, `exports/{uid}/` | delete |
| `jobs` (`customerId`) (#139) | `open`/`draft` ones already block; others keep, anonymize `customerName`; delete `jobs/*/views/{uid}`, `matches/{uid}`, `invites/{uid}` |
| `quotes` (`photographerId`) (#139) | keep (customer's decision history); name from the tombstone |
| `instant_requests` (`customerId`/`photographerId`) (#140) | keep (payments); delete `private/contact` of the customer's requests; delete `instant_presence/{uid}`, `instant_offers/{uid}` subtree |
| `studio_members`, `studio_collaborations` (+ `history`), `collab_jobs` (#136, #151) | keep (inactive by then: active ones block); names from the tombstone |
| `recruitPosts` (`studioId`), `recruitApplications` (`applicantId`) (#151) | delete (public posts are taken down) |
| identity (#135) | delete `identity`, keep `idHash` (identity spec §9) |
| Auth user | sessions revoked at lock (not disabled, so the owner can restore); deleted last by the purge |

- [ ] **Step 1: Failing tests:**
  - `account_deletion.test.ts`: `no blockers for a fresh customer`; `an upcoming booking blocks with count and first item`; `a delivered booking, an open job post, a submitted quote, an active instant request, an active studio membership and an open collab job each block` (Review Focus 3; one row per kind); `an assigned studio booking blocks the member as open_job`; `a cancelled, completed or reviewed booking does not block`; `a photographer's accepted job blocks as open_job`; `a paid ticket of an event that has not ended blocks; one that ended does not`; `a hosted open event blocks`; `held payments and refunds in progress give amounts (read from payments and refunds, no history rows needed)`; `a disputed payment blocks as open_dispute`; `a refund pending on a fully refunded payment still blocks as refund_in_progress`; `unpaid earnings block a photographer` (Review Focus 3); `blockers come in the fixed order`; `requestAccountDeletion with sign-in older than 5 minutes → reauth_required`; `requestAccountDeletion re-checks blockers server-side → conflict` (Review Focus 3); `confirming locks the account: deletion_pending, restoreUntil = +30 days, deletionPending on the provider, sessions revoked, Auth user not disabled`; `a second request while pending returns the same restoreUntil`; `raw other than {} → invalid_argument`; `restoreAccount within 30 days keeps every document` (Review Focus 6: status restored, accountStatus active, deletionPending false, nothing deleted); `restoreAccount after restoreUntil → deadline_passed`; `restoreAccount when not pending → not_found`; `restore and the purge start racing: exactly one wins` (`Promise.all([restoreAccount, startDueAccountPurges])` at `restoreUntil`: either restored or purging, never both); `nothing is purged before restoreUntil` (`startDueAccountPurges` skips a pending account whose window is open); `startDueAccountPurges moves at most 50 due accounts to purging`; `tombstoneOf keeps role, clears name and avatar, removes accountStatus and restoreUntil`.
  - `data_export.test.ts`: `buildExportDocument removes accountNumberEnc, payer, candidate, providerRef, token at any depth`; `adds schemaVersion and generatedAt`; `exportAllowed false within 24 h`; `requestDataExport writes, records expiresAt +7 days`; `a second export within 24 h → limit_exceeded`; `an export while deletion is pending → not_eligible`.
  - Functions `account_purge.test.ts` (in-memory `PurgeDeps`): `purge removes contacts and payout accounts and is idempotent` (Review Focus 4: run twice, the second run has nothing to do, Auth delete called once); `purge tombstones users/{uid} and anonymizes registrations and hosted events`; `purge records each step in done[]`; `a failing step stops before deleting the Auth user and the retry continues`; `a blocker found at purge time stops the purge with status blocked`; `after the purge restoreAccount → not_found` (Review Focus 6); `the trigger ignores updates that do not move status to purging`.
  - `account_callables.test.ts`: `requestAccountDeletion passes auth_time`; `conflict carries details.blockers kinds`; `restoreAccount maps deadline_passed to failed-precondition with details.code`; `requestDataExport logs no content`. Order gate: `a provider with deletionPending is not accepting orders`. `start_account_purges.test.ts`: `pruneNotifications runs startDueAccountPurges as a named step and a failure there does not stop pruneDataExports`. `prune_data_exports.test.ts`: `deletes exports older than 7 days and keeps newer ones`. Rules (written): `client cannot read or write account_deletions`; `client cannot set deleted on users/{uid}`; `owner can set hiddenFromDiscovery to a bool, not a string`; Storage: `owner reads exports/{uid}/x.json; another user cannot; no client write`. Integration (written): `request deletion → locked → restoreUntil moved to the past → daily step → trigger purges → Auth user gone`; `request deletion → restore → account usable`; `export → file in Storage → owner can read`.
- [ ] **Step 2: Run** domain and functions tests → fail.
- [ ] **Step 3: Implement.** Purge = ordered steps from `ACCOUNT_DATA_MAP`, each a function `(uid, deps) => Promise<void>` that is safe to repeat (queries in pages of 300 with `BulkWriter`; `recursiveDelete` for subtrees; Storage `bucket.deleteFiles({ prefix })`); after each step `done = arrayUnion(step)`; skip steps already in `done`; finally `adminAuth().deleteUser(uid)` (ignore `auth/user-not-found`) and `status: 'done'`. Lock: one Firestore transaction (`account_deletions/{uid}` create-or-return, `users/{uid}` `accountStatus`/`restoreUntil`, `photographers/{uid}.deletionPending` when that doc exists), then `adminAuth().revokeRefreshTokens(uid)` outside it (safe to repeat). Restore and `startPurge` are transactions on `account_deletions/{uid}` that re-read `status` and `restoreUntil`, so only one of them can move a `pending` document. Snapshot queries use existing indexes: bookings `(customerId|photographerId|assigneeId, status not-in OPEN_BOOKING_EXCLUDED)`; the #139/#140/#136/#151 sources with `limit 5` each (Decision 12); registrations collection group `userId == uid orderBy createdAt desc limit 50` then filter `held|paid` and `event.endAt > now`, events `hostId == uid orderBy startAt desc limit 50` then filter `open|full|closed`, `payments where payerId == uid orderBy createdAt desc limit 200` and `refunds where paymentId in` those ids (chunks of 30) for `PayerMoneyItem`s, `earnings/{uid}`. Export `gather` uses the same queries with `EXPORT_LIMITS`; JSON written with `contentType: 'application/json'`.
- [ ] **Step 4: Run** domain `npm test && npm run lint && npm run typecheck`; functions `npm test && npm run build` → pass. Ledger: rules/storage tests and integration written, not run.
- [ ] **Step 5: Commit** `feat(account): delete account with blockers and purge, data export, hide from discovery rules [#205]`.

### Task 3 (#205): App data — account repository and discovery fields (account half of the old Task 5)

**Files:**
- Create: `app_flutter/lib/data/account/account_repository.dart`, `lib/data/account/firebase_account_repository.dart`, `lib/data/account/account_providers.dart`; test support `test/support/fake_account_repository.dart`; tests `test/data/account/account_repository_test.dart`
- Modify: `lib/data/content/photographer_summary.dart` + `firestore_photographer_repository.dart` (`hiddenFromDiscovery`, `deletionPending`), `test/support/content_fixtures.dart` (`fixturePhotographer(..., hiddenFromDiscovery = false, deletionPending = false)`)

**Interfaces:**
- Consumes: Firestore `users/{uid}` (`accountStatus`, `restoreUntil`), `users/{uid}/private/dataExport`, `photographers/{uid}`; callables of Task 2; `FirebaseStorage.ref(path).getDownloadURL()`.
- Produces: Contract → App (`AccountRepository`, `DeletionBlocker`, `BlockerKind`, `DataExport`, `AccountException`, `AccountLock`, providers `accountRepositoryProvider`, `accountLockProvider`, `dataExportProvider`; `PhotographerSummary.hiddenFromDiscovery/deletionPending`).

- [ ] **Step 1: Contract check**; ledger differences.
- [ ] **Step 2: Failing tests:** `DeletionBlocker parses kinds, count, amount, first`; `DataExport.usableAt is false at expiresAt`; `photographerSummaryFrom reads hiddenFromDiscovery and deletionPending (missing → false)`; `FirebaseAccountRepository.requestDeletion returns restoreUntil and maps reauth_required and conflict to AccountException`; `restore maps deadline_passed`; `watchLock emits AccountLock for deletion_pending and null for active or missing`.
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/data/account` → fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/data/account`; `… test/data/content` → pass.
- [ ] **Step 6: Commit** `feat(data): account repository, deletion lock and hidden-profile fields [#205]`.

### Task 4 (#205): S22.02 Xoá tài khoản, S22.03 Quyền riêng tư & dữ liệu, S22.05 Khôi phục tài khoản, discovery filter, the S09.02 group (was Task 8 + the privacy row of the old Task 7)

**Files:**
- Create: `app_flutter/lib/features/account/delete_account_screen.dart`, `delete_account_controller.dart`, `privacy_screen.dart`, `privacy_controller.dart`, `restore_account_screen.dart`, `restore_account_controller.dart`; tests `test/features/account/delete_account_screen_test.dart`, `privacy_screen_test.dart`, `restore_account_screen_test.dart`, `test/app/account_lock_redirect_test.dart`
- Modify: `lib/app/router.dart` (`/settings/privacy`, `/settings/delete-account`, `/account/restore`, the lock redirect), `lib/features/settings/settings_screen.dart` (group "Thanh toán và dữ liệu" in #148's `paymentsData` slot of `settingsGroupOrder`, `_SectionLabel` key `settings-group-paymentsData`, with the row "Quyền riêng tư & dữ liệu" (`AppIcons.privacy`, key `settings-privacy`; customers see `settingsPrivacyBodyCustomer`); no edit to the order list or its test; #141 adds "Lịch sử thanh toán" above it), `test/features/settings/settings_test.dart`, `lib/core/theme/app_icons.dart` (`privacy`, `download`, `restore = Symbols.restore_rounded`), `lib/features/find/find_controller.dart` (`_visible` drops `hiddenFromDiscovery || deletionPending`), `lib/data/recommendation/local_recommender.dart` (`recommendPhotographers`, `similar` drop those candidates), `lib/l10n/app_vi.arb` (S22.02, S22.03, S22.05 keys and the #205 S09.02 keys), tests `test/features/find/find_controller_test.dart` (or the existing find test), `test/data/recommendation/local_recommender_test.dart` (existing), `test/features/photographer_profile/photographer_profile_screen_test.dart`, `services/recommender/api/openapi.yaml` (description note: candidates with `hiddenFromDiscovery == true` are excluded)

**Interfaces:**
- Consumes: `AccountRepository`, `accountLockProvider`, `dataExportProvider`, `currentProfileProvider` (role), `showReauthSheet` from `lib/features/account/widgets/reauth_sheet.dart` (#134; cross-plan review finding 24), `showConfirmSheet(danger: true)`, `authRepositoryProvider.signOut`, `externalLauncherProvider`, `PhotographerSummary.hiddenFromDiscovery`.
- Produces: `DeleteAccountScreen` (`ScreenCodes.deleteAccount`), `PrivacyScreen` (`ScreenCodes.privacy`), `RestoreAccountScreen` (`ScreenCodes.restoreAccount`).

**Backend wiring:** S22.02: `getAccountDeletionBlockers` on open (pull to refresh), `requestAccountDeletion` (on `reauth_required` → `showReauthSheet` → retry once, like `PayoutAccountController.save`), success → `signOut()` → `/login` with SnackBar `deleteAccountDone` (date = `restoreUntil` in Vietnam time, `dd/MM`). S22.05: `accountLockProvider` (listener on `users/{uid}`) drives the router redirect; "Khôi phục tài khoản" → `restore()` → `/` with SnackBar `restoreAccountDone` (`deadline_passed` → `restoreAccountExpired` and sign out); "Tiếp tục xoá" → `signOut()`; the export link shows only while `dataExportProvider` has a usable export. S22.03: `photographers/{uid}.hiddenFromDiscovery` write (rules Task 2) from the switch (optimistic, reverted with a SnackBar on error); `requestDataExport`; `users/{uid}/private/dataExport` listener; "Tải xuống" → `exportDownloadUrl(path)` → `externalLauncherProvider.open`.

**Mock parity (`#S22.02`, `#S22.02-confirm`, `#S22.03`):** S22.02 blocked: red-tinted warning card (title + body), a `GlassCard` list of blocker rows (icon by kind: `calendar` booking/job, `ticket` ticket, `celebration` event, `warning` dispute, `receipt` money; title from the `deleteBlock*` keys with count/amount; subtitle the first item "title · day" or the body text; chevron; tap opens `/b/:id`, tickets tab, `/events/:id/manage`, `/me/payments`, `/work/earnings`, `/jobs/:id` (job post, quote), `/instant/:id` (customer) or `/work/instant/:id` (photographer), `/studio/members`, `/collab`; icons `work` (job post, quote), `AppIcons.instant`, `group` (studio, collab)), section "Khi xoá tài khoản" with the five lines, bottom outline "Xoá tài khoản" disabled. No blockers: same without the warning and list, plus the quiet line `deleteExportHint` with the link `deleteExportHintLink` (→ `/settings/privacy`), outline enabled → confirmation sheet (`deleteConfirmTitle`, `deleteConfirmBody`, keep "Giữ tài khoản", red "Xoá tài khoản"). S22.05 (`#S22.05`): full screen without tab bar, large `AppIcons.restore` in a circle, title `restoreAccountTitle`, body `restoreAccountBody` with the date, optional export link card, primary "Khôi phục tài khoản" (the screen's one primary), text button "Tiếp tục xoá", quiet `restoreAccountContinueNote`. S22.03: section "Hồ sơ" (photographers only) with a `SwitchListTile` (`privacyHide` + `privacyHideBody`); section "Dữ liệu của bạn" card: title, body, state line (`privacyExportReady` with VN time and date, or nothing), outline small "Tạo bản sao" / "Đang tạo bản sao…" (loading) / "Tải xuống" (icon `AppIcons.download`); quiet `privacyExportCooldown`; red text button "Xoá tài khoản" at the bottom → `/settings/delete-account`.

- [ ] **Step 1: Failing tests:**
  - `delete_account_screen_test.dart`: `lists "1 buổi chụp chưa xong · Minh Trí · T7 12/10" and opens /b/:id`; `lists "500.000₫ đang hoàn" and opens /me/payments`; `a photographer with unpaid earnings sees "1.500.000₫ chờ chi trả" opening /work/earnings`; `with blockers the Xoá tài khoản button is disabled`; `without blockers it opens the red confirmation sheet`; `confirm calls requestDeletion, signs out and shows "Tài khoản đã khoá, sẽ xoá hẳn vào 06/11."`; `an active instant request shows "1 yêu cầu Chụp ngay chưa xong" opening /instant/:id`; `no blockers shows the export hint linking to /settings/privacy`; `reauth_required opens the reauth sheet (features/account/widgets) and retries once`; `conflict (blockers appeared) reloads the list`; `fits 320dp at 1.3x text`.
  - `privacy_screen_test.dart`: `a photographer sees the hide switch; a customer does not`; `toggling writes hiddenFromDiscovery`; `a write error reverts the switch`; `no export: "Tạo bản sao" calls requestExport and shows "Đang tạo bản sao…"`; `ready export shows "Bản sao tạo lúc 09:41 · tải được tới 14/10" and Tải xuống opens the download URL`; `limit_exceeded shows privacyExportLimit`; `an expired export shows Tạo bản sao again`; `Xoá tài khoản opens /settings/delete-account`.
  - `restore_account_screen_test.dart`: `shows "Tài khoản đang chờ xoá" with the date and one primary "Khôi phục tài khoản"`; `Khôi phục tài khoản calls restore and goes home with "Đã khôi phục tài khoản."`; `deadline_passed shows restoreAccountExpired and signs out`; `Tiếp tục xoá signs out`; `the export link shows only for a usable export`; `fits 320dp at 1.3x text`. `account_lock_redirect_test.dart`: `a locked account is redirected to /account/restore from any route` (Review Focus 6); `an active account visiting /account/restore goes to /`.
  - settings: `the paymentsData group passes #148's settingsGroupOrder test (after Thông báo, before Đăng xuất)`; `"Quyền riêng tư & dữ liệu" opens /settings/privacy`; `a customer sees "Tải bản sao dữ liệu, xoá tài khoản" as the subtitle`.
  - find/recommender: `hidden profiles are left out of Find; a page of only hidden ones loads the next page` (Review Focus 5); `a deletion-pending profile is left out of Find`; `LocalRecommender drops hidden and deletion-pending candidates`; profile: `a hidden profile opened by link still shows Đặt lịch` (Review Focus 5).
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/account`, `… test/app`, `… test/features/find`, `… test/data/recommendation`, `… test/features/photographer_profile`, `… test/features/settings` → fail.
- [ ] **Step 3: Implement**; arb; `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze`; the six folders → pass.
- [ ] **Step 5: Commit** `feat(account): S22.02 delete account with 30-day restore (S22.05), S22.03 privacy and data, hidden profiles out of discovery [#205]`.

### Task 5 (#205): Spec status, data model and ledger for deletion and privacy (deletion half of the old Task 9)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S22.02, S22.03, S22.05 status "✅ đã làm (#205)" with the note S22.03 "link tải trong app"), `docs/superpowers/specs/data-model/domain-model.md` (`Photographer.hiddenFromDiscovery`/`deletionPending`, `User.accountStatus`/`restoreUntil`, `AccountDeletion` with its five statuses and the 30-day window), `docs/superpowers/specs/data-model/relational-schema.md` (`account_deletions` (`restore_until`, status), `users.account_status`, `photographers.hidden_from_discovery`; mapping table rows), `docs/legal/terms-and-help-notes.md` (data copy and deletion — "Dữ liệu cá nhân" section with what is deleted and kept, per `ACCOUNT_DATA_MAP`, and the 30-day restore window)
- Create: `docs/superpowers/handover/ledger-s22-account-privacy.md`

- [ ] **Step 1:** Edit the docs to match the code as built (Vietnamese specs, English code names).
- [ ] **Step 2:** Ledger: shipped per task; rulings (Decisions 9–16 as built, Owner 2026-10-07 restore window, the split ruling of Decision 12, contract differences; which soft blocker sources (#136/#139/#140/#142/#151/#152) had merged); skipped emulator suites (rules tests for `account_deletions`, `hiddenFromDiscovery`, Storage `exports/`; integration `account.test.ts`); deploy order: (1) Firestore rules + indexes (`account_deletions (status, restoreUntil)`, `payments (payerId, createdAt desc)`, field override `timeline.authorId`) before the functions; (2) **Storage rules are a manual deploy** (`npm run deploy:storage:dev` from `rules-test/`, or the firebase-deploy workflow with `storage: true`) — without them "Tải xuống" is refused; (3) functions (`onAccountDeletionUpdated`, four callables; `pruneNotifications` now also prunes exports and starts due purges); (4) app last. Carry: any later order path must add its blocker kind and `ACCOUNT_DATA_MAP` row here; Google Play's web deletion-request link needs a public page (Deferred).
- [ ] **Step 3: Commit** `docs(spec): S22 deletion and privacy status, data model and ledger [#205]`.

### Task 6 (#141): Domain + Functions — payer payment history (was Task 2)

**Files:**
- Create: `packages/domain/src/payer_history.ts`, `packages/domain/src/memory_payer_history_store.ts`, `packages/domain/test/payer_history.test.ts`; Functions `src/infra/payer_history_firestore.ts` (`FirestorePayerHistoryStore`), `src/triggers/refund_write.ts` (`handleRefundWrite`), tests `test/unit/payer_history_firestore.test.ts`, `test/unit/refund_write.test.ts`, integration (written) `test/integration/payer_history.test.ts`
- Modify: `packages/domain/src/index.ts`; Functions `src/triggers/payment_write.ts` (also refresh the payer row when `status`, `escrowStatus`, `receivedAmount` or `refundedAmount` changed), `src/index.ts` (`onRefundWritten`), `test/unit/` payment write test (existing file for `handlePaymentWrite`, or create `payment_write.test.ts`); `app_flutter/firebase/firestore.rules` (`users/{uid}/payments`), `rules-test/rules.test.mjs`; `seed/fixtures.ts` + `seed/README.md` (history rows for the seed customer: one held, one refunded, one released; one `instant_request` fixture row for S22.01 testing, marked "fixture until #140")

**Interfaces:**
- Consumes (#129): `Payment`, `Refund` (`fromEscrow`), `escrowRefundedTotal`, `PaymentMethod`, `VN_BANKS`; (V2): `RefundMethod`; `RefundKind` is derived here from `fromEscrow`.
- Produces: everything in Contract → `payer_history.ts`; `FirestorePayerHistoryStore` (`subjectOf`: booking → `users/{photographerId}.displayName` + `serviceSnapshot.name` + `day`, `cancelled` for `cancelled|declined|expired`; ticket → registration `event.title` + `quantity` + VN day of `event.startAt`, `eventId`; `instant_request` → `{title: 'Chụp ngay · ' + area, searching}` from `instant_requests/{id}` when #140 exists, else the stored row's title); `handleRefundWrite(refundId, before, after, deps)`.

- [ ] **Step 1: Contract check** (#129 names present; `handlePaymentWrite` signature); ledger differences.
- [ ] **Step 2: Failing tests** (`payer_history.test.ts`, table-driven with `payerRowOf`):
  - `no row before money arrives` (created, receivedAmount 0) and `no row for an expired empty QR`;
  - `paid booking, escrow held → held, heldAmount = amount, open`;
  - `disputed → disputed, open`;
  - `released → released, heldAmount 0, not open`;
  - `50% cancel then release → partially_refunded, refundedAmount = half` (Review Focus 2);
  - `full refund done → refunded`; `refund pending → refunding, refundingAmount`; `refund failed → refunding` (Decision 3);
  - `refund awaiting_account → refund_account_needed, open` (Review Focus 1);
  - `overpaid: paid row with an excess refund line, status held` (Review Focus 2);
  - `late transfer to an expired QR, refunded → refunded` (Review Focus 2);
  - `bank refund destination label is "Vietcombank •••• 6789"; wallet refund label is null`;
  - `instant_request subject renders title and searching`;
  - `payerTotals sums held and refunding of open rows`;
  - `refreshPayerHistory writes the row and totals; deletes a row that has no money; missing payment → missing`.
  Functions: `refund_write.test.ts`: `a refund write refreshes the payer row of its payment`; payment write test: `a write that changes only updatedAt does not refresh the payer row`; `payer row and earnings both refresh on a status change`; `payer_history_firestore.test.ts`: `row round-trips Timestamps and never contains payer, candidate or accountNumberEnc`; `subjectOf a booking reads the photographer's display name`. Rules (written): `owner reads users/{uid}/payments/*`; `another user cannot`; `no client writes`.
- [ ] **Step 3: Run** `cd packages/domain && npm test` and `cd app_flutter/firebase/functions && npm test` → fail.
- [ ] **Step 4: Implement.** Status precedence exactly as Decision 3; `heldAmount = amount − escrowRefundedTotal(refunds)` only for held/disputed; the row never copies `payer`, `candidate`, `instructions`, `providerRef` (whitelist the fields). Trigger wiring in `index.ts`: `export const onRefundWritten = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'refunds/{refundId}' }, …)`.
- [ ] **Step 5: Run** domain `npm test && npm run lint && npm run typecheck`; functions `npm test && npm run build` → pass. Ledger: rules tests and `payer_history.test.ts` integration written, not run.
- [ ] **Step 6: Commit** `feat(payments): payer payment history rows and totals for S22.01 [#141]`.

### Task 7 (#141): Domain + Functions — refund account (S22.04 backend) (was Task 3)

**Files:**
- Create: `packages/domain/src/refund_account.ts`, test `packages/domain/test/refund_account.test.ts` (`account_lookup.ts` and its test come from #134, merged in #193; reuse); Functions `src/callables/refund_account.ts` (`handlePendingRefund`, `handleLookupRefundAccount`, `handleChooseRefundAccount`), `src/infra/live_refund_account.ts`, tests `test/unit/refund_account_callables.test.ts`, integration (written) `test/integration/refund_account.test.ts`
- Modify: `packages/domain/src/escrow.ts` (`Refund.candidate` only; `confirmBy` and `BookingTx.getRefund` are V2's; `applyRefundToPayment` per Contract), `commit_transition.ts` and `event_payments.ts` (`refundTicket`, `cancelEventWithRefunds`): do not dispatch `awaiting_account` refunds; set `booking.refundAccountNeeded` / registration `refundStatus: 'awaiting_account'`; call #138's `notifyRefundAccountNeeded`), `payment_sweeps.ts` (#129's `runPaymentSweeps` gains the named step `confirmDueRefundAccounts` at the end of its step list, own try/catch; `BookingStore.awaitingRefundsDue`, V2's), `refund_account.ts` `pendingRefundFor` (`{disputeId}` → the dispute's payment, #142), `booking.ts` (`refundAccountNeeded?: boolean`), memory stores, `index.ts`; Functions `src/infra/booking_firestore.ts` (refund `candidate`, `confirmBy`, booking `refundAccountNeeded`, `getRefund` in the transaction adapter), the Firestore `awaitingRefundsDue` query (`status == 'awaiting_account' && confirmBy <= now`) on `FirestoreBookingStore` in `src/infra/booking_firestore.ts` (no `payment_firestore.ts` exists; if V2 creates one, it goes there), `src/index.ts` (three callables), `firestore.indexes.json` (`refunds (status, confirmBy)`), tests `test/unit/payment_clock.test.ts`, `booking_firestore.test.ts` (extend the shared `round-trips Booking through Firestore conversion` with `refundAccountNeeded`; do not add a second round-trip test)

**Interfaces:**
- Consumes (#129): `dispatchRefund`, `dispatchTicketRefund` (export it), `AccountCipher`; `BookingStore` payment queries (#129; the old `PaymentLookup`); (V2, #201): `sendRefundOnce`, `mergeRefundOutcome`, `BookingTx.getRefund`, `BookingStore.awaitingRefundsDue`, `PayerBankAccount`/`StoredBankAccount` (`bankCode`); (V1, soft): `SettlementDeps`; `normalizeAccountNumber`, `normalizeHolderName`, `accountLast4`, `bankByCode`. (#134): `AccountNameLookup`, `FakeAccountNameLookup` from `account_lookup.ts`. (#138): `notifyRefundAccountNeeded`. (#142): `dispatchDisputeRefund`, `resolveDispute`.
- Produces: Contract → `refund_account.ts`, callables `pendingRefund`, `lookupRefundAccount`, `chooseRefundAccount`.

- [ ] **Step 1: Failing tests** (`refund_account.test.ts`, memory stores, fake gateway, fake lookup):
  - `a customer cancel of a bank_qr booking creates an awaiting_account policy refund prefilled with the payer and confirmBy +24 h, not sent`;
  - `a decline of a bank_qr booking does the same and calls notifyRefundAccountNeeded once` (dedupe by refund id is #138's key; a retry calls the hook again with the same refund id);
  - `a momo booking refund is sent at once (no window)`;
  - `an excess refund (overpaid) is sent at once to the payer` (#129 behaviour unchanged);
  - `no payer: awaiting_account with no confirmBy and the notification says "Chọn tài khoản để nhận tiền."` (Review Focus 1);
  - `booking.refundAccountNeeded is true while waiting and false after the choice`; `a ticket refund mirrors refundStatus awaiting_account`;
  - `pendingRefundFor returns amount, masked payer and confirmBy; null when nothing waits; another user → permission_denied`;
  - `lookupRefundAccount stores an encrypted candidate and returns the looked-up name (the caller's normalised name echoed by the fake)`; `number ending 0404 → not_found`; `ending 4321 → found TRAN VAN B`; `ending 9999 → not_eligible`; `unknown bank → invalid_argument`; `refund not awaiting → conflict`;
  - `chooseRefundAccount payer → pending and dispatched to the payer account`; `candidate → destination source customer`; `candidate missing → invalid_argument`; `a second choose returns the current status without a second dispatch`;
  - `choose and the 24-hour default racing dispatch once` (Review Focus 1: `Promise.all([choose, confirmDueRefundAccounts])`, fake `refundCalls` length 1);
  - `confirmDueRefundAccounts sends due ones to the payer and leaves no-payer ones waiting`;
  - `a dispute refund of a bank_qr payment waits for the account and is sent once` (#142's `resolveDispute` refund outcome → `awaiting_account`; `dispatchDisputeRefund` sends nothing; `chooseRefundAccount` sends it; Review Focus 1); `pendingRefundFor {disputeId} returns the dispute's waiting refund`.
  (No `account_lookup.test.ts` here: #134 owns it.)
  Functions: `refund_account_callables.test.ts`: `lookupRefundAccount logs only the code, never the number`; `errors map (not_found → not-found, not_eligible → failed-precondition)`; payment clock: `confirmDueRefundAccounts runs as the last named step and a failure in it does not stop the other steps`; mapping: `refund candidate and confirmBy round-trip`; the shared `round-trips Booking through Firestore conversion` covers `refundAccountNeeded`. Integration (written): `cancel → awaiting → choose payer → refund done`.
- [ ] **Step 2: Run** domain and functions tests → fail.
- [ ] **Step 3: Implement.** The race is settled inside one transaction per refund: both `chooseRefundAccount` and `confirmDueRefundAccounts` move `awaiting_account → pending` only when the stored status is still `awaiting_account` (re-read inside the transaction); only the caller that made the move dispatches. Sample:
  ```ts
  async function claimForDispatch(deps: RefundAccountDeps, refundId: string, patch: Partial<Refund>): Promise<{ refund: Refund; payment: Payment } | null> {
    return deps.bookings.store.runTransaction(async (tx) => {
      const r = await tx.getRefund(refundId);          // V2's BookingTx.getRefund (memory + Firestore)
      if (r === null || r.status !== 'awaiting_account') return null;
      const p = await tx.getPayment(r.paymentId);
      if (p === null) return null;
      const next: Refund = { ...r, ...patch, status: 'pending', updatedAt: deps.clock.now().toISOString() };
      await tx.addRefund(next);                         // set by id
      if (p.subjectType === 'booking') { /* clear booking.refundAccountNeeded when no other refund of it waits */ }
      return { refund: next, payment: p };
    });
  }
  ```
  Tickets: the registration mirror is updated by `dispatchTicketRefund`'s existing mirror write. `lookupRefundAccount` encrypts with the existing cipher and resolves `bankName` from `VN_BANKS`.
- [ ] **Step 4: Run** domain `npm test && npm run lint && npm run typecheck`; functions `npm test && npm run build` → pass. Ledger: integration written, not run.
- [ ] **Step 5: Commit** `feat(payments): refund account choice with 24-hour default and account name lookup [#141]`.

### Task 8 (#141): App data — history and refund account (payments half of the old Task 5)

**Files:**
- Create: `app_flutter/lib/data/payments/payment_history.dart`; test support: extend `test/support/fake_payments_repository.dart` (#129); tests `test/data/payments/payment_history_test.dart`
- Modify: `lib/data/payments/payments_repository.dart` (methods in Contract; rename `FunctionsPaymentsRepository` → `FirebasePaymentsRepository`), `lib/data/booking/booking.dart` (`refundAccountNeeded`, regenerate freezed) (the `refund_account_needed` type parsing is #138's, merged)

**Interfaces:**
- Consumes: Firestore `users/{uid}/payments`, `users/{uid}/private/paymentTotals`; callables of Task 7.
- Produces: Contract → App (`PayerPaymentRow`, `PayerRowStatus`, `PaymentTotals`, `RefundSubject`, `PendingRefund`, `RefundAccountChoice`, providers `paymentHistoryProvider(limit)` (stream, uid from `authStateProvider`), `paymentTotalsProvider`).

- [ ] **Step 1: Contract check**; ledger differences.
- [ ] **Step 2: Failing tests:** `payerRowFrom parses every status code and the refunds list`; `an unknown status → null (row skipped)`; `instant_request subject parses`; `PendingRefund parses payer and confirmBy, and null`; `Booking parses refundAccountNeeded (missing → false)`; `DisputeRefund sends {disputeId} to pendingRefund`.
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/data/payments` → fail.
- [ ] **Step 4: Implement**; `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 5: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/data/payments`; `… test/data/booking` → pass.
- [ ] **Step 6: Commit** `feat(data): payment history and refund account repositories [#141]`.

### Task 9 (#141): S22.04 Tài khoản nhận hoàn and its entry points (S05.02, S05.03, S11.04, S18.02) (was Task 6)

**Files:**
- Create: `app_flutter/lib/features/payments/refund_account_sheet.dart`, `refund_account_controller.dart`; test `test/features/payments/refund_account_sheet_test.dart`
- Modify: `lib/features/booking/cancel_sheet.dart` (after a successful customer cancel of a `bank_qr` booking → `showRefundAccountSheet(BookingRefund(id))`), `lib/features/booking/booking_detail_screen.dart` (the `refundAccountNeeded` card per `#S05.02-refund`), `lib/features/events/tickets_tab.dart` (after a refunded paid-ticket cancel of a `bank_qr` payment → `showRefundAccountSheet(TicketRefund(...))`; the registration `refundStatus == awaiting_account` compact row stays "Đang hoàn" per `#S11.04-pending`), #142's `lib/features/disputes/dispute_detail_screen.dart` (S18.02: while the dispute's refund waits, an outline small `payChooseRefundAccount` "Chọn tài khoản nhận hoàn" → `showRefundAccountSheet(DisputeRefund(id))`; Decision 5; if #142 has not merged, ledger it as a carry for #142), `lib/l10n/app_vi.arb` (S22.04 + S05.02 row keys), tests `test/features/booking/cancel_sheet_test.dart`, `booking_detail_screen_test.dart`, `test/features/events/tickets_tab_test.dart`

**Interfaces:**
- Consumes: `PaymentsRepository.pendingRefund/lookupRefundAccount/chooseRefundAccount`, `showBankPicker` and `AccountNumberFormatter` (`features/earnings/widgets/`), `VnBank`, `Booking.refundAccountNeeded`, `Booking.paymentMethod`, `showAppSheet`.
- Produces: `showRefundAccountSheet(context, ref, subject)` (`ScreenCode(ScreenCodes.refundAccount)`).

**Backend wiring:** callables `pendingRefund`, `lookupRefundAccount`, `chooseRefundAccount` (Task 7) through `FirebasePaymentsRepository`; `bookingProvider(id)` stream refreshes S05.02 when `refundAccountNeeded` flips.

**Mock parity (`#S22.04`, `#S22.04-other`, `#S05.02-refund`):** sheet header "Tài khoản nhận hoàn" + close icon (semantics `refundAccountClose`); row "Bạn được hoàn" + amount (16sp, tabular); "Tiền hoàn về tài khoản đã chuyển:"; the payer card (`bnk` short name from `VnBank`, "Vietcombank •••• 6789", holder name, check mark); primary "Hoàn về tài khoản này" (52dp); text link "Dùng tài khoản khác"; quiet line `refundAccountAutoNote` (only when `confirmBy` is set); quiet line `refundAccountWalletNote`. Other-account form (same sheet, second state): bank field with logo short name, name, full name and search icon (opens `showBankPicker`), account number field (`AccountNumberFormatter`), "Tra tên chủ tài khoản" outline small button → lookup result card (holder name + `refundAccountLookupNote`) or the red error text (`refundAccountNotFound` / `refundAccountUnsupported`), primary "Hoàn về tài khoản này" enabled only after a successful lookup, quiet `refundAccountEncrypted`. No payer: the sheet opens on the form with `refundAccountNoPayer` and no "Dùng tài khoản khác" link. S05.02 card: "Bạn được hoàn {amount}" + "Chọn tài khoản để nhận tiền hoàn." + outline small "Chọn tài khoản nhận hoàn".

- [ ] **Step 1: Failing tests:** `shows amount and the paying account "Vietcombank •••• 6789 · NGUYEN THANH HA"`; `Hoàn về tài khoản này calls chooseRefundAccount(payer), closes and shows "Đã gửi yêu cầu hoàn tiền"`; `Dùng tài khoản khác shows the form; lookup shows the returned name; confirm calls choose(candidate)`; `lookup not_found shows refundAccountNotFound; not_eligible shows refundAccountUnsupported; confirm stays disabled`; `no payer opens straight on the form with the no-payer line`; `nothing pending → no sheet`; `wallet bookings never open the sheet after cancel`; `cancel of a bank_qr booking opens the sheet after the success toast`; `S05.02 shows the refund card while refundAccountNeeded and hides it after`; `a bank_qr ticket cancelled ≥ 48 h opens the sheet`; `S18.02 shows "Chọn tài khoản nhận hoàn" while the dispute refund waits and opens the sheet for DisputeRefund`; `fits 320dp at 1.3x text`.
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/payments`, `… test/features/booking`, `… test/features/events`, `… test/features/disputes` → fail.
- [ ] **Step 3: Implement**; arb; `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze`; the four folders → pass.
- [ ] **Step 5: Commit** `feat(payments): S22.04 refund account sheet from cancel, booking detail, tickets and disputes [#141]`.

### Task 10 (#141): S22.01 Lịch sử thanh toán and its S09.02 row (was Task 7)

**Files:**
- Create: `app_flutter/lib/features/payments/payment_history_screen.dart`, `payment_history_controller.dart`; test `test/features/payments/payment_history_screen_test.dart`
- Modify: `lib/app/router.dart` (`/me/payments`), `lib/features/settings/settings_screen.dart` (the row "Lịch sử thanh toán" at the top of #205's "Thanh toán và dữ liệu" group; if #205 has not merged, create the group exactly as #205's Task 4 describes, without the privacy row), `lib/l10n/app_vi.arb` (`settingsPaymentHistory*` + S22.01 keys), `test/features/settings/settings_test.dart`

**Interfaces:**
- Consumes: `paymentHistoryProvider(limit)`, `paymentTotalsProvider`, `EarningRow`, `StatTile`/`StatTileRow`, `MoneyBreakdown`, `EmptyState`, `AsyncView`, `showRefundAccountSheet` (Task 9).
- Produces: `PaymentHistoryScreen` (`ScreenCode(ScreenCodes.paymentHistory)`).

**Backend wiring:** `FirebasePaymentsRepository.watchHistory(uid, limit)` (listener on `users/{uid}/payments` `orderBy('createdAt', descending: true).limit(limit)`), `watchTotals(uid)` (`users/{uid}/private/paymentTotals`); rules from Task 6; no new index.

**Mock parity (`#S22.01`):** AppBar back + "Lịch sử thanh toán"; `StatTileRow` with two tiles "Đang giữ" (short money) and "Đang hoàn"; meta line `paymentsHeldNote`; month groups with the first header "Các khoản" + month on the right (like S06.05's `_MonthHeader`); rows as `EarningRow` (title, meta "day · method[ · đang tìm thợ| · đã huỷ]", short amount, status badge text by `PayerRowStatus` and subject: booking "Đã chuyển cho thợ", ticket "Đã chuyển cho chủ sự kiện", platform ticket "Đã thanh toán"); tapping a row toggles a breakdown (`MoneyBreakdown`: "Đã trả", one line per refund "Hoàn về {destination} · đang xử lý|đã về", bold "Sẽ nhận lại" when a refund is in progress) and a text link "Xem buổi chụp" → `/b/:id`, "Xem vé" → tickets tab, "Xem yêu cầu Chụp ngay" (hidden until #140 adds the route); `refundAccountNeeded` rows show a small outline "Chọn tài khoản nhận hoàn" under the meta; "Xem thêm" outline when the page is full; empty state `paymentsEmptyTitle`/`paymentsEmptyBody`. S09.02: in the section "Thanh toán và dữ liệu" (`settings-group-paymentsData`, #205) the first `ListTile` "Lịch sử thanh toán" (`AppIcons.receipt`, key `settings-payment-history`).

- [ ] **Step 1: Failing tests:** `shows held and refunding totals`; `groups rows by month with "Các khoản" first`; `a held booking row reads "Đang giữ" with method "Chuyển khoản QR"`; `a released ticket reads "Đã chuyển cho chủ sự kiện"`; `an instant row reads "Chụp ngay · Quận 1" and "đang tìm thợ"`; `tapping a refunding row shows "Hoàn về ví ZaloPay · đang xử lý" and "Sẽ nhận lại"`; `a bank refund line shows "Vietcombank •••• 6789"`; `"Xem buổi chụp" opens /b/:id`; `"Xem thêm" raises the limit by 20`; `"Chọn tài khoản nhận hoàn" on a refund_account_needed row opens the S22.04 sheet for that subject`; `empty state copy`; `no text contains "cọc"`; `fits 320dp at 1.3x text`; settings: `S09.02 shows "Lịch sử thanh toán" first in the paymentsData group and opens /me/payments`.
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/payments` and `… test/features/settings` → fail.
- [ ] **Step 3: Implement**; arb; `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze`; the two folders → pass.
- [ ] **Step 5: Commit** `feat(payments): S22.01 payment history and its S09.02 row [#141]`.

### Task 11 (#141): Spec status, data model and handover ledger for payments (payments half of the old Task 9)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S22.01 and S22.04 status "✅ đã làm (#141)" with the note S22.01 "Chụp ngay hiện khi #140 ghi khoản"), `docs/superpowers/specs/data-model/domain-model.md` (payer history row, `Refund.candidate` and how this plan sets V2's `confirmBy`, `Booking.refundAccountNeeded`), `docs/superpowers/specs/data-model/relational-schema.md` (target: `payer_payment_rows` as a view over payments/refunds, refund `candidate` columns; mapping table rows), `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §5 (the 24-hour window and the no-payer case as built), `docs/legal/terms-and-help-notes.md` (new rows: refund account choice and the 24-hour default)
- Create: `docs/superpowers/handover/ledger-s22-payments.md`

- [ ] **Step 1:** Edit the docs to match the code as built (Vietnamese specs, English code names).
- [ ] **Step 2:** Ledger: shipped per task; rulings (Decisions 1–8 as built, contract differences found against V2/V1; whether #142 and V1 had merged); skipped emulator suites (rules tests for `users/{uid}/payments`; integration `payer_history.test.ts`, `refund_account.test.ts`); deploy order: (1) Firestore rules + indexes (V2's `refunds (status, confirmBy)`) before the functions; (2) functions (`onRefundWritten`, three callables, the payment-clock step); (3) app last. Carry: #140 writes `instant_request` payments (S22.01 rows); #148 owns the rest of S09.02 parity; optional follow-up: #205's money blockers may read the history rows once they exist (same kinds and amounts).
- [ ] **Step 3: Commit** `docs(spec): S22 payments status, data model and ledger [#141]`.

## Deferred

- Email delivery of the data copy (needs an email vendor; owner question 1).
- Google Play's out-of-app account-deletion request (a public web page/form); App Store's in-app path is covered by S22.02.
- Real account-name lookup and real bank refunds (the licensed intermediary, #129 Deferred); refunds stay on the fake gateway.
- Staff tools: failed refunds, manual refunds, needs_review payments (S23.02, S23.03, phase 1.5 #83).
- Instant booking payments and their S22.01 rows' backend (#140); jobs/quotes payments (#139).
- The rest of S09.02 mock parity (#148).
- Export of chat images and post images as files (the JSON lists their storage paths only).
- Remote recommender filtering of hidden profiles (description note only; the service is not wired).
- Self-hosted parity of the new collections (phase 2 #90).
