# Handover ledger — 8c/4-L2 (Booking Events Read Rule, Features & Ticker)

Unit: `8c/4-L2` (Lane 2 Step 4)
Branch: `plan/8c-4-L2-booking-events-ticker`
Target: `develop`

## Scope Completed

### 1. Task 1: Contract check, events read rule, flags and ticker
- **Firestore Security Rules (`app_flutter/firebase/firestore.rules`)**:
  - Added read rule under `match /bookings/{bookingId}` for `match /events/{eventId}` allowing read access if signed in and the caller is `customerId` or `photographerId` of the parent booking document. Writes remain denied (`allow write: if false`).
- **Security Rules Unit Tests (`app_flutter/firebase/rules-test/rules.test.mjs`)**:
  - Added tests for `booking events are readable by both parties and nobody else` and `clients cannot write booking events` (asserting create, update, and delete are blocked).
- **Booking Event Data & Repository Layer (`app_flutter/lib/data/booking/`)**:
  - `booking.dart`: Added `bookingEventRecordFromFirestore` mapper function to map Firestore document data (`status`, `at`, `actorId`) to `BookingEventRecord`.
  - `booking_repository.dart`:
    - Defined `enum BookingRole { customer, photographer }`.
    - Defined `enum BookingAction { accept, decline, cancel, complete }` with `.code => name`.
    - Added `Stream<List<BookingEventRecord>> watchEvents(String bookingId)` to `BookingRepository` interface.
  - `firestore_booking_repository.dart`:
    - Implemented `watchEvents` query reading `bookings/{id}/events` subcollection ordered by `at`.
    - Made FirebaseFunctions initialization lazy so read-only / unit tests using `FakeFirebaseFirestore` do not require Firebase App initialization.
  - `booking_rules.dart`:
    - Added top-level functions `startsAtOf(Booking b)`, `endsAtOf(Booking b)`, `refundPercentAt(Booking b, DateTime now)`, and `refundAmountAt(Booking b, DateTime now)`.
  - `booking_providers.dart`:
    - Added `myBookingsProvider`: auto-disposed stream provider parameterized by `BookingRole` watching customer or photographer bookings for the authenticated user.
    - Added `bookingEventsProvider`: auto-disposed stream provider for `List<BookingEventRecord>`.
    - Added `bookingContactProvider`: auto-disposed stream provider for `BookingContactSnapshot?`.
- **Feature Flags & Clock Ticker (`app_flutter/lib/features/booking/`)**:
  - Created `booking_features.dart`:
    - `BookingFeatures` class with `chat`, `reschedule`, `review` flags.
    - `bookingFeaturesProvider` defaulting to all false.
    - `nowTickerProvider`: auto-disposed stream provider family emitting current time from `clockProvider` periodically based on the requested `Duration`.
- **Test Harness & Tests**:
  - `fake_booking_repository.dart`: Added `events` map, `_eventChanges` controller, `seedEvents`, `addEvent`, and generic `_StreamStartWith<T>` extension.
  - `test/data/booking/booking_events_test.dart`:
    - `watchEvents maps bookings/{id}/events oldest first`
    - `myBookingsProvider follows the role and the signed-in user`
    - `refundPercentAt at 48 h, 47 h 59 min, 24 h, 23 h 59 min`
  - `test/features/booking/booking_features_test.dart`:
    - `all flags are off by default`
    - `nowTickerProvider emits the clock now and again after each period`
  - `test/data/booking/fake_booking_repository_test.dart`:
    - Verified `watchEvents`, `seedEvents`, and `addEvent` on the fake repository.

## Verification
- `(cd packages/domain && npm test)`: 150/150 passed.
- `(cd app_flutter/firebase/functions && npm test && npm run typecheck)`: 59/59 passed, clean typecheck.
- `(cd app_flutter && flutter analyze)`: 0 issues found.
- `(cd app_flutter && flutter test --no-pub)`: 1509 passed.

## Gate Status
- Reaches Gate **G4** (Lane 2 merges 4c Task 1).
- Unblocks Lane 1 Step 5 (4c Tasks 2–7: S05.01–S05.03, S06.01–S06.03).
