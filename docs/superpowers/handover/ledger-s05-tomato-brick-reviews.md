# Handover ledger — plan S05 tomato/brick reviews: verdicts, % cà chua stats, S05.05, profile reviews tab, Find filter (issue #130)

Plan: `docs/superpowers/plans/2026-10-07-s05-tomato-brick-reviews.md`, Tasks 1–7. Branch `plan/130-s05-theo-doi-buoi-chup-ban-giao-danh-gia` (the plan text says `plan/130-tomato-brick-reviews`; the claimed name wins). Merge base 2b9ee77 (#138 merged, so `notifyReviewVerdict`, `review_tomato` and `review_brick` exist and the Decision 5 fallback was not needed). Commits: 579075c (domain), 62c5ad0 (functions, seed, index, SQL), 8667d8e (app data, ranking, Find filter), cb50769 and 5a58c27 (core widgets), 6e7f565 (S05.05), 91d1418 and a176613 (profile, cards, Find chip, copy), then the docs commit of Task 7.

## Built
- Domain (Task 1): `review.ts` (`REVIEW_HITS_MAX`, `INTENSITY_FLOOR`, `TOMATO_PCT_MIN_REVIEWS`, `VERDICTS`, `REVIEW_REASONS`, `REVIEW_SUBJECT_TYPES`, `intensityOf`, `reviewDocId`, `isReviewable`, `validateReviewInput` that ignores `rating` and `intensity`); `review_stats.ts` (`addVerdict` replaces `addRating`; `countReview(store, reviewId, now)` counts into `review.subjectId`); `submit_review.ts` writes `reviewedAt` and a booking event `reviewed`, no status change; `badge.ts` (`tomatoPct` replaces `rating`, `top_rated` at 95% with 20 reviews).
- Functions (Task 2): `review_firestore.ts` (new fields, tolerant legacy reader, `FirestoreStatsStore` deletes `stats.rating` and `stats.ratingSum`, keeps `merge: true`), `onReviewWrite` on `reviews/{reviewId}` calls `notifyReviewVerdict` and badge evaluation and no longer emits `review_new`, index `photographers (…, stats.nextFreeDate, stats.score desc, …)`, seed rewritten with tomato/brick data, SQL migration `services/api/migrations/1791676800001_tomato_brick.sql` (only `photographers`), `services/api/src/db/database.ts` and `test/migrations.test.ts`, `services/dispatch/api/openapi.yaml` (`PhotographerCard.tomatoPct` nullable + `reviewCount`).
- App data (Task 3): `Review` with verdict/hits/reasons/subject/snapshots, `PhotographerSummary` (`tomatoPct`, `score`, `tomatoCount`, `brickCount`, `hasReviews`, `hasTomatoPct`), `smoothedScore`, `FindFilters.minTomatoPct`, `formatTomatoPct`, `kVerdictHitsMax`/`verdictIntensity` in `lib/core/format.dart`, `BookingRules.canReview`/`isReviewed`.
- Core widgets (Task 4): `VerdictIcon`, `VerdictPad`, `VerdictLevel`, `VerdictBadge`, `TomatoRatioBar`, `MetaLine`/`MetaPart`, tokens `tomato`/`brick`, assets `tomato.svg`/`brick.svg`, gallery tiles.
- S05.05 (Task 5): `review_screen.dart`/`review_controller.dart` rebuilt on `VerdictPad`, brick reasons, one primary "Gửi đánh giá" until a photo is picked; `StarRating` removed.
- Profile and discovery (Task 6): "% cà chua" stat tile, reviews tab (ratio bar, `VerdictBadge`, reason chips), `reviewMetaPart` for cards and meta lines, Find chip "🍅 90%+" (80/90/95), `reasonTopRated`, `findFallbackNote`, S03.02 badge copy.

## Docs changed in Task 7
- `docs/design/ui-mock.html`: frame `#S05.05-brick` only (Ruling 5): the share section (heading, hint, photo grid) shown, one primary "Gửi đánh giá" in the footer, field label "Nhận xét", caption text updated (the placeholder "Kể rõ điều chưa ổn để thợ cải thiện" is named in the caption; the field itself keeps the sample comment so the send button reads as enabled). The HTML still parses (`python3 html.parser`).
- `2026-10-06-tomato-brick-reviews-design.md`: Trạng thái "đã làm (#130)"; §3.1 `subjectType`, `subjectId`, `photographerId = subjectId`, `serviceName`, `bookingDay`, doc id `reviewDocId`, legacy reader, `reviewedAt` without status change; §3.2 `stats.score` and the `freeThisWeek` index; §5.1.7 footer and the brick-frame rule; §5.4 eligibility `isReviewable` and "đã đánh giá" = `reviewedAt`; §5.5 the real arb keys; §5.6 analytics not emitted; §6.1 profile tile always present; §7.1 `reasonTopRated`; §7.2 chip strings; §7.3 the badge hook was live and is now `tomatoPct`; §7.4 notifications by #138 (`review_tomato`/`review_brick`, hook `notifyReviewVerdict`); §8 the SQL decision (only `photographers`); §9 what is done.
- `2026-10-01-remaining-screens.md`: §2 rows S02.06 ("chip 🍅 90%+ (#130)"), S03.01 ("% cà chua và tab Đánh giá: ✅ (#130)"), S03.02 ("\"Được đánh giá cao\" theo % cà chua (#130)"), S05.05 ("✅ đã làm (4e) · cà chua/gạch ✅ (#130)"); the huy hiệu table row (`tomatoPct`), the `quality` row of the recommender table (`smoothedScore`, `C = 0,6`), the local recommender line, and the S05.05 screen-table row.
- `screens/account.md` (S05.05: info, layout, data, states, strings = the arb keys, no `s12_*`, analytics, acceptance), `screens/discovery.md` (S03.01 tile and reviews tab and strings; S02.06 chip, fallback note, `reasonTopRated`).
- `components/shared-components.md`: `VerdictLevel.showHint`, `MetaPart.tomato(pct, {count})`, `reviewMetaPart`.
- `data-model/domain-model.md`: `Review` (subject, snapshots, `countedAt`), `ReviewSubjectType`, `BadgeMetric` (`tomatoPct`), `PhotographerStats` (score invariant), `Booking.reviewedAt?`, invariant 6; `data-model/relational-schema.md`: `reviews` key `(booking_id, subject_type)` + `subject_type`, `subject_id`, `service_name`, `booking_day`, `counted_at`, `bookings.reviewed_at`, the photographers columns note "migration 1791676800001", the Firestore-to-SQL row.
- `2026-10-06-studio-members-design.md` §6: one bullet, model ready, `reviewDocId(bookingId, 'studio')`, studio reasons to add in #136.
- Every quoted string in `account.md`, `discovery.md` and the tomato spec was grepped against `app_flutter/lib/l10n/app_vi.arb` and the mock frames (`#S05.05`, `#S05.05-brick`, `#S03.01-reviews`, `#S03.01-new`, `#S02.06`).

## Rulings
Verbatim from the SDD progress ledger (`.superpowers/sdd/2026-10-07-s05-tomato-brick-reviews/progress-plan-130-s05-theo-doi-buoi-chup-ban-giao-danh-gia.md`), in order.

- Ruling 1: every task's commit must keep `flutter analyze` and the app tests green; when Task 3 removes `ratingAvg`/`hasRating`/`formatRating`, it switches each remaining caller minimally (tomato % or nothing) and Tasks 5–6 rebuild those screens to the mock — cost if wrong: a few lines touched twice.
- Ruling 2: functions typecheck may fail between Task 1 and Task 2 (rating-shaped adapters); functions npm test stays green; Task 2 restores typecheck — cost if wrong: one intermediate commit without functions typecheck.
- Ruling 3: a review created with countedAt already set (seed or importer) sends no verdict notice and runs no badge check; live submits always create with countedAt null — importers (#136 studio docs must keep countedAt null; Phase 2 migration) run badge evaluation themselves — cost if wrong: an imported review never notifies.
- Ruling 4: compact pad uses new key reviewBrickShort "Chưa ưng" (mock #S05.05-studio wins); regular pad keeps "Chưa hài lòng" — cost if wrong: one string.
- Ruling 5: S05.05 brick follows the plan over the shortened mock frame — share section on both sides, single primary until a photo is picked (Decision 9), field label "Nhận xét" with hint by side; Task 7 updates mock #S05.05-brick to match — cost if wrong: mock and app differ until fixed.
- Ruling 6: skip the gh issue comments on #139/#140 that Task 7's brief asked for — both plans already use the new names (ledger Decision 14) — cost if wrong: an emitter misses a rename note.
- Ruling 7: keep C = 0.6 (spec §7.1 sets it) and raise it as an owner question — cost if wrong: low-hit tomato providers rank below newcomers until changed.
- Ruling 8: tomatoPct stays rounded for display, badge and filter alike (94.5% counts as 95%), documented in the ledger — cost if wrong: a provider at 94.5–94.9% gets the badge.

Importer obligation of Ruling 3: the #136 studio review docs (`{bookingId}_studio`) must be created with `countedAt` null so the trigger counts them, notifies and checks badges; a Phase 2 importer that writes reviews with `countedAt` set must run `evaluateUserBadges` for subject and customer itself.

## Needs the owner
1. Ranking prior (Ruling 7). Spec §7.1 sets `smoothedScore = (v · score + m · C) / (v + m)` with `m = 10`, `C = 0.6`. `C = 0.6` is above the score of a 1–2-hit tomato (`intensityOf(1) = 0.4`, `intensityOf(2) = 0.58`), so a provider with only happy customers who tap lightly ranks below a newcomer: 30 tomato reviews averaging 2 hits smooth to (30 · 0.58 + 10 · 0.6) / 40 ≈ 0.585, below an unreviewed provider's 0.6. Options: (a) lower the prior to `C ≤ 0.4` (the score of a one-hit tomato), so reviews never rank below no reviews unless they include bricks; (b) smooth the tomato share instead (`(tomatoCount + m · C') / (reviewCount + m)`) and use `score` only as a tiebreak. Default until answered: keep `C = 0.6` as the spec says.

## Rounding of tomatoPct (Ruling 8)
`tomatoPct` is the rounded integer percent everywhere: display, the `top_rated` badge (≥ 95) and the Find filter (80 / 90 / 95). A provider at 94.5–94.9% shows 95%, gets the badge and passes the 95%+ filter; this is intended (one number, read the same everywhere).

## Decisions of the plan (summary)
1. No migration of star reviews (spec D7 wins): no production project, dev is on Spark so no Function ever wrote a review there; readers are tolerant of a legacy star doc (`rating >= 4` reads as tomato, else brick, one hit, no reasons); `addVerdict` ignores a legacy `reviewCount`; the adapter deletes `stats.rating` and `stats.ratingSum` on the first verdict write; seed rewritten.
2. Subject model now, studio later: `subjectType`/`subjectId`, `photographerId = subjectId`, doc id `reviewDocId(bookingId, subjectType)` (`bookingId` or `{bookingId}_studio`). #130 writes only `photographer`; #136 adds the studio block, the studio reason codes and the second doc.
3. The booking keeps its status after a review: `reviewedAt` plus a booking event `reviewed`; `reviewed` stays a readable legacy status; `isReviewable(status)` is `completed` here. **The delivery plan (`2026-10-07-s05-delivery-two-layer.md`) must extend `isReviewable` to `approved`.**
4. Review snapshots `serviceName` and `bookingDay` for the reviews tab and the notice.
5. Notification through #138's `notifyReviewVerdict`; `onReviewWrite` stops emitting `review_new` (type kept for old inbox rows); this plan adds no copy.
6. Badge: `BADGE_METRICS` `'rating'` → `'tomatoPct'`; `top_rated` ≥ 95% with ≥ 20 reviews; the hook was already live, so a code change.
7. Tomato glyph is the SVG icon next to the number (`VerdictIcon`/`MetaLine`); arb strings hold no emoji; exceptions are the server push title and `reasonTopRated`.
8. Profile stat tile always present: ≥ 5 reviews "97%" with icon, else "Mới" and "{n} đánh giá"; cards and meta lines hide the part at 0 reviews.
9. S05.05 footer: one primary "Gửi đánh giá" until a photo is picked, then outline "Chỉ đánh giá" + primary "Gửi & chia sẻ {n} ảnh" (owner question 1 answered yes in INDEX; mock fixed in Task 7).
10. Find filter chip "🍅 90%+", options 80/90/95, `FindFilters.minTomatoPct`, providers under 5 reviews never pass; sort "Đánh giá" uses `smoothedScore`.
11. SQL: `services/api` has no `reviews` or `posts` table, so the migration only alters `photographers`; the `reviews` DDL is the target in `relational-schema.md`, created by the slice that adds posts (Phase 2, #90).
12. `freeThisWeek` orders by `stats.score` (index updated); its invariant is "`stats.score` is written whenever `stats.nextFreeDate` is written"; nothing writes `nextFreeDate` yet, so no backfill.
13. Arb key names are camelCase versions of spec §5.5; no `s12_*` keys exist in the arb.
14. Sibling plans that read stars (#139 quote trust line and "Đánh giá" sort, #140 `ratingAvg` snapshots and score component): neither is merged (a grep of `ratingAvg|stats.rating|'rating'|formatRating|★` in `packages/domain/src`, `app_flutter/firebase/functions/src` and `app_flutter/lib` finds only the intentional legacy reader in `lib/data/review/review.dart`), and both plans are already written against the new names (cross-plan review finding 27: `tomatoPct`/`score`/`reviewCount` snapshots, `MetaLine` + `formatTomatoPct`, dispatch score component `(score + 1) / 2`). Replacement names, for the issue comments: `ratingAvg`/`hasRating` → `tomatoPct`/`hasTomatoPct`/`reviewCount`/`score`, `formatRating` → `formatTomatoPct`, `smoothedRating` → `smoothedScore`, `minRating` → `minTomatoPct`, `stats.rating` → `stats.score`. **Not posted**: the `gh issue comment` on #139 and #140 is left to the controller or the owner (publishing to GitHub needs the user's go-ahead).

## Deploy order
- Rules: unchanged (`match /reviews/{reviewId}` read signed-in, write false), no rules deploy needed.
- Indexes first: `firestore.indexes.json` (`stats.score` replaces `stats.rating` in the `photographers` composite) must be deployed before an app build that queries `freeThisWeek` ordered by `stats.score`.
- Functions before the app: the app no longer sends `rating`, and the old callable would reject a `verdict` payload. Deploy `submitReview`/`onReviewWrite` first.
- `services/api` migration `1791676800001_tomato_brick.sql` with the self-hosted slice; the `reviews` table is not created yet.

## Skipped suites (written, not run)
- Firestore rules tests (`app_flutter/firebase/rules-test`, `npm test`): emulator, outside the sandbox; the rules did not change.
- Functions integration tests (`npm run test:integration`): written (`the trigger counts once when retried`, `stats write keeps the other stats fields`), not run.
- `services/api` vitest (`npm test`, needs Postgres): `test/migrations.test.ts` was updated for the new photographers columns, not run; `npm run typecheck` and `npm run build` are the gates there.
- No device or iOS builds; golden tests (tag `golden`) are excluded from CI.

## Deviations and gaps
- l10n key names: `profileStatNew` and `photographerReviewsNew` were built instead of the contract's `tomatoNew` and `tomatoNewReviews`; the specs (`discovery.md`) now name the built keys.
- No analytics port yet: `review_submit{verdict, hits, reasons, shared}` is specified but not emitted.
- The mock frame `#S05.05-brick` field keeps a sample comment (so the primary button reads as enabled); the placeholder is described in its caption.

## Deferred minors (SDD ledger, by task)
Verbatim; "FINAL TRIAGE" marks the ones the controller picks up in the final review.

### Task 1
- minor (deferred): misformatted test lines; round2 defined twice; no test pinning permission_denied before conflict; legacy 'review' action in booking_machine (no caller found) — **fixed** in the final review (c30d1df): the action is gone and `transitionBooking` refuses it with `invalid_argument`

### Task 2
- minor (deferred, FINAL TRIAGE): seed detailed_reviewer progress for Lan should be 3/5 not 0/5 (fixtures.ts:704) — **fixed** (797d9f5)
- minor (deferred): import-skip test doesn't assert no badge evaluation; legacy rating 4/3 boundary untested; hits/intensity mismatch on malformed doc; index switch lands before Task 3 (same PR)

### Task 3
- minor (deferred, FINAL TRIAGE): photographer_summary.dart imports data/review/review.dart (cloud_firestore) → Firebase edge into core barrel; move kTomatoPctMinReviews to core/format.dart
- minor (deferred): app legacy reader defaults missing rating to 5/tomato while server reads brick; hits clamp vs reset; reasons kept on tomato — **fixed** (78acc5c): the app reader follows the server
- minor (deferred): transitional brick branch untested; detailActions completed+reviewedAt untested; hits cast throws on non-number — the last one **fixed** (78acc5c)

### Task 4
- minor (deferred → Task 5 note): VerdictLevel hint shown on #S05.05 but omitted on #S05.05-brick (mock frames disagree); consider showHint param
- minor (deferred): slider semantics no value/increasedValue; studio compact pads read identically (semanticsSubject, #136); icon stroke 1.8 vs mock 1.6/1.9; MetaLine tomato part reads "97%" only — the last one **fixed** ("97% cà chua")

### Task 5
- minor (deferred): tap hint hidden on brick (owner could show on both); no double-submit test; submit doesn't re-check missing; over-max text message; thin 320dp brick test; hint visibility test; review_submit analytics not emitted (no analytics port yet); "Làm lại" no-op looks tappable while submitting

### Task 6
- minor (deferred): l10n keys profileStatNew/photographerReviewsNew instead of contract tomatoNew/tomatoNewReviews; tomato part reads "97%" in semantics (**fixed**); reviews_sliver_test format churn; order test trivially seeded; _ReasonChip/_ReviewsHeader literals from mock; Find chip filled when selected (mock unfilled)

Status at Task 7 of two lines above: the Task 3 "FINAL TRIAGE" item is already resolved (`kTomatoPctMinReviews` lives in `lib/core/format.dart`, `lib/data/review/review.dart` re-exports it, and `photographer_summary.dart` imports only `core/core.dart`); the Task 4 `showHint` suggestion was done in Task 5 (tomato side only). The Task 2 seed item (Lan's `detailed_reviewer` progress) is still open. Fixed in the final review (797d9f5).

## Final review (98bc3bd) and its fixes
Verdict "with fixes". Fixed on this branch:
- I1 screen readers heard a bare "97%" (the icon is decorative): new arb keys `tomatoPctA11y` "{pct}% cà chua", `tomatoPctCountA11y` "{pct}% cà chua, {count} đánh giá", `findTomatoChipA11y` "Từ {pct}% cà chua"; `MetaLine` speaks one label through `metaPartsSemantics`, which the `PhotographerCard` header label also uses; the profile `StatTile` gets `semanticsValue`, the reviews header a `semanticsLabel`, and `AppChip` a new `semanticsLabel` for the Find chip.
- M3 Lan's seeded `detailed_reviewer` progress is 3/5 (her three reviews of ≥ 50 graphemes); the seed README's `sharer` 2/5 was also wrong (0/5).
- M4 the legacy `review` transition: removed from `TransitionAction` and `decideTransition`; `transitionBooking` answers `invalid_argument`; `reviewed` stays a readable status.
- M5 review rows show "{ngày} · {gói}" from `bookingDay` (Decision 4), falling back to the Vietnam day of `createdAt`.
- M6 the app's tolerant reader matches the server's: no rating → one brick, out-of-range or fractional or non-numeric `hits` → 1, non-numeric `intensity` → `intensityOf(hits)`, reasons only on a brick and de-duplicated.
- M10 `findFallbackNote` → "Đang xếp theo điểm cà chua và khoảng cách" (the fallback ranks by `smoothedScore`, not the share); specs updated.
- I2 → Ruling 7 and "Needs the owner" 1; M8 → Ruling 8.

Remaining minors (not fixed):
- Light theme: the `×n` hit count in `VerdictBadge` (side colour on its own tint) has a contrast of about 3.7:1, under 4.5:1 for small text.
- `lib/core/review_meta.dart` imports `lib/data/content/photographer_summary.dart`, a `core` → `data` edge (no Firebase import, but against the layering); move `reviewMetaPart` to a feature-level file or pass the three values it needs.

## Deferred by the plan
- Studio second review block, studio reason codes and `reviews/{bookingId}_studio` writes → #136 (S26), on the model of Decision 2.
- Notification copy (`review_tomato` / `review_brick`) is #138's; this plan only calls its hook.
- Reviews opening at `approved` and the "Đánh giá buổi chụp" button on S05.06 → `docs/superpowers/plans/2026-10-07-s05-delivery-two-layer.md` (same issue); it must extend `isReviewable` to `approved` and `BookingRules.canReview`/`isReviewed` follow.
- Provider replies, review disputes and moderation → S18/S20 (#142, #144), spec §11.
- "Common brick reasons" statistic on the profile (spec §11).
- `reviews` SQL table and the Go/self-hosted review endpoints → Phase 2 (#90).
- Remote recommender (`services/recommender`) using `score` → when that service exists; its OpenAPI has no rating field today.
- S03.01-reviews compact header bar (audit item 7) → #133 follow-up / mock parity pass (not part of the tomato change).
