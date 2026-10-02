# Step 4a: Booking Domain and Backend (fake payments, lifecycle, escrow, rules, app repository) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed-in customer with a phone number can create a booking for a free day of a photographer, pay the 30 % deposit through a fake gateway, and both parties can move the booking through its whole lifecycle (accept, decline, cancel with the refund policy, complete, automatic expiry and completion), with the deposit held in escrow, every money movement in an append-only ledger, the customer's number unlocked for the photographer only after the deposit, and a Flutter repository and providers that plans 4b–4e build their screens on.

**Architecture:** Every business rule is pure TypeScript in `packages/domain` (policy values and time maths, the transition table, escrow and ledger maths, and the use cases `createBookingDraft`, `createDeposit`, `handlePaymentNotification`, `checkDeposit`, `confirmFakePayment`, `transitionBooking`, `openDispute`, `runBookingSweeps`) behind ports (`BookingStore` with one transaction primitive, `ServiceCatalog`, `CustomerContactReader`, `PaymentGateway`); an in-memory `MemoryBookingStore` and a `fakePaymentGateway` are the reference adapters. `app_flutter/firebase/functions` only maps Firestore documents to the domain types, wires the ports, and exposes six callables plus one scheduled function (`bookingClock`, every 15 minutes). Firestore rules keep clients read-only on bookings (parties only) and locked out of payments, refunds and the ledger; the customer's contact copy lives in `bookings/{id}/private/contact`, readable by the photographer only while contact is unlocked. The app gets freezed domain types, pure mirror rules (deposit, refund, slots, allowed actions, S14 groups), a `BookingRepository` port with a Firestore + Functions adapter, providers, and an in-memory fake in `test/support`.

**Tech Stack:** TypeScript 5.9 (Node 22, `node:test` through `tsx`), firebase-admin 13 and firebase-functions 6 (v2 `onCall`, `onSchedule`), Firestore rules + `@firebase/rules-unit-testing`; Flutter, Riverpod 3, freezed 4 (`build_runner`), `cloud_firestore`, `cloud_functions`, `fake_cloud_firestore` (tests).

