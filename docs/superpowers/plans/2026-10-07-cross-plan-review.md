# Cross-plan review: 23 plans of 2026-10-07

Worktree `.worktrees/plans-1007`, branch `plan/plans-2026-10-07`, folder `docs/superpowers/plans/`. File names are shortened (`s04` = `2026-10-07-s04-booking-payment.md`, `s05r` = `…-s05-tomato-brick-reviews.md`, `s05d` = `…-s05-delivery-two-layer.md`, `s13c` = `…-s13-instant-customer.md`, `s13p` = `…-s13-s14-dispatch-provider.md`, `s15` = `…-s15-s16-job-posts.md`). `file:N` = line N. Read-only review; no plan was edited.

Severity: **Blocking** = would break the build (duplicate export, missing symbol) or produce two incompatible implementations; **Major** = rework likely; **Minor** = small fix or wording.

Counts: **13 Blocking, 18 Major, 14 Minor.**

## Checks on the controller's reconciliations

| Reconciled item | Holds? |
|---|---|
| Shared uploader `MediaUploader.upload(image, storagePath:, purpose:)`, `ImagePurpose`, `jpegUpTo` (S10) | Holds in s05d, s07, s18, s21. **Not in s15** (finding 23). |
| Ready flags in S09 (`verifyStartReadyProvider`, `studioRoutesReadyProvider`, `savedListsReadyProvider`) | Holds in s09, s19, s21, s26. **Not in s06** (finding 1). |
| One `AccountNameLookup` port in `account_lookup.ts` (S06 shape) | Port holds in s06 and s22. **The fake class does not** (finding 8). |
| Contact filter `findContactLeak` shared by S15–S16 and S27 | **Does not hold**: s27 still uses `findContactInfo(): boolean` (finding 2). |
| S27 keeps collaborator fees off the booking (`collab_jobs`) | Holds in s26:59, 95 and s27:63, 107–110. |

## Findings

### Blocking

**1. Two `verifyStartReadyProvider` definitions.**
- Where: s06:68, s06:240 (`features/verification/verification_routes.dart`, with `verifyStartPath`), s06:644 ("Produces: verifyStartReadyProvider (false)"), s06:654, s06:667; s09:32, 89 (`features/settings/settings_links.dart`); s21:503–505 (flips the s09 one and says "#134's S06.02 button reads it too").
- Conflict: s06 still creates its own provider in another file. Two global providers with the same name means ambiguous imports, and S21 flips only one of them.
- Fix:
  - s06 Decision 17, Contract line 240 and Task 9 "Produces": replace "create `verifyStartReadyProvider` in `features/verification/verification_routes.dart`" with "read `verifyStartReadyProvider` from `lib/features/settings/settings_links.dart` (#148); if #148 has not merged, create it at that path with `false`".
  - Keep `verifyStartPath` as a constant in the same file, or drop it and use the literal `/verify/start` as s09 does.

**2. Contact filter: two signatures for one module.**
- Where: s15:67 and s15:166 (`findContactLeak(text): 'phone'|'email'|'link'|'zalo'|null`), s15:445–456 (regexes), s15:336 (stale Review Focus still says "`findContactInfo` table"); s27:71, 116 (`findContactInfo(text): boolean` + local `hasZaloWord`), s27:597, 602, 619.
- Conflict: whichever plan lands second finds a module whose export it does not expect. Both plans also claim "exactly as the other specifies".
- Fix:
  - s27 Decision 11, Contract line 116 and Task 2: `findContactLeak(text) !== null` instead of `findContactInfo(text)`. Drop `hasZaloWord`, since `findContactLeak` already returns `'zalo'`. Copy the s15 test table.
  - s15:336: rename the stale `findContactInfo` to `findContactLeak`.

**3. `supportEmail` defined twice in `lib/core`.**
- Where: s18:60, 257–258, 502 (`lib/core/app_config.dart`: `const String? supportEmail` + `supportEmailUri()`); s21:28, 296, 470 (`lib/core/support_email.dart`: `const supportEmail = String.fromEnvironment(...)`, a `String`).
- Conflict: both files are exported from `core.dart`, so the name is exported twice (ambiguous export error). The types also differ (`String?` vs `String`).
- Fix: s21 Contract line 296 and Task 5 should read: "use `supportEmail`/`supportEmailUri()` from `lib/core/app_config.dart` (#142); if #142 has not merged, create that file exactly as s18 Contract §App specifies". Do not create `support_email.dart`.

**4. `PhotographerStatsPatch` exported twice from the domain.**
- Where: s02:96–101, 118, 151 (`discovery_stats.ts`); existing `packages/domain/src/review_stats.ts:3`, kept and extended by s05r:129–130.
- Conflict: `index.ts` uses `export *`, so the second declaration is a TS2308 compile error.
- Fix: in s02, rename to `DiscoveryStatsPatch` (Contract lines 96–101, 118, 151 and the Task 1/2 text).

**5. `distanceKm` exported twice.**
- Where: s13p:154 (`instant.ts`, haversine with R = 6371.0088); s15:175 (`job_eligibility.ts`).
- Fix: one shared `geo.ts` (`distanceKm`) in the domain, created by whichever plan lands first and imported by the other. Alternatively rename one of them (`jobDistanceKm`). Add this to both Contracts.

**6. `splitMilestones` exported twice with different signatures.**
- Where: s05d:146 (`milestones.ts`: `splitMilestones(net, shotAt): PaymentMilestone[]`); s15:72, 160, 284 (`job.ts`: `splitMilestones(price): {shoot, delivery}`, plus a Dart mirror).
- Conflict: TS2308 compile error. The two would also round independently.
- Fix:
  - In s15, rename to `milestoneAmounts(price)` (it feeds the `milestoneAmounts` field) in `job.ts` and in the Dart `job_rules.dart`.
  - Implement it as `{shoot: ⌊price·50%⌋, delivery: rest}`, the same rule as s05d:58.
  - Note that s05d's `splitMilestones` should read the percentages from `booking.terms.milestones` when present.

**7. `ProviderProfile` exported twice.**
- Where: s15:168–172 (new in `job_eligibility.ts`); existing `packages/domain/src/provider_ports.ts:4`; s26:191 also extends the existing one (`ProviderProfile.memberCount`).
- Fix: in s15, rename to `JobProviderProfile` (Contract and Tasks 2–3).

**8. Two `FakeAccountNameLookup` classes with different constructors and test numbers.**
- Where:
  - s06:62, 130–132, 171: a separate file `fake_account_name_lookup.ts`, `constructor(echoName: string | null)`; numbers ending 4321 → `TRAN VAN B`, 9999 → unsupported, 0404 → not_found.
  - s22:47, 124–131: inside `account_lookup.ts`, `constructor(nameFor: () => string)`; 0000 → not_found, 9999 → unsupported.
  - s06's `FakePayoutGateway` already uses "0000 → failed".
