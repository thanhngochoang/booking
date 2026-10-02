# Step 4e: Review and share S05.05, reviews on S03.01 Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle, blur-budget or performance steps; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and adds Functions. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** After a completed shoot the customer rates it (1–5 stars and a 10–1000 character comment), optionally shares up to 10 photos as a "Buổi chụp thật" post tagged with the photographer and the package, and the booking becomes `reviewed`; the review appears on the photographer's profile (S03.01 "Đánh giá") and updates their rating.

**Architecture:** The customer's photos upload straight to Storage under their own uid (existing `posts/{uid}/{postId}/{file}` rule, plan 3c), then one callable `submitReview` runs a single transaction: check the booking is the caller's and `completed` and has no review, write `reviews/{bookingId}`, create the `real_shoot` post when photos were shared, and move the booking to `reviewed` with a timeline event. A Firestore trigger `onReviewWrite` folds the rating into `photographers/{uid}.stats` (`rating`, `reviewCount`, `ratingSum`). Rules stay pure TypeScript in `packages/domain`; Functions are adapters; the app gets a `ReviewRepository`, S05.05 at `/b/:id/review` and a real reviews list on S03.01.

**Tech Stack:** TypeScript (domain, Functions v2), Firestore rules; Flutter, Riverpod 3, existing `MediaUploader` and image preparation from plan 3c.

