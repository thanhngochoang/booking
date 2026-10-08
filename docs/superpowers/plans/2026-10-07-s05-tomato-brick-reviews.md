# S05 · Đánh giá cà chua/gạch (S05.05, S03.01, S03.02) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests (2026-10-02, user):** this plan touches `firestore.indexes.json` and adds rules tests. Write the rules tests and the Functions integration test; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Customers rate a shoot by throwing tomatoes (satisfied) or bricks (not satisfied) 1–10 times instead of giving 1–5 stars; brick needs at least one reason. The server computes intensity and the provider's `% cà chua`, which replaces the star average everywhere (cards, meta lines, profile tile, reviews tab with ratio bar and `VerdictBadge`, Find filter "🍅 90%+", ranking, "Được đánh giá cao" badge at ≥ 95% and ≥ 20 reviews). The review model already carries a subject, so a studio booking (#136) can hold a review of the photographer and one of the studio.

**Architecture:** Pure rules in `packages/domain` (`review.ts`: verdict, hits, reasons, subject, `intensityOf`, `validateReviewInput`, `isReviewable`; `review_stats.ts`: `addVerdict`, `countReview`; `badge.ts`: metric `tomatoPct`). Notification copy is #138's: `onReviewWrite` calls its hook `notifyReviewVerdict` (types `review_tomato`/`review_brick`). Functions stay thin: `submitReview` callable, `onReviewWrite` trigger (stats, verdict notice through the #138 hook, badges), Firestore mappers. The booking no longer moves to `reviewed`; the review sets `booking.reviewedAt` (a booking can be reviewed while still `approved`, plan `2026-10-07-s05-delivery-two-layer.md`). Flutter: `lib/data/review/` model and repository, `PhotographerSummary` with `tomatoPct`/`score`, `local_recommender.dart` on `smoothedScore`, new core widgets `VerdictIcon`, `VerdictPad`, `VerdictBadge`, `TomatoRatioBar`, `MetaLine`, and the S05.05 / S03.01 screens rebuilt to the mock.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 `onCall` + `onDocumentWritten`, `node --test`), Firestore indexes, PostgreSQL migration (`services/api`, vitest); Flutter, Riverpod 3, go_router, `flutter_svg` (already a dependency), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-06-tomato-brick-reviews-design.md` (all; §11 out of scope); `docs/superpowers/specs/2026-10-06-studio-members-design.md` §6 (subject model only); `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` B6 (review opens at `approved`, applied by the delivery plan); `docs/superpowers/specs/screens/account.md` S05.05; `screens/discovery.md` S03.01, S02.06; `components/shared-components.md`; main spec `2026-10-01-remaining-screens.md` §2 (rows S03.01, S03.02, S05.05), §huy hiệu; `data-model/domain-model.md`, `relational-schema.md`; mock `docs/design/ui-mock.html` `#S05.05`, `#S05.05-brick`, `#S03.01`, `#S03.01-reviews`, `#S03.01-new`, `#S03.02`, `#S02.06` (chip "🍅 90%+", Thu Hà "Mới · 3 đánh giá").

**Issue:** #130 (S05 · Theo dõi buổi chụp, bàn giao & đánh giá), items "Đánh giá cà chua/gạch thay sao" and "S03.01 + S03.02 theo cà chua (chuyển từ #133)". The delivery items are in `docs/superpowers/plans/2026-10-07-s05-delivery-two-layer.md`, which runs after this plan.

**Branch:** `plan/130-tomato-brick-reviews` from `origin/develop`; PR into `develop` titled `feat(review): tomato/brick reviews replace stars (S05.05, S03.01, S03.02) [#130]`.

**Execution wave:** 2 (cross-plan review 2026-10-07). **Blocked by:** #138 (S17, wave 1: the hook `notifyReviewVerdict` and the `review_tomato`/`review_brick` copy; if it has not merged, create that hook and those two catalogue rows exactly as S17's Contract defines them, Decision 5). **Owns:** the tomato/brick names every later plan consumes (`tomatoPct`, `hasTomatoPct`, `formatTomatoPct`, `MetaLine`, `minTomatoPct`, `smoothedScore`, `reviewDocId`, `subjectType/subjectId`, `stats.score`).

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. Each task's Step 1 re-checks its part; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `review.ts` (`REVIEW_TEXT_MIN = 10`, `REVIEW_TEXT_MAX = 1000`, `REVIEW_PHOTOS_MAX = 10`, `ReviewPhoto`, `ReviewInput {bookingId, rating, text, postId, photos}`, `Review {bookingId, customerId, photographerId, serviceId, rating, text, photoPostId, createdAt, countedAt}`, `RealShootPost`, `validateReviewInput(raw, callerId, urlPrefixes)`); `review_ports.ts` (`ReviewTx {getBooking, getReview(bookingId), setBooking, addBookingEvent, setReview, createPost}`, `ReviewStore`, `ReviewDeps {reviews, clock, ids, storageUrlPrefixes}`); `review_stats.ts` (`PhotographerStatsPatch {ratingSum, reviewCount, rating, punctualMentions}`, `mentionsPunctual`, `addRating`, `StatsTx`, `StatsStore`, `countReview(store, bookingId, now)`); `submit_review.ts` (sets `booking.status = 'reviewed'`, requires `completed`); `memory_review_store.ts`; `badge.ts` (`BADGE_METRICS` has `'rating'`; `top_rated` rule `rating >= 4.8`, `minSample reviewCount 20`; `snapshotText` "4,9 sao từ 58 đánh giá"); `notification.ts` (`review_new: meta('badges', 'system')`); `notification_render.ts` (`review_new {customer, rating, text}` → "{customer} đã đánh giá {rating} sao"); `formatDayShortVi`, `truncateGraphemes`; `booking.ts` (`BookingStatus` includes `'reviewed'`; `Booking.reviewedAt?`).
- Functions (`app_flutter/firebase/functions/src`): `callables/review.ts` (`handleSubmitReview`), `infra/review_firestore.ts` (`reviewToFirestore`, `reviewFromFirestore` defaults `rating` to 5, `FirestoreReviewStore`, `FirestoreStatsStore` writes `{stats: patch}` with `merge: true`), `infra/live_review.ts`, `triggers/review_write.ts` (`handleReviewWrite`, `notifyNewReview` with `review_new`), `index.ts:183-200` (`submitReview`, `onReviewWrite` on `reviews/{bookingId}`), `infra/badge_firestore.ts:114-147` (`GROUP_STATS` reads `stats.rating`), `seed/fixtures.ts:301` (An `stats {rating: 4.9, reviewCount: 58, ratingSum: 284, punctualMentions: 3}`), `:535` (seed inbox row `review_new` with `rating: 5`).
- Indexes: `photographers (onboardingComplete, stats.nextFreeDate, stats.rating desc, __name__)` in `firestore.indexes.json` (~line 63); `reviews (photographerId, createdAt desc)`.
- Rules: `match /reviews/{bookingId}` read signed-in, write false (`firestore.rules:628`). Unchanged by this plan except the doc id variable name.
- Self-hosted: `services/api/migrations/1790812800002_photographers.sql` (`rating_avg numeric(3,2)`), no `reviews` or `posts` table; `test/migrations.test.ts` `EXPECTED.photographers`; `src/db/database.ts:96` `rating_avg`. `services/dispatch/api/openapi.yaml:463-469` (`PhotographerCard.rating`).
- App data: `lib/data/review/review.dart` (`Review` with `int rating`, `Review.fromFirestore`, `ReviewPhoto`, `ReviewPage`), `review_repository.dart` (`ReviewRepository.submit({bookingId, rating, text, postId, photos})`, `ReviewErrorCode`), `firestore_review_repository.dart`, `review_providers.dart` (`reviewRepositoryProvider`, `bookingReviewProvider`); `test/support/fake_review_repository.dart`; `lib/data/content/photographer_summary.dart` (`ratingAvg`, `reviewCount`, `hasRating`), `firestore_photographer_repository.dart` (`photographerSummaryFrom` reads `stats.rating`; `freeThisWeek` orders by `stats.rating`), `fake_content_repositories.dart:244`, `content_repositories.dart:70` (invariant comment); `lib/data/recommendation/local_recommender.dart` (`smoothedRating`, `_quality`, `RecommendationSort.rating`, `ReasonCode.topRated`); `lib/data/booking/booking_status.dart`, `booking_rules.dart` (`tabForBooking`).
- App features/core: `lib/core/format.dart:82` `formatRating`; `lib/core/widgets/photographer_card.dart` (`PhotographerCardData.hasRating/ratingAvg`, `_meta` String join); `lib/features/discovery/photographer_meta.dart` (`areaRatingMeta` String); `lib/features/photo/photo_detail_screen.dart:36`; `lib/features/events/event_info_tab.dart:259` (`eventHostRoleRating`); `lib/features/find/find_controller.dart` (`FindFilters.minRating` double, `setMinRating`, filter at ~214), `find_screen.dart:220-242`, `find_sheets.dart:14` (`_ratings = [4.0, 4.5, 4.8]`); `lib/features/photographer_profile/widgets/profile_header.dart:153-158` (`StatTile` value `formatRating`/'—'), `profile_sections.dart:640-800` (`_ReviewsContent`, `reviewsHeader`, `_ReviewRow`, `ReviewTile` with `StarRating`); `lib/features/review/review_controller.dart` (`ReviewState.rating`, `setRating`, `canSubmitReviewOnly`, `submit({share})`), `review_screen.dart` (eligibility `completed || reviewed`, `StarRating`), `widgets/star_rating.dart`, `widgets/share_photo_grid.dart`; `lib/features/booking/booking_view_rules.dart` (`DetailAction.review` when `completed`, `viewReview` when `reviewed`; `timelineSteps` step7), `my_bookings_screen.dart:249-258` (review button on `completed`).
- Core: `StatTile`, `StatTileRow`, `AppChip`, `AppButton.primary/outline/text`, `AsyncView`, `EmptyState`, `BookingCard`, `AppIcon`/`AppIcons`, `AppColors`/`AppColorsDark`, `AppSpace`, `AppRadius`, `context.l10n`, `ScreenCode`, `ScreenCodes.reviewAndShare`; tokens via `design-system/tokens.json` → `dart run tool/gen_tokens.dart`.
- Gallery: `scripts/tools/build_ui_components.py` (`tile(anchor, name, api, use, real, skel)`) → `docs/design/ui-components.html`.

