# Handover ledger — plan 4e (review and share), unit 8e/7-L1

Plan: `docs/superpowers/plans/2026-10-02-step4e-review-share.md`, Tasks 4–5 (lane 1 step 7). Tasks 1–3 landed in 8e/6-L2 (`ledger-step4e-8e-6-L2.md`).
Built: S05.05 "Đánh giá & chia sẻ" (`/b/:id/review`, `lib/features/review/`) and the reviews section on S03.01.

## History
- Started on machine `MAC-JM4RLWTXXR`; taken over on 2026-10-06 by `MacBook-Pro` on the user's instruction. Task 4 had been committed without a recorded review; Task 5 was a WIP commit, finished by a fresh implementer.

## Rulings
- The `/b/:id/review` route is registered in `bookingDetailRoutes`, not in `router.dart` (wired and tested there).
- The read-only view links "Xem ảnh đã chia sẻ" without a photo count: the `Review` carries no count.
- Uploaded files are deleted only after a successful submit; a `conflict` counts as success. Uploads still running when the user picks "Chỉ đánh giá", removes a tile or leaves the screen are deleted when they finish (composer pattern).
- Leaving S05.05 without submitting deletes the uploaded files (`ref.onDispose`).

## Deferred
- No image-preparation step yet: `ReviewPhoto` is sent with `blurHash`/`w`/`h` null, so real-shoot posts have null `imageMeta`. Add when the media pipeline gets a prepare step (the composer has the same gap).
- Reviews list on S03.01: one extra read per review row (≤ 20 per page) for the author; acceptable for v1.
- Loaded reviews render in a `SliverToBoxAdapter` (not lazy); switch to `SliverList` when the list is next touched.
- `ReviewTile` skeleton text block has a fixed 80 px height; small jump at text scale > 1.0.
- `test/support/booking_world.dart` checks the override origin with `dynamic`; callers should pass `reviews:` instead.
- Not in this plan: badges toast after review, the "Buổi chụp thế nào?" push, analytics `review_submit`.
- If the user leaves S05.05 while a "Gửi & chia sẻ" submit is still in flight, `onDispose` deletes the files before the submit may attach them (narrow window). Fix: skip dispose cleanup while a share submit runs and let `submit` clean up on failure/conflict.
- Tests not added: the reviews header (formatRating, hidden until the profile loads), the 48dp "Xem thêm" target, and the S05.01 "Đánh giá" entry against the real screen (`pumpBookingRoute` stubs `/bookings`; `my_bookings_screen_test` asserts the tap target).
