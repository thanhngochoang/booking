# Handover Ledger: S05/S06 Bàn giao hai lớp (Two-Layer Delivery)

Issue: [#152](https://github.com/thanhngochoang/booking/issues/152) · Branch: `plan/152-delivery-two-layer` · Date: 2026-10-18

---

## 1. Summary of Delivered Work

This unit implements the complete two-layer delivery system across the entire stack:
1. **Domain Layer (`packages/domain`)**:
   - Extended `BookingStatus` with 4 new states: `shot`, `delivered`, `revision_requested`, `approved`.
   - Milestone models and splitting logic (`PaymentMilestone`, `splitMilestones`, `milestonePayoutsOf`, `milestonesDoneOf`).
   - Pure domain business rules for delivery (`canSubmitDelivery`, `canApproveDelivery`, `canRequestRevision`, `canRespondExtraRound`, `checkWindowHours = 48`, `autoApproveHours = 72`).
   - Notification hooks: `notifyBookingDelivered`, `notifyRevisionRequested`, `notifyExtraRoundRequested`, `notifyExtraRoundResponded`, `notifyDeliveryApproved`.
2. **Cloud Functions (`app_flutter/firebase/functions`)**:
   - Sharp-based image processing trigger (`onDeliverySampleUpload`) generating 1600 px watermarked JPEG (with 45° diagonal repeating text pattern) and 400 px thumbnail, immediately purging the clean temporary upload from Storage.
   - Callables: `submitDeliveryRound`, `approveDelivery`, `requestRevision`, `respondExtraRound`, and extended `confirmShoot` and `openDispute`.
   - Periodic sweep `releaseMilestones` integrated into `bookingClock` (releasing shoot milestone after 24h dispute window and delivery milestone after 48h check window).
   - Storage and Firestore rules securing watermark samples (readable by booking parties) and private delivery link (readable only when `approved` or `completed`).
3. **Flutter App (`app_flutter`)**:
   - Provider/customer data models and repositories (`DeliveryRepository`, `DeliveryRound`, `DeliverySampleRef`, `DeliveryLink`).
   - S06.07 Provider delivery sheet (`submit_delivery_sheet.dart`) with sample upload previews, link input, photo count, and notes.
   - S05.06 Customer review screen (`delivery_review_screen.dart`) with 3-column watermarked sample grid, full-screen InteractiveViewer pager, masked link chip (`{host}/••••••••`), auto-approve countdown, 48h check window progress card, and dispute report button.
   - S05.07 Customer revision sheet (`revision_sheet.dart`) with numbered photo tile selection, preset chips dialog ("Da sáng hơn", "Bớt vàng", "Xoá vật thể", "Cân lại nghiêng"), and general note.
   - Report sheet (`report_delivery_sheet.dart`) with the 4 delivery dispute reasons.
   - Detail screen (`booking_detail_screen.dart`) integration with `/b/:id/delivery` route and dynamic primary CTAs across roles and states.
   - `ScreenCodes`: `deliveryReview` (`S05.06`), `requestRevision` (`S05.07`), `submitDelivery` (`S06.07`), `cancelBooking` (`S05.03`).

---

## 2. Rulings on Plan Decisions 1–16

- **Decision 1 (Status machine)**: 4 new statuses added (`shot`, `delivered`, `revision_requested`, `approved`). Existing bookings migrate smoothly (`completed` and legacy `reviewed` remain terminal and valid).
- **Decision 2 (Subcollection vs field)**: Rounds stored in subcollection `bookings/{id}/deliveries/{round}`; private link stored in separate document `bookings/{id}/private/delivery`.
- **Decision 3 (Server watermark vs client)**: Server-side watermark via Sharp Cloud Function on Storage upload to temporary path `deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`. Clean copy is immediately deleted after processing.
- **Decision 4 (Storage isolation & limits)**: Storage rules enforce JPEG, max 2 MiB per upload, matching `jpegUpTo(2 * 1024 * 1024)`.
- **Decision 5 (Revisions limit & extra rounds)**: Default `revisionsIncluded = 1` (package revisions 0–5). Revisions beyond limit require asking for an extra round (`requestRevision(extra: true)`) which provider can accept/decline.
- **Decision 6 (Link host masking)**: Provider submits full link, server extracts `linkHost` (e.g. `drive.google.com`) saved to round. Customer UI displays `{host}/••••••••` without ever having access to the real link until approval.
- **Decision 7 (Milestone split & escrow release)**: 50% shoot / 50% delivery split. Stored under `payments/{id}/milestones` and mirrored under `bookings/{id}/milestones`.
- **Decision 8 (Clock sweeps & intervals)**: `releaseMilestones` and auto-approve checks are evaluated in `bookingClock` (running every 5–15 minutes).
- **Decision 9 (Dispute window vs check window)**: 24h dispute window after `shot`; 48h check window after `approved`. Reporting within check window holds milestone release and opens dispute.
- **Decision 10 (Studio delivery permissions)**: Individual booking: assigned photographer delivers. Studio booking: only studio owner delivers; assigned shooter sees no S06.07 entry.
- **Decision 11 (Notification hooks)**: The 5 delivery hooks (`notifyBookingDelivered`, `notifyRevisionRequested`, `notifyExtraRoundRequested`, `notifyExtraRoundResponded`, `notifyDeliveryApproved`) are fully implemented and dispatched.
- **Decision 12 (Purge policy for samples)**: Delivery samples kept for 90 days after completion, then cleaned up by storage retention. UI renders `deliverySamplesPurged` fallback state if sample files are empty.
- **Decision 13 (Review timing)**: Review CTA is unlocked as soon as `approved` occurs (simultaneously with link unlock).
- **Decision 14 (Route structure)**: Customer route `/b/:id/delivery` opens S05.06. Provider opens S06.07 via modal sheet from S05.02 or S06.01.
- **Decision 15 (Report delivery sheet branch)**: Branch 15b was taken: since #142 (S18 disputes) is not yet merged, dedicated lightweight `ReportDeliverySheet` is implemented, calling `openDispute` callable and holding milestone release.
- **Decision 16 (Earnings display)**: `S06.05` displays milestone breakdown ("· mốc 1/2") and counts milestones towards total earnings.

---

## 3. Skipped Suites & Test Coverage

- **Skipped Suites**:
  - `rules-test`: Requires local Firebase emulator runtime with Java, which is skipped during agent plan execution in accordance with repo guidelines. CI runs it on push.
  - Functions Storage emulator integration tests: Functions unit tests pass (`npm test` in `packages/domain` and `app_flutter/firebase/functions`).
- **Executed Suites**:
  - `packages/domain`: 100% tests passing (`npm test`).
  - `app_flutter/firebase/functions`: 100% tests passing (`npm test`).
  - `app_flutter`: All delivery and booking feature tests passing:
    - `test/features/delivery/`: 29 tests passing.
    - `test/features/booking/`: 247 tests passing.
  - `flutter analyze`: 0 issues found.

---

## 4. Deployment Order

1. **Firestore Rules & Indexes**: Deploy `firestore.rules` and `firestore.indexes.json` (`npm run deploy:rules:dev`).
2. **Storage Rules**: Deploy `storage.rules` (`npm run deploy:storage:dev`).
3. **Cloud Functions**: Deploy updated callables and triggers to `dev` environment (`BLAZE_ENABLED=true` required for Sharp native build and Storage triggers on Cloud Build).
4. **Flutter App**: Release Flutter client with S05.06, S05.07, S06.07 and updated routing.
