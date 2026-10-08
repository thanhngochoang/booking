# S29 · Điểm chụp đang hot (trending photo spots) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (standing rule):** write them, do not run them; CI runs them. Record the skip in the ledger. No battery/performance, device build or iOS steps.

> **Detail level ("ở giữa", owner):** exact interfaces, tests listed by name with expected behaviour, sample code only for the hard parts.

**Goal:** Staff curate photo spots with a CLI (`npm run spots`); a daily job ranks them by recent activity and season and writes one ranking document per region, so Home shows "Điểm chụp đang hot" with a single read. A customer opens a spot (S29.02) and sees the photographers/studios who shoot there on given days (spot schedules), slot packages (gói chia suất), events and photos tagged there, then books through the normal S04 flow restricted to the schedule's packages, days and hours (or picks a slot in S29.06 and goes straight to S04.03). Providers open, edit and cancel spot schedules and slot offers (S29.03–S29.05). A spot day lets a provider take several non-overlapping bookings at that spot only. Events (S12.01) must choose a spot or "Không thuộc điểm chụp nào"; posts (S10.01) get a removable spot suggestion. Money, refunds, contact unlock, two-layer delivery and the order gate are unchanged (spec T9).

**Architecture:** Pure rules in `packages/domain`: `spot.ts` (model, regions, season, distance), `spot_slots.ts` (slot grid, slot offers), `spot_schedule.ts` (schedule input, day conflicts), `spot_booking.ts` (intervals, 15-minute gap, `assertSpotBooking`), `spot_schedule_use_cases.ts` (`saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer` over a transaction port with a per-provider lock document), `spot_score.ts` + `spot_ranking.ts` (`spotHotScore`, `rankSpots`, `spotDirectory`, `runSpotRanking` over a count port), `spot_admin.ts` (CLI use cases). A spot day is the holder's existing `availability/{uid}/days/{day}` document with the new server-only state `spot` (one per provider per day = the transaction lock), plus a public projection `spot_days/{scheduleId}_{day}` `{taken: [{start, end, offerId?}]}` written in the same transaction as the booking. `createBookingDraft` (with #152's `buildBookingDraft`, #144's gate and #190's add-ons already in it) gains a spot branch; every other path that reads or writes availability treats `spot` explicitly. Functions stay thin: four callables, one scheduled job `rankSpots` (the 10th Cloud Scheduler job), Firestore adapters with `count()` aggregations, the CLI and seed. Flutter: `lib/data/spots/`, `lib/features/spots/` (S29.01–S29.06), Home/Explore entries, the S04 flow's spot context, S06.01 entry, S12.01 and S10.01 tagging.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 `onCall` + `onSchedule`, Admin SDK aggregation `count()`, `sharp` for the CLI's cover resize, `node --test`), Firestore + Storage rules and indexes; Flutter, Riverpod 3, go_router, freezed (`build_runner`), `fake_cloud_firestore`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-08-trending-spots-design.md` (all; owner-approved 2026-10-08, binding); mock `docs/design/ui-mock.html` frames `#S29.01`, `#S29.02`, `#S29.02-empty`, `#S29.02-offseason`, `#S29.03`, `#S29.04`, `#S29.05`, `#S29.06`, `#S02.01-spots`, `#S02.03-spots`, `#S04.02-spot`, `#S12.01-spot`, `#S10.01-spot` (drawn together with the code-table rows of main spec §2, the S29 constants in `lib/core/screen_codes.dart` and `docs/superpowers/specs/screens/spots.md` before this plan runs; treat them as done); `docs/superpowers/specs/2026-10-08-booking-addons-design.md` (add-ons on the spot package flow, none on slot offers); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md`; `docs/superpowers/specs/2026-10-06-studio-members-design.md`; `docs/superpowers/specs/data-model/` (`README.md`, `domain-model.md`, `relational-schema.md`); cost unit prices `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`.

**Issue:** #194 (S29 · Điểm chụp đang hot). Phase 2 follow-ups: #195 (fully automatic hotness), #196 (save/follow spots).

**Branch:** `plan/194-trending-spots` from `origin/develop`; PR into `develop` titled `feat(spots): S29 trending photo spots and spot schedules [#194]`.

**Execution order:** after #190 (table "Thứ tự thực hiện (chia lại 2026-10-08)" in `2026-10-07-INDEX.md`). **Blocked by:** #190 (S04/S08 add-ons; hard, Decision 1), #136 (S26 studio members; hard), #132 (S02 discover; hard). Merged before those by the re-planned order: #199 N2 (`buildBookingDraft`, `BookingDraftInput`, `draftTotal`, `milestoneAmounts` — formerly #152's), #198 N1 (order gate `assertOrderAllowed`), #152 (S05 delivery, before #136), #144 (`hiddenUsersProvider`, after #198); #139 (`DomainError(code, field?)`, `findContactLeak`, `Booking.source`, `withdrawQuotesForDay`) is not on that chain: create-if-absent as #190 does, or wait for it. Already done: #129, #130, #134, #138, #147 (S10, `ImagePurpose`, uploader), events S11–S12 (PR #32). Soft: #140 (S13–S14 dispatch; Decision 17).