- Conflict: the port was reconciled but the fake was not. You get a duplicate export, or one plan's tests break on the other's fake.
- Fix:
  - One fake in `account_lookup.ts`, created by whoever lands first, with the s06 shape (`constructor(echoName: string | null)`) and the s06 numbers (4321, 9999, 0404).
  - In s22, drop the "0000 → not_found" rule, which collides with the payout gateway's 0000. Pass the caller's normalized display name as `echoName`.
  - Update s22:47 and :131, and s06:171 (file name).

**9. Dart `PayMethod` declared twice.**
- Where: s04:287–294 (`lib/core/payments.dart`, exported from `core.dart`: `bankQr | momo | zaloPay`); s27:313 (`lib/data/collab/collaboration.dart`: `enum PayMethod { bank, cash, other }`).
- Conflict: features import both `core/core.dart` and the collab data library, so the name is ambiguous.
- Fix: in s27, rename to `CollabPayMethod` (Contract line 313, `reportPaid` signature line 329, the CSV/sheet tasks).

**10. Job notifications defined twice (s15 vs s17).**
- Where:
  - s15:65 (Decision 13), 267–280 ("Notification hooks for #138" with its own `NotificationContent` shapes `{job, photographer, count}`, its own copy and dedupe keys such as `job_match_{jobId}`, `quote_accepted_{jobId}`); s15:280 says "#138 must not emit these types again".
  - s17:49 (Decision 1), 74–82 (content `{jobTitle, count, names}` etc., different copy), 115–122 (hooks `notifyQuoteNew` … `notifyQuoteNotSelected` with keys `job_match_{jobId}_{photographerId}`, `quote_accepted_{quoteId}`).
- Conflict: two `renderNotification` branches and content variants for the same 8 types. Each plan believes the other calls its code. The result is a duplicate union member or a duplicate switch case, and two different copies.
- Fix: s17 owns the copy and the hooks; s15 calls them.
  - s15 Decision 13, Contract §"Notification hooks for #138" and Tasks 2–4: replace `job_notifications.ts`, `sendQuoteNotices`, `sendMatchNotice`, `sendInviteNotice` and the copy table with "call s17's `notifyQuoteNew` / `notifyQuoteWithdrawn` / `notifyJobExpiring` / `notifyJobExpired` / `notifyJobMatch` / `notifyJobInvited` / `notifyQuoteAccepted` / `notifyQuoteNotSelected` from the triggers and sweeps after commit; if #138 has not merged, create those exact hook signatures and the s17 catalogue rows".
  - Then reconcile one copy. The s17 copy matches the mock S17.01 ("3 nhiếp ảnh gia đã báo giá…").

**11. Studio notifications defined twice (s26 vs s17).**
- Where:
  - s26:73 (Decision 23: all 13 types `booking/activity`; critical: `assign_overdue`, `change_answered`, `booking_reassigned`), s26:159 (`membershipNotices`), s26:180 (`studioBookingNotices`), s26:268–270 (own copy).
  - s17:54 (Decision 6: membership types `booking/system`, assignment `booking/activity`; only `assign_overdue` critical), s17:93–105 (different copy and fields, e.g. `assign_reminder {hours, day, start}` vs s26 "{deadline} … {service}"; `change_answered` outcomes include `reassigned`), s17:132–144 (`notifyStudio*`, `notifyBookingAssigned`, … hooks).
- Conflict: two catalogues with different tab, critical flag, copy and content fields.
- Fix:
  - In s26, replace Contract §Notifications and Decision 23 with "emit through s17's hooks (`notifyStudioInvite`, `notifyStudioJoinRequest`, `notifyStudioInviteAccepted`, `notifyStudioJoinApproved`, `notifyStudioRemoved`, `notifyStudioInviteExpiring`, `notifyBookingAssigned`, `notifyBookingReassigned`, `notifyAssignReminder`, `notifyAssignOverdue`, `notifyChangeRequested`, `notifyChangeAnswered`, `notifyAssignmentReturned`)".
  - `membershipNotices` / `studioBookingNotices` then become pure "which hook to call" deciders.
  - The owner picks one copy set. Copy and the critical list should come from one table, in s17.

**12. Chụp ngay notifications defined twice (s13p vs s17).**
- Where:
  - s13p:74 (Decision 20: adds `instant_round_ended`, `instant_no_match`, `instant_arrived`, `instant_finished`, `instant_cancelled`), s13p:246, s13p:425–434 (copy, including `instant_assigned` "Đã match với {name}" and `instant_missed` "Bạn đã bỏ lỡ một lời mời"), s13p:240 (`instantNotices` emits them all).
  - s17:83–84 (`instant_assigned {photographer, etaMinutes}` "${photographer} đã nhận chụp ngay", `instant_missed {}` with different copy), s17:123–125 (hooks `notifyInstantAssigned`, `notifyInstantMissed`). s17 does not know the five new types.
- Fix:
  - In s13p, emit `instant_assigned` and `instant_missed` through s17's hooks (or s17 drops its two rows and lists s13p as the owner of all instant copy).
  - Add the five new types to the s17 catalogue (s17:83–84, hooks table, `notification_visuals`, targets) so S17.01 has icons and targets for them.
  - Choose one copy for `instant_assigned` and `instant_missed`.

**13. s13p/s13c are written against the pre-#129 payment model; s04 removes it.**
- Where:
  - s13p:59 (Decision 5: `payments` doc, ledger `deposit_received`), s13p:135–137 (`PAY_METHODS`, `PayMethod`, `providerOfPayMethod` mapping zalopay/bank_qr → `vnpay` and momo → `momo`), s13p:218, 222–224 (`payUrl`, `handleInstantPayment`, `confirmFakeInstantPayment`, `checkInstantPayment`), s13p:255–256, 579–580 ("like `confirmFakeTicketPayment` / `checkTicketPayment`", "same policy as `resendTicketRefund`"), s13p:594 (refund resend in `runInstantSweep`).
  - s13c:41, 66, 97 (`openInstantPayment(...payUrl)`, `confirmFakePayment`, `checkPayment`), s13c:67 (`PayMethod`/`PayMethodPicker` from `core/widgets/provider_picker.dart`).
  - What s04 does to that model:
    - s04:97 moves `PAYMENT_PROVIDERS` to `['fake','ninepay','zalopay','vnpay','nganluong']`; `momo` is no longer a provider.
    - s04:141–160 replaces the port with `createPayment`, `queryPayment`, `refund` and `verifyWebhook`.
    - s04:173 drops `deposit_received`; s04:244 removes `confirmFakeTicketPayment` and `resendTicketRefund`.
    - s04:59 (Decision 19) sets one `confirmFakePayment` for all subjects; s04:327 renames `provider_picker.dart`.
    - s04:212–217 has `settleTransfer` dispatching only booking/ticket, and `reconcilePayments` re-sends every pending refund.
  - s22:43 (Decision 4) also assumes "#140 writes those payments through #129's settlement".
- Conflict: if s04 merges first (wave 1 below), s13p does not compile:
  - it uses missing gateway methods and a missing ledger type;
  - `providerOfPayMethod` returns `'momo'`, which is no longer a `PaymentProvider`;
  - bank-QR instant payments would have no `payUrl` and no VietQR;
  - instant refunds would be re-sent twice (`runInstantSweep` and `reconcilePayments`);
  - a webhook transfer for an instant payment would be `unmatched`.