**Spec:** `docs/superpowers/specs/screens/account.md` (S05.05); `docs/superpowers/specs/screens/discovery.md` (S03.01 "Đánh giá", "Chưa có đánh giá → empty có chữ rõ"); `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` §5 (`reviews/{bookingId}`, `posts` `kind: real_shoot`, `authorId` = customer, `bookingId`), §6 (`completed ──review──▶ reviewed`); `docs/superpowers/specs/data-model/domain-model.md` §2.3 (`Post`), §2.4 (`Review`), §6 invariants 6 and 8; `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3e.7 (signals; not built here); mock `docs/design/ui-mock.html` `data-code="S05.05"` and S03.01's reviews tab.

**Prerequisite:** plans 4a–4d merged into `flutter-rewrite`.

## Contract with plans 3c and 4a–4d

Task 1 Step 1 checks these exist (ledger and adapt any difference):

- Domain (4a): `Booking` (`id`, `customerId`, `photographerId`, `serviceId`, `serviceSnapshot`, `day`, `place`, `status`, `reviewedAt?`, `version`), `BookingEventRecord`, `graphemeCount`, `DomainError`, `Clock`, `IdGenerator`, `isId`; Functions `bookingFromFirestore`, `bookingToFirestore`, `BOOKINGS_COLLECTION`, `TRIGGER_OPTIONS`, `CALLABLE_OPTIONS`, `toHttpsError`, `CallableInput`, `db()`.
- App: `Booking`, `bookingProvider`, `BookingCard`/`BookingSummary` (4b), `bookingFeaturesProvider` and `DetailAction.review/.viewReview` wiring in `BookingDetailScreen._onAction` and `MyBookingsScreen._onReview` (4c), `MediaUploader` (`upload(PickedImage, storagePath:)` → `UploadEvent` with `UploadedMedia(url, storagePath)`), `imagePickerProvider` (`pick(max:)`), plan 3c's image preparation that yields `blurHash`, `width`, `height` for each picked photo (find it in `lib/features/create_post/` or `lib/data/media/`; reuse, do not duplicate), `PostKind.realShoot` (`lib/data/content/post_summary.dart`), `photographerProfileProvider`, `userRepositoryProvider`, `ReviewsSliver` (`lib/features/photographer_profile/widgets/profile_sections.dart`), `ScreenCodes.reviewAndShare` (S05.05), `newUlid` in the app (`lib/core/ulid.dart`).

## Global Constraints

- S05.05 (verbatim): "Back + "Buổi chụp thế nào?"; `BookingCard` thu gọn; 5 sao lớn (chạm chọn, giữ trượt chọn); ô nhận xét (bắt buộc, 10–1000 ký tự); section "Chia sẻ ảnh bạn thích" (tuỳ chọn, ≤ 10) với lưới ảnh chọn từ thư viện; nhắc "Ảnh hiện trong 'Buổi chụp thật' trên Trang chủ và hồ sơ {tên}, có tag nhiếp ảnh gia"; thanh dưới "Chỉ đánh giá" + "Gửi & chia sẻ {n} ảnh"."
- "ghi `reviews/{bookingId}` (một đánh giá/booking) và, nếu có ảnh, bài `posts` `kind=real_shoot` (`bookingId`, `serviceId`). Function `onReviewWrite` cập nhật `stats` và huy hiệu."
- "chưa chọn sao hoặc nhận xét ngắn → nút vô hiệu; đang tải ảnh → tiến độ từng ảnh; booking chưa `completed` → chặn; đã đánh giá → chuyển sang xem lại, không sửa."
- Strings: `s12_title` "Buổi chụp thế nào?", `s12_text` "Nhận xét", `s12_share` "Chia sẻ ảnh bạn thích", `s12_optional` "Tuỳ chọn", `s12_onlyReview` "Chỉ đánh giá", `s12_submitShare` "Gửi & chia sẻ {n} ảnh".
- "đánh giá lên hồ sơ NAG; bài chia sẻ mang nhãn "Buổi chụp thật" và link tới gói; một booking chỉ một đánh giá".
- Invariant 6: "`Review` chỉ tạo khi `Booking.status = completed`, một lần." Invariant 8: "`Post.serviceId` bắt buộc và thuộc cùng `photographerId`." `Rating` 1..5.
- Layering, strings, tokens, imports, commands and commit trailer as in plans 4a–4d; no Firebase in `lib/features/**`; one primary action per screen.

## Decisions (where the spec is silent)

1. **Who writes.** Clients never write `reviews` or `real_shoot` posts (rules deny); `submitReview` writes both in the booking's transaction, so a review without the `reviewed` status (or the reverse) cannot exist.
2. **Photo upload path.** The app picks a post id (ULID) before uploading and stores the files at `posts/{customerUid}/{postId}/{index}.jpg` (existing Storage rule: owner writes, signed-in users read, ≤ 8 MB). `submitReview` checks every `storagePath` starts with `posts/{callerUid}/{postId}/` and every `url` is a Firebase Storage download URL of this project's bucket for that path (prefix `https://firebasestorage.googleapis.com/v0/b/{bucket}/o/` + URL-encoded path; the bucket comes from the Functions config; in the emulator the host is `http://127.0.0.1:9199/` — accept both through a configured `storageUrlPrefixes` list).
3. **Post shape** (same fields the feed reads for `work` posts, plan 3b1): `{kind: 'real_shoot', authorId: customerId, photographerId, serviceId: booking.serviceId, bookingId, imageUrls, imageMeta: [{blurHash, w, h}], caption: <the review text>, location: {name: booking.place.name}, likeCount: 0, saveCount: 0, inPortfolio: false, createdAt}`. The caption is the review text (S02.02's "Chụp bởi … · gói …" line already renders real-shoot posts).
4. **Buttons.** With 0 photos the bottom bar shows one primary "Gửi đánh giá" (`reviewSubmit`); with ≥ 1 photo it shows outline "Chỉ đánh giá" (submits without the photos) + primary "Gửi & chia sẻ {n} ảnh". One primary per screen either way.
5. **Uploads first, submit after.** Photos upload when picked (progress per tile, retry on a failed tile, remove a tile). Submitting with photos waits until all are uploaded; a failed tile blocks "Gửi & chia sẻ" but not "Chỉ đánh giá". Files of removed tiles, and all files when the customer chooses "Chỉ đánh giá", are deleted with `MediaUploader.delete` (best effort).
6. **Stats.** `photographers/{uid}.stats`: `ratingSum` (int), `reviewCount` (int), `rating` = `round(ratingSum / reviewCount, 1)` (one decimal, half up). Reviews are never edited or deleted in v1, so the trigger only handles creates; it is idempotent through a marker `reviews/{bookingId}.countedAt` set in the same transaction.
7. **Badges** ("toast huy hiệu nếu vừa đạt") wait for the badges plan (S03.02): `onReviewWrite` has a clearly named no-op hook `awardBadgesAfterReview` that the badges plan fills.
8. **S03.01 reviews list.** Newest first, 10 per page, each row: customer avatar + display name (from `users/{uid}`), stars, date (`dd/MM/yyyy`), text (4 lines, "Xem thêm" expands), up to 3 photo thumbnails linking to the real-shoot post (`/p/{postId}`). Header line "{rating} · {n} đánh giá". `reviews/{bookingId}` is readable by any signed-in user (public on the profile); it holds no phone or contact data.
9. **Review doc**: `reviews/{bookingId}`: `customerId`, `photographerId`, `serviceId`, `rating`, `text`, `photoPostId?`, `createdAt`, `countedAt?` (set by the trigger).

## Review Focus

1. Double tap on "Gửi", or a retry after a timeout where the first call landed → one review, one post, one `reviewed` transition; the second call answers `conflict` and the app treats it as success by re-reading the booking. Pinned by Task 1 ("a second submit is a conflict and writes nothing") and Task 4 ("a conflict after a lost response shows the review as sent").
2. A forged request with someone else's storage paths or URLs, or more than 10 photos → refused, nothing written. Pinned by Task 1 ("photo paths must be the caller's own post folder", "more than 10 photos is invalid").
3. The trigger runs twice for the same review → the rating counts once. Pinned by Task 2 ("the same review is counted once").
4. A completed booking whose photographer later hid the package → the real-shoot post keeps the booking's `serviceId` (hidden packages stay valid, plan 2d1) and is created. Pinned by Task 1 ("a hidden package still gets the post").
5. A photo tile fails to upload → "Chỉ đánh giá" still works and deletes the uploaded files; "Gửi & chia sẻ" stays disabled until the tile is retried or removed. Pinned by Task 4 ("a failed tile blocks sharing but not review-only").

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/review.ts`, `review_ports.ts`, `memory_review_store.ts`, `submit_review.ts`, `review_stats.ts` (create) | rules, ports, reference adapter, use case, stats maths |
| `packages/domain/test/review*.test.ts` | tests |
| `app_flutter/firebase/functions/src/infra/review_firestore.ts`, `live_review.ts` (create) | adapters, wiring |
| `app_flutter/firebase/functions/src/callables/review.ts`, `src/triggers/review_write.ts` (create) | `submitReview`, `onReviewWrite` |
| `app_flutter/firebase/functions/src/config.ts`, `src/index.ts` (modify) | `storageUrlPrefixes`, exports |
| `app_flutter/firebase/functions/test/unit/review_*.test.ts`, `test/integration/review.test.ts` | tests |
| `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (modify) | `reviews` read, index `(photographerId, createdAt desc)` |
| `app_flutter/lib/data/review/review.dart`, `review_repository.dart`, `firestore_review_repository.dart`, `review_providers.dart` (create) | app data layer |
| `app_flutter/test/support/fake_review_repository.dart` (create) | fake |
| `app_flutter/lib/features/review/review_screen.dart`, `review_controller.dart`, `widgets/star_rating.dart`, `widgets/share_photo_grid.dart` (create) | S05.05 |
| `app_flutter/lib/features/photographer_profile/widgets/profile_sections.dart` (modify) | real `ReviewsSliver` |
| `app_flutter/lib/features/booking/booking_features.dart`, `booking_detail_screen.dart`, `my_bookings_screen.dart`, `lib/app/router.dart`, `lib/l10n/app_vi.arb` (modify) | flag, entry points, route, strings |
| `docs/superpowers/specs/2026-10-01-remaining-screens.md` (modify) | code table S05.05 |

---

### Task 1: Domain — review rules and `submitReview`

**Files:**
- Create: `packages/domain/src/review.ts`, `review_ports.ts`, `memory_review_store.ts`, `submit_review.ts`
- Modify: `packages/domain/src/index.ts`
- Test: `packages/domain/test/review.test.ts`, `packages/domain/test/submit_review.test.ts`

**Interfaces:**
- Produces:

```ts
export const REVIEW_TEXT_MIN = 10, REVIEW_TEXT_MAX = 1000, REVIEW_PHOTOS_MAX = 10;
export interface ReviewPhoto { readonly url: string; readonly storagePath: string; readonly blurHash: string | null; readonly w: number | null; readonly h: number | null; }
export interface ReviewInput { readonly bookingId: string; readonly rating: number; readonly text: string; readonly postId: string | null; readonly photos: readonly ReviewPhoto[]; }
export interface Review { readonly bookingId: string; readonly customerId: string; readonly photographerId: string; readonly serviceId: string;
  readonly rating: number; readonly text: string; readonly photoPostId: string | null; readonly createdAt: Date; readonly countedAt: Date | null; }
export interface RealShootPost { readonly id: string; readonly authorId: string; readonly photographerId: string; readonly serviceId: string;
  readonly bookingId: string; readonly imageUrls: readonly string[]; readonly imageMeta: readonly { blurHash: string | null; w: number | null; h: number | null }[];
  readonly caption: string; readonly locationName: string | null; readonly createdAt: Date; }

/** invalid_argument unless: rating integer 1..5; text 10..1000 graphemes after trim; photos 0..10;
 *  photos ⇒ postId is an id and every storagePath starts with `posts/{callerId}/{postId}/` and its url starts with
 *  one of [urlPrefixes] followed by the URL-encoded storagePath. */