**Spec:** `docs/superpowers/specs/screens/booking.md` (S05–S10, S14, S32, S33: money, errors, data each screen needs); `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` §5 (`bookings`, `payments`, `availability`), §6 (state machine, refund table), §7 (day unit, slot chips), §8 (deposit flow, never trust the redirect), §10 (`day_taken`, 30-minute draft clean-up), §11; `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b (phone gate, contact unlock, customer contact copy), §3g (escrow, release, refunds, ledger), §6, §7, §8 (open questions 3, 4, 5, 14, 18, 19, 20); `docs/superpowers/specs/screens/account.md` (S12: what a review needs from a booking); `docs/superpowers/specs/data-model/README.md` (§2 conventions, §3 ports, §4 authorization matrix, §5 use cases), `domain-model.md` (§2.4 `Booking`, `BookingContact`, `Payment`, `LedgerEntry`, `Refund`; §4 enums and `ErrorCode`; §5 booking, escrow and contact state machines; §6 invariants 2, 3, 6, 10, 11, 12), `relational-schema.md` (`bookings`, `booking_contacts`, `payments`, `refunds`, `ledger_entries`, §3 mapping). Existing code this plan extends: `packages/domain` and `app_flutter/firebase/functions` (backend phase 1), `app_flutter/firebase/firestore.rules`, `lib/data/booking/*`, `lib/data/photographer/availability_repository.dart` (plan 2d1), `lib/data/recommendation/availability_lookup.dart` (plan 3b3), `lib/features/discovery/book_entry.dart` (plan 3b4).

**Prerequisite (run order):** every plan listed as done in `docs/superpowers/plans/RUN-ORDER.md` (in particular backend-phase1, 2a, 2b, 2d1, 3b3, 3b4, 2d2). This plan uses, without redefining:

- backend phase 1: `@photobooking/domain` (`DomainError`, `ERROR_CODES`, `ErrorCode`, `isDomainError`, `isId`, `newUlid`, `requirePhone`, `isVnE164`, `BOOKING_CONTACT_DAYS`, `bookingContactUnlocked`, `Clock`, `IdGenerator`, `getContactLink` and its `BookingRecord` reading `completedAt`), `packages/domain/test/purity.test.ts` and the eslint import ban; Functions `REGION`, `CALLABLE_OPTIONS`, `db()`, `toHttpsError`, `CallableInput`, `bookingFromDoc` (contact-link reader), `seed/fixtures.ts` + `seed/apply.ts` + `seed/emulator_client.ts` (`callCallable`, `signIn`, `resetEmulators`, `emulatorProject`), npm scripts `test` and `test:integration`.
- 2a/2b: `users/{uid}/private/contact` (`phone` E.164, `allowZalo`, `allowWhatsApp`), `ContactAccess`, `contactAccessForBooking`, `getContactLink` (customer side).
- 2d1: `availability/{uid}/days/{yyyy-MM-dd}` (`state: off|pending|booked`, `bookingId`), `AvailabilityDay`, `availabilityDayFromFirestore`, `FakeAvailabilityRepository` (`seed`, `stored`), `availabilityMonthProvider`, S20 (photographers only mark free days `off` and only clear `off` days).
- 3b3: `AvailabilityLookup`/`FirestoreAvailabilityLookup` (any non-free day document hides the photographer on that day).
- 3b4: `startBooking` / `bookingPath` → `/u/:uid/book?serviceId=…&date=yyyy-MM-dd` (route built by plan 4b).
- `lib/data/booking/booking_status.dart` (`BookingStatus`, colors, labels), `lib/core` (`parseDayKey`, `calendarDay`, `DayState`), `authStateProvider`, `FakeAuthRepository`.

**How bookings and the photographer calendar fit together** (decided here, implemented in Tasks 4–7 and 10):

| Booking event | `availability/{photographerId}/days/{date}` (server write) | Effect already built |
|---|---|---|
| `createBooking` (draft) | created `{state: 'pending', bookingId}` in the same transaction; any existing record → `day_taken` (except the same customer's own draft, which is replaced) | S06/S03/S20 show "Chờ"; 3b3's lookup hides the photographer that day; S20 cannot mark the day off (rules refuse `update`) nor clear it (rules delete only `off`) |
| deposit paid (`requested`) | unchanged (`pending`) | "1 người đang chờ" |
| `accept` | `{state: 'booked', bookingId}` | "Đã đặt" |
| `decline`, `cancel`, expiry, unpaid draft removed after 30 min | deleted (only when its `bookingId` is this booking) | the day is free again |
| `completed` | unchanged (`booked`, history) | — |

A photographer who marks a day `off` first makes every later `createBooking` on that day `day_taken`; S20's own batch already fails cleanly when a day got a record meanwhile (`writeDaysOff` returns false).

## Global Constraints

Values copied from the specs (verbatim where quoted):

- Deposit: "cọc 30%, phần còn lại trả tại buổi chụp"; "`deposit = floor(price × 0,30)`, `remaining = price − deposit`"; "số tiền cọc làm tròn đến đồng, `cọc + còn lại = giá`". Money is integer VND everywhere.
- Customer cancellation: "≥ 48h trước `start` | 100%", "24–48h | 50%", "< 24h | 0%"; "nhiếp ảnh gia huỷ, từ chối hoặc hết hạn nhận → hoàn 100%".
- Answer deadline: "Nhiếp ảnh gia phải nhận trong 24 giờ, nếu không tự hoàn cọc." (`acceptDeadline = requestedAt + 24h`); "quá acceptDeadline ──▶ expired (hoàn cọc 100%, Function)".
- Upcoming: "accepted ──T‑24h──▶ upcoming". Completion: "nhiếp ảnh gia bấm hoàn thành, hoặc hệ thống sau `end + 24 giờ`"; "sau `endTime` NAG có 'Hoàn thành'".
- Drafts: "sau 30 phút booking `draft` bị Function dọn"; "Không lưu nháp lên server cho tới khi tạo `draft` ở bước 4".
- Slots: "mốc 30 phút từ 06:00 đến 20:00 trừ `durationMinutes`"; "Đơn vị v1 là **ngày**. Một booking khoá cả ngày cho nhiếp ảnh gia"; "Khách chỉ đặt được ngày Rảnh".
- Escrow: "held ──(booking/sự kiện completed + hết cửa sổ khiếu nại)──▶ released"; "`dispute_window_hours` (đề xuất 24 giờ)"; "Hoàn tiền **chỉ lấy từ số đang treo**"; "Phần không hoàn khi huỷ muộn | Sau thời điểm `start` của buổi lẽ ra diễn ra + cửa sổ khiếu nại | Nhiếp ảnh gia"; "Khách khiếu nại trong cửa sổ khiếu nại → khoản thành `disputed`".
- Ledger: "Mọi biến động tiền là một **bút toán bất biến** (append‑only) trong `ledger_entries`: `deposit_received`, `ticket_received`, `refund_issued`, `escrow_released`, `payout_paid`, `fee_charged`, `adjustment`"; invariant 11 "`Payment.amount = Σ LedgerEntry` loại `*_received` − `refund_issued`"; invariant 12 "Chỉ khoản `escrowStatus = held` mới hoàn được".
- Phone gate: "`transitionBooking(requested)` … đọc `users/{uid}/private/contact`, từ chối với `phone_required` nếu thiếu hoặc sai định dạng (ép ở server, không chỉ ở UI)"; "mọi nhánh server vẫn chặn khi thiếu số".
- Contact unlock: "Booking ở `requested` (đã cọc), `accepted`, `upcoming`, hoặc `completed` (trong 30 ngày sau) … `declined`, `expired`, `cancelled`, `refunded` thì khoá lại"; "Số của khách **chỉ hiện với nhiếp ảnh gia sau khi khách đặt cọc**"; "`customerContact` chỉ ghi bởi Function và chỉ hai bên đọc"; "Function xoá `phone` khỏi `customerContact` 30 ngày sau `completed`".
- Writes: "Mọi chuyển trạng thái đi qua **Cloud Function `transitionBooking`** (callable), không cho client ghi `status` trực tiếp"; matrix: `bookings` read "P, A", write "Svc"; `payments`, `refunds`, `ledger_entries` write "Svc" only.
- Payments: "Client không tin kết quả redirect; chờ `bookings.status`"; "không tạo thanh toán thứ hai khi 'Kiểm tra lại'"; "Secrets … chỉ nằm trong Functions config, không bao giờ trong app"; open question 1: "Nếu chưa, sub‑project 4 dùng cổng giả và bật thật sau."
- Note "tối đa 300 ký tự"; free place name "cần tên (≥ 3 ký tự)".
- Error codes are the stable `snake_case` codes of `domain-model.md` §4 (`day_taken`, `phone_required`, `price_changed`, `not_eligible`, `deadline_passed`, `conflict`, `permission_denied`, `not_found`, `invalid_argument`); callables carry them as `message` and `details.code`.
- Data conventions (data-model README §2): opaque ids `[A-Za-z0-9_-]{1,64}`, new ids ULID; instants UTC (`Timestamp` only inside adapters); calendar day `yyyy-MM-dd` and time `HH:mm` in Asia/Ho_Chi_Minh (UTC+7, no DST); enums are string codes; bookings carry `version` (optimistic lock) and money operations an `idempotencyKey`.
- Layering (CLAUDE.md): `packages/domain/src` imports nothing outside itself (no Firebase, no `node:*`; lint + `purity.test.ts`); Functions are thin adapters, region `asia-southeast1`; in the app `cloud_firestore`/`cloud_functions` appear only in `lib/data/**` adapters; imports `package:photobooking/...`; no UI strings in this plan.
- Commands: domain `(cd packages/domain && npm test)` from the repo root; Functions `(cd app_flutter/firebase/functions && npm test)` (unit) and `npm run typecheck`, `npm run lint`; Functions integration tests (`npm run test:integration`) and rules tests run **on CI only** (outside the sandbox); Flutter from `app_flutter/` with `../scripts/bin/flutter …` and `../scripts/bin/dart …`; run `../scripts/bin/dart format lib test` before each Flutter commit.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Assumptions

Where the specs are silent or an open question blocks a value, this plan takes the spec's proposal or decides as follows (each is also stated where it is implemented):

1. Spec proposals adopted: dispute window 24 h (open question 3); the customer's number is removed 30 days after `completed` (OQ 4); contact stays open 30 days after `completed` (OQ 5); the part kept on a late cancellation goes to the photographer after start + 24 h (OQ 20); 30 % deposit and the refund table as written (original OQ 3).
2. Payments use a fake gateway only (original OQ 1). It runs in the emulator, or in a project whose functions env sets `PAYMENTS_MODE=fake` (committed for the dev project `booking-c1922` only); anywhere else `createDeposit` answers `not_eligible`, so production cannot take fake money. A MoMo/VNPay adapter later implements the same `PaymentGateway` port.
3. A draft holds the day as `pending` from the moment it is created (use case `create_booking_deposit`: "Tạo booking `draft`, giữ ngày"). A pending day held by the same customer's own draft is replaced, not `day_taken` (going back from S07 to S06).
4. Unpaid drafts are deleted after 30 minutes (not moved to a status) and their day freed; money that arrives later, for a superseded payment, after the start, or without a valid customer number, is refunded 100 % at once.
5. `acceptDeadline = min(paidAt + 24 h, startsAt)`.
6. Accepting within 24 h of the start enters `accepted` and `upcoming` at once (both on the timeline).
7. Neither party can cancel at or after the start (`not_eligible`); disputes cover no-shows.
8. The photographer completes only after `end`; the system completes at `end + 24 h`; the deposit is released at `completedAt + 24 h`.
9. The customer contact copy is the document `bookings/{id}/private/contact` (not a field of the booking): the booking stays readable by both parties, the copy by the customer always and by the photographer only while contact is unlocked (rules), and the number is removed at once on `declined`/`expired`/`cancelled`. The specs are updated in Task 8.
10. Escrow `partially_refunded` still holds the kept part and is released like `held`.
11. `refund_issued` is written when the refund is created; the gateway call happens after the transaction; a failed call leaves the refund `failed` + `manual` for an admin.
12. Clients cannot read `payments`, `refunds` or `ledger_entries` in 4a; the booking document mirrors `escrowStatus`, deposit and refunded amount for the screens (S43 earnings come later).
13. `bookingClock` runs every 15 minutes (Asia/Ho_Chi_Minh), at most 100 items per sweep, one instance, no retries (the next run retries).
14. Limits the specs do not give: place name ≤ 120 characters, cancel/decline reason ≤ 200, dispute reason 1–500, booking date ≤ 365 days ahead, start strictly in the future, deposit ≥ 1 đồng; lengths count grapheme clusters (like Flutter's `maxLength`).
15. S14 groups: "Sắp tới" = `accepted`, `upcoming` (nearest first); "Đang chờ" = `requested`; "Đã xong" = `completed`, `reviewed`, `declined`, `expired`, `cancelled` (newest first); drafts are never listed.
16. `price_changed` and `not_eligible` (already in `domain-model.md` §4) join the TypeScript `ERROR_CODES`.
17. Out of scope, with hooks named in "Interfaces for plans 4b–4e": reschedule (4d), creating/attaching the chat on payment (4d), push and in-app notifications (S63–S65), `getContactLink` for the photographer calling the customer (4c), dispute resolution and payouts (admin, later), `stats.completedCount` and `nextFreeDate`.
18. Flutter test fakes for this plan live in `test/support/` (as asked for this plan), unlike earlier plans that keep fakes next to their port.

## Review Focus

1. Two customers ask for the same photographer and day at the same moment → exactly one draft holds the day and the other gets `day_taken`, never two pending bookings. Pinned by Task 6 Step 5 ("two customers racing for one day: exactly one draft wins", emulator, CI) and Task 4 Step 1 ("another customer's hold is day_taken").
2. The customer goes back from S07 to S06 and picks another time on the same day (or retries after a network error) → their own earlier draft never blocks them; it is replaced. Pinned by Task 4 Step 1 ("the customer's own earlier draft is replaced, not day_taken").
3. The payment confirmation arrives twice, after the 30-minute clean-up, or for a payment the customer replaced by switching gateway → no second capture, late money refunded in full, ledger balanced. Pinned by Task 4 Step 1 ("a duplicate confirmation captures nothing twice", "money after the draft was cleaned up is refunded in full", "a superseded payment that still gets paid is refunded").
4. Cancelling exactly 48 h / 24 h before the start, or after it → 100 % / 50 % / `not_eligible`; the kept half goes to the photographer only after start + 24 h. Pinned by Task 2 Step 1 ("customer cancel follows the policy table; never after the start") and Task 5 Step 1 ("customer cancels 30 h before: half back now, the rest released to the photographer 24 h after the start").
5. The photographer taps "Nhận" in the same minute the expiry sweep runs → one consistent winner at the deadline instant, nothing applied twice. Pinned by Task 5 Step 1 ("accept and expiry agree on the deadline instant").

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/errors.ts` (modify) | add `price_changed`, `not_eligible` |
| `packages/domain/src/booking_policy.ts` (create) | status/provider codes, spec values, deposit, refund %, VN time, slots, accept deadline |
| `packages/domain/src/booking.ts` (create) | `Booking`, `BookingContactSnapshot`, escrow codes |
| `packages/domain/src/booking_machine.ts` (create) | `decideTransition`, `applyTransition`, `roleOf` |
| `packages/domain/src/escrow.ts` (create) | `Payment`, `Refund`, `LedgerEntry`, capture/refund/release/dispute maths |
| `packages/domain/src/booking_ports.ts` (create) | `BookingStore`, `BookingTx`, `ServiceCatalog`, `CustomerContactReader`, `PaymentGateway`, `BookingDeps` |
| `packages/domain/src/booking_requests.ts` (create) | wire-payload helpers, grapheme length |
| `packages/domain/src/memory_booking_store.ts`, `fake_payment_gateway.ts`, `refunds.ts` (create) | reference adapters, refund dispatch |
| `packages/domain/src/create_booking.ts`, `create_deposit.ts`, `handle_payment.ts` (create) | draft, deposit, payment notification, check, fake confirm |
| `packages/domain/src/commit_transition.ts`, `transition_booking.ts`, `open_dispute.ts`, `booking_sweeps.ts` (create) | lifecycle, dispute, scheduled sweeps |
| `packages/domain/src/index.ts` (modify) | exports |
| `packages/domain/test/fixtures/booking_policy.json` (create) | cases shared with the Flutter tests |
| `packages/domain/test/support/booking_fixtures.ts`, `booking_world.ts` (create) | test builders and harness |
| `packages/domain/test/*.test.ts` (create) | per task |
| `app_flutter/firebase/functions/src/callables/errors.ts` (modify) | transport codes of the new error codes |
| `app_flutter/firebase/functions/src/infra/booking_firestore.ts`, `booking_readers.ts`, `live_booking.ts` (create) | mapping, store, readers, wiring |
| `app_flutter/firebase/functions/src/callables/run.ts`, `booking.ts` (create) | callable shell and handlers |
| `app_flutter/firebase/functions/src/scheduled/booking_clock.ts` (create) | scheduled sweeps |
| `app_flutter/firebase/functions/src/config.ts`, `src/index.ts` (modify) | `SCHEDULE_OPTIONS`, `paymentsMode`, exports |
| `app_flutter/firebase/functions/.env.booking-c1922` (create) | `PAYMENTS_MODE=fake` for the dev project |
| `app_flutter/firebase/functions/seed/fixtures.ts`, `seed/README.md` (modify) | bookings with payments, ledger, contact copies, days |
| `app_flutter/firebase/functions/test/unit/*`, `test/integration/*` | per task |
| `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (modify) | bookings, contact copy, money collections, indexes |
| `docs/superpowers/specs/2026-10-01-remaining-screens.md`, `data-model/domain-model.md`, `data-model/relational-schema.md` (modify) | contact copy location, new booking fields |
| `app_flutter/lib/data/booking/booking_status.dart` (modify) | status codes |
| `app_flutter/lib/data/booking/booking.dart` (+ generated `booking.freezed.dart`) (create) | freezed domain types |
| `app_flutter/lib/data/booking/booking_rules.dart` (create) | client mirror of the policy and allowed actions, S14 groups |
| `app_flutter/lib/data/booking/booking_repository.dart` (create) | port, requests/results, errors |
| `app_flutter/lib/data/booking/firestore_booking_repository.dart` (create) | Firestore reads + callables |
| `app_flutter/lib/data/booking/booking_providers.dart` (create) | providers |
| `app_flutter/lib/data/photographer/availability_repository.dart` (modify) | `FakeAvailabilityRepository.unseed` |
| `app_flutter/test/support/booking_fixtures.dart`, `fake_booking_repository.dart` (create) | builders, in-memory repository |
| `app_flutter/test/data/booking/*_test.dart` (create) | Task 10 tests |

---
