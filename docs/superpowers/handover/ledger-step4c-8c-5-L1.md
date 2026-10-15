# Handover ledger — 8c/5-L1 (Booking detail, lists, work dashboard)

Unit: `8c/5-L1` (Lane 1 Step 5), plan `2026-10-02-step4c-booking-detail-lists.md` Tasks 2–7 (Task 1 landed in 8c/4-L2)
Branch: `plan/8c-5-L1-booking-detail-lists`
Target: `develop`

## Scope completed

- **Task 2** pure view rules `lib/features/booking/booking_view_rules.dart` (actions, timeline, buckets, work dashboard, countdown).
- **Task 3** S05.02 `/b/:id` (`booking_detail_screen.dart`, `booking_parties.dart`); S04.04 now hands over to `/b/:id?paid=1` and `BookingPaidPanel` is gone.
- **Task 4** S05.03 cancel sheet (`cancel_sheet.dart`) with the live refund policy; `booking_errors.dart` maps error codes to friendly text.
- **Task 5** S05.01 customer bookings (`my_bookings_screen.dart`) in the `/bookings` tab.
- **Task 6** S06.01 work dashboard, S06.02 next-step empty state, S06.03 decline sheet, work tab badge (`lib/features/work/`).
- **Task 7** two-sided lifecycle e2e (`test/features/booking/booking_lifecycle_e2e_test.dart`); code table updated.

## Rulings

- With `?paid=1` the customer sees the mock's inline toast while `requested`, and the `EscrowNotice` is hidden meanwhile; otherwise `EscrowNotice` shows while escrow is held.
- "Nhắn tin" needs the chat flag and a `chatId`; "Đổi lịch" and cancel only before the start; the photographer gets no "Chỉ đường" on S05.02; Nhận/Từ chối disappear after the accept deadline.
- S05.03 starts with no reason selected (the mock preselects "Đổi kế hoạch"; a preselected optional reason would send a false one). A 0₫ refund toasts "Đã huỷ buổi chụp".
- Core `showConfirmSheet` shows `e.toString()`; lane 1 wraps `onConfirm` (`withBookingErrorText`) so it shows friendly text.
- S06.01 app bar follows the mock ("Công việc" over the date, no bell until S17); today's shoot is a `highlight` `BookingCard` (no hero variant yet); request cards carry a `ContactDial` (spec) at the end of the button row.
- S06.02 never shows the list tabs; package/skills/share sentences written in the spec's voice; "Chia sẻ hồ sơ" opens `/u/{uid}`.
- "Nhắn tin"/"Đánh giá" on list cards are outline small (no secondary style in `AppButton`).

## Deferred

- S05.01 paging; S06.01 offline rule (no connectivity signal, port has no `isFromCache`).
- Unused ARB keys: `emptyBookingsTitle`, `emptyBookingsBody`, `emptyWorkTitle`, `emptyWorkBody`, `payRequestSent`, `payReplyIn24h`, `payViewBookings` (and from 4b `paySuccessTitle`, `paySuccessBody`, `payExpired`, `payRetry`).
- `specs/screens/photographer.md` still says S06.01 is not built.

## Cross-lane requests (lane 2)

- `bookingSummaryOf` should format the day as "T7 12/10" (S04.04 shows "2026-10-15").
- `FakeBookingRepository`: emit a null contact copy; record `transitionBooking` calls (lane 1 subclasses it today).
- `confirm_sheet.dart`: accept an error-to-text mapper instead of `e.toString()`.
- `ReasonPicker`: hard-coded "Nhập lý do cụ thể...", "Tối thiểu {n} ký tự" → ARB or a hint parameter.
- `StatusTimeline`: hard-coded Vietnamese semantics labels.
- `MoneyBreakdown`: a larger total style (mock shows the refund at 16 px).
- `BookingCard`: a `hero` size for S06.01's today card; `SectionHeader`: a count slot; `StatTile`: `onTap` (for S06.05); a connectivity signal.