export function validateReviewInput(raw: unknown, callerId: string, urlPrefixes: readonly string[]): ReviewInput;

export interface ReviewTx {
  getBooking(id: string): Promise<Booking | null>;
  getReview(bookingId: string): Promise<Review | null>;
  setBooking(b: Booking): void;
  addBookingEvent(e: BookingEventRecord): void;
  setReview(r: Review): void;
  createPost(p: RealShootPost): void;
}
export interface ReviewStore { runTransaction<T>(fn: (tx: ReviewTx) => Promise<T>): Promise<T>; }
export interface ReviewDeps { readonly reviews: ReviewStore; readonly clock: Clock; readonly ids: IdGenerator; readonly storageUrlPrefixes: readonly string[]; }

export function submitReview(deps: ReviewDeps, callerId: string, raw: unknown): Promise<{ review: Review; postId: string | null }>;
```

`submitReview` order (sample):

```ts
const input = validateReviewInput(raw, callerId, deps.storageUrlPrefixes);
return deps.reviews.runTransaction(async (tx) => {
  const booking = await tx.getBooking(input.bookingId);
  const existing = await tx.getReview(input.bookingId);          // all reads before writes
  if (booking === null) throw new DomainError('not_found');
  if (booking.customerId !== callerId) throw new DomainError('permission_denied');
  if (existing !== null || booking.status === 'reviewed') throw new DomainError('conflict');
  if (booking.status !== 'completed') throw new DomainError('not_eligible');
  const now = deps.clock.now();
  const postId = input.photos.length > 0 ? input.postId : null;
  // … setReview, createPost (when postId), setBooking({...booking, status: 'reviewed', reviewedAt, version + 1, updatedAt}),
  //   addBookingEvent({id: ids.newId(), bookingId, status: 'reviewed', at, actorId: callerId})
});
```

- [ ] **Step 1: Contract check** (see "Contract"); ledger differences.
- [ ] **Step 2: Failing tests:** `review.test.ts`: "rating must be an integer from 1 to 5"; "text needs 10 to 1000 graphemes after trimming (emoji count as one)"; "photo paths must be the caller's own post folder"; "urls must match a configured storage prefix and the encoded path"; "more than 10 photos is invalid"; "no photos means postId is ignored". `submit_review.test.ts` (memory store with a completed booking): "writes the review, moves the booking to reviewed with an event"; "with photos also creates the real-shoot post with the booking's service, place and the text as caption"; "a hidden package still gets the post"; "a second submit is a conflict and writes nothing"; "someone else's booking is permission_denied"; "a booking that is not completed is not_eligible"; "an unknown booking is not_found".
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → FAIL. **Step 4: Implement.** **Step 5: Run** → PASS; typecheck and lint clean.
- [ ] **Step 6: Commit** `feat(domain): submit a review and share a real shoot in one transaction`.

---

### Task 2: Domain stats + Functions + rules

**Files:**
- Create: `packages/domain/src/review_stats.ts`, `packages/domain/test/review_stats.test.ts`, `functions/src/infra/review_firestore.ts`, `functions/src/infra/live_review.ts`, `functions/src/callables/review.ts`, `functions/src/triggers/review_write.ts`, `functions/test/unit/review_firestore.test.ts`, `functions/test/unit/review_callable.test.ts`, `functions/test/integration/review.test.ts`
- Modify: `functions/src/config.ts`, `functions/src/index.ts`, `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/firestore.indexes.json`, `app_flutter/firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces:
  - `export interface PhotographerStatsPatch { ratingSum: number; reviewCount: number; rating: number }`; `export function addRating(current: { ratingSum?: unknown; reviewCount?: unknown }, rating: number): PhotographerStatsPatch` (missing or malformed counters start at 0; `rating` one decimal half up).
  - `export async function countReview(store: { runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T> }, bookingId: string, now: Date): Promise<'counted' | 'already'>` with `StatsTx { getReview(id); getPhotographerStats(uid); setPhotographerStats(uid, patch); markCounted(bookingId, at) }`.
  - Callable `submitReview({bookingId, rating, text, postId?, photos?: [{url, storagePath, blurHash?, w?, h?}]}) → {postId: string | null}`; trigger `onReviewWrite` on `reviews/{bookingId}` (create only) → `countReview`, then `awardBadgesAfterReview(...)` (no-op, Decision 7).
  - `storageUrlPrefixes()` in `config.ts`: `[`https://firebasestorage.googleapis.com/v0/b/${bucket}/o/`]` plus, when `FUNCTIONS_EMULATOR === 'true'`, `http://127.0.0.1:9199/v0/b/${bucket}/o/` (bucket from `process.env.STORAGE_BUCKET` or `${projectId}.firebasestorage.app`; check how the app's `firebase_options.dart` names it and match).
  - Rules: `match /reviews/{bookingId} { allow read: if signedIn(); allow write: if false; }`. Index: `reviews` (`photographerId` asc, `createdAt` desc).

