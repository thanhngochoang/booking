# S21 · Xác minh để nhận đơn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, `storage.rules` and indexes. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`). **Money and identity are fake (owner, 2026-10-07):** the fee goes through the fake gateway, identity through `FakeIdentityVerifier`, the tax-code lookup through `FakeTaxCodeLookup`; the real vendors are Deferred.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A photographer or studio who taps "Bắt đầu nhận đơn" walks four steps (phone OTP, a 99.000₫ / 299.000₫ fee on the fake rails, identity through a fake VNeID / chip-CCCD adapter, the provider rules), submits, and is approved or rejected by staff (callable + CLI) within the app's own state machine; approval gives the blue tick and opens orders in the same write, rejection explains the reason and allows one free resubmit, revocation closes orders again. Studios can then verify the business with a tax code (S21.04). Every screen works on the real adapters against the emulators.

**Architecture:** All rules live in `packages/domain` (new `verification*.ts`, `identity_verification.ts`, `business_verification.ts`, ports with in-memory stores and fakes). Functions are thin: callables + Firestore adapters + a staff CLI `npm run verifications`; the reminder runs as one more step of the existing 15-minute `bookingClock` (no new Scheduler job). Firestore: owner-readable, server-written `verifications/{uid}`; server-only `users/{uid}/private/identity`, `identity_hashes/{idHash}`, `verificationAudit/{id}`; `photographers/{uid}.verified/verifiedAt/acceptingOrders/businessVerified` written in the decision's transaction. The fee is a `payments` doc with `subjectType 'verification_fee'`, payee `platform` (never earnings, never payouts). The app gets `lib/data/verification/` (Firestore + callables + fake, `PhoneVerifier` over Firebase Auth phone linking) and `lib/features/verification/` (S21.01–S21.04), plus entry points on S06.02, S09.02 and the owner view of S03.01.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 callables, `node --test`), Firestore/Storage rules; Flutter, Riverpod 3, go_router, `firebase_auth` phone provider (Auth emulator), `cloud_functions`, existing core widgets.

