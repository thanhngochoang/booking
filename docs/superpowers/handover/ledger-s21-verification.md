# Handover ledger — plan S21 provider verification: S21.01, S21.02, S21.03, S21.04 (issue #135)

Plan: `docs/superpowers/plans/2026-10-07-s21-verification.md`, Tasks 1–9. Branch `plan/135-s21-verification`, based on `origin/develop` (2e9017c). The fee, the `verification_fee` payment subject, the two fee callables and `VerifyFeeScreen` (plan Tasks 10–13) are **#203**, not this unit; they are written up in the "#203" section at the end of this file (the sections above describe #135 as it was handed over, with the fee off). Commits:
- `43fc2cf` docs(mock): S21 rules, approved, revoked and owner frames (Task 1)
- `f4a5120` feat(domain): verification states, staff decisions and gate re-checks (Task 2)
- `c20fba8` feat(domain): identity and business verification with fake adapters (Task 3)
- `133c3d2`, `45507df` feat(functions): verification callables, staff CLI, rules and seed; fix: refuse replacing a pending or approved business record (Task 4)
- `27d9a81`, `a4669ed` feat(data): verification repository, phone verifier and studio seal rule; fix: resubmit gate, provider watches and phone step (Task 5)
- `7389931` feat(verify): S21.01 phone OTP over Firebase Auth (Task 6)
- `4653034`, `3c96a7f` feat(verify): S21.02 steps, rules and decisions with entry points; fix: back stack and mock copy on rejected rows (Task 7)
- `01b4f0c`, `683781a` feat(verify): S21.03 identity on the fake adapter and S21.04 business; fix: identity result detection, business photo reset, shared verify parts (Task 8)
- Task 9: specs, data model and this ledger (one docs commit).
- Final whole-branch review fixes: `fix(verify): unblock back on unexpected errors and guard identity vendor calls` and `docs(ledger): S21 before-production list and final review fixes` (see "Fixes after the final review").

---

## Built
- **Domain (`packages/domain/src`)**: `verification.ts` (statuses, steps, `requiredSteps(feeRequired)`, `stepDone`, fee constants, reject reasons), `verification_use_cases.ts` (confirm phone, start and complete identity, accept rules, submit, resubmit, staff review, nudge), `identity_verification.ts`, `business_verification.ts`, `verification_ports.ts` (`IdentityVerifier`, `IdentityVault`, `TaxCodeLookup`, `VerificationStore`), `fake_identity_verifier.ts`, `fake_tax_code_lookup.ts`, `memory_verification_store.ts`. `providerMarkOf` gains `businessVerified` (gold Studio seal only for a business-verified studio). `handleTransferNotification` refunds 100% (`provider_not_accepting`) a transfer for a provider who no longer accepts orders. New error codes `identity_in_use`, `underage`, `rate_limited`.
- **Functions (`app_flutter/firebase/functions`)**: callables `confirmPhoneVerified`, `startIdentityVerification`, `completeIdentityVerification`, `acceptVerificationRules`, `submitVerification`, `resubmitVerification`, `lookupTaxCode`, `submitBusinessVerification`, `reviewVerification` (`callables/verification.ts`); Firestore adapter `infra/verification_firestore.ts`; dev vault `infra/identity_vault.ts`; `infra/live_verification.ts`; staff CLI `tools/verifications.ts` (`npm run verifications`); reminder step in `bookingClock`; business-photo purge as a second step of `purgeAwardProofs`; seed accounts (Giang submitted 26 h ago, Bình with nothing, Minh underage) in `seed/`.
- **Rules and indexes (`app_flutter/firebase`)**: `verifications/{uid}` owner read, server write; `identity_hashes`, `verificationAudit`, `fake_identities` server-only; `users/{uid}/private/identity` unreadable even by the owner; Storage `businessDocs/{uid}/{file}` owner read, JPEG up to 3 MiB, create once. Three composite indexes on `verifications`.
- **App**: `lib/data/verification/` (repository interface, Firestore and fake adapters, phone verifier, providers, `verificationFeeRequiredProvider` false) and `lib/features/verification/` (S21.01 phone and code, S21.02 steps, rules, pending, rejected, approved, revoked, S21.03 VNeID and NFC sheets, S21.04 business). Entry points: S06.02 button, S09.02 row "Xác minh & nhận đơn", and the "Còn {n} bước để nhận đơn" card on the owner's S03.01. Strings in `app_vi.arb` (`verify*`, `settingsVerify*`, `profileOwner*`).

