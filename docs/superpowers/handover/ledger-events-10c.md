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
| 10 Paid tickets (app) | a27b212, dc6a79d, e2c355d | S11.03 paid, S11.04 pending/refund, S12.03 revenue |
| Final review fix round | 2d992a9 + the docs commit after it | S11.04 ticket and S11.01 featured card match the mock, S12.02 FAQ editor (O2), refund guard tests, support line hidden, specs/data model for O1–O4 |

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
- **Task 9+10 fix round (I1, I2, M1–M6):** released ticket money enters the host's payout through the same path as bookings: staff run `createPayout` / `executePayout` (no daily job, no first-payout approval and no tax withholding yet — payments-payouts spec §5–7, unbuilt for bookings too) (`isPayoutPayable` in the domain: released, not batched, payee not `platform`; used by `FirestorePayoutStore` and the memory store); platform-event money never enters a provider payout. S11.04 shows only the upcoming ticket as the big card; pending, expired, past, cancelled and refunded tickets are the mock's compact row (`TicketCard(compact: true)`: `DateBlock`, title, "n vé · place", badge; a small "Thanh toán tiếp" under the text while the hold runs). A ticket refund is mirrored on the registration (`refundId`, `refundStatus` pending/done/failed): "Đang hoàn" until `done`, "Đã huỷ · đang hoàn tiền" / "Đã huỷ · đã hoàn tiền" for a payment that came after the hold; `eventClock` re-sends ticket refunds left `pending` for 10 minutes under the same refund id (`resendTicketRefund`, the gateway keys refunds by id), `failed` stays manual for staff. The fake-payment gate on the emulator now also needs the project id to be `demo-*` or the dev id. "Thanh toán tiếp" sends no provider and the server keeps the hold's current one. The payment sheet shows a SnackBar on errors (`fake_payments_disabled` has its own text). `cancelRegistration` that loses the race with a host cancel returns the stored `refunded` status.
- **Final review fix round (I1, I2):** the S11.04 upcoming `TicketCard` and the S11.01 featured `EventCard` now follow the mock exactly (type tag pill, one meta line, QR row with hint and code, "Chỉ đường" outline + "Thêm vào lịch" secondary, red cancel under the card; featured 16:10, light seat pill top-left with a status dot, overlay "weekday dd/MM · HH:mm · place" / title / "host · n/cap đã đăng ký", no price). "Vào nhóm chat" stays on the ticket as a full-width small outline button under the two buttons (spec S11.06 entry point) and is now drawn in the mock. The O2 FAQ is entered on S12.02 by staff for platform events (compact question/answer rows, at most 10, half-filled rows flagged; `EventForm.faq` → `EventDraft.faq` → `saveEventDraft`); the mock drew no FAQ field, so it was added to S12.02 below the price hints, before the preview, and to the mock and the screen spec.
- **Final review fix round:** the S11.02 support line is hidden (`eventSupportEmail` in `event_links.dart` is a nullable constant set to `null`): `hotro@photobooking.vn` was an invented domain on a live `mailto:`. Platform events show only the FAQ until the owner gives an address (owner question 2 below).
- **Task 10:** S11.03 payment methods follow the mock ("Chuyển khoản QR", "MoMo", "ZaloPay"); until #129 they map onto the gateway's codes: Chuyển khoản QR → `vnpay` (VNPAY-QR), MoMo → `momo`, ZaloPay → `vnpay`.

## Skipped emulator suites (written, not run here; CI runs them)

- `app_flutter/firebase/rules-test/rules.test.mjs`: event, registration, contact, timeline and group-chat rules (Tasks 2, 6, 7+8).
- `app_flutter/firebase/functions/test/integration/event.test.ts` (Task 2), `event_timeline.test.ts`, `event_chat.test.ts` (Tasks 7+8), `event_paid.test.ts` (Task 9: paid register + fake confirm, hold expiry frees the seat, cancel event refunds and removes members).

## Deploy order (merge of PR #32)

Nothing here was deployed by this unit; CI deploys Firestore and the functions on push, Storage only on a manual run.

1. **Firestore rules and indexes** (CI, on push). Let every new index finish building before the functions and the app use it:
   - `chats (members, kind, lastMessageAt desc)` (Task 7+8): S07.02 and the Home unread count error until it is built;
   - the `events` composites: `(status, [type], [price], startAt)` and `(status, location.geohash, startAt / createdAt)`;
   - `registrations` collection group `(userId, createdAt desc)` and `(status, holdExpiresAt)`, plus the `id` and `refundDue` field overrides (Task 9);
   - `timeline (status, addedAt desc)`;
   - `events (status, createdAt)`; `events (createdBy, startAt desc)` and `(hostId, startAt desc)` (the `watchMine` `Filter.or` behind S06.01 "Sự kiện của tôi"); `events (status, registrationDeadline)`, `(status, endAt)` and `(status, hostConsent, hostConsentExpiresAt)` (the `eventClock` sweeps); collection-scope `registrations (status, holdExpiresAt)` (hold release). `eventClock` and S06.01 error until these are built;
   - `payments (eventId, status, escrowStatus)` (Task 9);
   - `refunds (subjectType, status, createdAt)` (fix round): the `refund_resend` step of `eventClock` logs errors until it is built. Refunds now store `subjectType`; refunds written before have none and are never re-sent (none are pending outside dev).