**Spec:** `docs/superpowers/specs/2026-10-06-identity-verification-design.md` (all; §3 state, §4 flow, §5 business, §6 port, §7 gates, §10 tests); main spec `2026-10-01-remaining-screens.md` §2 (S21 rows), §3i.4 (S21.01 phone), §3d.1 (tick); `docs/legal/terms-and-help-notes.md` V1–V5, P2, P3, P7, P13; mock `docs/design/ui-mock.html` `#S21.02`, `#S21.02-fee`, `#S21.03`, `#S21.03-nfc`, `#S21.02-pending`, `#S21.02-rejected`, `#S21.04`, `#S06.02`, `#S03.01-new`, `#S09.02`; cost rules `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §6, §14; handover `docs/superpowers/handover/ledger-s03-orders-closed.md` (`ProviderOrderGate`, `acceptsOrders`, `acceptingOrders`).

**Issue:** #135 (S21 · Xác minh để nhận đơn). Branch `plan/135-s21-verification`, PR into `develop` titled `feat(verify): S21 paid verification to start receiving orders [#135]`.

**Execution wave:** 3 (cross-plan review 2026-10-07). **Blocked by:** #129 (S04, wave 1, hard: the fee runs on its payment model through the Decision 22 extension point); #148 (S09, wave 1: `verifyStartReadyProvider`, settings order); #134 (S06, wave 2: `OtpCodeField`, the S06.02 closed state and its `workClosed*` keys); #147 (S10, wave 1: `ImagePurpose.document`, `jpegUpTo`) for the S21.04 photo; #138 (S17, wave 1: the verification notification hooks). All land in earlier waves; where one has not, create exactly what this plan quotes from it and ledger it. **Owns (others consume):** `lib/core/app_config.dart` (`supportEmail`, `supportEmailUri()`; #142 consumes, cross-plan review finding 3), the error code `rate_limited` (#136, #151 reuse it), `vnDayKey`, the payment subject `verification_fee`.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. Each task's Step 1 re-checks its part; adapt and ledger any difference; if a named member does not exist, stop and report.

- Domain (`packages/domain/src`): `acceptsOrders`, `acceptingOrdersPatch` (`provider_orders.ts`); `ProviderOrderGate` (`booking_ports.ts`); from #129 (S04, merged in wave 1): `PaymentGateway {createPayment, queryPayment, refund, verifyWebhook}`, `PaymentInstructions`, `PaymentMethod`, `parsePaymentMethod`, `PAYMENT_EXPIRY_MINUTES` (`payments.ts`, `payment_ports.ts`), `newSubjectPayment`, `issuePaymentInstructions`, `instructionsOf`, `checkSubjectPayments` (`create_payment.ts`), `SubjectSettler`, `SettlementDeps.subjects`, `applyTransfer`, `expireUnpaid`, `TransferDecision`, `StoredBankAccount` (`payment_settlement.ts`), `sendRefundOnce`, `mergeRefundOutcome` (`refunds.ts`), the unified `confirmFakePayment({paymentId})`, `createPayment` (refuses `not_accepting_orders`) and `settleBookingTransfer` (refunds a paid draft of a provider who stopped accepting orders, #129 Decision 9); `Payment {subjectType, escrowStatus, payeeId, idempotencyKey…}`, `applyRefundToPayment`, `LEDGER_ENTRY_TYPES` incl. `payment_received`, `fee_charged` (`escrow.ts`); `PLATFORM_PAYEE = 'platform'`, `isPayoutPayable` excludes it (`payout.ts`); `ERROR_CODES` (`errors.ts`, 14 codes incl. `not_accepting_orders`); `PROVIDER_TYPES`, `providerTypeOf` (`provider_type.ts`); `NOTIFICATION_TYPES`, `NotificationContent`, `renderNotification`, `notify`, `NotifyDeps` (`notification*.ts`); `isVnE164` (`phone.ts`); `foldVietnamese` (`event_hashtag.ts`); `newUlid`, `isId` (`ids.ts`); `FakePaymentGateway`; `Clock`, `IdGenerator` (`ports.ts`). Test world `test/support/booking_world.ts` (`ControllableClock`, `SequentialIdGen`, `providers` map). No verification module exists.
- Functions (`app_flutter/firebase/functions/src`): `CALLABLE_OPTIONS`, `PAYMENT_CALLABLE_OPTIONS`, `SCHEDULE_OPTIONS`, `REGION = 'asia-southeast1'` (`config.ts`); `assertFakePaymentsAllowed`, `fakePaymentsAllowed` (`infra/fake_payments.ts`, done; reuse, do not re-plan); `toHttpsError` + `TRANSPORT_CODE` (`callables/errors.ts`); staff claim read as `request.auth?.token?.staffRole === 'admin'` (`callables/award.ts`); `FirestoreProviderOrderGate`, `liveBookingDeps` (`infra/booking_readers.ts`, `infra/live_booking.ts`); from #129: `liveSettlementDeps()` (`infra/live_payments.ts`, gains `subjects.verification_fee`), the live gateway of `infra/fake_gateway.ts`; `handleBookingClock(deps, reminders)` (`scheduled/booking_clock.ts`); `purgeAwardProofs` daily schedule (`index.ts:273`, `scheduled/award_purge.ts`); `liveNotifyDeps()` (`infra/live_notification.ts`); staff CLI pattern `tools/awards.ts` (`npm run awards`, `--actor <uid>` must hold the admin claim); `db()` (`infra/admin.ts`); seed `seed/fixtures.ts` (An verified, Bình `verified: false`, Cúc studio, admin `seed-staff-admin`), `seed/README.md`.
- Rules (`app_flutter/firebase/firestore.rules`): `match /users/{uid}/private/{docId}` (owner reads **every** doc today), `validContact(uid)` (client keeps `phoneVerified` unchanged, forces false on a changed number), `verifiedUntouched()`, `photographerServerFieldsUntouched()` (`… 'acceptingOrders'`), `match /payments/{paymentId}` (closed), `awardAudit` (closed), catch-all deny. Storage (`storage.rules`): `awardProofs/{uid}/{awardId}/{file}` create-only owner image ≤ 10 MB pattern.
- App data: `UserContact.phoneVerified` + `FirestoreUserContactRepository.save` (resets `phoneVerified` on a new number) and `currentContactProvider` (`lib/data/user/`); `PhotographerIntro` + `myIntroProvider` (`lib/data/photographer/`; owner listener on `photographers/{uid}`); `PhotographerSummary.verified/acceptingOrders/providerType` (`lib/data/content/photographer_summary.dart`); `providerMarkOf({type, verified})` (`lib/core/widgets/provider_mark.dart`); `PayMethod` (`lib/core/payments.dart`, #129's: `bankQr`/`momo`/`zaloPay`), `PayMethodList` (`lib/core/widgets/pay_method_picker.dart`), `PaymentInstructions` + `paymentInstructionsFrom` (`lib/data/payments/payment_instructions.dart`), `PaymentsRepository.confirmFake` (`lib/data/payments/payments_repository.dart`), `PaySubject`/`openPayment`/`PaymentScreen` (`lib/features/payment/`, S04.04) — all #129's; `realPaymentsProvider` (`lib/data/booking/payments_mode.dart`); `externalLauncherProvider` (`lib/data/contact/contact_providers.dart`); `MediaUploader.upload(image, storagePath:)`, `ImagePickerPort` (`lib/data/media/`); `authRepositoryProvider`, `authStateProvider`, `staffRoleProvider` (`lib/data/auth/`); `functionsRegion` (`lib/data/backend/backend_config.dart`); the support email pair in `lib/features/events/event_links.dart` (`String.fromEnvironment('SUPPORT_EMAIL')`, used by `event_info_tab.dart`), which this plan moves to `lib/core/app_config.dart`; `OtpCodeField` (core, #134).
- App features/core: `WorkEmptyState` + `workEmptyInputsProvider` (`features/work/work_empty.dart`), `SettingsScreen` (`features/settings/settings_screen.dart`, `_PhoneTile`, `_ProviderTypeTile`), `ProfileHeader(profile, owner)` + `_OrdersClosedNote` (`features/photographer_profile/widgets/profile_header.dart`), S04.04 `PaymentScreen` + `FakeWalletSheet` + `FakeTransferSheet` (#129); core `AppButton.primary/outline/text/danger`, `StepProgress`, `PhoneField`, `CountdownText`, `EmptyState`, `AsyncView`, `showAppSheet`, `showConfirmSheet`, `ScreenCode`, `AppIcons` (`lock`, `badge`, `verified`, `wallet`, `info`, `check`; add `verifiedUser`, `qrCode`, `photoCamera`, `person`, `photoLibrary`, `search` if missing), `formatMoney`; `ScreenCodes.verifyPhone 'S21.01'`, `verifyPhotographer 'S21.02'`, `verifyIdentity 'S21.03'`, `verifyBusiness 'S21.04'` (already in `lib/core/screen_codes.dart`); `lib/app/router.dart`.

## Global Constraints

- CLAUDE.md: business rules only in `packages/domain` (no Firebase or Node imports; `purity.test.ts`); Functions are thin adapters, region `asia-southeast1`; `cloud_firestore`/`firebase_*` only in `lib/data/**`, `firebase_options.dart`, `main.dart`.
- Imports `package:photobooking/...` only; features import `core/core.dart`, never files inside `core/`.
- Tokens: `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; never raw hex or numbers; 60‑30‑10 colour rule.
- Strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; the exact keys and Vietnamese text are in Contract §L10n.
- One `AppButton.primary` per screen; decline/cancel is a red button inside a confirmation sheet, never the gradient button.
- Mock is the authority for layout, order, copy and states; the specs for behaviour. Screens without a mock get their frame in Task 1 first.
- Conventions (`docs/superpowers/specs/data-model/README.md`): ULID/opaque ids, UTC instants (ISO strings in the domain, `Timestamp` in Firestore), integer VND, string enum codes, no Firebase types in the domain.
- Money rules stay (CLAUDE.md): only identity-verified, staff-approved providers receive orders; the fee is platform revenue on the fake rails; contact rules untouched.
- `ProviderOrderGate` (`acceptsOrders` = `verified && onboardingComplete`, error `not_accepting_orders`, Functions `failed-precondition`) is the only order gate; #129 applies it in `createPayment` and `settleBookingTransfer` (its Decision 9); this plan adds no gate code (Decision 15).
- Payments: #129 owns the payment model, callables and refund rules; the fee is one more payment subject through its Decision 22 extension point (`newSubjectPayment`, `issuePaymentInstructions`, a `SubjectSettler`, S04.04 with a `VerificationFeePay` subject); no `payUrl`-only flow, no own fake confirm, no own refund re-send.
- Notifications: #138 owns types, copy, targets and dedupe keys; this plan calls its verification hooks (Decision 22) and adds no copy.
- Commits: Conventional Commits with `[#135]` in the subject; footer exactly `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Flutter env (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Flutter tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time, never the whole suite in one command; bounded pumps (`pump(Duration)`), no endless animation or periodic timer left running in widget tests.
- Domain: `(cd packages/domain && npm test && npm run lint)`. Functions: `(cd app_flutter/firebase/functions && npm test && npm run build)`. Rules tests and Functions integration tests are written, not run (CI runs them).

## Decisions

1. **Where the state lives (spec §3 path changed).** The verification state is the top-level `verifications/{uid}` (owner reads, server writes), not `users/{uid}/private/verification`: staff need queue queries (`status == 'submitted'`, `business.status == 'submitted'`, reminders), and a collection-group query over `private` would mix `contact`, `inbox`, `business` docs that share field names. The identity stays at the spec path `users/{uid}/private/identity` (server-only). The business sub-record lives in `verifications/{uid}.business` (tax code and company name are public registry data). Task 9 updates spec §3.
2. **Steps and order.** Status `not_started → in_progress → submitted → approved | rejected`; `approved → revoked`; `rejected → submitted` (resubmit) or `rejected → in_progress` (paid resubmit). Steps can be done in any order except **identity needs the fee paid** (the vendor check costs money; mock "Trả xong tự sang bước danh tính"). "Tiếp tục" opens the first undone step in the order phone → fee → identity → rules. `submitVerification` needs all four.
3. **Phone step = `users/{uid}/private/contact.phoneVerified == true`.** S21.01 links the number to the Firebase Auth account (`linkWithCredential`, or `updatePhoneNumber` when a phone is already linked), then `confirmPhoneVerified` compares the Auth `phoneNumber` (Admin SDK) with `contact.phone` and sets `phoneVerified: true` server-side. A later number change resets it (existing repository + rule), so the step shows undone again; an approved provider stays approved (the phone is a contact detail, not identity).
4. **Fee payment on #129's model (cross-plan review finding 16).** The fee is the payment subject `verification_fee` plugged into #129's Decision 22 extension point: `startVerificationFee({method, renew?})` builds the payment with `newSubjectPayment({subjectType: 'verification_fee', subjectId: uid, payerId: uid, payeeId: PLATFORM_PAYEE, amount: 99_000 | 299_000 by kind, method, provider: gateway.provider, idempotencyKey: 'vfee_{uid}_{feeAttempt}_{method}', now, expiresAt: now + PAYMENT_EXPIRY_MINUTES})` and returns #129's `PaymentInstructions` from `issuePaymentInstructions` (bank QR → VietQR on S04.04; wallets → `payUrl`); a second tap with the same method reuses the live payment (`instructionsOf`), `renew` expires it and issues a new code, like #129's "Tạo QR mới". Money arrives only through #129's settlement: `VerificationFeeSettler` (a `SubjectSettler`, `verification_fee.ts`) applies the transfer inside the verification transaction with `applyTransfer`; `paid` → the payment's `escrowStatus` becomes `released` (platform revenue, never held; `PLATFORM_PAYEE` keeps it out of earnings and payouts), a `fee_charged` ledger entry to `platform_revenue` is added next to #129's `payment_received`, and the fee step is recorded. A paid fee for an attempt whose fee is already recorded (two methods, retry) is refunded 100% as a policy refund `duplicate_verification_fee`; over/short/late transfers follow #129's §3.3 table (excess refunds). The settler's `expire` uses `expireUnpaid`, its `dispatchRefund` uses `sendRefundOnce` + `mergeRefundOutcome` (refund id = idempotency key; re-sends are #129's `reconcilePayments`, never this plan's). The fake confirmation is #129's unified `confirmFakePayment({paymentId})` (`PaymentsRepository.confirmFake`); "Kiểm tra" on resume is `checkVerificationFee`, which runs #129's `checkSubjectPayments` over the attempt's `created` payments. `liveSettlementDeps().subjects.verification_fee` registers the settler, so webhooks and reconciliation reach it.
5. **Kind and fee.** `kind = 'studio'` when `providerType == 'studio'`, else `'individual'` (artists pay the individual fee), fixed when the fee is paid. Changing provider type later charges nothing more (Needs the owner 2).
6. **Identity.** Port `IdentityVerifier { start, result }` (spec §6). The only adapter here is `FakeIdentityVerifier`: on the emulator/dev (`fakePaymentsAllowed()`), `result` returns a deterministic test identity: an override from server-only `fake_identities/{uid}` (`{legalName, dob, gender, idNumber, passed}`, written by the seed or the Emulator UI) or else `legalName = upper(foldVietnamese(displayName))` (fallback `NGUOI DUNG THU`), `dob '1995-01-01'`, `gender null`, `idNumber` = `'0'` + 11 digits from an FNV-1a hash of the uid. Elsewhere the callables answer `not_eligible` (no provider yet). The app's fake VNeID/NFC sheets are shown only when `identityModeProvider` is false (`--dart-define=REAL_IDENTITY` unset).
7. **Identity storage.** `IdentityVault { hashId, encryptId }` port. The shipped `devIdentityVault` (Functions) uses HMAC-SHA256 and AES-256-GCM with a fixed, labelled dev key and refuses to run unless `fakePaymentsAllowed()`; the KMS-backed vault is Deferred (no Secret Manager in this plan). `identity_hashes/{idHash}` is created in the same transaction as `private/identity`; an existing hash of another uid → `identity_in_use`.
8. **Identity outcomes.** Under 18 on the VN calendar day → `underage`; duplicate → `identity_in_use` (an audit row names the other uid for staff); vendor "not passed" → identity step `failed` (`provider_failed`), use case answers `not_eligible`. Every failure counts toward **3 attempts per VN day**, the 4th start answers `rate_limited` until the next VN day. The failure is written first and the error thrown after the transaction commits (a throw inside would roll the attempt back).
9. **What the owner sees.** The verification doc stores only `maskedName` (`NGUYỄN M** T**`: first word whole, each later word first letter + `**`). The mock `#S21.02-pending` line "VNeID · NGUYEN MINH TRI" becomes "VNeID · NGUYỄN M** T**" (spec §4 privacy wins over the mock copy; Task 1 updates the mock).
10. **Rules step.** Five lines summarise P2, P3, P7, P13 and V3 of `terms-and-help-notes.md`; `rules.version = PROVIDER_RULES_VERSION = '2026-10-06'`. The "full terms" link is not shown: the terms text does not exist yet (Deferred); the mock frame has no link.
11. **Staff decisions.** One callable `reviewVerification({uid, target: 'identity' | 'business', action, reason?, note?})`, admin claim only, and the CLI `npm run verifications -- list | show <uid> | approve <uid> | reject <uid> <reason> ["note"] | revoke <uid> "note" | business-approve <uid> | business-reject <uid> <reason> ["note"] --actor <uid>` over the same use case. Every decision writes `verificationAudit/{id}` `{uid, target, action, reason, note, actorId, at}`. The S23.04 screen is phase 1.5 (#83).
12. **Approve writes the public flags in one transaction:** `verifications/{uid}` → `approved` and `photographers/{uid}` `{verified: true, verifiedAt, acceptingOrders: acceptsOrders({verified: true, onboardingComplete})}` together (ledger request from #133); the `onPhotographerWrite` trigger then finds the flag equal and writes nothing. Revoke writes `{verified: false, acceptingOrders: false}` the same way; running bookings are not touched (spec §4, S18 handles them).
13. **Rejection reasons and what reopens** (mock `#S21.02-rejected`): `fake_avatar` → a "Ảnh đại diện" fix row (→ `/settings/profile`); `stolen_portfolio` → a "Portfolio" fix row (→ `/u/{uid}`); `identity_mismatch` → the identity step is cleared and must pass again; `other` → staff note shown, plain resubmit; `duplicate_account` and `underage` are final (no resubmit, support line). `freeResubmitsLeft` starts at 1; at 0, `resubmitVerification` moves to `in_progress`, clears the fee step and bumps `feeAttempt` (pay again, then "Gửi duyệt").
14. **Revoked is terminal in the app** (S21.02 shows the revoked state and the support email); staff can only approve a `submitted` record. Re-instatement is an owner question (Needs the owner 3).
15. **Gate re-checks are #129's (cross-plan review finding 17).** `createPayment` refuses a provider who no longer accepts orders (`not_accepting_orders`), and `settleBookingTransfer` is the single place that turns a late transfer for such a draft into a 100% refund (`provider_not_accepting`, booking left `draft`, the sweep frees the day): #129 Decision 9. This plan writes no gate code; Task 2 only pins, with #129's booking world, that a revoke followed by a transfer is refunded.
16. **Studio business (S21.04).** Opens only for `providerType == 'studio'` with `verified == true`. Tax code: 10 digits (company), 10 digits + `-` + 3 digits (branch, company) or 12 digits (household: the owner's personal id since 01/07/2025). Port `TaxCodeLookup`; shipped `FakeTaxCodeLookup` (emulator/dev only): codes ending `0000` → `inactive`; 12 digits → household named `HỘ KINH DOANH {legalName}` where available; otherwise company `CÔNG TY TNHH STUDIO THỬ {last4}`, address `12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh`, `active`. Inactive → `not_eligible`. Household: `vault.hashId(taxCode) == identity.idHash` → approved at once (`businessVerified: true`), else rejected `representative_mismatch`. Company: a registration photo is required (`businessDocs/{uid}/{ulid}.jpg`), status `submitted`, staff decide. Real lookup (`api.vietqr.io/v2/business/{mst}`, needs outbound network on Blaze) is Deferred.
17. **Studio mark.** `providerMarkOf` gains `businessVerified`: a studio shows the blue tick once `verified`, the gold Studio seal only once `businessVerified` (spec V4/V5); artists keep the gold tick; individuals unchanged.
18. **Reminder.** One push `verification_reminder` 24 h after the last change of an `in_progress` record (`nudgedAt` makes it once). It runs as a new step of `bookingClock` (15 min, existing job; spec "không nhắc thêm, không email"). The S06.01 dismissible banner of spec §4 is not built: an unverified provider never has work, so S06.02 "Mở nhận đơn" is what they see (Task 7).
19. **Overdue staff queue (> 24 h)**: the CLI `list` marks rows older than `REVIEW_SLA_HOURS` with `!` (no job, no push to staff yet).
20. **Business photos** are purged 30 days after the decision by a second step of the existing daily `purgeAwardProofs` schedule (no new job). Selfie and chip data are never stored (fake or real).
21. **Customer OTP at booking (S04.05, spec §3i.4)** is not added: SMS cost (§13.1 of the cost spec) and the owner's 2026-10-07 money ruling; S21.01 is used for providers only now (Needs the owner 1).
22. **Notifications through #138's hooks** (one owner for types, copy, targets and dedupe keys; this plan is the only emitter). #138's catalogue holds the six types with this plan's copy (category `booking`, tab `system`; `verification_approved`, `verification_rejected`, `verification_revoked`, `business_verified`, `business_rejected` critical, `verification_reminder` not; targets `/verify/start` and `/verify/business`, allowlisted by #138). `verificationNotices(before, after)` is a pure decider returning which hook to call; `notifyVerificationChange(notify, change)` calls #138's `notifyVerificationDecision` / `notifyBusinessDecision` with it, and `sendVerificationNudges` calls `notifyVerificationReminder`. The callable adapter (and the CLI) calls `notifyVerificationChange` after the use case commits; no new trigger.
23. **Self-hosted parity:** none; `services/api` gets no migration (no booking routes there, same as plans 10c and #133). `data-model/*.md` are updated as the migration target (Task 9).

## Needs the owner

1. **OTP for customers at booking (S04.05).** Default: not now; only providers verify their phone (S21.01). Customer SMS at 10,000 MAU is the largest cost line of the cost spec.
2. **Provider type changed after paying the individual fee.** Default: no top-up; the kind is fixed when the fee is paid.
3. **Reinstating a revoked provider.** Default: terminal in the app; support handles it outside, staff tool later (#83).
4. **Phone change after approval.** Default: verification stays approved; the phone step simply shows undone until re-verified, nothing else changes.

## Contract

### Data model

`verifications/{uid}` (owner read, server write; ISO strings in the domain, `Timestamp` in Firestore):

| Field | Type / codes |
|---|---|
| `uid`, `kind` | string; `individual` \| `studio` |
| `status` | `not_started` \| `in_progress` \| `submitted` \| `approved` \| `rejected` \| `revoked` |
| `steps.phone` | `{doneAt}` \| null (mirror of `contact.phoneVerified`, set by `confirmPhoneVerified`) |
| `steps.fee` | `{paymentId, amount, paidAt}` \| null |
| `steps.identity` | `{method: vneid \| nfc, checkedAt, result: passed \| failed, failure: underage \| identity_in_use \| provider_failed \| null, maskedName \| null}` \| null |
| `steps.rules` | `{acceptedAt, version}` \| null |
| `identitySession` | `{id, method, startedAt}` \| null |
| `identityAttempts` | `{dayKey: 'yyyy-MM-dd' (VN), count}` |
| `feeAttempt` | int ≥ 1 |
| `submittedAt`, `decidedAt`, `decidedBy` | instant \| null; staff uid \| null |
| `rejectReason` | `{code: fake_avatar \| stolen_portfolio \| identity_mismatch \| duplicate_account \| underage \| other, text \| null}` \| null |
| `freeResubmitsLeft` | int (starts 1) |
| `nudgedAt` | instant \| null |
| `business` | null \| `{status: submitted \| approved \| rejected, kind: company \| household, taxCode, name, address, registryStatus: active \| inactive, docPath \| null, representativeMatched: bool, submittedAt, decidedAt \| null, decidedBy \| null, rejectReason: {code: inactive \| representative_mismatch \| doc_unreadable \| other, text \| null} \| null, purgeAfter \| null}` |
| `version`, `createdAt`, `updatedAt` | |

`users/{uid}/private/identity` (server only; the owner rule excludes this doc; #134's payout name match reads `legalName` server-side through its `VerifiedNameReader`, and its seed writes a partial doc for An — keep `legalName` as the field name): `legalName`, `dob` (`yyyy-MM-dd`), `gender` (`male` \| `female` \| null), `idNumberEnc`, `idHash`, `method`, `provider` (`fake` now), `providerRef`, `verifiedAt`. No selfie, no chip data. `identity_hashes/{idHash}` → `{uid, createdAt}` (server only). `verificationAudit/{id}` (server only). `fake_identities/{uid}` (server only, emulator/dev). `photographers/{uid}` server fields: `verified`, `verifiedAt`, `acceptingOrders`, `businessVerified`. `users/{uid}/private/contact.phoneVerified` (server sets true). `payments/{id}` with `subjectType 'verification_fee'`. Storage `businessDocs/{uid}/{file}`.

### Domain (`packages/domain/src`)

```ts
// verification.ts
export const VERIFICATION_STATUSES = ['not_started', 'in_progress', 'submitted', 'approved', 'rejected', 'revoked'] as const;
export type VerificationStatus = (typeof VERIFICATION_STATUSES)[number];
export type VerificationKind = 'individual' | 'studio';
export type VerificationStep = 'phone' | 'fee' | 'identity' | 'rules';
export type IdentityMethod = 'vneid' | 'nfc';
export const VERIFICATION_FEE_VND: Readonly<Record<VerificationKind, number>> = { individual: 99_000, studio: 299_000 };
export const FREE_RESUBMITS = 1, IDENTITY_ATTEMPTS_PER_DAY = 3, MIN_PROVIDER_AGE_YEARS = 18,
  REVIEW_SLA_HOURS = 24, VERIFICATION_NUDGE_AFTER_HOURS = 24, BUSINESS_DOC_RETENTION_DAYS = 30;
export const PROVIDER_RULES_VERSION = '2026-10-06';
export const REJECT_REASONS = ['fake_avatar', 'stolen_portfolio', 'identity_mismatch', 'duplicate_account', 'underage', 'other'] as const;
export const RESUBMITTABLE_REASONS = ['fake_avatar', 'stolen_portfolio', 'identity_mismatch', 'other'] as const;
export const BUSINESS_REJECT_REASONS = ['inactive', 'representative_mismatch', 'doc_unreadable', 'other'] as const;
export interface VerificationRecord { /* fields of the table above */ }
export interface IdentityRecord { legalName: string; dob: string; gender: 'male' | 'female' | null; idNumberEnc: string;
  idHash: string; method: IdentityMethod; provider: string; providerRef: string; verifiedAt: string }
export function verificationKindOf(t: ProviderType): VerificationKind;
export function feeFor(kind: VerificationKind): number;
export function emptyVerification(uid: string, kind: VerificationKind, now: Date): VerificationRecord;
export function stepDone(r: VerificationRecord, s: VerificationStep, phoneVerified: boolean): boolean;
export function nextStep(r: VerificationRecord, phoneVerified: boolean): VerificationStep | null; // phone, fee, identity, rules
export function stepsLeft(r: VerificationRecord, phoneVerified: boolean): number;
export function ageOn(dob: string, now: Date): number;          // whole years on the VN calendar day
export function maskLegalName(name: string): string;            // 'NGUYỄN MINH TRÍ' → 'NGUYỄN M** T**'
export function vnDayKey(now: Date): string;
export function identityAttemptsLeft(r: VerificationRecord, now: Date): number;

// verification_ports.ts
export interface ProviderVerificationView { providerType: ProviderType; onboardingComplete: boolean; verified: boolean; businessVerified: boolean }
export interface VerificationAuditEntry { id: string; uid: string; target: 'identity' | 'business'; action: string;
  reason: string | null; note: string | null; actorId: string | null; otherUid?: string; at: string }
export interface VerificationTx {
  getVerification(uid: string): Promise<VerificationRecord | null>;
  getProvider(uid: string): Promise<ProviderVerificationView | null>;   // photographers/{uid}; null = not a provider
  getContact(uid: string): Promise<{ phone: string | null; phoneVerified: boolean }>;
  getPayment(id: string): Promise<Payment | null>;
  getPaymentByIdempotencyKey(key: string): Promise<Payment | null>;
  getRefund(id: string): Promise<Refund | null>;                       // VerificationFeeSettler.dispatchRefund
  putRefund(r: Refund): void;
  getIdentity(uid: string): Promise<IdentityRecord | null>;
  identityOwner(idHash: string): Promise<string | null>;
  putVerification(r: VerificationRecord): void;
  putPayment(p: Payment): void; addLedgerEntry(e: LedgerEntry): void; addRefund(r: Refund): void;
  setProviderFlags(uid: string, patch: { verified?: boolean; verifiedAt?: string | null; acceptingOrders?: boolean; businessVerified?: boolean }): void;
  setPhoneVerified(uid: string): void;
  putIdentity(uid: string, r: IdentityRecord): void;
  putIdentityHash(idHash: string, uid: string): void;
  addAudit(e: VerificationAuditEntry): void;
}
export interface VerificationStore {
  runTransaction<T>(fn: (tx: VerificationTx) => Promise<T>): Promise<T>;
  dueForNudge(cutoff: Date, limit: number): Promise<VerificationRecord[]>;   // in_progress, updatedAt <= cutoff, nudgedAt null
  queue(target: 'identity' | 'business', limit: number): Promise<VerificationRecord[]>; // submitted, oldest first (CLI)
}
export interface AuthPhoneReader { verifiedPhoneOf(uid: string): Promise<string | null> }  // Auth user phoneNumber (E.164)
export interface IdentityResult { passed: boolean; legalName: string; dob: string; gender: 'male' | 'female' | null;
  idNumber: string; provider: string; providerRef: string }
export interface IdentityVerifier {
  start(uid: string, method: IdentityMethod): Promise<{ sessionId: string; redirectUrl: string | null }>;
  result(uid: string, sessionId: string): Promise<IdentityResult>;
}
export interface IdentityVault { hashId(idNumber: string): Promise<string>; encryptId(idNumber: string): Promise<string> }
export interface TaxCodeInfo { name: string; address: string; status: 'active' | 'inactive'; kind: 'company' | 'household' }
export interface TaxCodeLookup { lookup(taxCode: string): Promise<TaxCodeInfo | null> }
export interface VerificationDeps {
  readonly store: VerificationStore; readonly authPhones: AuthPhoneReader;
  readonly identity: IdentityVerifier | null; readonly vault: IdentityVault | null; readonly taxCodes: TaxCodeLookup | null;
  readonly gateway: PaymentGateway; readonly clock: Clock; readonly ids: IdGenerator;
}
export interface StaffCaller { readonly uid: string; readonly isAdmin: boolean }

// verification_use_cases.ts — every use case returns {before, after} records for notifications unless noted
export function confirmPhoneVerified(deps: VerificationDeps, uid: string): Promise<VerificationChange>;
export function startVerificationFee(deps: VerificationDeps, uid: string, raw: unknown /* {method: 'bank_qr'|'momo'|'zalopay', renew?: boolean} */):
  Promise<PaymentInstructions>;                                             // #129's type; Decision 4
/** The created payments of the current fee attempt (for checkSubjectPayments). */
export function verificationFeePayments(deps: VerificationDeps, uid: string): Promise<readonly Payment[]>;
// verification_fee.ts — the verification_fee subject of #129's Decision 22
export class VerificationFeeSettler implements SubjectSettler {   // settle / expire / dispatchRefund / statusOf over VerificationStore
  constructor(deps: VerificationDeps, cipher: AccountCipher);
}
export function acceptVerificationRules(deps: VerificationDeps, uid: string, raw: unknown /* {version} */): Promise<VerificationChange>;
export function submitVerification(deps: VerificationDeps, uid: string): Promise<VerificationChange>;
export function resubmitVerification(deps: VerificationDeps, uid: string): Promise<VerificationChange>;
export function reviewVerification(deps: VerificationDeps, staff: StaffCaller, raw: unknown
  /* {uid, target?: 'identity'|'business', action: 'approve'|'reject'|'revoke', reason?, note?} */): Promise<VerificationChange>;
export function sendVerificationNudges(deps: VerificationDeps, notify: NotifyDeps): Promise<number>;
export interface VerificationChange { readonly before: VerificationRecord | null; readonly after: VerificationRecord }
export type VerificationNotice =
  | { hook: 'decision'; outcome: 'approved' | 'rejected' | 'revoked'; decidedAt: string }
  | { hook: 'business'; outcome: 'verified' | 'rejected'; decidedAt: string };
export function verificationNotices(before: VerificationRecord | null, after: VerificationRecord): VerificationNotice[]; // pure decider
export function notifyVerificationChange(notify: NotifyDeps, change: VerificationChange): Promise<void>; // calls the #138 hooks below
// consumed from #138 (packages/domain/src/notification_hooks.ts; copy, targets and dedupe keys are #138's;
// if #138 has not merged, create these three hooks and the six catalogue rows exactly as S17's Contract lists them)
export function notifyVerificationDecision(deps: NotifyDeps, e: { uid: string; outcome: 'approved' | 'rejected' | 'revoked'; decidedAt: string }): Promise<NotifyResult>;
export function notifyBusinessDecision(deps: NotifyDeps, e: { uid: string; outcome: 'verified' | 'rejected'; decidedAt: string }): Promise<NotifyResult>;
export function notifyVerificationReminder(deps: NotifyDeps, e: { uid: string; stepsLeft: number; since: string }): Promise<NotifyResult>;
// identity_verification.ts
export function startIdentityVerification(deps: VerificationDeps, uid: string, raw: unknown /* {method} */):
  Promise<{ sessionId: string; redirectUrl: string | null }>;
export function completeIdentityVerification(deps: VerificationDeps, uid: string, raw: unknown /* {sessionId} */):
  Promise<{ result: 'passed'; maskedName: string }>;
// business_verification.ts
export function isTaxCode(s: unknown): s is string;   // ^\d{10}(-\d{3})?$ or ^\d{12}$
export function lookupTaxCode(deps: VerificationDeps, uid: string, raw: unknown /* {taxCode} */): Promise<TaxCodeInfo>;
export function submitBusinessVerification(deps: VerificationDeps, uid: string, raw: unknown /* {taxCode, docPath?} */):
  Promise<VerificationChange>;
// fake_identity_verifier.ts, fake_tax_code_lookup.ts, memory_verification_store.ts (+ MemoryIdentityVault in test support)
export class FakeIdentityVerifier implements IdentityVerifier {
  constructor(source: (uid: string) => Promise<Partial<IdentityResult> & { displayName?: string } | null>, ids: IdGenerator);
}
export function fakeIdNumberOf(uid: string): string;   // '0' + 11 digits, FNV-1a
export class FakeTaxCodeLookup implements TaxCodeLookup {}
// errors.ts ERROR_CODES gains 'identity_in_use', 'underage', 'rate_limited'
// escrow.ts PaymentSubject gains 'verification_fee' (#129 Decision 22)
// no gate code (Decision 15) and no notification copy (#138, Decision 22)
```

Use-case refusals: not a provider (`getProvider` null) → `permission_denied`; wrong status or missing prerequisite → `not_eligible`; bad input → `invalid_argument`; already done (fee paid, identity passed, same session used) → `conflict`; unknown session/payment → `not_found`; `reviewVerification` non-admin → `permission_denied`, wrong state → `conflict`, `reject` reason not in the list or `other`/`revoke` note outside 5–500 characters → `invalid_argument`.

### Callables (`asia-southeast1`, `CALLABLE_OPTIONS`; fee ones `PAYMENT_CALLABLE_OPTIONS`)

| Name | Input → output | Errors (domain code) |
|---|---|---|
| `confirmPhoneVerified` | `{}` → `{phoneVerified: true}` | `phone_required` (no contact phone), `conflict` (Auth phone ≠ contact phone), `permission_denied` |
| `startVerificationFee` (`PAYMENT_CALLABLE_OPTIONS`) | `{method: 'bank_qr'\|'momo'\|'zalopay', renew?: bool}` → `PaymentInstructions` (#129) | `not_eligible` (fee already paid; payments off), `invalid_argument`, `permission_denied` |
| `checkVerificationFee` | `{}` → `{paid, instructions: PaymentInstructions\|null}` | `not_found` |
| (fake confirmation) | #129's `confirmFakePayment({paymentId})` | — |
| `startIdentityVerification` | `{method: 'vneid'\|'nfc'}` → `{sessionId, redirectUrl: string\|null}` | `not_eligible`, `conflict`, `rate_limited` |
| `completeIdentityVerification` | `{sessionId}` → `{result: 'passed', maskedName}` | `underage`, `identity_in_use`, `rate_limited`, `not_eligible`, `not_found` |
| `acceptVerificationRules` | `{version}` → `{}` | `invalid_argument`, `not_eligible` |
| `submitVerification` | `{}` → `{status: 'submitted'}` | `not_eligible` |
| `resubmitVerification` | `{}` → `{status: 'submitted'\|'in_progress'}` | `not_eligible` |
| `lookupTaxCode` | `{taxCode}` → `{name, address, status, kind}` | `invalid_argument`, `not_found`, `not_eligible` |
| `submitBusinessVerification` | `{taxCode, docPath?}` → `{status: 'approved'\|'submitted'\|'rejected'}` | `not_eligible`, `invalid_argument` |
| `reviewVerification` | `{uid, target?, action, reason?, note?}` → `{status}` | `permission_denied`, `conflict`, `invalid_argument`, `not_found` |

`TRANSPORT_CODE`: `identity_in_use: 'already-exists'`, `underage: 'failed-precondition'`, `rate_limited: 'resource-exhausted'`.

### Dart (`app_flutter/lib`)

```dart
// lib/data/verification/verification.dart
enum VerificationStatus { notStarted, inProgress, submitted, approved, rejected, revoked } // codes not_started …
enum VerificationKind { individual, studio }
enum VerifyStep { phone, fee, identity, rules }
enum IdentityMethod { vneid, nfc }
enum RejectReason { fakeAvatar, stolenPortfolio, identityMismatch, duplicateAccount, underage, other }
enum BusinessStatus { submitted, approved, rejected }
@immutable class BusinessVerification { status, kind ('company'|'household'), taxCode, name, address, rejectCode?, rejectText? }
@immutable class VerificationState {
  status, kind, bool phoneDone, int? feeAmount, DateTime? feePaidAt, bool identityPassed, IdentityMethod? identityMethod,
  String? maskedName, String? identityFailure, DateTime? rulesAcceptedAt, DateTime? submittedAt, DateTime? decidedAt,
  RejectReason? rejectReason, String? rejectText, int freeResubmitsLeft, int identityAttemptsLeft, BusinessVerification? business;
  VerifyStep? get nextStep; int get stepsLeft; bool get canSubmit; bool get resubmittable;
  static VerificationState initial(VerificationKind kind);
}
VerificationState verificationFromFirestore(Map<String, dynamic>? d, {required bool phoneVerified, required VerificationKind kind, required DateTime now});
const providerRulesVersion = '2026-10-06';
const verificationFeeVnd = {VerificationKind.individual: 99000, VerificationKind.studio: 299000};

// lib/data/verification/verification_repository.dart
class VerificationError implements Exception { const VerificationError(this.code); final String code; }
class IdentitySession { sessionId, redirectUrl }   // the fee uses #129's PaymentInstructions
class TaxCodeInfo { name, address, active (bool), kind }
abstract class VerificationRepository {
  Stream<Map<String, dynamic>?> watchRaw(String uid);            // verifications/{uid}
  Future<void> confirmPhoneVerified();
  Future<PaymentInstructions> startFee(PayMethod method, {bool renew = false});   // #129's PayMethod / PaymentInstructions
  Future<PaymentCheck> checkFee();                                                // #129's PaymentCheck {paid, instructions}
  // fake confirmation: #129's PaymentsRepository.confirmFake(paymentId)
  Future<IdentitySession> startIdentity(IdentityMethod method);
  Future<String> completeIdentity(String sessionId);             // maskedName
  Future<void> acceptRules(String version);
  Future<void> submit();
  Future<void> resubmit();
  Future<TaxCodeInfo> lookupTaxCode(String taxCode);
  Future<BusinessStatus> submitBusiness({required String taxCode, String? docPath});
}
class FakeVerificationRepository implements VerificationRepository { /* in-memory, records calls, failWith */ }
// lib/data/verification/firestore_verification_repository.dart: FirestoreVerificationRepository (doc listener + callables, details.code → VerificationError)
// lib/data/verification/phone_verifier.dart
class PhoneCodeRequest { final String phone; final String verificationId; final int? resendToken; }
class PhoneVerifyError implements Exception { final PhoneVerifyErrorCode code; }
enum PhoneVerifyErrorCode { invalidPhone, tooManyRequests, invalidCode, codeExpired, alreadyInUse, network, unknown }
abstract class PhoneVerifier {
  Future<PhoneCodeRequest> sendCode(String e164, {int? resendToken});
  Future<void> confirmCode(PhoneCodeRequest request, String smsCode);   // links to the signed-in account
}
// lib/data/verification/firebase_phone_verifier.dart (FirebaseAuth adapter), FakePhoneVerifier in phone_verifier.dart
// lib/data/verification/verification_providers.dart
final verificationRepositoryProvider = Provider<VerificationRepository>(…Firestore…);
final phoneVerifierProvider = Provider<PhoneVerifier>(…Firebase…);
final identityModeRealProvider = Provider<bool>((_) => const bool.fromEnvironment('REAL_IDENTITY'));
final myVerificationProvider = StreamProvider.autoDispose<VerificationState>(…); // doc + currentContactProvider.phoneVerified + own providerType
// PhotographerIntro gains `verified`, `businessVerified`, `providerType` (mapped from photographers/{uid}); PhotographerSummary gains `businessVerified`.
// providerMarkOf({required ProviderType type, required bool verified, bool businessVerified = false}) — Decision 17.
// lib/core/app_config.dart (exported from core.dart; created here, #142 consumes it unchanged; cross-plan review finding 3)
const String _supportEmailRaw = String.fromEnvironment('SUPPORT_EMAIL');
const String? supportEmail = _supportEmailRaw == '' ? null : _supportEmailRaw;   // '' → null
Uri? supportEmailUri([String? email = supportEmail]);                             // mailto:{email}; null when email is null
// (moved from lib/features/events/event_links.dart, whose support email pair is removed; event_info_tab.dart uses these)
// lib/features/payment/pay_subject.dart (#129's file) gains, per its Decision 22:
final class VerificationFeePay extends PaySubject { const VerificationFeePay(); } // payPathOf → '/verify/start/fee/pay'
```

Routes (`lib/app/router.dart`): `/verify/phone` (`VerifyPhoneScreen`, query `returnTo`), `/verify/start` (`VerifyStartScreen`), `/verify/start/fee` (`VerifyFeeScreen`), `/verify/start/fee/pay` (#129's `PaymentScreen(subject: VerificationFeePay(), initial: extra)`, S04.04), `/verify/start/rules` (`VerifyRulesScreen`), `/verify/identity` (`VerifyIdentityScreen`, query `method=nfc` opens the NFC variant), `/verify/business` (`VerifyBusinessScreen`). Screen codes: `ScreenCodes.verifyPhone`, `verifyPhotographer` (labels `fee`, `rules`, `pending`, `rejected`, `approved`, `revoked`), `verifyIdentity` (label `nfc`), `verifyBusiness`.

### L10n (`app_vi.arb`, exact text)

S21.01: `verifyPhoneTitle` "Xác minh số điện thoại"; `verifyPhoneHeading` "Nhập số điện thoại của bạn"; `verifyPhoneBody` "Chúng tôi gửi mã 6 số qua SMS. Số này dùng để liên hệ khi có đơn, không hiện công khai."; `verifyPhoneExample` "Ví dụ: 0912 345 678."; `verifyPhoneSend` "Gửi mã"; `verifyCodeHeading` "Nhập mã 6 số"; `verifyCodeSentTo` "Đã gửi tới •••• {last4}"; `verifyCodeResendIn` "Gửi lại mã sau {time}"; `verifyCodeResend` "Gửi lại mã"; `verifyCodeChangePhone` "Đổi số điện thoại"; `verifyCodeConfirm` "Xác nhận"; `verifyCodeWrong` "Mã không đúng. Kiểm tra lại tin nhắn."; `verifyCodeExpired` "Mã đã hết hạn. Bấm Gửi lại mã."; `verifyPhoneTooMany` "Bạn đã thử quá nhiều lần. Thử lại sau ít phút."; `verifyPhoneInUse` "Số này đã gắn với một tài khoản khác."; `verifyPhoneInvalid` "Số điện thoại chưa đúng. Ví dụ: 0912 345 678."; `verifyPhoneDone` "Đã xác minh số điện thoại".

S21.02: `verifyStartTitle` "Bắt đầu nhận đơn"; `verifyStepCounter` "{n} / 4"; `verifyStartIntro` "Làm từng bước, lưu lại tiến độ. Thoát giữa chừng thì lần sau làm tiếp từ bước đang dở."; `verifyStepPhone` "Số điện thoại"; `verifyStepPhoneTodo` "Nhận mã 6 số qua SMS"; `verifyStepPhoneDone` "Đã xác minh · •••• {last4}"; `verifyStepFee` "Phí xác minh {amount}"; `verifyStepFeeTodoIndividual` "Studio 299.000₫ · trả bằng QR hoặc ví"; `verifyStepFeeTodoStudio` "Thợ ảnh cá nhân 99.000₫ · trả bằng QR hoặc ví"; `verifyStepFeeDone` "Đã trả {amount}"; `verifyStepIdentity` "Xác minh danh tính"; `verifyStepIdentityTodo` "VNeID hoặc quét chip CCCD"; `verifyStepIdentityDoneVneid` "Đã khớp qua VNeID"; `verifyStepIdentityDoneNfc` "Đã khớp qua chip CCCD"; `verifyStepRules` "Đồng ý quy định nhận việc"; `verifyStepRulesTodo` "5 điều chính và một dấu tích"; `verifyStepRulesDone` "Đã đồng ý"; `verifyStateDone` "Xong"; `verifyStateNow` "Đang làm"; `verifyStateTodo` "Chưa làm"; `verifyStateFix` "Cần sửa"; `verifyStartNote` "Xong 4 bước thì bấm \"Gửi duyệt\". Staff duyệt trong 24 giờ; được duyệt là có tích xanh và nhận đơn ngay."; `verifyContinue` "Tiếp tục"; `verifySubmit` "Gửi duyệt".
Fee: `verifyFeeTitle` "Phí xác minh"; `verifyFeeYouGet` "Bạn nhận được"; `verifyFeeBenefitTick` "Tích xanh cạnh tên trên hồ sơ"; `verifyFeeBenefitOrders` "Nhận đơn đặt lịch và gửi báo giá"; `verifyFeeBenefitReview` "Staff duyệt trong 24 giờ"; `verifyFeeKindIndividual` "Thợ ảnh cá nhân · studio 299.000₫"; `verifyFeeKindStudio` "Studio · thợ ảnh cá nhân 99.000₫"; `verifyFeeNoRefund` "Phí không hoàn vì chi phí kiểm tra đã phát sinh; bị từ chối được gửi lại miễn phí 1 lần."; (the method list is #129's `PayMethodList` with its own labels "Chuyển khoản QR" / "Miễn phí · xác nhận ngay" / "MoMo" / "ZaloPay"); `verifyFeePay` "Thanh toán {amount}"; `verifyFeePaid` "Đã nhận phí xác minh"; `verifyFeeFailed` "Chưa thanh toán được. Thử lại.".
Rules: `verifyRulesTitle` "Quy định nhận việc"; `verifyRulesIntro` "Đọc 5 điều chính trước khi gửi duyệt."; `verifyRule1` "Khách trả 100% khi đặt; tiền được giữ và chuyển cho bạn theo 2 mốc: sau buổi chụp, và sau khi khách đồng ý ảnh + 48 giờ."; `verifyRule2` "Bàn giao hai lớp: gửi ảnh mẫu có watermark trước; link ảnh gốc chỉ mở khi khách đồng ý."; `verifyRule3` "Khách huỷ trước 48 giờ được hoàn 100%, 24–48 giờ hoàn 50%, dưới 24 giờ không hoàn; bạn huỷ thì khách được hoàn 100%."; `verifyRule4` "Thợ cá nhân: nền tảng khấu trừ và nộp thay thuế trên phần chi trả cho bạn."; `verifyRule5` "Họ tên, ngày sinh, số định danh được mã hoá; không lưu ảnh selfie; chỉ dùng để xác minh, chống trùng tài khoản và khấu trừ thuế."; `verifyRulesAgree` "Tôi đã đọc và đồng ý quy định nhận việc".
Pending/rejected/approved/revoked: `verifyPendingHeading` "Đang chờ duyệt · trong 24 giờ"; `verifyPendingSent` "Gửi lúc {time} · có kết quả trước {deadline}"; `verifyTlFee` "Đã trả phí xác minh"; `verifyTlFeeBody` "{when} · {amount}"; `verifyTlIdentity` "Đã xác minh danh tính"; `verifyTlIdentityBody` "{method} · {name}"; `verifyMethodVneid` "VNeID"; `verifyMethodNfc` "Chip CCCD"; `verifyTlSubmitted` "Đã gửi duyệt"; `verifyTlSubmittedBody` "{when} · đã đồng ý quy định nhận việc"; `verifyTlReview` "Staff duyệt"; `verifyTlReviewBody` "Duyệt xong là có tích xanh và nhận đơn"; `verifyPendingNote` "Trong lúc chờ, bạn vẫn sửa portfolio, tạo gói và trò chuyện với khách."; `verifyViewProfile` "Xem hồ sơ"; `verifyRejectedTitle` "Hồ sơ chưa được duyệt"; `verifyRejectedReason` "Lý do: {reason}"; `verifyReject_fake_avatar` "Ảnh đại diện không phải ảnh người thật. Đổi sang ảnh chân dung rõ mặt của bạn rồi gửi lại."; `verifyReject_stolen_portfolio` "Portfolio có ảnh không phải của bạn. Gỡ những ảnh đó rồi gửi lại."; `verifyReject_identity_mismatch` "Danh tính không khớp với tên trên hồ sơ. Xác minh lại danh tính rồi gửi lại."; `verifyReject_duplicate_account` "Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn."; `verifyReject_underage` "Bạn cần đủ 18 tuổi để nhận đơn."; `verifyFreeResubmitsLeft` "Còn {n} lần gửi lại miễn phí"; `verifyNoFreeResubmit` "Hết lượt gửi lại miễn phí · gửi lại cần trả phí xác minh mới"; `verifyFixAvatar` "Ảnh đại diện"; `verifyFixAvatarBody` "Cần ảnh chân dung thật, rõ mặt"; `verifyFixPortfolio` "Portfolio"; `verifyFixPortfolioBody` "Gỡ ảnh không phải của bạn"; `verifyRejectedNote` "Chỉ sửa mục bị từ chối; các bước đã xong được giữ nguyên. Gửi lại thì staff duyệt trong 24 giờ."; `verifyResubmit` "Sửa và gửi lại"; `verifyApprovedHeading` "Bạn đã có thể nhận đơn"; `verifyApprovedBody` "Duyệt lúc {when}. Tích xanh đã hiện cạnh tên bạn."; `verifyRevokedHeading` "Xác minh đã bị thu hồi"; `verifyRevokedBody` "Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm."; `verifySupportLine` "Hỗ trợ: {email}".
S21.03: `verifyIdTitle` "Xác minh danh tính"; `verifyIdHeading` "Xác minh bằng căn cước điện tử"; `verifyIdBody` "Không cần gõ hay chụp giấy tờ: mở app VNeID, đồng ý chia sẻ rồi nhập mã PIN VNeID."; `verifyIdWeOnlyGet` "Chúng tôi chỉ nhận"; `verifyIdFieldName` "Họ tên"; `verifyIdFieldDob` "Ngày sinh"; `verifyIdFieldNumber` "Số định danh"; `verifyIdPrivacy` "Không lưu ảnh selfie. Dùng để khớp tên tài khoản nhận tiền và chống giả mạo; số định danh được mã hoá."; `verifyIdConsent` "Bấm \"Xác minh bằng VNeID\" là bạn đồng ý chia sẻ ba thông tin trên."; `verifyIdNfcLink` "Không dùng được VNeID? Quét chip CCCD"; `verifyIdVneid` "Xác minh bằng VNeID"; `verifyNfcTitle` "Quét chip CCCD"; `verifyNfcStep1` "Bước 1/2 · Đọc chip"; `verifyNfcStep2` "Bước 2/2 · Selfie"; `verifyNfcHeading` "Áp CCCD vào mặt sau điện thoại"; `verifyNfcBody` "Giữ yên thẻ ở giữa lưng máy tới khi máy rung. Tháo ốp lưng dày nếu đọc chậm."; `verifyNfcNextTitle` "Tiếp theo"; `verifyNfcNextBody` "Chụp selfie để kiểm tra người thật"; `verifyNfcNote` "Máy cần có NFC. Ảnh selfie chỉ dùng để so với ảnh trong chip, không lưu."; `verifyNfcStart` "Bắt đầu quét"; `verifySelfieHeading` "Chụp selfie 3–5 giây"; `verifySelfieBody` "Nhìn thẳng vào camera, quay đầu chậm sang trái rồi sang phải."; `verifySelfieStart` "Bắt đầu chụp"; `verifyIdPassed` "Đã xác minh: {name}"; `verifyIdUnderage` "Bạn cần đủ 18 tuổi để nhận đơn."; `verifyIdInUse` "Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn."; `verifyIdRateLimited` "Bạn đã thử 3 lần hôm nay. Thử lại vào ngày mai."; `verifyIdFailed` "Chưa xác minh được. Thử lại hoặc dùng cách khác."; `verifyIdFakeTitle` "VNeID (giả lập)"; `verifyIdFakeBody` "Môi trường thử: không mở app VNeID thật. Bấm Đồng ý để nhận một danh tính thử."; `verifyIdFakeAgree` "Đồng ý chia sẻ".
S21.04: `verifyBizTitle` "Xác minh doanh nghiệp"; `verifyBizIntro` "Cần cho con dấu Studio, hơn 3 thành viên và tài khoản nhận tiền đứng tên công ty. Không cần để nhận đơn."; `verifyBizTaxCode` "Mã số thuế"; `verifyBizLookup` "Tra cứu"; `verifyBizName` "Tên"; `verifyBizAddress` "Địa chỉ"; `verifyBizStatus` "Tình trạng"; `verifyBizActive` "Đang hoạt động"; `verifyBizInactive` "Ngừng hoạt động"; `verifyBizDocTitle` "Người đại diện: cần ảnh giấy đăng ký kinh doanh"; `verifyBizDocBody` "Staff đối chiếu người đại diện với chủ studio đã xác minh"; `verifyBizHouseholdNote` "Hộ kinh doanh: mã số thuế là số định danh của chủ, tự khớp, không cần tải giấy."; `verifyBizSubmit` "Gửi duyệt"; `verifyBizPending` "Đang chờ duyệt · trong 24 giờ"; `verifyBizApproved` "Đã xác minh doanh nghiệp"; `verifyBizRejected` "Chưa được duyệt: {reason}"; `verifyBizReject_inactive` "Doanh nghiệp không ở tình trạng đang hoạt động."; `verifyBizReject_representative_mismatch` "Mã số thuế không khớp với danh tính chủ studio."; `verifyBizReject_doc_unreadable` "Ảnh giấy đăng ký không đọc được. Chụp lại rõ nét."; `verifyBizNotFound` "Không tìm thấy mã số thuế này."; `verifyBizNeedsIdentity` "Xác minh danh tính chủ studio trước."; `verifyBizInvalid` "Mã số thuế gồm 10 hoặc 12 chữ số.".
Entry points: the S06.02 closed state reuses #134's keys `workClosedTitle`, `workClosedBody`, `workClosedNote`, `workClosedStart` (same texts; add them under those names only if #134 has not merged; cross-plan review finding 26); `settingsVerify` "Xác minh & nhận đơn" (#148's key, add only if absent); `settingsVerifyNotStarted` "Chưa bắt đầu"; `settingsVerifyStepsLeft` "Còn {n} bước"; `settingsVerifyPending` "Đang chờ duyệt"; `settingsVerifyApproved` "Đã xác minh"; `settingsVerifyRejected` "Chưa được duyệt"; `settingsVerifyRevoked` "Đã thu hồi"; `settingsBusiness` "Xác minh doanh nghiệp"; `settingsBusinessTodo` "Con dấu Studio, tới 30 thợ"; `profileOwnerStepsLeft` "Còn {n} bước để nhận đơn"; `profileOwnerStepsBody` "Khách chưa đặt được bạn cho tới khi xác minh xong."; `profileOwnerPending` "Đang chờ duyệt · trong 24 giờ"; `profileOwnerPendingBody` "Hồ sơ vẫn hiện \"Chưa nhận đơn\" với khách tới khi được duyệt."; `profileOwnerRejected` "Hồ sơ chưa được duyệt"; `profileOwnerRejectedBody` "Xem lý do và gửi lại."; `profileOwnerContinue` "Tiếp tục"; `profileOwnerView` "Xem".

### Rules, Storage, indexes

```
match /verifications/{uid} { allow read: if isOwner(uid); allow write: if false; }
match /identity_hashes/{h} { allow read, write: if false; }
match /verificationAudit/{id} { allow read, write: if false; }
match /fake_identities/{uid} { allow read, write: if false; }
// users/{uid}/private/{docId}: read becomes `isOwner(uid) && docId != 'identity'`
// photographerServerFieldsUntouched(): add 'businessVerified'
```
Storage: `match /businessDocs/{uid}/{file}` — read owner; create owner, `resource == null`, `jpegUpTo(3 * 1024 * 1024)` (the shared helper of the S10 plan, #147); no update; delete false (server purges). The app uploads with `MediaUploader.upload(image, storagePath: 'businessDocs/{uid}/{ulid}.jpg', purpose: ImagePurpose.document)` (2048 px q85, ≤ 3 MiB, EXIF stripped). If #147 has not merged yet, write the rule as `image/jpeg` ≤ 3 MiB inline and call `upload` without `purpose`; ledger it so #147's rebase converts it. Indexes (COLLECTION): `verifications (status ASC, updatedAt ASC)`, `verifications (status ASC, submittedAt ASC)`, `verifications (business.status ASC, business.submittedAt ASC)`, `verifications (business.purgeAfter ASC)` if the single-field default is disabled (contract check).

## Review Focus

1. **Approve without onboarding / revoke after load** — approve of a provider with `onboardingComplete: false` writes `acceptingOrders: false`; a revoke makes `createBookingDraft` and #129's `createPayment` refuse with `not_accepting_orders`, and a payment arriving for a draft of a revoked provider is refunded by #129's `settleBookingTransfer` (its Decision 9). Pinned in Task 2 ("approve writes verified and acceptingOrders together…", "after a revoke createPayment refuses and a late transfer is refunded provider_not_accepting").
2. **Double fee** — two methods or two taps produce two payments; only one is recorded, the other refunded 100% through #129's refund rule (idempotent by refund id, re-sent only by `reconcilePayments`); the fee never shows in earnings or payouts. Pinned in Task 2 ("a second paid fee is refunded…") and Task 4 ("a verification fee payment does not refresh earnings", "a webhook transfer for a verification fee is settled, not unmatched").
3. **Same person, two accounts, at the same time** — two `completeIdentityVerification` calls with the same id number: exactly one owns `identity_hashes/{h}`, the other gets `identity_in_use`. Pinned in Task 3 ("the hash guard is created in the same transaction…") and the Task 4 integration test (written).
4. **Client writes and reads** — a client cannot read `users/{uid}/private/identity`, cannot write `verifications/*`, `verified`, `businessVerified`, `acceptingOrders`, or `phoneVerified: true`. Pinned in Task 4 rules tests.
5. **OTP edge cases** — the number is linked to another account (`credential-already-in-use`), the user already has a phone provider (update instead of link), the code is wrong or expired; and a later number change shows the phone step undone. Pinned in Task 5 (`FirebasePhoneVerifier` mapping tests) and Task 6.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore nam5 upper bound $0.06/100K reads, $0.18/100K writes (**Singapore chưa xác nhận**); SMS Vietnam **$0.15/SMS** after 10 free/day (**chưa xác nhận** per-country table); Storage $0.02/GB-month; egress $0.12/GB (assumed). 

**Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s.

Volumes: (b) 1,000 MAU / 100 providers → ~30 verifications started per month; (c) 10,000 MAU / 1,000 providers → ~300 per month (new providers + retries).

| User action | Reads | Writes | Notes |
|---|---|---|---|
| Open S21.02 (and S21.03/S21.04, same doc) | 2 (listener `verifications/{uid}` + contact doc, already open in S09.02) | 0 | listener: the step list changes on server writes (fee, identity) |
| Phone OTP (S21.01) | 2 | 2 (contact, verification) | + 1 SMS per send (resend ≤ 1 typical) |
| Fee start / fake confirm / check | 3 / 4 / 3 | 1 / 4 (payment, ledger, verification, maybe refund) / 0–4 | `get`, no listener |
| Identity start / complete | 2 / 6 | 1 / 4 (verification, identity, hash, audit on duplicate) | |
| Rules / submit / resubmit | 2 each | 1 each | |
| Staff approve / reject / revoke | 4 | 4 (verification, photographer, audit, notification row + inbox) | trigger `onPhotographerWrite` re-fires once, writes nothing |
| S21.04 lookup / submit | 2 / 5 | 0 / 2–3 | + one upload ≤ 500 KB for companies |
| Staff CLI `list` | ≤ 50 | 0 | admin tool |
| S06.02 / S09.02 / S03.01 owner card | +1 (`verifications/{uid}` listener while the tab is open) | 0 | autoDispose |

- **New callables:** 11 (the fake confirmation is #129's). Calls ≈ 12 per verification → (b) ~360/month ($0, free tier), (c) ~3,600/month × 0.2 vCPU-s ≈ 720 vCPU-s ≈ $0.02 (Functions rule); 256 MiB, 10 s (fee ones 30 s).
- **New triggers:** none. **New scheduled jobs:** none; `bookingClock` (15 min, 2,880 runs/month) gains one query (`verifications where status == 'in_progress' and updatedAt <= now−24h`, empty = 1 read) → +2,880 reads/month ≈ $0.002; the daily `purgeAwardProofs` gains one query → +30 reads/month.
- **Storage:** `businessDocs/{uid}/…`, ≤ 500 KB after compression (2048 px q82), (b) ~3/month, (c) ~30/month, deleted 30 days after the decision → < 15 MB stored, egress only staff views → ≈ $0.
- **Paid APIs:** SMS for S21.01 only (providers): ≈ 1.3 SMS per verification → (b) ~40/month (< 10/day free) → **$0**; (c) ~390/month ≈ 13/day → ~3/day above the free 10 → ~90 SMS × $0.15 ≈ **$13.5/month** (worst case if all are paid: $58). No Maps, no KMS (dev vault), no Secret Manager. VNeID/eKYC and tax-code vendors are outside Google (Deferred).
- **Conclusion:** (b) **≈ $0.01/month**; (c) **≈ $0.04/month + SMS ≈ $13.5/month** (range $0–58). Mitigations for (c): OTP only from "Bắt đầu nhận đơn" (done), one resend per 60 s with a visible countdown (Task 6), Auth emulator and test numbers in dev, Firebase Auth per-IP limits kept; owner decision to evaluate a domestic SMS brand name / Zalo ZNS (≈ 200–500₫/tin, chưa xác nhận) through a Function before production.

## Tasks

### Task 1: Mock frames, screen codes and spec rows

**Files:**
- Modify: `docs/design/ui-mock.html` (S21 section after `#S21.04`; `#S21.02-pending` line; `#S03.01` group; `#S09.02` group; the screen table near line 2733: S21.01 "Có"), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S21.01 status cell "⬜ có mock, chưa làm"; §3i.4 one line "S21.01 dùng Firebase Auth phone (emulator khi dev); khách chưa phải OTP khi đặt (plan S21 Decision 21)"), `app_flutter/lib/core/screen_codes.dart` (check only)

**Interfaces:** Produces mock frames `S21.01`, `S21.01-code`, `S21.02-rules`, `S21.02-approved`, `S21.02-revoked`, `S21.03-selfie`, `S03.01-owner`, `S09.02-provider`; later tasks build to them.

- [ ] **Step 1: Contract check.** `ScreenCodes.verifyPhone` … `verifyBusiness` exist and are in `ScreenCodes.all`; the mock has no `S21.01` frame; ledger anything else.
- [ ] **Step 2: Add the frames** (follow existing frames: `.step` + `.phone` + `.cap`, `<span class="ms">`, existing classes `bar`, `prog`, `field`, `vsteps`/`vstep`, `ben`, `lockn`, `esc`, `idill`, `vqr`, `tl`, `warnc`, `btn pri|out|txt`; captions carry `<span class="n new">Mới</span>`). Copy is exactly the Contract §L10n text:
  - `S21.01`: bar back + "Xác minh số điện thoại" + "1 / 4"; `prog` 1 on; `h3` "Nhập số điện thoại của bạn"; meta body; row `field` "Mã" "+84" and `field foc` "Số điện thoại" "912 345 678"; meta x example; foot `btn pri` "Gửi mã". Caption: "S21.01 · Xác minh số điện thoại · Một số, một mã" — "Bước 1 của S21.02. Số lấy sẵn từ hồ sơ nếu có (S04.05, S09.03). Mã gửi qua Firebase Auth; SMS thật tốn khoảng $0.15/tin ở Việt Nam, dev dùng Auth emulator. Số đã gắn với tài khoản khác báo lỗi dưới ô. Khách đặt lịch chưa phải nhập mã."
  - `S21.01-code`: same bar/prog; `h3` "Nhập mã 6 số"; meta "Đã gửi tới •••• 5678"; six boxes (use the `field` style, `tn`) showing "4 8 1 · · ·"; row meta "Gửi lại mã sau 0:42"; `tlink` "Đổi số điện thoại"; foot `btn pri` "Xác nhận". Caption explains: auto-fill on Android, wrong code "Mã không đúng. Kiểm tra lại tin nhắn.", one resend per 60 giây.
  - `S21.02-rules`: bar back + "Quy định nhận việc" + "4 / 4"; `prog` 4 on; meta intro; card with five numbered lines (`verifyRule1`…`verifyRule5`); a checkbox row "Tôi đã đọc và đồng ý quy định nhận việc"; foot `btn pri` "Gửi duyệt" (`aria-disabled` until checked). Caption: no link to full terms until the terms exist (Decision 10).
  - `S21.02-approved`: `vqr` with `idill` `verified_user`, `h3` "Bạn đã có thể nhận đơn", meta "Duyệt lúc 10:05 hôm nay. Tích xanh đã hiện cạnh tên bạn."; foot `btn out` "Xem hồ sơ".
  - `S21.02-revoked`: `warnc` "Xác minh đã bị thu hồi" + body; meta "Hỗ trợ: hotro@…" (placeholder email); no primary.
  - `S21.03-selfie`: like `#S21.03-nfc` with step 2 on: `h3` "Chụp selfie 3–5 giây", meta body, `idill` `photo_camera`, foot `btn pri` "Bắt đầu chụp".
  - `S03.01-owner`: copy of `#S03.01-new` header but owner view: no orders-closed tag or note; a card under the stats row with `idill`-sized icon `verified_user`, **"Còn 3 bước để nhận đơn"**, meta "Khách chưa đặt được bạn cho tới khi xác minh xong.", `btn out xs` "Tiếp tục"; footer bar "Chỉnh sửa hồ sơ". Caption lists the pending/rejected variants (Contract copy).
  - `S09.02-provider`: copy of `#S09.02` with, in the Tài khoản card, a row `verified_user` "Xác minh & nhận đơn" / "Còn 2 bước"; and for a studio a row `workspace_premium` "Xác minh doanh nghiệp" / "Con dấu Studio, tới 30 thợ".
  - Edit `#S21.02-pending`: "VNeID · NGUYEN MINH TRI" → "VNeID · NGUYỄN M** T**" (Decision 9). In `#S21.02` caption add the not-done phone line "Nhận mã 6 số qua SMS".
- [ ] **Step 3: Check:** open-tag balance (`python3 - <<'EOF'` counting `<div` vs `</div>` inside the S21 section equals before + new frames), every new `id` unique (`grep -c 'id="S21.01"' == 1` …), the screen table row S21.01 says "Có".
- [ ] **Step 4: Commit** `docs(mock): S21.01 phone OTP, rules, approved and owner frames [#135]`.

### Task 2: Domain — verification state, fee, phone, rules, staff decisions, order gate re-checks

**Files:**
- Create: `packages/domain/src/verification.ts`, `verification_ports.ts`, `verification_use_cases.ts`, `verification_fee.ts` (`VerificationFeeSettler`), `memory_verification_store.ts`; `packages/domain/test/verification.test.ts`, `verification_use_cases.test.ts`, `verification_fee.test.ts`, `test/support/verification_world.ts`
- Modify: `src/errors.ts`, `src/escrow.ts` (`PaymentSubject`), `src/index.ts`; `test/booking_payments.test.ts` (#129's; one revoke case, Decision 15). No change to #129's payment code and no notification copy (#138).

**Interfaces:** Consumes `acceptsOrders`, `ProviderOrderGate`, `Payment`, `applyRefundToPayment`, `PLATFORM_PAYEE`; from #129 (signatures in its Contract, quoted here): `newSubjectPayment(p: {id, subjectType, subjectId, payerId, payeeId, amount, method, provider, idempotencyKey, now, expiresAt}): Payment`, `issuePaymentInstructions(gateway, payment, save, returnUrl?): Promise<PaymentInstructions>`, `instructionsOf(payment): PaymentInstructions | null`, `applyTransfer({payment, transfer, payer, ledgerEntryId, now}): {payment, ledgerEntry, decision, excess}`, `excessRefund(...)`, `expireUnpaid({payment, refundId, ledgerEntryId, now})`, `sendRefundOnce({gateway, cipher, clock}, refund, payment): Promise<Refund>`, `mergeRefundOutcome(stored, next): Refund | null`, `interface SubjectSettler { settle(paymentId, t, payer): Promise<TransferDecision>; expire(paymentId, now): Promise<'expired'|'unchanged'>; dispatchRefund(refund, payment): Promise<Refund>; statusOf(subjectId): Promise<string> }`; `NotifyDeps` and #138's three hooks (Contract). Produces everything under Contract §Domain except `identity_verification.ts`, `business_verification.ts` and the fakes (Task 3). `verification_world.ts` builds `VerificationDeps` from a `MemoryVerificationStore` (read-after-write guard like `memory_album_store.ts`), #129's `FakePaymentGateway` with a `MemoryFakeTransferLedger`, a map-backed `AuthPhoneReader`, `ControllableClock` (2026-10-10T10:00Z), `SequentialIdGen`, and seeds a photographer `p1` (individual, onboarded), a studio `s1`, a customer `c1` (not a provider).

Sample (approve; the one write that must stay together):

```ts
case 'approve': {
  if (rec.status !== 'submitted') throw new DomainError('conflict');
  const p = await tx.getProvider(input.uid);
  if (p === null) throw new DomainError('not_found');
  const after = { ...rec, status: 'approved', decidedAt: nowIso, decidedBy: staff.uid, rejectReason: null,
                  version: rec.version + 1, updatedAt: nowIso } as const;
  tx.putVerification(after);
  tx.setProviderFlags(input.uid, { verified: true, verifiedAt: nowIso,
    acceptingOrders: acceptsOrders({ verified: true, onboardingComplete: p.onboardingComplete }) });
  tx.addAudit({ id: deps.ids.newId(), uid: input.uid, target: 'identity', action: 'approve', reason: null,
                note: input.note ?? null, actorId: staff.uid, at: nowIso });
  return { before: rec, after };
}
```

- [ ] **Step 1: Contract check** of the domain bullets; ledger differences.
- [ ] **Step 2: Failing tests** — `verification.test.ts`: "kind is studio only for providerType studio"; "fees are 99 000 and 299 000"; "nextStep follows phone, fee, identity, rules"; "phoneVerified on the contact counts as the phone step"; "stepsLeft counts undone steps"; "ageOn turns 18 on the VN birthday (17:00Z the day before)"; "maskLegalName keeps the first word and masks the rest" (`NGUYỄN MINH TRÍ` → `NGUYỄN M** T**`, one word unchanged); "identity attempts reset on a new VN day". `verification_use_cases.test.ts`: "a non-provider is permission_denied"; "confirmPhoneVerified sets phoneVerified when Auth and contact match"; "a different Auth number is conflict"; "no contact phone is phone_required"; "startVerificationFee returns PaymentInstructions for a platform payment of the kind's fee (bank_qr has the VietQR payload)"; "the same method and attempt reuse the live payment"; "renew expires the live payment and issues a new code"; "fee after it is paid is not_eligible"; (`verification_fee.test.ts`, through #129's `settleTransfer` with `subjects.verification_fee`) "an exact transfer records the fee step, escrow released, payment_received plus fee_charged, in_progress"; "a second paid fee for the same attempt is refunded 100% as duplicate_verification_fee"; "the same transaction id applies once"; "an over transfer refunds the excess (overpaid)"; "expire refunds what an unpaid fee received"; "a throwing refund stays pending for reconcilePayments"; "#129's confirmFakePayment pays a fee and returns the verification status"; "checkVerificationFee settles a transfer found by queryPayment"; "acceptVerificationRules needs the current version"; "submit needs all four steps"; "submit moves to submitted with submittedAt"; "approve writes verified and acceptingOrders together"; "approve of a provider without onboarding writes acceptingOrders false"; "reject needs a known reason and a note for other"; "reject identity_mismatch clears the identity step"; "resubmit with a free resubmit goes back to submitted and uses it"; "resubmit without free resubmits clears the fee and bumps feeAttempt"; "duplicate_account and underage cannot resubmit"; "revoke turns verified and acceptingOrders off"; "only admins decide"; "every decision writes an audit row"; "verificationNotices: approved, rejected, revoked, business verified/rejected"; "notifyVerificationChange calls notifyVerificationDecision with the outcome and decidedAt"; "sendVerificationNudges calls notifyVerificationReminder once after 24 h of no change". `booking_payments.test.ts` (#129's, one case): "after a revoke createPayment refuses with not_accepting_orders and a late transfer is refunded provider_not_accepting". (The six types' copy is #138's and pinned by its `notification_render.test.ts`.)
  Copy (now in #138's catalogue, this plan's text; listed here so the tests can assert what the hooks render): approved "Bạn đã có thể nhận đơn" / "Hồ sơ đã được duyệt. Tích xanh đã hiện cạnh tên bạn."; rejected "Hồ sơ chưa được duyệt" / "Xem lý do và sửa để gửi lại."; revoked "Xác minh đã bị thu hồi" / "Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm."; reminder "Còn {n} bước để nhận đơn" / "Làm tiếp để khách đặt được bạn."; business verified "Studio đã xác minh doanh nghiệp" / "Con dấu Studio đã hiện trên hồ sơ, studio nhận tới 30 thợ."; business rejected "Xác minh doanh nghiệp chưa được duyệt" / "Xem lý do trong mục Xác minh doanh nghiệp."; targets `/verify/start` and `/verify/business`.
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → the new tests fail.
- [ ] **Step 4: Implement.** `startVerificationFee`: one transaction (provider, record, fee not yet paid, live payment of this attempt and method → reuse; `renew` → `expireUnpaid` on it), then `issuePaymentInstructions` outside it with a `save` callback that stores `providerRef` + `instructions` while the payment is still `created` (#129's pattern). `VerificationFeeSettler.settle`: reads payment + record in a `VerificationStore` transaction, `applyTransfer`, then on `paid`: fee step already recorded for `feeAttempt` → `applyRefundToPayment(100%, 'duplicate_verification_fee')`, else record the step and add `fee_charged`; payment `escrowStatus 'released'`; excess per #129's table; refunds dispatched after commit through `dispatchRefund` (= `sendRefundOnce` + a transaction applying `mergeRefundOutcome`). Add the three error codes.
- [ ] **Step 5: Run** `(cd packages/domain && npm test && npm run lint)` → pass (incl. `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): verification states, fee, staff decisions and gate re-checks [#135]`.

### Task 3: Domain — identity (VNeID / chip) and business verification

**Files:**
- Create: `packages/domain/src/identity_verification.ts`, `business_verification.ts`, `fake_identity_verifier.ts`, `fake_tax_code_lookup.ts`; `test/identity_verification.test.ts`, `business_verification.test.ts`; `MemoryIdentityVault` in `test/support/verification_world.ts`
- Modify: `src/verification_use_cases.ts` (`reviewVerification` business branch), `src/index.ts`

**Interfaces:** Consumes Task 2. Produces `startIdentityVerification`, `completeIdentityVerification`, `isTaxCode`, `lookupTaxCode`, `submitBusinessVerification`, `FakeIdentityVerifier`, `fakeIdNumberOf`, `FakeTaxCodeLookup`; `MemoryIdentityVault` hashes with a deterministic prefix (`h:` + reversed digits) so tests can build collisions.

Sample (write the failure, throw after commit):

```ts
const hash = await vault.hashId(res.idNumber);            // outside the transaction (async crypto)
const enc = await vault.encryptId(res.idNumber);
const outcome = await deps.store.runTransaction(async (tx) => {
  const rec = await tx.getVerification(uid); /* session, fee, attempts checks */
  const owner = await tx.identityOwner(hash);
  const failure = !res.passed ? 'provider_failed'
    : ageOn(res.dob, now) < MIN_PROVIDER_AGE_YEARS ? 'underage'
    : owner !== null && owner !== uid ? 'identity_in_use' : null;
  if (failure) {
    tx.putVerification(withIdentityFailure(rec, failure, now));   // counts the attempt, clears the session
    if (failure === 'identity_in_use') tx.addAudit({ …, action: 'duplicate', otherUid: owner! });
    return { failure } as const;
  }
  tx.putIdentity(uid, { legalName: res.legalName, dob: res.dob, gender: res.gender, idNumberEnc: enc, idHash: hash,
                        method, provider: res.provider, providerRef: res.providerRef, verifiedAt: nowIso });
  if (owner === null) tx.putIdentityHash(hash, uid);
  tx.putVerification(withIdentityPassed(rec, method, maskLegalName(res.legalName), now));
  return { failure: null, maskedName: maskLegalName(res.legalName) } as const;
});
if (outcome.failure === 'provider_failed') throw new DomainError('not_eligible');
if (outcome.failure) throw new DomainError(outcome.failure);
```

- [ ] **Step 1: Contract check** (Task 2 exports present).
- [ ] **Step 2: Failing tests** — identity: "start needs the fee paid"; "start after identity passed is conflict"; "a fourth start in one VN day is rate_limited, the next day works"; "start without a verifier is not_eligible"; "complete with an unknown or used session is not_found"; "a passing result stores the encrypted id, the hash guard and the masked name"; "the owner doc never stores the id number or the full name"; "under 18 is underage and counts an attempt"; "an id owned by another uid is identity_in_use, counts an attempt and audits the other uid"; "the same uid verifying again keeps its own hash"; "the hash guard is created in the same transaction as the identity" (memory store commit log); "identity_mismatch reopened by staff can pass again"; "FakeIdentityVerifier uses the override when present"; "fakeIdNumberOf is 12 digits starting with 0 and stable per uid". Business: "isTaxCode accepts 10, 10-3 and 12 digits"; "only a verified studio may start"; "an inactive code is not_eligible"; "a household code matching the owner's id hash is approved at once and sets businessVerified"; "a household code of someone else is rejected representative_mismatch"; "a company needs a businessDocs/{uid}/ photo and becomes submitted"; "staff approve sets businessVerified and purgeAfter = decidedAt + 30 days"; "staff reject needs a business reason"; "FakeTaxCodeLookup: …0000 is inactive, 12 digits is household, others a company".
- [ ] **Step 3: Run** → fail. **Step 4: Implement.** **Step 5: Run** `(cd packages/domain && npm test && npm run lint)` → pass.
- [ ] **Step 6: Commit** `feat(domain): identity and business verification with fake adapters [#135]`.

### Task 4: Functions, staff CLI, rules, storage, indexes, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/verification_firestore.ts` (`FirestoreVerificationStore`, `adminAuthPhoneReader`), `src/infra/identity_vault.ts` (`devIdentityVault()`), `src/infra/live_verification.ts` (`liveVerificationDeps()`), `src/callables/verification.ts` (11 handlers), `tools/verifications.ts`; tests `test/unit/verification_callables.test.ts`, `test/unit/verification_firestore.test.ts`, `test/unit/identity_vault.test.ts`, `test/unit/verifications_cli.test.ts`, `test/integration/verification.test.ts`
- Modify: `src/index.ts` (exports), `src/infra/live_payments.ts` (#129's `liveSettlementDeps()` registers `subjects.verification_fee = new VerificationFeeSettler(liveVerificationDeps(), cipher)`), `src/infra/booking_firestore.ts` (payment/refund `subjectType` whitelist accepts `verification_fee`), `src/callables/errors.ts`, `src/scheduled/booking_clock.ts` (nudge step), `src/scheduled/award_purge.ts` (business-doc purge step), `src/triggers/payment_write.ts` (no code change; a unit test pins that a platform-payee fee is skipped), `package.json` (`"verifications": "tsx tools/verifications.ts"`), `seed/fixtures.ts`, `seed/README.md`; `app_flutter/firebase/firestore.rules`, `storage.rules`, `firestore.indexes.json`, `app_flutter/firebase/rules-test/rules.test.mjs`

**Interfaces:** Consumes Tasks 2–3. Produces the callables of Contract §Callables; `liveVerificationDeps()` = Firestore store, `adminAuthPhoneReader` (`getAuth().getUser(uid).phoneNumber`), `identity = fakePaymentsAllowed() ? new FakeIdentityVerifier(readFakeIdentity, ids) : null`, `vault = fakePaymentsAllowed() ? devIdentityVault() : null`, `taxCodes = fakePaymentsAllowed() ? new FakeTaxCodeLookup() : null`, `gateway` = #129's live gateway (fake where `fakePaymentsAllowed()`, `off` elsewhere). `handleCheckVerificationFee` calls `checkSubjectPayments(liveSettlementDeps(), await verificationFeePayments(deps, uid))`. Each mutating handler calls `notifyVerificationChange(liveNotifyDeps(), change)` after the use case (errors logged, never thrown to the caller). `handleBookingClock` gains the step `verificationNudges` (`sendVerificationNudges`) at the end of its step list, its own try/log (a failure does not stop the booking sweep), with its dependencies in the optional `BookingClockExtras.verification?: { deps: VerificationDeps; notify: NotifyDeps }` (clock rule of #129's Global Constraints: no existing parameter changes; create `BookingClockExtras` in `scheduled/booking_clock.ts` if absent).

- [ ] **Step 1: Contract check** of the Functions/rules bullets (incl. how `award_purge.ts` is shaped, storage helper names); ledger differences.
- [ ] **Step 2: Failing tests.** Unit: "unauthenticated calls are refused"; "reviewVerification needs the admin claim"; "domain codes map: identity_in_use → already-exists, underage → failed-precondition, rate_limited → resource-exhausted"; "a webhook transfer for a verification fee is settled, not unmatched" (#129's `handlePaymentWebhookRequest` with `liveSettlementDeps()`); "startVerificationFee in payments-off mode is not_eligible"; "identity callables answer not_eligible when the fake is not allowed"; "verification maps to and from Firestore (Timestamps ↔ ISO)"; "approve writes verifications and photographers in one batch"; "devIdentityVault hashes deterministically and refuses outside emulator/dev"; "a verification fee payment does not refresh earnings" (`handlePaymentWrite` with payee `platform` returns null); "bookingClock runs the nudge step and survives its failure"; "the purge step deletes business photos past purgeAfter"; CLI: "parseArgs for list/show/approve/reject/revoke/business-approve/business-reject", "list marks rows older than 24 h", "--actor must hold the admin claim". Integration (write, do not run): "full path on the emulator: phone, fee (fake), identity (fake), rules, submit, approve → photographers.acceptingOrders true"; "two accounts with the same fake identity: one gets identity_in_use"; "createBooking refuses after revoke". Rules (write, do not run): "the owner reads verifications/{uid}, another user cannot"; "nobody writes verifications"; "the owner cannot read private/identity but still reads private/contact"; "identity_hashes, verificationAudit, fake_identities are closed"; "a client cannot set businessVerified on photographers"; "a client cannot set phoneVerified true on private/contact"; storage "the owner uploads a business photo once, cannot overwrite, others cannot read".
- [ ] **Step 3: Run** `(cd app_flutter/firebase/functions && npm test)` → fail.
- [ ] **Step 4: Implement.** Rules/Storage/indexes per Contract. Seed: `seed-photographer-giang` (`giang.pending@seed.test`, individual, onboarded, `verified: false`) with a `submitted` verification (all steps done, fee payment `paid`, identity with the fake id of its uid) for `npm run verifications -- approve`; `fake_identities/seed-photographer-binh` absent (Bình walks the full flow); a `fake_identities/seed-customer-minh` override `{dob: '2010-05-01'}` documented as the underage example if Minh switches role. Seed README: one table "Verification (S21)" listing Giang, Bình and the CLI commands.
- [ ] **Step 5: Run** `(cd app_flutter/firebase/functions && npm test && npm run build)` and `(cd packages/domain && npm test)` → pass. Ledger: rules tests and integration tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): verification callables, staff CLI, rules and seed [#135]`.

### Task 5: App data — verification repository, phone verifier, marks

**Files:**
- Create: `app_flutter/lib/data/verification/verification.dart`, `verification_repository.dart`, `firestore_verification_repository.dart`, `phone_verifier.dart`, `firebase_phone_verifier.dart`, `verification_providers.dart`, `lib/core/app_config.dart` (Contract §Dart; `test/core/app_config_test.dart`: "supportEmail is null when SUPPORT_EMAIL is empty; supportEmailUri builds mailto"); tests `test/data/verification/verification_mapping_test.dart`, `verification_repository_test.dart`, `phone_verifier_test.dart`, `test/core/widgets/provider_mark_test.dart` (extend if it exists)
- Modify: `lib/data/photographer/photographer_intro.dart` (`verified`, `businessVerified`, `providerType`), `lib/data/content/photographer_summary.dart` + `firestore_photographer_repository.dart` (`businessVerified`), `lib/core/widgets/provider_mark.dart`, every `providerMarkOf(` call site (pass `businessVerified`), `lib/core/core.dart` (export `app_config.dart`), `lib/features/events/event_links.dart` (remove its support email pair), `lib/features/events/event_info_tab.dart` (use `supportEmail` / `supportEmailUri()`), `test/features/events/event_links_test.dart` (its email cases move to `test/core/app_config_test.dart`), `lib/core/theme/app_icons.dart` (missing icons), `test/support/` fixtures (`fixturePhotographer(..., businessVerified = false)`)

**Interfaces:** Consumes the callables and the Firestore shape (Task 4). Produces Contract §Dart. `FirebasePhoneVerifier.sendCode` wraps `FirebaseAuth.verifyPhoneNumber` in a `Completer` (`codeSent` → request; `verificationFailed` → mapped error; `verificationCompleted` (Android auto-retrieval) → link immediately and complete with a request marked `autoVerified`); `confirmCode` builds `PhoneAuthProvider.credential` and calls `currentUser.updatePhoneNumber` when the user already has the `phone` provider, else `linkWithCredential`. Error mapping: `invalid-phone-number` → `invalidPhone`, `too-many-requests`/`quota-exceeded` → `tooManyRequests`, `invalid-verification-code` → `invalidCode`, `session-expired` → `codeExpired`, `credential-already-in-use`/`account-exists-with-different-credential` → `alreadyInUse`, `network-request-failed` → `network`. `myVerificationProvider` combines the doc stream, `currentContactProvider` (`phoneVerified`) and `myIntroProvider` (`providerType` → kind); a missing doc is `VerificationState.initial(kind)`.

- [ ] **Step 1: Contract check** (app bullets); ledger differences.
- [ ] **Step 2: Failing tests:** mapping — "missing doc is not started with the kind's fee"; "each status code maps"; "steps map with dates"; "phone step comes from the contact flag"; "nextStep and stepsLeft match the domain order"; "a rejected doc exposes reason, text and resubmittable"; "identity attempts left counts the VN day"; "business sub-record maps". Repository — "callables send the documented payloads" (fake `FirebaseFunctions` seam or the `FakeVerificationRepository` contract test used by both); "details.code becomes VerificationError(code)"; "unavailable becomes network". Phone verifier — "each FirebaseAuthException code maps to its PhoneVerifyErrorCode"; "link when no phone provider, update when one exists" (adapter takes injectable `FirebaseAuth`; use `mock_exceptions`-free fakes). Marks — "a verified studio without businessVerified shows the blue tick"; "businessVerified studio shows the seal"; "artist keeps the gold tick".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/data/verification` → fail.
- [ ] **Step 4: Implement.** `flutter gen-l10n` is not needed yet (no strings here).
- [ ] **Step 5: Run** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/data/verification`, then `test/core/widgets`, then `test/data/content` → pass.
- [ ] **Step 6: Commit** `feat(data): verification repository, phone verifier and studio seal rule [#135]`.

### Task 6: S21.01 phone OTP screen

**Files:**
- Create: `app_flutter/lib/features/verification/verify_phone_screen.dart`, `verify_phone_controller.dart`; test `test/features/verification/verify_phone_screen_test.dart`
- Modify: `lib/app/router.dart` (`/verify/phone`), `lib/l10n/app_vi.arb` (S21.01 keys), `test/support/` (a `VerificationWorld` helper: fake repositories, fake phone verifier, router with `/verify/start` stub)

**Interfaces:** Consumes `phoneVerifierProvider`, `verificationRepositoryProvider.confirmPhoneVerified`, `userContactRepositoryProvider.save`, `currentContactProvider`, `PhoneField`, and the six-digit input `OtpCodeField({required TextEditingController controller, String? errorText, ValueChanged<String>? onCompleted})` from core (#134; if #134 has not merged, create it in `lib/core/widgets/otp_code_field.dart` with exactly that signature, 6 digits, `AutofillHints.oneTimeCode`; cross-plan review finding 39). The six boxes of the mock are `OtpCodeField`'s look; no second code input is built. Produces `VerifyPhoneScreen({String? returnTo})`; state machine in `VerifyPhoneController` (`enter → sending → code → confirming → done`, with `error` codes) — the resend countdown is a one-shot `Timer` per second that stops at 0 and is cancelled in `dispose` (no periodic timer left running after the test).

**Backend wiring:** `FirebasePhoneVerifier` (Firebase Auth phone, Auth emulator in dev) → `FirestoreUserContactRepository.save` (when the number differs; keeps `allowZalo`/`allowWhatsApp`) → callable `confirmPhoneVerified` → `users/{uid}/private/contact.phoneVerified` + `verifications/{uid}.steps.phone` (rules: client cannot set `phoneVerified: true`).
**Mock parity:** `#S21.01` (bar title, "1 / 4" only when `returnTo` is `/verify/start`, `StepProgress` 1/4, heading, body, `PhoneField` +84, example line, primary "Gửi mã") and `#S21.01-code` (heading, "Đã gửi tới •••• {last4}", six-box code input, "Gửi lại mã sau m:ss" then text button "Gửi lại mã", text button "Đổi số điện thoại", primary "Xác nhận").

- [ ] **Step 1: Contract check** (`PhoneField` API, `CountdownText` usable or a local text).
- [ ] **Step 2: Failing tests:** "prefills the saved number"; "an invalid number shows verifyPhoneInvalid and does not send"; "Gửi mã sends and shows the code step with the last 4 digits"; "a different number is saved to the contact first"; "Xác nhận links, calls confirmPhoneVerified and returns to returnTo"; "a wrong code shows verifyCodeWrong and keeps the step"; "an expired code shows verifyCodeExpired"; "alreadyInUse shows verifyPhoneInUse under the field"; "tooManyRequests shows verifyPhoneTooMany"; "resend is disabled for 60 s and enabled after" (pump 61 × 1 s); "Đổi số điện thoại returns to the number step"; "an already verified number shows the done state and Tiếp tục"; "fits 320dp at 1.3x text".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/verification` → fail.
- [ ] **Step 4: Implement**; add arb keys, `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/features/verification` → pass.
- [ ] **Step 6: Commit** `feat(verify): S21.01 phone OTP over Firebase Auth [#135]`.

### Task 7: S21.02 steps, fee, rules, pending, rejected, approved, revoked + entry points

**Files:**
- Create: `app_flutter/lib/features/verification/verify_start_screen.dart`, `verify_fee_screen.dart`, `verify_rules_screen.dart`, `widgets/verify_step_tile.dart`, `widgets/verify_timeline.dart`; tests `test/features/verification/verify_start_screen_test.dart`, `verify_fee_screen_test.dart`, `verify_rules_screen_test.dart`, `test/features/work/work_empty_closed_test.dart`, `test/features/settings/settings_verify_row_test.dart`, `test/features/photographer_profile/owner_verify_card_test.dart`
- Modify: `lib/app/router.dart` (`/verify/start`, `/verify/start/fee`, `/verify/start/rules`, `/verify/start/fee/pay` → #129's `PaymentScreen(subject: VerificationFeePay())`), `lib/features/payment/pay_subject.dart` + `payment_controller.dart` (#129's files: the `VerificationFeePay` variant and its `case` — paid when `myVerificationProvider` shows the fee step done → `context.go('/verify/start')`; "Tạo QR mới" calls `startFee(method, renew: true)`; Decision 22 of #129), `lib/features/work/work_empty.dart` (closed variant with #134's `workClosed*` keys — only if #134 has not merged; when it has, its S06.02 closed state already exists and this task only flips the flag below), `lib/features/settings/settings_screen.dart` (add rows per S09's order, #148 Decision 12: in group Tài khoản, the existing "Xác minh & nhận đơn" row `settings-verify` gets the status subtitle, and the studio row "Xác minh doanh nghiệp" `settings-verify-business` goes right after it; flip `verifyStartReadyProvider` to `true` in `lib/features/settings/settings_links.dart`), `lib/features/photographer_profile/widgets/profile_header.dart` (owner card), `lib/l10n/app_vi.arb`

**Ready flag:** `verifyStartReadyProvider` (defined in `lib/features/settings/settings_links.dart` by #148; #134's S06.02 button reads it too) is set to `true` in this task, in the same commit that registers `/verify/start`. If neither #148 nor #134 has merged, create the provider at that path with value `true` so they find it. A test asserts it is `true` and that `/verify/start` resolves.

**Interfaces:** Consumes `myVerificationProvider`, `verificationRepositoryProvider`, `myIntroProvider.verified`, and from #129: `PayMethod`, `PayMethodList({value, onChanged, enabled})`, `PaymentInstructions`, `openPayment(BuildContext context, WidgetRef ref, {required PaySubject subject, required PaymentInstructions instructions, bool replace = false})` (bank QR → S04.04 VietQR; wallet → `FakeWalletSheet` in fake mode or the `payUrl`, then S04.04's wait), `PaymentScreen`. Produces `VerifyStartScreen`, `VerifyFeeScreen` ("Thanh toán" → `startFee(method)` → `openPayment(subject: const VerificationFeePay(), instructions)`), `VerifyRulesScreen`, `VerifyStepTile({index, icon?, title, subtitle, state: VerifyTileState {done, now, todo, fix}})`, `OwnerVerifyCard`.

**Backend wiring:** listener `verifications/{uid}` (rules: owner read); callables `startVerificationFee`, `checkVerificationFee` (S04.04 on resume), #129's `confirmFakePayment` (fake mode, through `FakeWalletSheet`/`FakeTransferSheet`), `acceptVerificationRules`, `submitVerification`, `resubmitVerification`; no new index on the client.
**Mock parity:** `#S21.02` (bar "Bắt đầu nhận đơn" + "{n} / 4", `StepProgress`, intro, four `VerifyStepTile` rows with text states Xong/Đang làm/Chưa làm, info note, primary "Tiếp tục" or "Gửi duyệt" when all done); `#S21.02-fee` (benefits card with three checks, amount large + kind line, no-refund `lockn`, #129's `PayMethodList` (Chuyển khoản QR default with its note, MoMo, ZaloPay), primary "Thanh toán {amount}"; the next screen is #129's S04.04 `#S04.04` for the fee); `#S21.02-rules` (five lines, checkbox, primary "Gửi duyệt" disabled until checked); `#S21.02-pending` (icon, heading, sent/deadline line, four-step timeline with the masked name, note, outline "Xem hồ sơ", no primary); `#S21.02-rejected` (`warnc` with reason, free-resubmit row + time, fix rows by Decision 13, note, primary "Sửa và gửi lại"; final reasons show the support line and no primary); `#S21.02-approved`, `#S21.02-revoked`; `#S06.02` (closed empty state: `verified_user` illustration, title, body, meta, small primary "Bắt đầu nhận đơn"; the tab chrome around it is unchanged — ledger the segment row of the mock if the work tab has none); `#S09.02-provider` rows; `#S03.01-owner` card.

- [ ] **Step 1: Contract check** (work tab chrome, settings tile style, header layout slots).
- [ ] **Step 2: Failing tests:** start — "a new provider sees four steps, phone Đang làm, others Chưa làm, counter 1 / 4"; "a done phone shows Đã xác minh · •••• 3456 and Xong"; "the studio fee row shows 299.000₫ and the individual alternative"; "Tiếp tục opens the first undone step route"; "all four done shows Gửi duyệt and submits"; "submitted shows the pending timeline with the masked name and no primary button"; "rejected fake_avatar shows the reason, Còn 1 lần gửi lại miễn phí, the avatar fix row opening /settings/profile, and Sửa và gửi lại resubmits"; "rejected with no free resubmit shows the paid line and resubmit moves back to the list with the fee step open"; "rejected duplicate_account shows the support line and no primary"; "approved shows the heading and Xem hồ sơ"; "revoked shows the warning and support line"; "states are text, not colour only" (semantics labels). Fee — "Chuyển khoản QR is selected by default"; "Thanh toán 99.000₫ starts the fee with bank_qr, momo or zalopay as chosen"; "bank_qr opens /verify/start/fee/pay with the VietQR instructions"; "S04.04 for the fee goes back to /verify/start when the fee step becomes done"; "a wallet in fake mode opens FakeWalletSheet and confirmFake pays it"; "a failure shows verifyFeeFailed and keeps the method". Rules — "five rules in order"; "Gửi duyệt is disabled until the box is checked"; "checking and sending accepts version 2026-10-06 then submits". Entry points — "S06.02 shows the closed state for an unverified provider and opens /verify/start"; "a verified provider keeps today's S06.02"; "S09.02 shows Xác minh & nhận đơn with Còn 2 bước / Đang chờ duyệt / Đã xác minh"; "a verified studio also sees Xác minh doanh nghiệp"; "a customer sees neither row"; "the owner card on S03.01 shows Còn {n} bước để nhận đơn and Tiếp tục"; "the owner card hides once approved"; "visitors never see the owner card". Each screen: "fits 320dp at 1.3x text".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/verification`, then `test/features/work`, `test/features/settings`, `test/features/photographer_profile` → fail.
- [ ] **Step 4: Implement**; arb keys; `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze`; the four folders one at a time → pass.
- [ ] **Step 6: Commit** `feat(verify): S21.02 steps, fee, rules and decisions with entry points [#135]`.

### Task 8: S21.03 identity (VNeID / chip CCCD) and S21.04 business

**Files:**
- Create: `app_flutter/lib/features/verification/verify_identity_screen.dart`, `verify_identity_controller.dart`, `fake_identity_sheet.dart`, `verify_business_screen.dart`; tests `test/features/verification/verify_identity_screen_test.dart`, `verify_business_screen_test.dart`
- Modify: `lib/app/router.dart` (`/verify/identity`, `/verify/business`), `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `verificationRepositoryProvider.startIdentity/completeIdentity/lookupTaxCode/submitBusiness`, `identityModeRealProvider`, `externalLauncherProvider` (real `redirectUrl`), `ImagePickerPort`, `MediaUploader` (path `businessDocs/{uid}/{ulid}.jpg`, `purpose: ImagePurpose.document` from #147). Produces `VerifyIdentityScreen({IdentityMethod method})` (VNeID screen, NFC two-step screen, result), `FakeIdentitySheet` (fake mode only: consent → `completeIdentity`), `VerifyBusinessScreen`.

**Backend wiring:** callables `startIdentityVerification`, `completeIdentityVerification` (fake verifier on emulator/dev; `not_eligible` elsewhere → `verifyIdFailed`), `lookupTaxCode`, `submitBusinessVerification`; Storage `businessDocs/{uid}/{file}` (rules: owner create once); listener `verifications/{uid}` for the result and business status.
**Mock parity:** `#S21.03` (bar + "3 / 4", progress, `badge` illustration, heading, body, card "Chúng tôi chỉ nhận" with the three fields and the lock note, consent meta, text link "Không dùng được VNeID? Quét chip CCCD", primary "Xác minh bằng VNeID"); `#S21.03-nfc` (step labels 1/2 · 2/2, two-segment progress, card illustration, heading, body, "Tiếp theo" row, NFC note, primary "Bắt đầu quét"); `#S21.03-selfie` (step 2); `#S21.04` (intro, tax-code field with search action, key–value result Tên / Địa chỉ / Tình trạng chip, upload tile + representative text for companies, household note, primary "Gửi duyệt").

- [ ] **Step 1: Contract check** (`ImagePickerPort`, `MediaUploader` fakes in `test/support`).
- [ ] **Step 2: Failing tests:** identity — "VNeID screen matches the mock copy"; "fake mode: Xác minh bằng VNeID starts a vneid session, the fake sheet agrees and the result shows Đã xác minh: NGUYỄN M** T**, then returns to S21.02"; "real mode opens redirectUrl and waits for the listener"; "underage shows verifyIdUnderage and no retry button"; "identity_in_use shows verifyIdInUse"; "rate_limited shows verifyIdRateLimited"; "not_eligible shows verifyIdFailed"; "Quét chip CCCD opens step 1/2, Bắt đầu quét moves to the selfie step, Bắt đầu chụp completes an nfc session"; "the identity step is disabled until the fee is paid (tap opens the fee route)". Business — "only a verified studio sees the form; others see verifyBizNeedsIdentity"; "an invalid code shows verifyBizInvalid"; "Tra cứu shows name, address and Đang hoạt động"; "an inactive company shows Ngừng hoạt động and disables Gửi duyệt"; "a company needs a photo before Gửi duyệt; the photo uploads to businessDocs/{uid}/"; "a 12-digit code hides the upload and shows the household note"; "approved, pending and rejected states read from the listener"; "fits 320dp at 1.3x text".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/verification` → fail.
- [ ] **Step 4: Implement**; arb keys; `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/features/verification` → pass.
- [ ] **Step 6: Commit** `feat(verify): S21.03 identity on the fake adapter and S21.04 business [#135]`.

### Task 9: Specs, data model, ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-identity-verification-design.md` (§3: `verifications/{uid}` path and `business` sub-record, Decision 1; §5: the fake tax-code lookup and the `api.vietqr.io` candidate; §6: shipped adapters and Deferred real ones; §7: the gate re-checks are #129's `createPayment` + `settleBookingTransfer`, Decision 15), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 status cells S21.01–S21.04 "✅ đã làm (#135) · danh tính/thuế giả lập"; S23.04 "tạm duyệt bằng CLI (`npm run verifications`)"; S06.02 and S09.02 notes), `docs/superpowers/specs/data-model/domain-model.md` (`Verification`, `IdentityRecord`, `PaymentSubject 'verification_fee'`, new error codes), `docs/superpowers/specs/data-model/relational-schema.md` (target tables `verifications`, `identities`, `identity_hashes`, `verification_audit`; `photographers.business_verified`; Firestore mapping rows), `docs/legal/terms-and-help-notes.md` (V1: rules version line), `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` (§6: S21.01 SMS volume note)
- Create: `docs/superpowers/handover/ledger-s21-verification.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names); check every string quoted in specs equals `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings per task, deferred minors, skipped suites (rules tests and Functions integration written, not run; no device build, so OTP on a real phone is unverified), deploy-order notes: (1) deploy rules before the app (the app reads `verifications/*`); (2) the identity callables stay `not_eligible` on any project that is not the emulator or dev until a real vendor and KMS vault exist; (3) dev providers who must stay bookable keep `verified: true` from the seed or the CLI; (4) `REAL_IDENTITY` must stay unset in builds until (2).
- [ ] **Step 3: Commit** `docs(spec): S21 verification state, data model and ledger [#135]`.

## Deferred

- Real VNeID adapter (RAR/C06 or an intermediary with mTLS and a fixed egress IP / Cloud NAT) and real chip-CCCD + liveness SDK (platform channel) — spec §6, §11.2; needs a contract.
- KMS-backed `IdentityVault` and Secret Manager keys (Blaze; owner ruling 2026-10-07); `devIdentityVault` refuses to run elsewhere.
- Real tax-code lookup (`api.vietqr.io/v2/business/{mst}` candidate, research §D) and representative-name matching for companies.
- Real payment intermediary for the fee (#129 Deferred; the fee already runs on #129's model and S04.04) and the e-invoice for the fee (spec payments §8).
- S23.04 staff screen (phase 1.5 dashboard, #83); staff push for the overdue queue.
- Customer OTP at booking (S04.05, Needs the owner 1); SMS brand name / Zalo ZNS adapter.
- Full terms page and the "Đọc điều khoản đầy đủ" link (terms text not written).
- Account deletion keeping `idHash` (S22.02, #141); data-protection impact assessment and domestic storage of identity data (spec §9, §11.3).
- `services/api` migration (phase 2, #90); the Go backend.
- Payout account name matching against the verified name (S06.06, #134).