- Fix:
  - Make s13p hard-depend on #129 and rewrite its money part on s04's model:
    - `PaymentMethod` from `payments.ts` (drop `PAY_METHODS`, `PayMethod`, `providerOfPayMethod`);
    - add `PaymentSubject 'instant_request'` to s04's settlement, either as a `settleInstantTransfer` branch in `settleTransfer` or as a third member of `SettlementDeps`;
    - return `PaymentInstructions` from `inviteInstant` (`{kind:'payment', instructions}`);
    - use s04's unified `confirmFakePayment({paymentId})` and `checkPayment` pattern (drop `confirmFakeInstantPayment` and `checkInstantPayment`, or keep them as thin wrappers);
    - ledger `payment_received`; refunds through s04's `dispatchRefund` rule, re-sent only by `reconcilePayments` (remove the resend from `runInstantSweep`).
  - In s13c, open S04.04 through s04's `openPayment(context, ref, subject: InstantPay(requestId), instructions)` (add a `PaySubject` variant in s04's `features/payment/`) instead of `openInstantPayment(payUrl)`. Add `PayMethodList`/`PayMethodPicker` from `pay_method_picker.dart`.

### Major

**14. Reviews notification: `review_new` (s05r) vs `review_tomato`/`review_brick` (s17).**
- Where: s05r:57 (Decision 5: keep `review_new` with payload `{customer, verdict, hits, day, text}`), s05r:71 (Needs the owner 2), s05r:135–148; s17:86–87, 126 (`notifyReviewVerdict` "called from `onReviewWrite` instead of `review_new`"), s17:148.
- Conflict: s05r (wave 2) keeps `review_new`, while s17 (wave 1) introduces the two types and expects #130 to switch.
- Fix: in s05r Decision 5, Contract §Trigger and Task 2: "if #138 has merged, call `notifyReviewVerdict` from `onReviewWrite` and stop emitting `review_new`; else keep Decision 5". Close Needs the owner 2 by pointing at s17.

**15. Delivery notifications have no emitter.**
- Where: s05d:62 (Decision 11: "None emitted here; … the data #138 needs"); s17:127–131 (hooks owned by "#130", "owning plans call the hook").
- Conflict: each plan expects the other to call `notifyDeliverySubmitted`, `notifyDeliveryRevisionRequested`, `notifyDeliveryApproved`, `notifyDeliveryAutoApproveSoon` and `notifyDeliveryExtraRound`. Nobody does, and nobody schedules the "auto-approve in 24 h" notice.
- Fix: in s05d Decision 11 and Tasks 2/4, call the five s17 hooks after commit:
  - `submitDelivery` → submitted;
  - `requestRevision` → revision_requested;
  - `approveDelivery` (customer or auto) → approved;
  - `answerExtraRound` → extra_round;
  - a new `bookingClock` step for `delivered` with `autoApproveAt − 24 h ≤ now` → auto_approve_soon, with a `autoApproveNoticeAt` marker.

  If #138 is not merged, create the hooks with s17's exact signatures.

**16. S21 verification fee is on the pre-#129 payment API.**
- Where:
  - s21:52 (Decision 4: idempotency `vfee_{uid}_{feeAttempt}_{provider}`), s21:181–185, s21:224–226 (`startVerificationFee {provider: 'momo'|'vnpay'|'fake'}` → `payUrl`; `confirmFakeVerificationFee`; `checkVerificationFee`), s21:25 (`PaymentGateway.createDepositIntent`), s21:267 (`startFee(PaymentProviderCode)`).
  - s04:13, 59, 141–160, 286 (`PaymentProviderCode` removed, unified `confirmFakePayment`, VietQR).
- Conflict: after #129 there is no `createDepositIntent` and no `PaymentProviderCode`. The fee screen's "Chuyển khoản QR" has no QR, and webhooks for `verification_fee` are unmatched.
- Fix: make s21 depend on #129 (wave 3 below) and use s04's model:
  - `startVerificationFee {method}` → `PaymentInstructions`;
  - `PaymentSubject 'verification_fee'` handled by `settleTransfer` (`escrowStatus 'released'`, payee `platform`);
  - the unified `confirmFakePayment`;
  - S04.04 (`openPayment` with a `VerificationFeePay` subject) and `PayMethodList` on S21.02-fee.

**17. Late payment for a provider who stopped accepting orders: s04 and s21 disagree.**
- Where: s04:49 (Decision 9: "`checkPayment`, webhook and reconciliation do not [re-check]; a late refusal would strand it"); s21:63 (Decision 15: the payment handler refunds 100% with `provider_not_accepting` and leaves the draft).
- Fix: the owner rules once. The default suggested here is s21's (refund, booking stays draft), because it does not strand money.
  - Write it into s04 Decision 9 as "settlement refunds 100% (`provider_not_accepting`) instead of moving a draft to `requested` when `acceptsOrders` is false".
  - In s21:63, point at s04's `settleBookingTransfer` as the single place.

**18. Dispute refund dispatch contradicts s04's refund rule; the index s18 relies on is removed by s04.**
- Where:
  - s18:53 (Decision 7: "a failed send leaves the refund `failed`/`manual`"; "ticket refunds left `pending` are re-sent by the existing event clock (`refunds (subjectType, status, createdAt)`)"), s18:25, 161–162 (`gateway.issueRefund`, `dispatchRefund(deps, refund, provider)`).
  - s04:48 (Decision 8: a throw keeps `pending`; re-sent by `reconcilePayments` under the same id), s04:53 (resend moves out of `runEventSweeps`), s04:281 (index `refunds (subjectType, status, createdAt)` removed), s04:155–157 (`refund(...)`, not `issueRefund`).
- Fix: in s18 Decision 7, Contract (`dispatchDisputeRefund`) and Task 2:
  - "use s04's `dispatchRefund`/`dispatchTicketRefund` (refund `kind: 'policy'`, `method`/`destination` from the payment); re-send is `reconcilePayments`'";
  - remove the reliance on the old index and on `issueRefund`.

**19. Disputes vs the two milestones: s18's window and money math are stale once s05d lands.**
- Where:
  - s18:47–48 (Decisions 1–2: dispute only `completed|reviewed` within `completedAt + 24 h`; freeze the payment-level `escrowStatus`), s18:53 ("held = payment.amount − Σ refunds"), s18:114–116, s18:136–137 (extension points).
  - s05d:58–59 (Decisions 7–8: windows `shot` → `shotAt + 24 h` for the `shoot` milestone and `approved` → `checkUntil` for `delivery`; `completed` happens after milestone 2 is released, so nothing is held at `completed`), s05d:66 (15c).
- Conflict: after s05d, s18's main booking path finds no held money (`not_eligible`) at `completed`. A split computed on `payment.amount − refunds` would include an already released shoot milestone.
- Fix: in s18 (wave 4, after s05d), make the s05d windows the primary rule:
  - `disputeWindow`: `shot` (shoot milestone), `approved` before `checkUntil` (delivery milestone), ticket as written;
  - `findSubjectPayment` freezes the milestone of the window (`disputeMilestone`);
  - `outcomeAmounts` uses the held milestone amount;
  - resolve releases or refunds that milestone.

  Keep the pre-milestone path only for payments without `milestones`.

