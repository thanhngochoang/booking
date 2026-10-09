# Ledger — N1 order gate (issue #198)

Plan: `docs/superpowers/plans/2026-10-08-n1-order-gate.md`. Branch: `plan/198-nen-cong-nhan-don-orderblocker-blockgate` (project.py's default name, not the plan's `plan/198-cong-nhan-don`).

## What shipped

| Task | Commit | Result |
|---|---|---|
| 1 Domain | b6a2787 | Error code `blocked`; `BlockGate`, `blockDocId` (`block_ports.ts`); `FakeBlockGate`; `orderBlocker` / `assertOrderAllowed` (`order_gate.ts`); `BookingDeps.blocks` (required); `createBookingDraft` calls `assertOrderAllowed`; `createPayment` re-checks a caller's own `draft` before any payment is read or created (Decision 4). |
| 2 Functions | c16372d | `FirestoreBlockGate` (`safety_firestore.ts`), `liveBlockGate()` (`live_safety.ts`), `liveBookingDeps()` sets `blocks`; `TRANSPORT_CODE.blocked = 'failed-precondition'`; every test `BookingDeps` literal carries a `FakeBlockGate`. |
| 3 App | this commit | `BookingErrorCode.blocked` (after `notAcceptingOrders`), `'blocked'` mapped in `_codeToBookingError`; controller clears the draft id and goes idle (no profile re-read); booking sheet SnackBar without "Thử lại"; S04.04 (`payment_pending_screen`, `qr_checkout_view`) shows the same text; l10n `bookingErrBlocked` "Không đặt lịch được với người này."; `FakeBookingRepository._serverCodeFor`. |

## Contract differences found in each task's Step 1

None blocking. Names in the plan's Contract matched `develop` c5123cb in the domain, Functions and app parts.

## Notes and rulings

- Integration test `a block document either way makes createBooking answer failed-precondition blocked` (`test/integration/booking.test.ts`) is written but not run in the sandbox; CI runs it.
- `payment_world.ts` lives in `test/unit/support/`, not `test/support/`.
- Deferred minors: the `createPayment` tests pin only the draft branch of Decision 4 (a stranger or a non-draft booking still answers `not_found` / `permission_denied` / `conflict`, covered by the existing tests); `blockDocId` joins with `_` (plan-mandated; Firebase uids contain no `_`).
- App Step 5: `flutter analyze` clean; `test/data/booking` and `test/features/booking` green; `test/l10n`, `test/lint` and `test/core/source_rules_test.dart` green. `dart run tool/affected_test.dart origin/develop --run` could not finish in the sandbox (its inner `flutter test` runs `pub get`, which needs pub.dev); CI runs it on the PR.

## For consumers (#144 S20, #139, #140, #136, #151 and the other order plans)

- Import from the domain: `orderBlocker`, `assertOrderAllowed`, `OrderGateDeps`, `OrderParties`, `OrderBlock`, `BlockGate`, `blockDocId`, `FakeBlockGate`; Functions: `liveBlockGate()`, `FirestoreBlockGate`.
- Every live deps that reaches `orderBlocker` / `assertOrderAllowed` must set `blocks: liveBlockGate()` (`OrderGateDeps.blocks` is optional, so a missing gate silently skips the block check; `BookingDeps.blocks` is required).
- Test worlds use `FakeBlockGate` (`block(a, b)`, `calls`).
- Order of checks: provider gate first, then blocks; `not_accepting_orders` wins over `blocked`. Customer = the person who orders, provider = the person who would do the work.
- App: reuse `BookingErrorCode.blocked` and `bookingErrBlocked`; the text never says who blocked whom.
- #144 extends `block_ports.ts`, `safety_firestore.ts` and `live_safety.ts` (it must not redefine `blockDocId`), writes `blocks/{blockerId}_{blockedId}` ("A blocked B" = that document exists), and adds the blocker's read rule and indexes. Until it lands no block document exists, so behaviour is unchanged.
- Deploy order: Functions first, then the app. An old app shows its generic error for `blocked`.

## Deferred (from the plan)

- Writing blocks, the per-user block index, rules and indexes for `blocks`, hiding content, block checks on inquiries, messages, contact links and event registration: #144.
- Gate calls in quotes (#139), Chụp ngay invites (#140), studio assignment (#136), collaborators (#151): their plans.
- Settlement re-check in `handleTransferNotification`: #135 for `not_accepting_orders`; a block arriving between QR and transfer is accepted (money held in escrow, the booking goes through support).
- Self-hosted parity (`services/api`, Go backend #90).
