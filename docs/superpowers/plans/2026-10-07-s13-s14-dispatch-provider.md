# S13–S14 Chụp ngay: dispatch core, dispatch service on Functions and the provider app (S14.01–S14.03, S13.04, S13.08 provider) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and `firestore.indexes.json` and adds Functions. Write the rules tests and the Functions integration tests; do not run them (CI runs them). Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`). Background location, the Android foreground service and full-screen offer intents are therefore out of this plan (Decision 10, Deferred).

> **Detail level (owner, "ở giữa"):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A verified photographer switches on Live Shutter (S14.01) after accepting the platform price list, receives up to three 60-second offers at once (S14.02), wins an offer only if they accept first, sees the "Đã match" moment (S13.04), shares their position on the way, marks Đã đến / Bắt đầu chụp / Hoàn thành (S14.03) or cancels with the outcome shown first (S13.08 provider side); behind it, a dispatch core in `packages/domain` and a dispatch service on Cloud Functions + Firestore run the whole request lifecycle (request, 5-candidate rounds, parallel invites, first-accept-wins, timeouts, no-match with money held, cancellation money table) on the fake payment rails, so the customer app of the companion plan only has to build screens.

**Architecture:** Every business rule of Chụp ngay is a pure module in `packages/domain/src/instant*.ts` (state machine, timers, pricing, candidate ranking, cancellation money, use cases over ports with an in-memory store). Cloud Functions are thin: 12 callables (`asia-southeast1`), one trigger `onInstantRequestWrite` (notifications, chat, track cleanup) and one extra step in the existing 15-minute `bookingClock` (backstop for timers nobody nudged). Timers are settled lazily: every callable that touches a request first applies `settleInstant(request, now)` inside its transaction, apps call `tickInstantRequest` when a countdown they show reaches zero, and the clock step catches the rest; there is no new scheduled job and no Cloud Tasks queue. The winner of an offer is decided by one Firestore transaction over the request document and the photographer's presence document. Clients only read (`instant_config`, own presence, own offers, the request, the track) and write exactly two things under strict rules: their own presence heartbeat and, while en route, their track point (≤ 1 per 15 s). The map is a schematic `MapPreview` (CustomPainter, same look as the mock `.map`), no map tiles and no Maps API; "Chỉ đường" opens the phone's maps app. Payments reuse `payments`/`refunds`/`ledger_entries`, the fake gateway and `bookingClock` step 5 for escrow release.

**Tech Stack:** TypeScript (`packages/domain`, `node --test` via tsx; Functions v2 `onCall`, `onDocumentWritten`, existing `onSchedule`), Firestore rules and indexes, `@firebase/rules-unit-testing` (written, not run); Flutter, Riverpod 3, go_router, `cloud_firestore`/`cloud_functions` (adapters only), `geolocator` (existing, through `LocationRepository`), `url_launcher` (existing, through `ExternalLauncher`), `fake_cloud_firestore` (adapter tests). No new package (pub.dev is blocked in the implementer sandbox).

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (§1 decisions table, §2.2 photographer flow, §3 states, rounds, offers, §4 money, §6 API, §7 data, §8 screens and strings, §9 location and privacy, §10 edge cases, §11 tests); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` (M1, M2, M7, §4, §5); `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §7 (gate); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (codes and status), §3h (notification types, "Lời mời Chụp ngay không là thông báo trong hộp thư"); `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §9, §13, §14; `docs/superpowers/specs/components/shared-components.md` (`SwipeDeck`/`MatchOverlay`, `OfferStack`, `MapPreview`); `docs/superpowers/specs/data-model/README.md` (ids, UTC, integer VND, string enums); mock `docs/design/ui-mock.html` `#S13.04`, `#S13.08`, `#S14.01`, `#S14.02`, `#S14.03`, `#S06.01`, `#S17.02` caption.

**Issue (split 2026-10-08):** **#140** = Tasks 1–10 of this plan (items "Viết lại I2 dispatch core", "I3 dịch vụ điều phối", "I4 app nhiếp ảnh gia (S13.08, S14)") **without money**, then Tasks 1–7 of the companion customer plan `docs/superpowers/plans/2026-10-07-s13-instant-customer.md` (also without money). **#202** ("S13–S14 · Chụp ngay: thanh toán (V1)", the fake-rails part of "I6 thanh toán") = **Task 11 of this plan**, then **Task 8 of the customer plan**; it is the only place that touches `payments`, `refunds`, `ledger_entries` or V1/V2 names, and it turns the feature on.