**Owns (others consume):** `Spot`, `SpotSchedule`, `SlotOffer`, `SpotDay`, `SpotInterval`, the `spot` availability state, `spotHotScore`, `rankSpots`, `spotDirectory`, `runSpotRanking`, `slotsFor`, `assertSpotBooking`, the four callables, the `rankSpots` job, the `spots` CLI, collections `spots`, `spot_rankings`, `spot_directory`, `spot_schedules`, `spot_slot_offers`, `spot_days`, Storage `spots/`, Dart `lib/data/spots/`, `lib/features/spots/`, core `SpotCard`, `SeasonTag`, `SlotGrid`. **Reuses without redefining:** `buildBookingDraft`/`BookingDraftInput` (#152, with #136, #139 and #190 extensions; extended in place), `assertOrderAllowed` (#144), `ProviderOrderGate.orderProfile` and `StudioRoster.relationOf` (#136), `priceAddonLines` (#190), `findContactLeak` + `DomainError(code, field?)` (#139), `withdrawQuotesForDay` (#139), `encodeGeohash` (`event.ts`), `formatVnDate`/`parseVnDateTime`/`addMinutesToTime` (`booking_policy.ts`), notifications (#138: no new type).

## Contract with existing code

Checked 2026-10-08 on `origin/develop` 905d27a (worktree base 9d1b7f4). Task 1 Step 1 and Task 2 Step 1 re-check the names the blocking plans bring; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- **Exists today.**
  - Domain: `AvailabilityDayRecord {state: 'off' | 'booked' | 'pending'; bookingId?}` and `BookingTx.getAvailabilityDay/setAvailabilityDay/deleteAvailabilityDay`, `getCustomerDraftForDay` (`booking_ports.ts`); `createBookingDraft` (`create_booking.ts`: refuses `off`/`booked`, allows the customer's own `pending` draft, replaces it, writes `pending`); `createPayment` refuses unless the day is `pending` for this booking (`create_payment.ts:81`); `commitTransition` writes `booked` on accept and deletes the day on decline/expire/cancel when `day.bookingId === booking.id` (`commit_transition.ts`); `runBookingSweeps` deletes expired drafts and their day hold (`booking_sweeps.ts`); chat reschedule moves the day hold (`reschedule.ts:195–210`); events: `publishEvent`/`updateEvent` refuse only `booked`/`pending` host days (`event_use_cases.ts:223, 276`), `AvailabilityRecord {state: 'off' | 'booked' | 'pending'; eventId?; bookingId?}` (`event_ports.ts:15`); `EventLocation {name, meetingPoint, lat, lng, geohash, areaId}`, `validateEventFields` (`event.ts`), `encodeGeohash` (`event.ts:262`); `Booking` (`booking.ts`: `place {name, point?}`, `serviceSnapshot {name, price, durationMinutes}`, `depositPaidAt?`); `ERROR_CODES` and `DomainError` (`errors.ts`); `computeDaySlots`, `addMinutesToTime`, `parseVnDateTime`, `formatVnDate`, `isDateString`, `isTimeString` (`booking_policy.ts`); `acceptsOrders` (`provider_orders.ts`); `isId` (`ids.ts`); album store pattern (`album_ports.ts`, `memory_album_store.ts`); `purity.test.ts`; `test/support/booking_world.ts`.
  - Functions: `AVAILABILITY_COLLECTION` and the booking transaction adapter (`infra/booking_firestore.ts`: `getAvailabilityDay` returns `{state, bookingId}` raw); event adapter maps any unknown day state to `'off'` (`infra/event_firestore.ts:337`, a bug once `spot` exists, Review Focus 2); `handleCreateBooking` passes `{...request.data, customerId}` (`callables/booking.ts`); `toHttpsError` + `TRANSPORT_CODE` (`callables/errors.ts`, details `{code}` today; #139 adds `field`); `CALLABLE_OPTIONS`, `SCHEDULE_OPTIONS` (`config.ts`); scheduled jobs in `src/index.ts` (`paymentClock`, `bookingClock`, `purgeAwardProofs`, `reconcileBadges`, `pruneNotifications`, `eventClock`, `releaseEventHolds` = 7; #134's `createPayouts` is the 8th and #132's `rollNextFreeDates` the 9th, so `rankSpots` is the **10th**); the staff CLI pattern `tools/awards.ts` (`guardEnv`, `HELP`, `--actor` admin check) + `test/unit/award_cli.test.ts` + `scripts/awards-local.sh`; seed `seed/fixtures.ts` (`seedDocuments(now)`, `SEED_POSTS` with `https://seed.test/...` images, An `seed-photographer-an` in Hà Nội, Bình in Đà Nẵng, Cúc studio in TP.HCM), `seed/apply.ts` (`applySeed`), `seed/README.md`.
  - Rules (`app_flutter/firebase/firestore.rules`): `availability/{uid}/days/{dayKey}` (read signed-in; client creates/deletes only `off`); `posts/{postId}` created by the client through `validPostCreate()` (`hasOnly([... 'location', ...])`, no `spotId`); `bookings` server-only. Storage (`storage.rules`): `eventCovers/{uid}/{eventId}/{file}` pattern, `jpegUpTo(...)`.
  - App: `AvailabilityDay` + `availabilityDayFromFirestore` (unknown state → `DayState.booked`, `lib/data/photographer/availability_repository.dart`); `DayState {free, pending, booked, off}` (`core/widgets/availability_calendar.dart`); `BookingFlowArgs {photographerId, serviceId?, day?, area?}`, `BookingFlowState`, `BookingFlowController`, `BookingStep {service, datetime, place, review}` (`features/booking/booking_flow_*.dart`); `daySlots(duration)` (`data/booking/booking_rules.dart`); `bookingPath(...)`/`startBooking(...)` (`features/discovery/book_entry.dart`); route `/u/:uid/book` (`app/router.dart`); `BookingRepository.createBooking({photographerId, serviceId, day, start, place, note, expectedPrice})`, `BookingErrorCode` + `bookingErrorOf` (`data/booking/booking_repository.dart`); `ExploreScreen` + `ExploreCategoryTab.places` (area tiles) and the S02.04 events section (`features/explore/explore_screen.dart`); `HomeScreen` sections (`features/home/home_screen.dart`); `locationControllerProvider`, `areasProvider`, `builtInAreas` (ids `hcm-q1`, `hcm-q3`, `hcm-q7`, `hcm-binh-thanh`, `hcm-thu-duc`, `hn-hoan-kiem`, `hn-ba-dinh`, `hn-cau-giay`, …, `dn-hai-chau`, `hue`, `da-lat`, `nha-trang`; `data/location/area.dart`); `haversineKm` (`core/geo.dart`); `formatDay` ("CN 18/10"), `weekdayLabel`, `formatDayMonth`, `priceFromLabel`, `formatDuration`, `formatMoney` (`core/format.dart`); `vnDateKey`, `dayKeyOf` (`core/vn_time.dart`); `externalLauncherProvider` (`data/contact/contact_providers.dart`); event link copy (`features/events/event_links.dart`, `copyEventLink`); `postFromFirestore` (`data/content/firestore_post_repository.dart`), `eventSummaryFromFirestore` (`data/events/firestore_event_mapping.dart`); `PostDraft` + `FirestorePostPublisher` (`data/content/post_publisher.dart`, `firestore_post_publisher.dart`); `EventDraft` (`data/events/event_draft.dart`), `PlaceField` and `CreateEventScreen` (`features/event_create/`); `CreatePostScreen` (`features/create_post/create_post_screen.dart`, field `create-location`); `WorkScreen` (`features/work/work_screen.dart`, app-bar action `open-calendar`); `PhotographerSummary` (`acceptingOrders`, `lat`, `lng`); `EventCard`, `PhotoCard`, `PhotographerCard`, `SegmentedTabs`, `AppChip`, `GlassCard`, `AppBottomSheet`, `ConfirmSheet`, `EmptyState`, `ErrorState`, `AsyncView`, `AppSkeleton`, `SectionHeader`, `AvailabilityCalendar`, `ScreenCode`; l10n `exploreSeeAll` "Xem tất cả", `exploreTabPlaces`.
- **Added by the blocking plans (verify in Step 1 of Tasks 1, 2, 6, 7).** #152: `BookingDraftInput`, `buildBookingDraft`. #139: `DomainError(code, field?)`, `details.field` in `toHttpsError`, `findContactLeak`, `Booking.source?: 'package' | 'quote' | 'instant'`, `withdrawQuotesForDay(deps, photographerId, day, exceptJobId)`. #144: `assertOrderAllowed` in `createBookingDraft`, `hiddenUsersProvider`. #136: `ProviderOrderGate.orderProfile(uid) → {acceptsOrders, providerType} | null`, `StudioRoster.relationOf(studioId, uid) → 'member' | 'collaborator' | null`, studio fields in `buildBookingDraft` (`assigneeId`, `assigneeKind`, `assignedAt`, …), `assignBooking`, `assignmentOptions` + `MemberDayReader`, `requestAssigneeChange`, `returnAssignment`, `leaveStudio`, `removeMember`, `studio_day_load`, `DayState.full`. #190: `priceAddonLines`, `CreateBookingDraftInput.addons/pickup/expectedTotal`, the S04.06 place step with its own `ScreenCode`, `BookingFlowState.addons/picks`. #132: Home/Explore rework, `photographers.startingPrice`, cached photographer pool.
- **Not anywhere yet:** any `spot` name, state, collection, route, string or index.

## Global Constraints

- Spec T5: on a spot day the holder takes only `source = spot | spot_slot` bookings of that schedule; any two intervals that day are ≥ 15 minutes apart, except two slots of the same slot offer (their grid already has the offer's gap). A normal booking, quote, studio assignment or event on that day is refused.
- Spec T6: slot-offer bookings carry no add-ons; package bookings at a spot keep #190's add-ons and pickup.
- Spec T9 / CLAUDE.md money and contact rules: 100% up front, held, two-milestone release, refund table, contact unlock after payment, `assertOrderAllowed` on every order path — unchanged, fake rails only (`PAYMENTS_MODE`, `confirmFakePayment`).
- `spot_days` is public: it holds `{scheduleId, spotId, providerId, day, taken: [{start, end, offerId?}], updatedAt}` and never a booking id, customer id, name or phone.
- Limits (spec §3.1, §5.1, §5.2): spot name 3–60 graphemes, radius 100–3,000 m, description ≤ 600, ≤ 5 tips of ≤ 120; schedule ≤ 40 days, each within 60 days from today (VN), window 05:00–21:00, 1–12 h, on a 15-minute grid; ≤ 8 open schedules per provider; slot offer name 3–60, price integer VND 10,000–100,000,000, `slotMinutes` 15–90, `gapMinutes` 0–30, `photoCount` 1–500, `editedCount` 0–`photoCount`, `deliveryDays` 1–30, ≤ 2 open offers per schedule.
- CLAUDE.md: business rules only in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; `cloud_firestore`/`cloud_functions` only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; imports `package:photobooking/...`, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only (Material Symbols Rounded, 60-30-10); one primary action per screen (S29.03 "Thêm lịch tại điểm", S29.04 "Mở lịch", S29.05 "Lưu", S29.06 "Tiếp tục · {giá}"; S29.01/S29.02 have none — small "Đặt"/"Chọn suất" card buttons are allowed like `PhotographerCard`); cancel is red text + red button in `ConfirmSheet`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`.
- Data model (`data-model/README.md`): ULID ids (`deps.ids.newId()`), UTC ISO instants in the domain, Firestore `Timestamp` only in adapters, integer VND, string enum codes, local days `yyyy-MM-dd` and times `HH:mm` in Asia/Ho_Chi_Minh.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time, never the whole suite in one command; bounded pumps (`pump(Duration)`), no `pumpAndSettle` on screens with `DotRingLoader`/`SignatureLoader`.
- Domain: `(cd packages/domain && npm test && npm run lint)`. Functions: `(cd app_flutter/firebase/functions && npm test && npm run build)`. Rules tests (`app_flutter/firebase/rules-test/rules.test.mjs`) and Functions integration tests are written, not run.
- Commits: Conventional Commits, subject ends with `[#194]`, body ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (owner's rule; never the Claude line).

## Decisions

1. **Blockers and wave.** #190 is a **hard** blocker: the spot package flow edits the same files (`create_booking.ts`, `booking_requests.ts`, `booking_flow_controller.dart`, `service_step.dart`, `review_step.dart`), the locked place lives on #190's S04.06 step (its Decision 13 gives the place step its own screen), and T6 must refuse `addons` on slot bookings with #190's field names. #136 is hard: studio schedules use `orderProfile`, `relationOf`, the builder's studio fields, and this plan extends `assignBooking`, `assignmentOptions`, `requestAssigneeChange`, `returnAssignment`, `leaveStudio`, `removeMember` in place. #132 is hard: Home and Explore are reworked there and S29.02 reads its `startingPrice`. Running next to #190 in wave 5 would collide in the same files, so this plan is wave 6.
2. **Region granularity.** Rankings per S02.05 district would leave almost every user without spots ("Quận 1" has no hill tea). `spots.areaCode` is a **city-level** code of the S02.05 taxonomy: the domain list `SPOT_AREAS` = `hcm` TP.HCM, `hn` Hà Nội, `dn` Đà Nẵng, `hue` Huế, `da-lat` Đà Lạt, `nha-trang` Nha Trang, `hoi-an` Hội An, `yen-bai` Yên Bái (staff add codes in code; ledger). A user's region is `regionOfArea(areaId)`: the prefix before the first `-` when it is `hcm`, `hn` or `dn`, else the id itself (`da-lat` → `da-lat`); with GPS, the nearest `builtInAreas` entry first; no location → `all`. `spot_rankings/{areaCode}` is keyed by this code.
3. **One directory document.** The job and the CLI also write `spot_directory/all` (every `active` spot, ≈ 350 B each, ≤ 1 MiB up to ~2,500 spots): S29.01 (client-side pages of 20, spec §4.2), S02.03-spots, the S02.04 row, the S29.04 picker and the S12.01/S10.01 suggestions all read this one document (cached per session) instead of querying `spots`. So the spec index `spots(areaCode, status, hotScore desc)` is not created; single spots are read by id.
4. **Spot-day model.** Opening a schedule writes `availability/{holder}/days/{day}` = `{state: 'spot', scheduleId, spotId, updatedAt}` for each day (holder = `assigneeId ?? providerId`, Decision 7). That document is the per-provider-per-day lock: every spot booking transaction reads it and reads + writes `spot_days/{scheduleId}_{day}`, so two customers booking clashing times serialize and the second gets `slot_taken`. Drafts hold their interval like they hold a day today (released by the draft sweep at `payableUntil`); payment checks the interval is still there; accept writes nothing; decline/expire/cancel remove the interval matching `{start, end}` exactly (intervals of one day never overlap, so the match is unique). The gap between two intervals is 15 minutes, 0 when both carry the same `offerId`.
5. **Error codes.** New: `outside_schedule`, `slot_taken`, `day_conflict`, `schedule_limit`, `spot_archived` (spec §7) and `schedule_has_bookings` (spec §5.3's "Còn {n} booking ngày {ngày}" needs its own code; `details.days: [{day, count}]`). `day_conflict` carries `details.days: [{day, reason: 'booked' | 'pending' | 'off' | 'spot' | 'full'}]`. Spec §5.3 says a normal booking into a spot day is `day_conflict`; this plan answers the existing **`day_taken`** there because for the customer it means exactly "ngày này không đặt được" and S04.02 already handles it (the day is drawn booked). `DomainError` gains an optional third argument `details` (after #139's `field`), copied into the callable error's `details`. Slot-offer count above 2 is the existing `limit_exceeded`.
6. **Every availability path treats `spot` explicitly.** `createBookingDraft` (normal → `day_taken`), `createPayment` (interval check), `commitTransition` (no `booked` write; release interval), `runBookingSweeps` (release interval), `reschedule` (spot bookings → `not_eligible`; normal into a spot day already `day_taken`), `publishEvent`/`updateEvent` (`spot` → `day_taken`), the event adapter (map `spot`, never to `off`), #136's member-day reader (`spot` = busy with the schedule window), and any path #139/#140/#151 added (Task 2 Step 1 greps them). The app keeps mapping unknown states to `DayState.booked`, so customers see a spot day as taken outside the spot flow (no new `DayState`).
7. **Studios.** A studio schedule names one member (`assigneeId`, required for `providerType == 'studio'`, forbidden otherwise) who must be a `member` (`relationOf`; S27 collaborators excluded in Phase 1) and pass the order gate. The spot day is written on the member's availability, which #136 already counts as "not free" for studio capacity (spec §5.3 "mỗi thợ một điểm một ngày"). Spot bookings of a studio are created already assigned (`assigneeId`, `assigneeKind: 'member'`, `assignedAt = now`) and never enter `studio_day_load`; `assignBooking`, `requestAssigneeChange` and `returnAssignment` on them are `not_eligible`; `leaveStudio`/`removeMember` are `member_busy` while the member is the assignee of an `open` schedule with a day ≥ today. `spotId` and `assigneeId` are immutable after creation (cancel and open a new schedule).
8. **Slot bookings.** `createBooking` with `slotOfferId` builds a synthetic `ServiceRecord` `{id: offer.id, photographerId: providerId, name: offer.name, price: offer.price, durationMinutes: offer.slotMinutes, active: offer.status == 'open'}` (the #139 quote pattern); `serviceId = slotOfferId`; `expectedPrice` compares with `offer.price` (`price_changed`); `start` must be one of `slotsFor(window, …)`; any `addons` or `pickup` → `invalid_argument` (T6). Booking fields: `spotId`, `spotScheduleId`, `slotOfferId?`, `source: 'spot' | 'spot_slot'` (extends #139's `source`).
9. **The place is the spot.** For both sources the server sets `place = {name: spot.name, point: spot.point}` whatever the request says; S04.06 shows it locked; #190's pickup still works for package bookings with a transport add-on.
10. **Archived spots** accept no new schedule and no new booking (`spot_archived`); existing bookings and schedules stay (providers may cancel empty schedules); the page opens with the band "Điểm này không còn nhận lịch mới" and hides the providers/offers blocks.
11. **Schedule limits are race-proof.** Every schedule/offer transaction reads and writes `photographers/{uid}/private/spot_schedules` (`{updatedAt}`), then counts open schedules with a day ≥ today by query inside the transaction (≤ 8). Removing a day or narrowing the window is refused (`schedule_has_bookings`) when an interval (paid or draft) would be dropped or fall outside; past days stay stored unchanged.
12. **Ranking.** `stats = {posts14d, events, bookings14d, openSchedules, providersWeek, providersWeekend}` (the last two serve "{n} thợ nhận chụp tuần này" and the filter "Cuối tuần này có thợ"; one provider holds a day for one schedule only, so a schedule count is a provider count). `hotScore = round((1·posts14d + 3·events + 2·bookings14d + 2·openSchedules) × (in season ? 1.5 : 1))`; "in season" needs a non-empty `seasonMonths` containing the VN month. Hot list of a region: its pinned spots (active, not hidden) then up to 10 spots with `hotScore > 0`, active, not hidden, in season or season-less, by score; fewer than 10 → filled from the national hot list; ≤ 20 entries. `all` = every pinned spot then the national top 10. `hidden` only removes a spot from hot lists: S29.01 still lists it among "còn lại". The job writes a spot only when its stats, score or flags changed.
13. **Posts.** Posts are client-written and have no coordinates (only `location` text; S10 strips EXIF). The S10.01 suggestion is the directory spot whose accent-folded name is contained in the location text (or vice versa), else the active spot whose radius contains the device position the app already has (`LocationState.location`, no new permission prompt). Rules accept an optional `spotId` naming an `active` spot. There is no hidden/removed/pending post state yet (moderation is #83/S23), so the page shows every tagged post minus #144's blocked users, and the job counts every tagged post; adding a `visible` filter is Deferred with that state.
14. **Events.** The server accepts `spotId: string | null` in `saveEventDraft`/`publishEvent`/`updateEvent`; a string must name an `active` spot whose centre is within `radiusM + 500 m` of the event location (`invalid_argument`, field `spotId`) or `spot_archived`. "Bắt buộc chọn" is an S12.01 form rule (the app requires a choice before publishing); old events and old clients read as `null`.
15. **No auto-accept.** Spot and slot bookings follow the normal lifecycle (`requested` → provider accepts within `ACCEPT_DEADLINE_HOURS`), so payment, refunds, reminders and two milestones are untouched (Needs the owner 1).
16. **Reschedule.** A chat reschedule proposal on a spot booking is refused `not_eligible` in Phase 1 (moving an interval inside a schedule needs its own UI); the customer cancels (refund table) and books another time.
17. **Instant booking (#140).** Spec §12: a spot day blocks "Chụp ngay" inside the schedule window. If #140 has merged when Task 2 runs, its candidate filter skips a photographer whose today record is `spot` and `now` is inside the window (`spotBusyAt(record, schedule, now)`, pure); if not, Task 10 comments the rule on #140 and ledgers it.
18. **Quotes.** After `saveSpotSchedule` commits, the callable adapter runs #139's `withdrawQuotesForDay(jobDeps, holder, day, null)` for each newly added day (a quote for that day could no longer become a booking).
19. **Provider summaries on S29.02** come from the existing public photographer provider (cached pool of #132); schedules of providers whose `acceptingOrders` is false are not shown (spec §12). `priceFrom` is denormalized on the schedule at save time (minimum price of the enabled active packages); S04.01 shows live prices.
20. **Covers.** The CLI resizes one JPEG into `spots/{spotId}/cover.jpg` (long side 1600, q80, the `ImagePurpose.share` limits) and `spots/{spotId}/card.jpg` (long side 480, q75) with `sharp` (dependency added by #152), `Cache-Control: public, max-age=604800`. Cards use `cardUrl`, the S29.02 hero uses `url`. Storage rules: signed-in read, no client write.
21. **Counts on S29.03** ("số booking theo ngày") come from the provider's bookings already loaded by the work screen (`spotScheduleId` + `day`), not from reading every `spot_days` document.
22. **Static map without a Maps API.** S29.02's "bản đồ nhỏ tĩnh" reuses #140's `MapPreview` (drawn, no tiles) when it exists; otherwise a small drawn tile in the mock's `.map` style with a pin and the spot name (private widget in `spot_screen.dart`). "Chỉ đường" opens `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}` through `externalLauncherProvider` (no key, no SKU).
23. **Copy.** The l10n keys below carry the spec's Vietnamese; where the S29 frames differ, the mock wins and the difference is ledgered (CLAUDE.md "UI matches the mock").

## Needs the owner

1. Should a slot or spot booking be confirmed without the provider accepting it (the provider opened the schedule)? Default: no, the normal accept step (Decision 15).
2. Studio schedules: one named member per schedule, fixed until the schedule is cancelled? Default: yes (Decision 7).
3. Archived spot: also stop new bookings on schedules already open there? Default: yes (Decision 10).
4. Photo egress: spot-page masonry may add up to ≈ $9/month at 10,000 MAU until the thumbnail unit of the cost spec (§11) exists. Default: ship with 9 first-image tiles loaded lazily, thumbnails as their own unit (see Chi phí Google).

## Contract

### Firestore

| Path | Fields | Writer / readers |
|---|---|---|
| `spots/{spotId}` (ULID) | `name`, `city`, `areaCode`, `point` (`GeoPoint`), `geohash`, `radiusM`, `cover: {url, cardUrl, path} \| null`, `description`, `tips: string[]`, `seasonMonths: int[]`, `pinned`, `hidden`, `status` (`active`\|`archived`), `hotScore`, `stats: {posts14d, events, bookings14d, openSchedules, providersWeek, providersWeekend}`, `createdAt`, `updatedAt`, `rankedAt`, `updatedBy` | server (CLI, job) / signed-in |
| `spot_rankings/{areaCode \| 'all'}` | `key`, `entries: [{spotId, name, city, areaCode, cardUrl, lat, lng, seasonMonths, inSeason, providersWeek, pinned}]` (≤ 20), `rankedAt` | job, CLI / signed-in |
| `spot_directory/all` | `entries: [{spotId, name, city, areaCode, lat, lng, radiusM, cardUrl, seasonMonths, inSeason, pinned, hidden, hotScore, openSchedules, providersWeek, providersWeekend, upcomingEvents}]` (active spots only), `updatedAt` | job, CLI / signed-in |
| `spot_schedules/{id}` (ULID) | `providerId`, `assigneeId` (null unless studio), `spotId`, `days: string[]` (sorted), `window: {start, end}`, `serviceIds: string[]` (`[]` = every active package), `priceFrom: int \| null`, `status` (`open`\|`cancelled`), `createdAt`, `updatedAt` | callables / signed-in when `open`; provider and assignee always |
| `spot_slot_offers/{id}` (ULID) | `providerId`, `scheduleId`, `spotId`, `name`, `price`, `slotMinutes`, `gapMinutes`, `photoCount`, `editedCount`, `deliveryDays`, `status` (`open`\|`closed`), `createdAt`, `updatedAt` | callables / signed-in when `open`; provider always |
| `spot_days/{scheduleId}_{day}` | `scheduleId`, `spotId`, `providerId`, `day`, `taken: [{start, end, offerId?}]`, `updatedAt` | booking transactions / signed-in |
| `availability/{uid}/days/{day}` | adds server-only state `spot` with `scheduleId`, `spotId`, `updatedAt` | callables / signed-in (unchanged rule) |
| `photographers/{uid}/private/spot_schedules` | `updatedAt` (lock) | callables / owner (existing `private` rule) |
| `bookings/{id}` | adds `spotId`, `spotScheduleId`, `slotOfferId` (slot only), `source: 'spot' \| 'spot_slot'` | unchanged |
| `events/{id}` | adds `spotId: string \| null` | unchanged (callables) |
| `posts/{id}` | adds optional `spotId` (client, validated by rules) | client create |
| Storage `spots/{spotId}/cover.jpg`, `card.jpg` | JPEG, `Cache-Control: public, max-age=604800` | CLI / signed-in |

Rules (Task 3 adds these top-level blocks; posts change in Task 9):
```
// Spots (spec 2026-10-08 S29). Written only by the server (CLI, rankSpots, callables).
match /spots/{spotId} { allow read: if signedIn(); allow write: if false; }
match /spot_rankings/{key} { allow read: if signedIn(); allow write: if false; }
match /spot_directory/{docId} { allow read: if signedIn(); allow write: if false; }
match /spot_schedules/{id} {
  allow read: if signedIn() && (resource.data.status == 'open'
    || resource.data.providerId == request.auth.uid || resource.data.assigneeId == request.auth.uid);
  allow write: if false;
}
match /spot_slot_offers/{id} {
  allow read: if signedIn() && (resource.data.status == 'open' || resource.data.providerId == request.auth.uid);
  allow write: if false;
}
// Public projection of a spot day: times only, never who booked (Global Constraints).
match /spot_days/{id} { allow read: if signedIn(); allow write: if false; }
```
Storage: `match /spots/{spotId}/{file} { allow read: if request.auth != null; allow write: if false; }`.

Indexes (`firestore.indexes.json`): `spot_schedules (spotId ASC, status ASC)`, `spot_schedules (providerId ASC, status ASC)`, `spot_schedules (assigneeId ASC, status ASC)`, `spot_schedules (spotId ASC, status ASC, days CONTAINS)`, `spot_slot_offers (spotId ASC, status ASC)`, `spot_slot_offers (providerId ASC, status ASC)`, `spot_slot_offers (scheduleId ASC, status ASC)`, `posts (spotId ASC, createdAt DESC)`, `events (spotId ASC, status ASC, startAt ASC)`, `bookings (spotId ASC, depositPaidAt ASC)`.

### Domain (`packages/domain/src`)

```ts
// spot.ts
export const SPOT_STATUSES = ['active', 'archived'] as const; export type SpotStatus = (typeof SPOT_STATUSES)[number];
export const SPOT_AREAS = [
  { code: 'hcm', name: 'TP.HCM' }, { code: 'hn', name: 'Hà Nội' }, { code: 'dn', name: 'Đà Nẵng' }, { code: 'hue', name: 'Huế' },
  { code: 'da-lat', name: 'Đà Lạt' }, { code: 'nha-trang', name: 'Nha Trang' }, { code: 'hoi-an', name: 'Hội An' },
  { code: 'yen-bai', name: 'Yên Bái' },
] as const;
export const SPOT_NAME_MIN = 3, SPOT_NAME_MAX = 60, SPOT_RADIUS_MIN = 100, SPOT_RADIUS_MAX = 3000,
  SPOT_DESCRIPTION_MAX = 600, SPOT_TIPS_MAX = 5, SPOT_TIP_MAX = 120, SPOT_EVENT_SLACK_M = 500;
export interface LatLng { readonly lat: number; readonly lng: number }
export interface SpotStats { readonly posts14d: number; readonly events: number; readonly bookings14d: number;
  readonly openSchedules: number; readonly providersWeek: number; readonly providersWeekend: number }
export interface SpotCover { readonly url: string; readonly cardUrl: string; readonly path: string }
export interface Spot {
  readonly id: string; readonly name: string; readonly city: string; readonly areaCode: string; readonly point: LatLng;
  readonly geohash: string; readonly radiusM: number; readonly cover: SpotCover | null; readonly description: string;
  readonly tips: readonly string[]; readonly seasonMonths: readonly number[]; readonly pinned: boolean; readonly hidden: boolean;
  readonly status: SpotStatus; readonly hotScore: number; readonly stats: SpotStats;
  readonly createdAt: string; readonly updatedAt: string; readonly rankedAt: string | null; readonly updatedBy: string;
}
export const EMPTY_SPOT_STATS: SpotStats;
export function regionOfArea(areaId: string | null): string;                 // Decision 2; null → 'all'
export function inSeason(seasonMonths: readonly number[], month: number): boolean;   // non-empty and contains month
export function seasonOk(s: Pick<Spot, 'seasonMonths'>, month: number): boolean;     // empty or inSeason
export function seasonRunEnd(seasonMonths: readonly number[], month: number): number | null; // last month of the run containing `month`, wraps 12→1
export function distanceMeters(a: LatLng, b: LatLng): number;                        // haversine, R = 6_371_000
export function spotCovers(s: Pick<Spot, 'point' | 'radiusM'>, p: LatLng, slackM?: number): boolean;

// spot_schedule.ts
export interface SpotWindow { readonly start: string; readonly end: string }      // HH:mm, VN time
export const SCHEDULE_MAX_DAYS = 40, SCHEDULE_DAYS_AHEAD = 60, MAX_OPEN_SCHEDULES = 8, WINDOW_EARLIEST = '05:00',
  WINDOW_LATEST = '21:00', WINDOW_MIN_MINUTES = 60, WINDOW_MAX_MINUTES = 720, WINDOW_STEP_MINUTES = 15;
export interface SpotSchedule {
  readonly id: string; readonly providerId: string; readonly assigneeId: string | null; readonly spotId: string;
  readonly days: readonly string[]; readonly window: SpotWindow; readonly serviceIds: readonly string[];
  readonly priceFrom: number | null; readonly status: 'open' | 'cancelled'; readonly createdAt: string; readonly updatedAt: string;
}
export interface SpotScheduleInput { readonly scheduleId?: string; readonly spotId: string; readonly days: readonly string[];
  readonly window: SpotWindow; readonly serviceIds: readonly string[]; readonly assigneeId?: string }
/** Unique sorted days, each today ≤ d ≤ today + 60, ≤ 40, ≥ 1; window rules; ids. DomainError('invalid_argument', field). */
export function validateScheduleInput(raw: unknown, today: string): SpotScheduleInput;
export function minutesOf(t: string): number; export function timeOf(minutes: number): string;
export const dayHolderOf = (s: Pick<SpotSchedule, 'assigneeId' | 'providerId'>): string => s.assigneeId ?? s.providerId;
export interface DayConflict { readonly day: string; readonly reason: 'booked' | 'pending' | 'off' | 'spot' | 'full' }
/** A day is free when it has no record, or a `spot` record of `ownScheduleId`. */
export function dayConflicts(days: readonly string[], records: ReadonlyMap<string, AvailabilityDayRecord | null>,
  ownScheduleId: string | null): DayConflict[];
export function priceFromOf(active: readonly ServiceRecord[], serviceIds: readonly string[]): number;  // invalid_argument 'serviceIds' if an id is unknown or nothing is enabled
export function scheduleEditBlocks(removed: readonly string[], window: SpotWindow,
  spotDays: ReadonlyMap<string, SpotDay | null>): { day: string; count: number }[];

// spot_slots.ts
export const SLOT_MINUTES_MIN = 15, SLOT_MINUTES_MAX = 90, SLOT_GAP_MAX = 30, MAX_OFFERS_PER_SCHEDULE = 2,
  SLOT_NAME_MIN = 3, SLOT_NAME_MAX = 60, SLOT_PRICE_MIN = 10_000, SLOT_PRICE_MAX = 100_000_000,
  SLOT_PHOTOS_MAX = 500, SLOT_DELIVERY_DAYS_MAX = 30;
export interface SlotOffer {
  readonly id: string; readonly providerId: string; readonly scheduleId: string; readonly spotId: string; readonly name: string;
  readonly price: number; readonly slotMinutes: number; readonly gapMinutes: number; readonly photoCount: number;
  readonly editedCount: number; readonly deliveryDays: number; readonly status: 'open' | 'closed';
  readonly createdAt: string; readonly updatedAt: string;
}
export interface SlotOfferInput { readonly offerId?: string; readonly scheduleId: string; readonly name: string; readonly price: number;
  readonly slotMinutes: number; readonly gapMinutes: number; readonly photoCount: number; readonly editedCount: number; readonly deliveryDays: number }
export function validateSlotOfferInput(raw: unknown): SlotOfferInput;   // + findContactLeak(name) → contact_leak 'name'
/** [start, start + slotMinutes] every slotMinutes + gapMinutes from window.start while the slot ends ≤ window.end. */
export function slotsFor(window: SpotWindow, slotMinutes: number, gapMinutes: number): { start: string; end: string }[];

// spot_booking.ts
export const SPOT_BOOKING_GAP_MINUTES = 15;
export interface SpotInterval { readonly start: string; readonly end: string; readonly offerId?: string }
export interface SpotDay { readonly scheduleId: string; readonly spotId: string; readonly providerId: string;
  readonly day: string; readonly taken: readonly SpotInterval[]; readonly updatedAt: string }
export const spotDayId = (scheduleId: string, day: string): string => `${scheduleId}_${day}`;
export function requiredGap(a: SpotInterval, b: SpotInterval): number;            // 0 for the same offerId, else 15
export function clashes(c: SpotInterval, taken: readonly SpotInterval[]): boolean;
export function freeStartTimes(window: SpotWindow, durationMinutes: number, taken: readonly SpotInterval[], stepMinutes?: number): string[]; // step 30
export function freeSlots(window: SpotWindow, offer: Pick<SlotOffer, 'id' | 'slotMinutes' | 'gapMinutes'>,
  taken: readonly SpotInterval[]): { start: string; end: string; free: boolean }[];
export interface SpotBookingCheck { readonly spot: Spot; readonly schedule: SpotSchedule; readonly offer: SlotOffer | null;
  readonly serviceId: string; readonly day: string; readonly start: string; readonly end: string;
  readonly taken: readonly SpotInterval[] }
/** spot_archived · outside_schedule (closed schedule/offer, day not in days, package not enabled, outside window, start not on the slot grid) · slot_taken. */
export function assertSpotBooking(c: SpotBookingCheck): void;
export function withInterval(day: SpotDay | null, base: Omit<SpotDay, 'taken' | 'updatedAt'>, iv: SpotInterval, now: string): SpotDay;
export function withoutInterval(day: SpotDay, iv: Pick<SpotInterval, 'start' | 'end'>, now: string): SpotDay;  // exact match; no match → unchanged
export function spotBusyAt(rec: AvailabilityDayRecord | null, schedule: SpotSchedule | null, now: Date): boolean;  // Decision 17

// spot_schedule_ports.ts
export interface SpotScheduleTx {
  lockProvider(providerId: string): Promise<void>;                       // reads photographers/{uid}/private/spot_schedules
  getSpot(id: string): Promise<Spot | null>;
  getSchedule(id: string): Promise<SpotSchedule | null>;
  openSchedulesOf(providerId: string, today: string): Promise<SpotSchedule[]>;   // status open, some day ≥ today
  activeServices(providerId: string): Promise<ServiceRecord[]>;
  availability(uid: string, day: string): Promise<AvailabilityDayRecord | null>;
  getSpotDay(scheduleId: string, day: string): Promise<SpotDay | null>;
  offersOf(scheduleId: string): Promise<SlotOffer[]>;                    // open and closed
  getOffer(id: string): Promise<SlotOffer | null>;
  putSchedule(s: SpotSchedule): void; putOffer(o: SlotOffer): void; touchLock(providerId: string, now: string): void;
  setSpotAvailability(uid: string, day: string, rec: { scheduleId: string; spotId: string }, now: string): void;
  deleteAvailability(uid: string, day: string): void;
}
export interface SpotScheduleStore { runTransaction<T>(fn: (tx: SpotScheduleTx) => Promise<T>): Promise<T> }
export interface SpotScheduleDeps { readonly schedules: SpotScheduleStore; readonly providers: ProviderOrderGate;  // with #136's orderProfile
  readonly roster: StudioRoster; readonly clock: Clock; readonly ids: IdGenerator }

// spot_schedule_use_cases.ts
export function saveSpotSchedule(deps: SpotScheduleDeps, callerId: string, raw: unknown): Promise<{ scheduleId: string; addedDays: string[] }>;
export function cancelSpotSchedule(deps: SpotScheduleDeps, callerId: string, raw: unknown /* {scheduleId} */): Promise<Record<string, never>>;
export function saveSlotOffer(deps: SpotScheduleDeps, callerId: string, raw: unknown): Promise<{ offerId: string }>;
export function closeSlotOffer(deps: SpotScheduleDeps, callerId: string, raw: unknown /* {offerId} */): Promise<Record<string, never>>;
// memory_spot_store.ts: MemorySpotStore implements SpotScheduleStore (+ spots, availability, spot days maps; serialized transactions; refuses reads after writes)

// booking side (extended in place)
// booking_ports.ts: AvailabilityDayRecord.state adds 'spot'; adds scheduleId?, spotId?
//   BookingTx adds getSpot(id), getSpotSchedule(id), getSlotOffer(id), getSpotDay(scheduleId, day), setSpotDay(d: SpotDay)
// booking.ts: Booking adds spotId?, spotScheduleId?, slotOfferId?; source adds 'spot' | 'spot_slot'
// booking_requests.ts: CreateBookingDraftInput adds spotScheduleId?: string, slotOfferId?: string (slotOfferId needs spotScheduleId)
// create_booking.ts: BookingDraftInput adds spot?: { spotId; scheduleId; slotOfferId?; source: 'spot' | 'spot_slot' };
//   buildBookingDraft copies them; studio spot bookings pass #136's assignee fields pre-filled (Decision 7)
// event_ports.ts: AvailabilityRecord.state adds 'spot'; EventTx adds getSpot(id): Promise<Spot | null> (Task 9)
// event.ts: EventRecord adds spotId: string | null; validateEventFields reads 'spotId' (Task 9)

// spot_score.ts + spot_ranking.ts (Task 4)
export const HOT_WEIGHTS = { posts14d: 1, events: 3, bookings14d: 2, openSchedules: 2 } as const;
export const SEASON_MULTIPLIER = 1.5, RANK_HOT_LIMIT = 10, RANKING_MAX_ENTRIES = 20;
export function spotHotScore(stats: SpotStats, seasonMonths: readonly number[], month: number): number;
export interface RankingEntry { readonly spotId: string; readonly name: string; readonly city: string; readonly areaCode: string;
  readonly cardUrl: string | null; readonly lat: number; readonly lng: number; readonly seasonMonths: readonly number[];
  readonly inSeason: boolean; readonly providersWeek: number; readonly pinned: boolean }
export interface SpotRankings { readonly key: string; readonly entries: readonly RankingEntry[]; readonly rankedAt: string }
export function rankSpots(spots: readonly Spot[], month: number, now: string): SpotRankings[];   // 'all' + one per areaCode with an active spot
export interface DirectoryEntry extends RankingEntry { readonly radiusM: number; readonly hidden: boolean; readonly hotScore: number;
  readonly openSchedules: number; readonly providersWeekend: number; readonly upcomingEvents: number }
export function spotDirectory(spots: readonly Spot[], month: number): DirectoryEntry[];          // active only
export interface SpotCounter {
  posts(spotId: string, sinceIso: string): Promise<number>;
  events(spotId: string, fromIso: string, toIso: string): Promise<number>;   // status open|full, startAt in range
  paidBookings(spotId: string, sinceIso: string): Promise<number>;           // depositPaidAt ≥ since
  schedulesWithDay(spotId: string, days: readonly string[]): Promise<number>; // open, array-contains-any (≤ 30 days)
}
export interface SpotRankStore { listSpots(): Promise<Spot[]>; saveSpot(s: Spot): Promise<void>;
  saveRankings(r: readonly SpotRankings[], staleKeys: readonly string[]): Promise<void>; saveDirectory(e: readonly DirectoryEntry[], now: string): Promise<void> }
export function nextDays(today: string, n: number): string[];  export function weekendDays(today: string): string[];
export function runSpotRanking(deps: { store: SpotRankStore; counter: SpotCounter; clock: Clock }):
  Promise<{ spots: number; changed: number; keys: string[] }>;

// spot_admin.ts (Task 4, CLI use cases)
export interface SpotInput { name; city; areaCode; lat; lng; radiusM; description; tips; seasonMonths; cover?: SpotCover | null }
export function validateSpotInput(raw: unknown): SpotInput;
export interface SpotAdminStore { getSpot(id): Promise<Spot | null>; putSpot(s: Spot): Promise<void> }
export interface SpotAdminDeps { readonly spots: SpotAdminStore; readonly staff: { isAdmin(uid: string): Promise<boolean> };
  readonly clock: Clock; readonly ids: IdGenerator }
export function addSpot(deps: SpotAdminDeps, actor: string, raw: unknown): Promise<Spot>;
export function editSpot(deps: SpotAdminDeps, actor: string, id: string, raw: unknown): Promise<Spot>;
export function setSpotFlag(deps: SpotAdminDeps, actor: string, id: string,
  flag: 'pin' | 'unpin' | 'hide' | 'unhide' | 'archive'): Promise<Spot>;

// errors.ts: ERROR_CODES adds 'outside_schedule', 'slot_taken', 'day_conflict', 'schedule_limit', 'spot_archived', 'schedule_has_bookings';
//   DomainError(code, field?, details?: Readonly<Record<string, unknown>>)
```

### Callables (`asia-southeast1`, `CALLABLE_OPTIONS`)

| Callable | Input | Output | Errors (`details.code`, `details.field`, extra `details`) |
|---|---|---|---|
| `saveSpotSchedule` | `{scheduleId?, spotId, days, window: {start, end}, serviceIds, assigneeId?}` | `{scheduleId, addedDays}` | `invalid_argument` (field `spotId`/`days`/`window`/`serviceIds`/`assigneeId`), `permission_denied`, `not_accepting_orders`, `not_found`, `spot_archived`, `schedule_limit`, `day_conflict` (`days: [{day, reason}]`), `schedule_has_bookings` (`days: [{day, count}]`) |
| `cancelSpotSchedule` | `{scheduleId}` | `{}` | `not_found`, `permission_denied`, `schedule_has_bookings` |
| `saveSlotOffer` | `{offerId?, scheduleId, name, price, slotMinutes, gapMinutes, photoCount, editedCount, deliveryDays}` | `{offerId}` | `invalid_argument` (field), `contact_leak` (field `name`), `not_found`, `permission_denied`, `not_accepting_orders`, `limit_exceeded` |
| `closeSlotOffer` | `{offerId}` | `{}` | `not_found`, `permission_denied` |
| `createBooking` (exists) | adds `spotScheduleId?`, `slotOfferId?` | unchanged | adds `outside_schedule`, `slot_taken`, `spot_archived`; `day_taken` for a normal booking into a spot day |

Transport codes: `outside_schedule`, `slot_taken`, `day_conflict`, `spot_archived`, `schedule_has_bookings` → `failed-precondition`; `schedule_limit` → `resource-exhausted`. Scheduled: `rankSpots` = `onSchedule({...SCHEDULE_OPTIONS, schedule: '0 3 * * *', timeZone: 'Asia/Ho_Chi_Minh', maxInstances: 1, timeoutSeconds: 300})`. CLI: `npm run spots -- list [--area <code>] | add --name … --city … --area … --lat … --lng … --radius … [--season 10,11,12] [--cover <file.jpg>] [--description …] [--tip …]… --actor <uid> | edit <id> [same flags] --actor <uid> | pin|unpin|hide|unhide|archive <id> --actor <uid> | rank`; `scripts/spots-local.sh` runs it against the emulators.

### App (`app_flutter/lib`)

```dart
// lib/data/spots/spot.dart (pure models + Map mappers; Timestamp conversion stays in the adapter)
@immutable class SpotStats { final int posts14d, events, bookings14d, openSchedules, providersWeek, providersWeekend; }
@immutable class SpotCover { final String url, cardUrl; }
@immutable class Spot { final String id, name, city, areaCode, description; final double lat, lng; final int radiusM;
  final SpotCover? cover; final List<String> tips; final List<int> seasonMonths; final bool pinned, hidden, archived; final SpotStats stats; }
@immutable class SpotEntry { /* one directory/ranking entry */ final String spotId, name, city, areaCode; final String? cardUrl;
  final double lat, lng; final int radiusM; final List<int> seasonMonths; final bool inSeason, pinned, hidden;
  final int hotScore, openSchedules, providersWeek, providersWeekend, upcomingEvents; }
@immutable class SpotWindow { final String start, end; }
@immutable class SpotSchedule { final String id, providerId, spotId; final String? assigneeId; final List<String> days;
  final SpotWindow window; final List<String> serviceIds; final int? priceFrom; final bool open;
  String get holderId => assigneeId ?? providerId; }
@immutable class SlotOffer { final String id, providerId, scheduleId, spotId, name; final int price, slotMinutes, gapMinutes,
  photoCount, editedCount, deliveryDays; final bool open; }
@immutable class SpotInterval { final String start, end; final String? offerId; }
@immutable class SpotDay { final String scheduleId, day; final List<SpotInterval> taken; }
Spot? spotFromMap(String id, Map<String, dynamic>? d); SpotEntry? spotEntryFromMap(Map<String, dynamic> d);
SpotSchedule? spotScheduleFromMap(String id, Map<String, dynamic>? d); SlotOffer? slotOfferFromMap(String id, Map<String, dynamic>? d);
SpotDay? spotDayFromMap(Map<String, dynamic>? d);

// lib/data/spots/spot_rules.dart (pure, mirrors the domain; server is the authority)
String regionOfArea(String? areaId); String regionForLocation({String? areaId, double? lat, double? lng}); // nearest builtInAreas
bool inSeason(List<int> months, int month); int? seasonRunEnd(List<int> months, int month);
List<({String start, String end})> slotsFor(SpotWindow w, int slotMinutes, int gapMinutes);
List<String> freeStartTimes(SpotWindow w, int durationMinutes, List<SpotInterval> taken, {int step = 30});
List<({String start, String end, bool free})> freeSlots(SpotWindow w, SlotOffer o, List<SpotInterval> taken);
List<SpotEntry> orderSpots(List<SpotEntry> all, {required int month, double? lat, double? lng}); // pinned → hot → rest by distance
List<String> expandWeekly(Set<int> weekdays, String from, String to);  // S29.04 "Lặp lại"
enum SpotDayConflictReason { booked, pending, off, spot, full }
Map<String, SpotDayConflictReason> scheduleConflicts(List<String> days, Map<DateTime, AvailabilityDay> mine, {String? scheduleId});

// lib/data/spots/spot_repository.dart
abstract class SpotRepository {
  Future<List<SpotEntry>> hot(String key);                 // spot_rankings/{key}; missing → spot_rankings/all
  Future<List<SpotEntry>> directory();                     // spot_directory/all
  Future<Spot?> spot(String spotId);
  Future<List<SpotSchedule>> openSchedulesAt(String spotId);
  Future<List<SlotOffer>> openOffersAt(String spotId);
  Future<SpotDay?> spotDay(String scheduleId, String day);
  Future<SpotSchedule?> schedule(String scheduleId);
  Future<SlotOffer?> offer(String offerId);
  Future<List<PostSummary>> postsAt(String spotId, {DateTime? before, int limit = 20});
  Future<List<EventSummary>> eventsAt(String spotId, {int limit = 10});  // open|full, startAt ≥ now
  Stream<List<SpotSchedule>> watchMine(String uid);         // providerId == uid, status open
  Stream<List<SlotOffer>> watchMyOffers(String uid);        // providerId == uid, status open
  Future<({String scheduleId, List<String> addedDays})> saveSchedule(SpotScheduleInput input);
  Future<void> cancelSchedule(String scheduleId);
  Future<String> saveOffer(SlotOfferInput input);
  Future<void> closeOffer(String offerId);
}
@immutable class SpotScheduleInput { /* scheduleId?, spotId, days, window, serviceIds, assigneeId?; toCallable() */ }
@immutable class SlotOfferInput { /* offerId?, scheduleId, name, price, slotMinutes, gapMinutes, photoCount, editedCount, deliveryDays */ }
enum SpotErrorCode { invalidArgument, contactLeak, notAcceptingOrders, notFound, permissionDenied, spotArchived, scheduleLimit,
  dayConflict, scheduleHasBookings, limitExceeded, network, unknown }
class SpotError { const SpotError(this.code, {this.field, this.conflicts = const {}, this.bookingCounts = const {}});
  final SpotErrorCode code; final String? field; final Map<String, SpotDayConflictReason> conflicts; final Map<String, int> bookingCounts; }
SpotError spotErrorOf(Object error);
// lib/data/spots/firestore_spot_repository.dart: FirestoreSpotRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
// lib/data/spots/fake_spot_repository.dart (test support lives in test/support/fake_spot_repository.dart)
// lib/data/spots/spot_providers.dart
final spotRepositoryProvider = Provider<SpotRepository>((ref) => FirestoreSpotRepository());
final spotRegionProvider = Provider<String>(...);                                   // from locationControllerProvider
final hotSpotsProvider = FutureProvider.family<List<SpotEntry>, String>(...);       // keep-alive per session
final spotDirectoryProvider = FutureProvider<List<SpotEntry>>(...);                 // keep-alive per session
final spotProvider = FutureProvider.autoDispose.family<Spot?, String>(...);
final spotSchedulesAtProvider = FutureProvider.autoDispose.family<List<SpotSchedule>, String>(...);
final spotOffersAtProvider = FutureProvider.autoDispose.family<List<SlotOffer>, String>(...);
final spotDayProvider = FutureProvider.autoDispose.family<SpotDay?, ({String scheduleId, String day})>(...);
final spotEventsProvider = FutureProvider.autoDispose.family<List<EventSummary>, String>(...);
final mySpotSchedulesProvider = StreamProvider.autoDispose.family<List<SpotSchedule>, String>(...);
final mySlotOffersProvider = StreamProvider.autoDispose.family<List<SlotOffer>, String>(...);
// spot posts: SpotPostsController (AsyncNotifier, pages of 20, loads its first page only when asked)

// booking
// lib/data/booking/booking.dart: Booking adds String? spotId, spotScheduleId, slotOfferId, source (regenerate freezed)
// booking_repository.dart: createBooking adds String? spotScheduleId, String? slotOfferId;
//   BookingErrorCode adds outsideSchedule, slotTaken, spotArchived
// features/booking/booking_flow_state.dart: BookingFlowArgs adds scheduleId, slotOfferId, start;
//   BookingFlowState adds SpotBookingContext? spot  ({schedule, spotName, spotPoint, offer?, takenByDay})
// features/discovery/book_entry.dart: bookingPath/startBooking add scheduleId, slotOfferId, start (query keys scheduleId, offerId, start)

// core widgets (exported from core.dart): SpotCard ({required SpotEntry entry, SpotCardSize size, VoidCallback? onTap}),
//   SeasonTag ({required String label}), SlotGrid ({required slots, String? selected, ValueChanged<String> onPick})
// features/spots: SpotsScreen (S29.01), SpotScreen (S29.02), MySpotSchedulesScreen (S29.03), SpotScheduleEditScreen (S29.04),
//   showSlotOfferSheet (S29.05), showSlotPickSheet (S29.06), spot_format.dart (labels below)
```

Routes: `/spots?area=` → `SpotsScreen`; `/spots/:spotId?date=` → `SpotScreen`; `/me/spot-schedules` → `MySpotSchedulesScreen`; `/me/spot-schedules/new?spotId=` and `/me/spot-schedules/:scheduleId` → `SpotScheduleEditScreen`; booking `/u/:uid/book?scheduleId=&date=` and `/u/:uid/book?scheduleId=&offerId=&date=&start=`. Screen codes (already in `lib/core/screen_codes.dart`, added with the mock): `ScreenCodes.spots` S29.01, `spotDetail` S29.02, `mySpotSchedules` S29.03, `spotScheduleEdit` S29.04, `spotSlotOffer` S29.05, `spotSlotPick` S29.06.

### l10n keys (`lib/l10n/app_vi.arb`, exact text; Decision 23)

- Shared: `spotInSeason` "Đang vào mùa"; `spotInSeasonUntil` "Đang vào mùa · tới cuối tháng {month}"; `spotSeasonRange` "Mùa đẹp: tháng {from}–{to}"; `spotSeasonList` "Mùa đẹp: tháng {months}"; `spotSeasonAllYear` "Đẹp quanh năm" (not in the spec; ledger); `spotArchivedBand` "Điểm này không còn nhận lịch mới".
- S02.01/S02.04: `homeHotSpots` "Điểm chụp đang hot"; `spotProvidersThisWeek` "{n} thợ nhận chụp tuần này"; `exploreSpotsNearby` "Điểm chụp gần bạn"; "Xem tất cả" reuses `exploreSeeAll`.
- S29.01: `spotsTitle` "Điểm chụp"; `spotsFilterArea` "Khu vực"; `spotsFilterAllAreas` "Mọi khu vực"; `spotsFilterInSeason` "Đang vào mùa"; `spotsFilterWeekend` "Cuối tuần này có thợ"; `spotsCardStats` "{n} thợ · {m} sự kiện sắp tới"; `spotsEmpty` "Chưa có điểm chụp nào ở khu vực này"; `spotsLoadError` "Không tải được điểm chụp.".
- S29.02: `spotShare` "Chia sẻ"; `spotLinkCopied` "Đã sao chép liên kết điểm chụp"; `spotTipsTitle` "Mẹo chụp"; `spotDirections` "Chỉ đường"; `spotProvidersTitle` "Thợ nhận chụp ở đây"; `spotDayToday` "Hôm nay"; `spotDayPick` "Chọn ngày"; `spotProviderAvailable` "Có mặt {day} · {start}–{end}"; `spotProfile` "Hồ sơ"; `spotBook` "Đặt"; `spotNoProviderDay` "Chưa có thợ nhận chụp ngày này · Xem ngày khác"; `spotOffersTitle` "Gói chụp tại điểm"; `spotOfferLine` "{name} · {price} · còn {n} suất {day}"; `spotOfferFull` "{name} · {price} · hết suất {day}"; `spotPickSlot` "Chọn suất"; `spotEventsTitle` "Sự kiện ở đây"; `spotPhotosTitle` "Ảnh chụp ở đây"; `spotProviderHint` "Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc."; `spotNotFound` "Không tìm thấy điểm chụp.".
- S29.06: `slotPickTitle` "Chọn suất"; `slotTaken` "Đã kín"; `slotContinue` "Tiếp tục · {price}"; `slotTakenError` "Suất này vừa có người đặt. Chọn suất khác.".
- S04 from a spot: `bookAtSpot` "Tại {spot}"; `bookSpotPlaceLocked` "Địa điểm là điểm chụp, không đổi được."; `bookSpotWindow` "Khung giờ tại điểm {start}–{end}"; `bookOutsideSchedule` "Lịch tại điểm vừa thay đổi. Chọn lại ngày giờ."; `bookSlotTaken` "Giờ này vừa có người đặt. Chọn giờ khác."; `bookSpotArchived` "Điểm này không còn nhận lịch mới.".
- S29.03: `spotSchedulesTitle` "Lịch tại điểm của tôi"; `spotSchedulesAdd` "Thêm lịch tại điểm"; `spotSchedulesEmptyTitle` "Chưa có lịch tại điểm"; `spotSchedulesEmptyBody` "Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt."; `spotScheduleDays` "{n} ngày · {start}–{end}"; `spotScheduleDayCount` "{day} · {n} booking"; `spotScheduleOffers` "{n} gói chia suất"; `spotScheduleAddOffer` "Thêm gói chia suất"; `spotScheduleCancel` "Huỷ lịch"; `spotScheduleCancelTitle` "Huỷ lịch tại {spot}?"; `spotScheduleCancelBody` "Khách sẽ không đặt được các ngày còn lại của lịch này."; `spotScheduleCancelConfirm` "Huỷ lịch"; `spotScheduleHasBookings` "Còn {n} booking ngày {day}. Liên hệ khách hoặc huỷ từng booking (khách được hoàn 100%)."; `spotScheduleCancelled` "Đã huỷ lịch tại điểm".
- S29.04: `spotScheduleNewTitle` "Thêm lịch tại điểm"; `spotScheduleEditTitle` "Sửa lịch tại điểm"; `spotScheduleSpot` "Điểm chụp"; `spotScheduleSearch` "Tìm theo tên điểm"; `spotScheduleRepeat` "Lặp lại"; `spotSchedulePickDays` "Chọn ngày"; `spotScheduleWeekdays` "Các thứ"; `spotScheduleFrom` "Từ ngày"; `spotScheduleTo` "Tới ngày"; `spotScheduleWindow` "Khung giờ"; `spotSchedulePackages` "Gói đặt được"; `spotScheduleAllPackages` "Mọi gói đang bật"; `spotScheduleMember` "Thợ chụp"; `spotSchedulePreview` "{n} ngày · {start}–{end}"; `spotScheduleConflictBooked` "Đã có booking"; `spotScheduleConflictOff` "Ngày nghỉ"; `spotScheduleConflictSpot` "Đã có lịch tại điểm khác"; `spotScheduleConflictFull` "Studio hết chỗ"; `spotScheduleOffSeason` "Điểm này đẹp nhất tháng {months}"; `spotScheduleOpen` "Mở lịch"; `spotScheduleSave` "Lưu lịch"; `spotScheduleSaved` "Đã mở lịch tại điểm"; `spotScheduleLimit` "Bạn đã có 8 lịch tại điểm đang mở. Huỷ bớt một lịch để mở lịch mới."; `spotScheduleNoDays` "Chọn ít nhất một ngày"; `spotScheduleTooMany` "Tối đa 40 ngày mỗi lịch, trong 60 ngày tới"; `spotScheduleWindowInvalid` "Khung giờ từ 05:00 tới 21:00, dài 1–12 giờ"; `spotScheduleNotAccepting` "Bạn cần được duyệt nhận đơn trước khi mở lịch tại điểm."; `spotScheduleError` "Không lưu được. Thử lại.".
- S29.05: `slotOfferTitle` "Gói chia suất"; `slotOfferName` "Tên gói"; `slotOfferPrice` "Giá mỗi suất (₫)"; `slotOfferMinutes` "Thời lượng suất"; `slotOfferGap` "Nghỉ giữa suất"; `slotOfferPhotos` "Số ảnh"; `slotOfferEdited` "Số ảnh chỉnh"; `slotOfferDelivery` "Số ngày giao"; `slotOfferMinutesValue` "{n} phút"; `slotOfferPreview` "{n} suất/ngày: {times}"; `slotOfferSave` "Lưu"; `slotOfferClose` "Đóng gói"; `slotOfferCloseTitle` "Đóng gói {name}?"; `slotOfferCloseBody` "Khách đã đặt vẫn giữ suất của mình."; `slotOfferLimit` "Mỗi lịch tối đa 2 gói chia suất"; `slotOfferErrorName` "Tên 3–60 ký tự"; `slotOfferErrorPrice` "Giá từ 10.000₫ tới 100.000.000₫"; `slotOfferErrorFit` "Khung giờ không đủ cho một suất"; `slotOfferErrorContact` "Bỏ số điện thoại, Zalo hoặc link ra khỏi tên gói"; `slotOfferSaved` "Đã lưu gói chia suất".
- S06.01: `workSpotSchedules` "Lịch tại điểm".
- S12.01: `eventSpotField` "Điểm chụp"; `eventSpotNone` "Không thuộc điểm chụp nào"; `eventSpotRequired` "Chọn một điểm chụp hoặc “Không thuộc điểm chụp nào”"; `eventSpotFar` "Địa điểm sự kiện nằm ngoài điểm chụp này".
- S10.01: `postSpotChip` "Gắn với {spot}"; `postSpotRemove` "Bỏ gắn {spot}".

## Review Focus

1. **Two customers get the same time at a spot.** Both read an empty `spot_days` and both write. Pinned: Task 2 `two concurrent spot drafts for clashing times: exactly one succeeds, the other is slot_taken` (memory store serializes, transaction reads the availability lock and the spot day), Task 3 `FirestoreBookingStore reads availability/{holder}/days/{day} and spot_days in the spot transaction` (fake Firestore records reads) and the integration test (written) `parallel createBooking on one slot → one slot_taken`.
2. **A normal booking, event or assignment lands on a spot day.** Paths that only know `off/booked/pending` treat `spot` as free (the event adapter even maps it to `off`). Pinned: Task 2 `a package booking without spotScheduleId on a spot day is day_taken`, `publishEvent on a host's spot day is day_taken`, `updateEvent moving to a spot day is day_taken`, `reschedule proposal into a spot day is day_taken`, `assignBooking to a member on a spot day is member_busy`; Task 3 `event adapter maps state spot to spot, not off`.
3. **Intervals that never go away.** A cancelled, declined, expired or abandoned spot booking keeps its interval and the time looks taken forever, or the wrong interval is removed. Pinned: Task 2 `decline, expire and cancel each remove exactly the booking's interval`, `the draft sweep removes the expired draft's interval and leaves the others`, `a customer's second draft on the same schedule replaces the first and its interval`, `accept writes nothing to availability for a spot booking`.
4. **The public projection leaks who booked.** Pinned: Task 3 `spotDayToFirestore writes only scheduleId, spotId, providerId, day, taken, updatedAt`, rules test `a signed-in stranger reads spot_days; no client writes it`; Task 2 `SpotInterval carries no booking or customer field` (type-level fixture compared with `Object.keys`).
5. **Days dropped under existing bookings.** Cancelling a schedule or removing a day deletes the `spot` record while a paid booking stays, so the day re-opens for normal bookings and double-books the provider. Pinned: Task 1 `cancelSpotSchedule with a taken interval is schedule_has_bookings and writes nothing`, `removing a day with a draft interval is schedule_has_bookings`, `narrowing the window under a taken interval is schedule_has_bookings`; Task 8 `S29.03 shows "Còn 2 booking ngày CN 18/10…" from details`.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore upper bound nam5 $0.06/100K reads, $0.18/100K writes (asia-southeast1 **chưa xác nhận**); Functions Tier 2 ($0.0000336/vCPU-s; at (b) inside the free tier, at (c) charged because the app already uses it up, §12); Cloud Scheduler $0.10/job/month beyond 3; Storage $0.02/GB-month, egress $0.12/GB (**giả định, chưa xác nhận**). Assumptions: (b) 1,000 MAU, 100 providers, 30 spots; (c) 10,000 MAU, 1,000 providers, 200 spots; 15 Home sessions/MAU/month; the directory is read in 30% of sessions; 5 spot-page opens/MAU/month (spec §10); 20% of providers save 3 schedules/offers a month; 10% of bookings are at a spot.

- **Per user action.**
  - Home: one `get` of `spot_rankings/{region}` (+1 for `all` when the region has no document), kept for the session → ≈ 1.2 reads/session. S02.03, S02.04 row, S29.01, S29.04 picker, S10.01/S12.01 suggestions: one `get` of `spot_directory/all` per session (Decision 3); S29.01 pages client-side, no query, no new index.
  - S29.02 (all `get`, no listener: nothing needs real time, a stale slot is caught by `slot_taken`): spot 1 + open schedules (≤ 20, typ. 8) + open offers (typ. 3) + `spot_days` of the chosen date (typ. 4) + provider summaries (typ. 8, cached pool of #132) + events (≤ 10, typ. 3) + posts (20 per page, loaded when the section is reached; typ. 12) ≈ **40 reads** (max ≈ 75). Date chip change: ≈ 4 reads. S29.06: 1 per chip.
  - Booking at a spot: +3–4 reads (schedule, spot, spot day, offer) and +1 write (`spot_days`) inside the existing transaction; payment/cancel +1 read +1 write.
  - S29.03: listeners on own open schedules (≤ 8) and offers (≤ 16); per-day counts from the bookings the work screen already loads (Decision 21). S29.04: directory (cached) + the existing own-availability listener. `saveSpotSchedule`: ≈ 30 reads (lock, spot, open schedules ≤ 8, packages ≤ 10, availability per added day typ. 8), ≈ 10 writes. `saveSlotOffer`: ≈ 5 reads, 2 writes.
- **New callables:** `saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer`: ≈ 60 calls/month at (b), 600 at (c) (0.2 vCPU-s each). No new trigger.
- **New scheduled job:** `rankSpots`, daily 03:00 VN, 30 runs/month, the repo's **10th** job → **+$0.10/month**. Reads per run ≈ 7 × spots (6 `count()` aggregations, each ≥ 1 read per 1,000 index entries, + the spot) + writes only for changed spots + ≤ 10 ranking docs + 1 directory: (b) ≈ 210 reads/run → 6.3K/month, ≤ 1.2K writes; (c) ≈ 1,400 reads/run → 42K/month, ≤ 6.6K writes; ≈ 10 vCPU-s per run at (c). Daily, so no frequency justification needed.
- **Storage:** `spots/{id}/cover.jpg` ≈ 300 KB + `card.jpg` ≈ 50 KB (Decision 20): 200 spots ≈ 70 MB stored ≈ $0.001. Egress (device cache, 7-day max-age): cards ≈ 20 × 50 KB per MAU/month + hero ≈ 3 distinct × 300 KB → ≈ 1.9 MB/MAU → (b) 1.9 GB ≈ $0.23, (c) 19 GB ≈ $2.28.
- **Photo masonry (S29.02):** existing post images (no thumbnails yet, cost spec §11: ≈ 0.29 MB/view after #147). The page shows the first image of each post, 9 tiles before "Xem thêm", loaded lazily (≈ 60% of opens reach it) → ≈ 27 views/MAU/month. If those views **replace** feed views, they are inside §11's 600 views/MAU budget (+$0); if they are **added**, ≈ 7.7 MB/MAU → (b) +$0.93, (c) +$9.3.
- **Paid APIs:** none (Decision 22: drawn static map; "Chỉ đường" opens the phone's maps app with a Google Maps URL, no API key, no Maps SKU).
- **Monthly totals.** (b) 1,000 MAU: reads ≈ 18K (Home) + 4.5K (directory) + 200K (S29.02) + 5K (bookings, providers) + 6.3K (job) ≈ 234K → $0.14; writes ≈ 3K → $0.01; Functions $0; Scheduler $0.10; Storage egress $0.23 → **≈ +$0.5/month** (worst case with added photo views ≈ +$1.4). (c) 10,000 MAU: reads ≈ 180K + 45K + 2M + 50K + 42K ≈ 2.3M → $1.39; writes ≈ 25K → $0.05; Functions ≈ $0.02; Scheduler $0.10; Storage egress $2.28 → **≈ +$3.9/month** (worst case ≈ +$13.2). The spec's §10 estimate (+$0.3 / +$2.1) left out Storage egress.
- **Above $5 at (c) only in the worst case.** Mitigations already in the plan: one-document rankings and directory, card-size covers, 7-day cache headers, `get` instead of listeners, first image per post with 9 lazy tiles. Further mitigation (separate unit, cost spec §11): ~35 KB thumbnails at upload cut the masonry worst case to ≈ +$1.1 and covers further (Needs the owner 4).

## Tasks

### Task 1: Domain — spots, slot offers, spot schedules (`saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer`)

**Files:**
- Create: `packages/domain/src/spot.ts`, `spot_slots.ts`, `spot_schedule.ts`, `spot_booking.ts` (pure interval helpers only; the booking use case is Task 2), `spot_schedule_ports.ts`, `spot_schedule_use_cases.ts`, `memory_spot_store.ts`; tests `packages/domain/test/spot.test.ts`, `spot_slots.test.ts`, `spot_schedule.test.ts`, `spot_intervals.test.ts`, `spot_schedule_use_cases.test.ts`.
- Modify: `packages/domain/src/errors.ts` (six codes; `DomainError(code, field?, details?)`), `booking_ports.ts` (`AvailabilityDayRecord.state` adds `'spot'` next to #136's `'full'`, fields `scheduleId?`, `spotId?`), `index.ts`; `docs/superpowers/specs/data-model/domain-model.md` (§2 entities `Spot`, `SpotSchedule`, `SlotOffer`, `SpotDay`; §4 enums `SpotStatus`, `SpotScheduleStatus`, `SlotOfferStatus`, the `spot` availability state and the six error codes; §6 invariants "một nhà cung cấp một điểm một ngày", "khoảng cách ≥ 15 phút giữa hai booking cùng ngày tại điểm", "tối đa 8 lịch tại điểm đang mở"), `relational-schema.md` (`spots`, `spot_schedules`, `spot_schedule_days(schedule_id, day)`, `spot_slot_offers`, `spot_day_intervals(schedule_id, day, start_time, end_time, offer_id, booking_id)` with a note that the public projection omits `booking_id`; Vietnamese prose like the rest of the file).

**Interfaces:**
- Consumes: `ServiceRecord`, `ProviderOrderGate` (+ #136 `orderProfile`), #136 `StudioRoster`, `Clock`, `IdGenerator`, `findContactLeak` + `DomainError(code, field?)` (#139), `encodeGeohash`, `formatVnDate`, `isDateString`, `isTimeString`, `graphemeCount`, `isId`.
- Produces: Contract → Domain `spot.ts`, `spot_slots.ts`, `spot_schedule.ts`, `spot_booking.ts` (helpers), `spot_schedule_ports.ts`, `spot_schedule_use_cases.ts`, `memory_spot_store.ts`, error codes, `DomainError` details.

- [ ] **Step 1: Contract check.** On `origin/develop` confirm #139's `DomainError(code, field?)` and `findContactLeak`, #136's `orderProfile` and `StudioRoster.relationOf`, and that no `spot` name exists; ledger the exact names. Stop if one is missing (Decision 1).
- [ ] **Step 2: Failing tests.**
  - `spot.test.ts`: `regionOfArea maps hcm-q1 → hcm, hn-ba-dinh → hn, dn-hai-chau → dn, da-lat → da-lat, null → all`; `inSeason([10,11,12], 11) is true, ([], 5) is false`; `seasonOk([], 5) is true`; `seasonRunEnd([11,12,1], 12) is 1 (wraps the year)`, `([10,11], 11) is 11`, `([3,9], 3) is 3`; `distanceMeters Hồ Gươm → Hồ Tây ≈ 3,000 m (±5%)`; `spotCovers is true inside the radius, false 1 m outside, true with slack`.
  - `spot_slots.test.ts`: `slotsFor 06:00–11:00, 30/10 → 06:00, 06:40, 07:20, 08:00, 08:40, 09:20, 10:00 (7 slots)`; `gap 0: 06:00–08:00, 30 → 4 slots ending 08:00`; `window shorter than a slot → []`; `a window that does not divide evenly drops the tail`; `validateSlotOfferInput: price 9_999 / 100_000_001 / 10_000.5 → field price`; `slotMinutes 14 and 91 → field slotMinutes`; `gapMinutes 31 → field gapMinutes`; `editedCount above photoCount → field editedCount`; `deliveryDays 0 and 31 → field deliveryDays`; `name "Gọi 0903 123 456" → contact_leak field name`; `name of 2 or 61 graphemes → field name`.
  - `spot_schedule.test.ts`: `validateScheduleInput sorts and dedupes days`; `a day before today or after today + 60 → field days`; `41 days → field days`; `no day → field days`; `window 04:45–09:00 or 17:00–21:15 → field window`; `window of 45 minutes or 12 h 15 → field window`; `window off the 15-minute grid (06:10) → field window`; `assigneeId when present must be an id`; `dayConflicts: booked/pending/off/full/spot of another schedule are conflicts with their reason; no record and spot of the same schedule are free`; `priceFromOf: [] → min of all active; listed ids → min of those; an unknown id → invalid_argument serviceIds; no active package → invalid_argument serviceIds`; `scheduleEditBlocks: a removed day with 2 intervals → {day, count: 2}; an interval outside the new window → blocked; inside → []`.
  - `spot_intervals.test.ts`: `requiredGap is 0 for two slots of the same offer and 15 otherwise`; `clashes: 07:00–08:00 vs 08:10–09:00 clash (gap 10 < 15); vs 08:15–09:00 do not`; `two same-offer slots back to back do not clash`; `freeStartTimes 06:00–11:00, 60 min, step 30, taken 07:00–08:00 → exactly ["08:30", "09:00", "09:30", "10:00"]` (06:00 ends 07:00 with a 0-minute gap, 08:00 starts with a 0-minute gap, 10:30 ends after the window); `freeSlots marks a slot overlapping a package booking taken and a same-offer neighbour free`; `withInterval appends and keeps taken sorted by start`; `withoutInterval removes only the exact {start, end}; an unknown interval leaves the day unchanged`; `SpotInterval carries no booking or customer field` (build one with every field and compare `Object.keys(iv).sort()` with `['end', 'offerId', 'start']`).
  - `spot_schedule_use_cases.test.ts` (memory store, fake clock 2026-10-08 10:00 VN, fake ids):
    - `saveSpotSchedule opens 4 weekend days: schedule open, priceFrom set, availability of each day is {state: spot, scheduleId, spotId}`.
    - `a provider who does not accept orders is not_accepting_orders`; `a customer (no orderProfile) is permission_denied`.
    - `an unknown spot is not_found field spotId`; `an archived spot is spot_archived`.
    - `a day already booked, pending, off or full is day_conflict with details.days [{day, reason}] and nothing is written`.
    - `a day of the provider's other open schedule is day_conflict reason spot`.
    - `the 9th open schedule is schedule_limit; a schedule whose days are all past does not count`.
    - `two concurrent saves at 7 open schedules: exactly one succeeds` (serialized on the lock).
    - `editing adds and removes days: added days get spot records, removed days lose them, past days are kept unchanged`.
    - `removing a day with a draft interval is schedule_has_bookings with details.days [{day, count: 1}]`.
    - `narrowing the window under a taken interval is schedule_has_bookings`.
    - `changing spotId or assigneeId of an existing schedule is invalid_argument`.
    - `studio without assigneeId is invalid_argument assigneeId; individual with assigneeId is invalid_argument assigneeId`.
    - `studio with a collaborator or a stranger as assignee is invalid_argument assigneeId; an assignee who does not accept orders is not_accepting_orders`.
    - `studio schedule writes the spot records on the member's availability, not the studio's`.
    - `cancelSpotSchedule with a taken interval is schedule_has_bookings and writes nothing`.
    - `cancelSpotSchedule without bookings: status cancelled, every future spot record deleted, its open offers closed`.
    - `another provider's schedule is not_found for save, cancel and offers`.
    - `saveSlotOffer creates an open offer bound to the schedule and spot`; `the 3rd open offer of a schedule is limit_exceeded`; `an offer that fits no slot in the window is invalid_argument field slotMinutes`; `an offer on a cancelled schedule is not_found`.
    - `closeSlotOffer closes it; closing twice is fine`.
- [ ] **Step 3:** `cd packages/domain && npm test` → the new tests fail.
- [ ] **Step 4: Implement.** `MemorySpotStore` follows `memory_album_store.ts` (refuse reads after writes inside a transaction; serialize transactions with a promise chain). Extend `DomainError` with `details` (`constructor(readonly code: ErrorCode, readonly field?: string, readonly details?: Readonly<Record<string, unknown>>)`; keep #139's call sites unchanged). Hard part, `saveSpotSchedule` (reads before writes, lock first):
  ```ts
  export async function saveSpotSchedule(deps: SpotScheduleDeps, callerId: string, raw: unknown) {
    const now = deps.clock.now();
    const today = formatVnDate(now);
    const input = validateScheduleInput(raw, today);
    const profile = await deps.providers.orderProfile(callerId);                 // #136
    if (!profile) throw new DomainError('permission_denied');
    if (!profile.acceptsOrders) throw new DomainError('not_accepting_orders');
    const studio = profile.providerType === 'studio';
    if (studio !== (input.assigneeId !== undefined)) throw new DomainError('invalid_argument', 'assigneeId');
    if (studio) {
      if ((await deps.roster.relationOf(callerId, input.assigneeId!)) !== 'member') throw new DomainError('invalid_argument', 'assigneeId');
      if (!(await deps.providers.acceptsOrders(input.assigneeId!))) throw new DomainError('not_accepting_orders', 'assigneeId');
    }
    return deps.schedules.runTransaction(async (tx) => {
      await tx.lockProvider(callerId);                                            // Decision 11
      const spot = await tx.getSpot(input.spotId);
      if (!spot) throw new DomainError('not_found', 'spotId');
      if (spot.status !== 'active') throw new DomainError('spot_archived');
      const existing = input.scheduleId === undefined ? null : await tx.getSchedule(input.scheduleId);
      if (input.scheduleId !== undefined && (!existing || existing.providerId !== callerId || existing.status !== 'open')) {
        throw new DomainError('not_found');
      }
      if (existing && (existing.spotId !== input.spotId || existing.assigneeId !== (input.assigneeId ?? null))) {
        throw new DomainError('invalid_argument', 'spotId');                      // Decision 7: immutable
      }
      const open = await tx.openSchedulesOf(callerId, today);
      if (!existing && open.length >= MAX_OPEN_SCHEDULES) throw new DomainError('schedule_limit');
      const priceFrom = priceFromOf(await tx.activeServices(callerId), input.serviceIds);
      const holder = input.assigneeId ?? callerId;
      const kept = existing ? existing.days.filter((d) => d >= today) : [];
      const added = input.days.filter((d) => !kept.includes(d));
      const removed = kept.filter((d) => !input.days.includes(d));
      const records = new Map<string, AvailabilityDayRecord | null>();
      for (const d of added) records.set(d, await tx.availability(holder, d));
      const spotDays = new Map<string, SpotDay | null>();
      for (const d of kept) spotDays.set(d, await tx.getSpotDay(existing!.id, d));
      const conflicts = dayConflicts(added, records, existing?.id ?? null);
      if (conflicts.length > 0) throw new DomainError('day_conflict', 'days', { days: conflicts });
      const blocked = scheduleEditBlocks(removed, input.window, spotDays);
      if (blocked.length > 0) throw new DomainError('schedule_has_bookings', 'days', { days: blocked });
      // writes
      const iso = now.toISOString();
      const id = existing?.id ?? deps.ids.newId();
      const past = existing ? existing.days.filter((d) => d < today) : [];
      tx.putSchedule({ id, providerId: callerId, assigneeId: input.assigneeId ?? null, spotId: spot.id,
        days: [...past, ...input.days].sort(), window: input.window, serviceIds: input.serviceIds, priceFrom,
        status: 'open', createdAt: existing?.createdAt ?? iso, updatedAt: iso });
      for (const d of added) tx.setSpotAvailability(holder, d, { scheduleId: id, spotId: spot.id }, iso);
      for (const d of removed) tx.deleteAvailability(holder, d);
      tx.touchLock(callerId, iso);
      return { scheduleId: id, addedDays: added };
    });
  }
  ```
  `cancelSpotSchedule`: same lock; read schedule, every future day's spot day, the offers; any taken → `schedule_has_bookings` (counts); else write `cancelled`, delete future spot records (holder's), close open offers. `saveSlotOffer`: gate, lock, schedule open and owned, offers of the schedule (≤ 2 open excluding this one, else `limit_exceeded`), `slotsFor(schedule.window, …)` non-empty (else `invalid_argument` `slotMinutes`), write. Hard part, the slot grid:
  ```ts
  export function slotsFor(w: SpotWindow, slotMinutes: number, gapMinutes: number) {
    const out: { start: string; end: string }[] = [];
    const last = minutesOf(w.end);
    for (let s = minutesOf(w.start); s + slotMinutes <= last; s += slotMinutes + gapMinutes) {
      out.push({ start: timeOf(s), end: timeOf(s + slotMinutes) });
    }
    return out;
  }
  export const requiredGap = (a: SpotInterval, b: SpotInterval): number =>
    a.offerId !== undefined && a.offerId === b.offerId ? 0 : SPOT_BOOKING_GAP_MINUTES;
  export function clashes(c: SpotInterval, taken: readonly SpotInterval[]): boolean {
    const cs = minutesOf(c.start), ce = minutesOf(c.end);
    return taken.some((t) => {
      const g = requiredGap(c, t);
      return cs < minutesOf(t.end) + g && minutesOf(t.start) < ce + g;   // not (c ends g before t, or t ends g before c)
    });
  }
  ```
  Export everything from `index.ts`; update the two data-model files.
- [ ] **Step 5:** `cd packages/domain && npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): photo spots, spot schedules and slot offers [#194]`.

### Task 2: Domain — booking on a spot day, and every availability path

**Files:**
- Modify: `packages/domain/src/booking.ts` (`spotId?`, `spotScheduleId?`, `slotOfferId?`, `source` adds `'spot' | 'spot_slot'`), `booking_ports.ts` (`BookingTx` spot reads/writes), `booking_requests.ts` (`spotScheduleId?`, `slotOfferId?`), `create_booking.ts` (spot branch; `BookingDraftInput.spot?`), `spot_booking.ts` (`assertSpotBooking`, `spotBusyAt`), `create_payment.ts`, `commit_transition.ts`, `booking_sweeps.ts`, `reschedule.ts`, `event_use_cases.ts` (publish/update refuse `spot`), `event_ports.ts` (`AvailabilityRecord.state` adds `'spot'`), `memory_booking_store.ts` (spots, schedules, offers, spot days), `memory_event_store.ts`; #136's `studio_assignment.ts` (`assignBooking`, `requestAssigneeChange`, `returnAssignment` → `not_eligible` for spot bookings; `assignmentOptions` reads `spot` as `busy` with the window) and its leave/remove use cases (`member_busy`, Decision 7) with their port (`openSpotSchedulesOfAssignee(uid, today)`) and memory store; if #140 has merged, its candidate filter (Decision 17); `test/support/booking_world.ts` (`withSpot(world, spot)`, `withSchedule(world, schedule)`, `withOffer(world, offer)`); tests: create `packages/domain/test/spot_booking.test.ts`, `spot_booking_paths.test.ts`; extend `create_booking.test.ts`, `event_use_cases.test.ts`, #136's studio tests.

**Interfaces:**
- Consumes: Task 1; #152 `buildBookingDraft`; #144 `assertOrderAllowed`; #190 `priceAddonLines`, `requirePickup`; #136 studio builder fields.
- Produces: `assertSpotBooking`, `spotBusyAt`; the spot branch of `createBookingDraft`; `Booking` spot fields; `BookingTx.getSpot/getSpotSchedule/getSlotOffer/getSpotDay/setSpotDay`; `releaseSpotInterval(tx, booking, now)` (internal helper used by every release path).

- [ ] **Step 1: Contract check.** Read the merged `createBookingDraft` (order: validate → service → `assertOrderAllowed` → `price_changed` → add-ons/pickup/`expectedTotal` → phone → transaction with #136's studio branch) and `buildBookingDraft`. List every call of `getAvailabilityDay`, `setAvailabilityDay`, `deleteAvailabilityDay`, `availability(`, `setAvailabilityBooked`, `deleteAvailability` in `packages/domain/src` (`grep -rn "vailability" packages/domain/src`), including any #139/#140/#151 addition; each one gets an explicit `spot` rule in this task. Ledger the list.
- [ ] **Step 2: Failing tests.**
  - `spot_booking.test.ts` (booking world, An's schedule at Hồ Tây on Sat 2026-10-17 06:00–11:00 with `seed-service-portrait` 120 min, offer "Bình minh Hồ Tây 30 phút" 490.000₫ 30/10):
    - `a package booking 06:00–08:00 creates a draft with spotId, spotScheduleId, source spot, place = spot name and point, and adds 06:00–08:00 to spot_days`.
    - `the place sent by the client is ignored` (request place "Nhà tôi" → stored "Hồ Tây").
    - `a second customer at 08:15–10:15 succeeds; at 08:10 is slot_taken`.
    - `a time outside the window (10:00 for 120 min) is outside_schedule`; `a day not in the schedule is outside_schedule`; `a package not in serviceIds is outside_schedule`; `a cancelled schedule is outside_schedule`.
    - `an archived spot is spot_archived`.
    - `a slot booking at 06:40 builds the synthetic service (name, 490.000, 30 min), serviceId = offerId, source spot_slot, interval carries offerId`.
    - `two slots of the same offer back to back both succeed; a package booking right after a slot needs 15 minutes`.
    - `a slot start off the grid (06:30) is outside_schedule`; `a closed offer is outside_schedule`; `expectedPrice ≠ offer price is price_changed`.
    - `a slot booking with addons or pickup is invalid_argument` (T6); `a package booking at a spot keeps add-ons and pickup` (#190).
    - `slotOfferId without spotScheduleId is invalid_argument`.
    - `two concurrent spot drafts for clashing times: exactly one succeeds, the other is slot_taken`.
    - `a customer's second draft on the same schedule replaces the first and its interval`.
    - `a provider who stopped accepting orders is refused before any spot read` (#144 gate order unchanged).
    - `a studio spot booking is pre-assigned to the schedule's member (assigneeId, assigneeKind member, assignedAt) and is not added to studio_day_load`.
    - `spotBusyAt is true inside the window of today's spot day and false outside it or on another day`.
  - `spot_booking_paths.test.ts`:
    - `a package booking without spotScheduleId on a spot day is day_taken`.
    - `createPayment on a spot draft succeeds while its interval exists; after the interval is gone it is day_taken`.
    - `accept writes nothing to availability for a spot booking` (record stays `spot`).
    - `decline, expire and cancel each remove exactly the booking's interval` (three cases, other intervals kept).
    - `the draft sweep removes the expired draft's interval and leaves the others`.
    - `a reschedule proposal on a spot booking is not_eligible`; `a reschedule proposal of a normal booking into a spot day is day_taken`.
    - `publishEvent on a host's spot day is day_taken`; `updateEvent moving to a spot day is day_taken`.
    - studio (#136): `assignBooking to a member on a spot day is member_busy`; `assignmentOptions shows that member busy 06:00–11:00`; `assignBooking, requestAssigneeChange and returnAssignment on a spot booking are not_eligible`; `leaveStudio and removeMember are member_busy while the member holds an open schedule with a future day; allowed after it is cancelled`.
    - if #140 merged: `an online photographer inside today's spot window is not an instant candidate`.
- [ ] **Step 3:** `npm test` → the new tests fail.
- [ ] **Step 4: Implement.** Request parsing: `spotScheduleId`/`slotOfferId` optional ids; `slotOfferId` alone → `invalid_argument`. Service resolution before the gate: with `slotOfferId`, read the offer (`deps.store` non-transactional get, re-read in the transaction) and build the synthetic `ServiceRecord` (Decision 8); `addons` non-empty or `pickup` present → `invalid_argument`. Hard part, the transaction (merged into the existing one; reads before writes):
  ```ts
  return deps.store.runTransaction(async (tx) => {
    const ctx = input.spotScheduleId === undefined ? null : await readSpotContext(tx, input);  // schedule, spot, offer, spotDay
    const holder = ctx ? dayHolderOf(ctx.schedule) : input.photographerId;
    const day = await tx.getAvailabilityDay(holder, input.day);
    const draft = await tx.getCustomerDraftForDay(input.customerId, input.photographerId, input.day);
    const draftDay = draft?.spotScheduleId !== undefined && draft.spotScheduleId !== input.spotScheduleId
      ? await tx.getSpotDay(draft.spotScheduleId, draft.day) : null;                        // another schedule's interval to release
    if (ctx) {
      if (day?.state !== 'spot' || day.scheduleId !== ctx.schedule.id) throw new DomainError('outside_schedule');
      const own = draft?.spotScheduleId === ctx.schedule.id ? draft : null;
      const taken = (ctx.spotDay?.taken ?? []).filter((t) => !(own && t.start === own.start && t.end === own.end));
      assertSpotBooking({ spot: ctx.spot, schedule: ctx.schedule, offer: ctx.offer, serviceId: service.id,
        day: input.day, start: input.start, end, taken });
    } else if (day) {
      if (day.state === 'spot' || day.state === 'off' || day.state === 'booked') throw new DomainError('day_taken');
      if (day.state === 'pending' && !(draft && day.bookingId === draft.id)) throw new DomainError('day_taken');
    }
    // ...#136's studio branch runs only when ctx === null (Decision 7)
    // writes (nowIso = now.toISOString(); draftInput = the BookingDraftInput the merged code already builds)
    if (draft) {
      await tx.deleteBooking(draft.id); await tx.deleteContactSnapshot(draft.id);
      if (draftDay) await tx.setSpotDay(withoutInterval(draftDay, draft, nowIso));   // other schedule; same schedule below
      // a normal pending draft releases its day exactly as today
    }
    const booking = buildBookingDraft({ ...draftInput,
      place: ctx ? { name: ctx.spot.name, point: ctx.spot.point } : input.place,           // Decision 9
      spot: ctx ? { spotId: ctx.spot.id, scheduleId: ctx.schedule.id, source: ctx.offer ? 'spot_slot' : 'spot',
                    ...(ctx.offer ? { slotOfferId: ctx.offer.id } : {}) } : undefined });
    await tx.setBooking(booking);
    if (ctx) {
      const base = { scheduleId: ctx.schedule.id, spotId: ctx.spot.id, providerId: input.photographerId, day: input.day };
      const latest = draft?.spotScheduleId === ctx.schedule.id && ctx.spotDay ? withoutInterval(ctx.spotDay, draft, nowIso) : ctx.spotDay;   // one write per spot day
      await tx.setSpotDay(withInterval(latest, base, { start: input.start, end, ...(ctx.offer ? { offerId: ctx.offer.id } : {}) }, nowIso));
    } else {
      await tx.setAvailabilityDay(input.photographerId, input.day, { state: 'pending', bookingId: booking.id });
    }
    // contact snapshot as today
    return booking;
  });
  ```
  `releaseSpotInterval(tx, b, now)`: when `b.spotScheduleId` is set, read `getSpotDay` (callers read it before their first write) and write `withoutInterval`; used by `commitTransition` (decline/expire/cancel; accept skips the `booked` write for spot bookings), `runBookingSweeps`, and draft replacement. `createPayment`: for spot drafts check `getSpotDay(...).taken` contains `{start, end}` instead of the `pending` day. `reschedule`: spot booking → `not_eligible` before any write; target day `spot` already gives `day_taken`. Events: `av.state === 'spot'` → `day_taken` in publish and update. Studio and #140 extensions as listed in Files. Update `domain-model.md` §2.4 (booking fields) and `relational-schema.md` (`bookings.spot_id`, `spot_schedule_id`, `slot_offer_id`).
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): bookings on spot days with non-overlapping times [#194]`.

### Task 3: Functions — adapters, callables, booking and event mapping, rules, indexes

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/spot_firestore.ts` (mappers + `FirestoreSpotScheduleStore`), `src/infra/live_spot.ts`, `src/callables/spot.ts`; tests `test/unit/spot_firestore.test.ts`, `test/unit/spot_callables.test.ts`, `test/integration/spot_booking.test.ts` (written, not run).
- Modify: `src/index.ts` (exports `saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer`), `src/callables/errors.ts` (six codes; copy `details` into the error details), `src/infra/booking_firestore.ts` (booking spot fields; `getAvailabilityDay` returns `scheduleId`/`spotId`; `getSpot`, `getSpotSchedule`, `getSlotOffer`, `getSpotDay`, `setSpotDay` in the transaction), `src/infra/event_firestore.ts` (map `spot`, Review Focus 2), `src/infra/booking_readers.ts` if the offer pre-read lives there, every test building `BookingDeps`/`BookingTx` fakes (TypeScript lists them), `test/unit/booking_firestore.test.ts`, `test/unit/booking_callables.test.ts`, `test/unit/event_firestore.test.ts`, `test/unit/errors.test.ts`; `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `storage.rules`; `app_flutter/firebase/rules-test/rules.test.mjs` (and the Storage rules test file next to it).

**Interfaces:**
- Consumes: Tasks 1–2; #139 `withdrawQuotesForDay` + its live job deps.
- Produces:
  ```ts
  // infra/spot_firestore.ts
  export function spotFromFirestore(id: string, d: DocumentData | undefined): Spot | null;
  export function spotToFirestore(s: Spot): DocumentData;                 // point as GeoPoint, Timestamps
  export function scheduleFromFirestore(id: string, d: DocumentData | undefined): SpotSchedule | null;
  export function scheduleToFirestore(s: SpotSchedule): DocumentData;
  export function offerFromFirestore(id: string, d: DocumentData | undefined): SlotOffer | null;
  export function offerToFirestore(o: SlotOffer): DocumentData;
  export function spotDayFromFirestore(d: DocumentData | undefined): SpotDay | null;
  export function spotDayToFirestore(d: SpotDay): DocumentData;           // exactly scheduleId, spotId, providerId, day, taken, updatedAt
  export class FirestoreSpotScheduleStore implements SpotScheduleStore { constructor(firestore: Firestore = db()) }
  // infra/live_spot.ts
  export function liveSpotScheduleDeps(): SpotScheduleDeps;              // providers/roster from #136's live readers
  // callables/spot.ts
  export async function handleSaveSpotSchedule(request: CallableInput, deps: SpotScheduleDeps,
    afterSave?: (holder: string, days: string[]) => Promise<void>): Promise<{ scheduleId: string; addedDays: string[] }>;
  export async function handleCancelSpotSchedule(request: CallableInput, deps: SpotScheduleDeps): Promise<Record<string, never>>;
  export async function handleSaveSlotOffer(request: CallableInput, deps: SpotScheduleDeps): Promise<{ offerId: string }>;
  export async function handleCloseSlotOffer(request: CallableInput, deps: SpotScheduleDeps): Promise<Record<string, never>>;
  ```
  `FirestoreSpotScheduleStore`: `lockProvider` = `tx.get(photographers/{uid}/private/spot_schedules)`; `openSchedulesOf` = `tx.get(query providerId == uid, status == 'open')` filtered by a day ≥ today in code; `activeServices` = `tx.get(photographers/{uid}/services where active == true)`; every read happens before the first `tx.set/delete` (Admin SDK rule; the domain orders them).

- [ ] **Step 1:** Contract check of `callables/album.ts` (requireUid + error handling), `toHttpsError` with #139's `field`, the booking transaction adapter, #139's live job deps for `withdrawQuotesForDay`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `spot_firestore.test.ts`: `spot round-trips (GeoPoint, Timestamps, cover null and set, stats)`; `schedule round-trips (assigneeId null and set, priceFrom null)`; `offer round-trips`; `spotDayToFirestore writes only scheduleId, spotId, providerId, day, taken, updatedAt`; `a document with an unknown status maps to null`; `FirestoreSpotScheduleStore reads private/spot_schedules before any write in save, cancel and offer transactions` (fake Firestore records the order).
  - `spot_callables.test.ts`: `unauthenticated → unauthenticated`; `saveSpotSchedule passes the caller uid and returns {scheduleId, addedDays}`; `day_conflict maps to failed-precondition with details.code day_conflict, details.field days and details.days`; `schedule_has_bookings maps to failed-precondition with details.days [{day, count}]`; `schedule_limit maps to resource-exhausted`; `after a successful save, afterSave runs once per added day with the holder uid` (Decision 18) and `a failing afterSave does not fail the call (logged)`; `saveSlotOffer contact_leak → invalid-argument field name`.
  - `booking_firestore.test.ts`: extend the shared `round-trips Booking through Firestore conversion` with `spotId`, `spotScheduleId`, `slotOfferId`, `source: 'spot_slot'`; `getAvailabilityDay returns scheduleId and spotId for a spot day`; `FirestoreBookingStore reads availability/{holder}/days/{day} and spot_days in the spot transaction`.
  - `booking_callables.test.ts`: `createBooking with spotScheduleId and a client place stores the spot's name` ; `slot_taken maps to failed-precondition`; `a normal createBooking on a spot day is day_taken`.
  - `event_firestore.test.ts`: `event adapter maps state spot to spot, not off`.
  - `errors.test.ts`: the six codes map as in the Contract; `details are copied next to code and field`.
  - Integration (written, not run): `parallel createBooking on one slot → one slot_taken`; `saveSpotSchedule on a day with a paid booking → day_conflict`; `cancelSpotSchedule with a paid booking → schedule_has_bookings`.
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` → the new tests fail.
- [ ] **Step 4: Implement** the adapters, callables (copy `callables/album.ts`'s shape), exports, error rows, booking/event mapping. `index.ts`: `saveSpotSchedule = onCall(CALLABLE_OPTIONS, (r) => handleSaveSpotSchedule(r, liveSpotScheduleDeps(), (holder, days) => withdrawQuotesForDays(holder, days)))` with a thin helper calling #139's `withdrawQuotesForDay(liveJobDeps(), holder, day, null)` per day.
- [ ] **Step 5: Rules, indexes, Storage.** Add the Contract rule blocks and the ten indexes; Storage `match /spots/{spotId}/{file}`. Rules tests (written, not run): `a signed-in user reads spots, spot_rankings, spot_directory and spot_days; a signed-out user reads none`; `nobody writes spots, spot_rankings, spot_directory, spot_schedules, spot_slot_offers or spot_days from a client`; `a customer reads an open schedule and cannot read a cancelled one`; `the provider and the assignee read their cancelled schedule`; `a customer list query on spot_schedules filtered by status == open succeeds; unfiltered fails`; `a customer reads an open offer, not a closed one; the provider reads a closed one`; `the owner cannot create or delete a spot availability day (only off)`; Storage: `a signed-in user reads spots/x/card.jpg; nobody uploads there`.
- [ ] **Step 6:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. Ledger: rules tests and integration tests written, not run.
- [ ] **Step 7: Commit** `feat(functions): spot schedule callables, spot bookings and rules [#194]`.

### Task 4: Ranking job, staff CLI and seed

**Files:**
- Create: `packages/domain/src/spot_score.ts`, `spot_ranking.ts`, `spot_admin.ts`, `memory_spot_rank_store.ts`; tests `packages/domain/test/spot_score.test.ts`, `spot_ranking.test.ts`, `spot_admin.test.ts`. `app_flutter/firebase/functions/src/infra/spot_rank_firestore.ts` (`FirestoreSpotCounter`, `FirestoreSpotRankStore`, `FirestoreSpotAdminStore`), `src/scheduled/rank_spots.ts`, `tools/spots.ts`, `scripts/spots-local.sh`; tests `test/unit/spot_rank_firestore.test.ts`, `test/unit/spot_cli.test.ts`, `test/unit/rank_spots_job.test.ts`.
- Modify: `packages/domain/src/index.ts`; `app_flutter/firebase/functions/src/index.ts` (`rankSpots` export), `package.json` (`"spots": "tsx tools/spots.ts"`), `seed/fixtures.ts`, `seed/apply.ts` (run the ranking once after the batch), `seed/README.md`, `test/unit/seed_fixtures.test.ts`.

**Interfaces:**
- Consumes: Task 1 (`Spot`, `seasonOk`, `inSeason`, `encodeGeohash`), Task 3 mappers; `sharp` (from #152) for covers; `guardEnv`/`assertLocalEmulators` pattern of `tools/awards.ts`.
- Produces: Contract → Domain `spot_score.ts`, `spot_ranking.ts`, `spot_admin.ts`; job `rankSpots`; CLI `npm run spots`; seed spots.

- [ ] **Step 1:** Contract check of `tools/awards.ts` (`HELP`, `guardEnv`, actor check), `test/unit/award_cli.test.ts`, `scripts/awards-local.sh`, `SCHEDULE_OPTIONS`, `seedDocuments`/`applySeed`, `sharp` in `functions/package.json` (if absent, ledger and require the cover files pre-sized: `--cover` + `--card`, both checked ≤ 2 MB / ≤ 200 KB and JPEG magic bytes).
- [ ] **Step 2: Failing tests.**
  - `spot_score.test.ts`: `score = 1·posts + 3·events + 2·bookings + 2·schedules` (2, 1, 1, 2 → 11); `in season ×1.5 rounded` (11 → 17); `season-less spots get no multiplier`; `December in [12, 1] is in season; February is not`.
  - `spot_ranking.test.ts`: `region list: pinned first, then by score, at most 10 hot`; `hidden spots are in no list but in the directory with hidden true`; `archived spots are in nothing`; `an out-of-season spot with score > 0 is not hot unless pinned`; `a region with 3 hot spots is filled from the national list up to 10, without duplicates`; `all = every pinned spot then the national top 10, ≤ 20`; `entries carry name, city, cardUrl, lat, lng, inSeason, providersWeek, pinned`; `nextDays(today, 30) has 30 VN days starting today`; `weekendDays on Wednesday → Sat, Sun; on Saturday → today, tomorrow; on Sunday → today`; `runSpotRanking counts posts 14 d, events 30 d, paid bookings 14 d, schedules 30 d/7 d/weekend for each active spot and saves only changed spots`; `runSpotRanking writes rankings and the directory and lists stale region keys to delete`.
  - `spot_admin.test.ts`: `addSpot validates name, area code from SPOT_AREAS, radius, season months 1–12, ≤ 5 tips of ≤ 120, description ≤ 600`; `a non-admin actor is permission_denied`; `pin/unpin/hide/unhide/archive set the flags and updatedBy`; `archive is final for the CLI (unarchive is not a command)`; `editSpot keeps stats and hotScore`.
  - `spot_rank_firestore.test.ts`: `schedulesWithDay builds spotId == X, status == open, days array-contains-any [...] with count()` (fake records the query); `paidBookings uses depositPaidAt >= since`; `events uses spotId, status in [open, full], startAt range`; `saveRankings deletes the stale keys in the same batch`.
  - `spot_cli.test.ts` (fake stores; mirrors `award_cli.test.ts`): `--help prints usage without touching Firebase`; `a half-set emulator environment is refused`; `add without --actor is refused`; `add --cover resizes to cover.jpg ≤ 1600 px and card.jpg ≤ 480 px and stores both URLs` (sharp on a generated JPEG); `pin rewrites spot_rankings and spot_directory from stored scores without counting`; `rank runs runSpotRanking`; `list prints id, name, area, status, flags, hotScore`.
  - `rank_spots_job.test.ts`: `the job runs runSpotRanking with the live deps once and logs the counts`.
  - `seed_fixtures.test.ts`: `five spots: Đồi chè Cầu Đất (da-lat, 10–12), Phố cổ Hội An (hoi-an), Hồ Tây (hn), Cầu Vàng (dn), Mù Cang Chải (yen-bai, 9–10), all active`; `An has an open schedule at Hồ Tây on the next two Saturdays and Sundays 06:00–11:00 with the offer "Bình minh Hồ Tây 30 phút" 490.000₫ 30/10, and spot availability records on those days`; `Bình has an open schedule at Cầu Vàng next Saturday 15:00–18:00` (only when Bình accepts orders in the seed; else the test asserts none); `seed-post-an-1 has spotId of Hồ Tây`; `no seed spot_days doc contains a booking or customer field`.
- [ ] **Step 3:** Run domain and functions tests → the new tests fail.
- [ ] **Step 4: Implement.** Hard part, ranking (pure):
  ```ts
  export function rankSpots(spots: readonly Spot[], month: number, now: string): SpotRankings[] {
    const live = spots.filter((s) => s.status === 'active' && !s.hidden);
    const pinned = live.filter((s) => s.pinned);
    const hot = live.filter((s) => !s.pinned && s.hotScore > 0 && seasonOk(s, month))
      .sort((a, b) => b.hotScore - a.hotScore || a.name.localeCompare(b.name, 'vi'));
    const national = hot.slice(0, RANK_HOT_LIMIT);
    const entry = (s: Spot) => entryOf(s, month);
    const out: SpotRankings[] = [{ key: 'all', rankedAt: now,
      entries: [...pinned, ...national].slice(0, RANKING_MAX_ENTRIES).map(entry) }];
    for (const area of [...new Set(spots.filter((s) => s.status === 'active').map((s) => s.areaCode))].sort()) {
      const own = hot.filter((s) => s.areaCode === area).slice(0, RANK_HOT_LIMIT);
      const fill = national.filter((s) => s.areaCode !== area).slice(0, RANK_HOT_LIMIT - own.length);
      out.push({ key: area, rankedAt: now,
        entries: [...pinned.filter((s) => s.areaCode === area), ...own, ...fill].slice(0, RANKING_MAX_ENTRIES).map(entry) });
    }
    return out;
  }
  ```
  `runSpotRanking`: `today = formatVnDate(now)`, `month` from `today`; for each active spot: `posts(since now − 14 d)`, `events(now, now + 30 d)`, `paidBookings(now − 14 d)`, `schedulesWithDay(nextDays(today, 30))`, `schedulesWithDay(nextDays(today, 7))`, `schedulesWithDay(weekendDays(today))`; new `hotScore = spotHotScore(...)`; save when stats/score changed (set `rankedAt`); then `saveRankings(rankSpots(all, month, nowIso), staleKeys)` and `saveDirectory(spotDirectory(all, month), nowIso)`. Adapter counts use `query.count().get()` (`.data().count`). Job: `export const rankSpots = onSchedule({ ...SCHEDULE_OPTIONS, schedule: '0 3 * * *', timeZone: 'Asia/Ho_Chi_Minh', maxInstances: 1, timeoutSeconds: 300 }, () => runRankSpots())`. CLI: copy the awards CLI structure (`HELP`, `guardEnv`, `--actor` must have `staffRole = admin`), commands of the Contract; after `add`/`edit`/flags it rewrites rankings and directory from stored scores (`rankSpots` + `spotDirectory`, no counting); `rank` runs the full job. `scripts/spots-local.sh` copies `scripts/awards-local.sh` (emulator hosts, unset credentials, `--help` safe). Seed: the five spots of spec §3.3 with real coordinates, radius 800–2,000 m, covers `https://seed.test/spots/{id}/cover.jpg` + `card.jpg`, seasons as listed; ids `seed-spot-cau-dat`, `seed-spot-hoi-an`, `seed-spot-ho-tay`, `seed-spot-cau-vang`, `seed-spot-mu-cang-chai`; schedules relative to `now` (next two weekends); `applySeed` ends with `runSpotRanking` against the emulator (live adapters on the same `db`) so Home shows them. README: a "Điểm chụp" table and the lines "Đăng nhập Lan, Trang chủ → Điểm chụp đang hot → Hồ Tây để thử S29.02 và đặt suất (S29.06)" and "`scripts/spots-local.sh rank` sau khi đổi dữ liệu".
- [ ] **Step 5:** `(cd packages/domain && npm test && npm run lint)` and `(cd app_flutter/firebase/functions && npm test && npm run build)` green.
- [ ] **Step 6: Commit** `feat(spots): daily rankSpots job, staff CLI and seed spots [#194]`.

### Task 5: App data — spot models, repository, providers, booking fields

**Files:**
- Create: `app_flutter/lib/data/spots/spot.dart`, `spot_rules.dart`, `spot_repository.dart`, `firestore_spot_repository.dart`, `spot_providers.dart`; `test/support/fake_spot_repository.dart`; tests `test/data/spots/spot_mapping_test.dart`, `spot_rules_test.dart`, `firestore_spot_repository_test.dart`, `spot_errors_test.dart`, `spot_providers_test.dart`.
- Modify: `lib/data/booking/booking.dart` (+ regenerate with `dart run build_runner build --delete-conflicting-outputs`), `lib/data/booking/booking_repository.dart`, `lib/data/booking/firestore_booking_repository.dart`, `test/support/fake_booking_repository.dart` (records `spotScheduleId`, `slotOfferId`), the booking mapping test in `test/data/booking/`.

**Interfaces:**
- Consumes: Task 3 callables and collections; `functionsRegion`; `builtInAreas`, `haversineKm`, `locationControllerProvider`; `postFromFirestore`, `eventSummaryFromFirestore`.
- Produces: Contract → App data (`lib/data/spots/*`, booking additions, `SpotError`).

- [ ] **Step 1:** Contract check of `Booking`, `bookingFromFirestore`, `BookingRepository.createBooking` after #190, `LocationState` fields, `builtInAreas`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `spot_mapping_test.dart`: `spotFromMap reads every field (GeoPoint converted by the adapter into lat/lng before the mapper)`; `archived status → archived true`; `spotEntryFromMap reads a directory entry`; `spotScheduleFromMap with assigneeId and holderId`; `slotOfferFromMap`; `spotDayFromMap with offerId on some intervals`; `unknown status → null`.
  - `spot_rules_test.dart`: `regionOfArea mirrors the server (hcm-q1 → hcm, hue → hue, null → all)`; `regionForLocation picks the nearest built-in area (21.07, 105.82 → hn)`; `seasonRunEnd wraps 12 → 1`; `slotsFor and freeStartTimes match the domain cases of Task 1` (same inputs, same outputs); `freeSlots marks taken`; `orderSpots: pinned, then hot in season by score, then the rest by distance from the origin; hidden only in the rest`; `expandWeekly({6, 7}, 2026-10-08, 2026-10-31) → 8 days`; `scheduleConflicts reports booked/pending/off/spot of another schedule; days of the same schedule are free`.
  - `firestore_spot_repository_test.dart` (`fake_cloud_firestore`, fake callable): `hot reads spot_rankings/{key} and falls back to all when missing`; `directory reads spot_directory/all`; `openSchedulesAt queries spotId and status open`; `spotDay reads spot_days/{scheduleId}_{day}`; `postsAt orders by createdAt desc, 20 per page, startAfter before`; `eventsAt filters open|full and startAt ≥ now`; `watchMine filters providerId and status open`; `saveSchedule sends {scheduleId?, spotId, days, window, serviceIds, assigneeId?} and returns scheduleId and addedDays`.
  - `spot_errors_test.dart`: `day_conflict details → dayConflict with conflicts {day: reason}`; `schedule_has_bookings → bookingCounts {day: n}`; `schedule_limit → scheduleLimit`; `contact_leak field name`; `unavailable → network`.
  - `spot_providers_test.dart`: `hotSpotsProvider reads once per key per session` (two listens, one repository call); `spotRegionProvider follows the picked area`.
  - booking mapping test: `bookingFromFirestore reads spotId, spotScheduleId, slotOfferId, source`; `createBooking sends spotScheduleId and slotOfferId only when given`; `bookingErrorOf maps outside_schedule, slot_taken, spot_archived`.
- [ ] **Step 3:** `flutter test --no-pub --timeout 60s test/data/spots` → fail.
- [ ] **Step 4: Implement.** Firebase only in `firestore_spot_repository.dart` (`FirebaseFunctions.instanceFor(region: functionsRegion)`); all reads are `get` (Chi phí Google) except the two `watch…` listeners for the owner. `hotSpotsProvider`/`spotDirectoryProvider` are not autoDispose (session cache, Decision 3).
- [ ] **Step 5:** Re-run `test/data/spots` and `test/data/booking` (one command each); `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(app): spot data layer and spot fields on bookings [#194]`.

### Task 6: S29.01, S29.02 and the entries on Home and Explore

**Files:**
- Create: `app_flutter/lib/features/spots/spots_screen.dart`, `spots_controller.dart`, `spot_screen.dart`, `spot_posts_controller.dart`, `spot_format.dart`, `widgets/spot_provider_card.dart`, `widgets/spot_offer_card.dart`; `lib/core/widgets/spot_card.dart`, `season_tag.dart`; tests `test/features/spots/spots_screen_test.dart`, `spot_screen_test.dart`, `spot_format_test.dart`, `test/core/widgets/spot_card_test.dart`, `test/features/home/home_hot_spots_test.dart`, `test/features/explore/explore_spots_test.dart`.
- Modify: `lib/app/router.dart` (`/spots`, `/spots/:spotId`; `/u/:uid/book` reads the query keys `scheduleId`, `offerId`, `start` into `BookingFlowArgs`), `lib/features/discovery/book_entry.dart` (`bookingPath`/`startBooking` gain `scheduleId`, `slotOfferId`, `start`; test in `test/features/discovery/book_entry_test.dart`: `bookingPath adds scheduleId, offerId and start`), `lib/features/booking/booking_flow_state.dart` (`BookingFlowArgs` gains `scheduleId`, `slotOfferId`, `start`, included in `==`/`hashCode`; the flow uses them in Task 7), `lib/core/core.dart` (exports), `lib/core/theme/app_icons.dart` (the icons the S29 frames use that `AppIcons` lacks; Step 1 lists them, e.g. `directions`, `landscape`), `lib/features/home/home_screen.dart` (section after the mock's position), `lib/features/explore/explore_screen.dart` (places tab → spot grid; S02.04 row above the events section), `lib/l10n/app_vi.arb` (shared, S02, S29.01, S29.02 keys) + `flutter gen-l10n`; `docs/superpowers/specs/components/shared-components.md` (`SpotCard`, `SeasonTag`, icon rows) and `docs/design/ui-components.html` (regenerate: `python3 scripts/tools/build_ui_components.py`).

**Interfaces:**
- Consumes: Task 5 providers; `startBooking` (extended here; "Đặt" calls it with `scheduleId` and `date`); the "Chọn suất" button takes an `onPickSlot` callback that Task 7 wires to `showSlotPickSheet`; `EventCard`, `PhotoCard`, `publicProfile`/photographer pool of #132, `hiddenUsersProvider` (#144), `externalLauncherProvider`, `copyEventLink` pattern.
- Produces: `SpotsScreen({String? area})`, `SpotScreen({required String spotId, String? date})`, `SpotCard`, `SeasonTag`, `spot_format.dart` (`seasonLabel(l, months, month)`, `spotCardStats(l, entry)`, `spotAvailableLabel(l, day, window)`), `spotLink(spotId)`.

**Backend wiring:** Home → `hotSpotsProvider(spotRegionProvider)` (one `get`, session cache); S02.03/S02.04/S29.01 → `spotDirectoryProvider` (one `get`); S29.02 → `spotProvider`, `spotSchedulesAtProvider`, `spotOffersAtProvider`, `spotDayProvider` per schedule for the chosen date, photographer summaries (cached pool), `spotEventsProvider`, `SpotPostsController` (`postsAt`, first page only when the section scrolls into view, 9 first-image tiles then "Xem thêm"); rules of Task 3; indexes `spot_schedules (spotId, status)`, `spot_slot_offers (spotId, status)`, `posts (spotId, createdAt)`, `events (spotId, status, startAt)`.

**Mock parity:** `#S02.01-spots` — section title "Điểm chụp đang hot" + "Xem tất cả" (→ `/spots`), horizontal `SpotCard` (cover `cardUrl`, name, city, `SeasonTag` "Đang vào mùa" when in season, "{n} thợ nhận chụp tuần này"); hidden when the list is empty. `#S02.03-spots` — the "Địa điểm" tab shows spot tiles (ordered by `orderSpots`) instead of area tiles; tap → `/spots/:id`; layout and "Xem tất cả" as the frame. S02.04 (no frame; follows `#S02.01-spots` cards): row "Điểm chụp gần bạn", ≤ 10 directory spots within 50 km of the user, nearest first, above the events section; hidden when none. `#S29.01` — app bar "Điểm chụp" with back; chips "Khu vực" (sheet of areas present in the directory + "Mọi khu vực"), "Đang vào mùa", "Cuối tuần này có thợ"; large `SpotCard`s (cover, name, city, season line "Mùa đẹp: tháng 10–12"/"Đang vào mùa · tới cuối tháng 12"/"Đẹp quanh năm", "{n} thợ · {m} sự kiện sắp tới"); order pinned → hot → rest by distance; 20 per page (client); empty "Chưa có điểm chụp nào ở khu vực này". `#S29.02` — hero cover, name (Fraunces), city, `SeasonTag` "Đang vào mùa · tới cuối tháng {m}" or line "Mùa đẹp: tháng {a}–{b}", share icon (copies `/spots/{id}`, SnackBar "Đã sao chép liên kết điểm chụp"); description, "Mẹo chụp" list, small static map tile + "Chỉ đường" (opens `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}`); "Thợ nhận chụp ở đây" with date chips (Hôm nay · each day with a schedule in the next 14 days · Chọn ngày), `SpotProviderCard` (name + provider mark, "Có mặt CN 18/10 · 06:00–11:00", `priceFromLabel(priceFrom)`, tomato %, outlined "Hồ sơ" → `/u/:uid`, small primary "Đặt"); "Gói chụp tại điểm" `SpotOfferCard` ("Bình minh Hồ Tây 30 phút · 490.000₫ · còn 4 suất CN 18/10", button "Chọn suất"); "Sự kiện ở đây" `EventCard`s; "Ảnh chụp ở đây" masonry (tap → `/p/:postId`); no gradient CTA. `#S29.02-empty` — "Chưa có thợ nhận chụp ngày này · Xem ngày khác" (tap moves to the next day with schedules); with nothing upcoming only description + photos and, for providers only, "Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc." (→ `/me/spot-schedules/new?spotId=`). `#S29.02-offseason` — the season line instead of the tag. Archived: band "Điểm này không còn nhận lịch mới", providers/offers blocks hidden.

- [ ] **Step 1:** Contract check of `HomeScreen`/`ExploreScreen` after #132 (section order, `_CategoryGrid`), the S29 frames and the screen-code names; list missing icons; ledger.
- [ ] **Step 2: Failing tests** (`FakeSpotRepository`, bounded pumps):
  - `spot_format_test.dart`: `seasonLabel: [10,11,12] in November → "Đang vào mùa · tới cuối tháng 12"; in March → "Mùa đẹp: tháng 10–12"; [12,1] in May → "Mùa đẹp: tháng 12–1"; [] → "Đẹp quanh năm"`; `spotCardStats → "3 thợ · 1 sự kiện sắp tới"`; `spotAvailableLabel → "Có mặt CN 18/10 · 06:00–11:00"`.
  - `spot_card_test.dart`: `shows name, city, season tag only in season, providers line`; `320 dp and text scale 1.3 without overflow`; `dark and light`.
  - `home_hot_spots_test.dart`: `the section reads the ranking once and shows cards in order`; `"Xem tất cả" opens /spots`; `no entries → no section`.
  - `explore_spots_test.dart`: `the Địa điểm tab shows spot tiles in orderSpots order and opens /spots/:id`; `with location, "Điểm chụp gần bạn" lists spots within 50 km nearest first above the events`; `no nearby spot → no row`.
  - `spots_screen_test.dart`: `default order pinned → hot → rest by distance`; `area chip filters by areaCode`; `"Đang vào mùa" keeps in-season spots only`; `"Cuối tuần này có thợ" keeps providersWeekend > 0`; `21 spots show 20 then the next page on scroll`; `empty text`; `load error with retry`; `no AppButton.primary`; `320 dp, 1.3×, dark, light`.
  - `spot_screen_test.dart`: `blocks appear in spec order (header, description, tips, map, providers, offers, events, photos)`; `date chips: Hôm nay + days with schedules within 14 days + Chọn ngày`; `a provider card shows "Có mặt CN 18/10 · 06:00–11:00", the price from and the tomato %`; `providers whose acceptingOrders is false are hidden`; `"Đặt" calls startBooking with photographerId, scheduleId and the chosen date`; `"Hồ sơ" opens /u/:uid`; `an offer card counts free slots of the chosen day ("còn 4 suất CN 18/10") and shows "hết suất" when none`; `a day without providers shows "Chưa có thợ nhận chụp ngày này · Xem ngày khác"`; `the provider hint shows only to providers`; `archived shows the band and hides providers and offers`; `off-season shows the season line`; `photos load only when the section is visible and show 9 tiles then Xem thêm`; `posts by blocked users are hidden`; `share copies the link and shows the SnackBar`; `Chỉ đường opens the maps URL with lat,lng`; `unknown spot shows ErrorState "Không tìm thấy điểm chụp."`; `no AppButton.primary`; `320 dp, 1.3×, dark, light`.
- [ ] **Step 3:** Run `test/features/spots`, `test/core/widgets/spot_card_test.dart`, `test/features/home`, `test/features/explore`, `test/features/discovery` (one command each) → fail.
- [ ] **Step 4: Implement**; add the l10n keys of this task; `flutter gen-l10n`; regenerate the component gallery.
- [ ] **Step 5:** Re-run the five test targets; `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(spots): S29.01 spot list, S29.02 spot page, Home and Explore entries [#194]`.

### Task 7: Booking from a spot — S04 spot context and S29.06

**Files:**
- Create: `app_flutter/lib/features/spots/slot_pick_sheet.dart`, `lib/core/widgets/slot_grid.dart`; tests `test/features/spots/slot_pick_sheet_test.dart`, `test/core/widgets/slot_grid_test.dart`, `test/features/booking/booking_flow_spot_test.dart`.
- Modify: `lib/features/booking/booking_flow_state.dart`, `booking_flow_controller.dart`, `steps/service_step.dart`, `steps/datetime_step.dart`, the S04.06 place step of #190, `steps/review_step.dart`, `booking_sheet_page.dart` (`_handleError`), `lib/features/spots/spot_screen.dart` (wire "Chọn suất"), `lib/core/core.dart`, `lib/l10n/app_vi.arb` (S29.06 and S04-spot keys) + `flutter gen-l10n`, `shared-components.md` (`SlotGrid`) + gallery; tests `test/features/booking/service_step_test.dart`, `datetime_step_test.dart`, `place_step_test.dart`, `review_step_test.dart`, `booking_flow_e2e_test.dart`.

**Interfaces:**
- Consumes: `spotRepositoryProvider` (`schedule`, `offer`, `spot`, `spotDay`), `freeStartTimes`, `freeSlots`, `BookingRepository.createBooking(spotScheduleId:, slotOfferId:)`, `BookingErrorCode.outsideSchedule|slotTaken|spotArchived`, #190's flow state (`addons`, `picks`, pickup).
- Produces: the flow's use of `BookingFlowArgs.scheduleId/slotOfferId/start` (fields added in Task 6); `SpotBookingContext {SpotSchedule schedule; String spotName; double lat, lng; SlotOffer? offer; Map<String, List<SpotInterval>> takenByDay; bool archived}`; controller `applySpotContext(SpotBookingContext)`, `refreshSpotDay(String day)`; `Future<void> showSlotPickSheet(BuildContext context, WidgetRef ref, {required SlotOffer offer, required SpotSchedule schedule, required String spotName, String? day})`; `SlotGrid({required List<({String start, String end, bool free})> slots, String? selected, required ValueChanged<String> onPick})`.

**Backend wiring:** the flow reads the schedule, spot and (slot path) offer once with `get`, and `spot_days/{scheduleId}_{day}` per chosen day; submit through `createBooking` with `spotScheduleId` (+ `slotOfferId`); `slot_taken` → `refreshSpotDay`, back to S04.02 with `bookSlotTaken` (package path) or close the sheet with `slotTakenError` (slot path); `outside_schedule` → reload the context, back to S04.02 with `bookOutsideSchedule`; `spot_archived` → close with `bookSpotArchived`; `day_taken` keeps today's handling.

**Mock parity:** S04.01 (spot context): only the schedule's packages (all active when `serviceIds` is empty), #190's add-on block unchanged, primary "Tiếp tục · {tổng}". `#S04.02-spot`: calendar with only the schedule's future days selectable (the viewed date preselected), the line "Khung giờ tại điểm 06:00–11:00", time chips from `freeStartTimes` (taken times absent). S04.06 (spot context): the place field shows the spot name, read-only, with the note "Địa điểm là điểm chụp, không đổi được." (icon `lock`); #190's "Điểm đón" still appears with a transport add-on. S04.03: summary adds "Tại {spot}"; money lines as #190. `#S29.06`: sheet title "Chọn suất" + close, offer line (name · price · {n} ảnh · giao {d} ngày as the frame), date chips (schedule days), `SlotGrid` of start times (taken: dimmed with "Đã kín", not tappable), primary "Tiếp tục · 490.000₫" disabled until a slot is picked → opens the booking sheet directly on S04.03; back from S04.03 in the slot path closes the sheet.

- [ ] **Step 1:** Contract check of the flow files after #190 (state fields, steps, place step and its `ScreenCode`), `startBooking`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `slot_grid_test.dart`: `taken slots are dimmed with "Đã kín" and not tappable`; `picking calls onPick with the start`; `320 dp, 1.3×, dark, light`.
  - `slot_pick_sheet_test.dart`: `shows the free and taken slots of the chosen day from spot_days`; `changing the date chip reads that day`; `"Tiếp tục · 490.000₫" is disabled until a slot is picked`; `continue calls startBooking with scheduleId, slotOfferId, date and start`; `exactly one AppButton.primary`.
  - `booking_flow_spot_test.dart` (controller, `ProviderContainer`, fake repos):
    - `with scheduleId the packages are limited to serviceIds`; `serviceIds [] keeps every active package`.
    - `the date step offers only the schedule's future days and preselects args.day`.
    - `start times come from freeStartTimes of the chosen day (window 06:00–11:00, taken 07:00–08:00, 120-min package → exactly 08:30 and 09:00)`.
    - `placeName is the spot name and setPlace is ignored in spot context`.
    - `submit sends spotScheduleId and no slotOfferId for a package`.
    - `slot path: opens on review with the offer as service (name, price, 30 min), day and start from args, no add-on block, back closes`.
    - `slot path submit sends slotOfferId and no addons or pickup`.
    - `slot_taken in the package path refreshes the spot day and returns to the date step with bookSlotTaken`.
    - `slot_taken in the slot path closes the sheet with slotTakenError`.
    - `outside_schedule reloads the context and returns to the date step`; `spot_archived closes with bookSpotArchived`.
  - `datetime_step_test.dart`: `spot context shows "Khung giờ tại điểm 06:00–11:00"`. `place_step_test.dart`: `spot context shows the locked field and the note; pickup still appears with transport`. `review_step_test.dart`: `summary shows "Tại Hồ Tây"`. `service_step_test.dart`: `spot context lists only enabled packages`. `booking_flow_e2e_test.dart`: `spot package path S04.01 → S04.02-spot → S04.06 → S04.03 → GoToPayment`; `slot path S29.06 → S04.03 → GoToPayment`.
- [ ] **Step 3:** Run `test/features/booking`, `test/features/spots`, `test/core/widgets/slot_grid_test.dart` (one command each) → fail.
- [ ] **Step 4: Implement.** Hard part, entering the flow with a spot context:
  ```dart
  // BookingFlowController.build(): when args.scheduleId != null
  ref.listen(_spotContextProvider(args), (_, next) {               // schedule + spot + offer, one get each
    final ctx = next.value;
    if (ctx != null) applySpotContext(ctx);
  }, fireImmediately: true);

  void applySpotContext(SpotBookingContext ctx) {
    final today = _todayKey();
    final days = ctx.schedule.days.where((d) => d.compareTo(today) >= 0).toList();
    final offer = ctx.offer;
    state = state.copyWith(
      spot: ctx,
      placeName: ctx.spotName,                                      // Decision 9, locked in the UI
      day: days.contains(args.day) ? args.day : (days.isEmpty ? null : days.first),
      serviceId: offer?.id, priceVnd: offer?.price, durationMinutes: offer?.slotMinutes, serviceName: offer?.name,
      start: offer != null ? args.start : null,
      step: offer != null ? BookingStep.review : state.step,
      picks: offer != null ? const {} : state.picks,                 // T6: no add-ons on slots
    );
  }
  ```
  `availableStarts` = `freeStartTimes(ctx.schedule.window, durationMinutes, ctx.takenByDay[day] ?? [])` filtered by the existing "start in the future" rule; packages filtered in the service step by `ctx.schedule.serviceIds`. Add the l10n keys of this task; `flutter gen-l10n`; gallery.
- [ ] **Step 5:** Re-run the three targets; `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(booking): book from a spot with limited days and times, S29.06 slot picker [#194]`.

### Task 8: Provider screens — S29.03, S29.04, S29.05 and the S06.01 entry

**Files:**
- Create: `app_flutter/lib/features/spots/my_spot_schedules_screen.dart`, `spot_schedule_edit_screen.dart`, `spot_schedule_edit_controller.dart`, `slot_offer_sheet.dart`; tests `test/features/spots/my_spot_schedules_screen_test.dart`, `spot_schedule_edit_screen_test.dart`, `spot_schedule_edit_controller_test.dart`, `slot_offer_sheet_test.dart`.
- Modify: `lib/app/router.dart` (`/me/spot-schedules`, `/me/spot-schedules/new`, `/me/spot-schedules/:scheduleId`), `lib/features/work/work_screen.dart` (entry line "Lịch tại điểm" as the S06.01 frame shows; `Key('open-spot-schedules')`), `lib/features/spots/spot_screen.dart` (provider hint link), `lib/l10n/app_vi.arb` (S29.03–S29.05, S06.01 keys) + `flutter gen-l10n`; test `test/features/work/` (one case).

**Interfaces:**
- Consumes: `mySpotSchedulesProvider`, `mySlotOffersProvider`, `spotDirectoryProvider`, `spotRepositoryProvider.saveSchedule/cancelSchedule/saveOffer/closeOffer`, `spotErrorOf`, `scheduleConflicts`, `expandWeekly`, `slotsFor`, the owner's availability listener (`AvailabilityRepository.watchRange`), `myPackagesProvider`, the work screen's bookings provider (Decision 21), #136's member list provider for studios, `AvailabilityCalendar`, `SegmentedTabs`, `ConfirmSheet`, `AppBottomSheet`.
- Produces: `MySpotSchedulesScreen()`, `SpotScheduleEditScreen({String? scheduleId, String? spotId})`, `SpotScheduleEditController` (`pickSpot`, `setMode(repeat|pick)`, `setWeekdays`, `setRange`, `toggleDay`, `setWindow`, `togglePackage`, `setAssignee`, `submit()`), `Future<void> showSlotOfferSheet(BuildContext context, {required SpotSchedule schedule, SlotOffer? offer})`.

**Backend wiring:** listeners on own open schedules and offers (rules: provider reads); writes only through the four callables; conflicts shown before submit from the owner's availability listener, the server's `day_conflict`/`schedule_has_bookings` details override them; S29.03 per-day counts from the work screen's bookings (no extra reads).

**Mock parity:** `#S29.03` — app bar "Lịch tại điểm của tôi"; one `GlassCard` per schedule: spot name + city, "{n} ngày · 06:00–11:00", day rows "CN 18/10 · 2 booking", "{n} gói chia suất" + "Thêm gói chia suất" (opens S29.05), red text "Huỷ lịch" → `ConfirmSheet` (title "Huỷ lịch tại {spot}?", red "Huỷ lịch"); a refused cancel shows "Còn 2 booking ngày CN 18/10. Liên hệ khách hoặc huỷ từng booking (khách được hoàn 100%)."; tap card → S29.04 edit; sticky primary "Thêm lịch tại điểm"; empty "Chưa có lịch tại điểm" / "Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt.". `#S29.04` — "Điểm chụp" picker (search "Tìm theo tên điểm", hot first, then nearest to the provider's service area; locked when editing or when opened with `spotId`); studio only: "Thợ chụp" member picker; `SegmentedTabs` "Lặp lại" (weekday chips T2…CN + "Từ ngày"/"Tới ngày") / "Chọn ngày" (multi-select calendar); "Khung giờ" start/end pickers (15-minute steps); "Gói đặt được" chips ("Mọi gói đang bật" or the chosen ones); preview "12 ngày · 06:00–11:00"; conflicting days red with the reason ("Đã có booking", "Ngày nghỉ", "Đã có lịch tại điểm khác", "Studio hết chỗ"); off-season note "Điểm này đẹp nhất tháng 10–11"; primary "Mở lịch" (edit: "Lưu lịch"). `#S29.05` — sheet "Gói chia suất": "Tên gói", "Giá mỗi suất (₫)", "Thời lượng suất" and "Nghỉ giữa suất" chips in minutes, "Số ảnh", "Số ảnh chỉnh", "Số ngày giao", preview "8 suất/ngày: 06:00, 06:40 …", primary "Lưu"; edit adds red text "Đóng gói" → `ConfirmSheet`. S06.01 — one entry line "Lịch tại điểm" (no own frame, spec §8).

- [ ] **Step 1:** Contract check of `WorkScreen`, the availability repository, #136's member list provider, `myPackagesProvider`; ledger.
- [ ] **Step 2: Failing tests.**
  - `my_spot_schedules_screen_test.dart`: `lists schedules with days, window, per-day booking counts from the provider's bookings and offer count`; `"Huỷ lịch" opens the confirm sheet; confirming calls cancelSchedule; cancelling the sheet calls nothing`; `schedule_has_bookings shows "Còn 2 booking ngày CN 18/10…"`; `"Thêm lịch tại điểm" opens /me/spot-schedules/new`; `"Thêm gói chia suất" opens S29.05`; `empty state copy`; `exactly one AppButton.primary`; `320 dp, 1.3×, dark, light`.
  - `spot_schedule_edit_controller_test.dart`: `repeat mode expands Sat+Sun from 08/10 to 31/10 into 8 days`; `pick mode toggles days`; `a booked day and an off day are marked with their reasons and block submit`; `more than 40 days or a day after +60 shows spotScheduleTooMany`; `window 04:45 or shorter than 1 h shows spotScheduleWindowInvalid`; `submit sends spotId, days, window, serviceIds ([] for Mọi gói) and assigneeId for a studio`; `server day_conflict marks the returned days red`; `schedule_limit shows spotScheduleLimit`; `not_accepting_orders shows spotScheduleNotAccepting`.
  - `spot_schedule_edit_screen_test.dart`: `the picker lists hot spots first, then by distance from the service area, and filters by typed name (accent-insensitive)`; `opened with spotId the spot is preselected and locked`; `preview reads "12 ngày · 06:00–11:00"`; `off-season note for Đồi chè Cầu Đất in March`; `studio shows "Thợ chụp", individual does not`; `success pops with "Đã mở lịch tại điểm"`; `exactly one AppButton.primary`; `320 dp, 1.3×, dark, light`.
  - `slot_offer_sheet_test.dart`: `preview "7 suất/ngày: 06:00, 06:40, …" for 06:00–11:00, 30/10`; `an offer that fits no slot shows "Khung giờ không đủ cho một suất" and Lưu is disabled`; `price 5.000 shows the price error`; `server contact_leak shows the contact message under Tên gói`; `limit_exceeded shows "Mỗi lịch tối đa 2 gói chia suất"`; `Lưu sends every field and closes with "Đã lưu gói chia suất"`; `"Đóng gói" confirms then calls closeOffer`.
  - work screen: `the "Lịch tại điểm" entry opens /me/spot-schedules for a provider`.
- [ ] **Step 3:** `flutter test --no-pub --timeout 60s test/features/spots` → fail.
- [ ] **Step 4: Implement**; add the l10n keys of this task; `flutter gen-l10n`.
- [ ] **Step 5:** Run `test/features/spots`, `test/features/work` (one command each); `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(spots): S29.03–S29.05 spot schedules and slot offers for providers [#194]`.

### Task 9: Tagging events and posts — S12.01-spot and S10.01-spot

**Files:**
- Modify (domain): `packages/domain/src/event.ts` (`EventRecord.spotId`, `validateEventFields` reads `spotId`), `event_ports.ts` (`EventTx.getSpot`), `event_use_cases.ts` (save/publish/update check the spot, Decision 14), `memory_event_store.ts`; tests `packages/domain/test/event_spot.test.ts`.
- Modify (functions): `src/infra/event_firestore.ts` (map `spotId`, `getSpot`), `test/unit/event_firestore.test.ts` (shared round-trip with `spotId`); `app_flutter/firebase/firestore.rules` (`validPostCreate` accepts `spotId`), `rules-test/rules.test.mjs`.
- Modify (app): `lib/data/events/event_draft.dart` (`spotId`, `spotDecided`), `firestore_event_repository.dart` + `firestore_event_mapping.dart` (send/read `spotId`), `lib/features/event_create/create_event_controller.dart`, `create_event_screen.dart` (field after `PlaceField`), create `lib/features/event_create/spot_field.dart`; `lib/data/content/post_publisher.dart` (`PostDraft.spotId`), `firestore_post_publisher.dart`, `lib/features/create_post/create_post_providers.dart`/`post_composer.dart`/`create_post_screen.dart` (suggestion chip); `lib/l10n/app_vi.arb` (S12.01, S10.01 keys) + `flutter gen-l10n`; tests `test/features/event_create/spot_field_test.dart`, `create_event_spot_test.dart`, `test/features/create_post/post_spot_chip_test.dart`, `test/data/content/` publisher test, `test/data/events/` mapping test.

**Interfaces:**
- Consumes: Task 1 `spotCovers`, `SPOT_EVENT_SLACK_M`; `spotDirectoryProvider`; `LocationState.location`; `foldVietnamese` (#132's accent fold).
- Produces: `EventRecord.spotId`; `SpotField({required List<SpotEntry> suggestions, required String? value, required bool decided, required ValueChanged<String?> onChanged, String? error})`; `suggestSpotForPost({required String locationText, double? lat, double? lng, required List<SpotEntry> spots}) → SpotEntry?`.

**Backend wiring:** events through the existing callables (`saveEventDraft`/`publishEvent`/`updateEvent`) with `spotId`; posts through the existing client create (rules accept `spotId` of an active spot: one rules `get`); suggestions from `spotDirectoryProvider` (no extra query).

**Mock parity:** `#S12.01-spot` — field "Điểm chụp" right after the place field: suggestion chips of active spots whose radius contains the event location (nearest first) and the chip "Không thuộc điểm chụp nào"; publishing without a choice shows "Chọn một điểm chụp hoặc “Không thuộc điểm chụp nào”" under the field and scrolls to it; editing an event can change it. `#S10.01-spot` — under the location field, chip "Gắn với {tên điểm} ×" when a suggestion exists; the "×" removes it in one tap (semantics "Bỏ gắn {spot}"); no chip without a suggestion.

- [ ] **Step 1:** Contract check of `validateEventFields` touched-keys handling, the create-event controller's publish validation, `PostDraft` and the post composer state, `foldVietnamese`; ledger.
- [ ] **Step 2: Failing tests.**
  - `event_spot.test.ts`: `a draft with spotId null saves`; `publish with an active spot covering the location stores spotId`; `a spot 3 km away is invalid_argument field spotId`; `an archived spot is spot_archived`; `an unknown spot is not_found field spotId`; `updateEvent changes spotId`; `an event without the field reads spotId null`.
  - `event_firestore.test.ts`: shared round-trip includes `spotId`.
  - rules (written): `a photographer creates a post with spotId of an active spot`; `spotId of an archived or missing spot is refused`; `a post without spotId still passes`.
  - `spot_field_test.dart`: `lists covering spots nearest first plus "Không thuộc điểm chụp nào"`; `selecting calls onChanged`; `error text shows under the field`; `320 dp, 1.3×`.
  - `create_event_spot_test.dart`: `publish without a decision shows eventSpotRequired and calls nothing`; `"Không thuộc điểm chụp nào" publishes spotId null`; `a chosen spot is sent`; `editing shows the saved choice`.
  - `post_spot_chip_test.dart`: `location text "Đồi chè Cầu Đất buổi sáng" suggests Đồi chè Cầu Đất`; `"ho tay" (no accents) suggests Hồ Tây`; `no text match but the device position inside Hồ Tây's radius suggests it`; `nothing matching → no chip`; `× removes the chip and the post publishes without spotId`; `publishing with the chip sends spotId`.
  - publisher test: `FirestorePostPublisher writes spotId only when set`. Event mapping test: `eventDetailFromFirestore reads spotId`.
- [ ] **Step 3:** Run domain, functions, `test/features/event_create`, `test/features/create_post`, `test/data/content`, `test/data/events` (one command each) → fail.
- [ ] **Step 4: Implement.** Rules sample:
  ```
  // in validPostCreate(): add 'spotId' to hasOnly([...]) and
  && (!('spotId' in d) || (d.spotId is string
       && exists(/databases/$(database)/documents/spots/$(d.spotId))
       && get(/databases/$(database)/documents/spots/$(d.spotId)).data.status == 'active'))
  ```
  Add the l10n keys of this task; `flutter gen-l10n`.
- [ ] **Step 5:** Re-run every target of Step 3; `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(spots): tag events (S12.01) and posts (S10.01) with a photo spot [#194]`.

### Task 10: Ledger, spec status, cross-issue notes

**Files:**
- Create: `docs/superpowers/handover/ledger-trending-spots.md`.
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 ("Làm bởi" cells of S29.01–S29.06 and the five variants: link the PR of #194, no prose status), `docs/superpowers/specs/2026-10-08-trending-spots-design.md` header "Trạng thái" → "đang làm (#194)" with the PR link, `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` (§4 job count 10 with `rankSpots`; the directory/rankings read pattern in §13 if it lists read patterns).

- [ ] **Step 1: Ledger** (English prose, Vietnamese copy verbatim): Step 1 findings of every task (real names of #152/#139/#136/#190/#132 members, the availability call-site list of Task 2, the screen-code constant names); Decisions 1–23 as taken; copy not in the spec or differing from the mock (`spotSeasonAllYear`, error strings, `bookSpotPlaceLocked`, `bookSpotWindow`, `spotScheduleConflictFull`, `slotOfferErrorFit`); skipped suites (rules tests, Storage rules tests, Functions integration tests: written, not run); deploy order (indexes first — the job's count queries and S29.02 queries fail without them — then Functions with `rankSpots`, then Firestore and Storage rules, then the app; the dev project is on Spark: emulators only, `scripts/spots-local.sh rank` replaces the schedule there); staff steps (`npm run spots -- add …` for real spots, covers through `--cover`); the Deferred list.
- [ ] **Step 2: Cross-issue notes.** If #140 had not merged when Task 2 ran, comment on #140 (`gh issue comment 140 -R thanhngochoang/booking`) with: "S29 (#194): a photographer whose `availability/{uid}/days/{today}` is `{state: 'spot', scheduleId}` is not an instant candidate while `now` is inside that schedule's window; use `spotBusyAt(record, schedule, now)` from `packages/domain/src/spot_booking.ts`." Comment on #195 and #196 with the collections and names they build on (`spots.stats`, `spot_rankings`, `spot_directory`).
- [ ] **Step 3: Spec status.** Fill the §2 cells and the spec header. `git diff --stat` shows only docs in this task.
- [ ] **Step 4: Commit** `docs(spots): handover ledger and screen status for trending spots [#194]`.

## Deferred

- Fully automatic hotness, personalised ranking and spot discovery from post clusters (#195, spec §11); save/follow spots and "vào mùa / có thợ mới" notifications (#196, S17).
- Add-ons on slot offers (spec T6, Phase 2); auto-confirming spot bookings (Needs the owner 1).
- Staff spot screens on the web dashboard (#161/S23, spec T7); the CLI is the Phase 1 tool. An `unarchive` command.
- Rescheduling a spot booking inside its schedule (Decision 16); reassigning a studio spot booking to another member (Decision 7); S27 collaborators as schedule assignees.
- Post moderation states (hidden/removed/pending) in the spot page query and the job's count — waits for the moderation state of #83/S23 (Decision 13).
- Thumbnails for post images and covers below 480 px (cost spec §11 unit), interactive map on S29.02 (spec §11), Maps API anything.
- Sharding `spot_directory/all` beyond ~2,500 active spots.
- Self-hosted parity: `services/api` routes and PostgreSQL migrations for `spots`, `spot_schedules`, `spot_schedule_days`, `spot_slot_offers`, `spot_day_intervals` (data-model docs updated in Tasks 1–2; code is phase 2, #90).
- Real payment intermediary, real payouts (fake rails only, owner ruling 2026-10-07).