- [ ] **Step 1: Failing tests:** `review_stats.test.ts`: "first review sets sum, count and rating"; "rating rounds to one decimal half up (4.25 → 4.3)"; "malformed counters start from zero"; "the same review is counted once" (memory stats store; second call `already`). Functions unit: "Review and RealShootPost map to the documents the feed reads (kind real_shoot, imageMeta, location.name, counters 0, Timestamp createdAt)"; "the callable maps conflict to aborted with details.code and never logs the text". Rules tests (not run): "reviews are readable by any signed-in user and writable by no client"; "clients still cannot create real_shoot posts". Integration (not run): complete a seeded booking → upload a fake image to the Storage emulator → `submitReview` → review, post and `reviewed` exist; stats updated by the trigger.
- [ ] **Step 2: Run** domain + functions unit → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; typecheck and lint clean in both packages.
- [ ] **Step 5: Commit** `feat(functions): submitReview callable, rating stats trigger, reviews rules`.

---

### Task 3: App data layer

**Files:**
- Create: `lib/data/review/review.dart`, `review_repository.dart`, `firestore_review_repository.dart`, `review_providers.dart`, `test/support/fake_review_repository.dart`
- Test: `test/data/review/review_mapping_test.dart`, `test/data/review/fake_review_repository_test.dart`