2. **Storage rules: manual, required.** `storage.rules` adds `eventCovers/{uid}/{eventId}/{file}`; without it every S12.01 cover upload is refused and, since the cover is required at publish (Decision 6), no event can be published on dev. Right after merging, either run the **firebase-deploy** workflow by hand (Actions → firebase-deploy → Run workflow, `target: dev`, `storage: true`), or from `app_flutter/firebase/rules-test/`:

   ```bash
   npm run deploy:storage:dev
   ```

   Production later: the same workflow with `target: production`, or `npm run deploy:storage:prod`.
3. **Functions** (CI job `deploy-functions`, after the domain and functions tests): adds the scheduled `releaseEventHolds` (every minute) and `eventClock`, and the callables `confirmFakeTicketPayment` and `checkTicketPayment`.
4. **App build last.** The events-enabled app build (`eventRoutesReadyProvider` / `eventPaymentsReadyProvider` true) goes to testers only after steps 1–3: every index above built, Storage rules and functions deployed.
5. **Production release stays blocked on #129**: the fake-payment gate refuses outside the emulator and the dev project and no real gateway exists, so paid tickets (and bookings) cannot be paid there. iOS also needs `NSCameraUsageDescription` before the check-in scanner ships on iOS.

Other notes:
- Events published before Task 7 have a group chat without moderator member docs (they still send; a one-off backfill fixes the member list).

### Carried to #129 (real payment gateway)

- The real gateway adapter **must treat `refundId` as the idempotency key** of a refund (today only a comment at `packages/domain/src/booking_ports.ts:89`): the event clock re-sends a ticket refund left `pending` under the same id, and only the provider's idempotency stops a double payout.
- Task 9+10 M7: `checkTicketPayment` asks the gateway only about the registration's latest intent (`reg.paymentId`); an earlier intent paid with another provider waits for the provider callback, which #129 adds.
- Task 9+10 N2: a gateway call that throws is recorded `failed` (manual) instead of staying `pending`, and a `failed` outcome written first hides a later success of a parallel send (same as bookings). With a real provider, a throw should leave the refund `pending` for the re-send and the provider callback should be able to move `failed` → `done`.
- The S11.03 mapping of "Chuyển khoản QR" and "ZaloPay" onto the `vnpay` code (owner question 5).
- Production release of paid tickets and bookings (deploy order step 5).

## Deferred

