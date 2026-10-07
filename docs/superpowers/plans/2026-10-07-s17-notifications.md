# S17 · Thông báo Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.indexes.json` only (no rules change). Functions integration tests are written, not run (CI runs them). Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Every notification type the specs name has its copy, deep link, icon and tone; the ones whose source exists today are emitted (`event_soon` before an event, `payout_released` when a payout is paid), the ones whose source is built by another use case are one named hook call away (quotes and job posts #139, Chụp ngay #140, tomato/brick reviews and delivery #130, studio #136, payout account #134, verification #135, disputes and support #142, refund account #141, recruiting and collaborators #151); the grouped "n nhiếp ảnh gia đã báo giá" row renders from real grouped data; the S17.03 primer is asked after buying a ticket; and every target the server writes opens in the app.

**Architecture:** This plan owns every notification type of the app: its meta, copy, dedupe/group key, target, app visual and the app allowlist (cross-plan review 2026-10-07: one owner per notification type, exactly one emitter per hook). One copy table stays in `packages/domain/src/notification_render.ts` (ruling R4 of 10a); `notification.ts` maps each type to category/tab/critical. A new module `notification_hooks.ts` holds one function per event (`notifyQuoteNew`, `notifyDeliverySubmitted`, …): each builds the `NotifyRequest` (recipient, dedupe or group key, actor, target) and calls the existing `notify`. Owning plans call the hook from their callable/trigger with `liveNotifyDeps()`; nothing else is needed on their side. Grouped rows get the actor names into the copy (one small change in `notify`). `event_soon` is a new step of the existing `eventClock` (an event-level marker `soonNoticeAt` keeps it to one pass per event, dedupe keeps it to one row per ticket). `payout_released` is emitted by the existing `onPayoutWritten` trigger on the transition to `paid` (works with today's CLI and #134's daily job). The app adds the icons/tones, the allowlisted targets (a TypeScript port of the allowlist pins server ↔ app parity), and a ticket variant of the primer.

**Tech Stack:** TypeScript (domain, Functions v2 trigger + schedule, `node --test`); Flutter, Riverpod 3, go_router, `flutter_test`.

**Spec:** main spec `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3h (all), §2 (S17 rows); the emitter plans of 2026-10-07 whose copy this catalogue holds (`2026-10-07-s06-work-earnings.md` Decision 13, `s13-s14-dispatch-provider.md` Decision 20, `s15-s16-job-posts.md` Decision 13, `s18-disputes-help.md` Decision 11, `s21-verification.md` Decision 22, `s22-payments-account.md` Decision 6, `s27-studio-recruiting.md` Decision 24, `s05-delivery-two-layer.md` Decision 11, `s05-tomato-brick-reviews.md` Decision 5, `s26-studio-members.md` Decision 23); `2026-10-06-tomato-brick-reviews-design.md` §7.4; `2026-10-06-delivery-preview-unlock-design.md` §6 (and §4 routes `/b/:id/delivery`); `2026-10-06-studio-members-design.md` §4 (routes `/studio/members`, `/me/studio`), §5, §7; `2026-10-05-provider-types-portfolio-jobs-design.md` §D notifications (line "Dùng các loại đã có … `quote_accepted` …"); `2026-10-01-instant-booking-design.md` (routes `/instant/:id`, `/work/instant`); `2026-10-06-payments-payouts-design.md` §6.1; `screens/account.md` (S17.01–S17.03); mock `docs/design/ui-mock.html` `#S17.01`, `#S17.02`, `#S17.03`; handover `ledger-notifications-badges-10a.md`, `ledger-events-10c.md`.

**Issue:** #138. **Execution wave:** 1 (cross-plan review 2026-10-07). **Blocked by:** none. **Owns (others consume):** `notification.ts` meta, `notification_render.ts` copy, `notification_hooks.ts` (every hook below), `notification_visuals.dart`, `notification_targets.dart` (`safeTarget`) and the TypeScript allowlist port `client_targets.ts`. Every later plan calls its hooks and adds no type, copy, visual or target; if an emitter plan runs before this one has merged, it creates exactly the rows and hooks this Contract lists and ledgers it.

**Branch:** `plan/138-s17-notifications`, PR into `develop` titled `feat(notifications): S17 missing types, hooks for other use cases, event reminders, ticket primer [#138]`.

