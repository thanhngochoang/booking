# Handover ledger: S15–S16 Đăng việc & báo giá (#139)

Unit: #139 (S15.01–S15.04 Đăng việc, S16.01–S16.03 Nhận việc đăng và báo giá)
Branch: `plan/139-s15-s16-dang-viec-bao-gia` (upstream `origin/plan/139-s15-s16-dang-viec-bao-gia`), target `develop`
Plan: `docs/superpowers/plans/2026-10-07-s15-s16-job-posts.md`
Spec: `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md`, `docs/superpowers/specs/screens/jobs.md`

Tasks 1–9 were implemented and committed according to the handoff ledger. Task 10 completes feature flag flip, notification routing verification, documentation updates, and this handover ledger.

## Scope delivered

- **Mocks & Screen Spec (Task 1):** Screen specifications for S15.01–S15.04 and S16.01–S16.03 in `docs/superpowers/specs/screens/jobs.md`; UI mock frames in `docs/design/ui-mock.html` (`#S15.01`, `#S15.01-b`, `#S15.02`, `#S15.02-d`, `#S15.03`, `#S15.04`, `#S16.01`, `#S16.02`, `#S16.03`, `#S15.02-invite`, `#S16.03-flex`); screen codes in `lib/core/screen_codes.dart`.
- **Domain logic (Tasks 2–3):**
  - `packages/domain/src/job.ts`: `JobRecord`, `QuoteRecord`, `JobInviteRecord`, `JobMatchRecord`, `BookingTerms`, validation, contact leaks filter (`findContactLeak`), eligibility, fit calculation (`jobFit`), city helpers (`cityOf`, `cityKeyOf`), duration and deadline rules.
  - `packages/domain/src/job_use_cases.ts`: `createJob`, `updateJob`, `extendJob`, `closeJob`, `inviteToJob`, `runJobSweeps`.
  - `packages/domain/src/quote_use_cases.ts`: `submitQuote`, `withdrawQuote`, `declineQuote`, `acceptQuote`, `awardJobFromBooking`, `withdrawQuotesForDay`.
  - `packages/domain/src/geo.ts`: Haversine `distanceKm` helper.
  - Slot in `create_booking.ts` for quote draft fields (`buildBookingDraft`).
- **Functions, Rules & Infrastructure (Task 4):**
  - Callables: `createJob`, `updateJob`, `extendJob`, `closeJob`, `inviteToJob`, `submitQuote`, `withdrawQuote`, `declineQuote`, `acceptQuote`, `openJobInquiry`.
  - Firestore triggers: `onJobQuoteWrite`, `onJobMatchCreated`, `onJobInviteCreated`, `onJobViewCreated`.
  - Trigger extensions: `onBookingWrite` hook for job award and quote auto-withdrawal; `bookingClock` step `jobSweeps` running `runJobSweeps`.
  - Firestore rules: read/write policies for `jobs/{id}`, `quotes/{photographerId}`, `invites/{photographerId}`, `matches/{photographerId}`, `views/{uid}`.
  - Storage rules: `jobRefs/{uid}/{draftId}/{file}` allowing JPEG uploads up to 2MB.
  - Firestore indexes: composite indexes for jobs, quotes, invites, and matches.
  - Seed fixtures: sample jobs and quotes.
- **App Data Layer (Task 5):**
  - Models: `Job`, `JobDraft`, `Quote`, `QuoteDraft`, `JobRules`.
  - Repositories: `JobRepository`, `FirestoreJobRepository`, `FakeJobRepository`.
  - Providers: `jobRepositoryProvider`, `jobStreamProvider`, `openJobsStreamProvider`, `myJobsStreamProvider`, `jobQuotesStreamProvider`, `myQuotesStreamProvider`, `jobCardDataOf`.
  - Routes in `router.dart`: `/jobs/new`, `/jobs/:id`, `/jobs/:id/quote`, `/jobs/:id/applications`, `/jobs/:id/applications/:quoteId`, `/jobs/:id/applications/:quoteId/pay`.
- **Core Widgets (Task 6):**
  - `JobCard`, `QuoteCard`, `DeliverableChips`, `FitPill`, `MilestoneTable`.
- **Customer Posting & Management (Task 7):**
  - S15.01 Post a Job (`JobPostScreen`, `JobDraftController`, sheets).
  - S15.02 My Jobs (`MyJobsTab`, `JobScreen` owner detail mode, `JobEntryCard`).
  - Invite Sheet (`InviteSheet`).
