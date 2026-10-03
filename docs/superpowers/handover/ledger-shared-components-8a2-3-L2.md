# Handover ledger — 8a2/3-L2 (Booking Contract Mirror, expectedPrice, Component Gallery)

Unit: `8a2/3-L2` (Lane 2 Step 3)
Branch: `plan/8a2-3-L2-booking-contract-gallery`
Target: `develop`

## Scope Completed

### 1. 4b Task 1: Booking Contract & Data Layer
- **Domain (`packages/domain`)**:
  - Added optional `expectedPrice?: number` to `CreateBookingDraftInput` and validated integer and non-negative constraints in `validateCreateBookingDraftInput`.
  - Added pre-write price check in `createBookingDraft`: throws `DomainError('price_changed')` if `input.expectedPrice !== undefined && input.expectedPrice !== service.price`.
  - Unit tests added in `packages/domain/test/create_booking.test.ts` for price match and rejection.
- **Firebase Functions (`app_flutter/firebase/functions`)**:
  - `handleCreateBooking` callable passes `expectedPrice` through request data to domain.
  - Added callable unit test in `test/unit/booking_callables.test.ts` verifying rejection on `price_changed` and success on valid `expectedPrice`.
- **Flutter Core & Data**:
  - `lib/data/booking/booking_rules.dart`: Mirrored domain slot/validation rules: `daySlots()`, `endTimeFor()`, validation constants (`kNoteMaxLength`, `kPlaceMinLength`, `kPlaceMaxLength`), and `depositFor()` (mirrored `computeEscrowDeposit` from `@photobooking/domain`).
  - `lib/data/booking/booking_repository.dart`: Added `BookingErrorCode` enum, `BookingException`, `bookingErrorOf(Object)` helper, and `expectedPrice` parameter to `BookingRepository.createBooking`.
  - `lib/data/booking/firestore_booking_repository.dart`: Updated to use shared `BookingException` from repository interface, passing `expectedPrice` to callable.
  - `lib/data/booking/booking_providers.dart`: Added `bookingProvider = StreamProvider.autoDispose.family<Booking?, String>` backed by repository `watchBooking`.
  - `lib/data/booking/payments_mode.dart`: Added `realPaymentsProvider` (defaults to false in dev / tests).
  - `lib/core/widgets/app_bottom_sheet.dart`: Exported public `AppSheetFrame` widget for custom sheets with standard drag handle and title header.
  - `lib/l10n/app_vi.arb`: Added `escrowNoticeDeposit` localization key.
- **Test Harness**:
  - `test/support/fake_booking_repository.dart`: Added `nextError` injection, call tracking (`createCalls`, `depositCalls`, `fakeConfirms`, `checkCalls`), and `remove(String id)`.
  - Added unit and widget tests:
    - `test/core/widgets/app_bottom_sheet_test.dart`: `AppSheetFrame` height cap (88%) and `canDismiss: false` barrier test.
    - `test/data/booking/booking_rules_test.dart`: `daySlots`, `endTimeFor`, `depositFor` matches fixture, `bookingErrorOf`.
    - `test/data/booking/fake_booking_repository_test.dart`: `nextError`, `remove`, and call tracking.

### 2. A Task 10: Gallery Builder and Spec Synchronization
- **Spec (`docs/superpowers/specs/components/shared-components.md`)**:
  - Marked all Group A widgets as `· Đã có` (BookingCard, StatusTimeline, SignatureLoader, AsyncView, SectionHeader, ErrorState & OfflineBanner, AppSkeleton, EscrowNotice, MoneyBreakdown, PolicyTable, ReasonPicker, ProviderPicker, ConfirmSheet, CountdownRing & CountdownText, ChatBubble, ChatComposer, ConversationRow).
  - Marked Section 7 (Group A plan) as `đã xong`.
- **Component Gallery (`docs/design/ui-components.html`)**:
  - Regenerated via `python3 scripts/tools/build_ui_components.py` (32 components rendered).

## Verification
- `(cd packages/domain && npm test)`: 150/150 passed.
- `(cd app_flutter/firebase/functions && npm test && npm run typecheck)`: 59/59 passed, clean typecheck.
- `(cd app_flutter && flutter analyze)`: 0 issues found.
- `(cd app_flutter && flutter test --no-pub)`: 1501 passed.

## Gate Status
- Reaches Gate **G3** (Lane 2 merges 4b Task 1).
- Unblocks Lane 1 Step 4 (4b Tasks 2–8: S04.01–S04.04 Booking Sheet UI).