**Not in this plan:** Chụp ngay invitations are not inbox rows (S14.02 full screen, spec §3h.1); their high-priority FCM push (`offerPushMessage`) is #140's. Emitting the hook types is each owner's (hooks table); `payout_account_needed` and `payout_account_changed` are now defined here (copy from #134's plan) and emitted only by #134.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. Each task's Step 1 re-checks its part; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `NOTIFICATION_CATEGORIES` (`booking, jobs, instant, events, chat, badges, promo`), `NOTIFICATION_TABS` (`activity, events, system`), `NOTIFICATION_TYPES` (already lists `payout_released`, `quote_new`, `quote_withdrawn`, `job_expiring`, `job_expired`, `job_match`, `job_invited`, `quote_accepted`, `quote_not_selected`, `job_selected`, `instant_assigned`, `instant_missed`, `event_soon`, `promo` without copy), `decideDelivery`, `prefsFromRaw` (`notification.ts`); `NotificationContent` union + `renderNotification`, `formatDayShortVi`, `formatVnd`, `truncateGraphemes`, `chatPreview` (`notification_render.ts`; the booking copies still say "Cọc"); `notify(deps, req)` with dedupe id `n_<dedupeKey>` and group id `g_<groupKey with : → _>`, the grouped branch renders `{...req.content, count}` (`notification_use_cases.ts`); `NotifyRequest`, `NotifyDeps {store, push, users, clock, onPushError}`, `NotificationActor`, `UserDirectory.get(uid)` (`notification_ports.ts`); `bookingNotices`/`notifyBookingChange` (private `actorOf` helper) (`booking_notifications.ts`); `EventRecord` (`title`, `coverUrl`, `startAt`, `status`, `location: {name, meetingPoint, …} | null`), `EVENT_STATUSES` (`event.ts`); `EventStore.dueForClose/dueForCompletion/dueForConsentExpiry`, `EventTx.getEvent/activeRegistrations (held | paid)/putEvent`, `EventDeps` (`event_ports.ts`); `runEventSweeps` (`event_sweeps.ts`); `formatVnDate`, `formatVnTime` (`booking_policy.ts`); `MemoryEventStore`, `MemoryNotificationStore`; test support `test/support/notify_world.ts` (`createNotifyWorld`), `test/support/event_world.ts` (`createEventWorld`, `eventRecord`, `registrationDoc`), `test/client_allow_list.ts` (precedent: a test-only TypeScript port of a client allowlist).
- Functions (`app_flutter/firebase/functions/src`): `liveNotifyDeps()` (`infra/live_notification.ts`; `LoggingPushSender` on the emulator); `handleEventClock(deps)` (`scheduled/event_clock.ts`) called by `eventClock` (every 5 minutes) in `index.ts`; `FirestoreEventStore` (`dueForClose` style queries, `eventToFirestore`/`eventFromFirestore`) (`infra/event_firestore.ts`); `handlePayoutWrite(before, after, deps)` (`triggers/payout_write.ts`) called by `onPayoutWritten` (`index.ts`); `notifyHostInvited` writes target `/events/{id}/manage` (`infra/live_event.ts`); `review_new` emitted in `triggers/review_write.ts`; seed `seed/fixtures.ts` (`SEED_EVENT_FREE`, `SEED_EVENT_PAID`, `make(id, title, type, daysAhead, price, capacity)`, `SEED_REGISTRATION_LAN`), `seed/local_guard.ts` (`assertLocalEmulators`); CLIs `tools/awards.ts`, `tools/payouts.ts`; `package.json` scripts.
- Indexes: `events (status, startAt)` exists; no `soonNoticeAt`.
- App: `notificationVisualOf(type, {variant})` + `NotificationTone` (`lib/features/notifications/notification_visuals.dart`, `lib/core/widgets/notification_row.dart`); `safeTarget(raw)` + `targetNeedsExistenceCheck` (`notification_targets.dart`; allows `/bookings`, `/notifications`, `/me/awards`, `/b/:id`, `/chat/:id`, `/u/:uid/badges`, `/u/:uid`, `/u/:uid?tab=reviews` — **not** `/events/:id/manage`, so today's `event_host_invited` row opens "Nội dung này không còn"); `openNotificationTarget(router, path)` (`notifications_screen.dart`); grouped avatars when `count > 1` (`notifications_screen.dart` ~line 339); `maybeAskForNotifications(context, ref, PrimerContext)`, `CustomerBookingPrimer`, `CustomerInstantPrimer`, `PhotographerPrimer`, `_PrimerSheet` (benefits `primerBenefit1–3`), `resetNotificationPrimerState` (`notification_primer.dart`); `showRegisterSheet` → `router.go('/bookings?tab=events&highlight=<regId>')` (`lib/features/events/register_sheet.dart`); `EventTicketsTab({highlightId})` (ConsumerWidget, `lib/features/events/tickets_tab.dart`), `EventRegistration.event.title/startsAt` (`lib/data/events/event_registration.dart`); routes `/e/:eventId`, `/events/:eventId/manage`, `/work/earnings`, `/work/earnings/account` (`lib/app/router.dart`); `AppIcons` (`calendar`, `camera`, `payment`, `work`, `instant`, `ticket`, `award`, `star`, `chat`, `info`, `favorite`, `image`, `schedule`, `store`, `swap`).
- Tests: `packages/domain/test/notification.test.ts`, `notification_render.test.ts`, `notification_use_cases.test.ts`, `booking_notifications.test.ts`, `event_sweeps.test.ts`; Functions `test/unit/event_firestore.test.ts`, `seed_fixtures.test.ts`; app `test/features/notifications/notification_visuals_test.dart`, `notification_targets_test.dart`, `notifications_screen_test.dart`, `notification_primer_test.dart`, `test/features/events/tickets_tab_test.dart`, `test/support/notifications_world.dart`, `test/support/fake_push.dart`.

## Global Constraints

- Spec §3h.1: "Chạm = đánh dấu đã đọc + đi tới `target` (deep link)"; "Gom nhóm: các thông báo cùng `groupKey` gộp thành một dòng, ví dụ '3 nhiếp ảnh gia đã báo giá cho việc "Chụp kỷ yếu"' → mở S15.03"; "Lời mời Chụp ngay không là thông báo trong hộp thư". §3h.3: "Chỉ server ghi thông báo và `unreadCount`"; "Tôn trọng `prefs` ở server". §3h.5 critical (quiet hours do not mute): payments, cancellations, Chụp ngay invitations. §3h.6: "Chỉ hỏi sau một hành động có ý nghĩa, không bao giờ khi mở app lần đầu. Khách: sau khi đặt lịch, mua vé hoặc gửi yêu cầu Chụp ngay".
- Mock `#S17.01` copy (verbatim targets for this plan): grouped row "3 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”" / "Minh Trí, Lan Chi và 1 người khác. Xem và so sánh báo giá."; event row "Chụp phố đêm bắt đầu sau 2 ngày" / "Tập trung 19:00 tại Nhà hát Thành phố. Mang vé trong mục Vé."; refund row "Đã hoàn 450.000₫" / "Tiền buổi chụp #A0C2 đã về tài khoản của bạn."; declined row "Lan Chi không nhận được lịch" / "Đã hoàn 100% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.".
- Copy lives in one domain table (`notification_render.ts`); the app never builds notification text. Push carries only `type`, `target`, title, body, `notificationId`.
- Business rules in `packages/domain` (no Firebase/Node imports; `purity.test.ts`); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**`, `firebase_options.dart`, `main.dart`.
- Ids, time, money: opaque ids, UTC instants, integer VND, string enum codes (`data-model/README.md`); Vietnam display time via `formatVnDate`/`formatVnTime`/`formatDayShortVi`.
- App: imports `package:photobooking/...` only, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; one primary action per screen/sheet; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `ScreenCode` on every screen and sheet.
- Owner ruling 2/3: no new paid API, no SMS, nothing deployed to `booking-c1922` (Spark); scheduled code is exercised on the emulators through the new `npm run clock` tool (the emulator does not fire schedules). Ruling 5 (`ProviderOrderGate`) does not apply: no booking, quote, assignment or invite is created here.
- `notification.ts`, `notification_render.ts`, `notification_hooks.ts`, `notification_visuals.dart`, `notification_targets.dart` are this plan's; later plans do not edit them (they call hooks). `app_vi.arb` is append-only; on a merge conflict keep both sides.
- Clock steps (#129's rule, cross-plan review finding 36): `sendEventSoonNotices` is a named entry at the end of `handleEventClock`'s step list, in its own try/catch that logs and continues; no existing parameter changes; its notify dependency goes into the optional last `extras` object (`EventClockExtras.notify?: NotifyDeps`, default `liveNotifyDeps()`; create the interface if absent).
- Commits: Conventional Commits, subject ends with `[#138]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Tests: Flutter `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; bounded pumps, no endless animation or timer. Domain `cd packages/domain && npm test && npm run lint`. Functions `cd app_flutter/firebase/functions && npm test && npm run build`. Functions integration tests written, not run.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.

## Decisions

1. **Hooks, not call sites, for features that do not exist yet.** Each hook is an exported domain function `(deps: NotifyDeps, event) => Promise<NotifyResult | NotifyResult[]>` that decides recipients, copy content, target, dedupe/group key and actor. Owning plans call it after their write commits (like `notifyBookingChange`), never inside a transaction; a hook failure is logged and retried by the trigger, never rolls back the business write. Names are fixed in the Contract table so the owning plans can cite them now.
2. **`quote_accepted` replaces `job_selected`.** Both describe "the customer chose your quote" (spec 10-05 adds `quote_accepted` → S05.02). `job_selected` stays in `NOTIFICATION_TYPES` (old rows still render an icon) but gets no copy branch beyond a generic one and no hook.
3. **Grouped copy can name actors.** `notify`'s grouped branch passes `names` (the stored actors' names, newest first, at most 3) along with `count`; `quote_new` uses them, `chat_message` ignores them. A read grouped row restarts with one actor (10a behaviour kept).
4. **`event_soon` timing:** one reminder per paid ticket when the event starts within 48 hours. The `eventClock` step queries events with `status in [open, full, closed]`, `soonNoticeAt == null`, `now < startAt <= now + 48 h`; it notifies every `paid` registration (dedupe `event_soon_{eventId}_{regId}`), then sets `soonNoticeAt` only if every send succeeded (a failure retries next tick, the dedupe prevents doubles). Tickets bought after the event-level pass get no reminder (they just bought it; ledgered). Title by Vietnam calendar days: ≥ 2 "bắt đầu sau {n} ngày", 1 "bắt đầu ngày mai", 0 "bắt đầu hôm nay"; body "Tập trung {HH:mm} tại {meetingPoint ?? location.name}. Mang vé trong mục Vé.". Target `/e/{eventId}` (S11.02 works for customers and photographers alike; `/bookings?tab=events` shows the work tab to a photographer). Thumbnail = the event cover. `soonNoticeAt` is written as `null` by `eventToFirestore` when absent, so events created before this change (no field) are never matched: dev data only.
5. **`payout_released`** is sent by `onPayoutWritten` when `status` becomes `paid` (before ≠ `paid`, after = `paid`), to the payee, dedupe `payout_released_{payoutId}`, amount = `amountNet` when the doc has it (#134) else `amount`, count = items, target `/work/earnings`. Critical (already in the table): money.
6. **Categories of the new types:** reviews → `badges` (row "Huy hiệu và đánh giá", tab `system`, like `review_new`); delivery → `booking`/`activity`; studio membership → `booking`/`system`; studio assignment → `booking`/`activity`; payout account and verification (#134, #135) → `booking`/`system`; disputes, support and refund account (#142, #141) → `booking`/`activity`; Chụp ngay (#140) → `instant`/`activity`; recruiting and collaborators (#151) → `jobs`/`activity` ("Việc đăng tuyển" channel). Critical (✓ in the table) follows §3h.5: money, cancellations, decisions on the user's right to work, and the time-boxed collaborator offer. `assign_overdue` is critical (the customer may cancel with a 100% refund). No new S17.02 row (the mock has seven rows; studio and delivery follow "Đặt lịch và thanh toán", whose in-app channel is always on).
7. **"Cọc" copy is replaced now** in `booking_declined`, `booking_cancelled` and `refund_done` to match the mock S17.01 (100% payment model): S17.01's copy is this use case's; #129 owns the app strings and the payment model. #129's server copy uses the same text ("số bạn đã trả", "Tiền buổi chụp #… đã về tài khoản của bạn."; cross-plan review finding 38), so whichever lands second finds it already equal.
8. **Targets of not-yet-built screens are allowlisted now, here, for every owner** (cross-plan review finding 29): `/jobs/:id`, `/jobs/:id/applications` (#139); `/instant/:id`, `/work/instant`, `/work/instant/:id`, `/work/instant/offer/:id` (#140); `/b/:id/delivery` (#130); `/studio/members`, `/me/studio` (#136); `/work/earnings`, `/work/earnings/account` (#134); `/verify/start`, `/verify/business` (#135); `/disputes/:id`, `/help/chat` (#142, unconditional); `/me/payments` (#141); `/recruit/:id`, `/studio/recruit` with the one query parameter `post=<id>`, `/collab` with the one query parameter `offer=<id>` (#151; these two are the only targets that accept a query, each limited to that key and an id-safe value). A row with such a target only exists once its owner calls the hook, in the same plan that registers the route; owner plans do not edit `safeTarget`. `/events/:id/manage` and `/e/:id` are added because they exist today (fixes `event_host_invited`). A TypeScript port of the allowlist (`packages/domain/test/client_targets.ts`) checks that every hook's target is accepted.
9. **Ticket primer:** after a successful registration the app lands on the tickets tab with `highlight`; `EventTicketsTab` asks the primer once when the highlighted ticket is shown (same pattern as `CustomerBookingPrimer` on booking detail with `justPaid`). New context `CustomerTicketPrimer(eventTitle)`, title "Bật thông báo để được nhắc trước khi {event} bắt đầu", two benefits that are true today: "Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung" and the existing `primerBenefit3`. Both ticket paths land on the highlight: a free registration (`showRegisterSheet`) and a paid ticket, which since #129 goes through S04.04 `TicketPay` and, once paid, lands on the same `/bookings?tab=events&highlight={regId}` (#129 Decision 15; cross-plan review finding 43), so the primer fires once for either. Photographers buying a ticket land on the work tab (existing behaviour) and get no ticket primer. The Chụp ngay primer call sites (`CustomerInstantPrimer` at S13.03, `PhotographerPrimer` when Live Shutter turns on) are #140's (hook table).
10. **Quote grouping with real data** means: the grouped row is produced by `notifyQuoteNew` against the real store and renders in the inbox (domain test + Functions unit test through the Firestore store + widget test from a repository row). The first rows in a real inbox appear when #139 calls the hook; no fake rows are seeded.
11. **`npm run clock -- events|bookings`** (new tool, emulators only via `assertLocalEmulators({ allowAnyProject: true })`) runs `handleEventClock`/`handleBookingClock` once, so the scheduled steps can be seen on the emulator; seed adds an event starting 36 hours after seeding with Lan's paid ticket so `npm run clock -- events` produces the `event_soon` row.
12. **One owner, one emitter (cross-plan review findings 10, 11, 12, 14, 15, 29).** Each type of the catalogue has exactly one hook and each hook exactly one emitter, named in the hooks table; the emitter's plan quotes the signature and calls it after its commit, nothing else. Where an emitter plan had its own copy (s06, s13p, s15, s18, s21, s22, s26, s27), this catalogue holds that plan's text (s15 and s26: this catalogue's earlier text wins; the others: the emitter's text, moved here unchanged). `review_new` is no longer emitted once #130 calls `notifyReviewVerdict` (the type keeps its visual for old rows).
13. **Delivery emitter (finding 15):** the five delivery hooks are called only by #152 (delivery plan, split from #130): `delivered`/`revision_requested`/`approved`/extra-round answers from its pure decider `deliveryNotices(before, after)` in the existing `onBookingWrite` trigger, and `notifyDeliveryAutoApproveSoon` from its `bookingClock` step `remindAutoApprovals` (once per round, marker `autoApproveNoticeAt`).
14. **`refundsResent` is gone from `handleEventClock`** (finding 36): #129 moves the refund resend into `reconcilePayments`; this plan's result type has no `refundsResent` once #129 has merged (if #129 has not, keep the field and ledger it).

## Needs the owner

1. Ticket holders get no notice when an event is cancelled (refund) or its time changes: no such type in spec §3h.2. **Default:** not in this plan; propose `event_cancelled` / `event_changed` (category `events`, critical for cancelled) in a follow-up issue.

## Contract

### Notification catalogue (domain `notification.ts` meta + `notification_render.ts` copy)

`d` = `formatDayShortVi(day)`, `t` = `truncateGraphemes(jobTitle, 40)`, `“…”` are typographic quotes. Existing rows keep their meta unless stated.

| `type` (content fields) | Category · tab · critical | Title / body (verbatim) |
|---|---|---|
| `payout_released` `{amount, count}` | booking · system · ✓ (exists) | `Đã chuyển ${formatVnd(amount)} cho bạn` / `Tiền của ${count} khoản đã vào tài khoản nhận tiền. Xem chi tiết trong Thu nhập.` |
| `quote_new` `{jobTitle, count, names}` | jobs · activity | count 1: `${names[0]} đã báo giá cho việc “${t}”` / `Xem báo giá và chọn người phù hợp.`; count 2: `2 nhiếp ảnh gia đã báo giá cho việc “${t}”` / `${names[0]} và ${names[1]}. Xem và so sánh báo giá.`; count ≥ 3: `${count} nhiếp ảnh gia đã báo giá cho việc “${t}”` / `${names[0]}, ${names[1]} và ${count − 2} người khác. Xem và so sánh báo giá.` (a missing name falls back to "Nhiếp ảnh gia") |
| `quote_withdrawn` `{photographer, jobTitle, auto}` | jobs · activity | `${photographer} đã rút báo giá` / auto: `Việc “${t}”: thợ đã kín lịch nên báo giá tự rút.`, else `Việc “${t}”. Xem các báo giá còn lại.` |
| `job_expiring` `{jobTitle, quoteCount}` | jobs · activity | `Việc “${t}” hết hạn sau 24 giờ` / `Bạn có ${quoteCount} báo giá. Chọn một người trước khi việc hết hạn.` |
| `job_expired` `{jobTitle}` | jobs · activity | `Việc “${t}” đã hết hạn` / `Đăng lại hoặc gia hạn để nhận thêm báo giá.` |
| `job_match` `{jobTitle, day, area}` | jobs · activity | `Việc mới hợp với bạn: “${t}”` / `${d} · ${area}. Xem và gửi báo giá.` |
| `job_invited` `{customer, jobTitle}` | jobs · activity | `${customer} mời bạn báo giá` / `Việc “${t}”. Xem chi tiết và gửi báo giá.` |
| `quote_accepted` `{customer, jobTitle}` | jobs · activity | `${customer} đã chọn báo giá của bạn` / `Việc “${t}” đã thanh toán. Mở buổi chụp để chốt chi tiết.` |
| `quote_not_selected` `{jobTitle, reason: awarded\|expired\|closed\|declined}` | jobs · activity | `Báo giá cho “${t}” chưa được chọn` / awarded `Khách đã chọn người khác. Cảm ơn bạn đã báo giá.`; expired `Việc đã hết hạn mà khách chưa chọn ai.`; closed `Khách đã đóng việc.`; declined `Khách đã từ chối báo giá này.` |
| `job_selected` `{}` (deprecated, Decision 2) | jobs · activity | `Bạn được chọn cho một việc` / `Mở Công việc để xem chi tiết.` |
| `instant_assigned` `{photographer, etaMinutes}` (copy from #140) | instant · activity | `Đã match với ${photographer}` / `${photographer} đến trong khoảng ${etaMinutes} phút.` |
| `instant_missed` `{}` (copy from #140) | instant · activity | `Bạn đã bỏ lỡ một lời mời` / `Lời mời chụp ngay đã hết hạn.` |
| `instant_round_ended` `{round}` (new, #140) | instant · activity | `Chụp ngay` / `Chưa ai nhận. Chọn thêm người nhé.` |
| `instant_no_match` `{amount}` (new, #140) | instant · activity | `Chưa tìm được nhiếp ảnh gia` / `${formatVnd(amount)} vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ.` |
| `instant_arrived` `{photographer, place}` (new, #140) | instant · activity | `${photographer} đã đến điểm hẹn` / `Gặp nhau ở ${place}.` |
| `instant_finished` `{photographer}` (new, #140) | instant · activity | `${photographer} đã hoàn thành buổi chụp` / `Xác nhận hoàn thành trong 2 giờ, nếu không sẽ tự hoàn thành.` |
| `instant_cancelled` `{to: photographer\|customer, name, feeVnd}` (new, #140) | instant · activity · ✓ | to photographer (customer cancelled): `Khách đã huỷ chụp ngay` / feeVnd > 0: `Bạn nhận ${formatVnd(feeVnd)} phí đi lại.`, else `Không cần tới điểm hẹn nữa.`; to customer (photographer cancelled): `${name} đã huỷ` / `Chọn người khác, không trả thêm.` |
| `event_soon` `{title, daysLeft, start, place}` | events · events | daysLeft ≥ 2: `${title40} bắt đầu sau ${daysLeft} ngày`; 1: `${title40} bắt đầu ngày mai`; 0: `${title40} bắt đầu hôm nay` / `Tập trung ${start} tại ${place}. Mang vé trong mục Vé.` |
| `review_tomato` `{hits, day, text}` (new) | badges · system | `Bạn nhận 🍅 ×${hits} từ buổi chụp ${d}` / `“${truncateGraphemes(text, 80)}”` |
| `review_brick` `{day, text}` (new) | badges · system | `Có góp ý mới về buổi chụp ${d}` / `“${truncateGraphemes(text, 80)}”` |
| `delivery_submitted` `{deliverer, count}` (new) | booking · activity | `${deliverer} đã gửi ảnh mẫu` / `Xem ${count} ảnh mẫu và đồng ý để nhận ảnh gốc.` |
| `delivery_revision_requested` `{customer, round}` (new) | booking · activity | `${customer} muốn chỉnh sửa vòng ${round}` / `Xem ghi chú của khách và nộp lại bàn giao.` |
| `delivery_approved` `{customer}` (new) | booking · activity | `${customer} đã đồng ý ảnh` / `Tiền chuyển cho bạn sau 48 giờ kiểm tra.` |
| `delivery_auto_approve_soon` `{deliverer}` (new) | booking · activity | `Còn 24 giờ để xem ảnh mẫu` / `Không phản hồi thì ảnh của ${deliverer} được tự đồng ý.` |
| `delivery_extra_round` `{deliverer, granted}` (new) | booking · activity | granted: `${deliverer} cho thêm một vòng sửa` / `Bạn có thể yêu cầu chỉnh sửa thêm một lần.`; else `${deliverer} không cho thêm vòng sửa` / `Bạn vẫn có thể đồng ý ảnh hoặc báo vấn đề với ảnh gốc.` |
| `studio_invite` `{studio}` (new) | booking · system | `${studio} mời bạn làm thành viên` / `Lời mời hết hạn sau 7 ngày.` |
| `studio_join_request` `{photographer}` (new) | booking · system | `${photographer} xin gia nhập studio` / `Duyệt hoặc từ chối trong mục Thành viên.` |
| `studio_invite_accepted` `{photographer}` (new) | booking · system | `${photographer} đã nhận lời mời` / `${photographer} là thành viên của studio từ hôm nay.` |
| `studio_join_approved` `{studio}` (new) | booking · system | `${studio} đã duyệt bạn` / `Bạn là thành viên của ${studio} từ hôm nay.` |
| `studio_removed` `{studio}` (new) | booking · system | `Bạn không còn là thành viên của ${studio}` / `Xem chi tiết trong mục Studio của tôi.` |
| `studio_invite_expiring` `{studio}` (new) | booking · system | `Lời mời của ${studio} hết hạn ngày mai` / `Chấp nhận hoặc từ chối trong mục Studio của tôi.` |
| `booking_assigned` `{to: customer\|assignee, studio, assignee, day, start}` (new) | booking · activity | customer: `${studio} đã báo thợ chụp cho bạn` / `${assignee} sẽ chụp buổi ${d} · ${start}.`; assignee: `${studio} giao cho bạn buổi ${d} · ${start}` / `Mở buổi chụp để xem chi tiết.` |
| `booking_reassigned` `{to: customer\|old\|new, studio, assignee, day, start}` (new) | booking · activity | customer: `${studio} đã đổi thợ chụp` / `${assignee} sẽ chụp buổi ${d} · ${start}.`; old: `Buổi ${d} · ${start} đã giao cho người khác` / `${studio} đã đổi thợ cho buổi chụp này.`; new: `${studio} giao cho bạn buổi ${d} · ${start}` / `Mở buổi chụp để xem chi tiết.` |
| `assign_reminder` `{hours: 48\|26, day, start}` (new) | booking · activity | `Còn ${hours} giờ để giao thợ` / `Buổi ${d} · ${start} chưa có thợ chụp.` |
| `assign_overdue` `{to: customer\|studio, day, start}` (new) | booking · activity · ✓ | customer: `Studio chưa báo thợ chụp đúng hạn` / `Buổi ${d} · ${start}. Bạn có thể chờ hoặc huỷ và được hoàn 100%.`; studio: `Quá hạn giao thợ buổi ${d} · ${start}` / `Giao thợ ngay để khách không huỷ.` |
| `change_requested` `{customer, day, respondBy /* 'HH:mm dd/MM' */}` (new) | booking · activity | `${customer} xin đổi thợ` / `Buổi ${d}. Trả lời trước ${respondBy}.` |
| `change_answered` `{studio, outcome: reassigned\|declined\|expired}` (new) | booking · activity | reassigned: `${studio} đã đổi thợ cho bạn` / `Xem thợ mới trong buổi chụp.`; declined: `${studio} không đổi thợ` / `Xem lý do trong buổi chụp.`; expired: `${studio} chưa trả lời yêu cầu đổi thợ` / `Yêu cầu đã hết hạn. Bạn vẫn có thể nhắn tin cho studio.` |
| `assignment_returned` `{assignee, day, start}` (new) | booking · activity | `${assignee} đã trả việc` / `Buổi ${d} · ${start} cần giao người khác.` |
| `payout_account_needed` `{amount}` (new, copy from #134) | booking · system | `Thêm tài khoản để nhận ${formatVnd(amount)}` / `Tiền của bạn đã sẵn sàng chuyển. Thêm tài khoản nhận tiền để nhận mỗi ngày.` |
| `payout_account_changed` `{bank, last4, activeFrom /* 'HH:mm dd/MM' Vietnam */}` (new, #134) | booking · system · ✓ | `Tài khoản nhận tiền đã đổi` / `${bank} •••• ${last4} có hiệu lực lúc ${activeFrom}. Không phải bạn đổi? Liên hệ hỗ trợ ngay.` |
| `verification_approved` `{}` (new, copy from #135) | booking · system · ✓ | `Bạn đã có thể nhận đơn` / `Hồ sơ đã được duyệt. Tích xanh đã hiện cạnh tên bạn.` |
| `verification_rejected` `{}` (new, #135) | booking · system · ✓ | `Hồ sơ chưa được duyệt` / `Xem lý do và sửa để gửi lại.` |
| `verification_revoked` `{}` (new, #135) | booking · system · ✓ | `Xác minh đã bị thu hồi` / `Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm.` |
| `verification_reminder` `{stepsLeft}` (new, #135) | booking · system | `Còn ${stepsLeft} bước để nhận đơn` / `Làm tiếp để khách đặt được bạn.` |
| `business_verified` `{}` (new, #135) | booking · system · ✓ | `Studio đã xác minh doanh nghiệp` / `Con dấu Studio đã hiện trên hồ sơ, studio nhận tới 30 thợ.` |
| `business_rejected` `{}` (new, #135) | booking · system · ✓ | `Xác minh doanh nghiệp chưa được duyệt` / `Xem lý do trong mục Xác minh doanh nghiệp.` |
| `dispute_opened` `{customer, subject, ticket}` (new, copy from #142) | booking · activity · ✓ | ticket: `${customer} báo vấn đề với vé sự kiện`, else `${customer} báo vấn đề với buổi chụp` / `${subject}. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại.` |
| `dispute_resolved` `{subject, kind: release\|refund\|split, provider, refund, release}` (new, #142) | booking · activity · ✓ | `Khiếu nại đã có kết quả` / release: `${subject}: tiền được chuyển cho ${provider}.`; refund: `${subject}: hoàn ${formatVnd(refund)} cho khách.`; split: `${subject}: hoàn ${formatVnd(refund)} cho khách, chuyển ${formatVnd(release)} cho ${provider}.` (platform events: provider = "ứng dụng") |
| `dispute_message` `{sender, preview, count}` (new, #142, grouped) | booking · activity | `${sender} nhắn trong khiếu nại` / count 1: `${preview}`; more: `${count} tin nhắn mới` |
| `support_reply` `{preview}` (new, #142) | booking · activity · ✓ | `Hỗ trợ đã trả lời` / `${preview}` |
| `refund_account_needed` `{amount, hasPayer}` (new, copy from #141) | booking · activity · ✓ | `Chọn tài khoản nhận hoàn` / hasPayer: `Bạn được hoàn ${formatVnd(amount)}. Sau 24 giờ tiền tự về tài khoản đã chuyển, hoặc chọn tài khoản khác.`, else `Bạn được hoàn ${formatVnd(amount)}. Chọn tài khoản để nhận tiền.` |
| `recruit_post_new` `{studio, title}` (new, copy from #151) | jobs · activity | `Tin tuyển hợp với bạn` / `${studio}: ${title}` |
| `recruit_application_new` `{names, title, count}` (new, #151, grouped) | jobs · activity | `Ứng viên mới` / count 1: `${names[0]} ứng tuyển “${title}”`; more: `${count} người ứng tuyển “${title}”` |
| `recruit_application_result` `{outcome: collaborator\|member\|declined\|expired, studio, title}` (new, #151) | jobs · activity | collaborator/member: `Studio đã nhận bạn` / collaborator `${studio} nhận bạn làm cộng tác viên.`, member `${studio} nhận bạn vào studio.`; declined: `Ứng tuyển chưa được nhận` / `${studio} chưa nhận ứng tuyển “${title}”.`; expired: `Ứng tuyển đã hết hạn` / `Ứng tuyển “${title}” đã hết hạn sau 7 ngày.` |
| `collab_invite` `{studio}` (new, #151) | jobs · activity | `Lời mời cộng tác` / `${studio} mời bạn cộng tác theo việc. Hết hạn sau 7 ngày.` |
| `collab_invite_result` `{outcome: accepted\|declined\|expired, name}` (new, #151) | jobs · activity | `Lời mời cộng tác` / accepted `${name} đã nhận lời cộng tác.`; declined `${name} đã từ chối lời mời cộng tác.`; expired `Lời mời cộng tác gửi ${name} đã hết hạn.` |
| `collab_assignment_offer` `{studio, service, day, start, fee, deadline}` (new, #151) | jobs · activity · ✓ | `Việc cộng tác mới` / `${studio} · ${service}, ${d} · ${start}. Thù lao ${formatVnd(fee)}. Trả lời trước ${deadline}.` |
| `collab_assignment_result` `{outcome: accepted\|declined\|expired, name, service, day, start, deadline}` (new, #151) | jobs · activity | accepted `${name} đã nhận việc` / `${service}, ${d} · ${start}.`; declined `${name} từ chối việc` / `Giao người khác trước ${deadline}.`; expired `${name} chưa trả lời` / `Giao người khác trước ${deadline}.` |
| `collab_pay_due` `{name, amount, service, day}` (new, #151) | jobs · activity | `Đến hạn trả thù lao` / `Trả ${name} ${formatVnd(amount)} cho buổi ${service} ${d}.` |
| `collab_pay_reported` `{studio, amount, method: bank\|cash\|other}` (new, #151) | jobs · activity | `Studio báo đã trả thù lao` / `${studio} báo đã trả ${formatVnd(amount)} (${method: chuyển khoản\|tiền mặt\|cách khác}). Bấm Đã nhận hoặc Chưa nhận.` |
| `collab_pay_disputed` `{name, amount, service, day}` (new, #151) | jobs · activity | `Cộng tác viên chưa nhận thù lao` / `${name} báo chưa nhận ${formatVnd(amount)} cho buổi ${service} ${d}.` |

Changed copies (Decision 7): `booking_declined` declined → body `Đã hoàn ${percent}% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.`; expired → body `Yêu cầu đã hết hạn. Đã hoàn ${percent}% số bạn đã trả.`; `booking_cancelled` party → body `${day} · ${start}.` + (percent ≠ null ? ` Hoàn ${percent}% số bạn đã trả.` : ``); `refund_done` → body `Tiền buổi chụp #${bookingId.slice(-4).toUpperCase()} đã về tài khoản của bạn.` (titles unchanged).

### Hooks (`packages/domain/src/notification_hooks.ts`), by emitting issue (exactly one emitter per hook)

Every hook: `(deps: NotifyDeps, e: …) => Promise<NotifyResult | NotifyResult[]>`; names come from `deps.users.get(id)` with fallbacks "Khách hàng" / "Nhiếp ảnh gia" / "Studio"; `day` is `yyyy-MM-dd` (Vietnam), `start` is `HH:mm`; actor = the counterpart, `thumbUrl` = actor avatar unless stated.

| Emitter (only caller) | Hook and input | Recipient(s) | Type | Target | Dedupe / group key |
|---|---|---|---|---|---|
| #139 | `notifyQuoteNew({customerId, jobId, jobTitle, photographerId, quoteVersion})` | customer | `quote_new` (grouped) | `/jobs/{jobId}/applications` | group `job:{jobId}:quotes`, `eventId` = `{photographerId}_{quoteVersion}`, actor = photographer |
| #139 | `notifyQuoteWithdrawn({customerId, jobId, jobTitle, photographerId, quoteVersion, auto})` | customer | `quote_withdrawn` | `/jobs/{jobId}/applications` | `quote_withdrawn_{jobId}_{photographerId}_{quoteVersion}` |
| #139 | `notifyJobExpiring({customerId, jobId, jobTitle, quoteCount, quoteDeadline})` | customer | `job_expiring` | `/jobs/{jobId}/applications` | `job_expiring_{jobId}_{quoteDeadline}` (an extended deadline gets a new notice) |
| #139 | `notifyJobExpired({customerId, jobId, jobTitle})` | customer | `job_expired` | `/jobs/{jobId}` | `job_expired_{jobId}` |
| #139 | `notifyJobMatch({photographerId, jobId, jobTitle, day, area})` | photographer | `job_match` | `/jobs/{jobId}` | `job_match_{jobId}_{photographerId}` |
| #139 | `notifyJobInvited({photographerId, customerId, jobId, jobTitle})` | photographer | `job_invited` | `/jobs/{jobId}` | `job_invited_{jobId}_{photographerId}` |
| #139 | `notifyQuoteAccepted({photographerId, customerId, jobId, bookingId, jobTitle})` | photographer | `quote_accepted` | `/b/{bookingId}` | `quote_accepted_{jobId}_{photographerId}` |
| #139 | `notifyQuoteNotSelected({photographerId, jobId, jobTitle, reason})` | photographer | `quote_not_selected` | `/jobs/{jobId}` | `quote_not_selected_{jobId}_{photographerId}` |
| #140 | `notifyInstantAssigned({customerId, requestId, photographerId, etaMinutes})` | customer | `instant_assigned` | `/instant/{requestId}` | `instant_assigned_{requestId}` |
| #140 | `notifyInstantMissed({photographerId, offerId})` | photographer | `instant_missed` | `/work/instant` | `instant_missed_{offerId}` |
| #140 | `notifyInstantRoundEnded({customerId, requestId, round})` | customer | `instant_round_ended` | `/instant/{requestId}` | `instant_round_ended_{requestId}_{round}` |
| #140 | `notifyInstantNoMatch({customerId, requestId, round, amount})` | customer | `instant_no_match` | `/instant/{requestId}` | `instant_no_match_{requestId}` |
| #140 | `notifyInstantArrived({customerId, requestId, photographerId, place})` | customer | `instant_arrived` | `/instant/{requestId}` | `instant_arrived_{requestId}` |
| #140 | `notifyInstantFinished({customerId, requestId, photographerId})` | customer | `instant_finished` | `/instant/{requestId}` | `instant_finished_{requestId}` |
| #140 | `notifyInstantCancelled({requestId, by: 'customer'\|'photographer', customerId, photographerId, feeVnd})` | the other party | `instant_cancelled` | photographer: `/work/instant/{requestId}`; customer: `/instant/{requestId}` | `instant_cancelled_{requestId}_{by}` |
| #140 | app: `maybeAskForNotifications(context, ref, const CustomerInstantPrimer())` after the request is paid and sent (S13.03); `const PhotographerPrimer()` when Live Shutter turns on (S14.01) | — | — | — | — |
| #130 | `notifyReviewVerdict({bookingId, subjectUserId, customerId, verdict: 'tomato'\|'brick', hits, day, text})` (called from `onReviewWrite` instead of `review_new`) | subject (photographer or studio) | `review_tomato` / `review_brick` | `/u/{subjectUserId}?tab=reviews` | `review_{verdict}_{bookingId}_{subjectUserId}` |
| #130 | `notifyDeliverySubmitted({bookingId, customerId, delivererId, round, count})` | customer | `delivery_submitted` | `/b/{bookingId}/delivery` | `delivery_submitted_{bookingId}_{round}` |
| #130 | `notifyDeliveryRevisionRequested({bookingId, customerId, delivererId, round})` | deliverer | `delivery_revision_requested` | `/b/{bookingId}` | `delivery_revision_{bookingId}_{round}` |
| #130 | `notifyDeliveryApproved({bookingId, customerId, delivererId})` | deliverer | `delivery_approved` | `/b/{bookingId}` | `delivery_approved_{bookingId}` |
| #130 | `notifyDeliveryAutoApproveSoon({bookingId, customerId, delivererId, round})` | customer | `delivery_auto_approve_soon` | `/b/{bookingId}/delivery` | `delivery_auto_soon_{bookingId}_{round}` |
| #130 | `notifyDeliveryExtraRound({bookingId, customerId, delivererId, round, granted})` | customer | `delivery_extra_round` | `/b/{bookingId}/delivery` | `delivery_extra_{bookingId}_{round}` |
| #136 | `notifyStudioInvite({photographerId, studioId, inviteId})` | photographer | `studio_invite` | `/me/studio` | `studio_invite_{inviteId}` |
| #136 | `notifyStudioJoinRequest({studioId, photographerId, requestId})` | studio | `studio_join_request` | `/studio/members` | `studio_join_request_{requestId}` |
| #136 | `notifyStudioInviteAccepted({studioId, photographerId, inviteId})` | studio | `studio_invite_accepted` | `/studio/members` | `studio_invite_accepted_{inviteId}` |
| #136 | `notifyStudioJoinApproved({photographerId, studioId, requestId})` | photographer | `studio_join_approved` | `/me/studio` | `studio_join_approved_{requestId}` |
| #136 | `notifyStudioRemoved({photographerId, studioId, membershipId})` | photographer | `studio_removed` | `/me/studio` | `studio_removed_{membershipId}` |
| #136 | `notifyStudioInviteExpiring({photographerId, studioId, inviteId})` | photographer | `studio_invite_expiring` | `/me/studio` | `studio_invite_expiring_{inviteId}` |
| #136 | `notifyBookingAssigned({bookingId, customerId, studioId, assigneeId, day, start})` | customer and assignee | `booking_assigned` | `/b/{bookingId}` | `booking_assigned_{bookingId}_{assigneeId}_{to}` |
| #136 | `notifyBookingReassigned({bookingId, customerId, studioId, oldAssigneeId, newAssigneeId, day, start})` | customer, old, new | `booking_reassigned` | `/b/{bookingId}` | `booking_reassigned_{bookingId}_{newAssigneeId}_{to}` |
| #136 | `notifyAssignReminder({bookingId, studioId, hours, day, start})` | studio | `assign_reminder` | `/b/{bookingId}` | `assign_reminder_{bookingId}_{hours}` |
| #136 | `notifyAssignOverdue({bookingId, customerId, studioId, day, start})` | customer and studio | `assign_overdue` | `/b/{bookingId}` | `assign_overdue_{bookingId}_{to}` |
| #136 | `notifyChangeRequested({bookingId, customerId, studioId, day, respondBy})` | studio | `change_requested` | `/b/{bookingId}` | `change_requested_{bookingId}` |
| #136 | `notifyChangeAnswered({bookingId, customerId, studioId, outcome})` | customer | `change_answered` | `/b/{bookingId}` | `change_answered_{bookingId}_{outcome}` |
| #136 | `notifyAssignmentReturned({bookingId, studioId, assigneeId, day, start})` | studio | `assignment_returned` | `/b/{bookingId}` | `assignment_returned_{bookingId}_{assigneeId}` |
| #134 | `notifyPayoutAccountNeeded({payeeId, amount})` | payee | `payout_account_needed` | `/work/earnings/account` | `payout_account_needed_{payeeId}` |
| #134 | `notifyPayoutAccountChanged({uid, accountId, bankCode, accountLast4, activeFrom /* ISO */})` | uid | `payout_account_changed` (`bank` = `bankByCode(bankCode).shortName`, `activeFrom` → Vietnam `HH:mm dd/MM`) | `/work/earnings/account` | `payout_account_changed_{accountId}` |
| #135 | `notifyVerificationDecision({uid, outcome: 'approved'\|'rejected'\|'revoked', decidedAt})` | uid | `verification_{outcome}` | `/verify/start` | `verification_{outcome}_{uid}_{decidedAt}` |
| #135 | `notifyBusinessDecision({uid, outcome: 'verified'\|'rejected', decidedAt})` | uid | `business_{outcome}` | `/verify/business` | `business_{outcome}_{uid}_{decidedAt}` |
| #135 | `notifyVerificationReminder({uid, stepsLeft, since})` | uid | `verification_reminder` | `/verify/start` | `verification_reminder_{uid}_{since}` |
| #142 | `notifyDisputeOpened({disputeId, providerId, customerId, subject, ticket})` → `NotifyResult \| null` (null for a platform event) | provider | `dispute_opened` | `/disputes/{disputeId}` | `dispute_opened:{disputeId}` |
| #142 | `notifyDisputeResolved({disputeId, recipientIds, subject, kind, providerName, refund, release})` → `NotifyResult[]` | `recipientIds` | `dispute_resolved` | `/disputes/{disputeId}` | `dispute_resolved:{disputeId}` |
| #142 | `notifyDisputeMessage({disputeId, recipientIds, senderId, preview})` → `NotifyResult[]` | `recipientIds` | `dispute_message` (grouped) | `/disputes/{disputeId}` | group `dispute:{disputeId}`, actor = sender |
| #142 | `notifySupportReply({threadId, disputeId: string \| null, messageId, recipientIds, preview})` → `NotifyResult[]` | `recipientIds` | `support_reply` | `/disputes/{disputeId}` when set, else `/help/chat` | `support_reply:{messageId}` |
| #141 | `notifyRefundAccountNeeded({uid, refundId, amount, hasPayer})` | uid | `refund_account_needed` | `/me/payments` | `refund_account_needed:{refundId}` |
| #151 | `notifyRecruitPostNew({recipientId, studioId, postId, title})` | recipient | `recruit_post_new` | `/recruit/{postId}` | `recruit_post_new:{postId}` |
| #151 | `notifyRecruitApplicationNew({studioId, postId, title, applicantId})` | studio | `recruit_application_new` (grouped) | `/studio/recruit?post={postId}` | group `recruit:{postId}:apps`, `eventId` = applicantId, actor = applicant |
| #151 | `notifyRecruitApplicationResult({applicantId, studioId, postId, title, outcome})` | applicant | `recruit_application_result` | `/recruit/{postId}` | `recruit_application_result:{postId}:{outcome}` |
| #151 | `notifyCollabInvite({collaboratorId, studioId, invitedAt})` | collaborator | `collab_invite` | `/collab` | `collab_invite:{studioId}_{invitedAt}` |
| #151 | `notifyCollabInviteResult({studioId, collaboratorId, invitedAt, outcome})` | studio | `collab_invite_result` | `/collab` | `collab_invite_result:{collaboratorId}_{invitedAt}:{outcome}` |
| #151 | `notifyCollabAssignmentOffer({collaboratorId, studioId, bookingId, service, day, start, fee, deadline})` | collaborator | `collab_assignment_offer` | `/collab?offer={bookingId}` | `collab_assignment_offer:{bookingId}_{collaboratorId}` |
| #151 | `notifyCollabAssignmentResult({studioId, collaboratorId, bookingId, outcome, service, day, start, deadline})` | studio | `collab_assignment_result` | `/b/{bookingId}` | `collab_assignment_result:{bookingId}_{collaboratorId}:{outcome}` |
| #151 | `notifyCollabPayDue({studioId, collaboratorId, bookingId, amount, service, day})` | studio | `collab_pay_due` | `/collab` | `collab_pay_due:{bookingId}_{collaboratorId}` |
| #151 | `notifyCollabPayReported({collaboratorId, studioId, bookingId, amount, method})` | collaborator | `collab_pay_reported` | `/collab` | `collab_pay_reported:{bookingId}_{collaboratorId}` |
| #151 | `notifyCollabPayDisputed({studioId, collaboratorId, bookingId, amount, service, day})` | studio | `collab_pay_disputed` | `/collab` | `collab_pay_disputed:{bookingId}_{collaboratorId}` |
| #138 (this plan) | `notifyPayoutReleased({payoutId, payeeId, amount, count})` | payee | `payout_released` | `/work/earnings` | `payout_released_{payoutId}` |
| #138 (this plan) | `sendEventSoonNotices(deps: EventDeps, notify: NotifyDeps, onError?)` → `{events, sent}` | paid ticket holders | `event_soon` | `/e/{eventId}` | `event_soon_{eventId}_{regId}` |

Notes for emitters: call after the commit; each hook has exactly the one emitter in the first column (no other plan calls it); for #136 `notifyBookingReassigned` with the same pair twice is a duplicate by design; for #130, studio bookings send two `notifyReviewVerdict` calls (photographer and studio subjects) and the reviews plan stops emitting `review_new`; the five `notifyDelivery*` hooks are called only by #152 (delivery plan, split from #130) (`onBookingWrite` decider and the `remindAutoApprovals` clock step, Decision 13); #140 also places the primer calls of its row above; #151's `notifyRecruitMatches` fan-out cap (3 per provider per Vietnam day, 200 recipients) stays in #151 and calls `notifyRecruitPostNew` per recipient. Dedupe keys keep each emitter's form (`_` or `:`); a key is unique within one user's inbox.

### Domain changes

```ts
// notification_render.ts — grouped content may carry names
export type NotificationContent = /* existing */ | { type: 'quote_new'; jobTitle: string; count: number; names: readonly string[] } | /* … table above … */;
// notification_use_cases.ts — grouped branch:
//   const t = renderNotification({ ...req.content, count, names: actors.map((a) => a.name) } as NotificationContent);
// event_ports.ts
//   EventRecord gains `readonly soonNoticeAt?: Date | null` (optional so existing literals compile)
//   EventStore gains dueForSoonNotice(now: Date, horizon: Date, limit: number): Promise<EventRecord[]>
// event_notices.ts (new)
export const EVENT_SOON_HOURS = 48;
export function eventSoonContent(ev: EventRecord, now: Date): Extract<NotificationContent, { type: 'event_soon' }>;
export async function sendEventSoonNotices(deps: EventDeps, notify: NotifyDeps,
  onError?: (eventId: string, e: unknown) => void): Promise<{ events: number; sent: number }>;
```

### Functions

```ts
// infra/event_firestore.ts: eventToFirestore writes soonNoticeAt (Timestamp | null); eventFromFirestore reads it;
//   dueForSoonNotice = events where status in ['open','full','closed'], soonNoticeAt == null, startAt > now, startAt <= horizon, limit
// scheduled/event_clock.ts
// The step is appended per #129's clock rule; the existing parameters stay, notify comes through the optional extras:
export interface EventClockExtras { readonly notify?: NotifyDeps /* default liveNotifyDeps() */ }
export async function handleEventClock(deps = liveEventPaymentDeps(), /* existing parameters unchanged */ extras: EventClockExtras = {}):
  Promise<{ closed: number; completed: number; consentExpired: number; refunded: number; soonEvents: number; soonSent: number }>;
  // no refundsResent once #129 has merged (Decision 14)
// triggers/payout_write.ts
export async function handlePayoutWrite(payoutId: string, before: Doc, after: Doc, deps: EarningsDeps, notify?: NotifyDeps): Promise<string | null>;
// tools/clock.ts (new): `npm run clock -- events` | `npm run clock -- bookings`
```

Index (`firestore.indexes.json`): `events` COLLECTION `status ASC, soonNoticeAt ASC, startAt ASC`.

### App

```dart
// notification_targets.dart — safeTarget additionally allows (no query unless stated):
//   /e/:id, /events/:id/manage, /work/earnings, /work/earnings/account,
//   /jobs/:id, /jobs/:id/applications, /instant/:id, /work/instant, /work/instant/:id, /work/instant/offer/:id,
//   /b/:id/delivery, /studio/members, /me/studio, /verify/start, /verify/business,
//   /disputes/:id, /help/chat, /me/payments, /recruit/:id, /collab,
//   query allowed only here: /studio/recruit?post=<id>, /collab?offer=<id> (exactly that one key, id-safe value; any other query refused)
// notification_visuals.dart — new types (icon, tone):
//   review_tomato (favorite, success) · review_brick (chat, action)
//   delivery_submitted (image, action) · delivery_revision_requested (image, action) · delivery_approved (image, success)
//   delivery_auto_approve_soon (schedule, action) · delivery_extra_round (image, neutral)
//   studio_invite, studio_join_request, studio_invite_expiring (store, action) · studio_invite_accepted, studio_join_approved (store, success)
//   studio_removed (store, muted) · booking_assigned (calendar, success) · booking_reassigned (calendar, neutral)
//   assign_reminder (calendar, action) · assign_overdue (calendar, danger) · change_requested (swap, action)
//   change_answered (swap, neutral) · assignment_returned (calendar, action)
//   instant_assigned (instant, success) · instant_missed (instant, muted) · instant_round_ended (instant, action)
//   instant_no_match (instant, action) · instant_arrived (instant, success) · instant_finished (instant, action) · instant_cancelled (instant, danger)
//   payout_account_needed (payment, action) · payout_account_changed (lock, action)
//   verification_approved (verified, success) · verification_rejected (verified, danger) · verification_revoked (verified, danger)
//   verification_reminder (schedule, action) · business_verified (store, success) · business_rejected (store, danger)
//   dispute_opened (flag, action) · dispute_resolved (payment, success) · dispute_message (chat, neutral) · support_reply (supportAgent, neutral)
//   refund_account_needed (payment, action)
//   recruit_post_new (work, neutral) · recruit_application_new (work, action) · recruit_application_result (work, neutral)
//   collab_invite (store, action) · collab_invite_result (store, neutral) · collab_assignment_offer (work, action)
//   collab_assignment_result (calendar, neutral) · collab_pay_due (payment, action) · collab_pay_reported (payment, neutral) · collab_pay_disputed (payment, danger)
// AppIcons gains (this plan; reuse if an emitter plan added one first): lock = Symbols.lock_rounded, flag = Symbols.flag_rounded,
//   supportAgent = Symbols.support_agent_rounded, verified = Symbols.verified_rounded
// notification_primer.dart
class CustomerTicketPrimer extends PrimerContext { const CustomerTicketPrimer(this.eventTitle); final String eventTitle; } // analytics context 'customer_ticket'
// tickets_tab.dart: EventTicketsTab becomes a ConsumerStatefulWidget with a one-shot `_primerAsked`
```

l10n keys: `primerTitleCustomerTicket`: "Bật thông báo để được nhắc trước khi {event} bắt đầu" (placeholder `event`, String); `primerTicketBenefit1`: "Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung".

## Review Focus

1. **A target the app refuses** (today's `event_host_invited` → `/events/:id/manage` already opens "Nội dung này không còn"): every hook's target must pass the app allowlist. This covers the targets of every emitter (#130, #134, #135, #136, #139, #140, #141, #142, #151), including the two query targets of #151. Pinned in Task 2 (`every hook target passes the client allowlist port`) and Task 4 (`safeTarget accepts each new pattern and refuses it with a query`, `post and offer are the only accepted query keys`).
2. **`event_soon` spam or misses** from a clock that runs every 5 minutes: one row per ticket ever, nothing for cancelled/refunded/held registrations or cancelled events, the marker only after all sends succeeded. Pinned in Task 3 (`a second clock run sends nothing`, `a failed send leaves soonNoticeAt null and the next run completes without doubles`, `held, cancelled and refunded registrations get nothing`).
3. **Quote grouping wrong:** the same quote notified twice must not count twice (retry), a read row must restart at 1 with only the new actor, and the names in the body must be the row's actors. Pinned in Task 2 (`notifyQuoteNew: three quotes → one row "3 nhiếp ảnh gia…" with three actors`, `the same photographer and quoteVersion twice is a duplicate`, `after reading, the next quote restarts at 1`).
4. **Prefs and quiet hours ignored for new types:** turning off "Sự kiện" must suppress `event_soon`, "Việc đăng tuyển" must suppress `quote_new`, and the critical types (`assign_overdue`, `payout_released`, `payout_account_changed`, `instant_cancelled`, the verification decisions, `dispute_opened`/`dispute_resolved`/`support_reply`, `refund_account_needed`, `collab_assignment_offer`) must still reach the inbox and push with sound at 23:00. Pinned in Task 2 (`prefs and critical flags apply to the new types`).
5. **Primer at the wrong time:** it must appear once after a fresh ticket (highlight), never when the tickets tab is opened normally, never stacked over another sheet, and never for an OS-granted permission. A paid ticket (S04.04, #129) lands on the same highlight as a free one and gets the same single ask. Pinned in Task 5 (`opening the tickets tab without highlight asks nothing`, `asks once per highlight`, `a paid ticket landing on the highlight asks once`).

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` (Firestore nam5 upper bound $0.06/100K reads, $0.18/100K writes, **chưa xác nhận** for Singapore; FCM free).

**Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. Scale (b) 1,000 MAU, ~300 bookings and ~100 tickets/month; (c) 10,000 MAU, ~3,000 bookings and ~1,500 tickets/month.

- **Per notification sent** (any type, hook or not): prefs `get` 1 read + inbox row transaction 1 read + 1 write + `onNotificationWrite` trigger (count aggregation ≈ 1 read + inbox doc 1 read + 1 write) + FCM device lookup ≈ 1 read ⇒ **≈ 5 reads, 2 writes, 1 trigger invocation**. No listener is added; S17.01 still listens to 30 rows only while open.
- **`event_soon`:** no new job; `eventClock` already runs every 5 minutes (8,640 runs/month). The new query costs ≥ 1 read per run (empty result is billed as one read) = **8,640 reads/month** at both scales; per due event: registrations read once (n) + n notices. (b) 100 notices → ~600 reads, 200 writes, 100 invocations; (c) 1,500 notices → ~9K reads, 3K writes, 1.5K invocations. One new composite index (`status, soonNoticeAt, startAt`).
- **`payout_released`:** the trigger already runs on every payout write; +1 notice per paid payout: (b) ≤ 300/month → 1.5K reads, 600 writes; (c) ≤ 3,000 → 15K reads, 6K writes.
- **Hook types** are emitted by #130/#134/#135/#136/#139/#140/#141/#142/#151; their volume belongs to those plans (cost per notice above, including the one `onNotificationWrite` invocation each). Order of magnitude at (c): ~3 notices per booking or job → ~15K notices → 75K reads, 30K writes.
- **App:** no new reads (targets, visuals and the primer are local).
- No new Storage path, no scheduled job, no paid API, no SMS.
- **Functions (rule above):** this plan's own invocations are the `payout_released`/`event_soon` notices and their `onNotificationWrite` runs: (b) ≤ 800/month → $0; (c) ≤ 9,000 invocations × $0.40/M ≈ $0.004 + ~900 vCPU-s × $0.0000336 ≈ $0.03 → ≈ $0.03.
- **Conclusion:** this plan alone adds **≈ +$0.01/month at (b)** and **≈ +$0.07/month at (c)** (≈ 33K reads + 9K writes ≈ $0.04, Functions ≈ $0.03); including the hook volume once all owners emit, ≈ +$0.20/month at (c). Below the $5 threshold.

## Tasks

### Task 1: Mock frame for the ticket primer

**Files:**
- Modify: `docs/design/ui-mock.html` (S17 section only)

**Interfaces:** none (design source; Task 5 builds to `#S17.03-ticket`).

- [ ] **Step 1:** Read `#S17.03` and the S11.04 tickets frame; reuse their classes (`.step`, `.phone`, `.scr`, `.body`, `.bar`, `.dim`, `.sheet`, `.grab`, `.ic`, `.h3`, `.irow`, `.btn pri`, `.btn txt`, `.meta x`, `.cap`).
- [ ] **Step 2:** Add after `#S17.03` a frame `id="S17.03-ticket"` (`data-code="S17.03"`): behind the sheet, the S11.04 tickets tab (bar "Đặt lịch", segmented "Buổi chụp · Vé sự kiện" with "Vé sự kiện" on, one highlighted ticket "Chụp phố đêm · T7 19/10 · 19:00"); toast "Đã đăng ký. Vé nằm trong mục Vé sự kiện."; sheet: bell disc, `.h3` "Bật thông báo để được nhắc trước khi Chụp phố đêm bắt đầu", two `.irow` rows (`calendar_today` "Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung"; `chat_bubble` "Tin nhắn mới khi app đang ở nền"), `.btn pri` "Bật thông báo", `.btn txt` "Để sau", `.meta x` "Chọn \"Để sau\", chúng tôi sẽ hỏi lại sau 7 ngày.". Caption: `<span class="n new">Mới</span><span class="n">S17.03 · Sau khi mua vé</span><b>Hỏi ngay sau vé vừa mua</b><span>Hiện một lần khi vào tab Vé sự kiện với vé vừa mua; không hỏi khi mở tab bình thường. Cùng luật 7 ngày của "Để sau".</span>`.
- [ ] **Step 3:** In the S17.01 caption append: "Dòng gom báo giá đến từ việc đăng (S15.03); dòng sự kiện gửi một lần trong 48 giờ trước giờ bắt đầu, mở chi tiết sự kiện."
- [ ] **Step 4:** Check the HTML parses (`python3 -c "import html.parser;html.parser.HTMLParser().feed(open('docs/design/ui-mock.html').read())"`) and `#S17.03-ticket` resolves.
- [ ] **Step 5: Commit** `docs(mock): S17.03 ticket primer variant [#138]` (TonyH trailer).

### Task 2: Domain — catalogue, copy, grouped names and hooks

**Files:**
- Create: `packages/domain/src/notification_hooks.ts`, `packages/domain/test/notification_hooks.test.ts`, `packages/domain/test/client_targets.ts` (test-only port of the app allowlist after Task 4)
- Modify: `packages/domain/src/notification.ts`, `notification_render.ts`, `notification_use_cases.ts`, `index.ts`, `test/notification.test.ts`, `test/notification_render.test.ts`, `test/notification_use_cases.test.ts`, `test/booking_notifications.test.ts` (copy changes)

**Interfaces:**
- Produces: the catalogue rows and `NotificationContent` members of the Contract table (including the #134, #135, #140, #141, #142 and #151 types), the changed booking copies, the grouped `names`, every hook of the hooks table except `sendEventSoonNotices` (Task 3), `notifyPayoutReleased`, and `isAllowedTarget(path: string): boolean` in `test/client_targets.ts` (mirrors the Dart `safeTarget` patterns listed in the App contract plus the existing ones).

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests.**
  `notification.test.ts`: `every new type has meta (category, tab, critical) as in the plan table`; `the critical set is exactly the ✓ rows of the table`; `review_tomato and review_brick are badges/system`.
  `notification_render.test.ts` (table-driven over the Contract table): `each type renders its verbatim title and body`; `quote_new 1, 2 and 3+ actors`; `quote_new with fewer names than count falls back to "Nhiếp ảnh gia"`; `event_soon 2 days / tomorrow / today`; `job titles are cut to 40 graphemes with …`; `booking_declined, booking_cancelled and refund_done no longer contain "Cọc"` and match the mock S17.01 strings.
  `notification_use_cases.test.ts`: `grouped render receives the actors' names newest first`; `chat_message grouped copy unchanged`.
  `notification_hooks.test.ts` (with `createNotifyWorld`, users seeded with names):
  - `notifyQuoteNew: three quotes → one row "3 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”" with three actors and body "Minh Trí, Lan Chi và 1 người khác. Xem và so sánh báo giá."` (Review Focus 3).
  - `the same photographer and quoteVersion twice is a duplicate`; `a new quoteVersion of the same photographer counts again`; `after reading, the next quote restarts at 1 with one actor`.
  - `notifyJobExpiring with an extended quoteDeadline sends a second notice`; `notifyInstantCancelled by customer goes to the photographer with /work/instant/{id} and the fee line, by photographer goes to the customer with /instant/{id}`; `notifyDisputeOpened returns null for a platform event`; `notifySupportReply targets /disputes/{id} with a dispute, /help/chat without`; `notifyRecruitApplicationNew groups per post`; `notifyPayoutAccountChanged renders the bank short name and the Vietnam time`.
  - For every other hook (table-driven): `writes one row for each recipient with the type, target and dedupe id of the plan table`; `a second call is a duplicate`.
  - `notifyBookingAssigned sends to customer and assignee with their own copy`; `notifyBookingReassigned sends three rows`; `notifyAssignOverdue reaches the inbox even when the booking channel is off`.
  - `prefs and critical flags apply to the new types` (events channel off → a `notify` of `event_soon` content returns `suppressed`; jobs channel off → `notifyQuoteNew` returns `suppressed`; `assign_overdue` and `payout_released` push with channel `default` at 23:00 Vietnam time) (Review Focus 4).
  - `every hook target passes the client allowlist port` (collect `target` of every row written above and assert `isAllowedTarget`) (Review Focus 1).
  - `a hook never throws for a missing user name (fallback names)`.
- [ ] **Step 3:** `cd packages/domain && npm test` → fail.
- [ ] **Step 4: Implement.** Grouped branch of `notify` (only change in that function):
  ```ts
  const actors = [req.actor, ...(carried?.actors ?? []).filter((a) => a.id !== req.actor?.id)].slice(0, 3);
  const t = renderNotification({ ...req.content, count, names: actors.map((a) => a.name) } as NotificationContent);
  ```
  Hooks: a private `nameOf(deps, id, fallback)` and `actorOf` like `booking_notifications.ts`; multi-recipient hooks use `Promise.allSettled` and throw one error at the end if any recipient failed (same contract as `notifyBookingChange`). Export the module from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): notification copy for every S17 type and hooks for every emitting use case [#138]`.

### Task 3: Event reminders, payout released, clock tool

**Files:**
- Create: `packages/domain/src/event_notices.ts`, `packages/domain/test/event_notices.test.ts`, `app_flutter/firebase/functions/tools/clock.ts`, `app_flutter/firebase/functions/test/unit/payout_write.test.ts`, `app_flutter/firebase/functions/test/unit/clock_cli.test.ts`, `app_flutter/firebase/functions/test/integration/event_soon.test.ts` (written, not run)
- Modify: `packages/domain/src/event.ts` (`EventRecord.soonNoticeAt?`), `event_ports.ts` (`dueForSoonNotice`), `memory_event_store.ts`, `index.ts`; `app_flutter/firebase/functions/src/infra/event_firestore.ts`, `src/scheduled/event_clock.ts`, `src/triggers/payout_write.ts`, `src/index.ts` (`onPayoutWritten` passes the id and `liveNotifyDeps()`), `package.json` (`"clock": "tsx tools/clock.ts"`), `seed/fixtures.ts`, `seed/README.md`, `test/unit/event_firestore.test.ts`, `test/unit/seed_fixtures.test.ts`; `app_flutter/firebase/firestore.indexes.json`

**Interfaces:**
- Consumes: Task 2 (`event_soon` content, `notifyPayoutReleased`).
- Produces: `EVENT_SOON_HOURS`, `eventSoonContent`, `sendEventSoonNotices`, `EventStore.dueForSoonNotice`, `EventRecord.soonNoticeAt`, `EventClockExtras.notify`, `handleEventClock(deps, …, extras)` with `soonEvents`/`soonSent`, `handlePayoutWrite(payoutId, before, after, deps, notify?)`, the `clock` tool, the index, seed `SEED_EVENT_SOON` (+ Lan's paid registration).

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests.**
  `event_notices.test.ts` (`createEventWorld` + `createNotifyWorld`):
  - `an open event starting in 36 h notifies each paid ticket once and sets soonNoticeAt`.
  - `a second clock run sends nothing` (Review Focus 2).
  - `held, cancelled and refunded registrations get nothing`; `a cancelled or completed event is not due`; `an event 49 h ahead is not due; one already started is not due`.
  - `a failed send leaves soonNoticeAt null and the next run completes without doubles` (push/store throws once for one user).
  - `title says "bắt đầu sau 2 ngày" 30 h before a next-next-day start; "ngày mai"; "hôm nay"` (Vietnam calendar days, clock near midnight UTC+7).
  - `place is the meeting point, else the location name`; `thumbUrl is the cover`; `target is /e/{eventId}`.
  Functions:
  - `event_firestore.test.ts`: `soonNoticeAt round-trips; absent reads null`; `dueForSoonNotice builds the status/soonNoticeAt/startAt query with the limit` (as the existing `dueFor*` tests do).
  - `payout_write.test.ts`: `pending → paid sends payout_released with amountNet when present`; `falls back to amount`; `paid → paid (rewrite) sends nothing`; `pending → failed sends nothing`; `the earnings refresh still runs first and a notify failure is rethrown after it` (so the trigger retries; the dedupe prevents doubles).
  - `clock_cli.test.ts`: `refuses a non-local Firestore host`; `events runs handleEventClock once and prints the counts`; `unknown command prints usage`.
  - `seed_fixtures.test.ts`: `SEED_EVENT_SOON starts 36 h after seeding, is open, has soonNoticeAt null and Lan's paid ticket`.
  Integration (written, not run): seed an event 36 h ahead with a paid registration, run `handleEventClock`, expect one `event_soon` row in `users/{uid}/notifications` and `soonNoticeAt` set.
- [ ] **Step 3:** Domain `npm test`; Functions `npm test` → fail.
- [ ] **Step 4: Implement.** `sendEventSoonNotices`:
  ```ts
  for (const ev of await deps.events.dueForSoonNotice(now, new Date(now.getTime() + EVENT_SOON_HOURS * HOUR_MS), BATCH)) {
    try {
      const regs = (await deps.events.runTransaction((tx) => tx.activeRegistrations(ev.id))).filter((r) => r.status === 'paid');
      const content = eventSoonContent(ev, deps.clock.now());
      const results = await Promise.allSettled(regs.map((r) => notify(notifyDeps, {
        userId: r.userId, content, target: `/e/${ev.id}`, dedupeKey: `event_soon_${ev.id}_${r.id}`, thumbUrl: ev.coverUrl,
      })));
      sent += results.filter((x) => x.status === 'fulfilled' && x.value === 'created').length;
      if (results.some((x) => x.status === 'rejected')) throw new Error('event_soon send failed');
      await deps.events.runTransaction(async (tx) => {
        const fresh = await tx.getEvent(ev.id);
        if (fresh === null || fresh.soonNoticeAt != null) return;
        tx.putEvent({ ...fresh, soonNoticeAt: deps.clock.now() }); // version unchanged: a server marker, not an edit
      });
      events += 1;
    } catch (e) { onError(ev.id, e); }
  }
  ```
  `daysLeft` = whole days between `formatVnDate(now)` and `formatVnDate(startAt)`; `start` = `formatVnTime(startAt)`. `handleEventClock` runs `sendEventSoonNotices` as the last named step of its step list (own try/catch; notify deps from `extras.notify ?? liveNotifyDeps()`), logging per-event errors with the event id only; drop `refundsResent` from the result when #129 has merged (Decision 14). `handlePayoutWrite`: refresh first (unchanged), then on the paid transition call `notifyPayoutReleased`. `tools/clock.ts`: `assertLocalEmulators({ allowAnyProject: true })`, then `events` → `handleEventClock()`, `bookings` → `handleBookingClock(undefined, liveReminderDeps())`. Seed: `SEED_EVENT_SOON = 'seed-event-an-night-walk'`, title "Chụp phố đêm", type `photo_walk`, free, start = seeding time + 36 h (give `make` an hours-ahead variant), Lan's paid registration with a new ticket code; README rows for it and for `npm run clock -- events`. Index entry from the Contract.
- [ ] **Step 5:** Domain `npm test && npm run lint`; Functions `npm test && npm run build` green. Ledger: integration test written, not run.
- [ ] **Step 6: Commit** `feat(functions): event reminders 48 h before, payout released notice, clock tool for the emulator [#138]`.

### Task 4: App — icons, tones and targets for every type

**Files:**
- Modify: `app_flutter/lib/features/notifications/notification_visuals.dart`, `notification_targets.dart`, `app_flutter/lib/core/theme/app_icons.dart` (`lock`, `flag`, `supportAgent`, `verified` if absent)
- Test: `test/features/notifications/notification_visuals_test.dart`, `notification_targets_test.dart`, `notifications_screen_test.dart`

**Interfaces:**
- Consumes: the type list of Task 2 (by name; the app has no import of the TS table).
- Produces: the visuals and allowlist of the App contract.
- **Backend wiring:** rows come from `users/{uid}/notifications` via `FirestoreNotificationRepository` (unchanged listener on the 30 newest rows while S17.01 is open); taps go through `safeTarget` then `openNotificationTarget`. On the emulator: Lan's `event_soon` row (after `npm run clock -- events`) opens `/e/seed-event-an-night-walk`; An's `event_host_invited` style targets open `/events/:id/manage`.
- **Mock parity (`#S17.01`):** grouped quote row = `work` icon, neutral tone, three stacked avatars, title and body as the mock; event row = ticket icon with the cover thumbnail; refund row = payment icon in the success tone; declined row = calendar in the danger tone; unread dot + hidden "Chưa đọc" label unchanged.

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests:**
  - Visuals (table-driven): `each new type has the plan's icon and tone`; `every server type of the plan table has a non-default visual` (list of all type codes written in the test).
  - Targets: `safeTarget accepts each new pattern and refuses it with a query` (`/e/x`, `/events/x/manage`, `/work/earnings`, `/work/earnings/account`, `/jobs/x`, `/jobs/x/applications`, `/instant/x`, `/work/instant`, `/work/instant/x`, `/work/instant/offer/x`, `/b/x/delivery`, `/studio/members`, `/me/studio`, `/verify/start`, `/verify/business`, `/disputes/x`, `/help/chat`, `/me/payments`, `/recruit/x`, `/collab`); `post and offer are the only accepted query keys` (`/studio/recruit?post=x` and `/collab?offer=x` accepted; `/collab?post=x`, `/studio/recruit?post=x&a=1`, `/studio/recruit?post=../x` refused); `bad ids are refused` (`/jobs/../x`, `/e/` + 129 chars); `existing patterns unchanged`.
  - Screen: `a grouped quote_new row shows the three avatars and opens /jobs/j1/applications` (fake repository row with `count: 3`, three actors; a stub route for `/jobs/:id/applications`); `an event_host_invited row opens /events/e1/manage` (regression for the old bug); `an event_soon row shows the cover thumbnail`.
- [ ] **Step 3:** `flutter test --no-pub --timeout 60s test/features/notifications` → fail.
- [ ] **Step 4: Implement** (extend the `switch (segments)` in `safeTarget`; keep `targetNeedsExistenceCheck` as is: `/b/:id/delivery` has four segments and is not checked).
- [ ] **Step 5:** `flutter analyze`; `flutter test --no-pub --timeout 60s test/features/notifications` green.
- [ ] **Step 6: Commit** `feat(notifications): icons, tones and deep links for every notification type [#138]`.

### Task 5: S17.03 primer after buying a ticket

**Files:**
- Modify: `app_flutter/lib/features/notifications/notification_primer.dart`, `lib/features/events/tickets_tab.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/notifications/notification_primer_test.dart`, `test/features/events/tickets_tab_test.dart`

**Interfaces:**
- Consumes: `maybeAskForNotifications`, `EventTicketsTab.highlightId`.
- Produces: `CustomerTicketPrimer`, l10n `primerTitleCustomerTicket`, `primerTicketBenefit1`.
- **Backend wiring:** none (OS permission + local primer policy; FCM registration through the existing `pushRegistrationProvider` when granted). On the emulator: Lan registers for a free event → lands on Vé sự kiện with the ticket highlighted → the sheet appears once.
- **Mock parity (`#S17.03-ticket`):** title with the event name, two benefit rows (calendar, chat), primary "Bật thông báo", text button "Để sau", note "Chọn \"Để sau\", chúng tôi sẽ hỏi lại sau 7 ngày."; one primary.

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests:**
  - Primer: `CustomerTicketPrimer shows "Bật thông báo để được nhắc trước khi Chụp phố đêm bắt đầu" and the two ticket benefits`; `analytics context is customer_ticket`.
  - Tickets tab (fake push/permission from `test/support/fake_push.dart`): `asks once per highlight when the highlighted ticket is shown` (pump the list, sheet visible; rebuild → no second sheet); `opening the tickets tab without highlight asks nothing` (Review Focus 5); `a highlight that is not an upcoming ticket asks nothing`; `granted permission asks nothing`; `"Để sau" closes it and the 7-day policy is recorded`; `a paid ticket landing on the highlight asks once` (the route `/bookings?tab=events&highlight=<regId>` that #129's TicketPay uses; Decision 9).
- [ ] **Step 3:** Run (`test/features/notifications`, then `test/features/events`) → fail.
- [ ] **Step 4: Implement.** `EventTicketsTab` → `ConsumerStatefulWidget`; after the data frame where `emphasised == highlightId`, `WidgetsBinding.instance.addPostFrameCallback` → `maybeAskForNotifications(context, ref, CustomerTicketPrimer(ticket.event.title))` guarded by `_primerAsked` (same pattern as `booking_detail_screen.dart` ~line 341). `_PrimerSheet` picks the title and benefits by context (ticket: `[PrimerBenefit(AppIcons.calendar, l.primerTicketBenefit1), PrimerBenefit(AppIcons.chat, l.primerBenefit3)]`). `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze`; both folders green, one at a time (call `resetNotificationPrimerState()` in `tearDown`).
- [ ] **Step 6: Commit** `feat(notifications): S17.03 primer after buying a ticket [#138]`.

### Task 6: Specs, hooks hand-off, ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3h.2 (table: every type of the Contract catalogue with role, icon, filter, target, note; `booking_cancelled` note "Hoàn {percent}% số đã trả"; `job_selected` marked "thay bằng `quote_accepted`"; a paragraph "Hook theo use case" listing the hooks table by owner) and §2 (S17.01 "✅ đã làm (10a) · đủ loại + hook (#138)"; S17.03 "✅ (10a) · thêm sau khi mua vé (#138)"); `docs/superpowers/specs/screens/account.md` (S17.01 types and S17.03 contexts; strings match `app_vi.arb`); `docs/superpowers/specs/2026-10-06-tomato-brick-reviews-design.md` §7.4, `2026-10-06-delivery-preview-unlock-design.md` §6, `2026-10-06-studio-members-design.md` §7 (one line each: "Hook: `notify…` trong `packages/domain/src/notification_hooks.ts` (#138)"); the same line in `2026-10-06-payments-payouts-design.md` (payout account, refund account), `2026-10-06-identity-verification-design.md` (verification), `2026-10-07-studio-recruiting-design.md` §8 (the ten S27 types), `2026-10-01-instant-booking-design.md` (instant types); `docs/superpowers/specs/data-model/domain-model.md` (`Event.soonNoticeAt`); `docs/superpowers/specs/data-model/relational-schema.md` (`events.soon_notice_at timestamptz null`)
- Create: `docs/superpowers/handover/ledger-s17-notifications.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names); check S17 strings against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings (Decisions 1–11 and anything ledgered during the tasks); the hooks table by emitter (#130, #134, #135, #136, #139, #140, #141, #142, #151) with "call after commit, from a trigger or callable, `liveNotifyDeps()`; you are the only caller"; skipped suites (integration test written, not run); deploy notes: (1) deploy the new `events` index before the functions (the clock query fails without it); (2) events written before deploy have no `soonNoticeAt` and never get a reminder; (3) no new scheduled job, no rules change; deferred list below.
- [ ] **Step 3: Commit** `docs(spec): S17 notification catalogue, hooks by use case, event reminder [#138]`.

## Deferred

- Emitting the hook types: quotes/jobs → #139; Chụp ngay (and its primer call sites, high-priority invitation push) → #140; tomato/brick reviews and delivery → #130; studio membership and assignment → #136; payout account → #134; verification → #135; disputes and support → #142; refund account → #141; recruiting and collaborators → #151.
- `event_cancelled` / `event_changed` for ticket holders → owner question 1.
- A reminder for tickets bought after the event-level `event_soon` pass (Decision 4).
- `promo` emission (needs a staff tool, dashboard #83).
- Email copies of critical notices (account change, cancellations).
- iOS APNs configuration (10a deferred, plan 15).
- Go backend (phase 2, #90) adapter for `NotificationStore`/`PushSender`: the hooks are reusable as is.
