# Handover ledger — 10c (photo events S11.01–S11.06, S12.01–S12.03)

Unit: `10c` (issue #126, GitHub Project 4), stacked on `plan/stack-2026-10`.
Plan: `docs/superpowers/plans/2026-10-06-10c-events.md`. Tasks 1–10, commit tag `[10c]`.

## What shipped

| Task | Commits | Scope |
|---|---|---|
| 1 Domain | 33e23b6, 70750ea | events, registrations, hashtag, ticket code, sweeps, O1 consent |
| 2 Functions, rules, indexes | 6f4bd5e, 905f1f3 | callables, `eventClock`, rules, rules tests |
| 3 App data | 5240d7d, 2032481 | `lib/data/events/`, nearby events, staff role |
| 4+5 S11.01–S11.04 (free) | 1d1eb80, cdf5fa1, b206035 | list, detail, register sheet, tickets tab |
| 6 S12.01–S12.03 | c5417c8, 436398c, 0108599 | create (2 steps), manage, check-in scanner |
| 7+8 Timeline, group chat | 8508331, 9704a7c, 9e83209 | S11.05, S11.06, triggers, moderation |
| 9 Paid tickets (backend) | a3f5ce8 | holds, payments, refunds, escrow, fake-payment gate |
| 10 Paid tickets (app) | see `git log --grep '\[10c\]'` | S11.03 paid, S11.04 pending/refund, S12.03 revenue |

## Rulings (from the SDD progress ledger)

- Free registrations carry `contactEligible: false` and write no contact snapshot (O3); `ticketContactUnlocked` needs the flag. Paid tickets set it when the payment lands.
- `updateEvent` refuses date/deadline/price changes once seats are sold or held (`conflict`); hosts cancel to change dates.
- An accepted staff draft returns to `pending` consent when material fields change (O1).
- From Task 6 on every screen is wired to its real adapter/callable and checked against its mock.
- **Decision 17 overridden (Task 7+8 C1):** `event_share` posts carry `photographerId: ''` so they never appear in the host's portfolio. No backfill for shares written before the fix (seed/dev only).
- Owner 2026-10-07: a member removed by a moderator rejoins only with a paid registration created after the removal, or by the moderator "Cho vào lại" (restore); S12.03 header "Check‑in" link built; S12.01 cover tile dashed like the mock.
- **Task 9:** paid tickets reuse the booking payment plumbing (PaymentGateway port, fake gateway, `payments` / `refunds` / `ledger_entries`, `bookingClock` step 5 release). The VietQR / licensed-intermediary move happens for bookings and tickets together in issue #129.
- **Task 9 security fix:** one shared fake-payment gate (`functions/src/infra/fake_payments.ts`, `DEV_PROJECT_ID` in `config.ts`) now guards the booking `confirmFakePayment` and the new `confirmFakeTicketPayment`: allowed only on the emulator (`FUNCTIONS_EMULATOR=true` with a `demo-*` or the dev project id, fix round M2) or the dev project `booking-c1922`, otherwise `failed-precondition` `fake_payments_disabled` before any read or write.
- **Task 9:** `registerEvent`, `cancelRegistration`, `confirmFakeTicketPayment`, `checkTicketPayment` run with a 30 s timeout (`PAYMENT_CALLABLE_OPTIONS`), `cancelEvent` 60 s (it refunds each ticket); the app waits 35 s / 65 s.
- **Task 9 (N4):** a registration keeps `createdAt` = the hold time when it is paid, so a hold taken before a moderator removal and paid after it does not re-admit the user (domain test in `event_chat.test.ts`).
- **Task 9:** a cancelled event marks every ticket whose money is held `refundDue: true` (paid tickets, and tickets cancelled late without a refund); each is refunded 100% in its own transaction, `eventClock` retries leftovers through the collection-group query `refundDue == true`. Completion stamps `releaseAfter = endAt + 24 h` on every held ticket payment of the event (query by the new `payments.eventId`). A late payment (hold expired, cancelled, second intent) is refunded 100% at once (`late_payment_hold_expired`).
- **Task 9+10 fix round (I1, I2, M1–M6):** released ticket money enters the host's daily payout like bookings (`isPayoutPayable` in the domain: released, not batched, payee not `platform`; used by `FirestorePayoutStore` and the memory store); platform-event money never enters a provider payout. S11.04 shows only the upcoming ticket as the big card; pending, expired, past, cancelled and refunded tickets are the mock's compact row (`TicketCard(compact: true)`: `DateBlock`, title, "n vé · place", badge; a small "Thanh toán tiếp" under the text while the hold runs). A ticket refund is mirrored on the registration (`refundId`, `refundStatus` pending/done/failed): "Đang hoàn" until `done`, "Đã huỷ · đang hoàn tiền" / "Đã huỷ · đã hoàn tiền" for a payment that came after the hold; `eventClock` re-sends ticket refunds left `pending` for 10 minutes under the same refund id (`resendTicketRefund`, the gateway keys refunds by id), `failed` stays manual for staff. The fake-payment gate on the emulator now also needs the project id to be `demo-*` or the dev id. "Thanh toán tiếp" sends no provider and the server keeps the hold's current one. The payment sheet shows a SnackBar on errors (`fake_payments_disabled` has its own text). `cancelRegistration` that loses the race with a host cancel returns the stored `refunded` status.
- **Task 10:** S11.03 payment methods follow the mock ("Chuyển khoản QR", "MoMo", "ZaloPay"); until #129 they map onto the gateway's codes: Chuyển khoản QR → `vnpay` (VNPAY-QR), MoMo → `momo`, ZaloPay → `vnpay`.

## Skipped emulator suites (written, not run here; CI runs them)

- `app_flutter/firebase/rules-test/rules.test.mjs`: event, registration, contact, timeline and group-chat rules (Tasks 2, 6, 7+8).
- `app_flutter/firebase/functions/test/integration/event.test.ts` (Task 2), `event_timeline.test.ts`, `event_chat.test.ts` (Tasks 7+8), `event_paid.test.ts` (Task 9: paid register + fake confirm, hold expiry frees the seat, cancel event refunds and removes members).

## Deploy notes

- Indexes before the app build: `chats (members, kind, lastMessageAt desc)` (Task 7+8), `payments (eventId, status, escrowStatus)` and the `registrations.refundDue` collection-group field override (Task 9), `refunds (subjectType, status, createdAt)` (fix round, the pending ticket refund re-send). Refunds now store `subjectType`; refunds written before have none and are never re-sent (none are pending outside dev). CI deploys them with Firestore on push.
- New scheduled function `releaseEventHolds` (every minute) and callables `confirmFakeTicketPayment`, `checkTicketPayment`.
- Events published before Task 7 have a group chat without moderator member docs (they still send; a one-off backfill fixes the member list).

## Deferred

- Push for announcements, cancellations and "Có ảnh mới" (no push pipeline for events yet, S17 plans).
- Analytics events of `events.md` (no analytics layer; `ContactAction.onEvent` unused).
- Post-publish edit UI (the `updateEvent` callable exists; the app edits drafts only).
- "Tạo hộ" UI: staff photographer picker on S12.01 (backend and the photographer's accept/decline exist; `hostInvitationsProvider` is not shown anywhere, the photographer reaches an invitation only through the notification).
- Support inbox for platform events (S23.06); S11.02 shows the FAQ and a fixed support line. The address `hotro@photobooking.vn` in `event_links.dart` is a placeholder the owner must confirm.
- Report sheet ("Báo cáo" in the S11.06 long-press menu is a disabled "Sắp có" row until S20.01).
- QR brightness: the full-screen ticket QR does not raise the screen brightness (no plugin).
- Author post deletion: a post deleted by its author should leave the timeline once post deletion exists.
- In-app unread badges for group chats (no per-message counters for groups by design).
- `PaymentGateway.createDepositIntent` naming: tickets pass the registration id as `bookingId` (plan I6 renames the port).
- Gateway refund failures of tickets are marked `failed` / `manual` for staff, like bookings (the customer keeps seeing "Đang hoàn"); the clock re-sends only refunds left `pending` (fix round M1). A staff screen for failed refunds is S23.
- M7 (carried to #129): `checkTicketPayment` asks the gateway only about the registration's latest intent (`reg.paymentId`); an earlier intent paid with the other provider waits for the provider callback, which #129 adds.
- A late payment of an earlier intent on a ticket already refunded (or paid through another intent) is refunded but not shown on that ticket (the ticket keeps its own refund state).
- Earnings: host ticket money now shows in S06.05 (`earnings_firestore` reads the registration); platform-hosted ticket money has no earnings page (payee `platform` is skipped).

### Deferred minors from the reviews (Tasks 1–8)

- Task 2: admin cannot list drafts; svg covers allowed like other upload paths.
- Task 3: `watchMine` sorts on the client (undated drafts).
- Task 4+5: raw colours/sizes in a few places; ticket card tap lacks a semantics label; duplicate `EventScreen` under `/e/:id/join`; re-registering with an identical highlight id would not reopen the tickets tab.
- Task 6: M4 raw numbers (work_screen 480 height, alphas, hashtag 40); M6 "Huỷ sự kiện" is a `TextButton` not `AppButton.text`; M7 `media_platform_config_test` name vs the CAMERA permission `mobile_scanner` merges; a stale value keeps the form during a draft reload; unrelated reformatting in `DateBlock`/`EventCard`.
- Task 7+8: M6 members can read every member doc (lastReadAt, mutedUntil, removedBy, …) — accepted; N1 the moderators-only test passes on old code (assert the SnackBar, add a fallback case); N2 the Check‑in header duplicates `SectionHeader`, the dashed painter duplicates `availability_calendar`'s; N3 a cancelled event removes free attendees from the chat at once, so the 7-day read-only window serves moderators and refund-pending ticket holders only; M10 the app mirrors the server's moderator seed; M12 the pending-post count refreshes late beyond the newest 100.

## Owner questions ("Needs the owner" in the Task 9+10 brief)

1. Staff hosting for a photographer (question 17): answered by O1 (draft until the photographer accepts within 24 h). Backend and photographer side done; staff picker deferred (above).
2. Support inbox for platform events (question 16): answered by O2 (FAQ + fixed support email until S23.06). Open: confirm the support address.
3. Free tickets unlock contact: answered by O3 (they do not; only paid tickets after payment).
4. Late cancellation of a paid ticket (< 48 h): answered by O4 (allowed, no refund, seat freed, money released to the host after the event). Implemented in Task 9; a host cancel afterwards refunds that money too.
5. New (Task 10): confirm the S11.03 mapping of "Chuyển khoản QR" and "ZaloPay" onto the VNPay gateway code until #129 brings the real methods.
