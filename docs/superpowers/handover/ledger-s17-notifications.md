# Handover ledger — plan S17 notifications: full catalogue, hooks, event reminder, ticket primer (issue #138)

Plan: `docs/superpowers/plans/2026-10-07-s17-notifications.md`, Tasks 1–6. Branch `plan/138-s17-thong-bao` (the plan text says `plan/138-s17-notifications`; the claimed name wins). Merge base 2cd64a0; commits fe020ef (mock), 478dec0 and a976693 (domain), 72aaf27 (functions), 3f3a8ab and d990315 (app), then the docs commit of Task 6.

## Built
- Mock (Task 1): frame `#S17.03-ticket` in `docs/design/ui-mock.html` (the primer sheet over the tickets tab after buying a ticket; ruling 2 keeps the "Photo walk" tag) and one sentence on the S17.01 caption about grouped quote rows and the event reminder.
- Domain (Task 2): `NOTIFICATION_TYPES` meta for 50 new types (instant ×5, `review_tomato`/`review_brick`, `delivery_*` ×5, studio ×6, assignment ×7, payout account ×2, verification and business ×6, dispute, support and refund account ×5, recruit and collab ×10); one copy table in `notification_render.ts` (verbatim Contract text); `notify`'s grouped branch passes `names` (the stored actors, newest first, at most 3) so `quote_new` and `recruit_application_new` can name them; `notification_hooks.ts` with one exported hook per catalogue event; booking copies without "cọc" (`booking_declined`, `booking_cancelled`, `refund_done`: "số bạn đã trả", "Tiền buổi chụp #… đã về tài khoản của bạn."); `recordDispatch` in `refunds.ts` now sets the booking's `depositRefundedAt` when an escrow refund becomes `done` (once, version unchanged), so the booking `refund_done` notice finally fires (the old S04 plan owed it, #129 left it unfired); test-only `packages/domain/test/client_targets.ts`, a TypeScript port of the app allowlist that checks every hook target.
- Functions (Task 3): `event_notices.ts` `sendEventSoonNotices` run by `handleEventClock` as its last step in its own try/catch (`EventClockExtras.notify`, result gains `soonEvents` and `soonSent`, `refundsResent` kept); `Event.soonNoticeAt` and `EventStore.dueForSoonNotice` (Firestore: `status in [open, full, closed]`, `soonNoticeAt == null`, `startAt` in (now, now + 48 h]); `handlePayoutWrite(payoutId, before, after, deps, notify?)` sends `payout_released` when a payout becomes `paid`; CLI `npm run clock -- events|bookings` (emulators only); seed night walk 36 h ahead with Lan's paid ticket, so `npm run clock -- events` produces the `event_soon` row; composite index `events (status, soonNoticeAt, startAt)`.
- App (Tasks 4 and 5): `notificationVisualOf` gives every type an icon and tone (`AppIcons.supportAgent` added); `safeTarget` accepts exactly the patterns of `CLIENT_TARGET_PATTERNS` (refuses repeated query keys and plain `/studio/recruit`; the one-query targets are `/u/:uid?tab=reviews`, `/studio/recruit?post=<id>` and `/collab?offer=<id>`), which also fixes `event_host_invited` opening "Nội dung này không còn"; `CustomerTicketPrimer(eventTitle)` and `EventTicketsTab` asks once per highlighted upcoming ticket (free ticket and paid ticket both land on `/bookings?tab=events&highlight={regId}`); l10n `primerTitleCustomerTicket`, `primerTicketBenefit1`.

## Docs changed in Task 6
- `2026-10-01-remaining-screens.md`: §2 rows S17.01 ("✅ đã làm (10a) · đủ loại + hook (#138)") and S17.03 ("✅ (10a) · thêm sau khi mua vé (#138)"); §3h.1 grouped copy names the 2 newest senders plus "N người khác" (avatars stack up to 3); §3h.2 rewritten as the full catalogue (every type: role, icon and tone, filter, target, S17.02 group, note; `booking_cancelled` note "Hoàn {percent}% số bạn đã trả"; `job_selected` "thay bằng `quote_accepted`"), plus the paragraphs "Nhắc sự kiện" and "Hook theo use case" (hooks by owner and the allowed targets); §3h.5 critical list; §3h.6 ticket primer; §3h.7 pointer to the hooks.
- `screens/account.md`: S17.01 allowlist and type coverage, S17.03 ticket context, strings renamed to the real `app_vi.arb` keys.
- One "Hook: `notify…` in `notification_hooks.ts` (#138)" line in `2026-10-06-tomato-brick-reviews-design.md` §7.4, `2026-10-06-delivery-preview-unlock-design.md` §6, `2026-10-06-studio-members-design.md` §7, `2026-10-06-payments-payouts-design.md` (§5 refund account, §6.1 payout account and `payout_released`, §6.2 account change), `2026-10-06-identity-verification-design.md` (reminder paragraph), `2026-10-07-studio-recruiting-design.md` §8, `2026-10-01-instant-booking-design.md` §3.3.
- `data-model/domain-model.md`: `Event.soonNoticeAt?` and the `NotificationType` list; `data-model/relational-schema.md`: `events.soon_notice_at timestamptz null` and a partial index.
- S17 strings in the specs were checked against `app_vi.arb` and the mock (`#S17.01`, `#S17.03`, `#S17.03-ticket`): primer titles and benefits, "Để sau", the 7-day note, the four S17.01 rows of the plan's Global Constraints.

## Rulings
Verbatim from the SDD progress ledger (`.superpowers/sdd/2026-10-07-s17-notifications/progress-plan-138-s17-thong-bao.md`), in order. Rulings 3 to 6 change hook inputs or keys of the plan's hooks table; the table below (Hooks) shows the built form.

- Ruling 1: Task 2 writes `test/client_targets.ts` from the plan's App contract target list (the patterns Task 4 will add), not from today's Dart code; Task 4 must make Dart `safeTarget` accept exactly that list — cost if wrong: one list edited twice.
- Ruling 2: keep the "Photo walk" tag on the mock ticket card — it mirrors the real S11.04 ticket card the primer sits over; reviewer approved — cost if wrong: one tag removed from the mock.
- Ruling 3: notifyDisputeMessage gets optional messageId used as eventId — call-compatible with #142 — cost if wrong: none.
- Ruling 4: quote_new group eventId per photographer (re-quote never increases count) — overrides plan test "new quoteVersion counts again" — cost if wrong: customer gets no separate notice for an edited quote (still visible in S15.03).
- Ruling 5: booking_reassigned dedupe key includes old assignee — cost if wrong: none.
- Ruling 6: #139 must call notifyQuoteNew only for a photographer's first quote on a job (notify compares only the last eventId; p1,p2,p1 would recount) — hand-off in Task 6 ledger; #136 passes reassignedAt to notifyBookingReassigned — cost if wrong: an inflated count when the emitter ignores the rule.

Pre-flight and review notes behind them (same file): the pre-flight scan found that Task 2 writes the TypeScript allowlist port before Task 4 adds the Dart patterns (Ruling 1); Task 2 review 1 approved with three plan-mandated Important findings (a dispute message without retry dedupe, a quote version inflating the group, a reassignment key that drops the old assignee), fixed in round 1 (Rulings 3, 4, 5; commits 478dec0..a976693); a note for Task 4, done: Dart `safeTarget` refuses duplicate query keys (`queryParametersAll`) and plain `/studio/recruit`.

## Decisions of the plan (summary)
1. Hooks, not call sites, for features that do not exist yet: each hook is an exported domain function `(deps, event) => Promise<NotifyResult | NotifyResult[]>` that picks recipients, copy content, target, dedupe or group key and actor. Owners call it after their write commits (never inside a transaction); a failure is logged and retried by the trigger, never rolls back the business write.
2. `quote_accepted` replaces `job_selected` (kept in `NOTIFICATION_TYPES` for old rows, generic copy, no hook).
3. Grouped copy can name actors: `notify` passes `names` along with `count`; `quote_new` uses them, `chat_message` ignores them; a read grouped row restarts with one actor.
4. `event_soon`: one reminder per paid ticket when the event starts within 48 hours; the `eventClock` step queries `status in [open, full, closed]`, `soonNoticeAt == null`, `now < startAt <= now + 48 h`, notifies every `paid` registration (dedupe `event_soon_{eventId}_{regId}`), then sets `soonNoticeAt` only if every send succeeded. Tickets bought after the event-level pass get no reminder. Title by Vietnam calendar days (≥ 2 "bắt đầu sau {n} ngày", 1 "bắt đầu ngày mai", 0 "bắt đầu hôm nay"), target `/e/{eventId}`, thumbnail the event cover.
5. `payout_released` is sent by `onPayoutWritten` when `status` becomes `paid`, to the payee, dedupe `payout_released_{payoutId}`, amount `amountNet` when present else `amount`, target `/work/earnings`; critical.
6. Categories of the new types: reviews → `badges`/`system`; delivery → `booking`/`activity`; studio membership → `booking`/`system`; studio assignment → `booking`/`activity`; payout account and verification → `booking`/`system`; disputes, support, refund account → `booking`/`activity`; Chụp ngay → `instant`/`activity`; recruiting and collaborators → `jobs`/`activity`. Critical follows spec §3h.5 (money, cancellations, decisions on the right to work, the time-boxed collaborator offer, `assign_overdue`). No new S17.02 row.
7. "Cọc" copy replaced in `booking_declined`, `booking_cancelled` and `refund_done` with the mock S17.01 text (#129 left different server wording; no "cọc" remains); Task 2 also made the booking `refund_done` fire (see Built).
8. Targets of not-yet-built screens are allowlisted now, for every owner (`/jobs/:id`, `/jobs/:id/applications`, `/instant/:id`, `/work/instant`, `/work/instant/:id`, `/work/instant/offer/:id`, `/b/:id/delivery`, `/studio/members`, `/me/studio`, `/work/earnings`, `/work/earnings/account`, `/verify/start`, `/verify/business`, `/disputes/:id`, `/help/chat`, `/me/payments`, `/recruit/:id`, `/studio/recruit?post=<id>`, `/collab`, `/collab?offer=<id>`, plus `/e/:id` and `/events/:id/manage`). Owner plans do not edit `safeTarget`; a row with such a target only exists once its owner calls the hook, in the plan that registers the route.
9. Ticket primer: `CustomerTicketPrimer` once per highlighted upcoming ticket on the tickets tab; photographers get none; the Chụp ngay primer call sites are #140's.
10. Quote grouping with real data is proven by domain, Functions and widget tests; no fake rows are seeded, the first real rows appear when #139 calls the hook.
11. `npm run clock -- events|bookings` (emulators only, `assertLocalEmulators({ allowAnyProject: true })`) runs `handleEventClock`/`handleBookingClock` once; the seed has an event 36 hours ahead with Lan's paid ticket.
12. One owner, one emitter per hook (the hooks table); `review_new` is no longer emitted once #130 calls `notifyReviewVerdict`.
13. The five delivery hooks are called only by #152 (`deliveryNotices` in `onBookingWrite` and the `remindAutoApprovals` step of `bookingClock`).
14. `refundsResent` stays in `handleEventClock` (#129 did not move the ticket refund re-send).

## Hooks: hand-off by emitter
All hooks live in `packages/domain/src/notification_hooks.ts`, take `deps: NotifyDeps` first and an event object second, and are exported from `@photobooking/domain`. Names come from `deps.users.get(id)` with the fallbacks "Khách hàng" / "Nhiếp ảnh gia" / "Studio"; `day` is `yyyy-MM-dd` (Vietnam), `start` is `HH:mm`; the actor is the counterpart and `thumbUrl` its avatar. Each hook has exactly one emitter. **For every emitter below: call after commit, from a trigger or callable, with `liveNotifyDeps()` (`app_flutter/firebase/functions/src/infra/live_notification.ts`; the emulator uses `LoggingPushSender`); you are the only caller.** Never call a hook inside a transaction. A hook with several recipients sends them all and throws one error at the end, so the trigger retries and the dedupe ids prevent doubles. The target of every hook already passes the app allowlist; the route itself is the emitter's to register.

### #139 · Đăng việc và báo giá (S15, S16)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyQuoteNew({customerId, jobId, jobTitle, photographerId, quoteVersion})` | customer | `quote_new` (grouped) | `/jobs/{jobId}/applications` | dedupe `quote_new_{jobId}`, group `job:{jobId}:quotes`, `eventId` = `{photographerId}` (Ruling 4), actor = photographer |
| `notifyQuoteWithdrawn({customerId, jobId, jobTitle, photographerId, quoteVersion, auto})` | customer | `quote_withdrawn` | `/jobs/{jobId}/applications` | `quote_withdrawn_{jobId}_{photographerId}_{quoteVersion}` |
| `notifyJobExpiring({customerId, jobId, jobTitle, quoteCount, quoteDeadline})` | customer | `job_expiring` | `/jobs/{jobId}/applications` | `job_expiring_{jobId}_{quoteDeadline}` (an extended deadline gets a new notice) |
| `notifyJobExpired({customerId, jobId, jobTitle})` | customer | `job_expired` | `/jobs/{jobId}` | `job_expired_{jobId}` |
| `notifyJobMatch({photographerId, jobId, jobTitle, day, area})` | photographer | `job_match` | `/jobs/{jobId}` | `job_match_{jobId}_{photographerId}` |
| `notifyJobInvited({photographerId, customerId, jobId, jobTitle})` | photographer | `job_invited` | `/jobs/{jobId}` | `job_invited_{jobId}_{photographerId}` |
| `notifyQuoteAccepted({photographerId, customerId, jobId, bookingId, jobTitle})` | photographer | `quote_accepted` | `/b/{bookingId}` | `quote_accepted_{jobId}_{photographerId}` |
| `notifyQuoteNotSelected({photographerId, jobId, jobTitle, reason})` | photographer | `quote_not_selected` | `/jobs/{jobId}` | `quote_not_selected_{jobId}_{photographerId}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- **Chỉ gọi `notifyQuoteNew` cho báo giá đầu tiên của một thợ trên một việc** (Ruling 6): `notify` chỉ so `eventId` cuối của dòng gom, nên chuỗi p1, p2, p1 sẽ đếm p1 lần hai. Báo giá sửa của cùng thợ không gọi lại hook; khách vẫn thấy bản sửa ở S15.03.
- `quoteVersion` còn trong đầu vào để giữ chữ ký của plan, hook không dùng nó để gom (`eventId` = `photographerId`).

### #140 · Chụp ngay (S13, S14)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyInstantAssigned({customerId, requestId, photographerId, etaMinutes})` | customer | `instant_assigned` | `/instant/{requestId}` | `instant_assigned_{requestId}` |
| `notifyInstantMissed({photographerId, offerId})` | photographer | `instant_missed` | `/work/instant` | `instant_missed_{offerId}` |
| `notifyInstantRoundEnded({customerId, requestId, round})` | customer | `instant_round_ended` | `/instant/{requestId}` | `instant_round_ended_{requestId}_{round}` |
| `notifyInstantNoMatch({customerId, requestId, round, amount})` | customer | `instant_no_match` | `/instant/{requestId}` | `instant_no_match_{requestId}` |
| `notifyInstantArrived({customerId, requestId, photographerId, place})` | customer | `instant_arrived` | `/instant/{requestId}` | `instant_arrived_{requestId}` |
| `notifyInstantFinished({customerId, requestId, photographerId})` | customer | `instant_finished` | `/instant/{requestId}` | `instant_finished_{requestId}` |
| `notifyInstantCancelled({requestId, by: 'customer'\|'photographer', customerId, photographerId, feeVnd})` | the other party | `instant_cancelled` | photographer: `/work/instant/{requestId}`; customer: `/instant/{requestId}` | `instant_cancelled_{requestId}_{by}` |
| app: `maybeAskForNotifications(context, ref, const CustomerInstantPrimer())` after the request is paid and sent (S13.03); `const PhotographerPrimer()` when Live Shutter turns on (S14.01) | — | — | — | — |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- Chỗ gọi primer là của #140: `maybeAskForNotifications(context, ref, const CustomerInstantPrimer())` sau khi yêu cầu đã trả và gửi (S13.03); `const PhotographerPrimer()` khi bật Live Shutter (S14.01).
- Lời mời Chụp ngay (push ưu tiên cao mở S14.02) không đi qua hook nào: hộp thư chỉ có `notifyInstantMissed` sau khi hết hạn.

### #130 · Đánh giá cà chua/gạch (S05.05)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyReviewVerdict({bookingId, subjectUserId, customerId, verdict: 'tomato'\|'brick', hits, day, text})` (called from `onReviewWrite` instead of `review_new`) | subject (photographer or studio) | `review_tomato` / `review_brick` | `/u/{subjectUserId}?tab=reviews` | `review_{verdict}_{bookingId}_{subjectUserId}` |
| `notifyDeliverySubmitted({bookingId, customerId, delivererId, round, count})` | customer | `delivery_submitted` | `/b/{bookingId}/delivery` | `delivery_submitted_{bookingId}_{round}` |
| `notifyDeliveryRevisionRequested({bookingId, customerId, delivererId, round})` | deliverer | `delivery_revision_requested` | `/b/{bookingId}` | `delivery_revision_{bookingId}_{round}` |
| `notifyDeliveryApproved({bookingId, customerId, delivererId})` | deliverer | `delivery_approved` | `/b/{bookingId}` | `delivery_approved_{bookingId}` |
| `notifyDeliveryAutoApproveSoon({bookingId, customerId, delivererId, round})` | customer | `delivery_auto_approve_soon` | `/b/{bookingId}/delivery` | `delivery_auto_soon_{bookingId}_{round}` |
| `notifyDeliveryExtraRound({bookingId, customerId, delivererId, round, granted})` | customer | `delivery_extra_round` | `/b/{bookingId}/delivery` | `delivery_extra_{bookingId}_{round}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- `notifyReviewVerdict` thay `review_new` trong `onReviewWrite`: #130 thôi phát `review_new` (loại này giữ biểu tượng cho dòng cũ); booking studio gọi hai lần, một cho thợ và một cho studio.
- Năm hook `notifyDelivery*` không do #130 gọi mà do #152 (Decision 13): từ bộ quyết định thuần `deliveryNotices(before, after)` trong trigger `onBookingWrite` có sẵn, và `notifyDeliveryAutoApproveSoon` từ bước `remindAutoApprovals` của `bookingClock` (một lần mỗi vòng, dấu `autoApproveNoticeAt`).

### #136 · Studio, thành viên, giao thợ (S26)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyStudioInvite({photographerId, studioId, inviteId})` | photographer | `studio_invite` | `/me/studio` | `studio_invite_{inviteId}` |
| `notifyStudioJoinRequest({studioId, photographerId, requestId})` | studio | `studio_join_request` | `/studio/members` | `studio_join_request_{requestId}` |
| `notifyStudioInviteAccepted({studioId, photographerId, inviteId})` | studio | `studio_invite_accepted` | `/studio/members` | `studio_invite_accepted_{inviteId}` |
| `notifyStudioJoinApproved({photographerId, studioId, requestId})` | photographer | `studio_join_approved` | `/me/studio` | `studio_join_approved_{requestId}` |
| `notifyStudioRemoved({photographerId, studioId, membershipId})` | photographer | `studio_removed` | `/me/studio` | `studio_removed_{membershipId}` |
| `notifyStudioInviteExpiring({photographerId, studioId, inviteId})` | photographer | `studio_invite_expiring` | `/me/studio` | `studio_invite_expiring_{inviteId}` |
| `notifyBookingAssigned({bookingId, customerId, studioId, assigneeId, day, start})` | customer and assignee | `booking_assigned` | `/b/{bookingId}` | `booking_assigned_{bookingId}_{assigneeId}_{to}` |
| `notifyBookingReassigned({bookingId, customerId, studioId, oldAssigneeId, newAssigneeId, day, start, reassignedAt?})` | customer, old, new | `booking_reassigned` | `/b/{bookingId}` | `booking_reassigned_{bookingId}_{oldAssigneeId}_{newAssigneeId}[_{reassignedAt}]_{to}` |
| `notifyAssignReminder({bookingId, studioId, hours, day, start})` | studio | `assign_reminder` | `/b/{bookingId}` | `assign_reminder_{bookingId}_{hours}` |
| `notifyAssignOverdue({bookingId, customerId, studioId, day, start})` | customer and studio | `assign_overdue` | `/b/{bookingId}` | `assign_overdue_{bookingId}_{to}` |
| `notifyChangeRequested({bookingId, customerId, studioId, day, respondBy})` | studio | `change_requested` | `/b/{bookingId}` | `change_requested_{bookingId}` |
| `notifyChangeAnswered({bookingId, customerId, studioId, outcome})` | customer | `change_answered` | `/b/{bookingId}` | `change_answered_{bookingId}_{outcome}` |
| `notifyAssignmentReturned({bookingId, studioId, assigneeId, day, start})` | studio | `assignment_returned` | `/b/{bookingId}` | `assignment_returned_{bookingId}_{assigneeId}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- **Truyền `reassignedAt`** (ISO, lúc đổi thợ) cho `notifyBookingReassigned` (Ruling 5, Ruling 6): khoá chống trùng là cặp thợ cũ → thợ mới; không có `reassignedAt` thì A → B lặp lại là bản trùng.
- `notifyBookingAssigned`, `notifyBookingReassigned`, `notifyAssignOverdue` gửi nhiều người nhận trong một lần gọi; một người nhận lỗi không chặn người khác, hook ném một lỗi ở cuối (trigger thử lại, khoá chống trùng chặn gửi đôi).

### #134 · Chi trả và tài khoản nhận tiền (S06)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyPayoutAccountNeeded({payeeId, amount})` | payee | `payout_account_needed` | `/work/earnings/account` | `payout_account_needed_{payeeId}` |
| `notifyPayoutAccountChanged({uid, accountId, bankCode, accountLast4, activeFrom /* ISO */})` | uid | `payout_account_changed` (`bank` = `bankByCode(bankCode).shortName`, `activeFrom` → Vietnam `HH:mm dd/MM`) | `/work/earnings/account` | `payout_account_changed_{accountId}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- `payout_released` đã do #138 gửi (xem cuối mục này); #134 chỉ gọi hai hook dưới. `notifyPayoutAccountChanged` nhận `activeFrom` ISO, đổi sang giờ Việt Nam; `bank` là `bankByCode(bankCode).shortName` (chính mã nếu không tra được).

### #135 · Xác minh (S21)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyVerificationDecision({uid, outcome: 'approved'\|'rejected'\|'revoked', decidedAt})` | uid | `verification_{outcome}` | `/verify/start` | `verification_{outcome}_{uid}_{decidedAt}` |
| `notifyBusinessDecision({uid, outcome: 'verified'\|'rejected', decidedAt})` | uid | `business_{outcome}` | `/verify/business` | `business_{outcome}_{uid}_{decidedAt}` |
| `notifyVerificationReminder({uid, stepsLeft, since})` | uid | `verification_reminder` | `/verify/start` | `verification_reminder_{uid}_{since}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- `decidedAt` / `since` nằm trong khoá chống trùng: quyết định mới tại thời điểm mới là thông báo mới, gọi lại cùng thời điểm là bản trùng.

### #142 · Khiếu nại và hỗ trợ (S18)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyDisputeOpened({disputeId, providerId, customerId, subject, ticket})` → `NotifyResult \| null` (null for a platform event) | provider | `dispute_opened` | `/disputes/{disputeId}` | `dispute_opened:{disputeId}` |
| `notifyDisputeResolved({disputeId, recipientIds, subject, kind, providerName, refund, release})` → `NotifyResult[]` | `recipientIds` | `dispute_resolved` | `/disputes/{disputeId}` | `dispute_resolved:{disputeId}` |
| `notifyDisputeMessage({disputeId, recipientIds, senderId, preview, messageId?})` → `NotifyResult[]` | `recipientIds` | `dispute_message` (grouped) | `/disputes/{disputeId}` | group `dispute:{disputeId}`, actor = sender |
| `notifySupportReply({threadId, disputeId: string \| null, messageId, recipientIds, preview})` → `NotifyResult[]` | `recipientIds` | `support_reply` | `/disputes/{disputeId}` when set, else `/help/chat` | `support_reply:{messageId}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- **Truyền `messageId`** cho `notifyDisputeMessage` (Ruling 3): dùng làm `eventId` của dòng gom, nên tin nhắn bị thử lại không đếm hai lần.
- `notifyDisputeOpened` trả `null` khi `providerId === 'platform'` (sự kiện nền tảng, không có ai để báo); `providerName` của `notifyDisputeResolved` là "ứng dụng" với sự kiện nền tảng (chủ phát quyết định).

### #141 · Thanh toán và tài khoản (S22)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyRefundAccountNeeded({uid, refundId, amount, hasPayer})` | uid | `refund_account_needed` | `/me/payments` | `refund_account_needed:{refundId}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- Một hook; thông báo quan trọng (luôn có dòng trong hộp thư, push có âm).

### #151 · Tuyển thợ và cộng tác viên (S27)

| Hook và đầu vào | Người nhận | Loại | Target | Khoá chống trùng / gom |
|---|---|---|---|---|
| `notifyRecruitPostNew({recipientId, studioId, postId, title})` | recipient | `recruit_post_new` | `/recruit/{postId}` | `recruit_post_new:{postId}` |
| `notifyRecruitApplicationNew({studioId, postId, title, applicantId})` | studio | `recruit_application_new` (grouped) | `/studio/recruit?post={postId}` | group `recruit:{postId}:apps`, `eventId` = applicantId, actor = applicant |
| `notifyRecruitApplicationResult({applicantId, studioId, postId, title, outcome})` | applicant | `recruit_application_result` | `/recruit/{postId}` | `recruit_application_result:{postId}:{outcome}` |
| `notifyCollabInvite({collaboratorId, studioId, invitedAt})` | collaborator | `collab_invite` | `/collab` | `collab_invite:{studioId}_{invitedAt}` |
| `notifyCollabInviteResult({studioId, collaboratorId, invitedAt, outcome})` | studio | `collab_invite_result` | `/collab` | `collab_invite_result:{collaboratorId}_{invitedAt}:{outcome}` |
| `notifyCollabAssignmentOffer({collaboratorId, studioId, bookingId, service, day, start, fee, deadline})` | collaborator | `collab_assignment_offer` | `/collab?offer={bookingId}` | `collab_assignment_offer:{bookingId}_{collaboratorId}` |
| `notifyCollabAssignmentResult({studioId, collaboratorId, bookingId, outcome, service, day, start, deadline})` | studio | `collab_assignment_result` | `/b/{bookingId}` | `collab_assignment_result:{bookingId}_{collaboratorId}:{outcome}` |
| `notifyCollabPayDue({studioId, collaboratorId, bookingId, amount, service, day})` | studio | `collab_pay_due` | `/collab` | `collab_pay_due:{bookingId}_{collaboratorId}` |
| `notifyCollabPayReported({collaboratorId, studioId, bookingId, amount, method})` | collaborator | `collab_pay_reported` | `/collab` | `collab_pay_reported:{bookingId}_{collaboratorId}` |
| `notifyCollabPayDisputed({studioId, collaboratorId, bookingId, amount, service, day})` | studio | `collab_pay_disputed` | `/collab` | `collab_pay_disputed:{bookingId}_{collaboratorId}` |

Quy tắc chung: **gọi sau khi giao dịch ghi xong, từ trigger hoặc callable, với `liveNotifyDeps()`; bạn là chủ phát duy nhất của các hook này** (không plan nào khác gọi chúng).

- Giới hạn gửi (3 thông báo mỗi thợ mỗi ngày, 200 người nhận) nằm ở `notifyRecruitMatches` của #151, nó gọi `notifyRecruitPostNew` cho từng người nhận.
- Hai đích có query (`/studio/recruit?post=<id>`, `/collab?offer=<id>`) là hai đích duy nhất app chấp nhận query; route phải được #151 đăng ký trong cùng plan.

### #138 (this unit, nothing to hand off)
| Hook | Recipient | Type | Target | Dedupe |
|---|---|---|---|---|
| `notifyPayoutReleased({payoutId, payeeId, amount, count})` (from `handlePayoutWrite`) | payee | `payout_released` | `/work/earnings` | `payout_released_{payoutId}` |
| `sendEventSoonNotices(deps: EventDeps, notifyDeps: NotifyDeps, onError?)` → `{events, sent}` (from `handleEventClock`) | paid ticket holders | `event_soon` | `/e/{eventId}` | `event_soon_{eventId}_{regId}` |

## Deploy notes
1. **Deploy the new `events` index before the functions**: `events (status ASC, soonNoticeAt ASC, startAt ASC)` in `app_flutter/firebase/firestore.indexes.json`. Without it the clock query fails (the step logs and continues, so the other clock steps still run).
2. Events written before this deploy have no `soonNoticeAt` field; Firestore does not match a missing field with `== null`, so they never get a reminder (dev data only; the memory store treats a missing field as null).
3. No new scheduled job (the step rides on `eventClock`, every 5 minutes), no rules change, no new Storage path, no paid API, no SMS. Nothing was deployed to `booking-c1922` (Spark). On the emulators schedules do not fire: use `npm run clock -- events` after seeding.
4. Cost (plan, Chi phí Google): about +$0.01 per month at 1,000 MAU and +$0.07 at 10,000 MAU for this unit alone; about +$0.20 at 10,000 MAU once every owner emits.

## Not run (sandbox)
- Functions integration test `app_flutter/firebase/functions/test/integration/event_soon.test.ts` is written, **not run** (one `event_soon` row with id `n_event_soon_{event}_{reg}`, target `/e/{event}`, `soonNoticeAt` set, a second run sends nothing). `test/integration/event.test.ts` was edited (explicit notify deps; the "check-in twice" test moved off "tomorrow" because of the seed night walk) and not run. Run both outside the sandbox with the emulators (`npm run test:integration`); CI runs them on push.
- Firestore rules emulator tests: not run; the rules are not changed by this unit.
- `npm run clock` cannot start inside the sandbox (the tsx CLI's IPC pipe gets EPERM); only `--help` and the refusals (no emulator host, a live host, an unknown command) were smoked through `node --import tsx tools/clock.ts`.
- No device build, no iOS step. Domain, Functions and Flutter unit, widget and analyze suites ran green in each task (Task 3: domain 845, Functions 262; Task 5: Flutter 3163 passed, 0 failed).

## Owner questions (still open)
1. Ticket holders get no notice when an event is cancelled (refund) or its start moves: spec §3h.2 has no `event_cancelled` / `event_changed`. Default applied: not in this unit; propose both in a follow-up issue (category `events`, `event_cancelled` critical). Related: `soonNoticeAt` is not reset when an event's start moves, so a holder gets no second reminder for the new date (suggested follow-up: reset it in `updateEvent` when `startAt` changes, together with `event_changed`).

## Deferred
From the plan:
- Emitting the hook types: quotes and jobs → #139; Chụp ngay (and its primer call sites, high-priority invitation push) → #140; tomato/brick reviews → #130 and delivery → #152 (split from #130); studio membership and assignment → #136; payout account → #134; verification → #135; disputes and support → #142; refund account → #141; recruiting and collaborators → #151.
- `event_cancelled` / `event_changed` for ticket holders → owner question 1.
- A reminder for tickets bought after the event-level `event_soon` pass (Decision 4).
- `promo` emission (needs a staff tool, dashboard #83).
- Email copies of critical notices (account change, cancellations).
- iOS APNs configuration (10a deferred, plan 15).
- Go backend (phase 2, #90): an adapter for `NotificationStore` and `PushSender`; the hooks are reusable as is.

## Minor findings (deferred)
Verbatim from the SDD ledger, grouped by task. Tasks 1 and 6 have none.

### Task 2
- Task 2: minor (deferred): grouped dedupe compares only the last eventId (existing notify; plan forbids changing it here)
- Task 2: minor (deferred): hook table test asserts titles not bodies
- Task 2: minor (deferred): quiet-hours sweep doesn't assert push non-empty
- Task 2: minor (deferred): notifyAll duplicates booking_notifications block
- Task 2: minor (deferred): vnTimeDay no input guard

### Task 3
- Task 3: minor (deferred): event_payment_callables.test.ts:213 calls handleEventClock without notify extras (builds live deps in a unit test)
- Task 3: minor (deferred): sweep failure skips the reminder step that tick
- Task 3: minor (deferred): permanently failing recipient re-scans the event every tick (cost)
- Task 3: minor (deferred): soonNoticeAt not reset when start moves (owner question event_changed)

### Task 4
- Task 4: minor (deferred): targetNeedsExistenceCheck true for /b/x/delivery (no read happens in practice)
- Task 4: minor (deferred): two overlapping accepted lists in targets test; trailing & not pinned

### Task 5
- Task 5: minor (deferred): segment re-entry can re-ask for the same highlight if the first call showed no sheet (bounded by 7-day rule)
- Task 5: minor (deferred): _primerAskedFor set during build

## Notes for the next unit
- Task 2 left one probe open that Ruling 6 answers by contract: `notify`'s grouped duplicate check compares only the row's last `eventId`, so p1, p2, p1 gives count 3 for 2 photographers (memory store probe). If #139 cannot guarantee "first quote only", the fix is in `notify` (treat an `eventId` already among the unread row's actors as a duplicate, or keep a set of event ids).
- Task 3: the memory event store treats a missing `soonNoticeAt` as null, Firestore does not match it (deploy note 2); the seed night walk (`seed-event-an-night-walk`) takes An's availability for the day 36 hours ahead, so publishing another An event on that day in the emulator answers `day_taken` (the seed now skips a day path a seed booking already wrote); `make(...)` in `seed/fixtures.ts` takes `hoursAhead` instead of `daysAhead`; `sendEventSoonNotices` names its second parameter `notifyDeps`; its transaction re-reads the event and skips one that is no longer open, full or closed or already marked.
- Task 4: `targetNeedsExistenceCheck` is `startsWith('/b/')` so it is true for `/b/x/delivery`, but `FirestoreNotificationRepository.targetExists` only reads for a 3-part `/b/id` or `/chat/id`, so no read happens in practice.
- Task 5: the primer only fires on the tickets tab built by `my_bookings_screen.dart` (segment Vé sự kiện); `EventsWorld.pump` in `test/support/event_world.dart` grants notification permission by default so existing events tests never show the sheet.
- A later plan that edits `notification.ts`, `notification_render.ts`, `notification_hooks.ts`, `notification_visuals.dart` or `notification_targets.dart` should not: call the hooks instead. `app_vi.arb` is append-only; keep both sides on a merge conflict.
