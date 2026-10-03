# Handover ledger — 8e/6-L2 (Review Domain, Functions, Rules, Indexes & Data Layer)

Unit: `8e/6-L2` (Lane 2 Step 6)  
Branch: `plan/8e-6-L2-review-core-data`  
Target: `develop`  

## Scope Completed

### 1. Task 1: Review Domain Model, Ports & `submitReview` (`packages/domain/src/`)
- `review.ts`:
  - Types: `Review`, `ReviewPhoto`, `ReviewInput`, `RealShootPost`.
  - Input validation: `validateReviewInput` checking rating (1..5), text (10..1000 graphemes, emoji-aware), photo count (<= 10), photo path security (`posts/${customerId}/...`), and storage URLs against configured prefixes.
- `review_ports.ts`:
  - Defined `ReviewStore`, `ReviewTx`, `ReviewDeps` ports with strict read-before-write checking.
- `memory_review_store.ts`:
  - In-memory implementation of `ReviewStore` with read-before-write validation.
- `submit_review.ts`:
  - `submitReview`: Transactional use case that verifies booking existence and ownership (`customerId`), validates completed status (`not_eligible`), ensures single review per booking (`conflict`), updates booking status to `reviewed`, writes booking history event, stores the review, and optionally creates a `RealShootPost` when photos are attached.
- Exported all review modules in `packages/domain/src/index.ts`.
- Tests in `packages/domain/test/review.test.ts` and `packages/domain/test/submit_review.test.ts`.

### 2. Task 2: Domain Stats, Functions, Security Rules & Indexes
- `review_stats.ts`:
  - `addRating`: Computes updated average rating (rounded to 1 decimal place half up) and sum.
  - `countReview`: Ensures idempotent review counting for photographer stats.
  - `StatsStore` & `StatsTx` interfaces.
  - Tests in `packages/domain/test/review_stats.test.ts`.
- **Cloud Functions (`app_flutter/firebase/functions/src/`)**:
  - `config.ts`: Added `storageUrlPrefixes()` configuration helper.
  - `infra/review_firestore.ts`: `FirestoreReviewStore` and `FirestoreStatsStore` implementations with atomic batching and field mappers (`reviewToFirestore`, `reviewFromFirestore`, `realShootPostToFirestore`).
  - `infra/live_review.ts`: Live dependency adaptors for review submission and statistics.
  - `callables/review.ts`: `submitReview` callable with authentication check, domain error mapping to HttpsError, and private log hygiene.
  - `triggers/review_write.ts`: `onReviewWrite` trigger updating photographer aggregate stats and awarding badges (`awardBadgesAfterReview`).
  - Exported callable and trigger in `functions/src/index.ts`.
  - Tests in `functions/test/unit/review_firestore.test.ts`, `functions/test/unit/review_callable.test.ts`, and `functions/test/integration/review.test.ts`.
- **Firestore Security Rules (`app_flutter/firebase/firestore.rules`)**:
  - Authored via `firestore-rules-author` subagent.
  - Added rules for `reviews/{bookingId}`: read allowed for signed-in users, client write blocked (`false`).
  - Rules unit tests added in `app_flutter/firebase/rules-test/rules.test.mjs`.
- **Composite Indexes (`app_flutter/firebase/firestore.indexes.json`)**:
  - Added composite index for `reviews` collection: `photographerId` (ASCENDING) + `createdAt` (DESCENDING).

### 3. Task 3: App Data Layer (`app_flutter/lib/data/review/`)
- `review.dart`:
  - Data models: `Review`, `ReviewPhoto`, `ReviewPage`.
  - Deserialization with Timestamp/ISO string fallback and value equality (`==`, `hashCode`).
- `review_repository.dart`:
  - `ReviewRepository` contract with `watchReview`, `forPhotographer` (cursor pagination), and `submit`.
  - `ReviewErrorCode` and `ReviewException`.
- `firestore_review_repository.dart`:
  - Production implementation integrating Cloud Firestore and Cloud Functions.
  - Robust error code mapping (`mapFunctionsError`) supporting domain and Functions transport error codes.
- `review_providers.dart`:
  - Riverpod providers: `reviewRepositoryProvider` and `bookingReviewProvider`.
- **Test Support & Tests**:
  - `app_flutter/test/support/fake_review_repository.dart`: In-memory fake repository with pagination, error injection (`nextError`, `nextException`), and call tracking.
  - `test/data/review/review_mapping_test.dart`: 20 unit tests covering model serialization, equality, error mapping, and Firestore queries.
  - `test/data/review/fake_review_repository_test.dart`: Tests covering fake repository streaming, pagination, conflict handling, and error simulation.

## Verification
- `(cd packages/domain && npm test)`: 201/201 passed.
- `(cd packages/domain && npm run lint && npm run typecheck)`: 100% clean.
- `(cd app_flutter/firebase/functions && npm test)`: 67/67 passed.
- `(cd app_flutter/firebase/functions && npm run lint && npm run typecheck)`: 100% clean.
- `(cd app_flutter && flutter analyze)`: 0 issues found.
- `(cd app_flutter && flutter test test/data/review/)`: 19/19 passed.

## Gate Status
- Reaches Gate **G6** (Lane 2 merges 4e Tasks 1–3).
- Unblocks Lane 1 Step 7 (4e Tasks 4–5: Review bottom sheet & flow UI).