**20. S22 deletion blockers miss states and sources added by other plans.**
- Where: s22:51 (Decision 12: `open_booking` = `requested|accepted|upcoming`; "studio (#136), job posts (#139) and instant (#140) add their blockers in their plans"); s05d:81 (`shot`, `delivered`, `revision_requested`, `approved`); s15, s26, s13p, s27 never mention deletion blockers.
- Conflict: a customer or photographer with a booking in delivery can delete the account. The deferred blockers are owned by nobody.
- Fix: in s22 (wave 5, after all of them), have Decision 12 and `AccountSnapshot` cover:
  - `open_booking` = every status except `draft|declined|expired|cancelled|completed|reviewed`;
  - open job posts or submitted quotes (#139);
  - an active instant request or job (#140);
  - active studio membership or open studio bookings (#136);
  - active collaborations or open `collab_jobs` (#151).

  Remove "add their blockers in their plans".

**21. Quote bookings bypass `createBookingDraft`, so they miss what other plans add there.**
- Where:
  - s15:525 (`createQuoteBookingDraft` in `quote_use_cases.ts`, its own path);
  - s04:50 (Decision 10: `draftExpiresAt`; the sweep ignores drafts without it);
  - s05d:55 (Decision 4: `revisionsIncluded` snapshot);
  - s26:58 (Decision 8: `isStudio`, `assignStatus`, `assignDeadline`…);
  - s20:47, 155–156 (`BlockGate` in `createBookingDraft`).
- Conflict:
  - quote drafts are never swept after #129;
  - studio quote bookings never ask for an assignee (S26 T-rules break);
  - revisions ignore `terms.revisions`;
  - a blocked customer can still buy a quote.
- Fix: in s15 Decision 9/10 and Task 3, build the quote draft through a shared `bookingDraftFields(...)` helper (or call `createBookingDraft` with an override) that applies:
  - `draftExpiresAt` (s04);
  - `revisionsIncluded = clamp(terms.revisions)` (s05d);
  - the studio fields (s26);
  - the `BlockGate` check (s20).

  Each of s04, s05d, s26 and s20 adds one line naming quote bookings in its Contract ("also applied by `createQuoteBookingDraft`").

**22. `BlockGate` is not called by the other order paths.**
- Where: s20:47 (Decision 2: quotes #139, Chụp ngay invites #140, studio assignment #136 "call the same `BlockGate`"), s20:155–161; s15:44, s13p:38/71, s26:43, s27:53 list only `ProviderOrderGate`.
- Fix:
  - Add to the Global Constraints of s15 (`submitQuote`, `inviteToJob`, `acceptQuote`), s13p (`inviteInstant`/offer creation, customer ↔ each invitee), s26 (`assignBooking`, customer ↔ assignee) and s27 (`applyToRecruitPost`, `inviteCollaborator`, collaborator assignment, studio ↔ collaborator and customer ↔ collaborator): "call `BlockGate.isBlockedEitherWay` (s20, `blocked`, `failed-precondition`) when #144 has merged".
  - Wave order below puts s20 before them.

**23. S15 job references bypass the shared image API.**
- Where: s15:76 (Decision 24: `pickImages(max, longSide: 1280)`, a new picker parameter), s15:129 (Storage `jobRefs/...` owner create < 8 MB `image/*`), s15:293, 634, 693; s10:24 (`purpose` required by type), s10:60 (Decision 12: new paths use `jpegUpTo`, never `image/.*`), s10:137.
- Conflict: after #147, `MediaUploader.upload` without `purpose` does not compile, and the Storage rule breaks the "JPEG only" rule.
- Fix:
  - s15 Decision 24 and Task 4/7: `MediaUploader.upload(image, storagePath: 'jobRefs/{uid}/{draftId}/{ulid}.jpg', purpose: ImagePurpose.share)` (1600 q80, ≤ 2 MiB, or add a `reference` purpose 1280 q80 to s10's table) and Storage `jpegUpTo(2 * 1024 * 1024)`.
  - Drop the `longSide` picker parameter.
  - Correct the cost line s15:367.

**24. S06 deletes the re-auth sheet that S22 needs.**
- Where: s06:59 (Decision 8: `showReauthSheet` and its strings removed), s06:604 (Delete `reauth_sheet.dart`); s22:74, 540, 543 (S22.02 deletion uses `showReauthSheet` on `reauth_required`).
- Fix:
  - In s06, move `reauth_sheet.dart` to `lib/features/account/widgets/reauth_sheet.dart`, or to core, instead of deleting it, and keep the `payoutAccountReauth*` keys renamed to `reauth*`. Alternatively s22 recreates it.
  - State the choice in both plans (s06 Task 8 "Delete", s22 Contract line 74).

**25. `settings_screen.dart` has seven editors and no single order.**
- Where:
  - s09:37 (Decision 12 mentions only s18's "Hỗ trợ" group and s15), s09:78–84;
  - s18:59, 334 ("Hỗ trợ" group);
  - s20:239 ("Người đã chặn" row, placement undefined);
  - s21:311, 503 (status subtitle and "Xác minh doanh nghiệp" row);
  - s22:53, 284 ("Thanh toán và dữ liệu" group);
  - s26:282, 492 (rows and subtitles);
  - s27:472–475, 875 ("Cộng tác", "Tin tuyển" rows).
- Conflict: every implementer will put its row somewhere, and the s09 tests assert group order ("groups appear in the mock order …").
- Fix: extend s09 Decision 12 and the `#S09.02-photographer` mock frame (Task 1) with the full target order and placeholder flags. For example:
  - Tài khoản (… Xác minh & nhận đơn, Xác minh doanh nghiệp, Studio của tôi | Thành viên studio, Cộng tác, Tin tuyển, Xem hồ sơ công khai);
  - Chế độ;
  - Giao diện;
  - Kiểu nút chính;
  - Thông báo;
  - Thanh toán và dữ liệu (Lịch sử thanh toán, Quyền riêng tư & dữ liệu, Người đã chặn);
  - Hỗ trợ;
  - Đăng xuất.

  Each later plan then only fills its slot, and the order test lists every group.

**26. S06.02 "closed" variant is built twice, with two key sets.**
- Where: s06:68 (Decision 17), s06:261 (`workClosedTitle/Body/Note/Start`); s21:311 (`workEmptyClosedTitle/Body/Meta/Action`, same texts), s21:503 (builds the variant "only if #134 has not merged" but still lists its own keys).
- Fix: in s21 L10n and Task 7, "reuse s06's `workClosed*` keys; add them under those names only if #134 has not merged".

**27. Star ratings still used after tomato/brick lands.**
- Where:
  - s13c:67 (consumes `formatRating`), s13c:158 (`waitingRowMeta` "★ {rating} · khoảng {minutes} phút");
  - s13p:77 (Decision 23: score from `stats.rating`, cards "★ 4,9"), s13p:110, 117, 157 (`ratingAvg` snapshots);
  - s05r:66 (Decision 14 swaps them only "when merged"; it does not mention s13c), s05r:183 (`formatRating` removed).
- Conflict: with the wave order below (s05r in wave 2, s13p in wave 4, s13c in wave 5), s13c's contract check fails on the missing `formatRating`. `stats.rating` is deleted on the first verdict, so s13p's score component and cards read 0.
- Fix:
  - In s13p Decision 23 and the presence/candidate fields, use `tomatoPct`, `reviewCount` and score component `(score + 1) / 2` (s05r:66), with the card meta through `MetaLine`.
  - In s13c, use `waitingRowMeta` "{pct}% · khoảng {minutes} phút" via `MetaLine`/`formatTomatoPct` and drop `formatRating`.

**28. S09 reuses names that already exist in the app.**
- Where: s09:61–70 (`MyPostsState`, `MyPostsController`, `myPostsProvider` in new `features/profile/my_posts_controller.dart`); existing `app_flutter/lib/features/album/my_albums_controller.dart` already declares `MyPostsController`, `MyPostsState` and `myPostsProvider` (family on `MyPostsFilter`, used by `edit_award_sheet.dart`, `add_posts_sheet.dart` …).
- Conflict: an ambiguous import wherever both are visible. Profile tab rows such as "Album của tôi" and the award nudge make that likely.
- Fix: rename in s09 to `OwnPostsState`, `OwnPostsController`, `ownPostsProvider`, `ownPostCountsProvider`.

**29. Notification targets of owner plans are not in the app allowlist.**
- Where: s17:56 (Decision 8), s17:185–188 (allowlist: query strings refused unless stated); s27:236 (`/recruit/{id}`, `/studio/recruit?post=…`, `/collab`, `/collab?offer=…`); s22:45, 294 (`/me/payments`); s21:70 (six verification types, no target named); s18:504 (`/disputes/{id}`, `/help/chat` added only "if that plan's file exists").
- Conflict: those rows open "Nội dung này không còn".
- Fix:
  - Each owner plan adds its targets to `safeTarget` and to s17's TypeScript port test: s27 (with the two query parameters explicitly allowed), s22, s21 (pick targets, e.g. `/verify/start`, `/verify/business`), s18 (unconditionally).
  - s17 Decision 8 lists them as "added by their owners".

**30. S06 payouts vs S05d milestones.**
- Where: s06:57 (Decision 6), s06:103, 157 (`createPayout` per item on `listDuePayees` = `escrowStatus == 'released'`, `PayoutItem {paymentId, amount, fee, tax, net}`); s05d:58, 89, 153, 180 (`payableAmount`, `PayoutItem.milestone`, index `payments (payeeId, payableAmount)`; aggregate `escrowStatus` is `held` while the delivery milestone is held).
- Conflict: with s06 first and s05d second, s05d must rework s06's new `runDailyPayouts`/`createPayout`. Otherwise the shoot milestone of a payment whose delivery milestone is still held is never paid (the aggregate stays `held`).
- Fix: s05d Task 3 Step 1 already checks #134. Add explicitly:
  - "switch `listDuePayees` and `listPayablePayments` to `payableAmount > 0`;
  - `runDailyPayouts` builds one `PayoutItem` per released milestone, with `payoutLineOf(gross = milestone.amount)`;
  - pin a test 'shoot milestone paid while delivery held'".

  s06 Decision 15 should name s05d as the owner of that change.

**31. S22 refund-account wait vs S18 dispute refunds.**
- Where: s22:44 (Decision 5: every policy refund of a `bank_qr` payment starts `awaiting_account`; `applyRefundToPayment` changes, s22:154–155); s18:53 (dispatches right after commit).
- Conflict: after both land, a dispute refund either waits silently or is dispatched while `awaiting_account`.
- Fix: in s22 (wave 5), "dispute outcome refunds (`resolveDispute`) follow Decision 5 too; `dispatchDisputeRefund` skips `awaiting_account`; the S22.04 sheet is reachable from S18.02 ('Chọn tài khoản nhận hoàn')". Add the case to s22 Review Focus 1.

### Minor

**32. `settingsStudioMembersBody` defined twice with different text.**
- Where: s09:97 ("Mời thợ, giao việc cho thành viên"); s26:282 ("{n}/{max} thợ").
- Fix: s26 changes the value in place ("changed value" list), or uses a new key `settingsStudioMembersQuota`.
- Same-text duplicates to add only if absent: `settingsMyStudio`, `settingsStudioMembers` (s09:97, s26:282); `settingsVerify` (s09:97, s21:311); `workAssignedBy` (s06:261, s26:280); `earningsMilestones`/`earningsMilestonesAll` (s05d:259 already conditional).

**33. Duplicate keys for the same S09.01 counts.**
- Where: s09:96 (`profileFollowingCount`, `profileSavedCount`); s19:152 (`profileCountFollowing`, `profileCountSaved`, same texts).
- Fix: s19 reuses the s09 keys and adds only `profileCountFollowers`.

**34. `findTomatoTitle` text differs.**
- Where: s02:218 ("% cà chua tối thiểu"); s05r:212 ("Tỷ lệ hài lòng").
- Fix: s02 keeps "add only if absent" and uses s05r's text.

**35. Photographers composite index edited by two plans.**
- Where: s02:161 (replaces the `stats.rating` index with `(acceptingOrders, stats.nextFreeDate, stats.reviewCount desc)`); s05r:64, 152 (changes the same index to `stats.score`).
- Fix: s02 Task 2 also matches the `stats.score` variant (s05r lands first in the waves below).

**36. Clock steps and `handleBookingClock` signature.**
- Where:
  - steps added to `bookingClock`: s05d:176, s13p:56, s15:66/265, s21:66, s26:70, s27:260;
  - steps added to `eventClock`: s04:53/276, s17:173–177, s22:222;
  - s17:174 still returns `refundsResent` from event sweeps, which s04:53 moves into `reconcilePayments`.
- Conflict: each plan changes the signature (extra deps) and step order independently.
- Fix:
  - One line in each plan: "add your step as a named entry of the `handleBookingClock` step list, each in its own try/catch, after the existing steps; do not change existing parameters, pass new deps through a `ClockDeps` object".
  - s17 drops `refundsResent` if #129 has merged.

**37. "7th Scheduler job" claimed twice.**
- Where: s02:64 (`rollNextFreeDates`); s06:287, 667 (`createPayouts`).
- Fix: both say "one more Scheduler job (+$0.10)". The total becomes 8 jobs.

**38. Booking notification copy differs between s04 and s17.**
- Where: s04:410 ("Đã hoàn ${percent}% số đã trả", `refund_done` "Tiền hoàn buổi chụp #${code} …"); s17:107 (mock S17.01: "số bạn đã trả", "Tiền buổi chụp #… đã về tài khoản của bạn.").
- Fix: s04 uses the mock text; s17 Decision 7 then keeps it.

**39. Two OTP input widgets.**
- Where: s06:247 (core `OtpCodeField`); s21:367 (S21.01 six boxes built in the feature).
- Fix: s21 Task 6 reuses `OtpCodeField` if #134 has merged, else creates it in core with s06's signature.

**40. Milestone net vs `policyRefundTotal`.**
- Where: s05d:58 (`net = amount − refunded`); s04:46, 175 (subtract policy refunds only).
- Fix: s05d Decision 7 reads `net = amount − policyRefundTotal(refunds)`.

**41. `Chat` mapping round-trip.**
- Where: new `Chat` fields come from s07 (`bookingStatus`), s15:127 (`jobId`, `startedBy`, `customerRepliedAt`, `photographerMessagesBeforeReply`), s20:70 (`blockedAt`), s26:66 (`assigneeId`), s27:110 (kind `collab`) and s13p (`syncInstantChat`).
- Fix: each plan extends one shared round-trip test in `test/unit/chat_firestore.test.ts` (as s20 Review Focus 1 does). Same for `bookingToFirestore` (s05d Review Focus 3, s18:58, s22, s26, s27).

**42. Two names for the same refusal.**
- Where: s21:211, 236 and s26:192, 218, s27:70 (`rate_limited`); s06, s18, s20, s15 (`limit_exceeded` for daily caps).
- Fix: accept, but say so in s26 and s27 (which reuse s21's code). No change needed in code.

**43. Ticket primer and the new ticket payment flow.**
- Where: s17:57 (primer when the tickets tab opens with `highlight` after registration); s04:55 (bank-QR tickets now go through S04.04 first).
- Fix: s17 Task 5 also asks the primer when S04.04 completes a `TicketPay`, or s04 lands the user on `/bookings?tab=events&highlight=` after payment.

**44. Report sheet key namespace.**
- Where: s05d:257 (`reportTitle`, `reportMissing`, `reportOther` "Lý do khác" …); s20:237 (`reportTitleUser`, `reportReasonOther` "Lý do khác" …).
- Fix: s05d prefixes its fallback keys `deliveryReport*` to avoid confusion with S20.

**45. S06 assigned-bookings stream vs s26's.**
- Where: s06:234–237 (`watchAssignedBookings`, `assignedBookingsProvider`, `myWorkBookingsProvider`); s26:255 (`assignedBookingsStreamProvider`); s26:492 reuses s06's when merged.
- Fix: s26 Contract line 255 says "use s06's `assignedBookingsProvider` if present" (it does so only in Task 8 today).

## Dependency graph

Declared hard edges:
- s05d → s05r
- s05d Tasks 4 and 7 → s10
- s13c → s13p
- s22 → s04
- s26 → s05r + s05d
- s27 → s26, s21, s05r
- s18 Tasks 3 and 6 → s10
- s02 Task 7 → s05r (skippable)
- s07 Task 6 → s10 (skippable)

Declared soft edges:
- s05d after s04 and s06 (adapts either way)
- s15 ~ s04, s05r/s05d
- s19 after s09 and s02
- s20 after s07, s09, s18, s19
- s21 after s10 and s09
- s26 after s21
- s18 after s04/s05d and s09
- s06 reads s04/s05d/s21/s26 outputs

Edges proposed by this review:
- s13p → s04 (13)
- s21 → s04 (16)
- s18 → s04 + s05d (18, 19)
- s15/s26/s13p/s05r/s05d → s17 (10–15)
- s15/s13p/s26/s27 → s20 (22)
- s09 → every plan editing settings (25)
- s10 → s15 (23)

**Cycles:** none hard. The soft pairs marked "whichever lands first" (s15↔s27 contact filter, s06↔s22 lookup, s05d↔s18 dispute window, s05d↔s06 earnings fields) are exactly where findings 2, 8, 19 and 30 came from. Fixing their texts as above removes the ambiguity.

## Execution waves

Plans in one wave run in parallel on separate machines. Waves are chosen so no two plans in a wave rewrite the same function or screen. Append-only shared files will still get mergeable conflicts: `app_vi.arb`, `notification*.ts`, `firestore.rules`, `firestore.indexes.json`, `index.ts`, `router.dart`, `screen_codes.dart`, `ui-mock.html`.

| Wave | Plans (issue) | Why here |
|---|---|---|
| 1 | s04 (#129), s10 (#147), s09 (#148), s17 (#138, after findings 10–15 are applied), s01 (#149), s08 (#146), s25 (#145) | No dependencies. These are the foundations others consume: payment model, image API, settings and flags, notification catalogue and hooks. s17 leaves the booking copy to s04 (finding 38). |
| 2 | s05r (#130 reviews), s07 (#131), s06 (#134) | s05r unblocks the longest chain (s05d → s26 → s27). s07 needs s10 for Task 6. s06 needs s04's ledger types and lands before s05d, s21 and s22. Kept apart from s02 (same summary, Find and index) and from s20 (same chat files). |
| 3 | s05d (#152 delivery), s02 (#132), s21 (#135), s20 (#144) | s05d needs s05r, s10, s04 and s06. s02 runs Task 7 on the tomato data. s21 needs s04, s06, s09 and s10. s20 needs s07 and s09, and must precede the plans that call `BlockGate`. |
| 4 | s13p (#140 dispatch), s15 (#139), s26 (#136), s18 (#142), s19 (#143) | s13p needs s04, s05r, s17 and s20. s15 needs s04, s10, s17 and s20. s26 needs s05r, s05d, s21 and s20. s18 needs s04, s05d, s09 and s10. s19 needs s09 and s02. s15 and s26 both touch booking drafts: apply finding 21 so the second adds the other's fields. |
| 5 | s13c (#140 customer), s27 (#151), s22 (#141) | s13c needs s13p. s27 needs s26, s21 and s15 (contact filter, S06.01 tabs). s22 needs s04, s06 and s18, and lists blockers of every earlier plan (finding 20). |

## Cost summary ("Chi phí Google", USD/month added)

| Plan | (b) 1,000 MAU | (c) 10,000 MAU | Main item |
|---|---|---|---|
| s01 entry | 0 | 0 | — |
| s02 discover | **−1.4** | **−24.5** | Find pool cache. Added items at (c) about $10: search $3.60, "Rảnh tuần này" $2.76, Functions $2.30. |
| s04 payment | +0.02 | +0.08 | reconciliation reads |
| s05r reviews | 0 | 0 | — |
| s05d delivery | +0.46 | +4.6 | egress $1.80, watermark CPU $1.73, storage $0.70 |
| s06 earnings | +0.12 | +0.30 (+3 once real SMS OTP) | Scheduler $0.10 |
| s07 chat | **−0.57** | **−5.7** | unread listeners instead of N+1 gets |
| s08 setup | 0 | 0 | — |
| s09 profile | +0.25 | +2.50 | full-size cover egress $1.20, reads $1.20 |
| s10 upload | **−26** | **−262** | compression egress saving |
| s13c instant customer | +0.02 | +0.19 | Home `get` |
| s13p dispatch | +0.10 | +1.3 | Firestore $0.73, Functions $0.50 |
| s15 jobs | +0.22 | +3.0 | S16.02 reads $0.84, reference egress $1.44 |
| s17 notifications | +0.01 | +0.04 (+0.10 with hooks) | `event_soon` |
| s18 disputes | +0.02 | +0.15 | — |
| s19 saved | +0.31 | +3.1 | feed-boost reads |
| s20 report/block | +0.02 | +0.16 | gate reads |
| s21 verification | +0.01 | +0.02 + **SMS ≈ $13.5** (range $0–58) | S21.01 phone OTP SMS |
| s22 payments/account | +0.10 | +0.85 | S22.01 listener, exports |
| s25 awards | 0 | +0.03 | — |
| s26 studio | +0.05 | +0.40–0.45 | studio profile reads |
| s27 recruiting | +0.03 | +0.4–0.6 | fan-out |
| **Sum of additions** | **≈ +1.74** | **≈ +17.4 without SMS; ≈ +30.9 with S21 SMS (+3 with S06 SMS later)** | |
| **Sum of savings** (s02, s07, s10) | ≈ −28.0 | ≈ −292.2 | |
| **Net** | **≈ −26.2** | **≈ −275 without SMS; ≈ −261 with SMS** | |

Largest added items at (c):
1. S21 SMS ≈ $13.5 (up to $58). This is above the $5 threshold. Its mitigations (domestic brand-name SMS or Zalo ZNS) are owner decisions.
2. s05d ≈ $4.6.
3. s19 ≈ $3.1.
4. s15 ≈ $3.0.
5. s09 ≈ $2.5.
6. s02's gross additions ≈ $10, netted against its own Find saving.

Inconsistent assumptions between plans:
- **Functions free tier at (c).**
  - Charged as used up: s02 ($2.30), s13p ($0.50), s15 ($0.49), s05d (watermark CPU).
  - Assumed free: s04, s06, s17, s18, s19, s20, s21, s22, s26, s27 (s27 notes "+$0.2 if used up").
  - Pick one rule in the cost spec §12 and restate it in every plan.
- **Scheduler.** s02 and s06 each claim the "7th job" (finding 37). Both cost $0.10, so the total is 8 jobs, +$0.20.
- **`bookingClock` runs per month.** s27 uses 2,976 (31 days); everyone else uses 2,880 (30 days). The difference is negligible but inconsistent.
- **Egress overlap.**
  - s10 counts all image views, including chat (5%) and portfolio/feed (45%), in its −$262 saving.
  - s07 (+$1.08 chat egress) and s09 (+$1.20 grid egress) add egress for some of the same images.
  - The parts are not double-counted exactly, but the baselines differ: s07 assumes 500 KB/photo without #147, while s10 assumes 650 KB.
- **Unit prices.**
  - Consistent across plans: Firestore $0.06/100K reads, $0.18/100K writes, $0.02/100K deletes (nam5 upper bound, Singapore "chưa xác nhận"), Storage $0.020/GB, egress $0.12/GB (assumed).
  - Only s10 notes that the 100 GB/month free download may apply to the bucket, which would change (b) from −$26 to about −$14.
  - SMS $0.15 in both s06 and s21, but s21 also applies the "10 free/day" Firebase Auth allowance and s06 does not.

## Resolution (2026-10-07)

Applied to `docs/superpowers/plans/2026-10-07-*.md` in worktree `plans-1007` (branch `plan/plans-2026-10-07`), not committed. `s03-orders-closed` untouched. `2026-10-07-studio-recruiting-design.md` unchanged (no finding required it; its §5 "Lịch bận: chặn lịch của CTV từ lúc chấp nhận" already matches the owner's capacity decision). Every plan header now has **Execution wave**, **Blocked by** (hard/soft, with "if not landed, create exactly as defined there") and, where relevant, **Owns**. Every plan's "Chi phí Google" carries the same Functions sentence (free tier at (b); at (c) the app already exceeds it, so Functions work is priced at Tier 2), and the Scheduler count is 8 jobs (s06 `createPayouts` = 7th, s02 `rollNextFreeDates` = 8th).

Result: **45 / 45 FIXED** (13 Blocking, 18 Major, 14 Minor; finding 42 fixed as text only, as the finding asks). Nothing DEFERRED.

### Blocking
1. FIXED — s09 owns `verifyStartReadyProvider` in `lib/features/settings/settings_links.dart` (header Owns); s06 Decision 17 and s21 consume it.
2. FIXED — s15 owns `contact_filter.ts` / `findContactLeak` (Decision 15, header Owns); s27 Decision 11 consumes it.
3. FIXED — s21 owns `lib/core/app_config.dart` (`supportEmail`, `supportEmailUri`; definition in s21); s18 Decision 14 consumes it.
4. FIXED — s02 renames its patch to `DiscoveryStatsPatch` (no second `PhotographerStatsPatch`).
5. FIXED — `geo.ts` `distanceKm` created by s13p (Decision 12, wave 4 first in file order); s15 Decision 5 consumes it.
6. FIXED — s05d owns the milestone model (`percents`, `milestoneAmounts`, Decision 7, header Owns); s15 Decision 20 consumes; no second `splitMilestones`.
7. FIXED — s15 uses `JobProviderProfile`.
8. FIXED — s06 Decision 11 creates `account_lookup.ts` with the one `FakeAccountNameLookup(echoName)` (4321 / 9999 / 0404); s22 Decision 8, Contract and Task 3 consume it (no `0000` rule, no second fake, caller's normalised name as `echoName`).
9. FIXED — s27 renames to `CollabPayMethod`.
10. FIXED — s15 Decision 13 + Notifications contract (8 jobId-keyed signatures); s17 hooks table re-keyed to them; s17 copy wins.
11. FIXED — s26 Decision 23 calls s17's 13 studio hooks; s17 copy and critical flags win.
12. FIXED — s13p Decision 20 (7 hooks, its copy moved to s17); s17 catalogue replaces `instant_assigned`/`instant_missed` copy and adds 5 types, hooks, targets `/instant/:id`, `/work/instant`, `/work/instant/:id`, `/work/instant/offer/:id`.
13. FIXED — s04 Decision 22 (extension point: `SubjectSettler`, `newSubjectPayment`, `issuePaymentInstructions`, `checkSubjectPayments`, `expireUnpaid`, `sendRefundOnce`, `mergeRefundOutcome`); s13p Decision 5 (InstantPaymentSettler, no own confirm/resend), s13c Decision 1 (`openPayment(InstantPay)`), Decision 2 (`PayMethodPicker`).

### Major
14. FIXED — s05r Decision 5 calls `notifyReviewVerdict`, stops `review_new`; s17 Decision 12.
15. FIXED — s05d Decision 11 is the only emitter (`deliveryNotices` in `onBookingWrite`, clock step `remindAutoApprovals` with `autoApproveNoticeAt`); s17 Decision 13.
16. FIXED — s21 Decision 4 puts the fee on s04's model (`VerificationFeeSettler`, `startVerificationFee` → `PaymentInstructions`, unified `confirmFakePayment`, `VerificationFeePay`).
17. FIXED — s04 Decision 9: settlement refunds 100% `provider_not_accepting`; s21 Decision 15 points to it.
18. FIXED — s18 Decision 7: dispute refunds go through s04's dispatch rule (`sendRefundOnce` + `mergeRefundOutcome`, `reconcilePayments` resend), no reliance on the removed index.
19. FIXED — s18 Decisions 1/2/7: dispute freezes the shoot or delivery milestone (legacy payment whole), money math on `policyRefundTotal`.
20. FIXED — s22 Decision 12, `AccountSnapshot`, `BLOCKER_KINDS`, l10n, Task 4 tests and `ACCOUNT_DATA_MAP`: `open_booking` = every status except draft|declined|expired|cancelled|completed|reviewed; open job posts / submitted quotes (#139); active instant (#140); studio relation and assigned studio bookings (#136); collaborations / open `collab_jobs` (#151). "Add their blockers in their plans" removed.
21. FIXED — s04 Decision 23 `buildBookingDraft(BookingDraftInput)`; s15 Decision 1, s05d Decision 4, s26 Decision 8 build through it.
22. FIXED — s04 Decision 23 `orderBlocker`/`assertOrderAllowed` (`OrderGateDeps {providers; blocks?}`); s20 Decision 2 plugs `BlockGate` in; s13p Decision 17, s15, s26 Decision 10, s27 Decision 13 call it.
23. FIXED — s10 Decision 12 (`jobRefs` share, 2 MiB); s15 Decision 24 uses `MediaUploader`.
24. FIXED — s06 Decision 8 moves the sheet to `lib/features/account/widgets/reauth_sheet.dart` (keys `reauth*`); s22 Contract and Task 8 consume it.
25. FIXED — s09 Decision 12 `settingsGroupOrder` + one order test; rows/slots placed in s06, s18 (support), s20, s21, s22 (`paymentsData`), s26, s27.
26. FIXED — s21 reuses s06's `workClosed*` keys.
27. FIXED — tomato names: s05r Decision 14 (later plans use them); s13p Decision 23, s13c, s15 Decision 21, s02 `findTomatoTitle`.
28. FIXED — s09 `MyPosts*` → `OwnPosts*`.
29. FIXED (owner choice differs from the suggested split) — s17 owns `safeTarget` for every owner (Decision 8 lists all targets including `/studio/recruit?post=` and `/collab?offer=` as the only query targets; Task 4 tests); emitter plans (s18, s21, s22, s27, s06, s13p) name their targets and do not edit `notification_targets.dart`. One owner per shared file, per the coordinator's principle.
30. FIXED — s05d Task 3 Step 1 (`payableAmount > 0`, one `PayoutItem` per released milestone, test "shoot milestone paid while delivery held"); s06 Decision 15 names s05d as owner.
31. FIXED — s22 Decision 5 (dispute refunds follow the 24 h window; `dispatchDisputeRefund` skips `awaiting_account`; `DisputeRefund` subject; S18.02 entry in Task 6), Review Focus 1 and Task 3 test; s18 Decision 7 already says the same.

### Minor
32. FIXED — s26 uses `settingsStudioMembersQuota`; same-text keys "add only if absent".
33. FIXED — s19 reuses `profileFollowingCount` / `profileSavedCount`.
34. FIXED — s02 `findTomatoTitle` "Tỷ lệ hài lòng" (s05r's text).
35. FIXED — s02 index on `stats.score` with `ensureScore`.
36. FIXED — clock rule in s04 Global Constraints (named step, own try/catch, `BookingClockExtras`/`EventClockExtras`), one line in s05d, s13p, s15, s18, s21, s22, s26, s27, s17; s17 Decision 14 drops `refundsResent`.
37. FIXED — s06 = 7th Scheduler job, s02 = 8th, both "+$0.10".
38. FIXED — s04 server copy = mock text ("số bạn đã trả", "Tiền buổi chụp #… đã về tài khoản của bạn."); s17 Decision 7.
39. FIXED — s06 owns `OtpCodeField`; s21 reuses it.
40. FIXED — s05d Decision 7, s13p Decision 7, s15 use `policyRefundTotal`.
41. FIXED — shared tests `chat round-trips every field` (s07 creates; s13p, s15, s20, s26, s27 extend) and `booking round-trips every field` (s04 creates; s05d, s15, s18, s22, s26, s27 extend).
42. FIXED (text only, as asked) — s26 Decision 25 and s27 Decision 10 state they reuse s21's `rate_limited`; `limit_exceeded` stays for daily caps.
43. FIXED — s04 Decision 15 lands a paid ticket on `/bookings?tab=events&highlight={regId}`; s17 Decision 9 + Task 5 test.
44. FIXED — s05d `deliveryReport*` keys.
45. FIXED — s06 owns `assignedBookingsProvider`; s26 Contract consumes it.

### Owner decisions 2026-10-07 (recorded as "Owner 2026-10-07", removed from "Needs the owner")
1. Studio capacity = one booking per free member per day — s26 Decision 26 (`studio_day_load/{studioId}_{day}`, `full` day state "Hết chỗ" in the S04 date step, task + the four named tests); s27 Decision 26: collaborators count only after acceptance.
2. Chụp ngay commission 100% to the photographer, `platformFeeBp` config (default 0) — s13p Decision 6, s13c Decision 8.
3. Arrived-cancel split from config `instantArrivedCancelPhotographerPercent` (default 50, seed 50, snapshotted on the request) — s13p Decision 9, s13c Decision 8; S13.08 shows server dry-run amounts.
4. 30-day restore window — s22 Decision 11 (`deletion_pending`, `restoreUntil`, sessions revoked, hidden via `deletionPending`, S22.05 "Khôi phục tài khoản" / "Tiếp tục xoá" with mock frame in Task 1, purge started by a step of the existing daily `pruneNotifications`, `onAccountDeletionUpdated` purge, export interplay, S22.02 copy, cost, Review Focus 6).

### Final execution waves
| Wave | Plans |
|---|---|
| 1 | s04 (#129), s10 (#147), s09 (#148), s17 (#138), s01 (#149), s08 (#146), s25 (#145) |
| 2 | s05r (#130 reviews), s07 (#131), s06 (#134) |
| 3 | s05d (#152 delivery), s02 (#132), s21 (#135), s20 (#144) |
| 4 | s13p (#140 dispatch), s15 (#139), s26 (#136), s18 (#142), s19 (#143) |
| 5 | s13c (#140 customer), s27 (#151), s22 (#141) |

Cost lines changed by the Functions rule or by the fixes (USD/month, (b) / (c)): s04 +0.02 / ≈ +0.15; s05d +0.30 / +4.7; s06 (c) +0.33; s15 +0.30 / +3.7; s17 +0.01 / +0.07 (≈ +0.20 with all hooks); s18 (c) +0.19; s19 (c) +3.2; s21 (c) +0.04 + SMS; s22 +0.10 / +0.91; s26 +0.06 / +0.55–0.60; s27 (c) ≈ +0.6. Other rows of the cost summary above are unchanged.