> **Split 2026-10-08 (#140 / #202).** #140 runs end to end on the emulator with no money: the first "Gửi lời mời" sends the offers at once (no payment step, no `pending_payment`), the request records `committedAt` (offers sent at least once) and every cancel/no-show outcome is recorded with zero money (`paidAt` stays null, so the cancel rule is `unpaid`, Decision 9). Contact channels and the customer-contact copy stay locked because they require `paidAt` (Decision 22). The free dispatch can never reach a real customer: `kInstantEnabled` stays `false` (#202 flips it), `instant_config/current` exists only in the seed, and `handleInviteInstant` refuses with `not_eligible` unless `fakePaymentsAllowed()` (`infra/fake_payments.ts`: the dev project or a `demo-*` emulator). #202 inserts the payment gate before the offers (Decision 5), applies every recorded money outcome to the payment, removes that guard and flips the flag. Task headings below are tagged; money items inside Tasks 2–9 carry "→ Task 11 (#202)".

**Branch:** #140: `plan/140-instant-dispatch` (claimed with `project.py claim 140`), PR into `develop` titled `feat(instant): Chụp ngay dispatch on Functions and the photographer app (S14, S13.04, S13.08) [#140]`; the customer plan follows on `plan/140-instant-customer`. #202: `plan/202-instant-payments` from `origin/develop` after #140 (both plans) and #200 have merged; PR titled `feat(instant): Chụp ngay payment on the shared payment model [#202]` (this plan's Task 11, then the customer plan's Task 8, one PR).

**Execution wave:** 4 (cross-plan review 2026-10-07; re-planned 2026-10-08). **#140 is blocked by:** #198 only (`2026-10-08-n1-order-gate.md`: `orderBlocker`, `OrderGateDeps {providers, blocks?}`, `BlockGate`, `FakeBlockGate`, `liveBlockGate()`, Decision 17; previously "#144 Task 2"). Already merged on develop: #129 (S04, in #154: `PaymentMethod`, `PaymentGateway`, `FakePaymentGateway`, `PAYMENT_EXPIRY_MINUTES`), #130 (reviews: `stats.tomatoPct`, `stats.score`, `MetaLine`, Decision 23), #138 (S17: the seven instant notification hooks, Decision 20). **#202 is blocked by:** #140 (both plans) and #200 (V1, `2026-10-08-v1-subject-payments.md`: `newSubjectPayment`, `issuePaymentInstructions`, `instructionsOf`, `applyTransfer`, `expireUnpaid`, `SubjectSettler`, `SettlementDeps`, `settleTransfer`, `checkSubjectPayments`, the unified `confirmFakePayment`, `liveSettlementDeps()`, app `openPayment`/`PaymentScreen`/`PaySubject`/`PaymentController`/`PaymentInstructions`/`PaymentsRepository.confirmFake`). Soft for #202: #201 (V2, `2026-10-08-v2-refund-destination.md`: `sendRefundOnce`, `mergeRefundOutcome`, refund destination, the `pending` re-send); until #201 lands, Task 11 dispatches refunds with #129's existing `dispatchRefunds(deps, items)` (`refunds.ts`; a gateway error → `failed` + `manual`, no automatic re-send) and ledgers it. Payment names called "#129's" below that #129 did not build are V1's or V2's (table in `2026-10-08-s04-reconciliation.md`). The companion customer plan `2026-10-07-s13-instant-customer.md` is blocked by Tasks 1–10 of this one. **Shares with #139 (same wave):** `packages/domain/src/geo.ts` (`distanceKm`), Decision 12.

**Replaces the stale plans** (written 2026-10-01 for one-at-a-time offers and a self-hosted service):
- `2026-10-01-instant-i2-dispatch-core.md` (`packages/dispatch-core`) → Tasks 2–3 here (modules in `packages/domain`). Kept from it: the ETA estimate (straight line × 1.4 at 20 km/h), price × surge rounded to 1.000 ₫, the cancellation table with "refund + fee = amount" tests, priority/expanded tiers, score with reasons, arrival check ≤ 200 m.
- `2026-10-01-instant-i3-dispatch-service.md` (`services/dispatch`, Fastify, Redis GEO, PostgreSQL, BullMQ) → Tasks 4–5 here (Functions + Firestore). The OpenAPI file `services/dispatch/api/openapi.yaml` stays the phase-2 target (Go backend #90); Task 10 adds a note.
- `2026-10-01-instant-i4-photographer-app.md` → Tasks 6–9 here, without `flutter_foreground_task`, `flutter_local_notifications`, `battery_plus`, `maplibre_gl` and the HTTP `ApiClient` to `DISPATCH_URL`.
- `2026-10-01-instant-i6-payments.md` (MoMo/VNPay) → fake rails only here; the real licensed intermediary is #129/#141.
- Task 10 adds a "Superseded by …" line at the top of those four files.

## Global Constraints

- CLAUDE.md money rules (do not weaken): customer pays 100% up front, money is held, released to the provider after the job; phone/Zalo/WhatsApp unlock only after payment (before that, in-app chat only); a customer needs a phone number to request; phone numbers never go in public documents. #140 moves no money and is never reachable outside the dev project/emulator (the split box above); the payment gate is #202's (Task 11) and the feature is switched on only there.
- Spec §3.1: "Mỗi chuyển đổi chỉ do dịch vụ thực hiện (client gọi API, không ghi trạng thái)." Only two client writes exist: own presence heartbeat, own track point (Decisions 10, 11).
- Spec §3.3: "Hạn một lời mời 60 giây"; "Lời mời đang chờ tối đa cho một nhiếp ảnh gia 3"; "Người được mời trong một lượt 1–5"; "Thời gian tìm một đợt 10 phút … quá thì `no_match`, tiền vẫn treo".
- Spec §2.2.5: "Đang có yêu cầu thì không nhận lời mời mới (không được gợi ý cho khách khác)."
- Spec §9 privacy: "địa chỉ chính xác chỉ gửi cho người đã nhận; trước đó lời mời chỉ có khu phố và khoảng cách. Vị trí nhiếp ảnh gia chỉ khách của yêu cầu thấy, chỉ khi đang đến. Không lưu lịch sử điểm."
- Spec §4: "Tổng hoàn + tiền nhiếp ảnh gia + phí nền tảng luôn bằng số tiền đã thu, kiểm bằng test (không lệch 1 ₫)."
- Owner ruling 5: anything that creates an instant invite goes through #198's shared `orderBlocker(deps: OrderGateDeps, p: OrderParties): Promise<'not_accepting_orders' | 'blocked' | null>` (`packages/domain/src/order_gate.ts`: `ProviderOrderGate.acceptsOrders` = `verified && onboardingComplete`, then `BlockGate.isBlockedEitherWay` customer ↔ photographer from `block_ports.ts`), errors `not_accepting_orders` / `blocked` (`failed-precondition`) (cross-plan review finding 22). `OrderGateDeps.blocks` is optional, so `InstantDeps` declares it and `liveInstantDeps()` sets `blocks: liveBlockGate()` (`src/infra/live_safety.ts`) explicitly (Task 4); a deps object without it would make `orderBlocker` skip blocks silently.
- Owner ruling 2 (#202, Task 11): money moves on the fake rails only, through #129's payment model (one owner for payments: `createPayment`-style instructions with VietQR, its settlement, the unified `confirmFakePayment({paymentId})` behind `assertFakePaymentsAllowed()`, refund idempotency by refund id, re-sends by V2 only); the real intermediary is #129's Deferred adapter.
- Owner ruling 3: everything runs and is tested on the emulators (`scripts/backend-local.sh`); no new deploy-only gate, no secret.
- Server code: rules in `packages/domain` (no Firebase/Node imports; `purity.test.ts` must stay green); Functions are thin adapters in `app_flutter/firebase/functions/src`; region `asia-southeast1` via `REGION`/`CALLABLE_OPTIONS`/`PAYMENT_CALLABLE_OPTIONS`/`TRIGGER_OPTIONS` (`src/config.ts`).
- Data conventions (`data-model/README.md`): ULID ids (`newUlid`), UTC instants (Firestore `Timestamp`), integer VND, string enum codes, no Firebase types in the domain.
- App: `package:photobooking/...` imports only; features import `core/core.dart`, never files inside `core/`; Firebase only in `lib/data/**` adapters; tokens via `AppColors`/`AppColorsDark`/`AppSpace`/`AppRadius`, icons via `AppIcons` (Material Symbols Rounded); every string in `lib/l10n/app_vi.arb` then `flutter gen-l10n`; every screen/sheet wrapped in `ScreenCode`; `AsyncView` for every `AsyncValue`; one `AppButton.primary` per screen; cancel/decline confirmations are a red button in a sheet, never the gradient button.
- Live Shutter keeps its English name in the UI (spec §1).
- Env for Flutter (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time, never the whole suite in one command; widget tests use bounded `pump(Duration)` (no `pumpAndSettle` on screens with a countdown or the match animation; inject `clockProvider`/`now` and turn animations off with `MediaQuery(disableAnimations: true)` where a test does not exercise them). Domain: `cd packages/domain && npm test && npm run lint`. Functions: `cd app_flutter/firebase/functions && npm test && npm run build`. Rules tests (`app_flutter/firebase/rules-test/rules.test.mjs`) and Functions integration tests (`test/integration/`) are written, not run.
- Commits: Conventional Commits, subject ends with `[#140]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).

## Decisions

1. **Phase 1 runs on Cloud Functions + Firestore, not `services/dispatch`.** Spec §5 (Redis GEO, PostgreSQL, BullMQ, Cloud Run) is the phase-2 target; owner rulings 1 and 3 require everything on the emulators now. Firestore transactions give the "first accept wins" lock (spec §3.3 `SELECT … FOR UPDATE`), presence lives in Firestore with a 30-minute freshness window instead of a Redis TTL.
2. **Rules live in `packages/domain`, not a new `packages/dispatch-core`.** CLAUDE.md puts business rules in `packages/domain` with one purity test and one lint; a second package would duplicate `DomainError`, `Payment`, `ProviderOrderGate`. File prefix `instant*`.
3. **Timers without a new cron.** Offer expiry (60 s), payment window (15 min), search window (10 min), abandon (30 min), shoot end and auto-complete (2 h) are settled by the pure `settleInstant(request, now)` (refund re-sends are not a timer here: V2's re-send sends every pending refund again, Decision 5):
   - inside every instant callable, in its transaction, before anything else (the server clock is the referee: an accept at 60.5 s gets `offer_expired`);
   - on `tickInstantRequest`, which apps call when a countdown they show reaches zero (customer S13.03 at the last offer expiry and at the 10-minute mark; photographer S14.03 at shoot end);
   - in a new step of the existing `bookingClock` (every 15 minutes) over `instant_requests` where `active == true && nextDeadlineAt <= now` (limit 100), for requests nobody is looking at.
   A 1-minute job would add 43.200 runs and ≥ 43.200 reads a month (cost spec §13.4) to cover a case where the only effect of a late settle is a later push ("Chưa ai nhận …", "Bạn đã bỏ lỡ một lời mời") — no money is released or refunded by a timer except auto-complete, which has a 2-hour slack. Cloud Tasks (one task per offer) was considered and rejected for phase 1: one more API, IAM setup on Blaze and emulator wiring for precision that lazy settling already gives where it matters.
4. **First accept wins in one transaction.** `answerInstantOffer(accept)` reads the request, the offer, the photographer's presence (with `activeRequestId` and `pendingOffers`) and the requests of the photographer's other pending offers, then writes all outcomes. Two accepts on one request conflict on the request document; one photographer accepting two requests conflicts on their presence document. Firestore retries the loser, which then reads `assigned` (→ `already_assigned`) or an `activeRequestId` (→ `already_assigned`, spec §10 row 4).
5. **Pay before dispatch (spec §4), on the shared payment model (cross-plan review finding 13) — #202, Task 11.** In #140 there is no payment: the first `inviteInstant` re-quotes the price, then sends the offers at once and sets `committedAt` (dev/emulator only, split box); everything below is what #202 inserts in front of the offers. `instant_request` is a payment subject plugged into V1's extension point (the old S04 plan's Decision 22; #129 did not build it). The first `inviteInstant` stores the selection in `pendingInviteIds`, moves the request to `pending_payment` and creates the payment with V1's `newSubjectPayment({id: await freshPaymentId(settlement.payments, ids), subjectType: 'instant_request', subjectId: requestId, payerId: customerId, payeeId: '', amount: amountVnd, method, provider: gateway.provider, idempotencyKey: 'inst_{requestId}_{n}', now, expiresAt: now + PAYMENT_EXPIRY_MINUTES})` (`paymentDeadlineAt = expiresAt`), then `issuePaymentInstructions(gateway, payment, save)` outside the transaction (no `returnUrl`; `save(providerRef, instructions: GatewayInstructions)` stores the gateway answer on the payment while it is still `created`) and returns `{kind: 'payment', instructions: PaymentInstructions, amountVnd}` (V1's flat shape: `transferCode`, `qrPayload?`, `bankName?`, `accountMasked?`, `payUrl?`, `bankAppsUrl?`, `subjectType`, `subjectId`; bank QR → VietQR on S04.04; wallets → `payUrl`). Money arrives only through V1's settlement: `InstantPaymentSettler` (a `SubjectSettler`, `instant_payments.ts`, registered in `liveSettlementDeps().subjects.instant_request`) applies a transfer in `settle(paymentId, transfer)` (no `payer`; V2 adds an optional one) inside the instant transaction with `applyTransfer({payment, transfer, ledgerEntryId, now})` (ledger `payment_received`, `decision` = #129's `TransferDecision`, excess per #129's §3.3 table; idempotency by V1's transfer record `transferRecordId(transfer)`), returning #129's outcome (`Exclude<TransferOutcome, 'needs_review'>`); `paid` while the request is `pending_payment` with this `paymentId` → `paidAt`, offers sent; paid in any other case (cancelled, payment window passed, another payment already paid) → 100% policy refund `late_payment`. Its `expire` uses `expireUnpaid`; its `dispatchRefund` uses `sendRefundOnce` + `mergeRefundOutcome` (V2, #201; until #201 lands, #129's `dispatchRefunds`, failures `failed` + `manual`) and mirrors `refundStatus` on the request; refunds left `pending` are re-sent only by V2's re-send under the same refund id, through V2's `RefundSubjects` registry (`liveRefundSubjects()`, where Task 11 registers an `instant_request` `RefundSubjectHandler {resend, record}`; not through `SettlementDeps.subjects`), never by `runInstantSweep`. The fake confirmation is V1's unified `confirmFakePayment({paymentId, kind?})` (returns `{outcome, subjectType, paymentStatus, subjectStatus}`, `subjectStatus` from `statusOf(payment)`); `checkInstantPayment({requestId})` stays as a thin wrapper over V1's `checkSubjectPayments` (S04.04 on app resume). Offers go out only when the payment is `paid`. Reasons: spec §4 says so ("Lời mời chỉ được gửi khi cổng xác nhận đã trả"); a photographer must never drive to an unpaid customer; contact unlock needs payment; paying after the match would leave the winner waiting on the customer's payment and block their presence. Later rounds reuse the held money. `payeeId` is set to the winner at assignment and cleared when the photographer cancels.
6. **Owner 2026-10-07: commission 100% to the photographer, platform fee 0%, configurable.** As in the payments spec (M7: "hoa hồng sàn mặc định 0%"), the platform fee is a config value, not code: `instant_config/current.platformFeeBp` (integer 0–10 000, default and seed 0), read by the domain through `InstantConfigReader` (`parseInstantConfig` refuses a missing or out-of-range value). `photographerEarning(amount, cfg) = amount − round(amount × platformFeeBp / 10 000)`; with 0 the photographer gets 100% and both numbers of a S14.01 row are equal (the mock's 312K/552K/952K are example values). A non-zero fee is taken at payout (#202, Task 11) through #134's `platform_fee` ledger line (`payoutLineOf` with the instant fee as `feeBp` for an `instant_request` payment), so "Bạn nhận" always equals what the payout pays. The request snapshots `platformFeeBp` with the price.
7. **Release: one milestone (#202, Task 11).** Completed (or fee-bearing cancelled / no-show) money gets `releaseAfter = endAt + 24 h` (`DISPUTE_WINDOW_HOURS`) and is released by the existing `bookingClock` step 5 (`releaseEscrowPayment` pays `amount − escrowRefundedTotal(refunds)`, #129). An instant payment has no `milestones` (#130's milestone model applies to bookings with a delivery), so it keeps this single release; joining the two-milestone release is Deferred with instant reviews.
8. **Status set.** Spec §3.1 plus `finished` (photographer pressed "Hoàn thành" or the package time ran out; waiting for the customer, auto-complete after 2 h). `payment_failed` is dropped (the fake rails cannot fail; an unpaid payment window of 15 minutes returns the request to `choosing` with the choices kept on the device). `disputed` is deferred to S18 (#142). Photographer cancel returns the request to `choosing` (spec §3.1), it is not a status.
9. **Cancellation table** (spec §4, mock S13.08): customer cancel unpaid → no money (rule `unpaid` whenever `paidAt === null`, whatever the status: in #202 only `choosing`/`pending_payment` can be unpaid; in #140 every request is, so every #140 cancel and no-show records its rule-independent effects — status, presence, `reliability.late` when past `lateDeadlineAt` before arrival — with zero money); paid in `choosing`/`pending_payment`/`searching`/`no_match` → 100%; `assigned`/`en_route` before `freeCancelUntil` (= `assignedAt` + 2 min) → 100%; after `lateDeadlineAt` (= `assignedAt` + initial ETA + 15 min) and not arrived → 100% (the photographer's fault: `reliability.late++` on their presence); otherwise `assigned`/`en_route` → 80% refund, 20% to the photographer; `arrived` → **Owner 2026-10-07: a config split**, not hard-coded: the photographer keeps `instantArrivedCancelPhotographerPercent` % (server config in `instant_config/current`, integer 0–100, default and emulator seed 50; read through `InstantConfigReader`, snapshotted on the request at creation so the dry run and the real cancel agree) and the customer gets the rest; S13.08 shows the amounts of the server's dry run, never a number in copy; `in_progress` and later → `conflict` (dispute is S18). Photographer cancel in `assigned`/`en_route`/`arrived` → customer 100%, photographer 0, `reliability.cancelled++`. No-show (photographer, `arrived` ≥ 15 min) → 50/50. Refund amount = `computeRefund(amount, percent)` (floor), photographer amount = `amount − refund`.
10. **Presence in Firestore, foreground only.** `instant_presence/{uid}`: `setLiveShutter` (callable) switches `online` and checks eligibility; the app writes the heartbeat directly (rules: owner, only position fields, `heartbeatAt == request.time`, ≥ 60 s since the last one) on resume, every 5 minutes while foregrounded and on moves > 300 m (a low-accuracy fix sampled every 60 s, spec §9 "khi đi > 300 m hoặc 5 phút một lần"). A presence is fresh for 30 minutes after `heartbeatAt` (`PRESENCE_FRESH_MIN`); stale presences are not suggested. Without a foreground service (standing rule: no device steps) a backgrounded app keeps receiving FCM offers for 30 minutes with its last position, then pauses until reopened, and reopening resumes silently. The mock note "Bật lâu không mở app, chúng tôi hỏi lại sau 30 phút." becomes "Không mở app trong 30 phút thì tạm ngừng nhận lời mời; mở lại app là nhận tiếp. Huỷ sau khi nhận làm giảm điểm tin cậy." (Task 1).
11. **Location while en route: capped.** The S14.03 screen (foreground) takes a fix every 15 s and writes `instant_tracks/{requestId}` only when it moved ≥ 25 m or 60 s passed since the last write; rules refuse writes closer than 15 s apart (≤ 4 writes/min, ≤ 60 per 15-minute trip). Only `en_route`; the server deletes the track at arrival and at any end. The mock note about the Android notification becomes "Vị trí của bạn chỉ chia sẻ với khách trong lúc đang đến. Tới nơi là dừng." (Task 1).
12. **Candidate search without Maps APIs; one `distanceKm` (cross-plan review finding 5).** Distances use the shared `packages/domain/src/geo.ts` `distanceKm(a, b)` (haversine, R = 6371.0088), the one definition #139's job eligibility also uses: create `geo.ts` here (or reuse it if #139 landed first and created it exactly so); `instant.ts` does not export its own. Presence stores `geohash5` and `geohash4`; a round queries `online == true && geohash5 in [9 cells]` (3 km) and, when fewer than 5 survive, `online == true && geohash4 in [9 cells]` (covers 6 and 10 km), limit 50 each, then filters by haversine distance in rings 3 → 6 → 10 km (spec §3.2). ETA everywhere = `ceil(km × 1.4 / 20 × 60)` minutes, min 1 (spec §3.2); the UI says "khoảng". No Distance Matrix, no Directions.
13. **Offer path `instant_offers/{uid}/offers/{offerId}`** instead of the spec's `…/items/…`: the collection id `items` is already used by `earnings/{uid}/items`, and Firestore indexes and rules are scoped by collection id.
14. **Pending-offer cap on presence.** `presence.pendingOffers` = `[{offerId, requestId, expiresAt}]`; only entries with `expiresAt > now` count toward the 3 (spec §3.3); stale entries are pruned whenever the presence is written. Suggestions use the same count, so no offer query runs per candidate.
15. **The request document carries the current round only.** `candidates`, `offers`, `pendingInviteIds` are emptied at assignment, so the assigned photographer (who can read the request) never sees whom else the customer invited (spec §2.2.2 "không nêu tên người khác").
16. **Round end is cheap.** When the last pending offer of a round is declined, expires or is withdrawn, the request goes to `choosing` with `roundEnded: true` and no candidates; the customer app shows "Chưa ai nhận. Chọn thêm người nhé." and calls `nextInstantCandidates`. Accept/decline transactions never compute candidates.
17. **Gate checks:** `setLiveShutter(online: true)` (`ProviderOrderGate`, reason `not_accepting_orders`), each invitee at offer creation through #198's `orderBlocker(deps, {customerId, providerId: invitee})` (any non-null answer → row `unavailable`, silently: a customer never learns they are blocked), and `answerInstantOffer(accept)` through the same `orderBlocker` (errors `not_accepting_orders` / `blocked`; #198's `BlockGate` lives inside it, cross-plan review finding 22). `InstantDeps extends OrderGateDeps` with `blocks` wired in every deps object (live: `liveBlockGate()`; tests: `FakeBlockGate`). Revocation or a block therefore stops offers within one call.
18. **One active request per customer, one active job per photographer.** `createInstantRequest` refuses with `conflict` when the customer has an active request (the app opens it from Home, companion plan); `presence.activeRequestId` blocks suggestions and accepts.
19. **Meet point = GPS fix + a typed name** (≤ 80 characters, e.g. "Cổng Trương Định, Công viên Tao Đàn"); the area label shown in offers ("Quận 1, TP.HCM") is the nearest `areas` entry of the config within 8 km, else the city name. No geocoding, no autocomplete (cost spec §9: avoid Geocoding/Places from the client). The street line of S14.03 shows "{area} · {km} km".
20. **Notifications through #138's hooks (cross-plan review finding 12).** Offers are push-only (no inbox row, spec §3h.1), channel `default` (high priority) even in quiet hours (mock S17.02 caption); `offerPushMessage` stays here (a push, not a catalogue type). The seven inbox types — `instant_assigned`, `instant_missed`, `instant_round_ended`, `instant_no_match`, `instant_arrived`, `instant_finished`, `instant_cancelled` (critical) — are #138's catalogue rows (category `instant`, tab `activity`) with this plan's copy (the Server copy list below, moved there by the review), icons, targets and dedupe keys; this plan is the only emitter: the pure decider `instantNotices(before, after)` returns which hook to call and `onInstantRequestWrite` calls #138's seven hooks (signatures in Contract). No `notification.ts`/`notification_render.ts`/`notification_visuals.dart`/`notification_targets.dart` edit here. If #138 has not merged, create those hooks and rows exactly as S17's Contract lists them and ledger it.
21. **Chat.** On assignment the trigger ensures the pair chat (`chatIdFor(customer, photographer)`) with `kind: 'booking'`, `bookingId: null`, `readOnlyAt: null` (an existing inquiry chat is upgraded so the inquiry limits do not block the job); when the request ends and the chat has `bookingId == null`, `readOnlyAt = end + 7 days` (`BOOKING_CHAT_READONLY_DAYS`).
22. **Contact.** Customer → photographer: `getContactLink` gains subject `instant_request` (`{instantRequestId, channel}`), unlocked while the request has a photographer, is active **and is paid** (`paidAt !== null`), and 7 days after `completedAt`. Photographer → customer: `instant_requests/{id}/private/contact` (the `BookingContactSnapshot` shape), written at assignment only when the request is paid (or at payment if that comes later), deleted when the photographer cancels, readable by the assigned photographer while the request is active; the app reuses `CustomerContactDial`.
23. **Tomato/brick, not stars (cross-plan review finding 27).** #130's reviews plan has merged before this one (wave 2) and deletes `stats.rating`; this plan reads `photographers/{uid}.stats` (`tomatoPct`, `score`, `reviewCount`, `completedCount`). Score component = `(score + 1) / 2` with ≥ 5 reviews (`TOMATO_PCT_MIN_REVIEWS`), else 0.5 (the instant note of the tomato spec §9). Snapshots carry `tomatoPct` and `reviewCount` instead of `ratingAvg`. Cards and rows show the meta through #130's `MetaLine` (`MetaPart.tomato(pct)` + "{n} buổi"; "Mới · {n} đánh giá" under 5 reviews), never "★". The expanded tier takes a photographer with ≥ 5 reviews and `tomatoPct < 90` (the old "< 4.5 stars").
24. **Reviews after an instant shoot** are deferred to #130 (reviews are tied to bookings today); completion shows no review entry.
25. **Decline reason** (spec "tuỳ chọn") is not collected; "Từ chối" declines at once.
26. **"Thường có người nhận trong khoảng {n} phút"** stays hidden (spec: hide without data); deferred.
27. **Surge** is one factor per city (`surgeBp`, 10000 = ×1.0); time-of-day windows are deferred.
28. **Feature flag.** `instantEnabledProvider` (`Provider<bool>`, default `kInstantEnabled`, still `false`) hides the S06.01 Live Shutter card; routes exist and are tested. #202 (customer plan Task 8) flips `kInstantEnabled` once payment is in; #140 never does. The config doc also has `enabled` (server refuses `not_eligible` when false).
29. **Dev CLI** `npm run instant` (emulator only, `seed/local_guard` like `npm run seed`) to create a request with an offer (#140: offers at once; #202: paid through the fake confirmation first) for a photographer who is online, so S14.02/S14.03 can be checked on a device before the customer app exists.
30. **Map:** core `MapPreview` draws the mock `.map` (blocks, roads, water, park in new `map*` tokens), labelled pins placed by an equirectangular projection of their coordinates, a dotted route between the first two pins and a "Về vị trí của tôi" button. No tiles, no SDK, $0 (cost section). "Chỉ đường" opens `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}` through `ExternalLauncher` (any maps app, $0).
31. **Genres** are the five of spec §2.1 (`portrait`, `couple`, `family`, `event`, `product`, existing specialty codes; `event` is shown as "Sự kiện nhỏ"); the mock shows four chips because of width, Task 1 adds the fifth.

## Needs the owner

1. (Decided by the owner 2026-10-07: 100% to the photographer, platform fee 0% configurable — Decision 6.)
2. Real map tiles for S13.05/S14.03 (Google Maps SDK — likely free on mobile but "chưa xác nhận" —, Goong, or keep the schematic map)? Default: schematic `MapPreview` (Decision 30).
3. Price list v1 and the first cities: default 390.000 / 690.000 / 1.190.000 ₫ (30 phút·15 ảnh, 1 giờ·30 ảnh, 2 giờ·60 ảnh, from the mock), TP.HCM, Hà Nội, Đà Nẵng by bounding box, surge ×1.0 (seed only; a config doc, no code change to adjust).
4. Background presence/location (foreground service, "Vẫn muốn nhận việc?" prompt, full-screen offer intent): default foreground-only in phase 1 (Decision 10).
5. Money held in `no_match` with no customer action (spec question 9): default held until the customer cancels; one push at `no_match`, no reminders.
6. (Decided by the owner 2026-10-07: a config value `instantArrivedCancelPhotographerPercent`, default 50 — Decision 9.)

## Contract

### Existing code this plan builds on (checked 2026-10-07 on `develop` 812afd6; #129's names re-checked 2026-10-08 on develop 87d8187; Task steps "Contract check" re-check and ledger any difference; if a member is missing, stop and report)

- Domain: `DomainError`, `ERROR_CODES` (`errors.ts`), `ProviderOrderGate`, `CustomerContactReader`, `CustomerContactRecord` (`booking_ports.ts`), `Payment`, `Refund`, `LedgerEntry`, `PaymentSubject`, `applyRefundToPayment`, `releaseEscrowPayment`, `escrowRefundedTotal` (`escrow.ts`), `computeRefund`, `DISPUTE_WINDOW_HOURS` (`booking_policy.ts`), `BookingContactSnapshot` (`booking.ts`); from #129 (merged in #154) only `PaymentMethod`, `isPaymentMethod` (`escrow.ts`), `PaymentProvider` (`booking.ts`), `PAYMENT_EXPIRY_MINUTES` (`booking_policy.ts`), `PaymentGateway`, `TransferDecision` (`transfer_rules.ts`), `transferRefund` (`refunds.ts`) and `FakePaymentGateway` exist; also #129's `TransferNotification` (`booking_ports.ts`; the old plan's `TransferEvent`). The rest of this list up to `mergeRefundOutcome` is used only by Task 11 (#202) and is V1's (#200) or V2's (#201) (`2026-10-08-s04-reconciliation.md`, signatures as the old S04 plan wrote them; the files `payment_ports.ts` and `payment_settlement.ts` are V1 proposals, not on develop): V1's (names as in `2026-10-08-v1-subject-payments.md`, "Names consumers quote that differ") `PAYMENT_SUBJECTS`/`PaymentSubject`/`isPaymentSubject` (`escrow.ts`), flat `PaymentInstructions` and #129's renamed gateway answer `GatewayInstructions`, `SubjectSettler {settle(paymentId, transfer), expire(paymentId, now), dispatchRefund(refund, payment), statusOf(payment)}`, `newSubjectPayment`, `freshPaymentId`, `issuePaymentInstructions`, `instructionsOf`, `checkSubjectPayments` (`create_payment.ts`), `applyTransfer`, `expireUnpaid`, `settleTransfer`, `confirmFakePayment`, `SettlementDeps {payments, gateway, clock, subjects}` (`payment_settlement.ts`); V2's `StoredBankAccount`, `sendRefundOnce`, `mergeRefundOutcome` (`refunds.ts`), with #129's `dispatchRefunds` (`refunds.ts`, on develop) as the fallback until #201 lands; #198's `orderBlocker`, `assertOrderAllowed`, `OrderGateDeps {providers, blocks?}`, `OrderParties` (`order_gate.ts`), `BlockGate` (`block_ports.ts`), `FakeBlockGate` (`fake_block_gate.ts`); from #130's reviews plan: `TOMATO_PCT_MIN_REVIEWS`; `encodeGeohash` (`event.ts`), `isId`, `newUlid` (`ids.ts`), `isVnE164` (`phone.ts`), `Clock`, `IdGenerator`, `UserDirectory`, `PushSender`, `PushMessage`, `NotifyRequest`, `NotifyDeps`, `notify` (`notification_*.ts`), `NOTIFICATION_TYPES`, `renderNotification`, `formatVnd`, `Chat`, `chatIdFor`, `ChatDeps`, `BOOKING_CHAT_READONLY_DAYS` (`chat.ts`, `chat_ports.ts`), `getContactLink`, `parseContactLinkRequest`, `ContactSubject` (`contact.ts`, `get_contact_link.ts`), `runBookingSweeps` step 5 (`booking_sweeps.ts`), `FakePaymentGateway`, the memory-store pattern that refuses a read after a write inside a transaction (`memory_album_store.ts`), `purity.test.ts`.
- Functions: `REGION`, `CALLABLE_OPTIONS`, `PAYMENT_CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`, `SCHEDULE_OPTIONS` (`src/config.ts`), `toHttpsError` + `TRANSPORT_CODE` (`callables/errors.ts`), `assertFakePaymentsAllowed`, `fakePaymentsAllowed` (`infra/fake_payments.ts`; #140's guard on `inviteInstant`), #198's `liveBlockGate()` (`infra/live_safety.ts`) and `FirestoreBlockGate` (`infra/safety_firestore.ts`), V1's (#202 only) `liveSettlementDeps()` (`infra/live_payments.ts`; this plan registers `subjects.instant_request`) and #129's live gateway (`getSharedFakeGateway()`, `infra/live_booking.ts`), `liveNotifyDeps` (`infra/live_notification.ts`), `FcmPushSender`/`FirestoreDeviceDirectory` (`infra/fcm_push.ts`), `liveChatDeps` (`infra/live_chat.ts`), `liveContactDeps` (`infra/live.ts`), `firestoreUserContactReader` (`infra/firestore.ts`), `FirestoreProviderOrderGate` (`infra/booking_readers.ts`), `paymentToFirestore`/`paymentFromFirestore`/`refundFromFirestore` (`infra/booking_firestore.ts`, `subjectType` whitelists at ~line 230), earnings `getSubject` (`infra/earnings_firestore.ts` ~line 82) and `earningItemFromFirestore` subject mapping (~line 42), `handleBookingClock` (`scheduled/booking_clock.ts`), `db()` (`infra/admin.ts`), seed `seed/fixtures.ts` (`SEED_PHOTOGRAPHERS`, `SEED_CUSTOMER_PHONES`, Lan has a phone, Minh has none), `seed/local_guard` (used by `npm run seed`), CLIs `tools/awards.ts`, `tools/payouts.ts`.
- Rules/indexes: helpers `signedIn()`, `isOwner(uid)`, `onlyKeys(allowed)`; catch-all deny at the end; `match /payments` deny all; one test file `rules-test/rules.test.mjs`.
- App: `kInstantEnabled` (`lib/core/feature_flags.dart`), `ScreenCodes.instantAvailability` (S14.01), `.instantOffer` (S14.02), `.instantJob` (S14.03), `.instantMatched` (S13.04), `.instantCancel` (S13.08), `ScreenCode(code, label:, child:)`, `AppIcons.instant`, `CountdownRing({deadline, total, size, onExpired, now})`, `CountdownText`, `StatusTimeline`/`TimelineStep`/`TimelineStepState`, `showConfirmSheet({title, body, content, confirmLabel, keepLabel, danger, onConfirm})`, `showAppSheet`, `AppButton.primary/outline/text/danger`, `AppOptionTile`, `EscrowNotice`, `AsyncView`, `EmptyState`, `haversineKm`, `encodeGeohash`, `roundKm` (`lib/core/geo.dart`), `formatMoney`, `clockProvider` (`lib/data/clock/clock.dart`), `LocationRepository` (`currentPosition`, `permissionStatus`, `request`, `openSettings`) + `FakeLocationRepository`, `locationRepositoryProvider`, `ExternalLauncher` via `externalLauncherProvider`, `CustomerContactDial(copy:)` (`features/booking/booking_parties.dart`), `BookingContactSnapshot` (Dart, `lib/data/booking/booking.dart`), `maybeAskForNotifications(context, ref, PhotographerPrimer())`, `notificationVisualOf` (`features/notifications/notification_visuals.dart`), `safeTarget` (`features/notifications/notification_targets.dart`), `TabShell` (`features/shell/tab_shell.dart`), `WorkScreen` (`features/work/work_screen.dart`), `appRouter` routes (`lib/app/router.dart`), `currentProfileProvider`, `authStateProvider`, `functionsRegion` (`lib/data/backend/backend_config.dart`), the callable error pattern of `lib/data/events/event_callable.dart`.

### Firestore data (server writes unless stated)

| Path | Fields |
|---|---|
| `instant_config/current` (signed-in read) | `enabled: bool`, `priceListVersion: int`, `platformFeeBp: int` (0–10 000, default 0), `instantArrivedCancelPhotographerPercent: int` (0–100, default 50), `packages: [{code, durationMin, photos, priceVnd}]`, `cities: [{id, name, south, west, north, east, surgeBp}]`, `areas: [{name, lat, lng}]` |
| `instant_presence/{uid}` (owner read; owner heartbeat update) | `online`, `helpReady`, `priceListVersion: int\|null`, `cityId\|null`, `lat\|null`, `lng\|null`, `accuracyM`, `geohash5`, `geohash4`, `heartbeatAt`, `activeRequestId\|null`, `pendingOffers: [{offerId, requestId, expiresAt}]`, `profile: {name, avatarUrl, verified, providerType, tomatoPct, score, reviewCount, completedCount, specialties[], photos[≤3]}`, `reliability: {offers, accepted, declined, expired, cancelled, late, noShow}`, `updatedAt` |
| `instant_requests/{id}` (customer, assigned photographer read) | `customerId`, `customerName`, `customerAvatarUrl`, `status`, `active`, `packageCode`, `durationMin`, `photos`, `genre`, `note`, `cityId`, `meetPoint: {lat, lng, name}`, `areaLabel`, `amountVnd`, `earningVnd`, `priceListVersion`, `platformFeeBp`, `arrivedCancelPhotographerPercent` (snapshots of the config at creation, Decisions 6 and 9), `committedAt\|null` (offers sent at least once; #140 sets it on the first send, #202 in the same transaction as `paidAt`), money fields written only by #202 (null throughout #140): `payMethod\|null` (#129 `PaymentMethod` code), `provider\|null` (#129 `PaymentProvider`), `paymentId\|null`, `paidAt\|null`, `paymentDeadlineAt\|null`, `refundId\|null`, `refundStatus\|null`, `round`, `invitedTotal`, `roundsWithInvites`, `candidates[]`, `offers[]`, `pendingInviteIds[]`, `roundEnded` (`excludedIds[]` is **not** on this document: it lives in the server-only `private/dispatch` below, Task 3 ruling), `photographerId\|null`, `photographer\|null`, `chatId\|null`, `etaMinutes\|null`, `assignedAt`, `freeCancelUntil`, `lateDeadlineAt`, `startedRouteAt`, `arrivedAt`, `forcedArrivalAccuracyM\|null`, `startedAt`, `shootEndsAt`, `finishedAt`, `completedAt`, `cancelledAt`, `cancelledBy: 'customer'\|'photographer'\|null`, `cancelRule\|null`, `refundPercent\|null`, `feeVnd\|null`, `searchDeadlineAt\|null`, `lastActivityAt`, `nextDeadlineAt\|null`, `createdAt`, `updatedAt`, `version` (all instants are `Timestamp\|null`) |
| `instant_requests/{id}/private/contact` (assigned photographer read while active) | `name`, `phone`, `allowZalo`, `allowWhatsApp` |
| `instant_requests/{id}/private/dispatch` (server only, read inside transactions; added 2026-10-22) | `excludedIds[]` (who is never suggested again for this request; kept off the public document so the assigned photographer cannot see whom else the customer looked at) |
| `instant_customers/{uid}` (server only; added 2026-10-22) | `activeRequestId\|null`, `updatedAt`: the lock behind "one active request per customer" (Decision 18), read and written in the create/end transactions |
| `instant_offers/{uid}/offers/{offerId}` (owner read) | `requestId`, `photographerId`, `round`, `offeredAt`, `expiresAt`, `outcome`, `decidedAt\|null`, `packageCode`, `durationMin`, `photos`, `genre`, `areaLabel`, `distanceKm`, `etaMinutes`, `earningVnd`, `note`, `invitedCount` |
| `instant_tracks/{requestId}` (both parties read; assigned photographer updates position) | `customerId`, `photographerId`, `active`, `lat`, `lng`, `accuracyM`, `heading\|null`, `at` |
| `payments/{id}` (#202 only; existing, #129's shape plus V1's subject fields) | `subjectType: 'instant_request'`, `subjectId` = request id, `payeeId` = photographer once assigned, else `''`; `method`, `code`, `expiresAt`, `instructions` as every #129 payment |

Candidate entry: `{photographerId, name, avatarUrl, verified, providerType, tomatoPct, reviewCount, completedCount, distanceKm, etaMinutes, photos[≤3], reasons: [{code, text}] (≤ 2), tier: 'priority'|'expanded', score}`. Offer row: `{offerId|null, photographerId, name, avatarUrl, tomatoPct, reviewCount, etaMinutes, outcome: 'pending'|'accepted'|'declined'|'expired'|'withdrawn'|'unavailable', expiresAt|null}`. Party snapshot (`photographer`): `{id, name, avatarUrl, verified, tomatoPct, reviewCount, completedCount}`.

Indexes (`firestore.indexes.json`): `instant_requests (customerId ASC, active ASC)`, `instant_requests (photographerId ASC, active ASC)`, `instant_requests (active ASC, nextDeadlineAt ASC)`, `instant_presence (online ASC, geohash5 ASC)`, `instant_presence (online ASC, geohash4 ASC)`. The offer listener (`outcome == 'pending'`) uses the automatic single-field index.

### Domain (`packages/domain/src`)

```ts
// instant.ts
export const INSTANT_STATUSES = ['choosing', 'pending_payment', 'searching', 'assigned', 'en_route', 'arrived',
  'in_progress', 'finished', 'completed', 'no_match', 'abandoned', 'cancelled_by_customer', 'no_show_customer'] as const;
export type InstantStatus = (typeof INSTANT_STATUSES)[number];
export const INSTANT_TERMINAL: readonly InstantStatus[]; // completed, abandoned, cancelled_by_customer, no_show_customer
export const isInstantActive = (s: InstantStatus): boolean;
export const INSTANT_GENRES = ['portrait', 'couple', 'family', 'event', 'product'] as const;
export type InstantGenre = (typeof INSTANT_GENRES)[number];
export const OFFER_OUTCOMES = ['pending', 'accepted', 'declined', 'expired', 'withdrawn'] as const;
export type OfferOutcome = (typeof OFFER_OUTCOMES)[number];
export type OfferRowOutcome = OfferOutcome | 'unavailable';
// payment methods (#202): #129's PaymentMethod / isPaymentMethod (no instant copy of them)
export const INSTANT = {
  OFFER_TTL_S: 60, MAX_PENDING_OFFERS: 3, ROUND_SIZE: 5, PAYMENT_WINDOW_MIN: 15, SEARCH_WINDOW_MIN: 10,
  ABANDON_AFTER_MIN: 30, FREE_CANCEL_MIN: 2, LATE_GRACE_MIN: 15, NO_SHOW_WAIT_MIN: 15, AUTO_COMPLETE_H: 2,
  ARRIVE_RADIUS_M: 200, POOR_ACCURACY_M: 100, PRESENCE_FRESH_MIN: 30, RADII_KM: [3, 6, 10],
  NOTE_MAX: 140, MEET_NAME_MAX: 80, AREA_MAX_KM: 8, CONTACT_DAYS: 7, // refund re-send timing is V2's REFUND_RESEND_AFTER_MINUTES
} as const;
export interface InstantPackage { readonly code: string; readonly durationMin: number; readonly photos: number; readonly priceVnd: number }
export interface InstantCity { readonly id: string; readonly name: string; readonly south: number; readonly west: number; readonly north: number; readonly east: number; readonly surgeBp: number }
export interface InstantArea { readonly name: string; readonly lat: number; readonly lng: number }
export interface InstantConfig { readonly enabled: boolean; readonly priceListVersion: number; readonly platformFeeBp: number;
  readonly instantArrivedCancelPhotographerPercent: number; // owner 2026-10-07: config, default 50
  readonly packages: readonly InstantPackage[]; readonly cities: readonly InstantCity[]; readonly areas: readonly InstantArea[] }
export function parseInstantConfig(raw: unknown): InstantConfig; // DomainError('not_eligible') when missing/invalid; platformFeeBp 0–10000, instantArrivedCancelPhotographerPercent 0–100
export function cityAt(cfg: InstantConfig, lat: number, lng: number): InstantCity | null;
export function areaLabelAt(cfg: InstantConfig, city: InstantCity, lat: number, lng: number): string;
export function quoteInstantPrice(pkg: InstantPackage, city: InstantCity): number; // round(price × surgeBp / 10000 / 1000) × 1000
export function photographerEarning(amountVnd: number, cfg: Pick<InstantConfig, 'platformFeeBp'>): number; // amount − round(amount × platformFeeBp / 10000)
// geo.ts (shared with #139, Decision 12; create it if absent, exactly this):
export function distanceKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number; // haversine, R = 6371.0088
export function estimateEtaMinutes(km: number): number; // max(1, ceil(km × 1.4 / 20 × 60))
export function instantSearchCells(lat: number, lng: number, ring: 'near' | 'wide'): { field: 'geohash5' | 'geohash4'; cells: string[] }; // 3×3 cells
export interface InstantParty { readonly id: string; readonly name: string; readonly avatarUrl: string | null; readonly verified: boolean; readonly tomatoPct: number; readonly reviewCount: number; readonly completedCount: number }
export interface InstantCandidate { /* fields of the table above */ }
export interface InstantOfferRow { /* fields of the table above, Dates */ }
export interface InstantRequest { readonly id: string; /* every field of instant_requests, Dates for instants */ }
export interface InstantOffer { readonly id: string; /* fields of instant_offers */ }
export interface InstantPresence { readonly uid: string; /* fields of instant_presence */ }
export type InstantEvent = 'invite_unpaid' | 'payment_expired' | 'paid' | 'round_ended' | 'accept' | 'photographer_cancel'
  | 'start_route' | 'arrive' | 'start' | 'finish' | 'complete' | 'no_match' | 'reopen' | 'abandon' | 'customer_cancel' | 'no_show';
export function nextInstantStatus(from: InstantStatus, event: InstantEvent): InstantStatus; // DomainError('conflict') when not allowed
export function presenceFresh(p: InstantPresence, now: Date): boolean; // online && heartbeatAt ≥ now − 30 min
export function livePendingOffers(p: InstantPresence, now: Date): InstantPresence['pendingOffers']; // expiresAt > now

// instant_settle.ts
export interface SettleOutcome { readonly request: InstantRequest; readonly expired: readonly InstantOfferRow[];
  readonly withdrawn: readonly InstantOfferRow[]; readonly changed: boolean; readonly ended: boolean }
export function settleInstant(r: InstantRequest, now: Date): SettleOutcome;
export function nextDeadlineOf(r: InstantRequest): Date | null;

// instant_match.ts
export function rankCandidates(input: { presences: readonly InstantPresence[]; meetPoint: { lat: number; lng: number };
  genre: InstantGenre; excluded: ReadonlySet<string>; customerId: string; priceListVersion: number; now: Date }): InstantCandidate[]; // ≤ 5
export function isPriorityTier(p: InstantPresence): boolean;
export function candidateReasons(p: InstantPresence, genre: InstantGenre, km: number): { code: 'genre' | 'distance'; text: string }[];

// instant_cancel.ts
export type InstantCancelRule = 'unpaid' | 'full_refund' | 'free_window' | 'photographer_late' | 'en_route' | 'arrived' | 'photographer_cancel' | 'no_show';
export interface InstantCancelQuote { readonly rule: InstantCancelRule; readonly refundPercent: number; // 0..100
  readonly refundVnd: number; readonly feeVnd: number; readonly amountVnd: number }
/** arrived: refundPercent = 100 − r.arrivedCancelPhotographerPercent (the request's snapshot of the config, Decision 9). */
export function quoteInstantCancel(r: InstantRequest, by: 'customer' | 'photographer', now: Date): InstantCancelQuote; // conflict when not cancellable
export function quoteInstantNoShow(r: InstantRequest, now: Date): InstantCancelQuote; // deadline_passed before arrivedAt + 15 min

// instant_ports.ts
export interface InstantTx {
  getRequest(id: string): Promise<InstantRequest | null>;
  getOffer(photographerId: string, offerId: string): Promise<InstantOffer | null>;
  getPresence(uid: string): Promise<InstantPresence | null>;
  getPayment(id: string): Promise<Payment | null>;
  getRefund(id: string): Promise<Refund | null>;
  findActiveRequestOfCustomer(customerId: string): Promise<InstantRequest | null>;
  putRequest(r: InstantRequest): void; putOffer(o: InstantOffer): void; putPresence(p: InstantPresence): void;
  putPayment(p: Payment): void; putRefund(r: Refund): void; putLedgerEntry(e: LedgerEntry): void;
  putContact(requestId: string, c: BookingContactSnapshot): void; deleteContact(requestId: string): void;
  putTrack(requestId: string, t: InstantTrackDoc): void; deleteTrack(requestId: string): void;
}
export interface InstantTrackDoc { readonly customerId: string; readonly photographerId: string; readonly active: boolean;
  readonly lat: number; readonly lng: number; readonly accuracyM: number; readonly heading: number | null; readonly at: Date }
export interface InstantStore { runTransaction<T>(fn: (tx: InstantTx) => Promise<T>): Promise<T>;
  findDue(now: Date, limit: number): Promise<readonly InstantRequest[]> }
export interface PresenceDirectory { nearby(q: { field: 'geohash5' | 'geohash4'; cells: readonly string[]; limit: number }): Promise<readonly InstantPresence[]> }
export interface InstantConfigReader { get(): Promise<InstantConfig> }
export interface PhotographerPhoneReader { hasPhone(uid: string): Promise<boolean> } // photographers/{uid}/private/contact.phone is VN E.164
export interface InstantProfileReader { snapshot(uid: string): Promise<InstantPresence['profile'] | null> } // users + photographers + 3 latest work photos
/** #198's OrderGateDeps: providers + blocks. `blocks` is optional there, so every InstantDeps literal sets it:
 *  liveInstantDeps() → liveBlockGate(), the test world → FakeBlockGate (Task 3/4 tests pin both). */
export interface InstantDeps extends OrderGateDeps { readonly store: InstantStore; readonly presences: PresenceDirectory; readonly config: InstantConfigReader;
  readonly providers: ProviderOrderGate; readonly blocks: BlockGate; readonly contacts: CustomerContactReader; readonly phones: PhotographerPhoneReader;
  readonly profiles: InstantProfileReader; readonly users: UserDirectory; readonly gateway: PaymentGateway /* used from #202 */; readonly push: PushSender;
  readonly clock: Clock; readonly ids: IdGenerator }
export interface InstantCaller { readonly uid: string }

// instant_requests.ts (customer side + sweeps)
export function createInstantRequest(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ requestId: string; amountVnd: number; round: number; candidateCount: number }>;
export function nextInstantCandidates(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ round: number; candidateCount: number; status: InstantStatus }>;
export type InviteResult = { kind: 'payment'; instructions: PaymentInstructions; amountVnd: number } // #202 only: V1's type (VietQR / payUrl)
  | { kind: 'invited'; invited: string[]; unavailable: string[] }  // #140: every invite
  | { kind: 'price_changed'; amountVnd: number }; // spec §10: the new price is saved, nothing paid, the app asks again
export function inviteInstant(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<InviteResult>;
/** #202 (Task 11). Thin wrapper (payer only): V1's checkSubjectPayments over the request's created payments. */
export function checkInstantPayment(deps: InstantDeps & { settlement: SettlementDeps }, caller: InstantCaller, raw: unknown): Promise<{ paid: boolean; status: InstantStatus }>;
// instant_payments.ts (#202, Task 11) — the instant_request subject of V1's extension point (no handleInstantPayment, no own fake confirm)
export class InstantPaymentSettler implements SubjectSettler {      // settle / expire / dispatchRefund / statusOf over InstantStore
  constructor(deps: InstantDeps, cipher?: AccountCipher /* V2 (#201) only */);
}
export function cancelInstantRequest(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<InstantCancelQuote & { status: InstantStatus }>;
export function confirmInstantComplete(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }>;
export function tickInstantRequest(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }>;
export function runInstantSweep(deps: InstantDeps): Promise<{ settled: number }>; // no refund re-send: V2's

// instant_jobs.ts (photographer side)
export const LIVE_SHUTTER_REASONS = ['not_accepting_orders', 'phone_required', 'price_list_not_accepted', 'outside_service_area'] as const;
export type LiveShutterReason = (typeof LIVE_SHUTTER_REASONS)[number];
export function setLiveShutter(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ online: boolean; reasons: LiveShutterReason[] }>;
export function saveInstantSettings(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ priceListVersion: number | null; helpReady: boolean }>;
export function answerInstantOffer(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ outcome: 'accepted' | 'declined'; requestId: string }>;
export type InstantJobAction = 'start_route' | 'arrive' | 'start' | 'finish' | 'no_show';
export function updateInstantJob(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }>;

// instant_notices.ts
export type InstantNotice =
  | { hook: 'assigned' } | { hook: 'round_ended'; round: number } | { hook: 'no_match'; round: number }
  | { hook: 'arrived' } | { hook: 'finished' } | { hook: 'cancelled'; by: 'customer' | 'photographer'; photographerId: string; feeVnd: number }
  | { hook: 'missed'; photographerId: string; offerId: string };
export function instantNotices(before: InstantRequest | null, after: InstantRequest | null): InstantNotice[]; // pure decider
// consumed from #138 (packages/domain/src/notification_hooks.ts; copy, targets and dedupe keys are #138's):
export function notifyInstantAssigned(deps: NotifyDeps, e: { customerId: string; requestId: string; photographerId: string; etaMinutes: number }): Promise<NotifyResult>;
export function notifyInstantMissed(deps: NotifyDeps, e: { photographerId: string; offerId: string }): Promise<NotifyResult>;
export function notifyInstantRoundEnded(deps: NotifyDeps, e: { customerId: string; requestId: string; round: number }): Promise<NotifyResult>;
export function notifyInstantNoMatch(deps: NotifyDeps, e: { customerId: string; requestId: string; round: number; amount: number }): Promise<NotifyResult>;
export function notifyInstantArrived(deps: NotifyDeps, e: { customerId: string; requestId: string; photographerId: string; place: string }): Promise<NotifyResult>;
export function notifyInstantFinished(deps: NotifyDeps, e: { customerId: string; requestId: string; photographerId: string }): Promise<NotifyResult>;
export function notifyInstantCancelled(deps: NotifyDeps, e: { requestId: string; by: 'customer' | 'photographer'; customerId: string; photographerId: string; feeVnd: number }): Promise<NotifyResult>;
export function offerPushMessage(offer: InstantOffer): PushMessage;
export function syncInstantChat(deps: ChatDeps, before: InstantRequest | null, after: InstantRequest | null): Promise<'created' | 'upgraded' | 'closed' | 'none'>;
export function instantTrackShouldGo(before: InstantRequest | null, after: InstantRequest | null): boolean; // left en_route
```

Changes to existing domain names: `ERROR_CODES` gains `'no_match'`, `'offer_expired'`, `'already_assigned'`, `'outside_service_area'` (spec §6); `PaymentSubject` gains `'instant_request'` (V1's extension point; #202, Task 11); no notification type or content here (#138 owns the seven instant rows); `ContactSubject` gains `{ type: 'instant_request', id }` (request key `instantRequestId`); `GetContactLinkDeps` gains `instantRequests?: InstantContactReader` (`get(id): Promise<{customerId, photographerId|null, status, completedAt|null} | null>`).

### Callables (all `asia-southeast1`; errors carry `details.code`)

| Name | Caller | Input | Output | Errors |
|---|---|---|---|---|
| `createInstantRequest` | customer | `{packageCode, genre, meetPoint: {lat, lng, name}, note?}` | `{requestId, amountVnd, round, candidateCount}` | `phone_required`, `outside_service_area`, `not_eligible` (disabled), `conflict` (has an active request), `invalid_argument` |
| `nextInstantCandidates` | customer | `{requestId, skipped: string[]}` | `{round, candidateCount, status}` | `conflict`, `not_found`, `permission_denied` |
| `inviteInstant` | customer | `{requestId, photographerIds: string[1..5], skipped: string[], expectedAmountVnd}`; #202 adds `payMethod: 'bank_qr'\|'momo'\|'zalopay'` (required while uncommitted) | `{kind:'invited', invited, unavailable}` or `{kind:'price_changed', amountVnd}`; #202 adds `{kind:'payment', instructions: PaymentInstructions, amountVnd}` (V1's type) | `not_eligible` (id not in the round; #140: outside the dev project/emulator; #202: payments off), `conflict`, `invalid_argument` |
| (fake confirmation, #202) | customer | V1's unified `confirmFakePayment({paymentId})` | — | — |
| `checkInstantPayment` (#202) | customer | `{requestId}` | `{paid, status}` | `not_found`, `permission_denied` |
| `cancelInstantRequest` | customer or assigned photographer | `{requestId, dryRun: boolean}` | `{rule, refundPercent, refundVnd, feeVnd, amountVnd, status}` | `conflict`, `permission_denied` |
| `confirmInstantComplete` | customer | `{requestId}` | `{status}` | `conflict` |
| `tickInstantRequest` | customer, assigned photographer, or a photographer with an offer on it | `{requestId}` | `{status}` | `permission_denied` |
| `setLiveShutter` | photographer | `{online: boolean, dryRun?: boolean, location?: {lat, lng, accuracyM}}` | `{online, reasons}` | `invalid_argument` (online without location) |
| `saveInstantSettings` | photographer | `{acceptPriceListVersion?: int, helpReady?: boolean}` | `{priceListVersion, helpReady}` | `price_changed` |
| `answerInstantOffer` | photographer | `{offerId, action: 'accept'\|'decline'}` | `{outcome, requestId}` | `offer_expired`, `already_assigned`, `not_accepting_orders`, `not_found` |
| `updateInstantJob` | assigned photographer | `{requestId, action, location?: {lat, lng, accuracyM}, force?: boolean}` | `{status}` | `conflict`, `not_eligible` (too far for `arrive`), `deadline_passed` (`no_show` too early), `invalid_argument` |

Payment-touching and contended ones use `PAYMENT_CALLABLE_OPTIONS` (30 s): `inviteInstant`, `checkInstantPayment` (#202), `answerInstantOffer`, `cancelInstantRequest`, `confirmInstantComplete`. Trigger `onInstantRequestWrite` on `instant_requests/{requestId}` (`TRIGGER_OPTIONS`). Transport codes: the four new codes → `failed-precondition`.

### App data (`app_flutter/lib/data/instant/`, produced by Task 6, consumed by both plans)

```dart
enum InstantStatus { choosing, pendingPayment, searching, assigned, enRoute, arrived, inProgress, finished, completed, noMatch, abandoned, cancelledByCustomer, noShowCustomer;
  String get code; static InstantStatus? fromCode(String? c); bool get isActive; }
enum InstantGenre { portrait, couple, family, event, product; String get code; static InstantGenre? fromCode(String? c); }
enum OfferOutcome { pending, accepted, declined, expired, withdrawn, unavailable; static OfferOutcome fromCode(String? c); } // unknown → expired
enum InstantJobAction { startRoute, arrive, start, finish, noShow; String get code; }
enum LiveShutterReason { notAcceptingOrders, phoneRequired, priceListNotAccepted, outsideServiceArea, locationRequired }
class InstantPackage { code, durationMin, photos, priceVnd }
class InstantConfig { enabled, priceListVersion, platformFeeBp, instantArrivedCancelPhotographerPercent, packages, cityNames; int earningOf(int amountVnd); }
class InstantParty { id, name, avatarUrl, verified, tomatoPct, reviewCount, completedCount }
class InstantCandidate { photographerId, name, avatarUrl, verified, tomatoPct, reviewCount, completedCount, distanceKm, etaMinutes, photos, reasons /* List<String> texts */ }
class InstantOfferRow { photographerId, name, avatarUrl, tomatoPct, reviewCount, etaMinutes, outcome, expiresAt }
// meta lines use #130's MetaLine([MetaPart.tomato(tomatoPct) when reviewCount >= kTomatoPctMinReviews, else MetaPart.text('Mới · {n} đánh giá'), …])
class InstantMeetPoint { lat, lng, name }
class InstantRequest { id, customerId, customerName, customerAvatarUrl, status, packageCode, durationMin, photos, genre, note, meetPoint, areaLabel,
  amountVnd, earningVnd, platformFeeBp, arrivedCancelPhotographerPercent, payMethod, paid, committed /* committedAt != null */, round, invitedTotal, roundsWithInvites, candidates, offers, roundEnded, photographerId, photographer, chatId,
  etaMinutes, assignedAt, freeCancelUntil, lateDeadlineAt, arrivedAt, startedAt, shootEndsAt, finishedAt, completedAt, cancelledAt, cancelledBy,
  refundPercent, feeVnd, searchDeadlineAt, paymentDeadlineAt }
class InstantOffer { id, requestId, round, offeredAt, expiresAt, outcome, packageCode, durationMin, photos, genre, areaLabel, distanceKm, etaMinutes, earningVnd, note, invitedCount }
class InstantTrack { lat, lng, accuracyM, at }
class LiveShutterState { online, helpReady, priceListVersion, heartbeatAt, activeRequestId; bool fresh(DateTime now); }
class InstantCancelQuote { rule, refundPercent, refundVnd, feeVnd, amountVnd }
sealed class InstantInviteResult; class InstantInvited { invited, unavailable } class InstantPriceChanged { amountVnd } // #140
class InstantPaymentNeeded { PaymentInstructions instructions; int amountVnd } // #202 (Task 11): V1's PaymentInstructions
class InstantError implements Exception { const InstantError(this.code); final String code; }
String instantErrorCodeOf(Object e); // InstantError.code, SocketException → 'network', else 'unknown'
int estimateEtaMinutes(double km); // same formula as the domain (parity test)

abstract class InstantRepository {
  Future<InstantConfig> config();
  // customer (used by the companion plan)
  Future<String> createRequest({required String packageCode, required InstantGenre genre, required double lat, required double lng, required String meetPointName, String? note});
  Future<void> nextCandidates(String requestId, {List<String> skipped = const []});
  Future<InstantInviteResult> invite(String requestId, {required List<String> photographerIds, required List<String> skipped, required int expectedAmountVnd, PayMethod? payMethod}); // #140 sends no method; #202 sends #129's payMethod.code
  // #202: fake confirmation is V1's PaymentsRepository.confirmFake(paymentId, {kind}) → outcome code
  Future<bool> checkPayment(String requestId); // #202 (Task 11)
  Future<void> confirmComplete(String requestId);
  Future<String?> myActiveRequestId();
  Stream<InstantTrack?> watchTrack(String requestId);
  // both
  Stream<InstantRequest?> watchRequest(String requestId);
  Future<InstantCancelQuote> cancel(String requestId, {required bool dryRun});
  Future<void> tick(String requestId);
  // photographer
  Stream<LiveShutterState?> watchPresence();
  Future<List<LiveShutterReason>> setLiveShutter({required bool online, bool dryRun = false, ({double lat, double lng, double accuracyM})? location});
  Future<void> saveSettings({int? acceptPriceListVersion, bool? helpReady});
  Future<void> heartbeat({required double lat, required double lng, required double accuracyM});
  Stream<List<InstantOffer>> watchPendingOffers();
  Future<String> answerOffer(String offerId, {required bool accept});
  Future<InstantStatus> updateJob(String requestId, InstantJobAction action, {({double lat, double lng, double accuracyM})? location, bool force = false});
  Future<void> shareTrack(String requestId, {required double lat, required double lng, required double accuracyM, double? heading});
  Stream<BookingContactSnapshot?> watchCustomerContact(String requestId);
  Stream<InstantRequest?> watchMyActiveJob();
}
```

Providers (`instant_providers.dart`): `instantRepositoryProvider` (`FirestoreInstantRepository`, rebuilt on uid change), `instantEnabledProvider` (`Provider<bool>((_) => kInstantEnabled)`), `instantConfigProvider` (`FutureProvider.autoDispose`), `livePresenceProvider` (`StreamProvider.autoDispose<LiveShutterState?>`), `pendingOffersProvider` (`StreamProvider.autoDispose<List<InstantOffer>>`), `instantRequestProvider` (`StreamProvider.autoDispose.family<InstantRequest?, String>`), `instantTrackProvider` (same, `InstantTrack?`), `instantCustomerContactProvider` (same, `BookingContactSnapshot?`), `myActiveInstantJobProvider` (`StreamProvider.autoDispose<InstantRequest?>`).

### Routes

`/work/instant` → `LiveShutterScreen` (S14.01); `/work/instant/offer/:offerId` → `OfferScreen` (S14.02); `/work/instant/:id` → `InstantJobScreen` (S14.03; ~~S13.04 overlay on arrival from S14.02 with `?matched=1`~~ corrected 2026-10-22: S14.02 shows the S13.04 overlay itself and then replaces itself with `/work/instant/{requestId}`, no query; S14.03 never shows the overlay). Push targets `/work/instant`, `/work/instant/:id`, `/work/instant/offer/:offerId` are allowlisted by #138 (S17 owns `safeTarget`).

### Strings (`lib/l10n/app_vi.arb`, exact Vietnamese)

| Key | Text |
|---|---|
| `instantTitle` | Chụp ngay |
| `instantGenrePortrait` / `Couple` / `Family` / `Event` / `Product` | Chân dung / Cặp đôi / Gia đình / Sự kiện nhỏ / Sản phẩm |
| `instantDurationMinutes` | {n} phút |
| `instantDurationHours` | {n} giờ |
| `instantPackageLabel` | {duration} · {photos} ảnh |
| `instantStatusAssigned` / `EnRoute` / `Arrived` / `InProgress` / `Finished` | Đã nhận / Đang đến / Đã đến / Đang chụp / Chờ khách xác nhận |
| `instantErrorGeneric` | Chưa thực hiện được. Thử lại nhé. |
| `instantErrorNetwork` | Mất kết nối. Thử lại nhé. |
| `liveShutterTitle` | Live Shutter |
| `liveShutterBody` | Nhận lời mời ở gần bạn. Vị trí được dùng khi bật. |
| `liveShutterCardOn` | Đang bật · nhận lời mời ở gần bạn |
| `liveShutterCardOff` | Đang tắt · bật để nhận việc chụp ngay |
| `liveShutterCardJob` | Việc chụp ngay · {name} · {status} |
| `helpReadyTitle` | Sẵn sàng hỗ trợ |
| `helpReadyBody` | Được ưu tiên mời cả việc gấp, xa hơn một chút. |
| `priceListTitle` | Bảng giá gói |
| `priceListAccepted` | Bản {version} · đã đồng ý |
| `priceListNotAccepted` | Bản {version} · chưa đồng ý |
| `priceListCustomerPays` | Khách trả |
| `priceListYouGet` | Bạn nhận |
| `priceListTermsNote` | Giá do nền tảng đặt, giống nhau cho mọi nhiếp ảnh gia trong một lượt gợi ý. Đồng ý để bật Live Shutter. |
| `priceListAccept` | Đồng ý bảng giá |
| `liveShutterNote` | Không mở app trong 30 phút thì tạm ngừng nhận lời mời; mở lại app là nhận tiếp. Huỷ sau khi nhận làm giảm điểm tin cậy. |
| `liveShutterOffToday` | Tắt khi xong việc hôm nay |
| `liveShutterLockedTitle` | Chưa bật được Live Shutter |
| `liveShutterReasonNotAccepting` | Hoàn tất xác minh và hồ sơ để nhận đơn |
| `liveShutterReasonPhone` | Thêm số điện thoại |
| `liveShutterReasonPriceList` | Đồng ý bảng giá gói |
| `liveShutterReasonOutside` | Bạn đang ở ngoài khu vực có Chụp ngay |
| `liveShutterReasonLocation` | Cho phép dùng vị trí để nhận lời mời ở gần |
| `liveShutterAddPhone` | Thêm số |
| `liveShutterOpenSettings` | Mở cài đặt |
| `offerTitle` | Lời mời chụp ngay |
| `offerPendingCount` | {n} lời mời đang chờ |
| `offerSecondsUnit` | giây |
| `offerYouGet` | Bạn nhận · {genre} {duration} · {photos} ảnh |
| `offerDistance` | {km} km · khoảng {minutes} phút · địa chỉ hiện khi bạn nhận |
| `offerChosenAmong` | Khách đã chọn bạn trong {n} người. Ai nhận trước sẽ được việc. |
| `offerDecline` | Từ chối |
| `offerAccept` | Nhận việc |
| `offerAlreadyAssigned` | Khách đã chọn được người khác |
| `offerExpired` | Lời mời đã hết hạn |
| `offerNotAccepting` | Bạn chưa nhận đơn được lúc này |
| `matchTitle` | Đã match với {name} |
| `matchBodyCustomer` | {name} đã nhận lời mời của bạn và đang chuẩn bị tới {place}, khoảng {minutes} phút. |
| `matchBodyPhotographer` | {name} đang chờ ở {place}. Tiếp tục để xem đường đi. |
| `matchContinue` | Tiếp tục |
| `jobTitleEnRoute` | Đang đến |
| `jobTitleArrived` | Đã đến |
| `jobTitleShooting` | Đang chụp |
| `jobTitleFinished` | Chờ khách xác nhận |
| `jobTitleCompleted` | Đã hoàn thành |
| `jobSubtitle` | {name} · {genre} {duration} |
| `jobDirections` | Chỉ đường |
| `jobDistanceLine` | {area} · {km} km |
| `jobStepAccepted` | Đã nhận · {time} |
| `jobStepArriveHint` | Đã đến (bật khi còn cách 200 m) |
| `jobStepArrived` | Đã đến · {time} |
| `jobStepShoot` | Bắt đầu chụp · Hoàn thành |
| `jobStepStarted` | Bắt đầu chụp · {time} |
| `jobLocationNote` | Vị trí của bạn chỉ chia sẻ với khách trong lúc đang đến. Tới nơi là dừng. |
| `jobLocationNeeded` | Cho phép dùng vị trí để chia sẻ đường đi với khách. |
| `jobArrive` | Đã đến |
| `jobArriveFar` | Còn cách {distance}. Tới gần hơn để bấm Đã đến. |
| `jobArriveForceTitle` | GPS chưa chính xác |
| `jobArriveForceBody` | Vị trí đang lệch khoảng {meters} m. Xác nhận bạn đã tới điểm hẹn? |
| `jobArriveForceConfirm` | Xác nhận đã đến |
| `jobArriveForceKeep` | Chờ GPS |
| `jobStart` | Bắt đầu chụp |
| `jobFinish` | Hoàn thành |
| `jobShootLeft` | còn lại |
| `jobShootNote` | Hết giờ gói hoặc bấm Hoàn thành, khách sẽ xác nhận. |
| `jobFinishedNote` | Khách xác nhận hoặc tự hoàn thành sau 2 giờ. Tiền chuyển cho bạn 24 giờ sau khi hoàn thành. |
| `jobBackToWork` | Về Công việc |
| `jobNoShow` | Khách không có mặt |
| `jobNoShowIn` | Khách không có mặt (sau {time}) |
| `jobNoShowTitle` | Báo khách không có mặt? |
| `jobNoShowBody` | Khách được hoàn 50%, bạn nhận {amount}. |
| `jobNoShowConfirm` | Báo khách không có mặt |
| `jobNoShowKeep` | Chờ thêm |
| `jobCancel` | Huỷ việc |
| `jobCancelledTitle` | Khách đã huỷ yêu cầu |
| `jobCancelledFee` | Bạn nhận {amount} phí đi lại. |
| `jobCancelledNoFee` | Không cần tới điểm hẹn nữa. |
| `providerCancelTitle` | Huỷ việc chụp ngay? |
| `providerCancelBody` | Khách được hoàn 100%. Huỷ sau khi nhận làm giảm điểm tin cậy của bạn. |
| `providerCancelConfirm` | Huỷ việc |
| `providerCancelKeep` | Giữ việc |
| `mapRecenter` | Về vị trí của tôi |
| `mapSemantics` | Bản đồ: {pins} |

Server copy, verbatim. The offer push stays here (`offerPushMessage`); the seven inbox copies below were moved by the cross-plan review into #138's catalogue (`notification_render.ts`, owned by #138) unchanged, and are listed here only so this plan's tests can assert what the hooks render:
- offer push: title "Lời mời chụp ngay", body "{genre} {duration} · {area} · bạn nhận {earning}. Còn 60 giây."
- `instant_assigned`: "Đã match với {name}" / "{name} đến trong khoảng {minutes} phút."
- `instant_round_ended`: "Chụp ngay" / "Chưa ai nhận. Chọn thêm người nhé."
- `instant_no_match`: "Chưa tìm được nhiếp ảnh gia" / "{amount} vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ."
- `instant_arrived`: "{name} đã đến điểm hẹn" / "Gặp nhau ở {place}."
- `instant_finished`: "{name} đã hoàn thành buổi chụp" / "Xác nhận hoàn thành trong 2 giờ, nếu không sẽ tự hoàn thành."
- `instant_cancelled` (to the photographer, customer cancelled): "Khách đã huỷ chụp ngay" / "Bạn nhận {amount} phí đi lại." when fee > 0, else "Không cần tới điểm hẹn nữa."; (to the customer, photographer cancelled): "{name} đã huỷ" / "Chọn người khác, không trả thêm."
- `instant_missed`: "Bạn đã bỏ lỡ một lời mời" / "Lời mời chụp ngay đã hết hạn."
Targets: customer rows `/instant/{id}`; photographer `instant_cancelled` → `/work/instant/{id}`; `instant_missed` → `/work/instant` (all allowlisted by #138 in `safeTarget`; this plan does not edit `notification_targets.dart` or `notification_visuals.dart`).

## Review Focus

1. **Two accepts on one request, and one photographer accepting two requests.** Exactly one `assigned`; the loser gets `already_assigned`, their presence keeps `activeRequestId: null`, every other offer of the request and of the winner is `withdrawn`. Pinned by Task 3 tests "two accepts on one request: one winner" and "one photographer, two requests: one accept" and Task 5 integration "five parallel accepts, one winner" (written).
2. **Money never moves on a timer except release, and every split sums to the amount** (the money parts are pinned in Task 11, #202; #140 pins that nothing writes money). `no_match` writes no refund; abandoning an unpaid request touches no payment; a payment confirmed after cancel or after the payment window refunds 100% (`late_payment`); each row of the cancel table sums `refund + fee == amount` to the đồng. Pinned by Task 2 "every cancel rule sums to the amount (property over 1.000 random amounts)" and Task 3 "search window ends in no_match without a refund", "payment confirmed after cancel is refunded in full".
3. **Privacy.** An offer never carries the meet point coordinates or name (only `areaLabel`, `distanceKm`); the assigned photographer never sees other invitees (round fields emptied); the track exists only while `en_route` and is readable only by the two parties; the customer phone copy is readable only by the assigned photographer while active and is deleted on photographer cancel. Pinned by Task 3 "offer doc has no meet point" and "assignment empties the round", Task 5 rules tests "an invited photographer cannot read the request", "another user cannot read the track", "a cancelled photographer cannot read the contact copy".
4. **Expiry by server time and the forgotten request.** Accept at 60.5 s → `offer_expired` and the row shows "Hết hạn"; a `searching` request whose offers all expired while both apps are closed is settled by the clock step (status `choosing` with `roundEnded`, or `no_match` after 10 minutes) and a photographer whose offer expired gets one `instant_missed` row. Pinned by Task 3 "accept after expiry", "sweep settles a forgotten round", Task 5 "trigger notifies missed offers once".
5. **Gate and duplicates.** A photographer whose verification was revoked after going online gets no new offers (`unavailable`) and cannot accept (`not_accepting_orders`); the client cannot write `online`, `activeRequestId`, `pendingOffers` or `cityId` on its presence, nor a track point faster than 15 s. Pinned by Task 3 "revoked photographer is unavailable at invite", "revoked photographer cannot accept" and Task 5 rules "owner cannot switch online by writing", "track write within 15 s is denied".

## Chi phí Google

Assumptions (cost spec §11–12): (b) 1.000 MAU, 100 photographers, 150 instant requests/month (100 matched), 30 Live Shutter users × 20 days; (c) 10.000 MAU, 1.000 photographers, 1.500 requests (1.000 matched), 300 Live Shutter users × 20 days. Firestore at the nam5 upper bound ($0.06/100K reads, $0.18/100K writes, **Singapore price chưa xác nhận**); 0.2 vCPU-s and 0.1 GiB-s per call. **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s.

**Reads/writes per action** (get vs listener):
| Action | Reads | Writes | Notes |
|---|---|---|---|
| `createInstantRequest` | ~25 (config 1, contact 1, active check 1, user 1, presence queries 2 × ≤ 50, typically ~20) | 1 | `get`/queries inside the callable, `limit(50)`, two new composite indexes |
| `nextInstantCandidates` | ~20 | 1 | same queries |
| `inviteInstant` first round + payment confirm | ~11 | ~11 (payment, ledger, request, 3 offers, 3 presences, contact) | gate reads 3 outside the transaction |
| later round invite | ~9 | ~8 | |
| `answerInstantOffer` accept | ~7 | ~9 (request, ≤ 5 offers, presence, payment, contact) | |
| decline | 2 | 3 | |
| job updates (start route → complete) | ~11 | ~9 + track create/delete 2 | |
| track while en route | 0 (rules use no `get()`) | ≤ 60 per 15-minute trip | cap 1/15 s and ≥ 25 m (Decision 11) |
| photographer listeners | offers ~3, request ~8, contact 1 per job | — | listener only while S14.x is open; offer listener app-wide only while online and foregrounded |
| trigger notices + chat | ~10 | ~12 | 6–8 notices per request (rows, inbox counts, prefs, devices) |
| heartbeat | 0 | ≤ 24 per online photographer-day | client write, ≥ 60 s apart by rules |
| `setLiveShutter` (dry run on open + toggles, ~4/day) | ~8 (photographer, contact, config, 6 posts) | 1 | |
| clock step | 1 per run (empty query) | settles only | 2.880 runs/month inside the existing `bookingClock` |

Per request ≈ 105 reads and 112 writes. Totals per month: (b) reads ≈ 16K + 9.6K (`setLiveShutter`) + 2.9K (clock) ≈ 28K, writes ≈ 17K + 14K (heartbeats) + 1.2K ≈ 32K → ~$0.02 + $0.06; (c) reads ≈ 158K + 96K + 2.9K ≈ 257K, writes ≈ 168K + 144K + 12K ≈ 324K → ~$0.15 + $0.58.

**New functions:** 11 callables + 1 trigger (the fake confirmation is #129's), 256 MiB, 10 s (30 s for the six payment/contended ones), `maxInstances: 10`. Calls/month ≈ 28 per request (16 callables + 12 trigger runs) + 4 `setLiveShutter` per photographer-day: (b) 150 × 28 + 2.400 ≈ 6.6K; (c) 1.500 × 28 + 24K ≈ 66K. (b) inside the free tier; (c) 13K vCPU-s ≈ $0.45 + 6.6K GiB-s ≈ $0.02 + 66K calls ≈ $0.03 = ~$0.50 (Functions rule: charged at (c)).

**Scheduled jobs:** none new (Decision 3). One step added to `bookingClock` (every 15 minutes, 2.880 runs/month, 1 read when nothing is due). Scheduler cost unchanged.

**Storage:** no new path.

**Paid APIs:** none. Maps: `MapPreview` is drawn on the device, "Chỉ đường" is a deep link to the maps app ($0). For comparison if the owner chooses a real map later (cost spec §9, 10.000 free per SKU): ~6 map loads per request ((c) 9.000/month, under the free 10.000 of Dynamic Maps if mobile loads are billed at all, "chưa xác nhận") and a live ETA from Distance Matrix/Routes at 1 per minute for 15 minutes (15 elements per trip, (c) 15.000/month → ~5.000 billable × $5/1.000 ≈ **$25/month**), plus autocomplete/geocoding for the meet point (under 10.000 at (c)). The schematic map and the straight-line ETA avoid all of it. FCM is free.

**Conclusion:** this plan adds ≈ **$0.1/month at (b)** and ≈ **$1.3/month at (c)** (Firestore $0.73, Functions $0.50, Scheduler $0), below the $5 threshold of §14. Mitigations already in the design: no 1-minute cron, no Maps API, offer cap and candidate queries limited to 50, track writes capped at 4/min by rules, heartbeat ≥ 60 s by rules, listeners only on open screens.

---

## Tasks

### Task 1 (#140): Mock frames and copy for the provider side

**Files:**
- Modify: `docs/design/ui-mock.html` (rail `#S14`, rail `#S06`, `#S13.04`, `#S13.08`; reuse `.step`/`.phone`/`.cap`, `.card`, `.sw2`, `.opt`, `.cd`/`.ring`, `.tl`, `.btn`, `.map`, `.mpin`, `<span class="ms">`), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (only the S14.01 and S14.03 "Trạng thái" cells get "mock cập nhật 2026-10-07 (#140)"; codes unchanged).

- [ ] **Step 1: Add frames** after the existing ones of each rail, each with a caption `<span class="n new">Mới</span>` and the copy below verbatim (Vietnamese, from the Strings table):
  - `id="S06.01-instant"` (data-code `S06.01`): S06.01 with a `card hi` above "Hôm nay": `bolt` icon, title "Live Shutter", line "Đang bật · nhận lời mời ở gần bạn", chevron; second card below it for an active job: "Việc chụp ngay · Lan Anh · Đang đến". Caption: "Thẻ Live Shutter ở đầu Công việc. Đang tắt: 'Đang tắt · bật để nhận việc chụp ngay'. Có việc đang làm: thẻ việc mở S14.03."
  - `id="S14.01-terms"` (data-code `S14.01`): same layout as S14.01 with the switch disabled (`.sw2.dis`), section "Bảng giá gói · Bản 1 · chưa đồng ý", the three rows, note `priceListTermsNote`, footer primary "Đồng ý bảng giá".
  - `id="S14.01-locked"`: switch disabled; card "Chưa bật được Live Shutter" with rows (icon + text + small outline action): "Hoàn tất xác minh và hồ sơ để nhận đơn", "Thêm số điện thoại" + "Thêm số", "Cho phép dùng vị trí để nhận lời mời ở gần" + "Mở cài đặt"; price table below; no footer button.
  - In `#S14.01` replace the note with `liveShutterNote` (Decision 10) and add to the caption "Giá trị 'Bạn nhận' lấy từ cấu hình (100% ở giai đoạn 1, quyết định 6)."
  - `id="S13.04-provider"` (data-code `S13.04`): the `.match` layout with "Đã match với Lan Anh" and `matchBodyPhotographer` ("Lan Anh đang chờ ở Công viên Tao Đàn. Tiếp tục để xem đường đi."), "Tiếp tục".
  - In `#S14.03`: add a small outline `cdial` "Liên hệ" next to "Chỉ đường", a text button "Huỷ việc" (red, `.btn.txt` with `--bad`) above the footer, replace the address line with "Quận 1, TP.HCM · 1,4 km" and the note with `jobLocationNote` (Decision 11).
  - `id="S14.03-arrived"`: title "Đã đến"; map hidden; card with meet point; timeline: "Đã nhận · 15:21" done, "Đã đến · 15:38" done, "Bắt đầu chụp · Hoàn thành"; text button "Khách không có mặt (sau 12:40)" (disabled look); footer primary "Bắt đầu chụp".
  - `id="S14.03-shooting"`: title "Đang chụp"; `.cd` ring "38:12 còn lại"; card; note `jobShootNote`; footer primary "Hoàn thành".
  - `id="S14.03-done"`: title "Chờ khách xác nhận"; note `jobFinishedNote`; footer outline "Về Công việc".
  - `id="S13.08-provider"` (data-code `S13.08`): sheet over the dimmed S14.03 map: "Huỷ việc chụp ngay?", body `providerCancelBody`, red "Huỷ việc", text "Giữ việc".
  - In `#S13.01` add the fifth chip "Sự kiện nhỏ" (Decision 31).
- [ ] **Step 2:** Open the mock (`#S14.01-terms`, `#S14.03-arrived`) and check the Debug overlay shows the codes; no broken layout at the 320px phone width.
- [ ] **Step 3: Commit** `docs(mock): Chụp ngay provider frames S06.01-instant, S14.01 variants, S14.03 states, S13.04/S13.08 provider [#140]`.

### Task 2 (#140): Domain rules — model, config, pricing, timers, ranking, cancellation

**Files:**
- Create: `packages/domain/src/instant.ts`, `instant_settle.ts`, `instant_match.ts`, `instant_cancel.ts`; tests `packages/domain/test/instant.test.ts`, `instant_settle.test.ts`, `instant_match.test.ts`, `instant_cancel.test.ts`, `test/support/instant_fixtures.ts` (`aRequest(overrides)`, `aPresence(uid, overrides)`, `aConfig(overrides)`, fixed `T0`).
- Create also: `packages/domain/src/geo.ts` (`distanceKm`, Decision 12; skip if #139 already created it with this exact signature) and `test/geo.test.ts` (`distanceKm Tao Đàn → Bến Thành ≈ 0,65 km` (corrected 2026-10-22; the plan first said ≈ 1,1 km), `0 for the same point`).
- Modify: `packages/domain/src/errors.ts` (four codes), `index.ts` (exports). (`escrow.ts` `PaymentSubject` += `'instant_request'` → Task 11 (#202).)

**Interfaces:** Produces everything listed under `instant.ts`, `instant_settle.ts`, `instant_match.ts`, `instant_cancel.ts` in the Contract, and `geo.ts` `distanceKm(a: {lat, lng}, b: {lat, lng}): number`. Consumes `encodeGeohash` (`event.ts`), `computeRefund`, `TOMATO_PCT_MIN_REVIEWS` (#130).

- [ ] **Step 1: Contract check** of the domain names in "Existing code"; ledger any difference.
- [ ] **Step 2: Failing tests.**
  - `instant.test.ts`: `parseInstantConfig accepts the seed config`; `refuses platformFeeBp outside 0–10000 and instantArrivedCancelPhotographerPercent outside 0–100 with not_eligible`; `a missing split reads the default 50 only through the seed, never in code paths of the request (the request snapshots it)`; `refuses a package with a non-integer price`; `cityAt finds HCM inside its box and null in the sea`; `areaLabelAt picks the nearest area within 8 km, else the city name`; `quoteInstantPrice rounds 690000 × 1.15 to 794000` (and ×1.0 unchanged, ×1.25 of 390000 = 488000); `photographerEarning is the amount with platformFeeBp 0 and amount − 10% with 1000`; `estimateEtaMinutes: 0 km → 1, 1.2 km → 6, 2.1 km → 9, 10 km → 42`; `instantSearchCells near uses geohash5 3×3, wide uses geohash4 3×3, centre cell first`; `nextInstantStatus allows every arrow of spec §3.1 plus finished` (table of `[from, event, to]`) and `refuses every other pair with conflict` (generated from the table: all statuses × all events not listed); `isInstantActive is false only for the four terminal statuses`; `livePendingOffers drops expired entries`; `presenceFresh is false 30 minutes after the heartbeat or when offline`.
  - `instant_settle.test.ts`: `a pending offer past expiresAt becomes expired and its photographer is excluded`; `the last pending offer expiring ends the round: choosing, roundEnded, no candidates`; `an offer still pending keeps searching`; `committed request past searchDeadlineAt becomes no_match and pending offers are withdrawn`; `no_match is not ended and has no refund fields`; `pending_payment past paymentDeadlineAt returns to choosing and clears pendingInviteIds` (state reached only from #202; pure); `uncommitted choosing idle for 30 minutes becomes abandoned (inactive)`; `committed choosing idle for 30 minutes is not abandoned`; `in_progress past shootEndsAt becomes finished at shootEndsAt`; `finished 2 h later becomes completed (ended) with completedAt = finishedAt + 2 h`; `settling twice changes nothing the second time`; `nextDeadlineOf returns the earliest timer of the status` (one case per status, null for terminal and for en_route); refunds never set a deadline here (#129 re-sends them).
  - `instant_match.test.ts`: `returns at most 5, nearest rings first (3 then 6 then 10 km)`; `stops widening once 5 are found within 3 km`; `skips offline, stale, busy, excluded, self, other price list, and 3 live pending offers`; `counts only unexpired pending offers`; `priority tier fills first, expanded only fills the rest`; `helpReady joins the priority tier and gets +0.05`; `a photographer with ≥ 5 reviews and tomatoPct below 90 is expanded`; `the score component is (score + 1) / 2 with ≥ 5 reviews, else 0.5` (Decision 23); `a photographer with ≥ 10 offers and > 10% cancels is expanded`; `score orders by ETA when everything else is equal`; `genre match beats 1 km of distance at equal rating`; `ties break by distance then uid (stable)`; `reasons: "Chuyên chân dung" first when the genre matches, then "Cách 1,2 km" ("Cách 800 m" below 1 km)`; `candidate photos are at most 3`.
  - `instant_cancel.test.ts`: one test per rule of Decision 9 (`unpaid`, `full_refund` in choosing/pending_payment(paid)/searching/no_match, `free_window` at assignedAt + 1:59, `en_route` at assignedAt + 2:01 → 80/20 of 690000 = 552000/138000, `photographer_late` after lateDeadlineAt, `arrived` with the request's split: 50 → 345000/345000 of 690000, 30 → refund 483000 / fee 207000, `photographer_cancel` 100, `no_show` 50; all with `paidAt` set); `an unpaid request gives rule unpaid with zero refund, fee and amount in every status` (#140's only case on the real backend); `the arrived split comes from the request snapshot, not the current config`; `in_progress, finished and terminal refuse with conflict`; `photographer cannot cancel before assignment (conflict)`; `quoteInstantNoShow refuses before arrivedAt + 15 min with deadline_passed`; property `refundVnd + feeVnd == amountVnd for 1.000 random amounts (1.000–20.000.000) and every rule` (seeded PRNG).
- [ ] **Step 3:** `cd packages/domain && npm test` → the new tests fail (missing modules).
- [ ] **Step 4: Implement.** `settleInstant` is the subtle part; follow this order so one call converges:
  ```ts
  export function settleInstant(r: InstantRequest, now: Date): SettleOutcome {
    if (!isInstantActive(r.status)) return { request: r, expired: [], withdrawn: [], changed: false, ended: false };
    const t = now.getTime();
    let next = r;
    const expired: InstantOfferRow[] = [];
    let withdrawn: InstantOfferRow[] = [];
    if (next.status === 'searching') {
      const offers = next.offers.map((o) => {
        if (o.outcome !== 'pending' || o.expiresAt === null || o.expiresAt.getTime() > t) return o;
        expired.push(o);
        return { ...o, outcome: 'expired' as const };
      });
      next = { ...next, offers, excludedIds: union(next.excludedIds, expired.map((o) => o.photographerId)) };
      if (!offers.some((o) => o.outcome === 'pending')) next = { ...next, status: 'choosing', roundEnded: true, candidates: [] };
    }
    const committed = next.committedAt !== null; // offers sent at least once; from #202 on this implies paid
    if (committed && (next.status === 'choosing' || next.status === 'searching')
        && next.searchDeadlineAt !== null && next.searchDeadlineAt.getTime() <= t) {
      withdrawn = next.offers.filter((o) => o.outcome === 'pending');
      next = { ...next, status: 'no_match', roundEnded: false, candidates: [],
        offers: next.offers.map((o) => (o.outcome === 'pending' ? { ...o, outcome: 'withdrawn' as const } : o)) };
    }
    if (next.status === 'pending_payment' && next.paymentDeadlineAt !== null && next.paymentDeadlineAt.getTime() <= t) {
      next = { ...next, status: 'choosing', pendingInviteIds: [] };
    }
    if (!committed && (next.status === 'choosing' || next.status === 'pending_payment')
        && next.lastActivityAt.getTime() + INSTANT.ABANDON_AFTER_MIN * 60_000 <= t) {
      next = { ...next, status: 'abandoned', active: false, candidates: [], offers: [], pendingInviteIds: [] };
    }
    if (next.status === 'in_progress' && next.shootEndsAt !== null && next.shootEndsAt.getTime() <= t) {
      next = { ...next, status: 'finished', finishedAt: next.shootEndsAt };
    }
    if (next.status === 'finished' && next.finishedAt !== null
        && next.finishedAt.getTime() + INSTANT.AUTO_COMPLETE_H * 3_600_000 <= t) {
      next = { ...next, status: 'completed', active: false,
        completedAt: new Date(next.finishedAt.getTime() + INSTANT.AUTO_COMPLETE_H * 3_600_000) };
    }
    const changed = next !== r;
    next = changed ? { ...next, nextDeadlineAt: nextDeadlineOf(next), updatedAt: now, version: r.version + 1 } : r;
    return { request: next, expired, withdrawn, changed, ended: changed && !next.active };
  }
  ```
  `rankCandidates`: filter (Decision 14, spec §3.2 exclusions), compute `km = distanceKm(meetPoint, p)`, keep the smallest ring of `RADII_KM` that yields ≥ 5 (else all within 10 km), score `0.45·eta + 0.25·genre + 0.15·rating + 0.15·reliability` with `eta = 1 − min(etaMin, 60)/60`, `rating` = the tomato score component of Decision 23, `reliability = offers ≥ 10 ? clamp(accepted/offers − cancelled/max(accepted,1), 0, 1) : 0.5`, `+0.05` for `helpReady` in the priority tier; sort priority tier then expanded, each by score desc, distance asc, uid asc. Genre words for reasons: `portrait` "chân dung", `couple` "cặp đôi", `family` "gia đình", `event` "sự kiện nhỏ", `product` "sản phẩm"; distance text with a comma decimal ("1,2 km"). Export everything from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): Chụp ngay rules — states, timers, pricing, ranking, cancellation money [#140]`.

### Task 3 (#140): Domain use cases — requests, offers, jobs, presence, notices

**Files:**
- Create: `packages/domain/src/instant_ports.ts`, `memory_instant_store.ts`, `instant_requests.ts`, `instant_jobs.ts`, `instant_notices.ts`; tests `packages/domain/test/instant_requests.test.ts`, `instant_jobs.test.ts`, `instant_notices.test.ts`, `test/support/instant_world.ts`. (`instant_payments.ts` and its test → Task 11 (#202).)
- Modify: `contact.ts` + `get_contact_link.ts` (`instant_request` subject), `index.ts`; tests `test/get_contact_link.test.ts`. (No `notification.ts`/`notification_render.ts` change: #138's.)

**Interfaces:**
- Consumes: Task 2; `ProviderOrderGate`, `CustomerContactReader`, `PushSender`, `UserDirectory`, `ChatDeps`, `chatIdFor`, `BOOKING_CHAT_READONLY_DAYS`; #198's `orderBlocker(deps: OrderGateDeps, p: OrderParties): Promise<'not_accepting_orders' | 'blocked' | null>` (`order_gate.ts`) and `FakeBlockGate` (`fake_block_gate.ts`); #138's seven instant hooks (Contract). Task 11 (#202) consumes, not this task: `applyRefundToPayment` and, from V1/V2 (signatures in Task 11 and in `2026-10-08-v1-subject-payments.md` / `2026-10-08-v2-refund-destination.md`): `newSubjectPayment`, `freshPaymentId`, `issuePaymentInstructions`, `instructionsOf`, `applyTransfer`, #129's `transferRefund(...)`, `expireUnpaid`, `sendRefundOnce`, `mergeRefundOutcome`, `checkSubjectPayments`, `SubjectSettler`, #129's `FakePaymentGateway` (`pushTransfer`), `settleTransfer`, `confirmFakePayment`, V2's refund re-send.
- Produces: the `instant_ports.ts`, `instant_requests.ts`, `instant_jobs.ts`, `instant_notices.ts` signatures of the Contract; `MemoryInstantStore` (serialises transactions with a promise chain, refuses a read after a write in the same transaction like `memory_album_store.ts`, exposes `requests`, `offers`, `presences`, `payments`, `refunds`, `ledger`, `contacts`, `tracks` maps for assertions) and `MemoryPresenceDirectory` (filters `online` and the cell field in memory); `createInstantWorld({now?})` returning `{deps, store, pushes: PushMessage[] by uid, gate: Map<uid, OrderEligibilityFields>, blocks: FakeBlockGate (also `deps.blocks`), phones: Set<uid>, clock: {set(d), advance(ms)}, online(uid, {lat, lng, …}), customer(uid, {phone?})}` with seed config TP.HCM, Lan (`c-lan`, phone) and five photographers `p1`–`p5` around Tao Đàn (0.5–2.5 km) plus `p6` at 8 km. Task 11 (#202) adds `gateway: FakePaymentGateway` (#129's; simulated transfers through `pushTransfer`) and `settlement: SettlementDeps` (with `subjects.instant_request`).

Behaviour (each use case starts with `settleInstant` on the request inside its transaction and applies the side writes of what settled: expired/withdrawn offer docs, presence `pendingOffers` pruning; the payment release stamp on completion is added by Task 11 (#202)). **No payment, refund or ledger write anywhere in this task (#140):**
- `createInstantRequest`: validate (`packageCode` in config, `genre`, `meetPoint` lat/lng and name 1–80 after trim, `note` ≤ 140), `config.enabled` else `not_eligible`, customer phone (`contacts.get`, `isVnE164`) else `phone_required`, `cityAt` else `outside_service_area`, no active request (`findActiveRequestOfCustomer`) else `conflict`; price = `quoteInstantPrice`, snapshots `platformFeeBp` and `arrivedCancelPhotographerPercent = cfg.instantArrivedCancelPhotographerPercent`; candidates from `presences.nearby` (near, then wide when < 5) → `rankCandidates`; write the request (`choosing`, `round: 1`, `lastActivityAt: now`, `customerName/AvatarUrl` from `users.get`).
- `nextInstantCandidates`: status `choosing` or `no_match` (→ `choosing` via `reopen`); `excludedIds += skipped`; new round; when the new round is empty and the request is committed (`committedAt`; = paid from #202 on) → `no_match` (spec §2.1.9), uncommitted → stays `choosing` with no candidates.
- `inviteInstant` (#140): `photographerIds` 1–5, all in the current `candidates` else `not_eligible`; `excludedIds += skipped`. Uncommitted: recompute `quoteInstantPrice` with the current config; when it differs from the stored `amountVnd`, save the new `amountVnd`/`earningVnd` and return `{kind: 'price_changed', amountVnd}` (a thrown error would roll the save back); else `expectedAmountVnd !== amountVnd` → the same result without a write; else `sendOffers` now and return `{kind: 'invited', invited, unavailable}` (**#140 decision: no payment step; offers go out right after the first invite**). Committed: `sendOffers` now. Task 11 (#202) replaces the uncommitted branch after the price check with the payment step (`pending_payment`, `{kind: 'payment', …}`), so the offers wait for `paid`.
- `sendOffers(tx, request, ids, now)` (internal): for each id read presence + `orderBlocker(deps, {customerId, providerId: id})` (read before the transaction; #198's gate with its `BlockGate` from `deps.blocks`): offer only when `presenceFresh`, `activeRequestId == null`, `priceListVersion == config`, `livePendingOffers.length < 3`, `orderBlocker` null; else row `unavailable` (not excluded). Offer doc carries `areaLabel`, `distanceKm`, `etaMinutes`, `earningVnd`, `invitedCount` = number offered, never `meetPoint`. Presence gets the pending entry and `reliability.offers++`. Request: `searching`, `offers` rows, `invitedTotal += n`, `roundsWithInvites++`, `searchDeadlineAt = now + 10 min`, `roundEnded: false`, `lastActivityAt: now`, `committedAt ??= now`. All unavailable → `choosing`, `roundEnded: true` (spec §10 row 2). After commit, `push.send` one `offerPushMessage` per offer.
- → Task 11 (#202): `InstantPaymentSettler.settle(paymentId, transfer)` (Decision 5; one `InstantStore` transaction, reads first): `applyTransfer` (#129: `payment_received` ledger, `already_applied` → no change); `paid` and the request still `pending_payment` with this `paymentId` → `paidAt`, `sendOffers(pendingInviteIds)`; `paid` otherwise (cancelled, payment window passed, another payment) → `applyRefundToPayment(100%, 'late_payment')`; excess → `transferRefund`; refunds dispatched after commit through `dispatchRefund` (`sendRefundOnce` + a transaction with `mergeRefundOutcome`, mirroring `refundId`/`refundStatus` on the request). `expire` = `expireUnpaid` in the same store; `statusOf(payment)` = the status of the request `payment.subjectId`.
- → Task 11 (#202): `checkInstantPayment`: payer only; `checkSubjectPayments(settlement, createdPaymentsOfRequest)`. The fake confirmation is V1's `confirmFakePayment({paymentId})`, which reaches `InstantPaymentSettler` through `SettlementDeps.subjects`.
- `answerInstantOffer`: see sample below; decline → offer `declined`, row `declined`, `excludedIds += uid`, presence pending entry removed and `reliability.declined++`; round end when no pending row is left.
- `updateInstantJob`: caller is the request's photographer; `start_route` (from `assigned`, needs `location`; creates the track doc `active: true`), `arrive` (from `en_route`; `distanceKm(location, meetPoint) ≤ 0.2` or (`force` and `location.accuracyM > 100`, stored in `forcedArrivalAccuracyM`) else `not_eligible`; deletes the track), `start` (`arrived` → `in_progress`, `shootEndsAt = now + durationMin`), `finish` (`in_progress` → `finished`), `no_show` (`quoteInstantNoShow`, request `cancelRule: 'no_show'`, `refundPercent`, `feeVnd` (0 while unpaid, Decision 9), status `no_show_customer` (the 50% refund and `releaseAfter = now + 24 h` on the payment → Task 11 (#202)), presence free, `reliability` untouched for the photographer, `noShow` counted on the request only).
- `cancelInstantRequest`: `quoteInstantCancel` for the caller's role; `dryRun` returns the quote without writing; a real cancel stores `cancelRule`, `refundPercent`, `feeVnd`, `cancelledAt`, `cancelledBy` on the request (the customer's closed view and the photographer's fee line read them). Customer: → `cancelled_by_customer` (#140: always the `unpaid` rule, zero money; Task 11 (#202) adds: a `created` payment is left as is and a later confirmation refunds it; paid → `applyRefundToPayment(percent)`; fee > 0 → payment `releaseAfter = now + 24 h` and payee stays the photographer); presence of an assigned photographer freed (rule `photographer_late` also does `reliability.late++` on it); offers withdrawn. Photographer: refund nothing yet (money stays held), request → `choosing` via `photographer_cancel` (`excludedIds += uid`, photographer fields cleared, contact copy (if any) and track deleted, `payeeId = ''` from Task 11 (#202), `searchDeadlineAt = now + 10 min`, `roundEnded: true`), presence freed, `reliability.cancelled++`.
- `confirmInstantComplete`: `in_progress` or `finished` → `completed` (`completedAt`, `finishedAt ??= now`), presence freed (payment `releaseAfter = completedAt + 24 h` → Task 11 (#202)), `reliability.accepted` unchanged.
- `tickInstantRequest`: allowed for the customer, the assigned photographer, or a photographer with an offer row on the request; settles and returns the status.
- `runInstantSweep`: `store.findDue(now, 100)` → settle each in its own transaction (errors logged by the caller, one bad request does not stop the batch). No refund re-send here: V2's re-send sends every pending refund again under the same id.
- `setLiveShutter`: reasons computed in this order: gate (`not_accepting_orders`), `phones.hasPhone` (`phone_required`), presence `priceListVersion` equals config (`price_list_not_accepted`), `location` inside a city (`outside_service_area`; only when `online: true` with a location). `dryRun` or any reason → nothing written. Online: presence upsert with profile snapshot (`profiles.snapshot`), position, `geohash5/4`, `heartbeatAt: now`, `cityId`. Offline: `online: false` (pending offers stay valid until they expire; an active job is untouched).
- `saveInstantSettings`: `acceptPriceListVersion` must equal the config version else `price_changed`; `helpReady` bool; creates the presence (offline) when missing.
- `instantNotices(before, after)` (pure decider; recipients, copy, targets and dedupe keys are #138's hooks): `assigned` → `{hook: 'assigned'}`; `roundEnded` false → true → `{hook: 'round_ended', round}`; → `no_match` → `{hook: 'no_match', round}`; → `arrived` → `{hook: 'arrived'}`; → `finished` → `{hook: 'finished'}`; → `cancelled_by_customer` after assignment → `{hook: 'cancelled', by: 'customer', photographerId, feeVnd}`; assigned → `choosing` with `cancelledBy: 'photographer'` → `{hook: 'cancelled', by: 'photographer', photographerId: before.photographerId, feeVnd: 0}`; each offer row `pending` → `expired` → `{hook: 'missed', photographerId, offerId}`.
- `syncInstantChat`: on `photographerId` null → id: create or upgrade the pair chat (`kind: 'booking'`, `bookingId: null`, `readOnlyAt: null`); on end with a photographer and `bookingId == null`: `readOnlyAt = now + 7 days`.

Sample (the accept transaction; reads first, then writes):
```ts
async function acceptOffer(deps: InstantDeps, uid: string, offerId: string): Promise<{ requestId: string }> {
  // plain reads, outside the transaction: #198's orderBlocker (provider gate + deps.blocks, customer ↔ uid)
  const pre = await deps.store.runTransaction(async (tx) => tx.getOffer(uid, offerId));
  const customerId = pre === null ? null : (await deps.store.runTransaction((tx) => tx.getRequest(pre.requestId)))?.customerId ?? null;
  const contact = customerId === null ? null : await deps.contacts.get(customerId);
  const blocker = customerId === null ? null : await orderBlocker(deps, { customerId, providerId: uid });
  const box: { push: PushMessage[] } = { push: [] };
  const res = await deps.store.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const offer = await tx.getOffer(uid, offerId);
    if (offer === null) throw new DomainError('not_found');
    const raw = await tx.getRequest(offer.requestId);
    if (raw === null) throw new DomainError('not_found');
    const presence = await tx.getPresence(uid);
    const others = presence === null ? [] : livePendingOffers(presence, now).filter((p) => p.requestId !== raw.id);
    const otherRequests = await Promise.all(others.map((p) => tx.getRequest(p.requestId)));
    const payment = raw.paymentId === null ? null : await tx.getPayment(raw.paymentId);
    // ---- decisions ----
    const settled = settleInstant(raw, now).request;
    if (offer.outcome !== 'pending' || offer.expiresAt.getTime() <= now.getTime()) throw new DomainError('offer_expired');
    if (settled.status !== 'searching' || presence?.activeRequestId) throw new DomainError('already_assigned');
    if (blocker !== null) throw new DomainError(blocker); // 'not_accepting_orders' | 'blocked'
    // ---- writes ----
    // request → assigned, round fields emptied (Decision 15), chatId = chatIdFor(customer, uid),
    //   freeCancelUntil = now + 2 min, lateDeadlineAt = now + offer.etaMinutes + 15 min, etaMinutes = offer.etaMinutes
    // this offer accepted; every other pending row of this request withdrawn (+ their offer docs)
    // the winner's other pending offers withdrawn; their requests' rows updated, round end when none pending
    // presence: activeRequestId, pendingOffers = [], reliability.accepted++
    // contact copy written from `contact` (when isVnE164) only if settled.paidAt !== null (Decision 22; never in #140)
    // Task 11 (#202): payment.payeeId = uid
    return { requestId: raw.id };
  });
  return res;
}
```
(The memory store and the Firestore adapter both require reads before writes inside a transaction; the gate and the customer contact are plain reads done before it. Keep the two small pre-reads or pass the request id from the offer listener; either way the transaction re-reads everything it decides on.)

- [ ] **Step 1: Contract check** (domain names; `notify`, `NotifyRequest`, `ChatTx.setChat`, `getContactLink` subject parsing); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `instant_requests.test.ts`: `create: refuses without phone (phone_required)`, `outside the boxes (outside_service_area)`, `when disabled (not_eligible)`, `a second active request (conflict)`; `create: locks the price and lists ≤ 5 candidates, nearest first`; `next round excludes skipped and offers no one twice`; `committed request with no candidates left goes no_match`; `uncommitted request with no candidates stays choosing`; `first invite sends the offers at once to the chosen people only, each with a 60 s expiry and a push, and sets committedAt (#140: no payment, no pending_payment)`; `price change returns price_changed with the new amount saved and nothing sent`; `a stale expectedAmountVnd returns price_changed without a write`; `an id outside the round is not_eligible`; `a blocked invitee (#198's BlockGate through orderBlocker) is unavailable and not excluded`; `offer doc has no meet point` (keys of the offer doc never include `meetPoint`/`lat`/`lng`); `a chosen photographer who went busy is unavailable and not excluded`; `revoked photographer is unavailable at invite`; `a photographer with 3 live pending offers is unavailable`; `all unavailable on the first invite: choosing with roundEnded and committedAt set`; `later round invites send at once`; `search window ends in no_match`; `customer cancel of an unpaid request records rule unpaid, zero money, frees an assigned photographer and withdraws the offers`; `a customer cancel after lateDeadlineAt before arrival still counts reliability.late`; `cancel dryRun writes nothing`; `cancel in_progress is conflict`; `confirm complete frees the photographer`; `tick by a stranger is permission_denied`; `sweep settles a forgotten round` (two expired offers, clock + 61 s → `choosing`, `roundEnded`, rows `expired`, offer docs `expired`); `sweep turns a 10-minute-old search into no_match`; `no use case writes a payment, refund or ledger entry` (memory maps stay empty through a full flow); `abandoned uncommitted request after 30 minutes`. Moved to Task 11 (#202): every payment, transfer, refund, `releaseAfter` and `late_payment` case.
  - `instant_jobs.test.ts`: `setLiveShutter dryRun lists reasons in order and writes nothing`; `online needs a location (invalid_argument)`; `online outside the boxes is refused with outside_service_area`; `online writes geohash5/4, heartbeat and a profile snapshot`; `offline keeps an active job`; `saveInstantSettings with an old version is price_changed`; `accept: assigned, round emptied, chatId set, no contact copy while the request is unpaid` (and `assignment empties the round`); `two accepts on one request: one winner` (run both with `Promise.all`; the other gets `already_assigned`; loser presence `activeRequestId` null); `one photographer, two requests: one accept` (second → `already_assigned`, its row `withdrawn`, the other request's round ends); `accept after expiry is offer_expired and the row reads expired`; `revoked photographer cannot accept (not_accepting_orders)`; `a photographer blocked by the customer cannot accept (blocked)`; `decline of the last pending row ends the round`; `start_route creates the track; arrive within 200 m deletes it`; `arrive at 350 m is not_eligible; with force and accuracy 150 m it passes and stores the accuracy`; `force with good accuracy is still not_eligible`; `start sets shootEndsAt from the package`; `no_show before 15 minutes is deadline_passed; after, no_show_customer with rule no_show recorded (zero money while unpaid)`; `photographer cancel returns the request to choosing, excludes them, clears contact and track, resets the 10-minute window`; `the world's deps carry a BlockGate (blocks is set)`; `an unrelated photographer cannot update the job (permission_denied)`.
  - `instant_notices.test.ts`: one test per notice of the list above (the decider returns the right `InstantNotice`; through #138's hooks with `createNotifyWorld`: recipient, type, target and the Server copy strings); `no notice for a write that changes nothing visible (heartbeat-like version bump)`; `offerPushMessage text and data {type: 'instant_offer', target: '/work/instant/offer/{id}'}, channel default`; `syncInstantChat creates a booking-kind chat on assignment, upgrades an inquiry chat, closes it 7 days after the end`; `instantTrackShouldGo when leaving en_route`.
  - `get_contact_link.test.ts`: `instant_request: unlocked for the customer while a photographer is assigned and the request is paid` (fixture with `paidAt`); `locked while unpaid even when assigned (contact_locked; every #140 request)`; `locked before assignment (contact_locked)`; `unlocked 7 days after completion, locked on day 8`; `another user is permission_denied`; `parse refuses two subject keys`.
- [ ] **Step 3:** `npm test` → fail.
- [ ] **Step 4: Implement** per the behaviour list; export from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): Chụp ngay use cases — rounds, first-accept-wins, jobs, presence, notices [#140]`.

### Task 4 (#140): Functions — adapters, callables, clock step, seed and CLI

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/instant_firestore.ts` (`FirestoreInstantStore`, `FirestorePresenceDirectory`, `instantRequestToFirestore`/`FromFirestore`, `instantOfferTo/From`, `instantPresenceTo/From`), `src/infra/instant_readers.ts` (`FirestoreInstantConfigReader` with a 60 s in-memory cache, `FirestorePhotographerPhoneReader`, `FirestoreInstantProfileReader`), `src/infra/live_instant.ts` (`liveInstantDeps()`), `src/callables/instant.ts` (10 handlers + `instantCallerOf`; `handleCheckInstantPayment` is Task 11's), `tools/instant.ts`; tests `test/unit/instant_callables.test.ts`, `test/unit/instant_firestore.test.ts`, `test/unit/instant_cli.test.ts`, `test/integration/instant.test.ts` (written, not run).
- Modify: `src/index.ts` (exports), `src/callables/errors.ts` (four codes), `src/scheduled/booking_clock.ts` (+ `runInstantSweep` step), `seed/fixtures.ts` + `seed/README.md` (a row for `instant_config/current` and the `npm run instant` usage), `package.json` (`"instant": "tsx tools/instant.ts"`), `test/unit/errors.test.ts`, `test/unit/seed_fixtures.test.ts`. (`booking_firestore.ts` `subjectType` whitelist and `live_payments.ts` settler registration → Task 11 (#202).)

**Interfaces:**
- Consumes: Task 3 use cases and ports.
- Produces: `export async function handle<Name>(request: InstantCallableInput, deps: InstantDeps)` for each callable (`handleCreateInstantRequest`, `handleNextInstantCandidates`, `handleInviteInstant` (#140: first refuses with `HttpsError('failed-precondition', 'not_eligible', {code: 'not_eligible'})` unless `fakePaymentsAllowed()` — the free dispatch runs only on the dev project or a `demo-*` emulator; Task 11 removes this guard), `handleCancelInstantRequest`, `handleConfirmInstantComplete`, `handleTickInstantRequest`, `handleSetLiveShutter`, `handleSaveInstantSettings`, `handleAnswerInstantOffer`, `handleUpdateInstantJob`), each `catch (e) { throw toHttpsError(e) }`, unauthenticated → `HttpsError('unauthenticated', 'permission_denied', {code})`. Exports in `index.ts` with the options of the Contract. `handleBookingClock` gains the step `instantSweep` (`runInstantSweep`) at the end of its step list in its own try (a failure is logged, not rethrown, so booking sweeps are not retried twice); its dependency goes into the optional `BookingClockExtras.instant?: InstantDeps` (default `liveInstantDeps()`), per the clock rule (restated in `2026-10-08-s04-reconciliation.md`) (no existing parameter changes; create `BookingClockExtras` if absent).
- `liveInstantDeps()` sets `providers: new FirestoreProviderOrderGate()` and `blocks: liveBlockGate()` (#198, `src/infra/live_safety.ts`) explicitly; without `blocks`, `orderBlocker` would skip blocks silently (`OrderGateDeps.blocks` is optional).
- `FirestorePresenceDirectory.nearby({field, cells, limit})`: `collection('instant_presence').where('online', '==', true).where(field, 'in', cells).limit(limit)`.
- `FirestoreInstantStore.findDue(now, limit)`: `where('active', '==', true).where('nextDeadlineAt', '<=', Timestamp.fromDate(now)).orderBy('nextDeadlineAt').limit(limit)`.
- Transaction adapter: buffer writes, refuse reads after the first write (throw `Error('read after write')`), `findActiveRequestOfCustomer` = `fTx.get(query customerId == uid && active == true limit 1)`.
- Seed `instant_config/current`: `enabled: true`, `priceListVersion: 1`, `platformFeeBp: 0`, `instantArrivedCancelPhotographerPercent: 50`, packages `p30` (30, 15, 390000), `p60` (60, 30, 690000), `p120` (120, 60, 1190000); cities `hcm` "TP.HCM" (10.35, 106.36, 11.17, 107.03, 10000), `hn` "Hà Nội" (20.56, 105.28, 21.39, 106.02, 10000), `dn` "Đà Nẵng" (15.92, 107.82, 16.20, 108.33, 10000); areas = the twelve `builtInAreas` of `lib/data/location/area.dart` (names and centres copied).
- CLI `npm run instant -- offer --photographer <uid> [--customer seed-customer-lan] [--package p60] [--genre portrait]`: refuses unless the emulator env is set (`seed/local_guard`); reads the photographer's presence (must be online and fresh), creates a request for the customer 500 m north of it with meet point name "Điểm hẹn thử (CLI)", invites the photographer (#140: the offer goes out at once; Task 11 (#202) adds the fake payment confirmation through V1's `confirmFakePayment` before it), prints the request and offer ids. `npm run instant -- status <requestId>` prints status and offers.

- [ ] **Step 1: Contract check** of the Functions names in "Existing code"; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `instant_callables.test.ts` (memory deps from the domain world): `createInstantRequest maps phone_required to failed-precondition with details.code`; `outside_service_area maps to failed-precondition`; `unauthenticated calls are refused`; `inviteInstant returns invited rows`; `inviteInstant outside the dev project or a demo emulator is not_eligible` (#140 guard); `liveInstantDeps wires a BlockGate` (`liveInstantDeps().blocks` is defined); `answerInstantOffer offer_expired and already_assigned keep their codes`; `updateInstantJob passes force and location through`; `setLiveShutter returns reasons, not an error`.
  - `instant_firestore.test.ts`: round trips for request (every Timestamp, nested arrays, nulls), offer, presence; `request mapping never writes undefined`; `unknown status in a stored doc reads as not found` (defensive).
  - `errors.test.ts`: `no_match, offer_expired, already_assigned, outside_service_area map to failed-precondition`.
  - `seed_fixtures.test.ts`: `seed has a valid instant config` (`parseInstantConfig` accepts it).
  - `instant_cli.test.ts`: `refuses without emulator env`; `offer creates a request and one offer for an online photographer` (memory deps).
  - `test/integration/instant.test.ts` (written, not run): `five parallel accepts, one winner`; `fifty customers inviting the same photographer never exceed 3 live pending offers`; `full flow on the emulator without money: create → invite (offers at once) → accept → start_route → arrive → start → finish → confirm → completed, no payments document` (Task 11 extends it with the fake payment and the release).
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` → fail.
- [ ] **Step 4: Implement** adapters, readers (profile snapshot: `users/{uid}` `displayName`/`avatarUrl`, `photographers/{uid}` `verified`/`providerType`/`stats`/`specialties`, `posts` where `photographerId == uid` order `createdAt desc` limit 6, first image of the first three `kind == 'work'`), callables, clock step, seed, CLI.
- [ ] **Step 5:** `npm test && npm run build` green; `cd packages/domain && npm test` still green.
- [ ] **Step 6: Commit** `feat(functions): Chụp ngay callables, Firestore adapters, clock step, seed config and CLI [#140]`.

### Task 5 (#140): Functions — trigger, rules, indexes, contact link, earnings subject

**Files:**
- Create: `app_flutter/firebase/functions/src/triggers/instant_request_write.ts`; tests `test/unit/instant_request_write.test.ts`.
- Modify: `src/index.ts` (`onInstantRequestWrite`), `src/infra/live.ts` (`liveContactDeps().instantRequests` reader), `test/unit/get_contact_link_handler.test.ts`; (`earnings_firestore.ts` instant subject → Task 11 (#202)); `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (new `describe('instant')`).

**Interfaces:**
- Produces: `export async function handleInstantRequestWrite(input: {requestId: string; before: InstantRequest | null; after: InstantRequest | null}, deps: {notify: NotifyDeps; chat: ChatDeps; deleteTrack(id: string): Promise<void>}): Promise<{notices: number; chat: string; trackDeleted: boolean}>` — runs `instantNotices` → the matching #138 hook for each (`notifyInstantAssigned`, …; errors per notice logged, not rethrown; #138's dedupe keys make a replayed event send nothing twice), `syncInstantChat` (if it writes a `Chat` field missing from #131's shared `chat round-trips every field` fixture, extend that test), and deletes the track when `instantTrackShouldGo`. Event older than 1 hour → no-op (same expiry policy as `handlePhotographerEvent`).
- Rules (sample; keep the catch-all deny last):
  ```
  match /instant_config/{docId} { allow read: if signedIn(); allow write: if false; }

  match /instant_presence/{uid} {
    allow get: if isOwner(uid);
    allow update: if isOwner(uid)
      && resource.data.online == true
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['lat', 'lng', 'accuracyM', 'geohash5', 'geohash4', 'heartbeatAt'])
      && request.resource.data.heartbeatAt == request.time
      && request.time > resource.data.heartbeatAt + duration.value(60, 's')
      && request.resource.data.lat is number && request.resource.data.lat >= -90 && request.resource.data.lat <= 90
      && request.resource.data.lng is number && request.resource.data.lng >= -180 && request.resource.data.lng <= 180
      && request.resource.data.accuracyM is number && request.resource.data.accuracyM >= 0
      && request.resource.data.geohash5 is string && request.resource.data.geohash5.size() == 5
      && request.resource.data.geohash4 == request.resource.data.geohash5[0:4];
    allow create, delete, list: if false;
  }

  match /instant_requests/{requestId} {
    allow read: if signedIn()
      && (resource.data.customerId == request.auth.uid || resource.data.photographerId == request.auth.uid);
    allow write: if false;
    match /private/{docId} {
      allow read: if signedIn() && docId == 'contact'
        && get(/databases/$(database)/documents/instant_requests/$(requestId)).data.photographerId == request.auth.uid
        && get(/databases/$(database)/documents/instant_requests/$(requestId)).data.active == true;
      allow write: if false;
    }
  }

  match /instant_offers/{uid}/offers/{offerId} { allow read: if isOwner(uid); allow write: if false; }

  match /instant_tracks/{requestId} {
    allow read: if signedIn()
      && (resource.data.customerId == request.auth.uid || resource.data.photographerId == request.auth.uid);
    allow update: if signedIn()
      && resource.data.photographerId == request.auth.uid
      && resource.data.active == true
      && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lat', 'lng', 'accuracyM', 'heading', 'at'])
      && request.resource.data.at == request.time
      && request.time > resource.data.at + duration.value(15, 's')
      && request.resource.data.lat is number && request.resource.data.lat >= -90 && request.resource.data.lat <= 90
      && request.resource.data.lng is number && request.resource.data.lng >= -180 && request.resource.data.lng <= 180
      && request.resource.data.accuracyM is number
      && (request.resource.data.heading == null || request.resource.data.heading is number);
    allow create, delete: if false;
  }
  ```
  (List queries on `instant_requests` must filter by `customerId == uid` or `photographerId == uid`; the rule above proves both.)
- Indexes: the five of the Contract.

- [ ] **Step 1: Contract check** (rules helpers, `liveContactDeps`); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `instant_request_write.test.ts`: `assignment notifies the customer and creates the chat`; `trigger notifies missed offers once` (before/after with two rows pending → expired; replaying the same event yields the same dedupe keys); `leaving en_route deletes the track`; `a stale event (> 1 h) does nothing`; `a failing notice does not stop the others`.
  - `get_contact_link_handler.test.ts`: `instantRequestId subject reaches the instant reader`.
  - `rules.test.mjs` `describe('instant')` (written, not run): `signed-in user reads instant_config`; `nobody writes instant_config`; `owner reads own presence, others cannot`; `owner heartbeat with request.time passes`; `heartbeat within 60 s is denied`; `owner cannot switch online by writing`; `owner cannot write activeRequestId, pendingOffers, cityId or priceListVersion`; `heartbeat on an offline presence is denied`; `customer reads own request; assigned photographer reads it`; `an invited photographer cannot read the request`; `nobody writes a request`; `assigned photographer reads the contact copy while active`; `a cancelled photographer cannot read the contact copy` (request `photographerId` changed); `customer cannot read the contact copy` (it is the customer's own number; not needed); `owner reads own offers, another photographer cannot`; `both parties read the track, another user cannot`; `assigned photographer updates the track with request.time`; `track write within 15 s is denied`; `track write when inactive is denied`; `customer cannot write the track`.
- [ ] **Step 3:** `npm test` → fail.
- [ ] **Step 4: Implement** trigger (+ `index.ts` export `onInstantRequestWrite = onDocumentWritten({...TRIGGER_OPTIONS, document: 'instant_requests/{requestId}'}, …)`), contact reader, rules, indexes.
- [ ] **Step 5:** `npm test && npm run build` green. Ledger: rules tests and integration tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): Chụp ngay trigger, rules, indexes and contact link [#140]`.

### Task 6 (#140): App data — models, repository, Firestore adapter, providers

**Files:**
- Create: `app_flutter/lib/data/instant/instant_models.dart`, `instant_repository.dart`, `firestore_instant_mapping.dart`, `firestore_instant_repository.dart`, `instant_providers.dart`, `instant_geo.dart`; `test/support/fake_instant_repository.dart`; tests `test/data/instant/instant_mapping_test.dart`, `test/data/instant/firestore_instant_repository_test.dart`, `test/data/instant/instant_geo_test.dart`.
- Modify: `lib/data/contact/contact_link_repository.dart` (`ContactSubjectType.instantRequest`, `ContactSubject.instantRequest(id)`, request key `instantRequestId`) and its test.

**Interfaces:** Produces the "App data" Contract block. `FirestoreInstantRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions, required String? uid})`; callables via a private `_call(name, data)` copied from `callEventFunction` (throws `InstantError(details.code)`, `network` on `unavailable`/`deadline-exceeded`). `heartbeat` writes `{lat, lng, accuracyM, geohash5: encodeGeohash(lat, lng, precision: 5), geohash4: …[0..4], heartbeatAt: FieldValue.serverTimestamp()}` with `update`; `shareTrack` writes `{lat, lng, accuracyM, heading, at: FieldValue.serverTimestamp()}`. `watchPendingOffers` = `instant_offers/{uid}/offers where outcome == 'pending'`, sorted by `expiresAt` client-side. `myActiveRequestId` = one `get` of `instant_requests where customerId == uid && active == true limit 1`. `watchMyActiveJob` = listener on `photographerId == uid && active == true limit 1`. `FakeInstantRepository` (test support): in-memory, controllable streams (`emitRequest`, `emitOffers`, `emitPresence`, `emitTrack`), records every call (`calls` list of `(name, args)`), configurable errors per method (`failNext(method, code)`).

- [ ] **Step 1: Contract check** (app side names in "Existing code"); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `instant_mapping_test.dart`: `request maps every field, Timestamps to UTC`; `unknown status maps to null and the stream yields null`; `offer rows with unknown outcome read as expired`; `missing optional fields default (no candidates, no photographer)`; `offer maps areaLabel, distanceKm, earningVnd`; `presence fresh is false 30 minutes after heartbeat`; `config earningOf is amount − round(amount × platformFeeBp / 10000)`; `config reads instantArrivedCancelPhotographerPercent`.
  - `firestore_instant_repository_test.dart` (`fake_cloud_firestore` + a fake functions caller injected through a small `InstantCallable` typedef): `createRequest sends the exact payload`; `invite parses invited and price_changed results and sends no payMethod`; `a FirebaseFunctionsException with details.code becomes InstantError(code)`; `unavailable becomes InstantError('network')`; `heartbeat writes only the six position fields`; `shareTrack writes only lat/lng/accuracyM/heading/at`; `watchPendingOffers sorts by expiresAt`; `myActiveRequestId returns null when none`.
  - `instant_geo_test.dart`: `estimateEtaMinutes matches the domain table (0→1, 1.2→6, 2.1→9, 10→42)`.
  - contact test: `instantRequest subject sends instantRequestId`.
- [ ] **Step 3:** Run `flutter test --no-pub --timeout 60s test/data/instant` → fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/data/instant` and `… test/data/contact` green.
- [ ] **Step 6: Commit** `feat(data): Chụp ngay repository, models and Firestore adapter [#140]`.

### Task 7 (#140): S14.01 Live Shutter, S06.01 card, heartbeat, routes

**Files:**
- Create: `app_flutter/lib/features/instant_work/live_shutter_screen.dart`, `live_shutter_controller.dart`, `live_shutter_heartbeat.dart`, `live_shutter_card.dart`; tests `test/features/instant_work/live_shutter_screen_test.dart`, `live_shutter_controller_test.dart`, `live_shutter_heartbeat_test.dart`, `live_shutter_card_test.dart`; `test/support/instant_work_world.dart`.
- Modify: `lib/app/router.dart` (`/work/instant`), `lib/features/work/work_screen.dart` (card on top, behind `instantEnabledProvider`), `lib/features/shell/tab_shell.dart` (mount `LiveShutterHeartbeat` for photographers), `lib/l10n/app_vi.arb` (S14.01 + card + shared `instant*` keys), `test/features/work/work_screen_test.dart` (flag off: no card).

**Interfaces:**
- Consumes: Task 6 providers; `LocationRepository`; `maybeAskForNotifications(context, ref, const PhotographerPrimer())`.
- Produces:
  ```dart
  class LiveShutterView { final LiveShutterState? presence; final InstantConfig config; final List<LiveShutterReason> reasons; final bool busy; }
  class LiveShutterController extends AsyncNotifier<LiveShutterView> {
    Future<void> setOnline(bool on);     // on: permission → currentPosition → setLiveShutter(online, location) → primer
    Future<void> setHelpReady(bool on);
    Future<void> acceptPriceList();
  }
  final liveShutterControllerProvider = AsyncNotifierProvider.autoDispose<LiveShutterController, LiveShutterView>(…);
  /// Keeps the heartbeat while a photographer is online and the app is foregrounded: a low-accuracy fix
  /// (`currentApproxLocation`) every 60 s; writes at once on resume, then when the position moved more than
  /// 300 m or 5 minutes passed since the last write; never two writes closer than 60 s (the rules refuse them).
  class LiveShutterHeartbeat extends ConsumerStatefulWidget { const LiveShutterHeartbeat({super.key, required this.child,
    this.sample = const Duration(seconds: 60), this.maxSilence = const Duration(minutes: 5)}); }
  class LiveShutterCard extends ConsumerWidget {} // S06.01 top card
  ```
- **Backend wiring:** `instantConfigProvider` (`get instant_config/current`), `livePresenceProvider` (owner listener), `setLiveShutter(dryRun: true)` on open for reasons, `setLiveShutter(online)`, `saveInstantSettings`, direct heartbeat write (rules Task 5); `myActiveInstantJobProvider` for the card.
- **Mock parity:** `#S14.01` (bar "Chụp ngay" with back; `card hi` Live Shutter + switch (`Switch` with semantics label "Live Shutter"); card "Sẵn sàng hỗ trợ" + switch; section header "Bảng giá gói" + trailing "Bản {n} · đã đồng ý"; three `AppOptionTile`-like rows "30 phút · 15 ảnh" / "Khách trả 390K" / "Bạn nhận 390K" (short money `formatMoney` K/M form as in S06.05); note; footer outline "Tắt khi xong việc hôm nay" only while online); `#S14.01-terms` (switch disabled, primary "Đồng ý bảng giá"); `#S14.01-locked` (reason rows with actions: phone → `/profile/phone?returnTo=/work/instant`, location → `openSettings`, not accepting → no action); `#S06.01-instant` (card above "Hôm nay", job card when active).

- [ ] **Step 1: Contract check** (router, `WorkScreen` layout, `TabShell`, `PhotographerPrimer`, `AppOptionTile`); ledger differences.
- [ ] **Step 2: Failing tests** (`FakeInstantRepository`, `FakeLocationRepository`, fixed `clockProvider`):
  - screen: `shows the price table with customer and photographer amounts and "Bản 1 · đã đồng ý"`; `not accepted: switch disabled, primary "Đồng ý bảng giá" calls saveSettings(acceptPriceListVersion: 1)`; `locked: lists reasons in order with "Thêm số" opening /profile/phone?returnTo=/work/instant`; `location denied shows "Cho phép dùng vị trí để nhận lời mời ở gần" and "Mở cài đặt"`; `turning on asks permission, takes a fix and calls setLiveShutter(online: true, location)`; `turning on with a server reason shows it and leaves the switch off`; `footer "Tắt khi xong việc hôm nay" only while online and turns it off`; `helpReady switch calls saveSettings(helpReady: true)`; `fits 320dp at 1.3× text, light and dark` (no overflow).
  - controller: `primer is asked once after the first successful turn-on`; `network error keeps the previous state and reports instantErrorNetwork`.
  - heartbeat: `writes on resume when online`; `writes after 5 minutes, not before` (bounded pumps); `writes on a 350 m move after 70 s, not on a 350 m move after 30 s`; `stops when offline or when the widget is disposed (no pending timers)`.
  - card: `off/on/job texts`; `tap opens /work/instant or /work/instant/:id`; `hidden when instantEnabledProvider is false`.
- [ ] **Step 3:** Run `flutter test --no-pub --timeout 60s test/features/instant_work` → fail.
- [ ] **Step 4: Implement**; arb keys + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantAvailability, label: 'terms' | 'locked' | null)`.
- [ ] **Step 5:** `flutter analyze` clean; run `test/features/instant_work`, `test/features/work`, `test/features/shell` one at a time, green.
- [ ] **Step 6: Commit** `feat(instant): S14.01 Live Shutter, S06.01 card and presence heartbeat [#140]`.

### Task 8 (#140): S14.02 offers, `OfferStack`, `MatchOverlay`, offer listener and push targets

**Files:**
- Create: `app_flutter/lib/core/widgets/offer_stack.dart`, `lib/core/widgets/match_overlay.dart` (export both from `core.dart`), `lib/features/instant_work/offer_screen.dart`, `offer_controller.dart`, `instant_offer_listener.dart`; tests `test/core/widgets/offer_stack_test.dart`, `test/core/widgets/match_overlay_test.dart`, `test/features/instant_work/offer_screen_test.dart`, `instant_offer_listener_test.dart`.
- Modify: `lib/app/router.dart` (`/work/instant/offer/:offerId`), `lib/features/shell/tab_shell.dart` (mount `InstantOfferListener` for photographers), `lib/l10n/app_vi.arb`. (Targets `/work/instant`, `/work/instant/:id`, `/work/instant/offer/:id` and the visuals of the seven instant types are #138's: its App contract allowlists and draws them; if #138 has not merged, add exactly its lines.)

**Interfaces:**
- Produces:
  ```dart
  /// Up to three offer cards: the first full, the next two as edges peeking above it (mock S14.02 `.ostk`).
  class OfferStack extends StatelessWidget { const OfferStack({super.key, required this.offers}); final List<Widget> offers; }
  /// S13.04: one continuous line draws a camera (1.8 s), the lens flashes, both avatars land in the lens;
  /// continues by itself after ~3 s; "Tiếp tục" always; tap skips to the last frame; reduced motion = last frame, no haptic.
  class MatchOverlay extends StatefulWidget {
    const MatchOverlay({super.key, required this.name, required this.body, this.myAvatarUrl, this.theirAvatarUrl,
      required this.onContinue, this.autoContinueAfter = const Duration(seconds: 3)});
  }
  class OfferController extends AutoDisposeNotifier<OfferUiState> { Future<void> accept(String offerId); Future<void> decline(String offerId); }
  /// While a photographer is online and the app is foregrounded, a new pending offer opens S14.02 unless it is already open.
  class InstantOfferListener extends ConsumerStatefulWidget { const InstantOfferListener({super.key, required this.child}); }
  ```
- `MatchOverlay` path (`CustomPainter` + `PathMetric.extractPath` by progress; stroke `onSurface` width 4 in a 420×250 box; wash `primary` 16%; flash ring `primary` 0.55→1.35; avatars 40dp land with a light spring, 100 ms apart; `HapticFeedback.lightImpact` at the flash; `Semantics(liveRegion: true, label: matchTitle)`): copy the camera path from the mock `.mcam` svg. The `Timer` for auto-continue is cancelled in `dispose`.
- **Backend wiring:** `pendingOffersProvider` (listener on own offers), `answerInstantOffer` callable; push `type: 'instant_offer'` opens `/work/instant/offer/{id}` through the existing push-open handler (allowlist added).
- **Mock parity:** `#S14.02`: bar "Lời mời chụp ngay" + subtitle "{n} lời mời đang chờ"; `CountdownRing` 60 s with number + "giây" (ring and number, not colour only); earning "552.000₫" large + "Bạn nhận · Chân dung 1 giờ · 30 ảnh"; `OfferStack`; card with `location_on` icon, area label, distance line, "Khách đã chọn bạn trong **3** người. Ai nhận trước sẽ được việc.", quoted note; footer outline "Từ chối" + primary "Nhận việc" (height ≥ 56dp). `#S13.04-provider` for the overlay.

- [ ] **Step 1: Contract check** (`CountdownRing` API and unit text, push-open handler, `TabShell`); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `offer_stack_test.dart`: `shows one full card and two edges for three offers`; `one offer shows no edges`; `more than three shows three`.
  - `match_overlay_test.dart`: `reduced motion shows the final frame with name and body at once`; `"Tiếp tục" calls onContinue once`; `auto-continues after 3 s` (pump 3 s); `tap skips to the last frame`; `no timer left after dispose`; `semantics live region reads "Đã match với Lan Anh"`.
  - `offer_screen_test.dart`: `top card is the routed offer; count line reads "3 lời mời đang chờ"`; `countdown shows seconds from expiresAt with the injected clock`; `card shows area, "2,1 km · khoảng 8 phút · địa chỉ hiện khi bạn nhận" and never an exact address`; `accept → overlay → /work/instant/{requestId}`; `already_assigned shows "Khách đã chọn được người khác" and drops the card`; `offer_expired shows "Lời mời đã hết hạn" and drops the card`; `not_accepting_orders shows "Bạn chưa nhận đơn được lúc này"`; `decline calls answerOffer(accept: false) and shows the next card`; `last card gone pops to /work/instant`; `a card whose countdown reaches 0 disappears`; `Nhận việc is at least 56dp tall`; `fits 320dp at 1.3× text`.
  - `instant_offer_listener_test.dart`: `a new offer opens /work/instant/offer/{id}`; `does nothing when S14.02 is already open`; `does nothing when the photographer is offline`.
- [ ] **Step 3:** Run `test/core/widgets` (the two files), `test/features/instant_work` one at a time → fail.
- [ ] **Step 4: Implement**; arb keys + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantOffer)`, overlay `ScreenCode(ScreenCodes.instantMatched, label: 'provider')`.
- [ ] **Step 5:** `flutter analyze` clean; the same folders green one at a time.
- [ ] **Step 6: Commit** `feat(instant): S14.02 offer stack, S13.04 match overlay and offer push targets [#140]`.

### Task 9 (#140): S14.03 job screen, `MapPreview`, route sharing, S13.08 provider sheet

**Files:**
- Create: `app_flutter/lib/core/widgets/map_preview.dart` (export from `core.dart`), `lib/features/instant_work/instant_job_screen.dart`, `instant_job_controller.dart`, `route_tracker.dart`, `provider_cancel_sheet.dart`; tests `test/core/widgets/map_preview_test.dart`, `test/features/instant_work/instant_job_screen_test.dart`, `route_tracker_test.dart`, `provider_cancel_sheet_test.dart`.
- Modify: `design-system/tokens.json` (`semantic.color` and `dark.semantic.color`: `map-bg`, `map-block`, `map-road`, `map-water`, `map-park`, `map-self` with the mock values: dark `#1A1C24 #22252F #3A3E4C #16324A #1E3328 #3D63FF`, light `#ECE8E1 #E2DDD4 #FFFFFF #BFD9EA #CFE3C8 #3D63FF`), regenerate `lib/core/theme/tokens.g.dart` with `dart run tool/gen_tokens.dart`; `lib/app/router.dart` (`/work/instant/:id`), `lib/l10n/app_vi.arb`. (The S06.05 earnings row for an `instant_request` payment → Task 11 (#202).)

**Interfaces:**
- Produces:
  ```dart
  class MapPin { const MapPin({required this.lat, required this.lng, required this.label, this.self = false}); }
  /// Schematic map (mock `.map`): decorative blocks/roads/water/park, labelled pins placed by an
  /// equirectangular projection of [pins] (padding 20%, minimum span 400 m), a dotted route between
  /// the first two pins when [route], and a "Về vị trí của tôi" button when [onRecenter] is set.
  class MapPreview extends StatelessWidget {
    const MapPreview({super.key, required this.pins, this.height = 250, this.route = false, this.onRecenter, this.borderRadius});
  }
  /// Fix every 15 s while en route and the screen is visible; writes when moved ≥ 25 m or 60 s passed.
  class RouteTracker { RouteTracker({required LocationRepository location, required InstantRepository repo, required String requestId,
    required DateTime Function() now, Duration every = const Duration(seconds: 15)}); void start(); void stop(); }
  Future<void> showProviderCancelSheet(BuildContext context, WidgetRef ref, {required String requestId});
  ```
  Projection (the easy-to-get-wrong part):
  ```dart
  Offset project(MapPin p, Rect box, ({double minLat, double maxLat, double minLng, double maxLng}) b, double cosLat) {
    final w = (b.maxLng - b.minLng) * cosLat, h = b.maxLat - b.minLat;   // degrees, x scaled by cos(latitude)
    final scale = math.min(box.width / w, box.height / h);
    final cx = box.center.dx, cy = box.center.dy;
    final mx = (b.minLng + b.maxLng) / 2, my = (b.minLat + b.maxLat) / 2;
    return Offset(cx + (p.lng - mx) * cosLat * scale, cy - (p.lat - my) * scale);
  }
  // bounds: pins' min/max, expanded so each side spans ≥ 0.0036° lat (~400 m), then padded by 20% of the span.
  ```
- **Backend wiring:** `instantRequestProvider(id)` (assigned photographer read), `instantCustomerContactProvider(id)` → `CustomerContactDial`, `updateInstantJob` (`start_route` on the first fix when `assigned`; `arrive`/`start`/`finish`/`no_show`), `shareTrack` (direct write, rules Task 5), `cancelInstantRequest(dryRun)` then confirm, `tickInstantRequest` when `CountdownRing` of the shoot reaches 0; chat icon → `/chat/{request.chatId}` (written by the server at assignment, so the app never rebuilds the id).
- **Mock parity:** `#S14.03` (bar "Đang đến" + "{customer} · {genre} {duration}", chat icon; `MapPreview` with pins "{customer}" and "Bạn" (self), route; card: meet point name bold, "{area} · {km} km", small outline "Chỉ đường" + `CustomerContactDial`; `StatusTimeline`: "Đã nhận · 15:21" done, "Đã đến (bật khi còn cách 200 m)" current, "Bắt đầu chụp · Hoàn thành" upcoming; note; text "Huỷ việc" (red); primary "Đã đến"), `#S14.03-arrived`, `#S14.03-shooting`, `#S14.03-done`, `#S13.08-provider`.
- Arrival button: enabled when the latest fix is ≤ 200 m from the meet point (client estimate with `haversineKm`), else shows `jobArriveFar` under it; when the fix accuracy > 100 m, the button opens the force sheet (`showConfirmSheet`, not danger) and calls `arrive` with `force: true`. "Chỉ đường" opens `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}` via `externalLauncherProvider`. Closed states: customer cancelled → `jobCancelledTitle` + fee line + outline "Về Công việc"; completed → `jobTitleCompleted` + outline "Về Công việc"; a request the photographer no longer owns (cancelled by them, now `choosing`) → pop to `/work/instant`.

- [ ] **Step 1: Contract check** (`StatusTimeline`, `CustomerContactDial`, `showConfirmSheet`, chat id helper, `tool/gen_tokens.dart`); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `map_preview_test.dart`: `two pins are placed inside the box with 20% padding and the self pin is blue (mapSelf)`; `one pin is centred`; `pins 5 m apart do not overlap the box edges (minimum span)`; `recenter button appears only with onRecenter and calls it`; `semantics reads "Bản đồ: Lan Anh, Bạn"`; `light and dark use the map tokens`.
  - `route_tracker_test.dart`: `first fix writes at once`; `a 10 m move after 15 s does not write; a 30 m move does`; `60 s without moving writes once`; `never writes twice within 15 s`; `stop cancels the timer` (bounded pumps via `FakeAsync`-free manual clock: the tracker takes `now` and a `Timer` factory; tests drive it).
  - `instant_job_screen_test.dart`: `assigned: the first fix calls updateJob(startRoute, location)`; `en route: map pins, area line, "Chỉ đường" opens the maps URL`; `Đã đến disabled at 350 m with "Còn cách 350 m. Tới gần hơn để bấm Đã đến."`; `Đã đến at 150 m calls arrive`; `poor accuracy opens "GPS chưa chính xác" and confirms with force`; `arrived: "Bắt đầu chụp" calls start; "Khách không có mặt (sau 12:40)" disabled until 15 minutes, then confirm sheet "Khách được hoàn 50%, bạn nhận 345.000₫." calls noShow`; `shooting: ring counts to shootEndsAt and "Hoàn thành" calls finish; reaching 0 calls tick`; `finished: note and "Về Công việc"`; `customer cancelled: "Khách đã huỷ yêu cầu" and "Bạn nhận 138.000₫ phí đi lại."`; `contact dial shows the customer's channels from the copy`; `location denied shows jobLocationNeeded and no tracker`; `no route sharing after arrival` (tracker stopped); `fits 320dp at 1.3× text`.
  - `provider_cancel_sheet_test.dart`: `shows "Huỷ việc chụp ngay?" and the 100% line; red "Huỷ việc" calls cancel(dryRun: false); "Giữ việc" closes`; `server conflict keeps the sheet open with instantErrorGeneric`.
- [ ] **Step 3:** Run `test/core/widgets/map_preview_test.dart` and `test/features/instant_work` → fail.
- [ ] **Step 4: Implement**; tokens regenerated (never edit `tokens.g.dart` by hand); arb + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantJob, label: 'arrived' | 'shooting' | 'done' | null)`, sheet `ScreenCode(ScreenCodes.instantCancel, label: 'provider')`.
- [ ] **Step 5:** `flutter analyze` clean; `test/core/widgets`, `test/features/instant_work` green one at a time.
- [ ] **Step 6: Commit** `feat(instant): S14.03 job screen with schematic map, route sharing and provider cancel [#140]`.

### Task 10 (#140): Specs, data model, docs and handover ledger

**Files:**
- Create: `docs/superpowers/specs/screens/instant.md` (S14.01–S14.03, S13.04, S13.08 provider: layout, states, copy keys, behaviour as built; a placeholder heading "S13 khách" for the companion plan), `docs/superpowers/handover/ledger-instant-dispatch-provider.md`.
- Modify: `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (a dated "Giai đoạn 1 (2026-10-07)" box at the top of §5: Functions + Firestore, lazy timers + clock step, presence 30 min, offer path, track cap, payout 100%, no Maps API; §9 cadence numbers), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S14.01–S14.03 "✅ đã làm (#140)", S13.04 and S13.08 "◐ phía thợ (#140)"), §3h.2 (rows for the five new notification types), `docs/superpowers/specs/data-model/domain-model.md` (`InstantRequest`, `InstantOffer`, `InstantPresence`, `NotificationType` list, `PaymentSubject`), `relational-schema.md` (Firestore mapping rows for `instant_*`; the `dispatch` DDL stays the phase-2 target), `docs/superpowers/specs/components/shared-components.md` (`OfferStack`, `MatchOverlay`, `MapPreview` as built), `services/dispatch/README.md` (one line: phase 1 runs on Functions, see this plan), the four stale plans (one "Superseded by …" line each), `app_flutter/firebase/functions/seed/README.md` (instant config, `npm run instant`).

- [ ] **Step 1:** Write the docs; Vietnamese specs, English code names; check every string in `screens/instant.md` against `app_vi.arb` and the mock.
- [ ] **Step 2: Ledger** sections: Built; Decisions (1–31 one line each); Rulings taken while implementing; Skipped by standing rules (rules tests and Functions integration tests written not run; no device build; no FGS/background location; no iOS); Deploy order (indexes before functions; seed/config doc `instant_config/current` must exist in each project before `enabled` is used; rules deploy with the functions); the #140/#202 split (no money in #140, `inviteInstant` guarded by `fakePaymentsAllowed()`, flag off; #202 inserts the payment gate); Deferred (below).
- [ ] **Step 3: Commit** `docs(spec): Chụp ngay phase 1 on Functions, provider screens, data model and ledger [#140]`.

### Task 11 (#202): Money — `instant_request` payment subject on V1, refunds, release, earnings

**Runs as issue #202** on `plan/202-instant-payments` after #140 (Tasks 1–10 here and Tasks 1–7 of the customer plan) and #200 (V1) have merged; the customer plan's Task 8 follows in the same PR. Commit subjects end with `[#202]`. Everything below was cut out of Tasks 2–9 by the 2026-10-08 split; signatures are in Contract (items tagged #202) and Decision 5.

**Files:**
- Create: `packages/domain/src/instant_payments.ts` (`InstantPaymentSettler`); tests `packages/domain/test/instant_payments.test.ts`.
- Modify (domain): `escrow.ts` (V1's `PAYMENT_SUBJECTS` += `'instant_request'`, so `PaymentSubject` and `isPaymentSubject` accept it), `instant_requests.ts` (`inviteInstant` uncommitted branch → payment step; `checkInstantPayment`; money effects of `cancelInstantRequest`, `confirmInstantComplete`, auto-complete), `instant_jobs.ts` (`answerInstantOffer`: `payment.payeeId = uid`, contact copy when paid; photographer cancel: `payeeId = ''`; `no_show`: 50% refund + `releaseAfter`), `test/support/instant_world.ts` (`gateway: FakePaymentGateway`, `settlement: SettlementDeps` with `subjects.instant_request`), `index.ts`; tests `instant_requests.test.ts`, `instant_jobs.test.ts`.
- Modify (Functions): `src/callables/instant.ts` (`handleCheckInstantPayment` with `liveSettlementDeps()`; `handleInviteInstant` loses the #140 `fakePaymentsAllowed()` guard — payments off now means `not_eligible` through V1's `checkoutGatewayAvailable()`), `src/index.ts` (export `checkInstantPayment`, `PAYMENT_CALLABLE_OPTIONS`), `src/infra/live_payments.ts` (V1's `liveSettlementDeps()` registers `subjects.instant_request = new InstantPaymentSettler(liveInstantDeps(), cipher)`; `cipher` only once #201 has merged), `src/infra/booking_firestore.ts` (`subjectType` whitelists accept `instant_request`), V2's `liveRefundSubjects()` (registers the instant handler; only with #201), `src/infra/earnings_firestore.ts` (`getSubject` for `instant_request`; `earningItemFromFirestore` keeps it), the payout path (`payoutLineOf` takes the request's `platformFeeBp` as `feeBp` for an `instant_request` payment, Decision 6), `tools/instant.ts` (CLI confirms the fake payment before the offer goes out); tests `test/unit/instant_callables.test.ts`, `booking_firestore.test.ts`, `earnings_firestore.test.ts`, `instant_cli.test.ts`, `test/integration/instant.test.ts` (written, not run).
- Modify (app data): `lib/data/instant/instant_models.dart` (`InstantPaymentNeeded`), `firestore_instant_mapping.dart`/`firestore_instant_repository.dart` (`invite` sends `payMethod.code` and parses `{kind: 'payment', instructions}` with V1's flat Dart `PaymentInstructions` parser; `checkPayment` → `checkInstantPayment`, returning V1's `PaymentCheck {paid, instructions?}` if Task 8's `PaymentController` case wants the renewed instructions, else `bool`), `test/support/fake_instant_repository.dart`; `lib/features/earnings/earnings_screen.dart` (an `instant_request` row opens `/work/instant/{subjectId}`); tests `test/data/instant/firestore_instant_repository_test.dart`, `test/features/earnings`.

**Interfaces:**
- Consumes: Tasks 2–9; V1 (#200; the domain names land in its Task 2, `liveSettlementDeps()` in its Task 4, the app side in its Task 6 — Step 1 checks all three are on develop): `PAYMENT_SUBJECTS`, `newSubjectPayment(p: {id, subjectType, subjectId, payerId, payeeId, amount, method, provider, idempotencyKey, now, expiresAt}): Payment` with `id` from `freshPaymentId(payments, ids)`, `issuePaymentInstructions(gateway, payment, save: (providerRef, instructions: GatewayInstructions) => Promise<void>): Promise<PaymentInstructions>` (no `returnUrl`), `instructionsOf(payment): PaymentInstructions | null`, `applyTransfer({payment, transfer, ledgerEntryId, now}): {payment, ledgerEntry, decision: TransferDecision, excess}` (no `payer`), `expireUnpaid({payment, refundId, ledgerEntryId, now})`, `transferRecordId`/`transferRecordOf`, `SubjectSettler {settle(paymentId, transfer): Promise<Exclude<TransferOutcome, 'needs_review'>>; expire(paymentId, now): Promise<'expired' | 'unchanged'>; dispatchRefund(refund, payment): Promise<Refund>; statusOf(payment): Promise<string>}`, `SettlementDeps {payments: PaymentLookup, gateway, clock, subjects}` (`subjects` required), `settleTransfer`, `checkSubjectPayments(deps, payments): Promise<boolean>`, `confirmFakePayment` (returns `{outcome, subjectType, paymentStatus, subjectStatus}`), `liveSettlementDeps()`, flat `PaymentInstructions` (TS and Dart; `transferCode`, `qrPayload?`, `bankName?`, `accountMasked?`, `payUrl?`, `bankAppsUrl?`, `subjectType`, `subjectId`) and the gateway's `GatewayInstructions`; #129: `applyRefundToPayment`, `transferRefund`, `releaseEscrowPayment` (clock step 5), `FakePaymentGateway.pushTransfer`, `dispatchRefunds`; V2 (#201, soft; `2026-10-08-v2-refund-destination.md`): `sendRefundOnce(d: {gateway, cipher, clock}, refund, payment: Pick<Payment, 'id' | 'provider'>)`, `mergeRefundOutcome(stored, next): Refund | null`, the `pending` re-send through its `RefundSubjects` registry (`RefundSubjectHandler {resend(refund), record(next)}`, `liveRefundSubjects()`), `AccountCipher`, bank accounts with `bankCode`. **Until #201 lands:** `InstantPaymentSettler.dispatchRefund` and the cancel/no-show/late-payment refunds go through #129's `dispatchRefunds(deps, items)` (gateway error → refund `failed` + `manual`, no automatic re-send), mirrored on the request as `refundId`/`refundStatus`; ledger it, and switch to `sendRefundOnce` + `mergeRefundOutcome` when #201 is on develop (Step 1 decides which).
- Produces: `InstantPaymentSettler`, `checkInstantPayment` (domain + callable), `InviteResult.payment`, Dart `InstantPaymentNeeded`, the earnings row; with #201 on develop also `instantRefundHandler` (`RefundSubjectHandler` for `instant_request`, `resend` = `sendRefundOnce` + a transaction with `mergeRefundOutcome` mirroring `refundStatus` on the request) registered in `liveRefundSubjects()`.

Behaviour (Decision 5, 7, 9; reads before writes in every transaction):
- `inviteInstant` uncommitted: after the price check, reuse a still-`created` payment of the same amount and method (`instructionsOf`), else `newSubjectPayment` with `id = await freshPaymentId(settlement.payments, ids)` (transfer codes unique across subjects; idempotency key `inst_{requestId}_{n}`, `expiresAt = now + PAYMENT_EXPIRY_MINUTES`); status `pending_payment`, `paymentDeadlineAt = payment.expiresAt`, `pendingInviteIds`, `payMethod`, `provider`, `paymentId`; `issuePaymentInstructions(gateway, payment, save)` outside the transaction (`save` writes the `GatewayInstructions` and `providerRef` in a short instant transaction, only while the payment is still `created`); returns `{kind: 'payment', instructions, amountVnd}` with V1's flat `PaymentInstructions`. No offer is sent. Committed requests keep sending at once (later rounds use the held money).
- `InstantPaymentSettler.settle(paymentId, transfer)` (no `payer`; one `InstantStore` transaction, reads first): transfer record `transferRecordId(transfer)` exists → `'duplicate'`; else `applyTransfer({payment, transfer, ledgerEntryId, now})` (`payment_received`), write the transfer record (`transferRecordOf`), return #129's outcome; `paid` and the request still `pending_payment` with this `paymentId` → `paidAt`, `committedAt`, `sendOffers(pendingInviteIds)` (Task 3's internal), contact copy if a photographer is somehow already assigned (never in practice); `paid` otherwise (cancelled, payment window passed, another payment) → `applyRefundToPayment(100%, 'late_payment')`; excess → `transferRefund`; refunds dispatched after commit with `this.dispatchRefund(refund, payment)` (V2 or the fallback above). `expire(paymentId, now)` = `expireUnpaid` → `'expired' | 'unchanged'`; `statusOf(payment)` = the status of the request `payment.subjectId` (`'gone'` if missing).
- `checkInstantPayment`: payer only; `checkSubjectPayments(settlement, createdPaymentsOfRequest)`. The fake confirmation is V1's `confirmFakePayment({paymentId, kind?})`, which reaches the settler through `SettlementDeps.subjects` and answers `{outcome, subjectType, paymentStatus, subjectStatus}`.
- Money effects on a paid request: customer cancel → `applyRefundToPayment(percent)` with the Decision 9 rule; fee > 0 → payment `releaseAfter = now + 24 h`, payee stays the photographer; `no_show` → 50% refund, `releaseAfter = now + 24 h`; accept → `payment.payeeId = uid` and the contact copy (Decision 22); photographer cancel → `payeeId = ''` (money stays held); `confirmInstantComplete` and auto-complete → `releaseAfter = completedAt + 24 h` (released by the existing `bookingClock` step 5).
- Earnings subject for `instant_request` (paid, payee set): `counterpartName` = request `customerName`, `label` = "Chụp ngay · {duration}" ("Chụp ngay · 1 giờ"), `day` = VN date of `assignedAt`.

- [ ] **Step 1: Contract check** of V1's names on develop (and V2's: present → use them; absent → the #129 fallback, ledgered); ledger differences.
- [ ] **Step 2: Failing tests** (moved here from Tasks 3–6 by the split):
  - `instant_requests.test.ts`: `first invite creates one payment and pending_payment, no offer yet, and returns PaymentInstructions with the VietQR payload for bank_qr`; `price change returns price_changed with the new amount saved and no payment`; `a second invite tap reuses the created payment`; `payment confirmed (V1's confirmFakePayment through subjects.instant_request) sends offers to the chosen people only, each with a 60 s expiry and a push`; `all unavailable after payment: choosing with roundEnded, money held`; `later round invites without a new payment`; `search window ends in no_match without a refund`; `payment window passes: choosing, then a late transfer refunds 100% (late_payment)`; `payment confirmed after cancel is refunded in full`; `the same transaction id applies once`; `a webhook transfer for an instant payment is settled through SettlementDeps.subjects, not unmatched`; `an over transfer refunds the excess`; `a throwing refund stays pending and is re-sent by V2's re-send, not by runInstantSweep` (with #201; with the fallback: `a throwing refund is failed + manual`); `customer cancel in each state applies the Decision 9 percent and writes refund + ledger lines that sum to the amount`; `confirm complete stamps releaseAfter + 24 h and frees the photographer`; `auto-complete 2 h after finish stamps releaseAfter`; `sweep never sends a refund`; `committedAt is never set without paidAt` (invariant over a full flow).
  - `instant_jobs.test.ts`: `accept of a paid request writes the contact copy and sets the payment payee`; `no_show after 15 minutes refunds 50/50 and stamps releaseAfter`; `photographer cancel clears the payee and keeps the money held`.
  - `instant_payments.test.ts`: `settle is idempotent per transfer`; `expire uses expireUnpaid`; `statusOf(payment) returns the status of payment.subjectId's request, gone when missing`; `settle returns duplicate for a replayed transfer record`; `the payment id comes from freshPaymentId (code unique across subjects)`.
  - Functions: `inviteInstant returns V1's flat PaymentInstructions (bank_qr has transferCode and qrPayload)`; `inviteInstant in payments-off mode is not_eligible`; `checkInstantPayment maps to the payer only`; `booking_firestore.test.ts`: `a refund with subjectType instant_request keeps it`; `earnings_firestore.test.ts`: `instant payment row reads "Chụp ngay · 1 giờ" with the customer name and the assignment day`; `unpaid or payee-less instant payment has no row`; `instant_cli.test.ts`: `offer creates a paid request and one offer for an online photographer`; integration (written, not run): `full flow on the emulator: create → invite → fake pay → accept → start_route → arrive → start → finish → confirm → clock releases after 24 h (clock injected)`.
  - App: `invite parses payment, invited and price_changed results and sends payMethod.code`; `checkPayment calls checkInstantPayment`; earnings `an instant_request row opens /work/instant/{id}`.
- [ ] **Step 3:** Run the domain, Functions and app suites above → fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5:** `cd packages/domain && npm test && npm run lint`; `cd app_flutter/firebase/functions && npm test && npm run build`; `flutter analyze`; `test/data/instant`, `test/features/earnings`, `test/features/instant_work` green one at a time. Ledger: V2 present or fallback used; the guard removed; rules/integration tests written, not run.
- [ ] **Step 6: Commit** `feat(instant): Chụp ngay payment subject, refunds, release and earnings on V1 [#202]`. Then run the customer plan's Task 8.

## Deferred

- Customer app S13.01–S13.08 (customer side), entry points on S02.01/S02.06, the flag flip → `2026-10-07-s13-instant-customer.md` (blocked by this plan).
- Real payment intermediary (#129 Deferred) and S22.04 refund-account choice (#141). VietQR, webhooks, reconciliation and refunds run through #129's model on the fake gateway in Task 11 (#202).
- Two-milestone release for instant shoots (they have no delivery; #130's milestone model is booking-only) and reviews after instant (#130); disputes within 24 h (S18, #142).
- Background presence and route sharing (Android foreground service `location`, iOS background mode), "Vẫn muốn nhận việc?" prompt, battery nudges, full-screen offer intent with sound (device steps; battery plan).
- Real map tiles, live ETA from a routing API, address autocomplete/geocoding (Needs the owner 2; cost section).
- Typical match time per area; time-of-day surge; staff tools for the instant config and stuck refunds (S23, phase 1.5 #83).
- Merging instant requests into `bookings` with `source: instant` (data-model proposal) and the self-hosted dispatch service of spec §5 (`services/dispatch`, Go backend phase 2 #90).
- Cloud Tasks for exact timers if the 15-minute backstop proves too slow at scale.