---

## Rulings
Each ruling lists what it costs if wrong.

1. **Tasks 1–3 taken as done.** The session was resumed with no ledger; the three commits existed and matched the plan's file lists, so work continued from the uncommitted Task 4 state instead of redoing them. If wrong: the final whole-branch review catches gaps.
2. **Rebased onto `origin/develop`** (see "Base of this branch" below). The skill requires develop as the base, and a PR into develop must not carry another unit's 73 files. If wrong: see the base note.
3. **Index `(status, nudgedAt, updatedAt)`** instead of the plan's `(status, updatedAt)`. The nudge query must filter `nudgedAt == null`; without it, already-nudged records starve the page. If wrong: one extra index to drop.
4. **A rejected company resubmission overwrites `docPath` and `purgeAfter`**, so the rejected photo is no longer purged. Not fixed here: it needs a design choice (keep old paths for the purge, or delete on resend); it is a dev-only fake flow. Correction (final review): a registration certificate is not just public registry data, it carries the legal representative's personal data (name, ID number, address), so the purge is required before production (see "Trước khi lên production"). If wrong: rejected company photos linger in Storage beyond 30 days until a follow-up adds the purge. Related: a re-picked photo in S21.04 also leaves the earlier upload in Storage.
5. **The domain `stepDone('phone')` follows Decision 3 exactly**: the step is `contact.phoneVerified` and `steps.phone` only mirrors it, so the server refuses a submit after a number change that the app shows as undone. If wrong: a provider who changed number must re-verify before submitting (this is the intended rule).
6. **`myVerificationProvider` refactor was promoted from a minor** into the Task 5 fix round (it awaited before `ref.watch`, which breaks on an unmounted ref when the S21.01 flag flips). Screens in Tasks 6–7 build on it. If wrong: one small extra refactor.
7. **Step bar on S21.01 only when `returnTo` is `/verify/start`**, like the counter (the mock caption says S21.01 is step 1 of S21.02). If wrong: the bar is missing when the screen is opened from Settings.
8. **The contact is saved after the code links and before `confirmPhoneVerified`**, not before the SMS: a typed but unconfirmed number must not reset `phoneVerified`. If wrong: the order of two calls and a test change.
9. **T7 tests assert the route path pushed, T8 registers `/verify/identity`** (the route was used by "Tiếp tục" in Task 7 before Task 8 existed). If wrong: one test adjusted.
10. **The S21.02 counter shows the current step's position** ("1 / 3"), as the task's named tests require; the mock frame `#S21.02` shows "1 / 4" with step 2 current, which is inconsistent. If wrong: the counter semantics change.
11. **"Còn 0 lần gửi lại miễn phí" is hidden at 0 while the fee is off** (a resubmit is still free then, Decision 24). The mock caption says the line is always shown, which describes the #203 target. If wrong: one row to show.
12. **Rejected-row titles use the mock copy** ("Danh tính", "Quy định nhận việc"; promoted from a minor): the mock is the authority for copy. Cost: one extra arb key.
13. **`settings_mode_test` now pins the shipped flag** (promoted from a minor): tests must run the shipped configuration. Cost: a small test change.
14. **Extra arb keys accepted without a contract entry**: `verifyAtToday`, `verifyAtTomorrow`, `verifyAtDate` (the mock shows "9:12 hôm nay / ngày mai") and `verifySelfieNote` (mock selfie frame text).
15. **The identity result, the error alerts and S21.04 pending, approved and rejected have no mock frame** (the plan's Task 1 drew none); they were built from existing mock elements. If wrong: visual rework once frames exist.
16. **Task 8 findings promoted into its fix round**: the rate limit must not hide the final reasons `underage` and `identity_in_use`; a new tax code must not inherit the previous S21.04 photo; `VerifyAlert` and `VerifyMeta` duplicated Task 7's private widgets and were merged into shared `verify_parts`; the production `/verify/identity` and `/verify/business` routes are now tested rather than re-declared by the test world. Cost: a slightly larger fix diff.
17. **Task 4 Important fixed**: `submitBusinessVerification` no longer overwrites a pending or approved business record (`45507df`).
18. **A household's 12-digit tax code is stored in plain text** in `verifications/{uid}.business.taxCode` (owner-readable only). It is the owner's personal citizen ID, so it breaks the rule that id numbers are only encrypted (`IdentityRecord`) or hashed (`IdentityHash`). The controller kept the code as is in #135 and the specs state the exception (identity spec §3, §5, §11 question 9; domain-model invariant 27). If wrong: a citizen ID sits unencrypted in an owner-only Firestore document until a follow-up changes it to a hash or last 4 digits.
19. **The identity rate limit counts starts, not failures**: `startIdentityVerification` adds one per start, even an abandoned one, and the 4th start in a VN day is `rate_limited`. Specs were corrected to say so. If wrong: a user who abandons sessions is locked out for the day earlier than the "3 tries" wording suggests.

## Plan decisions worth knowing (full text is in the plan)
- State lives in the top-level `verifications/{uid}`, not `users/{uid}/private/verification` (staff queue queries); the identity stays at `users/{uid}/private/identity`; the business sub-record is `verifications/{uid}.business`.
- Staff decisions go through one use case, `reviewVerification`, from both the callable and the CLI; approving writes `verifications/{uid}` and `photographers/{uid}` in one transaction.
- The reminder is one push 24 h after the last change of an `in_progress` record, inside the existing `bookingClock`; no S06.01 banner.
- Customers do not get an OTP at booking (S04.05); S21.01 is for providers only.
- Notifications use #138's hooks (`notifyVerificationDecision`, `notifyBusinessDecision`, `notifyVerificationReminder`) after the use case commits.
- Free until #203 (Decision 24): `feeRequired` was false on the server (`liveVerificationDeps()`) and in the app (`verificationFeeRequiredProvider`). **#203 flipped both to true** in one PR (see the "#203" section).

## Needs the owner (defaults taken)
1. OTP for customers at booking (S04.05): not now.
2. Provider type changed after paying the individual fee: no top-up (in force since #203: `kind` is frozen when the fee is recorded).
3. Reinstating a revoked provider: terminal in the app; support handles it outside; staff tool later (#83).
4. Phone change after approval: stays approved; the phone step shows undone until re-verified.
5. Household tax code (12 digits = the owner's personal ID): store only a hash or the last 4 digits instead of plain text in `business.taxCode`? Default now: plain text, owner-readable only.

---

## Deferred minors (not fixed; grouped)
**Phone (S21.01)**: no toast "Đã xác minh số điện thoại" before leaving on success (the mock caption has it); stale `_DoneStep` doc comment; resend does not clear the code boxes; server errors (`phone_required`, `conflict`) all show `engagementError`; `setupNext` was reused for "Tiếp tục" (fixed in Task 7, now `verifyContinue`); untested `_linked` retry path, `PopScope` back and the "Đổi số" countdown-stopped assertion; the 320 dp test lacks the done and in-use states; RTL nit `EdgeInsets.only(right:)` in the app bar action.
**Steps and rules (S21.02)**: `ref.watch` inside `AsyncView` data-builder helpers (`verify_start_screen.dart`); `_WarnCard` duplicates the earnings `name_lookup_card` warning card (shared widget candidate); step tile semantics use selected instead of the mock's `aria-current`, and the counter is excluded from semantics; `verifyWhen` builds the date and time order in code (`verify_timeline.dart`); the literal `'/verify/start'` in `profile_header` and raw alpha and size literals following precedent; the support line is hidden when `SUPPORT_EMAIL` is unset, so **release builds must set it**.
**Identity and business (S21.03, S21.04)**: real mode has no cancel while waiting and a null `redirectUrl` waits forever (no vendor yet); a real-mode failure snapshot arriving during the `starting` phase is ignored until a later snapshot; business submit `invalid_argument` always shows the tax-code text; an upload stream that ends with no media leaves the tile without a check or error; the upload tile uses light-only colours in dark mode, has no semantics label and a solid instead of dashed border; `VerifyCounter` is not excluded from semantics, the NFC art is unlabeled, the chip link position differs from the mock spacer; the NFC option is not hidden on phones without NFC (the mock note says it should be).
**Data layer (Task 5)**: the test "callables run in the app region with a timeout" checks only the timeout; fake `completeIdentity` always returns `vneid`, `_changes` is never closed, seed is a shallow copy; the `fromCode` loop is repeated four times and the null-doc branch duplicates `VerificationState.initial`.
**Functions and domain (Task 4)**: `verification_scheduled.test.ts` logs ERROR stack traces and does not assert logging (use the `process.stderr` mock pattern); the integration test hard-codes booking days 2026-12-05 and 2026-12-12 (breaks after those dates); `identityFromFirestore` maps missing fields to the string `'undefined'` (`verification_firestore.ts`); `freeResubmitsLeft` reads a default of 0 instead of 1 when absent; `putIdentityHash` writes `createdAt` with `Timestamp.now()`, not the domain clock; the seed README admin row does not mention `npm run verifications`; the overdue staff queue has no job or push yet (the CLI only marks `!`).

---

## Fixes after the final review
- **Back no longer trapped on unexpected errors.** `FirestoreVerificationRepository` maps any other `Exception` from a callable (platform channel, socket, timeout, malformed reply) to `VerificationError('network')` and any other throwable to `'unknown'`; `FirebasePhoneVerifier._link` does the same with `PhoneVerifyErrorCode.network` / `unknown`. `VerifyIdentityController.start` and `_complete` also catch everything else and show the failed message, so `calling` ends and S21.03's `PopScope` lets go. S21.01's `sendCode` has a 90 s timeout (`verifyPhoneSendTimeout`, mapped to `network`), so a `verifyPhoneNumber` that never calls back no longer holds the screen in `sending`.
- **Reminder push**: says at least "Còn 1 bước" (a record with every step done but not sent counted 0), is sent only when the guarding transaction wrote `nudgedAt` (a record submitted or nudged meanwhile gets nothing), and the cutoff uses `VERIFICATION_NUDGE_AFTER_HOURS`.
- **Vendor not called for a refused request**: `startIdentityVerification` checks `conflict` (identity passed) and `rate_limited` in its first read transaction, before `IdentityVerifier.start`; `completeIdentityVerification` checks the session belongs to the uid and is current (`not_found`) before `IdentityVerifier.result`. Both still re-check inside the write transaction.
- Minors: the business reject uses `BUSINESS_REJECT_REASONS` and length-checks a given note (5–500) like the identity reject; the stale "all reads already done" comment on `applyTransfer` is corrected; the `directChatDocuments` JSDoc in `seed/fixtures.ts` is back above its function.

## Trước khi lên production (before production)
1. **Household tax code storage** (ruling 18, owner question 5): decide it together with the real `TaxCodeLookup`. Default: store a hash plus the last 4 digits, not the plain 12-digit code.
2. **Purge re-sent and re-picked business photos** (ruling 4): a rejected company's resubmission and a re-picked S21.04 photo leave the earlier upload in Storage. Registration certificates carry the legal representative's personal data, so they must be deleted on the same clock as a decided photo.
3. **`SUPPORT_EMAIL` must be set in release builds** (deploy order 6): without it the revoked and duplicate-account states show no support line.
4. **Duplicate identity race**: when CI first runs the Functions integration test "two accounts with the same fake identity", confirm the losing call answers 409 (`already-exists`), not 500.

---

## Written but not run
- **Firestore and Storage rules tests** (`app_flutter/firebase/rules-test/`) and **Functions integration tests** (`firebase/functions`, `npm run test:integration`) were written and **not run**: the sandbox cannot start the emulators, and CI runs them on push. Domain, Functions unit and Flutter suites ran clean.
- **No device build**: nothing ran on a phone or emulator. The OTP flow (`verifyPhoneNumber`, `linkWithCredential`, auto-fill of the SMS code) is **unverified on a real phone**; test it with an Auth emulator number first, then one real SMS.

## Deploy order
1. **Deploy Firestore rules, indexes and Storage rules before the app**: the app reads `verifications/*`, and the three `verifications` indexes must be built before the reminder and queue queries run.
2. The identity callables answer `not_eligible` on any project that is not the emulator or dev (`fakePaymentsAllowed()`), until a real vendor and a KMS-backed vault exist.
3. Dev providers who must stay bookable keep `verified: true` from the seed or the CLI (`npm run verifications -- approve <uid> --actor <uid>`); the gate now refuses providers without it.
4. `REAL_IDENTITY` must stay unset in builds until (2) is resolved: with it unset the app shows its fake VNeID and NFC sheets.
5. Verification was free until #203 (Decision 24): #203 flips `feeRequired` to true on both the server and the app in one PR so a released build never disagrees. Deploy order for that flip is in the "#203" section.
6. Set `SUPPORT_EMAIL` in release builds (the revoked and duplicate-account states show a support line only when it is set).

## Index deviation
`firestore.indexes.json` has `(status, nudgedAt, updatedAt)` on `verifications`, not the plan's `(status, updatedAt)` (ruling 3). The other two are `(status, submittedAt)` and `(business.status, business.submittedAt)`.

## Mock follow-ups (the mock was not edited in Task 9)
- `#S21.02`: the counter reads "1 / 4" while step 2 is current; with the position-of-current-step rule it should read the current step's position (or the frame should show step 1).
- `#S21.02-rejected`: the caption says "Còn 1 lần gửi lại miễn phí" is always shown; the app hides "Còn 0 lần gửi lại miễn phí" at 0 while the fee is off (ruling 11). The target behaviour (line shown at 1, and at 0 as "Hết lượt gửi lại miễn phí · gửi lại cần trả phí xác minh mới") is in the app since #203; the mock caption still needs the 0 variant (see the "#203" section).
- Missing frames: the S21.03 identity result ("Đã xác minh: {name}"), the S21.03 error alerts (underage, in use, rate limited, failed), and S21.04 pending, approved and rejected.
- **Done in #203**: the fee row texts, the fee screen route, `verifyStepPath(VerifyStep.fee)` and the flag flip (the old "#203 must fill" list). The mock frames `#S21.02-fee` and the "Đã trả phí xác minh" timeline row were already the target.

## Base of this branch
This branch was **rebased from `origin/main` onto `origin/develop`** (backup in the local branch `backup/135-before-rebase`). `origin/main` (07cbc98) holds #201's PR #230, which was merged into main instead of develop, so basing on it would have put #201's 73 files into this PR. One conflict, in `handle_transfer.ts`, was resolved by keeping develop's `paid` variable around the Decision 15 check. If #201's refund changes are later re-merged into develop (an owner action), this branch needs one more rebase.

## Sandbox note
`gh` and `git` to GitHub need `dangerouslyDisableSandbox` in this environment (the keychain token is unreadable inside the sandbox).

---

# #203 — verification fee (plan Tasks 10–13)

Branch `plan/203-s21-verification-fee`, based on `origin/develop` e29ca39 (has #135, #200 V1 payments, #201 V2 refunds, #190, #204). Commits:
- `c3a7d2e` feat(domain): verification fee as a payment subject (Task 10)
- `9613e45`, `7d83906` fix(domain): fee amount, attempt and paid resubmit guards; no fee for final rejections and grandfathered free resubmits (Task 10 fix rounds)
- `7cc1e8f` feat(functions): verification fee callables and settlement subject (Task 11)
- `e80b914`, `7846f21` feat(verify): S21.02 verification fee on S04.04; fix(domain): identity start honours the grandfathered fee waiver (Task 12)
- Task 13: specs, data model and this section (one docs commit).

## Built (#203)
- **Domain** (`packages/domain/src`): `verification_fee.ts` (`startVerificationFee`, `checkVerificationFee`, `feePayable`, `VerificationFeeSettler`, `verificationFeeRefundHandler`), `feeWaived` in `verification.ts`, `PaymentSubject` gains `verification_fee` in `escrow.ts` (V1 had not added it on develop), `VerificationTx` and `VerificationDeps` gain the payment members and `gateway`, `payments`, `cipher`. Identity start needs the fee step done.
- **Functions**: callables `startVerificationFee` and `checkVerificationFee`; `FirestoreVerificationTx` reads and writes the shared `payments`, `refunds`, `ledger_entries` and `payment_notifications` collections; `liveVerificationDeps()` has `feeRequired: true`; the fee is registered in `liveSettlementDeps()` (as `verification_fee: new VerificationFeeSettler(...)`, through the new `settlementSubjectsOf`) and in `liveRefundSubjects()` (through `refundSubjectsOf`), so the webhook, the payment clock, `confirmFakePayment` and the refund re-send all reach it. Seed: Giang's submitted record holds a paid fee with its payment and two ledger entries; An, Cúc and Dũng (approved before #203) keep `steps.fee` null.
- **App**: `VerifyFeeScreen` at `/verify/start/fee`, S04.04 with the `VerificationFeePay` subject at `/verify/start/fee/pay`, the fee row on S21.02, the fee-paid timeline row, the no-free-resubmit line, S21.03 sending an unpaid provider to the fee, `verificationFeeRequiredProvider` true. Strings use the `verifyFee*`, `verifyStepFee*`, `verifyTlFee*` and `verifyNoFreeResubmit` keys (every quoted string equals `app_vi.arb` and the mock).

## Rules worth knowing (#203)
- **Refund reasons**: `duplicate_verification_fee` when a fee arrives for a record that already holds one (second payment, two methods paid); `stale_verification_fee` when the payment is no longer this attempt's fee (the code was for the other kind's amount, for an earlier attempt, or the record cannot take a fee any more: past the steps, finally rejected, waived or gone). Both refund 100% through V2; they are `applyRefundToPayment` policy refunds and live in `VERIFICATION_FEE_REFUND_REASONS`, not in `PAYMENT_REFUND_REASONS` (which holds `transferRefund` reasons).
- **`feePayable`**: no fee for a final rejection (`underage`, `duplicate_account`); `startVerificationFee` answers `not_eligible`, and a payment that still arrives is refunded as stale.
- **`feeWaived` (Decision 24)**: a record with status `rejected`, a free resubmit left, `submittedAt` set and `steps.fee` null was submitted before the fee existed, so its free resubmit needs no fee. **Flipping `feeRequired` off and on again waives records submitted while it was off** in the same way (same signature). Cost if wrong: those providers skip one 99.000₫ or 299.000₫ fee.
- **Identity start honours the waiver**: `startIdentityVerification` treats the fee step as done when paid or waived, so a grandfathered record rejected for `identity_mismatch` can re-verify without paying (found in Task 12; fixed in `7846f21`).
- **Ledger sign convention**: `fee_charged` is written **positive** to `platform_revenue`, next to the positive `payment_received` to `platform_escrow` that V1 writes on receipt; `platform_fee` entries are **negative** (the commission taken out of a provider's payout). Do not sum the two types without the sign.
- **The fee is a registered subject**: `liveSettlementDeps()` and `liveRefundSubjects()` both carry `verification_fee`; a new subject must add its line to both, or its payments are unmatched and its refunds are never re-sent.

## Rulings (#203)
Each ruling lists what it costs if wrong.

1. **Fee before phone is allowed.** Decision 2: steps go in any order except that identity needs the fee. If wrong: one guard.
2. **A fee paid after a rejection counts as the paid resubmit.** For a pre-#203 record with no free resubmit left, a fee paid after the rejection (`steps.fee.paidAt` later than `decidedAt`) sends the resubmit straight to `submitted`, keeps the fee and does not bump `feeAttempt`; otherwise the provider would pay twice. If wrong: one branch.
3. **The settler records a fee only when it fits the record.** The amount must equal the fee of the current kind and the payment must belong to the record's `feeAttempt`; otherwise it is refunded 100% as `stale_verification_fee`. `startVerificationFee` also expires every open code of the attempt whose amount no longer matches the kind. If wrong: a studio could end up verified for 99.000₫.
4. **Implementer deviations accepted**: renewed codes use keys `vfee_{uid}_{attempt}_{method}_{n}` and the live payment is found by `feePaymentsOf` (a fixed key cannot find a renewed code); one upsert `putRefund`; `cipher` and `payments` on `VerificationDeps`; `verification_fee` added to `PaymentSubject` here; the refund handler is registered in Task 11. If wrong: names only.
5. **Rejected records with a non-resubmittable reason cannot open the fee**, and a payment for one is refunded as stale. Cost: none.
6. **Grandfathering by signature** (`submittedAt` set, `steps.fee` null): every #203 submit carries a fee and a paid resubmit clears `submittedAt`, so the signature only matches old records. If wrong: such providers skip one fee.
7. **After paying, S04.04 returns to S21.02 by pop** (`go` only as a fallback), not the plain `go('/verify/start')` of the brief, so S21.02 keeps its own back stack like #135. Cost: none.
8. **Mock caption gaps are ledger follow-ups, the brief wins on behaviour** (see below). Cost: a mock edit later.

## V1/V2 contract differences found in Tasks 10–12 (merged code wins)
- `PaymentSubject` on develop held only `booking` and `event_registration`; the V1 ledger said V1 had added `verification_fee`, the code had not. Added in Task 10. (The data-model tables already listed it.)
- `VerificationTx` has `feePaymentsOf(uid)` instead of a lookup by idempotency key, one upsert `putRefund` (no `addRefund`), and `getTransferRecord` / `putTransferRecord` because V1's `SubjectSettler.settle` writes the transfer record in the subject's transaction.
- `VerificationDeps` gains `gateway`, `payments: PaymentLookup` (V1's `freshPaymentId` needs a cross-subject lookup by transfer code) and `cipher: AccountCipher` (V2 payer capture and bank-transfer refunds); the settler takes only `(deps)`.
- V2 has no refund-subject registry in the domain: handlers are per-subject factories wired in `infra/live_refunds.ts`; the fee adds `verificationFeeRefundHandler(deps)` there. Only the V2 path (`sendRefundOnce` plus `mergeRefundOutcome`) exists; no V1 fallback.
- `checkVerificationFee` lives in the domain and takes the settlement as an argument (the callable passes `liveSettlementDeps()`); it answers `{paid, instructions}` over V1's `checkSubjectPayments`.
- An already-paid fee answers `not_eligible`, not `conflict`.
- The Functions gateway is `getSharedFakeGateway()` (the same instance as the booking deps, without building them); `settlementSubjectsOf` and `refundSubjectsOf` are new composition helpers so tests use the live registry. "Payments off" means `!checkoutGatewayAvailable(env)`, the same check `createPayment` makes; `startVerificationFee` refuses before any read or write.
- App: V1's `PaymentCheck` lives in `data/payments/payments_repository.dart`; `PayDone` gains `paid` (default true) so a "nothing to pay" exit shows no snack; for the fee, `renew()` puts the new instructions in the controller state itself (no stream carries them); resuming `/verify/start/fee/pay` with no extra calls `checkFee` and, with no live payment, returns to S21.02 with no message.
- The seed adds both ledger entries the settler would write, not just the paid payment.

## Deferred minors (#203, not fixed)
- `feeWaived`'s `submittedAt` term is redundant on a `rejected` record that was submitted; fix the doc comment in `verification.ts` to say so.
- `FirestoreVerificationTx` writes at once (`tx.set`) while the event adapter queues, and `MemoryVerificationStore` returns staged writes; the fee use cases do all reads before writes, which Firestore requires. Add a comment or queue the writes. Cost if wrong: a future use case that writes before reading fails only on Firestore.
- Two concurrent first fee taps are serialised only by the `payments` query; always touching the verification document in `startVerificationFee` would serialise them. Cost if wrong: two live codes for one attempt (the second is refunded as duplicate if both are paid).
- The integration test variable `noRecordCheck` really tests "not a provider"; rename.
- `checkVerificationFee` has no `checkoutGatewayAvailable` gate (harmless: it only reads and settles).
- `FakeVerificationRepository.startIdentity` ignores `feeWaived` (it checks `feePaidAt` only), so the fake diverges from the server after `7846f21`; fix in the final fix wave.
- `_resumeFee` re-checks `_seeded` only before the await (harmless).
- A waived record that reaches the fee routes by a direct link sees "Đã nhận phí xác minh" although nothing was paid.

## Written, not run (#203)
- **Functions integration suite** (`test/integration/verification.test.ts`, the fee path: identity refused until paid, bank QR payload `000201…`, reuse on a second tap, check, `confirmFakePayment`, the `fee_charged` and `payment_received` entries, a second method refused). It depends on emulator behaviour the sandbox cannot start; CI runs it on push.
- **Rules test** ("the payer cannot read or forge a verification fee payment, its refund or ledger entry, or set `steps.fee`", `app_flutter/firebase/rules-test/rules.test.mjs`): `node --check` passes, not run.
- Ran clean: domain 1324/1324 (and lint), Functions unit 498/498 (and build), the Flutter verification, data, payment, app, settings and other folders touched by the flag flip, `flutter analyze`.

## Deploy note (#203)
1. **The server and app flags flip in this PR**: `feeRequired` is true in `liveVerificationDeps()` and in `verificationFeeRequiredProvider`. **Deploy Functions before shipping the app build that shows the fee step**, so the new callables and the fee settler exist when the app calls them; an old server with the new app answers `not_found` on the fee callables.
2. **Tasks 11 and 12 must ship together** (server `feeRequired` true, app flag true). On this branch the server was true while the app was still false between those two commits; only the pair is safe to release.
3. Functions deploy only behind `BLAZE_ENABLED` (owner keeps it off, 2026-10-09), so until it is on the fee runs on the emulators and the fake gateway; the callables answer `not_eligible` on a project without a checkout gateway. The real payment intermediary and the e-invoice for the fee are still Deferred.
4. No new secret, service, index or rules change: `payments`, `refunds` and `ledger_entries` stay closed, and `verifications` stays server-written.

## Mock follow-ups (#203; the mock was not edited)
- `#S21.02-fee`: the caption says "Trả xong tự sang bước danh tính", but the app returns to S21.02, where the identity row is "Đang làm" and "Tiếp tục" opens it (ruling 7). Change the caption.
- `#S21.02-rejected`: the frame shows only "Còn 1 lần gửi lại miễn phí"; add the 0 variant "Hết lượt gửi lại miễn phí · gửi lại cần trả phí xác minh mới" that the app shows when no free resubmit is left and the fee is on.
- The mock has no frame for the fee paid line `verifyFeePaid` ("Đã nhận phí xác minh") on S21.02-fee or the snack on return from S04.04.