## Global Constraints

- Spec §2: D1 "Cà chua = hài lòng, gạch = không hài lòng." D2 "một phe". D3 "tối đa 10". D4 "Con số công khai là **% cà chua**". D5 "Gạch **công khai** như cà chua, nhưng bắt buộc chọn ít nhất một lý do." D6 "Server tính hệ số và thống kê (`packages/domain`); app chỉ gửi phe và số hit."
- §4.1 verbatim: `intensityOf(hits) = round2(0.4 + 0.6 · log10(hits)),  hits ∈ 1..10`; `REVIEW_HITS_MAX = 10`, `INTENSITY_FLOOR = 0.4`.
- §6.1: 0 reviews → hidden on cards; 1–4 → "Mới · {n} đánh giá"; ≥ 5 → "🍅 {tomatoPct}%". `TOMATO_PCT_MIN_REVIEWS = 5` (domain) and `kTomatoPctMinReviews = 5` (app).
- §7.1 verbatim: `smoothedScore(p) = (v · score + m · C) / (v + m),  v = reviewCount, m = 10, C = 0.6`.
- §5.2: "Hiệu ứng chỉ chạy khi chạm, không có animation lặp nền". §5.3: a11y labels "Ném cà chua, {n} trên 10" / "Ném gạch, {n} trên 10", increase/decrease actions, tap target ≥ 48 dp.
- Tokens: two new colours `tomato`, `brick` (light `#D93A2B` / `#A65A35`, dark `#FF5A47` / `#D2875E`, from the mock `:root`), used only for the two icons, the level track, `VerdictBadge` and the ratio bar; everything else keeps 60‑30‑10.
- CLAUDE.md: business rules in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1` (`REGION` in `config.ts`); Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; imports `package:photobooking/...`, features import `core/core.dart`; one `AppButton.primary` per screen; every screen/sheet in `ScreenCode`; `AsyncView` for every `AsyncValue`.
- Data conventions (`data-model/README.md`): opaque ids, UTC instants, integer VND, enums as string codes (`tomato`, `brick`, `late`, `not_as_portfolio`, `slow_delivery`, `attitude`, `price_changed`, `other`, `photographer`, `studio`).
- Commits: Conventional Commits, subject ends with `[#130]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Tests: Flutter one folder or file at a time: `flutter test --no-pub --timeout 60s <file or folder>` (never the whole suite in one command; bounded pumps, no endless animation or timer in widget tests); goldens tagged `golden` (CI excludes them); domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; `services/api` `npm test` needs Postgres (write, do not run if the sandbox has none; ledger it); rules-test and Functions integration suites are written, not run.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.

## Decisions

1. **No migration of star reviews (spec D7 wins).** There is no production project; the dev project `booking-c1922` is on Spark, so no Function ever wrote a review there (no `reviews` docs exist outside the emulators). Emulator data is reseeded (`scripts/backend-local.sh --fresh`). For a developer's saved emulator export that still holds star docs, readers are tolerant: a doc without `verdict` reads as `tomato` when `rating >= 4`, else `brick`, `hits = 1`, `reasons = []` (display only). Stats never mix: `addVerdict` derives `reviewCount = tomatoCount + brickCount`, so a legacy `reviewCount`/`rating`/`ratingSum` is ignored and the adapter deletes `stats.rating` and `stats.ratingSum` on the first verdict write. The seed is rewritten with tomato/brick data.
2. **Subject model now, studio later.** A review has `subjectType` (`photographer` | `studio`) and `subjectId` (the account whose stats it counts into); `photographerId` stays equal to `subjectId` so the existing profile query and index (`reviews (photographerId, createdAt desc)`) work for a studio's own tab. Doc id = `reviewDocId(bookingId, subjectType)`: `bookingId` for `photographer`, `${bookingId}_studio` for `studio` (studio spec §6). This plan only writes `photographer` reviews; #136 adds the studio block, the studio reason codes and the second doc in the same `submitReview` transaction.
3. **The booking keeps its status after a review.** `submitReview` sets `booking.reviewedAt` (and a booking event `reviewed`), not `status = 'reviewed'`, because the delivery plan opens reviews at `approved` and that state must still run its 48 h check; a studio booking also needs both reviews before it counts as reviewed. `reviewed` stays a readable legacy status. Eligibility is `isReviewable(status)` = `completed` in this plan; the delivery plan adds `approved`. Already reviewed = a review doc exists or `reviewedAt` is set or status is `reviewed` → `conflict`.
4. **Review snapshots for display.** The review stores `serviceName` and `bookingDay` (from the booking) so the reviews tab shows "12/10 · Chân dung 2 giờ" (mock `#S03.01-reviews`) and the notice says "buổi chụp {ngày}" without extra reads.
5. **Notification through #138's hook (cross-plan review finding 14).** #138 (S17, wave 1) owns the notification types, copy, targets and dedupe keys: it defines `review_tomato` / `review_brick` (category `badges`, tab `system`; spec §7.4 copy "Bạn nhận 🍅 ×{n} từ buổi chụp {ngày}" / "Có góp ý mới về buổi chụp {ngày}") and the hook `notifyReviewVerdict`. `onReviewWrite` calls that hook after `countReview` and **stops emitting `review_new`** (the type stays in `NOTIFICATION_TYPES` with its old star copy so old inbox rows still render; nothing emits it). This plan adds no notification copy. If #138 has not merged when Task 2 runs, create `notifyReviewVerdict` in `packages/domain/src/notification_hooks.ts` and the two catalogue rows exactly as S17's Contract defines them (signature in Contract → Trigger) and ledger it.
6. **Badge.** `BADGE_METRICS` replaces `'rating'` with `'tomatoPct'`; `top_rated`: `tomatoPct >= 95`, `minSample reviewCount >= 20`, description "Từ 95% cà chua với ít nhất 20 đánh giá", snapshot "{pct}% cà chua từ {n} đánh giá" (mock `#S03.02`: "97% cà chua từ 58 đánh giá"). The hook is live (`handleReviewWrite` evaluates badges), so this is a code change, not only a spec edit (spec §7.3 is stale on this point).
7. **Tomato glyph.** Wherever the spec writes 🍅, Flutter draws the SVG icon (mock `.tm`) next to the number through `VerdictIcon`/`MetaLine`; arb strings hold no emoji. Exceptions: push/inbox text rendered on the server (#138's `review_tomato` title keeps "🍅" as the spec writes it) and `reasonTopRated`, a text-only chip, which reads "{pct}% cà chua từ {count} đánh giá" (same wording as the S03.02 badge) instead of an emoji.
8. **Profile stat tile follows the mock, not §6.1's "0 → ẩn".** The tile is always there: ≥ 5 reviews "97%" with the icon and "58 đánh giá"; 0–4 "Mới" and "{n} đánh giá" (mock `#S03.01-new` shows "Mới / 0 đánh giá"). Cards and meta lines hide the part at 0 reviews (§6.1).
9. **S05.05 footer.** With no shared photo, one primary "Gửi đánh giá" as today (spec §5.1.7 "giữ nguyên"); with photos, outline "Chỉ đánh giá" + primary "Gửi & chia sẻ {n} ảnh". The `#S05.05-brick` frame draws both buttons without photos; treated as a frame simplification (Needs the owner 1).
10. **Find filter.** Chip "🍅 90%+" (icon + "90%+"), options 80 / 90 / 95; `FindFilters.minTomatoPct` (`int?`); a provider with < 5 reviews never passes a set filter. Sort "Đánh giá" uses `smoothedScore`.
11. **SQL.** `services/api` has no `reviews` or `posts` table, so the new migration only alters `photographers` (spec §8 columns). The `reviews` DDL stays the target in `relational-schema.md`, updated to the subject key `(booking_id, subject_type)`; the table is created by the slice that adds posts (Phase 2, #90).
12. **`freeThisWeek` ordering** moves from `stats.rating` to `stats.score` (index updated). Its server invariant becomes "`stats.score` is written (0 without reviews) whenever `stats.nextFreeDate` is written"; nothing writes `nextFreeDate` yet (audit), so no backfill. If #132's plan (`2026-10-07-s02-discover.md`, its Decision 6) is already merged, the query no longer orders by `stats.rating` (it uses `stats.reviewCount`): leave its query and index as they are and only remove what still names `stats.rating`.
13. **Arb key names** are camelCase versions of spec §5.5 (`reviewReason_late` → `reviewReasonLate`), the house style; there are no `s12_*` keys in the arb (spec §5.5 "giữ các khoá s12_*" has nothing to keep).
14. **Sibling plans that still read stars.** `2026-10-07-s15-s16-job-posts.md` (#139, quote trust line and "Đánh giá" sort, its Decision 21) and `2026-10-07-s13-s14-dispatch-provider.md` (#140, `ratingAvg` snapshots and score component, its Decision 23) say #130 swaps them. Step 1 of Tasks 2, 3 and 6 greps `ratingAvg|stats\.rating|'rating'|formatRating|★` in `packages/domain/src`, `app_flutter/firebase/functions/src` and `app_flutter/lib`; every hit that comes from those plans (when merged) moves to `tomatoPct`/`reviewCount`/`score` in the same task (dispatch score component = `(score + 1) / 2`, instant-booking spec note in the tomato spec §9; trust line = the `MetaLine` tomato part). When they are not merged (the expected case: in the execution waves of the cross-plan review this plan is wave 2, #139 and the #140 dispatch plan wave 4, the #140 customer plan `2026-10-07-s13-instant-customer.md` wave 5), those plans are already written against these names (cross-plan review finding 27: score component `(score + 1) / 2`, `tomatoPct`/`reviewCount` snapshots, `MetaLine` + `formatTomatoPct` instead of `formatRating`), and Task 7 only comments on #139 and #140 to confirm. `2026-10-07-s02-discover.md` Task 7 (#132) and `2026-10-07-s26-studio-members.md` (#136) consume this plan's names as written here (`tomatoPct`, `hasTomatoPct`, `formatTomatoPct`, `minTomatoPct`, `countReview(store, reviewId, now)`, `reviewDocId`, `subjectType/subjectId`).

## Needs the owner

1. `#S05.05-brick` shows "Chỉ đánh giá" + "Gửi đánh giá" with no photo picked; two buttons would do the same thing. Default: one primary "Gửi đánh giá" until a photo is picked (Decision 9).
2. (Closed by the cross-plan review: #138 owns the types and adds `review_tomato` / `review_brick`; this plan calls its hook, Decision 5.)

## Contract

### Data (Firestore)

`reviews/{reviewId}` (server-only writes; `reviewId = reviewDocId(bookingId, subjectType)`):

| Field | Type | Rule |
|---|---|---|
| `bookingId` | string | booking id |
| `subjectType` | `'photographer'` \| `'studio'` | this plan writes `photographer` |
| `subjectId` | string | stats owner |
| `photographerId` | string | = `subjectId` (profile query) |
| `customerId`, `serviceId` | string | as today |
| `serviceName` | string | snapshot of `booking.serviceSnapshot.name` |
| `bookingDay` | string `yyyy-MM-dd` | snapshot of `booking.day` |
| `verdict` | `'tomato'` \| `'brick'` | |
| `hits` | int 1–10 | |
| `intensity` | number (2 decimals) | server only, `intensityOf(hits)` |
| `reasons` | string[] | brick ≥ 1 distinct known codes; tomato `[]` |
| `text` | string | 10–1000 graphemes, trimmed |
| `photoPostId` | string \| null | as today |
| `createdAt`, `countedAt` | Timestamp, Timestamp \| null | as today |

No `rating` field is written.

`photographers/{uid}.stats` (server-only): `reviewCount`, `tomatoCount`, `brickCount`, `signedSum` (2 decimals), `tomatoPct` (int 0–100, 0 without reviews), `score` (3 decimals, −1…+1, 0 without reviews), `punctualMentions` (kept). `rating` and `ratingSum` are deleted on write.

`bookings/{id}.reviewedAt` set by `submitReview`; `status` unchanged.

### Domain (`packages/domain/src`)

```ts
// review.ts
export const REVIEW_HITS_MAX = 10;
export const INTENSITY_FLOOR = 0.4;
export const TOMATO_PCT_MIN_REVIEWS = 5;
export const VERDICTS = ['tomato', 'brick'] as const;
export type Verdict = (typeof VERDICTS)[number];
export const REVIEW_REASONS = ['late', 'not_as_portfolio', 'slow_delivery', 'attitude', 'price_changed', 'other'] as const;
export type ReviewReason = (typeof REVIEW_REASONS)[number];
export const REVIEW_SUBJECT_TYPES = ['photographer', 'studio'] as const;
export type ReviewSubjectType = (typeof REVIEW_SUBJECT_TYPES)[number];
export function intensityOf(hits: number): number;              // throws DomainError('invalid_argument') outside 1..10 or non-integer
export function reviewDocId(bookingId: string, subjectType: ReviewSubjectType): string;
export function isReviewable(status: BookingStatus): boolean;    // this plan: status === 'completed'
export interface ReviewInput { bookingId; verdict: Verdict; hits: number; reasons: readonly ReviewReason[]; text; postId: string | null; photos: readonly ReviewPhoto[] }
export interface Review {
  readonly id: string; readonly bookingId: string;
  readonly subjectType: ReviewSubjectType; readonly subjectId: string; readonly photographerId: string;
  readonly customerId: string; readonly serviceId: string; readonly serviceName: string; readonly bookingDay: string;
  readonly verdict: Verdict; readonly hits: number; readonly intensity: number; readonly reasons: readonly ReviewReason[];
  readonly text: string; readonly photoPostId: string | null; readonly createdAt: Date; readonly countedAt: Date | null;
}
export function validateReviewInput(raw: unknown, callerId: string, urlPrefixes: readonly string[]): ReviewInput; // ignores raw.intensity and raw.rating
// review_ports.ts — ReviewTx.getReview(reviewId) (was bookingId)
// review_stats.ts
export interface PhotographerStatsPatch { reviewCount; tomatoCount; brickCount; signedSum; tomatoPct; score; punctualMentions }
export function addVerdict(current: Record<string, unknown>, verdict: Verdict, intensity: number, punctual?: boolean): PhotographerStatsPatch;
export interface StatsTx { getReview(reviewId); getPhotographerStats(uid): Promise<Record<string, unknown> | null>; setPhotographerStats(uid, patch); markCounted(reviewId, at) }
export function countReview(store: StatsStore, reviewId: string, now: Date): Promise<'counted' | 'already'>; // counts into review.subjectId
// badge.ts — BADGE_METRICS: 'rating' → 'tomatoPct'
// notification copy: none here (#138, Decision 5)
```

`addRating` is removed (no caller left). `submitReview` keeps its signature `submitReview(deps, callerId, raw): Promise<{ review: Review; postId: string | null }>`.

Notice (consumed from #138, `packages/domain/src/notification_hooks.ts`; copy, target and dedupe are #138's):
```ts
export function notifyReviewVerdict(deps: NotifyDeps, e: {
  bookingId: string; subjectUserId: string; customerId: string;
  verdict: 'tomato' | 'brick'; hits: number; day: string /* yyyy-MM-dd */; text: string;
}): Promise<NotifyResult>; // review_tomato | review_brick to subjectUserId, target /u/{subjectUserId}?tab=reviews, dedupe review_{verdict}_{bookingId}_{subjectUserId}
```

### Callable

`submitReview` (unchanged name, region `asia-southeast1`): input `{ bookingId, verdict, hits, reasons, text, postId?, photos? }`; output `{ postId: string | null }`; errors (`details.code`): `invalid_argument` (any §4.2 case), `permission_denied` (not the customer / unauthenticated), `not_found`, `conflict` (already reviewed), `not_eligible` (not `isReviewable`).

### Trigger

`onReviewWrite` on `reviews/{reviewId}` (create only): `countReview` → `notifyReviewVerdict(liveNotifyDeps(), {bookingId, subjectUserId: review.subjectId, customerId, verdict, hits, day: review.bookingDay, text})` (#138's hook; a studio booking's second review doc (#136) sends its own call with the studio as subject) → `evaluateUserBadges` for subject and customer. No `review_new` is emitted any more.

### Indexes

Replace `stats.rating` by `stats.score` (DESCENDING) in the `photographers (onboardingComplete, stats.nextFreeDate, …, __name__)` index. `reviews (photographerId, createdAt desc)` unchanged.

### SQL (`services/api`)

New `services/api/migrations/1791676800001_tomato_brick.sql`: `alter table photographers drop column rating_avg, add column tomato_count int not null default 0, add column brick_count int not null default 0, add column signed_sum numeric(8,2) not null default 0, add column tomato_pct smallint not null default 0 check (tomato_pct between 0 and 100), add column score numeric(4,3) not null default 0 check (score between -1 and 1);` with a Down section that restores `rating_avg numeric(3,2) not null default 0`.

### App data (`lib/data`)

```dart
// lib/data/review/review.dart
enum Verdict { tomato, brick; String get code => name; static Verdict? fromCode(Object? c) }
enum ReviewReason { late('late'), notAsPortfolio('not_as_portfolio'), slowDelivery('slow_delivery'), attitude('attitude'), priceChanged('price_changed'), other('other'); final String code; static ReviewReason? fromCode(Object? c) }
const int kReviewHitsMax = 10;
const int kTomatoPctMinReviews = 5;
double intensityOf(int hits); // display mirror of the server rule (track width)
class Review { id, bookingId, subjectType ('photographer'|'studio'), subjectId, customerId, serviceId, serviceName?, bookingDay?, verdict, hits, intensity, reasons, text, photoPostId?, createdAt }
// Review.fromFirestore: legacy doc without verdict → Decision 1 mapping.
// review_repository.dart
Future<String?> submit({required String bookingId, required Verdict verdict, required int hits, required List<ReviewReason> reasons, required String text, String? postId, List<ReviewPhoto> photos = const []});
// photographer_summary.dart: remove ratingAvg/hasRating; add
final int tomatoPct; final double score; final int tomatoCount; final int brickCount; // reviewCount kept
bool get hasReviews => reviewCount > 0;
bool get hasTomatoPct => reviewCount >= kTomatoPctMinReviews;
// local_recommender.dart
double smoothedScore(PhotographerSummary p); // replaces smoothedRating
// find_controller.dart: FindFilters.minTomatoPct (int?), setMinTomatoPct(int?)
// booking_rules.dart
static bool canReview(Booking b);   // this plan: status == completed && reviewedAt == null
static bool isReviewed(Booking b);  // reviewedAt != null || status == reviewed
```

`lib/core/format.dart`: `formatRating` removed; `String formatTomatoPct(int pct)` → `'97%'`; `const int kVerdictHitsMax = 10`; `double verdictIntensity(int hits)` (display mirror of §4.1; core cannot import `lib/data`, so `lib/data/review/review.dart`'s `intensityOf` and `kReviewHitsMax` delegate to these).

### Core widgets (`lib/core/widgets`, exported from `core.dart`)

```dart
enum VerdictKind { tomato, brick }                 // core cannot import data; features map Verdict → VerdictKind
class VerdictIcon extends StatelessWidget { const VerdictIcon(this.kind, {super.key, this.size = 16, this.color}); } // SvgPicture.asset('assets/icons/tomato.svg'|'brick.svg'), colour = token unless given
class VerdictPad extends StatelessWidget {
  const VerdictPad({super.key, required this.kind, required this.hits, required this.onChanged, this.compact = false, this.enabled = true});
  final VerdictKind? kind; final int hits;               // kind null ⇔ hits 0
  final void Function(VerdictKind? kind, int hits) onChanged;
}
class VerdictLevel extends StatelessWidget { const VerdictLevel({super.key, required this.kind, required this.hits, required this.label, required this.onReset}); } // level label, "Làm lại", track (width = intensityOf), hint
class VerdictBadge extends StatelessWidget { const VerdictBadge({super.key, required this.kind, required this.hits}); }
class TomatoRatioBar extends StatelessWidget { const TomatoRatioBar({super.key, required this.tomatoCount, required this.brickCount}); }
sealed class MetaPart { const factory MetaPart.text(String text) = _TextPart; const factory MetaPart.tomato(int pct) = _TomatoPart; }
class MetaLine extends StatelessWidget { const MetaLine(this.parts, {super.key, this.style, this.maxLines = 1}); } // joins with ' · ', tomato part = VerdictIcon(12) + '{pct}%'
```

`PhotographerCardData`: `ratingAvg`/`hasRating` → `reviewCount`, `tomatoPct`.

Assets: `app_flutter/assets/icons/tomato.svg`, `brick.svg` (paths of the mock symbols `#i-tomato`, `#i-brick`, `viewBox="0 0 24 24"`, stroke `currentColor`, `fill="none"`, stroke-width 1.8), declared in `pubspec.yaml` `assets: - assets/icons/`.

### Routes

Unchanged: `/b/:id/review` (S05.05), `/u/:uid?tab=reviews` (S03.01 tab), `/u/:uid/badges` (S03.02).

### l10n (`lib/l10n/app_vi.arb`, exact Vietnamese)

New: `reviewTomato` "Hài lòng"; `reviewBrick` "Chưa hài lòng"; `reviewHits` "×{n}" (n int); `reviewTomatoLevel1` "Ổn"; `reviewTomatoLevel2` "Hài lòng"; `reviewTomatoLevel3` "Rất hài lòng"; `reviewTomatoLevel4` "Tuyệt vời!"; `reviewBrickLevel1` "Hơi tiếc"; `reviewBrickLevel2` "Chưa ưng"; `reviewBrickLevel3` "Thất vọng"; `reviewBrickLevel4` "Rất thất vọng"; `reviewReset` "Làm lại"; `reviewTapMore` "Chạm tiếp để tăng mức độ, tối đa 10"; `reviewPadLabel` "Đánh giá buổi chụp"; `reviewReasonsTitle` "Điều gì chưa ổn?"; `reviewReasonsMin` "Chọn ít nhất 1"; `reviewReasonLate` "Đến trễ"; `reviewReasonNotAsPortfolio` "Ảnh không như mẫu"; `reviewReasonSlowDelivery` "Giao ảnh chậm"; `reviewReasonAttitude` "Thái độ"; `reviewReasonPriceChanged` "Đổi giá"; `reviewReasonOther` "Khác"; `reviewTextHintTomato` "Điều bạn thích nhất ở buổi chụp"; `reviewTextHintBrick` "Kể rõ điều chưa ổn để thợ cải thiện"; `reviewNeedVerdict` "Chọn cà chua hoặc gạch"; `reviewNeedReason` "Chọn ít nhất một lý do"; `reviewA11yTomato` "Ném cà chua, {n} trên 10"; `reviewA11yBrick` "Ném gạch, {n} trên 10"; `tomatoNew` "Mới"; `tomatoNewReviews` "Mới · {count} đánh giá"; `reviewsRatioCounts` "{tomato} cà chua · {brick} gạch · {count} đánh giá"; `reviewsRatioSemantics` "{tomato} cà chua, {brick} gạch"; `verdictBadgeTomato` "Cà chua, {n} trên 10"; `verdictBadgeBrick` "Gạch, {n} trên 10"; `findTomatoMin` "{pct}%+"; `findTomatoTitle` "Tỷ lệ hài lòng".

Changed text: `reasonTopRated` "{pct}% cà chua từ {count} đánh giá" (placeholders `pct` int, `count` int); `reviewsHeader` removed (replaced by the ratio header); `eventHostRoleRating` removed (the event host line is built with `MetaLine`: `eventHostRole` + tomato part); `findRatingMin` removed; `reviewStarsSemantics` removed. `reviewTextHint` stays for nothing → removed.

Server strings (domain): badge description "Từ 95% cà chua với ít nhất 20 đánh giá", snapshot "{pct}% cà chua từ {n} đánh giá". Notification copy: #138's (`review_tomato`, `review_brick`).

## Review Focus

1. **A star doc or star stats left in a developer's emulator export** — the reviews tab and the profile must not crash or show "0%"; `addVerdict` must not add a new verdict onto the legacy `reviewCount` (Decision 1). Pinned in Task 1 (`addVerdict ignores a legacy reviewCount`) and Task 3 (`a legacy star doc reads as a verdict`).
2. **`stats` overwritten instead of merged** — `FirestoreStatsStore` writes `{stats: patch}` with `merge: true`; if the patch writer ever switches to `set` without merge, `stats.completedCount`, `responseMinutes`, `nextFreeDate`, `skillsCompleteness` vanish. Pinned in Task 2 (`stats write keeps the other stats fields`).
3. **Double counting on a retried trigger** — the `countedAt` guard must use the review doc id, including the future `{bookingId}_studio` id. Pinned in Task 1 (`countReview counts a studio review into the studio`) and Task 2 (`the trigger counts once when retried`).
4. **A provider with 3 glowing reviews outranking one with 80 good ones** in "Đánh giá" sort and in Find with "🍅 90%+" — `smoothedScore` and the < 5 exclusion. Pinned in Task 3.
5. **Fast tapping and screen readers on `VerdictPad`** — the 11th tap must not change anything, switching side resets to 1, and TalkBack increase/decrease must work without tapping. Pinned in Task 4 (`semantics increase and decrease`) and Task 5.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` (Firestore: nam5 upper bound, Singapore "chưa xác nhận").

**Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s.

- **Per user action.** Submit a review: callable `submitReview` (already exists) = 2 reads (booking, review) + 3–4 writes (review, booking `reviewedAt`, booking event, optional post) — same as today. Trigger `onReviewWrite` (exists): 2 reads + 2 writes (stats, `countedAt`) + notice (~2 reads prefs/devices, 2 writes inbox row and unread count) + badge evaluation (~6 reads, ≤ 2 writes) — same as today. Open the reviews tab: `get` page of 10 (+1 look-ahead) = 11 reads, paginated, no listener (unchanged). Profile tile, cards, Find filter, ranking: 0 extra reads (numbers live on `photographers/{uid}.stats`, already read). S05.05 open: existing booking listener + review listener (1 read each).
- **New functions / jobs:** none. Calls: `submitReview` ≈ 60% of finished bookings = 180/month at 1,000 MAU (300 bookings), 1,800/month at 10,000 MAU (3,000 bookings) — unchanged volume.
- **Indexes:** one composite index changes a field (`stats.rating` → `stats.score`); no new index.
- **Storage:** none new (two SVG icons ship in the app bundle).
- **Paid APIs:** none.
- **Conclusion:** +$0.00/month at (b) 1,000 MAU and +$0.00/month at (c) 10,000 MAU (the review flow already exists; field changes only). Compared with §12 tables: no change.

## Tasks

### Task 1: Domain — verdicts, intensity, stats, subject, badge and notice

**Files:**
- Modify: `packages/domain/src/review.ts`, `review_ports.ts`, `review_stats.ts`, `submit_review.ts`, `memory_review_store.ts`, `badge.ts`, `index.ts` (exports unchanged module list; new names come through `export *`)
- Test: `packages/domain/test/review.test.ts`, `review_stats.test.ts`, `submit_review.test.ts`, `badge.test.ts`

**Interfaces:**
- Consumes: `DomainError`, `isId`, `graphemeCount`, `BookingStatus`, `Booking`, `formatDayShortVi`, `truncateGraphemes`.
- Produces: everything in Contract → Domain.

- [ ] **Step 1:** Contract check of the domain names above; ledger any difference.
- [ ] **Step 2: Failing tests.**
  - `review.test.ts`: `intensityOf matches the spec table` (1→0.40, 2→0.58, 3→0.69, 5→0.82, 7→0.91, 10→1.00); `intensityOf refuses 0, 11, 2.5 and NaN with invalid_argument`; `validateReviewInput accepts tomato ×7 without reasons`; `accepts brick ×3 with [late, slow_delivery]`; `refuses an unknown verdict`; `refuses hits 0, 11, 3.5, "3"`; `refuses brick without reasons`; `refuses brick with an unknown reason`; `refuses brick with a duplicate reason`; `refuses tomato with reasons`; `ignores a client intensity and a client rating` (result has no such field); `keeps the old text and photo checks` (9 graphemes → invalid; 1001 → invalid; bad photo path → invalid); `reviewDocId: photographer → bookingId, studio → {bookingId}_studio`; `isReviewable is true only for completed`.
  - `review_stats.test.ts`: `addVerdict from empty stats` (tomato 0.91 → `{reviewCount 1, tomatoCount 1, brickCount 0, signedSum 0.91, tomatoPct 100, score 0.91}`); `mixed verdicts` (56 tomato ×1.0 + 2 brick ×0.69 → `tomatoPct 97`, `score` = round3((56 − 1.38)/58) = 0.942); `rounding of tomatoPct` (2 of 3 → 67); `addVerdict ignores a legacy reviewCount` (`{reviewCount: 58, rating: 4.9, ratingSum: 284}` + one tomato → `reviewCount 1`); `corrupt fields count as 0` (strings, negatives, NaN); `punctual mention increments punctualMentions`; `countReview counts once` (second call → `'already'`); `countReview counts a studio review into the studio` (review with `subjectType studio`, `subjectId studio-1` → stats written for `studio-1`); `countReview skips a missing review`.
  - `submit_review.test.ts`: `stores verdict, hits, server intensity, reasons, subject, serviceName and bookingDay`; `sets booking.reviewedAt and keeps booking.status completed`; `adds a booking event with status reviewed`; `refuses a second review with conflict` (doc exists); `refuses when reviewedAt is set with conflict`; `refuses a legacy reviewed booking with conflict`; `refuses a booking that is not completed with not_eligible` (`upcoming`); `refuses another customer with permission_denied`; `creates the real-shoot post with photos as before`.
  - `badge.test.ts`: `top_rated needs tomatoPct >= 95 and reviewCount >= 20` (94/30 → no; 95/19 → no; 95/20 → yes); `top_rated snapshot reads "97% cà chua từ 58 đánh giá"`; `progress of top_rated counts reviews toward 20`; `BADGE_METRICS has no rating`.
  - (No notification copy test here: `review_tomato`/`review_brick` rendering is pinned by #138's `notification_render.test.ts`.)
- [ ] **Step 3:** `cd packages/domain && npm test` — the new tests fail.
- [ ] **Step 4: Implement.** Hard parts:
  ```ts
  const round2 = (x: number) => Math.round(x * 100) / 100;
  export function intensityOf(hits: number): number {
    if (!Number.isInteger(hits) || hits < 1 || hits > REVIEW_HITS_MAX) throw new DomainError('invalid_argument');
    return round2(INTENSITY_FLOOR + (1 - INTENSITY_FLOOR) * Math.log10(hits));
  }
  export function addVerdict(current: Record<string, unknown>, verdict: Verdict, intensity: number, punctual = false): PhotographerStatsPatch {
    const n = (k: string) => (typeof current[k] === 'number' && Number.isFinite(current[k]) && (current[k] as number) >= 0 ? (current[k] as number) : 0);
    const tomatoCount = Math.trunc(n('tomatoCount')) + (verdict === 'tomato' ? 1 : 0);
    const brickCount = Math.trunc(n('brickCount')) + (verdict === 'brick' ? 1 : 0);
    const reviewCount = tomatoCount + brickCount; // never the legacy reviewCount
    const prevSigned = typeof current.signedSum === 'number' && Number.isFinite(current.signedSum) ? current.signedSum : 0;
    const signedSum = round2(prevSigned + (verdict === 'tomato' ? intensity : -intensity));
    return { reviewCount, tomatoCount, brickCount, signedSum,
      tomatoPct: Math.round((100 * tomatoCount) / reviewCount),
      score: Math.round((signedSum / reviewCount) * 1000) / 1000,
      punctualMentions: Math.trunc(n('punctualMentions')) + (punctual ? 1 : 0) };
  }
  ```
  `submitReview`: validate → transaction: read booking and `getReview(reviewDocId(bookingId, 'photographer'))`, order of refusals `not_found` → `permission_denied` → `conflict` (doc exists, `reviewedAt`, or status `reviewed`) → `not_eligible` (`!isReviewable`); write the review with `intensity: intensityOf(hits)`, `subjectType 'photographer'`, `subjectId = photographerId = booking.photographerId`, `serviceName = booking.serviceSnapshot.name`, `bookingDay = booking.day`; booking `{...booking, reviewedAt, version + 1, updatedAt}` (status unchanged); booking event `status: 'reviewed'`. `countReview` reads `review.subjectId`. Update `MemoryReviewStore` (keyed by review id). Remove `addRating`.
- [ ] **Step 5:** `cd packages/domain && npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): tomato/brick verdicts, intensity and % cà chua stats [#130]` (TonyH trailer).

### Task 2: Functions, indexes, seed, SQL and API contract

**Files:**
- Modify: `app_flutter/firebase/functions/src/infra/review_firestore.ts`, `src/callables/review.ts` (only if the result type changes; it should not), `src/triggers/review_write.ts`, `src/index.ts` (trigger path param `{reviewId}`), `src/infra/badge_firestore.ts`, `seed/fixtures.ts`, `seed/README.md`, `test/unit/review_firestore.test.ts`, `test/unit/review_callable.test.ts`, `test/unit/badge_metrics.test.ts`, `test/unit/seed_fixtures.test.ts`, `test/unit/notification_mapping.test.ts` (if it asserts `review_new`), `test/integration/review.test.ts`; `app_flutter/firebase/firestore.indexes.json`; `app_flutter/firebase/rules-test/rules.test.mjs`; `services/api/src/db/database.ts`, `services/api/test/migrations.test.ts`; `services/dispatch/api/openapi.yaml`
- Create: `services/api/migrations/1791676800001_tomato_brick.sql`

**Interfaces:**
- Consumes: Task 1 domain names.
- Produces: `reviewToFirestore(r: Review)` (fields of Contract → Data; no `rating`), `reviewFromFirestore(id, d)` (legacy mapping of Decision 1; `bookingId` from the field, falling back to the doc id), `FirestoreStatsStore.setPhotographerStats(uid, patch)` writing `{ stats: { ...patch, rating: FieldValue.delete(), ratingSum: FieldValue.delete() } }` with `merge: true`; `handleReviewWrite(input: { reviewId; before; after }, store, now, badges?)`; `FirestoreBadgeMetricsReader` reads `stats.tomatoPct` for metric `tomatoPct`.

- [ ] **Step 1:** Contract check of the Functions files above; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `review_firestore.test.ts`: `reviewToFirestore writes verdict, hits, intensity, reasons, subject fields and no rating`; `reviewFromFirestore reads a verdict doc`; `reviewFromFirestore maps a legacy rating 5 doc to tomato ×1 and rating 2 to brick ×1`; `stats write keeps the other stats fields` (fake `set` receives `merge: true` and a nested `stats` map with only patch keys plus the two deletes).
  - `review_callable.test.ts`: `submitReview passes verdict input through and returns postId`; `an unknown verdict is invalid-argument with details.code invalid_argument`; `an upcoming booking is failed-precondition with details.code not_eligible`.
  - `review_write` (in `review_retry_reminders.test.ts` or a new `review_write.test.ts`): `the trigger calls notifyReviewVerdict with subjectUserId, verdict, hits, day and text and emits no review_new`; `the trigger counts once when retried` (second invocation → `'already'`, notice deduped by #138's key `review_{verdict}_{bookingId}_{subjectUserId}`).
  - `badge_metrics.test.ts`: `tomatoPct and reviewCount come from stats` (`{tomatoPct: 97, reviewCount: 58}`); `a photographer without stats has tomatoPct null`.
  - `seed_fixtures.test.ts`: `An's stats are 56 tomato and 2 brick (97%) and his seeded reviews are verdict docs`; `Cúc has 3 reviews and no tomatoPct shown (under 5)`; `Dũng has 6 reviews with 3 bricks, each brick with a reason`; `no seed doc carries rating`; `the seed inbox review row uses the verdict payload`.
  - `migrations.test.ts`: `EXPECTED.photographers` without `rating_avg`, with `tomato_count`, `brick_count`, `signed_sum`, `tomato_pct`, `score` at the end; `tomato_pct check refuses 101`; `score check refuses 1.5`.
  - `rules.test.mjs` (written, not run): `a customer cannot create reviews/{bookingId} with a verdict`; `a customer cannot write photographers/{uid}.stats.tomatoPct`.
  - `test/integration/review.test.ts` (written, not run): submit a brick review on the emulator → doc has `intensity 0.69`, stats updated, inbox row title "Có góp ý mới về buổi chụp …".
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` — new tests fail.
- [ ] **Step 4: Implement.** Mapping, trigger (`notifyNewReview` is replaced by a call to #138's `notifyReviewVerdict` with `day: after.bookingDay`; #138 renders `formatDayShortVi`, the target and the dedupe key), badge reader, index change (`stats.score` DESCENDING), SQL migration (Contract → SQL) and `database.ts` (`tomato_count: Def<number>`, `brick_count: Def<number>`, `signed_sum: Def<string>` (numeric), `tomato_pct: Def<number>`, `score: Def<string>`; remove `rating_avg`), `openapi.yaml` `PhotographerCard`: replace `rating` by `tomatoPct: {type: integer, nullable: true, description: "null under 5 reviews"}` and add `reviewCount: {type: integer}` to `required`. Seed: three An reviews on synthetic booking ids `seed-review-an-1..3` (two tomato ×10/×6, one brick ×3 `[late, slow_delivery]`, texts from mock `#S03.01-reviews`, customers Lan/Minh), An stats `{reviewCount 58, tomatoCount 56, brickCount 2, signedSum 54.62, tomatoPct 97, score 0.942, punctualMentions 3}`; Cúc 3 tomato reviews (stats folded with `addVerdict`); Dũng 6 reviews (3 tomato, 3 brick with reasons, stats folded with `addVerdict`); seed inbox row `{type: 'review_new', customer: 'Lan (seed)', verdict: 'tomato', hits: 7, day: 'T7 27/9', text: 'Rất hài lòng, đúng giờ.'}`. `seed-booking-completed-recent` stays unreviewed (Lan can review it). `seed/README.md`: a "Reviews (tomato/brick)" table (An 97% from 58, Cúc "Mới · 3 đánh giá", Dũng 50% with bricks) and the line "Run `scripts/backend-local.sh --fresh` once: star reviews in saved emulator data are not converted."
- [ ] **Step 5:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. `services/api`: run `npm test` only if Postgres is available in the sandbox, else ledger "written, not run". Ledger: rules tests and integration test written, not run.
- [ ] **Step 6: Commit** `feat(functions): store tomato/brick reviews, % cà chua stats and the verdict notice [#130]`.

### Task 3: App data, ranking and Find filter

**Files:**
- Modify: `app_flutter/lib/data/review/review.dart`, `review_repository.dart`, `firestore_review_repository.dart`, `lib/data/content/photographer_summary.dart`, `firestore_photographer_repository.dart`, `fake_content_repositories.dart`, `content_repositories.dart` (invariant comment), `lib/data/recommendation/local_recommender.dart`, `lib/data/booking/booking_rules.dart`, `lib/core/format.dart`, `lib/features/find/find_controller.dart`, `lib/l10n/app_vi.arb` (`reasonTopRated`), `test/support/fake_review_repository.dart`, `test/support/content_fixtures.dart`, `test/support/discovery_world.dart`, `test/support/booking_world.dart`, `test/support/event_world.dart`
- Test: `test/data/review/review_mapping_test.dart`, `test/data/review/fake_review_repository_test.dart`, `test/data/content/firestore_photographer_repository_test.dart`, `test/data/recommendation/local_recommender_test.dart`, `test/data/recommendation/recommendation_contract.dart`, `test/features/find/find_controller_test.dart`, `test/data/booking/booking_rules_test.dart` (create if absent), `test/core/format_test.dart` (or the existing format test)

**Interfaces:**
- Consumes: Contract → Data (Firestore field names).
- Produces: Contract → App data (`Verdict`, `ReviewReason`, `kTomatoPctMinReviews`, `intensityOf`, `Review`, `ReviewRepository.submit`, `PhotographerSummary.tomatoPct/score/tomatoCount/brickCount/hasReviews/hasTomatoPct`, `smoothedScore`, `FindFilters.minTomatoPct`, `setMinTomatoPct`, `BookingRules.canReview/isReviewed`, `formatTomatoPct`); `fixturePhotographer(..., int tomatoCount = 0, int brickCount = 0)` computing `tomatoPct`/`score` like the server.

- [ ] **Step 1:** Contract check (app data); ledger differences.
- [ ] **Step 2: Failing tests.**
  - mapping: `Review.fromFirestore reads verdict, hits, intensity, reasons and subject`; `unknown reason codes are dropped`; `a legacy star doc reads as a verdict` (rating 5 → tomato ×1; rating 2 → brick ×1); `submit sends verdict code, hits, reason codes and no rating` (fake `FirebaseFunctions` captures the map).
  - summary: `photographerSummaryFrom reads tomatoPct, score, tomatoCount, brickCount from stats`; `hasTomatoPct needs 5 reviews`; `legacy stats with rating and no counts read as no reviews`.
  - `intensityOf (app mirror) matches the server table`.
  - recommender: `smoothedScore pulls a 3-review provider toward 0.6` (3 × score 1.0 → (3 + 6)/13 = 0.692); `80 reviews at 0.9 beat 3 reviews at 1.0 in rating sort`; `topRated reason needs reviewCount >= 10 and tomatoPct >= 95` with text "97% cà chua từ 58 đánh giá"; `quality stays within 0..1 with negative score` (score −1 → clamped).
  - find: `minTomatoPct 90 keeps 92% with 12 reviews and drops 88%`; `minTomatoPct drops a provider with 4 reviews even at 100%`; `no filter keeps providers without reviews`; existing look-ahead test still green.
  - booking rules: `canReview is true for completed without reviewedAt`; `false after reviewedAt`; `isReviewed is true for legacy status reviewed`.
  - `formatTomatoPct(97)` → `97%`; `verdictIntensity` table (1 → 0.40, 7 → 0.91, 10 → 1.00).
- [ ] **Step 3:** Run the new tests (one folder at a time); they fail.
- [ ] **Step 4: Implement.** `local_recommender.dart`:
  ```dart
  double smoothedScore(PhotographerSummary p) {
    const m = 10.0, c = 0.6;
    final v = p.reviewCount.toDouble();
    return (v * p.score + m * c) / (v + m);
  }
  double _quality(PhotographerSummary p) =>
      _unit(smoothedScore(p) + 0.05 * (math.log(1 + p.completedCount) / math.ln10));
  ```
  `freeThisWeek` orders by `stats.score` (descending) and its defensive re-sort compares `score`; fake content repositories sort by `score`. Remove `formatRating` and `PhotographerSummary.ratingAvg/hasRating` (compile errors guide the remaining callers to Task 6; keep the app compiling in this task by switching those callers to `hasReviews`/`tomatoPct` with plain text, Task 6 then does the visual). Update fixtures (Decision 1 legacy branch covered by a test only).
- [ ] **Step 5:** `flutter analyze` clean; run `test/data`, `test/features/find`, `test/core` folders one by one; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(data): tomato/brick reviews, % cà chua on summaries, smoothed score and Find filter [#130]`.

### Task 4: Tokens, icons and the shared widgets (gallery and widget docs included)

**Files:**
- Create: `app_flutter/assets/icons/tomato.svg`, `app_flutter/assets/icons/brick.svg`, `app_flutter/lib/core/widgets/verdict_icon.dart`, `verdict_pad.dart`, `verdict_badge.dart`, `tomato_ratio_bar.dart`, `meta_line.dart`; tests `test/core/widgets/verdict_icon_test.dart`, `verdict_pad_test.dart`, `verdict_badge_test.dart`, `tomato_ratio_bar_test.dart`, `meta_line_test.dart`; goldens under `test/core/widgets/goldens/`
- Modify: `design-system/tokens.json` (semantic + dark `tomato`, `brick`), `design-system/tokens.css` (if the generator does not write it, mirror by hand), `app_flutter/lib/core/theme/tokens.g.dart` (generated only), `app_flutter/lib/core/core.dart` (exports), `app_flutter/pubspec.yaml` (`assets/icons/`), `lib/l10n/app_vi.arb` (pad, badge, ratio keys of Contract → l10n), `docs/superpowers/specs/components/shared-components.md`, `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html` (regenerated)

**Interfaces:**
- Consumes: `AppColors`/`AppColorsDark` (new `tomato`, `brick`); `verdictIntensity`, `kVerdictHitsMax` (`lib/core/format.dart`, Task 3).
- Produces: Contract → Core widgets.

- [ ] **Step 1:** Contract check (tokens generator output names, `StatTile`, `AppChip`); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `VerdictPad`: `first tap on tomato selects tomato ×1`; `each tap on the selected side adds one hit`; `the 11th tap changes nothing` (onChanged not called again, or called with 10); `tapping the other side resets to that side ×1`; `the selected side shows "×n"`; `semantics: each side is a slider labelled "Ném cà chua, 3 trên 10" with increase and decrease actions`; `semantics increase and decrease change hits by one without a tap`; `decrease at 1 clears the side` (kind null, hits 0); `disabled pad ignores taps`; `light haptic on each hit, heavier at 10` (`SystemChannels.platform` mock records `HapticFeedback.lightImpact` and `heavyImpact`); `bounce runs once per tap and settles` (`pumpAndSettle` returns in bounded frames; no repeating ticker); `compact layout puts icon, label and hits on one row` (studio block use, `#S05.05-studio`); `tap targets are at least 48 dp`.
  - `VerdictLevel`: `labels by hits` (tomato 1→Ổn, 3→Hài lòng, 6→Rất hài lòng, 10→Tuyệt vời!; brick 2→Hơi tiếc, 5→Chưa ưng, 9→Thất vọng, 10→Rất thất vọng); `track width is intensity` (7 hits → 0.91 of the width); `"Làm lại" calls onReset`.
  - `VerdictBadge`: `shows the icon and ×10` with semantics "Cà chua, 10 trên 10"; brick colour differs from tomato.
  - `TomatoRatioBar`: `segments are proportional (56:2)`; `zero reviews draws an empty track`; semantics "56 cà chua, 2 gạch".
  - `MetaLine`: `joins text parts with " · "`; `a tomato part shows the icon and "97%"`; `ellipsises at maxLines`.
  - Goldens (`tags: ['golden']`): `VerdictPad tomato ×3` and `brick ×10`, light and dark; `VerdictBadge` both kinds.
- [ ] **Step 3:** Run the widget tests; they fail.
- [ ] **Step 4: Implement.** Tokens: add `"tomato"` and `"brick"` under `semantic.color` (light `#D93A2B`, `#A65A35`) and under `dark.semantic.color` (`#FF5A47`, `#D2875E`), then `dart run tool/gen_tokens.dart`. SVGs: copy the mock `<symbol>` paths into files with `stroke="currentColor"` so `ColorFilter.mode(color, BlendMode.srcIn)` tints them. `VerdictPad` (hard part):
  ```dart
  void _tap(VerdictKind side) {
    if (!enabled) return;
    if (kind == side) {
      if (hits >= kVerdictHitsMax) return;           // 11th tap: nothing
      final next = hits + 1;
      next == kVerdictHitsMax ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
      onChanged(side, next);
    } else {
      HapticFeedback.lightImpact();
      onChanged(side, 1);                              // switch side: back to 1, no confirm
    }
  }
  ```
  Each side is a `Semantics(slider: true, value: '$n trên 10', label: l.reviewA11yTomato(n), onIncrease: …, onDecrease: …)`; the bounce is an `AnimatedScale` keyed on `hits` (one short run per change, no `repeat()`). `VerdictLevel` track = `FractionallySizedBox(widthFactor: verdictIntensity(hits))` in the side's colour. Selected side: border and 14–16% tinted background in the side colour (mock `.vbtn.t.on`), unselected `glass` background. Docs: add `VerdictPad`, `VerdictLevel`, `VerdictBadge`, `TomatoRatioBar`, `MetaLine`, `VerdictIcon` entries to `shared-components.md` (Vietnamese, house format "#### Name · Mới"), and gallery tiles in `build_ui_components.py` using the mock classes `.vpad`, `.vbtn`, `.vtrack`, `.vbdg`, `.vratio`, `.tm`; regenerate `docs/design/ui-components.html` (`python3 scripts/tools/build_ui_components.py`).
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/core/widgets` (goldens run locally with `--update-goldens` once, then compared; CI excludes the tag).
- [ ] **Step 6: Commit** `feat(core): VerdictPad, VerdictBadge, TomatoRatioBar and tomato/brick tokens [#130]`.

### Task 5: S05.05 Đánh giá & chia sẻ on VerdictPad

**Files:**
- Modify: `app_flutter/lib/features/review/review_controller.dart`, `review_screen.dart`, `lib/features/booking/booking_view_rules.dart` (review actions from `BookingRules.canReview/isReviewed`), `lib/features/booking/my_bookings_screen.dart` (review button), `lib/l10n/app_vi.arb`
- Delete: `lib/features/review/widgets/star_rating.dart`, `test/features/review/star_rating_test.dart`
- Test: `test/features/review/review_controller_test.dart`, `review_screen_test.dart`, `review_e2e_test.dart`, `test/features/booking/booking_view_rules_test.dart`, `my_bookings_screen_test.dart`

**Interfaces:**
- Consumes: `VerdictPad`, `VerdictLevel`, `VerdictBadge`, `AppChip`, `Verdict`, `ReviewReason`, `ReviewRepository.submit` (Tasks 3–4).
- Produces:
  ```dart
  class ReviewState { Verdict? verdict; int hits; Set<ReviewReason> reasons; String text; List<SharedPhotoTile> photos; String? postId; ReviewPhase phase; Object? error; bool isConflict; bool? submittedShare;
    ReviewBlock? get missing; // null when sendable
    bool get canSubmitReviewOnly; bool get canSubmitWithShare; }
  enum ReviewBlock { verdict, reason, text }
  // ReviewController: setVerdict(Verdict? v, int hits); toggleReason(ReviewReason r); reset(); (setRating removed)
  ```
  Reasons picked on the brick side are kept when the customer switches to tomato and back (spec §5.2), but only sent when the verdict is brick.

**Backend wiring:** `ReviewRepository.submit` → callable `submitReview` (`FirestoreReviewRepository`, region `asia-southeast1`); read-only view through `bookingReviewProvider` (Firestore listener on `reviews/{bookingId}`). Rules unchanged (client cannot write reviews).

**Mock parity:** `#S05.05` and `#S05.05-brick`: bar title "Buổi chụp thế nào?"; compact `BookingCard`; `VerdictPad` left tomato "Hài lòng", right brick "Chưa hài lòng", "×n" top-right of the selected side; level row = label (bold) + text button "Làm lại", track, hint "Chạm tiếp để tăng mức độ, tối đa 10" (tomato frame); brick: section "Điều gì chưa ổn?" + "Chọn ít nhất 1", six chips in the order Đến trễ, Ảnh không như mẫu, Giao ảnh chậm, Thái độ, Đổi giá, Khác (multi-select); text field labelled "Nhận xét" with hint by side; share section unchanged ("Chia sẻ ảnh bạn thích" / "Tuỳ chọn" / hint / grid); footer per Decision 9.

- [ ] **Step 1:** Contract check (review screen, controller, booking view rules); ledger differences.
- [ ] **Step 2: Failing tests.**
  - controller: `setVerdict(tomato, 3) stores side and hits`; `reset clears side, hits and keeps text`; `toggleReason adds and removes`; `missing is verdict, then reason (brick without reasons), then text (< 10)`; `brick reasons survive a switch to tomato and back`; `submit sends verdict, hits and reasons; tomato sends no reasons`; `conflict is treated as done` (unchanged behaviour).
  - screen: `shows the pad, level and hint after the first tap` (find "Rất hài lòng" after 6 taps); `brick shows the reasons title and six chips`; `submit is disabled with "Chọn cà chua hoặc gạch" under it before a side is picked`; `brick without reason shows "Chọn ít nhất một lý do"`; `short text shows "Viết ít nhất 10 ký tự"`; `a full tomato review submits and goes back to /b/:id with "Cảm ơn bạn đã đánh giá!"`; `a send error keeps side, hits, reasons and text and shows the network message`; `read-only view shows VerdictBadge ×n, reason chips and the text`; `eligibility: completed opens the form; upcoming shows "Buổi chụp chưa hoàn thành nên chưa đánh giá được."`; `reviewedAt set opens the read-only view`; `fits 320 dp at 1.3× text`; `the screen carries ScreenCode S05.05`.
  - view rules / list: `customer gets review on completed without reviewedAt`; `viewReview when reviewedAt is set`; `timeline step 7 is done when reviewedAt is set`; `S05.01 Đã xong shows "Đánh giá" only for a booking that can be reviewed`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.** Rebuild `_buildFormView` as the mock order; replace `StarRating` in the read-only view with `VerdictBadge` (large, mapping `Verdict` → `VerdictKind`) + reason chips (non-interactive `AppChip`) + text; eligibility uses `BookingRules.canReview`/`isReviewed`; analytics `review_submit{verdict, hits, reasons, shared}` if an analytics port exists (grep `review_submit`; if none, ledger "no analytics port yet"). Remove `reviewStarsSemantics`, `reviewTextHint` arb keys; run `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/features/review` then `test/features/booking`; affected tests green.
- [ ] **Step 6: Commit** `feat(review): S05.05 tomato/brick review with VerdictPad and brick reasons [#130]`.

### Task 6: S03.01 tile and Đánh giá tab, cards, meta lines, Find chip, S03.02

**Files:**
- Modify: `app_flutter/lib/features/photographer_profile/widgets/profile_header.dart`, `widgets/profile_sections.dart` (`_ReviewsContent`, `_ReviewRow`, `ReviewTile`), `lib/core/widgets/photographer_card.dart`, `lib/features/discovery/photographer_meta.dart` (returns `List<MetaPart>`), its callers (`grep -rn areaRatingMeta lib`), `lib/features/photo/photo_detail_screen.dart`, `lib/features/events/event_info_tab.dart`, `lib/features/find/find_screen.dart`, `find_sheets.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/photographer_profile/reviews_sliver_test.dart`, `photographer_profile_screen_test.dart`, `test/core/widgets/photographer_card_test.dart`, `test/features/find/find_screen_test.dart`, `test/features/photo/photo_detail_screen_test.dart`, `test/features/events/` (event info tab test), `test/features/badges/` (badges screen test, copy only)

**Interfaces:**
- Consumes: `PhotographerSummary` fields, `MetaLine`/`MetaPart`, `VerdictIcon`, `VerdictBadge`, `TomatoRatioBar`, `Review.serviceName/bookingDay/reasons` (Tasks 3–4).
- Produces: `List<MetaPart> areaRatingMeta(PhotographerSummary p, AppLocalizations l)` (area · tomato part or "Mới · n đánh giá" · sessions); `PhotographerCard` meta built with `MetaLine`.

**Backend wiring:** all numbers come from `photographers/{uid}.stats` through `FirestorePhotographerRepository`/`FirestorePublicProfileRepository` (already read); the tab pages through `FirestoreReviewRepository.forPhotographer` (`reviews where photographerId == uid orderBy createdAt desc`, index exists); customer names through `partyProfileProvider`. Badges: `badges/{id}` catalogue synced from the domain constant by the existing `syncCatalog`; earned snapshot text from the server.

**Mock parity:**
- `#S03.01` stat tile: "97%" with the tomato icon (tomato colour on the icon only), label "58 đánh giá"; `#S03.01-new`: "Mới" / "0 đánh giá" (Decision 8).
- `#S03.01-reviews`: header row = big "97%" (display font) with a 24 dp tomato icon, then `TomatoRatioBar` and "56 cà chua · 2 gạch · 58 đánh giá" (under 5: "Mới" instead of the %); each row: avatar, name, "12/10 · Chân dung 2 giờ" (date `formatDayMonth` of `createdAt` in VN time + `serviceName` when present), `VerdictBadge` on the right, reason chips for bricks ("Đến trễ", "Giao ảnh chậm"), then text and up to 3 thumbs as today; bricks are not hidden or moved.
- `#S02.06`: card meta "Chân dung · 1,2 km · [🍅]97% · 112 buổi"; Thu Hà "Kỷ yếu · Mới · 3 đánh giá · 21 buổi"; filter chip "[🍅]90%+" with options 80%+ / 90%+ / 95%+ in the sheet titled "Tỷ lệ hài lòng".
- Event host line: "Chủ sự kiện · [🍅]97%" (mock S11.02).
- `#S03.02`: earned text "97% cà chua từ 58 đánh giá" (server snapshot), locked text "Từ 95% cà chua với ít nhất 20 đánh giá".

- [ ] **Step 1:** Contract check (profile widgets, card, find sheet, event info tab); ledger differences.
- [ ] **Step 2: Failing tests.**
  - profile: `the tile shows 97% with the tomato icon and "58 đánh giá"`; `under 5 reviews the tile shows "Mới" and "3 đánh giá"`; `no reviews shows "Mới" and "0 đánh giá"`.
  - reviews tab: `header shows 97%, the ratio bar and "56 cà chua · 2 gạch · 58 đánh giá"`; `under 5 the header shows "Mới"`; `a brick row shows VerdictBadge ×3 and chips "Đến trễ", "Giao ảnh chậm"`; `rows keep createdAt order, bricks included`; `row meta reads "12/10 · Chân dung 2 giờ"`; `a legacy row without serviceName shows only the date`.
  - card: `≥ 5 reviews shows the tomato part "97%"`; `3 reviews shows "Mới · 3 đánh giá"`; `0 reviews shows no review part`.
  - find: `the chip reads 90%+ with the tomato icon after picking 90`; `the sheet offers 80%+, 90%+, 95%+`; `clearing the chip resets minTomatoPct`.
  - photo detail / event info: `meta shows the tomato part instead of stars`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.** Replace every `★`/`formatRating` use (grep must return nothing in `lib/`: `grep -rn "★\|formatRating\|ratingAvg\|hasRating" app_flutter/lib`). Remove `reviewsHeader`, `findRatingMin`, `eventHostRoleRating` arb keys; `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; folder runs of `test/features/photographer_profile`, `test/core/widgets`, `test/features/find`, `test/features/photo`, `test/features/events`, `test/features/badges`; affected tests green.
- [ ] **Step 6: Commit** `feat(profile): % cà chua tile, tomato/brick reviews tab, cards, Find chip and badge copy [#130]`.

### Task 7: Specs, data model and handover ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-tomato-brick-reviews-design.md` (Trạng thái → "đã làm (#130)"; §3.1 add `subjectType`, `subjectId`, `serviceName`, `bookingDay`, doc id rule; §5.4 "đã đánh giá" = `reviewedAt` set; §7.3 note that the badge hook was live and is now on `tomatoPct`; §7.4 "thông báo do #138 (`review_tomato`/`review_brick`, hook `notifyReviewVerdict`)"; §8 the SQL decision), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 rows S03.01 (append "· % cà chua và tab Đánh giá: ✅ (#130)"), S03.02 (append "· "Được đánh giá cao" theo % cà chua (#130)"), S05.05 ("✅ đã làm (4e) · cà chua/gạch ✅ (#130)"), S02.06 (chip 🍅 90%+ (#130)); `docs/superpowers/specs/screens/account.md` S05.05 strings list = the arb keys; `screens/discovery.md` S03.01/S02.06; `docs/superpowers/specs/data-model/domain-model.md` (`Review` fields with subject and snapshots, `PhotographerStats`, `BadgeMetric`), `relational-schema.md` (`reviews` key `(booking_id, subject_type)` + `subject_type`, `subject_id`, `service_name`, `booking_day`; photographers columns note "migration 1791676800001"); `docs/superpowers/specs/2026-10-06-studio-members-design.md` §6 (one line: model ready, `reviewDocId(bookingId, 'studio')`, studio reasons to add in #136)
- Create: `docs/superpowers/handover/ledger-s05-tomato-brick-reviews.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names); check every string in `account.md`/`discovery.md` against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: Decisions 1–14 as rulings; skipped suites (rules-test, Functions integration, `services/api` if no Postgres); deploy order (rules unchanged; indexes deploy before the app build that queries `stats.score`; Functions before the app because the app no longer sends `rating`); deferred list below; "the delivery plan must extend `isReviewable` to `approved`". If #139 or #140 is not merged yet, comment on those issues (`gh issue comment`) with the replacement names of Decision 14.
- [ ] **Step 3: Commit** `docs(spec): tomato/brick reviews done, subject model and ledger [#130]`.

## Deferred

- Studio second review block, studio reason codes and `reviews/{bookingId}_studio` writes → #136 (S26), on the model of Decision 2.
- Notification copy (`review_tomato` / `review_brick`) is #138's; this plan only calls its hook.
- Reviews opening at `approved` and the "Đánh giá buổi chụp" button on S05.06 → `docs/superpowers/plans/2026-10-07-s05-delivery-two-layer.md` (same issue).
- Provider replies, review disputes and moderation → S18/S20 (#142, #144), spec §11.
- "Common brick reasons" statistic on the profile (spec §11).
- `reviews` SQL table and the Go/self-hosted review endpoints → Phase 2 (#90).
- Remote recommender (`services/recommender`) using `score` → when that service exists; its OpenAPI has no rating field today.
- S03.01-reviews compact header bar (audit item 7) → #133 follow-up / mock parity pass (not part of the tomato change).
