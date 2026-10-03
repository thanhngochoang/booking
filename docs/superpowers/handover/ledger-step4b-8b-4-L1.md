# Handover ledger — 8b/4-L1 (Booking sheet S04.01–S04.04)

Unit: `8b/4-L1` (Lane 1 Step 4), plan `2026-10-02-step4b-booking-sheet.md` Tasks 2–8 (Task 1 landed earlier in 8a2/3-L2)
Branch: `plan/8b-4-L1-booking-sheet`
Target: `develop`

## Scope completed

- **Task 2** `BookingFlowController` + state (`lib/features/booking/booking_flow_controller.dart`, `booking_flow_state.dart`).
- **Task 3** route `/u/:uid/book` (sheet page) and S04.01 package step.
- **Task 4** S04.02 day and start time on the live calendar.
- **Task 5** place step and S04.03 review (money, escrow, policy, provider).
- **Task 6** submit: draft booking, deposit, fake gateway sheet, error handling.
- **Task 7** S04.04 `/b/:id/pay` (`lib/features/booking/payment_pending_screen.dart`): draft → vibration `SignatureLoader`, "Kiểm tra lại" (`checkDeposit`), "Đổi cổng thanh toán" (`ProviderPicker` → `createDeposit`), paid → `BookingPaidPanel`, removed draft → expired with "Đặt lại"/"Về trang chủ".
- **Task 8** end-to-end test `test/features/booking/booking_flow_e2e_test.dart`; S04.01–S04.04 marked built in `remaining-screens.md`.

## Rulings

- `payPendingBody` is "{provider} chưa báo về. …" with new keys `payProviderNamed` "Cổng {name}" and `payProviderGeneric` "Cổng thanh toán": the fake gateway reads "Cổng thử nghiệm" (Decision 2), real mode "Cổng MoMo/VNPay" (mock wording).
- Expired "Đặt lại" goes to `bookingPath(photographerId, serviceId)` (plan) rather than plain S04.01 (spec); same screen, with the package preselected.
- Picking the current gateway in "Đổi cổng thanh toán" does nothing (no new deposit).
- S04.02 month row and `AvailabilityLegend` now share a `Wrap`: the legend drops under the month at 320 dp / 1.3× text instead of overflowing (mock's one-line layout kept where it fits).

## Deferred / for later plans

- **S02.06 "Đặt T7" opens S04.01, not S04.02.** `find_screen.dart` passes only `date` because recommendation items carry no package; the plan/spec ("có sẵn ngày và dịch vụ") expect S04.02. The e2e test asserts current behaviour (S04.01 with the only package chosen and the day kept). Skipping to S04.02 needs S02.06 to choose a package — new product work.
- The fake repository's `createBooking` always stores price 1.000.000₫ / deposit 300.000₫, so the paid panel's deposit amount is not asserted in the e2e test.
- Unused ARB keys from Task 3 duplicate Task 7 ones: `paySuccessTitle`, `paySuccessBody`, `payExpired`, `payRetry` — remove in a cleanup.
- Analytics events `book_step{n}`, `book_submit`, `book_error`: no analytics port yet.
- `BookingPaidPanel` is temporary; plan 4c deletes it and sends non-draft S04.04 to `/b/:id`.

## Cross-lane requests

None.