- **Customer Review Quotes & Checkout (Task 8):**
  - S15.03 Quotes List (`QuotesScreen`).
  - S15.04 Quote Detail (`QuoteDetailScreen`, `DeclineQuoteSheet`).
  - Quote Checkout (`QuoteCheckoutScreen`, `QuoteCheckoutController` running 100% upfront payment via #129's model).
- **Photographer Job Market & Quotes (Task 9):**
  - S16.01 Job Detail for Photographer (`JobPhotographerDetail`, view recording, matching fit pill).
  - S16.02 Open Jobs and My Quotes (`OpenJobsTab`, `MyQuotesTab`, integrated into `WorkScreen` tabs).
  - S16.03 Submit Quote (`QuoteSheet`, `QuoteSheetController`).
- **Integration & Notification Wiring (Task 10):**
  - Enabled `kJobsEnabled = true` in `lib/core/feature_flags.dart`.
  - Verified and updated S17.02 notification settings screen test for "Việc đăng tuyển" row.
  - Added router tests in `notifications_screen_test.dart` for `job_match` -> `/jobs/:id`, `quote_new` -> `/jobs/:id/applications`, and `quote_accepted` -> `/b/:id`.
  - Updated domain model, relational schema, remaining screens, and cost inventory specs.

## Decisions 1–28

1. **100% up front on #129's model, through the one booking-draft builder:** A quote booking is built by `buildBookingDraft` with `source: 'quote'`, `terms`, `jobId`, `quoteId`, full deposit, and zero remaining.
2. **Two milestones (amounts by #199, release by #152):** Stored as 50/50 `terms.milestones` with rounding on milestone 2; release follows delivery milestones when #152 lands.
3. **Mock wins on copy, spec on behaviour and codes:** Tabs match mock copy ("Hôm nay / Việc đang tuyển · {n} / Báo giá của tôi"); no calendar slot hold on quoting; calendar marker for quoted days deferred.
4. **Flexible jobs: photographer proposes day:** Fixed jobs use the job date/time; flexible jobs have `proposal {day, start, end}` within the customer's `[from, to]` window.
5. **Service area = distance, else city:** Matched via `distanceKm(area, center) <= radiusKm` when center is present; otherwise matched via `cityKeyOf(cityOf(area.name)) == cityKeyOf(serviceArea.city)`.
6. **Fit is computed on the server:** Computed via domain `jobFit` (weights: specialty 35, distance 20, free day 20, budget 15, quality 10) and persisted on matches/invites/quotes; client never recomputes it.
7. **Matching at creation:** `createJob` scans up to 200 candidates, checks eligibility and availability for top 40, writes up to 30 `matches/{uid}`.
8. **Visibility rules:** Photographers read `jobs` with `status == 'open'`; photographers who quoted or were invited read the job in any status.
9. **Checkout lock:** `acceptQuote` locks the job with `checkout = {quoteId, bookingId, expiresAt: now + 15m}`; subsequent checkout attempts fail with `job_checkout_locked`.
10. **Award after payment, in the booking trigger:** `handleTransferNotification` moves the quote booking from `draft` to `accepted`, which triggers `handleBookingWrite` to award the job and decline unselected quotes.
11. **Auto-withdraw:** When a photographer has a booking accepted on a day, all other `submitted` quotes for that day are automatically withdrawn with `autoWithdrawn: true`.
12. **Pending days:** Submitting a quote for a day with `pending` booking requests is permitted; `booked` or `off` is rejected with `day_taken`.
13. **Notifications through #138's hooks:** Uses the 8 job types defined by #138 (`quote_new`, `quote_withdrawn`, `quote_accepted`, `quote_not_selected`, `job_match`, `job_invited`, `job_expiring`, `job_expired`); `job_selected` is deprecated and not emitted.
14. **No new Scheduler job:** Sweeps for job expiry, 24-hour notice, and reference cleanup run inside the existing `bookingClock` via `runJobSweeps`.
15. **Field errors:** `DomainError` carries an optional `field`; mapped to HTTP `failed-precondition` / `invalid-argument` with `details.field`.
16. **Job inquiries:** `openJobInquiry` creates or retrieves a chat linked to `jobId`; sets `startedBy` to indicate inquiry initiator.
17. **Views:** S16.01 creates `jobs/{id}/views/{uid}` once per photographer; `onJobViewCreated` atomically increments `viewCount`.
18. **"{m} mới":** `newQuoteCount` on job document increments on new/resubmitted quotes; customer resets it to 0 upon viewing quotes in S15.03.
19. **`quoteCount`:** Counts all non-withdrawn quotes (`submitted`, `accepted`, `not_selected`, `declined`); `recentQuoters` holds up to 3 avatar snapshots.
20. **Quote terms:** Price up to 1B VND, delivery days 1–60, revisions 0–5, milestone split 50/50 via `milestoneAmountsOf`.
21. **Trust line in tomato:** Reviews use #130's `MetaLine` and smoothed scores with tomato percentage; "★" is never used.
22. **Entry points:** S05.01 third tab + FAB for customers, S02.06 empty state link, S15.02 invite sheet; S03.01 menu deferred.
23. **Only customers post:** `createJob` requires `users/{uid}.role == 'customer'`; quoting requires role `photographer`.
24. **References through #147's image API:** Uses `MediaUploader` with path `jobRefs/{uid}/{draftId}/{ulid}.jpg`; storage rule enforces JPEG <= 2MB; purged 30 days after job completion/close.
25. **Specialty `other`:** Allowed for job posts ("Khác"), but not allowed as a photographer specialty.
26. **Hire count and phone flag:** `customer.hireCount` and `customer.phoneVerified` snapshotted on job creation; phone number is never exposed.
27. **Report on S15.04 "…":** Hidden until S20 (#144); menu displays "Từ chối báo giá" only.
28. **Repost & Edit:** "Đăng lại" creates a new draft prefilled with content/area/budget/wants; "Sửa" reopens S15.01 and calls `updateJob` (only allowed when 0 quotes exist).

## Differences found in contract checks

- `OrderGateDeps`: Uses `#198` (`n1-order-gate`)'s `orderBlocker` / `assertOrderAllowed` pattern; `liveJobDeps` explicitly wires `blocks: liveBlockGate()`.
- `buildBookingDraft`: Uses `#199` (`n2-booking-draft`) builder with extension point `quoteDraftFields`.
- Firestore composite index count: Adjusted in cost spec from 52 to 60 (incorporating the 11 S15–S16 composite indexes).
- `Chat` entity in domain model: Added `jobId` and `startedBy` to match backend implementation.

## Deferred list

- Real payment intermediary (#129 Deferred) and the S22.04 refund-account choice (#141); checkout runs on #129's model, VietQR and S04.04 (`PaymentPendingScreen`) with fake gateway.
- Studio "· {m} thợ đi cùng" (#136). (Two milestones and tomato trust line are implemented per Decisions 2 and 21.)
- S03.01 "…" -> "Mời báo giá" (no "…" menu in app or mock); saving jobs (S16.01 bookmark, S19 #143); reporting a quote (S20 #144).
- S06.04 calendar marker for quoted days (mock caption S16.03, Decision 3) (#134).
- Job context chip in S07.01 for job inquiries (#131).
- Server-side recommender (`services/recommender`) and remote `recommend` callable; fit remains domain rule (Decision 6).
- Orphan reference uploads when the app dies mid-draft (a sweep over `jobRefs/` older than 7 days without a job).
- Staff tools for jobs and quotes (S23, phase 1.5 dashboard #83); Go backend parity (phase 2 #90): `relational-schema.md` is target, no `services/api` routes.
- Recruiting posts of a future S27 ("Studio tuyển thợ", visible only to photographers and studios) are a separate feature (`recruitPosts`, not `jobs`).

## Skipped suites

- Firestore rules tests (`app_flutter/firebase/rules-test/`) and Functions integration tests (`app_flutter/firebase/functions/test/integration/job.test.ts`) are written for CI execution with emulators and skipped during local agent runs.

## Deploy order

1. **Deploy Firestore Rules and Composite Indexes:**
   - Deploy `app_flutter/firebase/firestore.rules` and `app_flutter/firebase/firestore.indexes.json`.
   - **Crucial:** The composite index `photographers (acceptingOrders, specialties)` must be built before `createJob` serves production traffic, as `createJob` candidate matching relies on this query.
   - Deploy `app_flutter/firebase/storage.rules`.
2. **Deploy Cloud Functions:**
   - Deploy callables and triggers from `app_flutter/firebase/functions`.
   - Verify `bookingClock` scheduled function includes `runJobSweeps`.
   - No new secret is required (uses existing `PAYOUT_ACCOUNT_KEY` and firebase configs).
3. **Database Seed:**
   - Run seed scripts to add initial test job posts and quotes if in staging/dev.
4. **Deploy App:**
   - App is released with `kJobsEnabled = true`.

## Notification hooks emitted (#138)

- `job_match`: Emitted by trigger `onJobMatchCreated` to photographers matching a new job. Target: `/jobs/:id` (S16.01).
- `job_invited`: Emitted by trigger `onJobInviteCreated` to invited photographers. Target: `/jobs/:id` (S16.01).
- `quote_new`: Emitted by trigger `onJobQuoteWrite` when a photographer submits a quote. Grouped by job: `job:{jobId}:quotes`. Target: `/jobs/:id/applications` (S15.03).
- `quote_withdrawn`: Emitted by trigger `onJobQuoteWrite` when a quote is withdrawn. Target: `/jobs/:id/applications` (S15.03).
- `quote_accepted`: Emitted by trigger `onBookingWrite` when customer pays and booking becomes `accepted`. Target: `/b/:id` (S05.02). Note: replaces deprecated `job_selected` (`job_selected` is NOT emitted).
- `quote_not_selected`: Emitted by trigger `onJobQuoteWrite` when a quote is marked `not_selected`. Target: `/jobs/:id` (S16.01).
- `job_expiring`: Emitted by `bookingClock` -> `runJobSweeps` 24 hours before deadline if quotes exist. Target: `/jobs/:id/applications` (S15.03).
- `job_expired`: Emitted by `bookingClock` -> `runJobSweeps` when job deadline passes. Target: `/jobs/:id` (S15.02).

## Unit dependencies

- Ran after prerequisite foundation units: #198 (`n1-order-gate`) and #199 (`n2-booking-draft`).
- Built upon merged units: #129 (payments), #130 (reviews/tomato score), #138 (notifications), #147 (image uploads).
