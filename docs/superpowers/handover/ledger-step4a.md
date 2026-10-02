# SDD ledger — plan: docs/superpowers/plans/2026-10-02-step4a-booking-backend.md

Branch plan-4a from flutter-rewrite a547353. Baseline: analyze clean, 1390 Flutter tests pass, 93 domain tests pass, 45 functions unit tests pass.
Ruling: commits end with Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com> — user/harness instruction.
Ruling: Every battery/idle/blur-budget step skipped (final plan 16); rules emulator tests not run locally (CI) — plan header + standing rules.
Ruling: workspace ledger updated task-by-task.

Task 1: dispatched
Task 1: complete (policy, errors, types, shared fixtures, 103 tests pass, typecheck and lint clean)

Task 2: dispatched
Task 2: complete (booking state machine, decideTransition, roleOf, 121 tests pass, typecheck and lint clean)

Task 3: dispatched
Task 3: complete (escrow and ledger maths, payments, refunds, ledger entries, invariants 11 & 12, 130 tests pass, typecheck and lint clean)

Task 4: dispatched
Task 4: complete (booking ports, in-memory reference store, fake gateway, createBookingDraft, createDeposit, confirmFakePayment, handlePaymentNotification, checkDeposit, 140 tests pass, typecheck and lint clean)

Task 5: dispatched
Task 5: complete (commitTransition, transitionBooking, openDispute, runBookingSweeps, 148 tests pass, purity clean, typecheck and lint clean)

Task 6: dispatched
Task 6: complete (Firestore booking store, catalog reader, customer contact reader, live deps wiring, 48 functions unit tests pass, typecheck and lint clean)

Task 7: dispatched
Task 7: complete (booking callables, bookingClock scheduled function, env config, 57 functions unit tests pass, typecheck and lint clean)

Task 8: dispatched
Task 8: complete (Firestore security rules for bookings/private/contact & escrow tables, composite indexes for sweeps & queries, specs updated)

Task 9: dispatched
Task 9: complete (seed fixtures across requested/accepted/upcoming/completed states with payments, ledger entries, contact copy, availability, 58 functions unit tests pass, typecheck and lint clean)

Task 10: dispatched
Task 10: complete (Flutter booking domain models, mirror rules, repository port, firestore adapter, providers, fake repository, fixtures, 1405 tests pass, analyze clean)