- Push for announcements, cancellations and "Có ảnh mới" (no push pipeline for events yet, S17 plans).
- Analytics events of `events.md` (no analytics layer; `ContactAction.onEvent` unused).
- Post-publish edit UI (the `updateEvent` callable exists; the app edits drafts only). This includes the staff FAQ of platform events, which is frozen at publish.
- "Tạo hộ" UI: staff photographer picker on S12.01 (backend and the photographer's accept/decline exist; `hostInvitationsProvider` is not shown anywhere, the photographer reaches an invitation only through the notification).
- Support inbox for platform events (S23.06); S11.02 shows the staff-entered FAQ only. The support line is hidden until the owner gives an address the project owns (`eventSupportEmail` in `event_links.dart`, now `null`).
- ~Report sheet ("Báo cáo" in the S11.06 long-press menu is a disabled "Sắp có" row until S20.01).~ Done in #144 (`docs/superpowers/plans/2026-10-07-s20-report-block.md`).
- Final-fix review minors: the FAQ "incomplete" error shows while the question is still being typed (show it on save or blur instead); a few raw pixel values in the rebuilt TicketCard/EventCard should move to tokens; the free hero event on S11.01 no longer shows "Không thu phí" because the featured card carries no price (mock).
- QR brightness: the full-screen ticket QR does not raise the screen brightness (no plugin).
- Author post deletion: a post deleted by its author should leave the timeline once post deletion exists.
- In-app unread badges for group chats (no per-message counters for groups by design).
- `PaymentGateway.createDepositIntent` naming: tickets pass the registration id as `bookingId` (plan I6 renames the port).
- Gateway refund failures of tickets are marked `failed` / `manual` for staff, like bookings (the customer keeps seeing "Đang hoàn"); the clock re-sends only refunds left `pending` (fix round M1). A staff screen for failed refunds is S23.
- M7 and N2 of Task 9+10: carried to #129 (list above).
- A late payment of an earlier intent on a ticket already refunded (or paid through another intent) is refunded but not shown on that ticket (the ticket keeps its own refund state).
- Earnings: host ticket money now shows in S06.05 (`earnings_firestore` reads the registration); platform-hosted ticket money has no earnings page (payee `platform` is skipped).

### Deferred minors from the reviews (Tasks 1–8)

- Task 2: admin cannot list drafts; svg covers allowed like other upload paths.
- Task 3: `watchMine` sorts on the client (undated drafts).
- Task 4+5: raw colours/sizes in a few places (`_QrFullScreen` white/monospace/20, stepper 32/16, sort width 210; the S11.02 cover buttons now use `AppColors.overlay`/`onScrim`); ticket card tap lacks a semantics label; duplicate `EventScreen` under `/e/:id/join`; re-registering with an identical highlight id would not reopen the tickets tab.
- Task 6: M4 raw numbers (work_screen 480 height, alphas, hashtag 40); M6 "Huỷ sự kiện" is a `TextButton` not `AppButton.text`; M7 `media_platform_config_test` name vs the CAMERA permission `mobile_scanner` merges; a stale value keeps the form during a draft reload; unrelated reformatting in `DateBlock`/`EventCard`.
- Task 7+8: M6 members can read every member doc (lastReadAt, mutedUntil, removedBy, …) — accepted; N1 the moderators-only test passes on old code (assert the SnackBar, add a fallback case); N2 the Check‑in header duplicates `SectionHeader`, the dashed painter duplicates `availability_calendar`'s; N3 a cancelled event removes free attendees from the chat at once, so the 7-day read-only window serves moderators and refund-pending ticket holders only; M10 the app mirrors the server's moderator seed; M12 the pending-post count refreshes late beyond the newest 100.

## Owner questions ("Needs the owner" in the Task 9+10 brief)

1. Staff hosting for a photographer (question 17): answered by O1 (draft until the photographer accepts within 24 h). Backend and photographer side done; staff picker deferred (above).
2. Support inbox for platform events (question 16): answered by O2 (FAQ + fixed support email until S23.06). FAQ editor built (S12.02, staff). Owner 2026-10-07: the address is build config, set later — `--dart-define=SUPPORT_EMAIL=<address>` fills `eventSupportEmail`; unset keeps the line hidden (the earlier `hotro@photobooking.vn` was invented).
3. Free tickets unlock contact: answered by O3 (they do not; only paid tickets after payment).
4. Late cancellation of a paid ticket (< 48 h): answered by O4 (allowed, no refund, seat freed, money released to the host after the event). Implemented in Task 9; a host cancel afterwards refunds that money too.
5. New (Task 10): confirm the S11.03 mapping of "Chuyển khoản QR" and "ZaloPay" onto the VNPay gateway code until #129 brings the real methods.

### Final review minors not fixed in the fix round (each over ~15 minutes or needs a decision)

- M4: `cancelEvent` refunds paid tickets one by one inside the 60 s callable; with hundreds of paid tickets it can time out after the cancel committed (the app then shows a generic failure while the event is cancelled; `eventClock` finishes the refunds through `refundDue`, so no money is lost). Later: return right after the cancel and let the clock (or a trigger) refund, or refund in parallel batches.
- M5 (S11.02): the capacity label is one line under the bar, the mock has a label row above it ("14 / 20 đã đăng ký" left, "Còn 6 chỗ" right) — a `CapacityBar` change shared with badges; the trailing "Chỉ đường" on the place row is not in the mock (Decision 21; add to the mock or move into the subtitle link); the host meta lacks the event count ("· 9 sự kiện", needs a per-host event count) and shows ★ until the tomato/brick unit lands. The type tag is fixed (shared `EventTypeTag`).
- M6 (mock not updated for spec-backed states): S11.01 "Không thu phí" chip + "Sớm nhất / Gần tôi" row, S11.03 phone "Đổi", S12.03 "Bài chờ duyệt · n" row. S11.04's "Vào nhóm chat" and "Thanh toán tiếp" are now in the mock.
- M7: S11.03 stepper uses bare `IconButton`s instead of the mock's 44 px outlined circles; `core/format.dart` `weekdayLabel` returns hard-coded `'CN'` / `'T{n}'` (pre-existing, used by tickets and the featured card). Fixed: S12.01 empty cover tile 16:8, S11.06 send glyph `arrow_forward` (shared composer, S07.02 too), S12.03 participants header indent, free events' cancel link says "Huỷ sự kiện".

