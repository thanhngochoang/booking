# Handover ledger — plan S03 orders-closed (issue #133)

Plan: `docs/superpowers/plans/2026-10-07-s03-orders-closed.md`, Tasks 1–5. Branch `plan/133-s03-orders-closed` (commits 8df5e9f, e42d19f, bf0ad33, 847fb46, then the docs commit).

## Built
- Domain: `acceptsOrders`, `acceptingOrdersPatch`, port `ProviderOrderGate`, `BookingDeps.providers`, error code `not_accepting_orders`; `createBookingDraft` refuses after the service check.
- Functions: `FirestoreProviderOrderGate`; `syncAcceptingOrders` in `onPhotographerWrite`; `not_accepting_orders` → failed-precondition; seed `acceptingOrders` computed; rules: `acceptingOrders` server-only.
- App: `PhotographerSummary.acceptingOrders`, `BookingErrorCode.notAcceptingOrders`, Find drops closed providers, S03.01 orders-closed variant (`OrdersClosedTag`, note, locked button), S02.02 and S24.01 bars locked.

## Decisions (plan)
1. "Hồ sơ đủ để đặt" = `onboardingComplete`; no active package is not part of the rule.
2. New error code `not_accepting_orders` (not `not_eligible`, which means "payments off" in the booking sheet).
3. Server gate reads source fields (`verified` + `onboardingComplete`), client reads the derived flag; missing flag falls back to the same rule, no backfill.
4. Owner view unchanged; owner card "Còn {n} bước để nhận đơn" belongs to S21 (#135).
5. Only `createBookingDraft` is gated now; Chụp ngay (#140), quotes (#139) and `assignBooking` (#136) must call the same `ProviderOrderGate`.
6. Find filtered client-side with the rating filter (same empty-page look-ahead); Home shelves not filtered; remote recommender gets a note only.
7. S06 photo detail shows the locked outline "Chưa nhận đặt lịch" for a closed provider; "Xem hồ sơ" stays.
8. Stat tiles and badge row unchanged.
9. Fixtures: `PhotographerSummary.acceptingOrders` defaults false; `fixturePhotographer(..., acceptingOrders = true)`; const summaries in `booking_world.dart` and `event_world.dart` set true.

## Rulings
- Task 4: Ruling: tag border uses colorScheme.outline (mock .ptag --line-2) instead of the brief's outlineVariant — mock is the layout authority (user: "follow the UI mới nhất") — cost if wrong: a slightly darker dashed border, one-line change
- Task 4: Ruling: new core ordersClosedButtonStyle (60% ink-2 text, 60% line-2 border) instead of Material's default disabled outline — matches mock .btn.out.dis — cost if wrong: a style helper to remove
- Task 4: Ruling: album detail (S24.01) also passes acceptingOrders to ProfileBottomBar (required param), `?? true` while loading — keeps today's bar until the profile loads; server still guards — cost if wrong: a closed provider's album briefly shows the primary button while loading

## Deferred
- Task 1: minor (deferred): acceptingOrdersPatch has no case for a non-bool stored flag ('true' string) — provider_orders.test.ts
- Task 1: minor (deferred): second refusal test in create_booking.test.ts checks only the availability day, not the customer draft
- Task 2: minor (deferred): sync runs after skills in the same try — a permanent skills error skips the sync (gate unaffected; next write heals)
- Task 2: minor (deferred): liveAcceptingOrdersWriter uses update(); NOT_FOUND (code 5) on a doc deleted mid-event retries up to 1 h — set(merge) would avoid it
- Task 2: minor (deferred): FirestoreProviderOrderGate defaults firestore to db() unlike sibling readers (plan-mandated signature)
- Task 2: minor (deferred): handlePhotographerEvent positional args (writer before now) easy to misorder
- Task 3: minor (deferred): notAcceptingOrders branch in BookingFlowController duplicates the deadlinePassed/notFound group
- Task 3: minor (deferred): mapping test helper returns bool? for a non-nullable field
- Task 3: minor (deferred): "page of only closed providers" Find test does not assert a second page was requested
- Task 4: minor (deferred): orders_closed_tag_test proves a CustomPaint, not the dashed painter type
- Task 4: minor (deferred): screen tests only assert style isNotNull for the locked button
- Task 4: minor (deferred): ordersClosedButtonStyle lives in orders_closed_tag.dart (discoverability)
- Task 4: minor (deferred): brightness lookup for foregroundSecondary/Muted copied 3 more times (existing precedent)
- Task 4: minor (deferred): tag top gap 4 (AppSpace.s1) vs mock margin-top 2 (parity with ProviderTag)
- % cà chua tile, reviews tab and "Được đánh giá cao" by % → #130.
- Studio variant and "Thành viên của {Studio}" → #136 (the label is not in the mock: design gap).
- Owner card "Còn {n} bước để nhận đơn" → #135.
- The same gate in Chụp ngay (#140), quotes (#139), `assignBooking` (#136).
- Remote recommender filtering (note added to `services/recommender/api/openapi.yaml`).
- Home shelves filtering (spec silent).
- "Mời báo giá" has no screen yet (Decision 5, #139).

## Skipped by standing rules
- The rules test for `acceptingOrders` is written, not run (CI runs it); no Functions integration tests; no device build, so the pixel look is not verified on device.
- Task 3 env: implementer sandbox blocked pub.dev; tests ran with `--no-pub`.