**Interfaces:**
- Produces:

```dart
@immutable class Review { String bookingId; String customerId; String photographerId; String serviceId;
  int rating; String text; String? photoPostId; DateTime createdAt; }
@immutable class ReviewPhoto { String url; String storagePath; String? blurHash; int? width; int? height; }
@immutable class ReviewPage { List<Review> items; Object? cursor; bool get hasMore; }
enum ReviewErrorCode { conflict, notEligible, permissionDenied, notFound, invalidArgument, network, unknown }
class ReviewException implements Exception { final ReviewErrorCode code; }
abstract class ReviewRepository {
  Stream<Review?> watchReview(String bookingId);
  Future<ReviewPage> forPhotographer(String photographerId, {Object? after, int limit = 10});
  Future<String?> submit({required String bookingId, required int rating, required String text, String? postId, List<ReviewPhoto> photos = const []}); // returns postId
}
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => FirestoreReviewRepository());
final bookingReviewProvider = StreamProvider.autoDispose.family<Review?, String>(...);
```

- [ ] **Step 1: Failing tests:** mapping round trip with `fake_cloud_firestore` (`Timestamp`, missing `photoPostId`); `forPhotographer` pages newest first by `createdAt` with a cursor; callable error mapping (`details.code` → `ReviewErrorCode`); fake: records submits, `nextError`, emits on `watchReview` after submit.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(review): review data layer, repository and fake`.

---

### Task 4: S05.05 review and share `/b/:id/review`

**Files:**
- Create: `lib/features/review/review_screen.dart`, `review_controller.dart`, `widgets/star_rating.dart`, `widgets/share_photo_grid.dart`
- Modify: `lib/app/router.dart`, `lib/features/booking/booking_features.dart` (`review: true`), `lib/features/booking/booking_detail_screen.dart`, `lib/features/booking/my_bookings_screen.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/review/review_screen_test.dart`, `test/features/review/star_rating_test.dart`, `test/features/review/review_controller_test.dart`, update 4c tests that asserted the review buttons hidden

**Interfaces:**
- Produces:
  - `GoRoute(path: '/b/:id/review', builder: (_, s) => ReviewScreen(bookingId: s.pathParameters['id']!))` (outside the shell).
  - `class StarRating extends StatelessWidget { const StarRating({required int value, ValueChanged<int>? onChanged, double size = 40}); }` — tap selects, horizontal drag across the stars selects continuously, `Semantics(slider)` with value "{n} trên 5 sao" and increase/decrease actions; read-only when `onChanged == null`.
  - `reviewControllerProvider` (autoDispose family by bookingId): `rating`, `text`, `List<SharedPhotoTile>` (`{local: PickedImage, state: uploading(fraction) | done(ReviewPhoto) | failed}`), `postId` (ULID made when the first photo is picked), `phase` (`idle`, `submitting`, `done`), `pick()`, `retry(i)`, `remove(i)`, `submit({required bool share})`.

Layout per mock: app bar Back + `reviewTitle`; `BookingCard(size: compact)` with status; `StarRating(size: 40)`; text field `reviewText` (min 10, max 1000, counter); section `reviewShare` + `reviewOptional` tag; grid of tiles (3 columns, add tile while < 10, progress ring per tile, retry/remove on failed, remove on done); hint `reviewShareHint(name)`; bottom bar per Decision 4. States: booking not `completed` and not `reviewed` → `EmptyState` `reviewNotYet` "Buổi chụp chưa hoàn thành nên chưa đánh giá được." with Back; already reviewed (`bookingReviewProvider` non-null) → read-only view: stars, text, "Đã chia sẻ {n} ảnh" with a link to the post, no inputs; submitting → buttons loading, inputs disabled; success → `context.go('/b/$id')` with SnackBar `reviewThanks` "Cảm ơn bạn đã đánh giá!"; `conflict` → treat as sent (re-read the review, show the read-only view); other errors → SnackBar, stay. `ScreenCode(ScreenCodes.reviewAndShare)`.

- [ ] **Step 1: Failing tests:**
  - star_rating: "tap selects the tapped star"; "dragging across selects continuously"; "semantics expose a slider with increase/decrease"; "read-only ignores taps".
  - controller: "submit is disabled without stars or with a short text"; "picking photos uploads each with progress under posts/{uid}/{postId}/"; "a failed tile blocks sharing but not review-only"; "review-only deletes uploaded files and sends no photos"; "remove deletes that file"; "at most 10 photos".
  - screen: "shows the compact card, stars, the comment field with a counter, and the share section"; "0 photos: one primary Gửi đánh giá"; "with photos: Chỉ đánh giá and Gửi & chia sẻ 2 ảnh"; "submitting sends rating, trimmed text, postId and the uploaded photos, then opens S05.02 with the thanks message"; "a conflict after a lost response shows the review as sent"; "a booking that is not completed shows chưa đánh giá được"; "an existing review shows the read-only view"; "S05.02 Đánh giá and S05.01 Đánh giá open this screen; S05.02 Xem đánh giá opens the read-only view"; "320 dp and 1.3× text, light and dark: no overflow; the bottom bar stays visible above the keyboard".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB: `reviewTitle`, `reviewText`, `reviewTextHint`, `reviewTextTooShort` "Viết ít nhất 10 ký tự", `reviewShare`, `reviewOptional`, `reviewShareHint` "Ảnh hiện trong 'Buổi chụp thật' trên Trang chủ và hồ sơ {name}, có tag nhiếp ảnh gia", `reviewOnly`, `reviewSubmitShare` "Gửi & chia sẻ {n} ảnh", `reviewSubmit` "Gửi đánh giá", `reviewNotYet`, `reviewThanks`, `reviewShared` "Đã chia sẻ {n} ảnh", `reviewStarsSemantics` "{n} trên 5 sao", `reviewUploadFailed` "Tải ảnh lỗi. Thử lại"). **Step 4: Run** → PASS (whole `test/features`).
- [ ] **Step 5: Commit** `feat(review): S05.05 rate the shoot and share photos as a real shoot`.

---

### Task 5: Reviews on S03.01, end-to-end, code table

**Files:**
- Modify: `lib/features/photographer_profile/widgets/profile_sections.dart`, `lib/features/photographer_profile/photographer_profile_screen.dart` (pass the photographer id to `ReviewsSliver`), `lib/l10n/app_vi.arb`, `docs/superpowers/specs/2026-10-01-remaining-screens.md`
- Test: `test/features/photographer_profile/reviews_sliver_test.dart`, `test/features/review/review_e2e_test.dart`

**Interfaces:**
- Produces: `final photographerReviewsProvider = AsyncNotifierProvider.autoDispose.family<PhotographerReviews, List<Review>, String>(...)` with `loadMore()`; `ReviewsSliver({required String photographerId})` rendering Decision 8 (keeps the existing empty state strings `profileNoReviewsTitle`/`Body` when the list is empty).

- [ ] **Step 1: Failing tests:** reviews sliver: "shows the newest reviews with name, stars, date and text"; "Xem thêm expands a long review"; "photo thumbnails open the real-shoot post"; "scrolling to the end loads the next page"; "no reviews keeps the empty state"; "320 dp, 1.3×". E2E (fakes for booking, review, media, profile): completed booking → S05.02 "Đánh giá" → 5 stars, text, 2 photos → "Gửi & chia sẻ 2 ảnh" → S05.02 shows `reviewed` with timeline step 7 done → S03.01 "Đánh giá" lists the review.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB `reviewsHeader` "{rating} · {n} đánh giá", `reviewsMore` "Xem thêm"). **Step 4: Run** whole suite + analyze → PASS.
- [ ] **Step 5: Update the code table:** S05.05 "✅ đã làm (4e) · huy hiệu chờ plan huy hiệu". Commit `feat(profile): reviews on S03.01; end-to-end review flow; mark S05.05 built`.

---

## Self-review notes

- Spec coverage: S05.05 layout, stars tap/drag, text 10–1000, ≤ 10 photos with per-photo progress, hint, two buttons (Tasks 4, Decision 4); one review per booking and `completed` only (Task 1); real-shoot post with `bookingId`, `serviceId`, photographer tag (Tasks 1–2); `onReviewWrite` stats (Task 2); review on the profile (Task 5); already reviewed → read-only (Task 4). Not covered by design: badges and their toast (badges plan, hook in Task 2), the push "Buổi chụp thế nào?" (notifications plan), "Đã giao ảnh" photographer action (not in any spec screen yet), analytics `review_submit` (no analytics port).
